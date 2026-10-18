"use strict";

const {OrderContractError} = require("./order-contract");
const {validateOrderShift} = require("./financial-authorization");
const {readCanonicalOrderInvoice} = require("./order-invoice");

function cents(value) {
  const number = Number(value ?? 0);
  if (!Number.isFinite(number) || number < 0 || !Number.isSafeInteger(Math.round(number * 100))) {
    throw new OrderContractError("failed-precondition", "Invalid monetary amount.");
  }
  return Math.round(number * 100);
}

function text(value) {
  return String(value ?? "").trim();
}

function itemKey(item) {
  return `${text(item.medicineId)}|${item.sellAsPiece === true ? "piece" : "pack"}`;
}

function claimDue(invoice) {
  return Math.max(0, cents(invoice.insuranceClaimAmount ?? invoice.companyShare ?? invoice.insuranceDiscount) -
    cents(invoice.insuranceRefundedAmount) - cents(invoice.insuranceCollectedAmount) - cents(invoice.insuranceCreditAppliedAmount) + cents(invoice.insuranceCreditAmount));
}

function financialEntry({pharmacyId, invoiceId, actor, timestamp, amount, type, accountType, direction, metadata}) {
  return {pharmacyId, type, accountType, direction, amount: amount / 100,
    referenceId: invoiceId, referenceCollection: "sales", createdBy: actor.id,
    transactionDate: timestamp, createdAt: timestamp, isPosted: true, isVoided: false,
    currency: "LYD", metadata};
}

async function refundDeliveredOrder({transaction, db, order, actor, payload, operationKey, timestamp, directInvoice = null}) {
  if (actor.type !== "pharmacy" || order.status !== "completed") {
    throw new OrderContractError("failed-precondition", "Only delivered orders can be refunded by the pharmacy.");
  }
  const reason = text(payload.reason);
  const shiftId = text(payload.shiftId);
  if (!reason || !shiftId || !Array.isArray(payload.items) || payload.items.length === 0) {
    throw new OrderContractError("invalid-argument", "Refund reason, shift and items are required.");
  }
  const pharmacyId = order.pharmacy.pharmacyId;
  const pharmacy = db.collection("pharmacies").doc(pharmacyId);
  const {invoice, invoiceRef} = directInvoice || await readCanonicalOrderInvoice({
    transaction, db, order, paymentState: "delivered",
  });
  const originalInvoiceId = invoiceRef.id;
  const orderId = order.orderId || null;
  const source = directInvoice ? "posRefund" : "orderRefund";
  const shiftRef = pharmacy.collection("shifts").doc(shiftId);
  const {snapshot: shiftSnapshot} = await validateOrderShift({transaction, db, pharmacyId, actor, shiftId});
  if (!shiftSnapshot.exists || shiftSnapshot.data().status !== "open") {
    throw new OrderContractError("failed-precondition", "Refund requires an open shift.");
  }
  const companyId = text(invoice.insuranceCompanyId);
  const companyRef = companyId ? pharmacy.collection("insurance_companies").doc(companyId) : null;
  const companySnapshot = companyRef ? await transaction.get(companyRef) : null;
  if (companyRef && !companySnapshot.exists) {
    throw new OrderContractError("failed-precondition", "Insurance company is missing.");
  }

  const originals = new Map();
  for (const line of invoice.items || []) {
    const key = itemKey(line);
    const quantity = Number(line.quantity);
    if (!Number.isSafeInteger(quantity) || quantity <= 0) throw new OrderContractError("failed-precondition", "Invalid invoice quantity.");
    const gross = cents(line.unitPrice) * quantity;
    const discount = cents(line.discountAmount) > 0 ? cents(line.discountAmount) :
      Math.round(gross * Number(line.discountPercentage || 0) / 100);
    const previous = originals.get(key);
    originals.set(key, {line, allocations: [...(previous?.allocations || []), ...(line.batchAllocations || [])], quantity: (previous?.quantity || 0) + quantity,
      net: (previous?.net || 0) + Math.max(0, gross - discount)});
  }
  const requested = new Map();
  for (const item of payload.items) {
    const quantity = Number(item.quantity);
    if (!Number.isSafeInteger(quantity) || quantity <= 0) {
      throw new OrderContractError("invalid-argument", "Refund quantities must be positive integers.");
    }
    const key = itemKey(item);
    if (!originals.has(key)) throw new OrderContractError("invalid-argument", "Refund item is not in the invoice.");
    requested.set(key, (requested.get(key) || 0) + quantity);
  }
  const returned = {...invoice.refundedQuantities};
  for (const [key, quantity] of requested) {
    returned[key] = Number(returned[key] || 0) + quantity;
    if (returned[key] > originals.get(key).quantity) {
      throw new OrderContractError("failed-precondition", "Refund exceeds the remaining sold quantity.");
    }
  }
  let originalNet = 0;
  let returnedNet = 0;
  for (const [key, item] of originals) {
    originalNet += item.net;
    returnedNet += item.net * Number(returned[key] || 0) / item.quantity;
  }
  const ratio = originalNet > 0 ? returnedNet / originalNet : 0;
  const customerCumulative = Math.round(cents(invoice.customerShare ?? invoice.total) * ratio);
  const companyCumulative = Math.round(cents(invoice.companyShare ?? invoice.insuranceDiscount) * ratio);
  const customerRefund = customerCumulative - cents(invoice.refundedCustomerAmount);
  const companyRefund = companyCumulative - cents(invoice.insuranceRefundedAmount);
  if (customerRefund < 0 || companyRefund < 0 || customerCumulative > cents(invoice.paidAmount ?? (directInvoice ? invoice.total : 0))) {
    throw new OrderContractError("failed-precondition", "Refund cannot exceed actual customer payment.");
  }
  const cashOut = cents(payload.cashOut);
  const cardOut = cents(payload.cardOut);
  if (cashOut + cardOut !== customerRefund) {
    throw new OrderContractError("failed-precondition", "Refund payout must equal the customer paid share.",
      {customerRefund: customerRefund / 100});
  }
  const dueReduction = Math.min(companyRefund, claimDue(invoice));
  const companyCredit = companyRefund - dueReduction;
  const refundId = `${directInvoice ? "pos" : "order"}-refund-${operationKey}`;
  const refundRef = pharmacy.collection("sales").doc(refundId);
  const items = [...requested].map(([key, quantity]) => {
    const original = originals.get(key);
    let skip = Number(invoice.refundedQuantities?.[key] || 0);
    let remaining = quantity;
    const batchAllocations = [];
    for (const part of original.allocations) {
      const piece = original.line.sellAsPiece === true;
      const units = piece ? part.pieces : part.packages;
      const ignored = Math.min(skip, units);
      skip -= ignored;
      const taken = Math.min(remaining, units - ignored);
      if (taken) batchAllocations.push({...part, packages: piece ? 0 : taken, pieces: piece ? taken : 0});
      remaining -= taken;
    }
    return {...original.line, quantity, batchAllocations,
      batchTraceStatus: remaining ? "legacyUnallocated" : "allocated"};
  });
  const fullRefund = [...originals].every(([key, item]) => returned[key] === item.quantity);
  transaction.create(refundRef, {
    schemaVersion: 3, id: refundId, invoiceNumber: refundId, pharmacyId,
    source, type: "refund", status: "completed", isSaved: true, isDeleted: false,
    orderId, refSaleId: originalInvoiceId, refInvoiceNumber: invoice.invoiceNumber,
    items, total: 0, subtotal: (customerRefund + companyRefund) / 100,
    cashOut: cashOut / 100, cardOut: cardOut / 100,
    customerRefund: customerRefund / 100, insuranceRefund: companyRefund / 100,
    insuranceDueReduction: dueReduction / 100, insuranceCredit: companyCredit / 100,
    insuranceCompanyId: companyId || null, shiftId, reason,
    financialPosted: true, inventoryDisposition: "quarantined",
    createdAt: timestamp, completedAt: timestamp, saleDate: timestamp, performedById: actor.id,
  });
  for (const [index, item] of items.entries()) {
    transaction.create(pharmacy.collection("quarantinedReturns").doc(`${refundId}-${index}`), {
      refundId, orderId, invoiceId: originalInvoiceId,
      medicineId: item.medicineId, quantity: item.quantity, soldByPiece: item.sellAsPiece === true,
      batchAllocations: item.batchAllocations, batchTraceStatus: item.batchTraceStatus,
      reason: "returned-after-delivery", availableForSale: false, createdAt: timestamp,
    });
  }
  const metadata = {orderId, refundId, source};
  for (const [method, amount] of [["cash", cashOut], ["card", cardOut]]) {
    if (!amount) continue;
    transaction.create(pharmacy.collection("financial_transactions").doc(`${refundId}-${method}`), {
      ...financialEntry({pharmacyId, invoiceId: originalInvoiceId, actor, timestamp, amount,
        type: "refund", accountType: method === "cash" ? "cashbox" : "bank", direction: "outflow", metadata}),
      paymentMethod: method, shiftId, title: "رد حصة الزبون من الطلب",
    });
  }
  if (companyRefund) {
    transaction.create(pharmacy.collection("financial_transactions").doc(`${refundId}-insurance`), {
      ...financialEntry({pharmacyId, invoiceId: originalInvoiceId, actor, timestamp, amount: companyRefund,
        type: "refund", accountType: "insuranceReceivable", direction: "payable",
        metadata: {...metadata, dueReduction: dueReduction / 100, companyCredit: companyCredit / 100}}),
      insuranceCompanyId: companyId, title: "تسوية تأمين مرتجع طلب",
    });
  }
  const shift = shiftSnapshot.data();
  transaction.update(shiftRef, {
    cashRefunds: (cents(shift.cashRefunds) + cashOut) / 100,
    cardRefunds: (cents(shift.cardRefunds) + cardOut) / 100,
    insuranceRefunds: (cents(shift.insuranceRefunds) + companyRefund) / 100,
    refundsCount: Number(shift.refundsCount || 0) + 1,
    updatedAt: timestamp,
  });
  if (companyRef && companyRefund) {
    const company = companySnapshot.data();
    transaction.update(companyRef, {
      currentReceivable: Math.max(0, cents(company.currentReceivable) - dueReduction) / 100,
      totalRefundedClaims: (cents(company.totalRefundedClaims) + companyRefund) / 100,
      creditBalance: (cents(company.creditBalance) + companyCredit) / 100,
      updatedAt: timestamp,
    });
  }
  transaction.update(invoiceRef, {
    refundedQuantities: returned, refundedCustomerAmount: customerCumulative / 100,
    insuranceRefundedAmount: companyCumulative / 100,
    insuranceCreditAmount: (cents(invoice.insuranceCreditAmount) + companyCredit) / 100,
    refundState: fullRefund ? "refunded" : "partiallyRefunded", lastRefundId: refundId, updatedAt: timestamp,
  });
  if (!directInvoice) transaction.update(db.collection("orders").doc(order.orderId), {
    refundState: fullRefund ? "refunded" : "partiallyRefunded", lastRefundId: refundId, updatedAt: timestamp,
  });
  transaction.create(invoiceRef.collection("returns").doc(refundId), {
    refundId, items, customerRefund: customerRefund / 100, companyRefund: companyRefund / 100,
    reason, createdAt: timestamp, createdBy: actor.id, operationId: operationKey,
  });
  if (companyRefund) transaction.create(pharmacy.collection("insurance_ledger").doc(`${refundId}-insurance`), {
    type: "refund", invoiceId: originalInvoiceId, insuranceCompanyId: companyId,
    amount: companyRefund / 100, dueReduction: dueReduction / 100, companyCredit: companyCredit / 100,
    createdAt: timestamp, createdBy: actor.id, operationId: operationKey,
  });
  return {success: true, orderId, refundId,
    customerRefund: customerRefund / 100, insuranceCredit: companyCredit / 100,
    insuranceDueReduction: dueReduction / 100};
}

async function collectInsurancePayment({transaction, db, pharmacyId, actor, payload, operationKey, timestamp}) {
  const companyId = text(payload.companyId);
  const amount = cents(payload.amount);
  if (!companyId || !["cash", "card", "bank", "bank_transfer"].includes(text(payload.paymentMethod))) {
    throw new OrderContractError("invalid-argument", "Company, non-negative amount and payment method are required.");
  }
  const pharmacy = db.collection("pharmacies").doc(pharmacyId);
  const companyRef = pharmacy.collection("insurance_companies").doc(companyId);
  const companySnapshot = await transaction.get(companyRef);
  if (!companySnapshot.exists) throw new OrderContractError("not-found", "Insurance company not found.");
  const invoicesSnapshot = await transaction.get(pharmacy.collection("sales").where("insuranceCompanyId", "==", companyId));
  const receiptsSnapshot = await transaction.get(pharmacy.collection("insurance_collections").where("insuranceCompanyId", "==", companyId));
  if (receiptsSnapshot.docs.some((doc) => doc.data().isVoided !== true &&
      cents(doc.data().amount) > 0 && !Array.isArray(doc.data().allocations))) {
    throw new OrderContractError("failed-precondition", "Existing insurance receipts require invoice allocation before another collection.");
  }
  const invoices = invoicesSnapshot.docs.filter((doc) => {
    const invoice = doc.data();
    return invoice.type !== "refund" && invoice.isDeleted !== true && invoice.status === "completed" &&
      (invoice.source !== "order" || invoice.paymentState === "delivered") && claimDue(invoice) > 0;
  }).sort((a, b) => {
    const aTime = a.data().createdAt?.toMillis?.() || 0;
    const bTime = b.data().createdAt?.toMillis?.() || 0;
    return aTime - bTime || a.id.localeCompare(b.id);
  });
  const totalDue = invoices.reduce((sum, doc) => sum + claimDue(doc.data()), 0);
  if (amount > totalDue) throw new OrderContractError("failed-precondition", "Collection exceeds delivered outstanding claims.");
  const allocations = [];
  const creditAllocations = [];
  const availableCredit = cents(companySnapshot.data().creditBalance);
  const hasExplicitCredit = Object.prototype.hasOwnProperty.call(payload, "creditAmount");
  const requestedCredit = hasExplicitCredit ? cents(payload.creditAmount) : Math.min(availableCredit, totalDue);
  if (requestedCredit > availableCredit) {
    throw new OrderContractError("failed-precondition", "Settlement exceeds the company credit balance.");
  }
  if (requestedCredit > totalDue) {
    throw new OrderContractError("failed-precondition", "Settlement exceeds delivered outstanding claims.");
  }
  let remainingCredit = requestedCredit;
  const creditApplied = requestedCredit;
  if (!amount && !creditApplied) throw new OrderContractError("failed-precondition", "No payment or credit is available to settle.");
  if (amount > totalDue - creditApplied) {
    throw new OrderContractError("failed-precondition", "Collection exceeds outstanding claims after company credit.");
  }
  let remaining = amount;
  for (const doc of invoices) {
    if (!remaining && !remainingCredit) break;
    const due = claimDue(doc.data());
    const credit = Math.min(remainingCredit, due);
    remainingCredit -= credit;
    const allocated = Math.min(remaining, due - credit);
    remaining -= allocated;
    if (allocated) allocations.push({invoiceId: doc.id, amount: allocated / 100});
    if (credit) creditAllocations.push({invoiceId: doc.id, amount: credit / 100});
    transaction.update(pharmacy.collection("sales").doc(doc.id), {
      insuranceCollectedAmount: (cents(doc.data().insuranceCollectedAmount) + allocated) / 100,
      insuranceCreditAppliedAmount: (cents(doc.data().insuranceCreditAppliedAmount) + credit) / 100,
      insuranceClaimStatus: allocated + credit === due ? "collected" : "partiallyCollected",
      updatedAt: timestamp,
    });
  }
  const collectionId = `insurance-${operationKey}`;
  const transactionId = `${collectionId}-receipt`;
  const company = companySnapshot.data();
  const receipt = {
    pharmacyId, insuranceCompanyId: companyId, insuranceCompanyName: text(company.name),
    amount: amount / 100, allocations, creditAllocations, creditApplied: creditApplied / 100, paymentMethod: payload.paymentMethod,
    collectionYear: Number(payload.collectionYear) || timestamp.toDate().getUTCFullYear(),
    collectionMonth: Number(payload.collectionMonth) || timestamp.toDate().getUTCMonth() + 1,
    referenceNumber: text(payload.referenceNumber) || null, notes: text(payload.notes) || null,
    collectionDate: timestamp, createdAt: timestamp, createdBy: actor.id,
    financialPosted: true, financialTransactionId: amount ? transactionId : (creditApplied ? `${collectionId}-credit` : null), isVoided: false,
  };
  transaction.create(pharmacy.collection("insurance_collections").doc(collectionId), receipt);
  if (amount) transaction.create(pharmacy.collection("financial_transactions").doc(transactionId), {
    ...financialEntry({pharmacyId, invoiceId: collectionId, actor, timestamp, amount,
      type: "insuranceCollection", accountType: "insuranceReceivable", direction: "inflow",
      metadata: {allocations, source: "insuranceCollection"}}),
    referenceCollection: "insurance_collections", insuranceCompanyId: companyId,
    insuranceCompanyName: text(company.name), paymentMethod: payload.paymentMethod,
    title: "تحصيل تأمين موزع على الفواتير",
  });
  if (creditApplied) transaction.create(pharmacy.collection("financial_transactions").doc(`${collectionId}-credit`), {
    ...financialEntry({pharmacyId, invoiceId: collectionId, actor, timestamp, amount: creditApplied,
      type: "insuranceSettlement", accountType: "insuranceReceivable", direction: "settlement",
      metadata: {creditAllocations, source: "insuranceCreditSettlement"}}),
    referenceCollection: "insurance_collections", insuranceCompanyId: companyId,
    insuranceCompanyName: text(company.name), paymentMethod: "credit",
    title: "تسوية رصيد دائن من مرتجعات التأمين",
  });
  transaction.update(companyRef, {
    totalCollected: (cents(company.totalCollected) + amount) / 100,
    currentReceivable: (totalDue - amount - creditApplied) / 100,
    creditBalance: (cents(company.creditBalance) - creditApplied) / 100,
    lastCollectionId: collectionId, lastCollectionTransactionId: amount ? transactionId : null,
    updatedAt: timestamp,
  });
  transaction.create(pharmacy.collection("insurance_ledger").doc(collectionId), {
    type: amount ? "collection" : "creditSettlement", insuranceCompanyId: companyId, amount: amount / 100, allocations,
    creditAllocations, creditApplied: creditApplied / 100, createdAt: timestamp,
    createdBy: actor.id, operationId: operationKey,
  });
  return {success: true, collectionId, transactionId, companyId, companyName: text(company.name),
    amount: amount / 100, previousReceivable: totalDue / 100, newReceivable: (totalDue - amount - creditApplied) / 100,
    creditApplied: creditApplied / 100, remainingCreditBalance: (availableCredit - creditApplied) / 100,
    allocations, creditAllocations};
}

module.exports = {cents, claimDue, refundDeliveredOrder, collectInsurancePayment};
