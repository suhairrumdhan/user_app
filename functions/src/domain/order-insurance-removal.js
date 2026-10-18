"use strict";

const {OrderContractError, ORDER_STATUS} = require("./order-contract");
const {cents} = require("./order-ledger");
const {readCanonicalOrderInvoice} = require("./order-invoice");
const {Timestamp} = require("firebase-admin/firestore");

const COMMANDS = new Set(["requestInsuranceRemoval", "acceptInsuranceRemoval", "rejectInsuranceRemoval", "cancelInsuranceRemoval"]);
const ACTIVE = new Set(["received", "underReview", "partialOfferPending", "confirmedReserved", "preparing", "ready"]);

function stale() {
  throw new OrderContractError("stale-offer-price", "stale-offer-price: Review the current uninsured amount again.");
}

async function handleInsuranceRemoval({transaction, db, order, orderRef, actor, command, payload,
  timestamp, quoteForOrder, cancelOrder, operationId}) {
  if (!ACTIVE.has(order.status) || order.insurance?.enabled !== true) {
    throw new OrderContractError("failed-precondition", "Only active insured orders can change coverage.");
  }
  const pending = order.insuranceRemoval;
  const basis = {status: order.status, offerVersion: Number(order.offerVersion || 0), invoiceId: order.invoiceId || null};
  let canonical;
  async function quote() {
    if (basis.invoiceId && !(order.status === ORDER_STATUS.PARTIAL_OFFER_PENDING && order.partialOffer?.kind === "replacement")) {
      canonical = await readCanonicalOrderInvoice({transaction, db, order, paymentState: "pendingDelivery"});
      const gross = (cents(canonical.invoice.subtotal) - cents(canonical.invoice.discount)) / 100;
      return {currency: "LYD", grossTotal: gross, insuranceShare: 0, customerTotal: gross,
        previousCustomerTotal: canonical.invoice.customerShare};
    }
    const current = await quoteForOrder();
    return {...current, previousCustomerTotal: Number(order.customerEstimatedTotalPrice ?? order.estimatedTotalPrice ?? 0)};
  }
  let update;
  const instant = timestamp.toMillis();
  const processing = ["underReview", "confirmedReserved", "preparing"].includes(order.status);
  if (command === "requestInsuranceRemoval") {
    const refreshing = pending?.status === "pending" && payload.version === pending.version;
    if (pending?.status === "pending" && !refreshing) {
      throw new OrderContractError("failed-precondition", "An insurance removal decision is already pending.");
    }
    const quoted = await quote();
    update = {insuranceRemoval: {version: Number(pending?.version || 0) + 1, status: "pending",
      basis, quote: quoted, requestedBy: {id: actor.id, type: actor.type}, requestedAt: refreshing ? pending.requestedAt : timestamp,
      previousInsuranceSelection: order.insuranceSelection || null,
      reason: String(payload.reason || pending?.reason || "").trim()}};
    if (!refreshing) update.insuranceDecisionWaitIntervals = [...(order.insuranceDecisionWaitIntervals || []), {start: timestamp, end: null}];
    if (processing && !refreshing) {
      const started = order.reviewStartedAt?.toMillis?.();
      update.pharmacyReviewActiveMs = Number(order.pharmacyReviewActiveMs || 0) +
        (Number.isFinite(started) ? Math.max(0, instant - started) : 0);
      update.reviewStartedAt = null;
      update.pharmacyDelayAt = null;
    }
  } else {
    if (actor.type !== "user") throw new OrderContractError("permission-denied", "Only the user may decide coverage removal.");
    if (pending?.status !== "pending" || !Number.isSafeInteger(payload.version) || payload.version !== pending.version ||
        pending.basis?.status !== basis.status || pending.basis?.offerVersion !== basis.offerVersion ||
        pending.basis?.invoiceId !== basis.invoiceId) stale();
    update = {insuranceRemoval: {...pending, status: command === "acceptInsuranceRemoval" ? "accepted" :
      command === "cancelInsuranceRemoval" ? "cancelled" : "rejected",
      decidedAt: timestamp, decidedBy: actor.id}};
    const waited = Math.max(0, instant - pending.requestedAt.toMillis());
    update.insuranceDecisionWaitIntervals = (order.insuranceDecisionWaitIntervals || []).map((interval) =>
      interval.end == null ? {...interval, end: timestamp} : interval);
    if (processing) {
      update.reviewStartedAt = timestamp;
      update.pharmacyDelayAt = Timestamp.fromMillis(instant + Math.max(0, 86400000 - Number(order.pharmacyReviewActiveMs || 0)));
    }
    if (order.status === "ready" && order.pickupDeadline?.toMillis) {
      update.pickupDeadline = Timestamp.fromMillis(order.pickupDeadline.toMillis() + waited);
      update.pickupOverdue = instant >= update.pickupDeadline.toMillis();
    }
    if (command === "cancelInsuranceRemoval") {
      Object.assign(update, await cancelOrder(), {status: ORDER_STATUS.CANCELLED, statusLabel: "ملغي",
        cancelledAt: timestamp, reviewStartedAt: null, pharmacyDelayAt: null,
        userDecisionStartedAt: null, userDecisionDeadline: null,
        statusHistory: [...(order.statusHistory || []), {status: ORDER_STATUS.CANCELLED,
          changedAt: timestamp, changedById: actor.id, changedByType: actor.type, command}]});
    } else if (command === "acceptInsuranceRemoval") {
      const current = await quote();
      const itemKey = (item) => `${item.medicineId}:${item.soldByPiece === true}:${item.quantity}:${cents(item.unitPrice)}`;
      if (cents(current.customerTotal) !== cents(pending.quote.customerTotal) ||
          cents(current.previousCustomerTotal) !== cents(pending.quote.previousCustomerTotal) ||
          (current.items || []).map(itemKey).sort().join("|") !==
          (pending.quote.items || []).map(itemKey).sort().join("|")) stale();
      Object.assign(update, {requestedInsurance: order.insurance, insurance: {...order.insurance, enabled: false},
        containsInsurance: false, insuranceSelection: null, insuranceEstimatedShare: 0,
        customerEstimatedTotalPrice: current.customerTotal, grossEstimatedTotalPrice: current.grossTotal,
        estimatedTotalPrice: current.customerTotal, insuranceDecision: "continueWithoutInsurance", insuranceDecisionAt: timestamp});
      if (canonical) {
        transaction.update(canonical.invoiceRef, {total: current.customerTotal, customerShare: current.customerTotal,
          remainingAmount: current.customerTotal, companyShare: 0, insuranceDiscount: 0,
          insuranceCompanyId: null, insuranceCompanyName: null, insuranceCoveragePercentage: 0,
          insuranceClaimAmount: 0, insuranceClaimStatus: "notApplicable", insuranceRemovalVersion: pending.version,
          insuranceRemovedAt: timestamp, previousInsuranceSnapshot: {companyId: canonical.invoice.insuranceCompanyId,
            companyShare: canonical.invoice.companyShare, customerShare: canonical.invoice.customerShare}});
        Object.assign(update, {finalCustomerTotalPrice: current.customerTotal, finalGrossTotalPrice: current.grossTotal,
          finalInsuranceShare: 0});
      } else if (order.partialOffer?.quote) {
        update.partialOffer = {...order.partialOffer, quote: {currency: current.currency, items: current.items,
          grossTotal: current.grossTotal, insuranceShare: 0, customerTotal: current.customerTotal}};
        // Invalidate decisions made from an insured offer dialog; preserve an already accepted reservation.
        update.offerVersion = Number(order.offerVersion || 0) + 1;
        update.partialOffer.version = update.offerVersion;
        if (order.acceptedOfferVersion != null) update.acceptedOfferVersion = update.offerVersion;
      }
      if (order.status === ORDER_STATUS.RECEIVED) Object.assign(update, {status: ORDER_STATUS.UNDER_REVIEW,
        statusLabel: "قيد المراجعة", reviewStartedAt: timestamp,
        statusHistory: [...(order.statusHistory || []), {status: ORDER_STATUS.UNDER_REVIEW,
          changedAt: timestamp, changedById: actor.id, changedByType: actor.type, command}],
        pharmacyDelayAt: Timestamp.fromMillis(instant + 24 * 60 * 60 * 1000)});
    }
  }
  transaction.create(db.collection("pharmacies").doc(order.pharmacy.pharmacyId).collection("audit_logs")
    .doc(`insurance-removal-${operationId}`), {action: command, orderId: order.orderId, actor,
      version: update.insuranceRemoval.version, quote: update.insuranceRemoval.quote, createdAt: timestamp});
  const decision = update.insuranceRemoval;
  const userMessage = decision.status === "pending" ?
    `راجع طلب الدفع بدون تأمين. المبلغ عليك ${decision.quote.customerTotal.toFixed(2)} د.ل.` :
    decision.status === "accepted" ? "تم اعتماد موافقتك على الدفع بدون تأمين بالمبلغ المعروض." :
      decision.status === "cancelled" ? "تم إلغاء طلبك بناءً على اختيارك عدم المتابعة بدون تأمين." :
      "تم رفض التحول إلى الدفع بدون تأمين. التغطية السابقة لم تتغير.";
  const pharmacyMessage = decision.status === "pending" ?
    `بانتظار موافقة المستخدم على الدفع بدون تأمين. المبلغ على المستخدم ${decision.quote.customerTotal.toFixed(2)} د.ل.` :
    decision.status === "accepted" ? "وافق المستخدم على الدفع بدون تأمين بالمبلغ المعروض." :
      decision.status === "cancelled" ? "ألغى المستخدم الطلب بدلاً من المتابعة بدون تأمين." :
      "رفض المستخدم التحول إلى الدفع بدون تأمين. التغطية السابقة لم تتغير.";
  for (const [role, recipientId, message, isActionable] of [
    ["user", order.user.userId, userMessage, decision.status === "pending"],
    ["pharmacy", order.pharmacy.pharmacyId, pharmacyMessage, decision.status === "accepted"],
  ]) {
    const ref = db.collection(role === "user" ? "users" : "pharmacies")
      .doc(recipientId).collection("notifications");
    transaction.create(ref.doc(`insurance_removal_${order.orderId}_${decision.version}_${decision.status}`), {
      recipientRole: role, recipientId,
      userId: order.user.userId, pharmacyId: order.pharmacy.pharmacyId, orderId: order.orderId,
      type: "orderUpdate", title: "قرار التغطية التأمينية", message, body: message,
      referenceType: "order", referenceId: order.orderId, actionRoute: "/orders", actionId: order.orderId,
      isRead: false, isDeleted: false, isActionable, createdAt: timestamp,
    });
  }
  transaction.update(orderRef, {...update, updatedAt: timestamp, operationId});
  return {success: true, orderId: order.orderId, status: update.status || order.status,
    insuranceRemoval: update.insuranceRemoval};
}

module.exports = {INSURANCE_REMOVAL_COMMANDS: COMMANDS, handleInsuranceRemoval};
