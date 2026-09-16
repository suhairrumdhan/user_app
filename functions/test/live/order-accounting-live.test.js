"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const admin = require("firebase-admin");
const {
  initializeLiveSuite,
  readDocument,
  testOrder,
  writeEvidence,
} = require("./helpers/live-firebase");

const SUITE_NAME = "f03-live-order-accounting";

function pathFor(context, suffix) {
  return `pharmacies/${context.pharmacyUid}/${suffix}`;
}

async function seedBase(context) {
  const now = admin.firestore.Timestamp.now();
  context.accountingEmployeeId = `accounting-manager-${context.runId}`;
  context.shiftA = `accounting-shift-a-${context.runId}`;
  context.shiftB = `accounting-shift-b-${context.runId}`;
  const batch = context.db.batch();
  batch.set(context.db.doc(`users/${context.userUid}`), {
    userId: context.userUid,
    name: "Live Accounting User",
    isActive: true,
    updatedAt: now,
  }, {merge: true});
  batch.set(context.db.doc(`pharmacies/${context.pharmacyUid}`), {
    pharmacyId: context.pharmacyUid,
    name: "Roshita Live Accounting Pharmacy",
    acceptedInsuranceCodes: ["LIVE"],
    status: "approved",
    isOnline: true,
    isActive: true,
    updatedAt: now,
  }, {merge: true});
  batch.set(context.db.doc(pathFor(context, `employees/${context.accountingEmployeeId}`)), {
    id: context.accountingEmployeeId,
    roleId: "admin",
    isActive: true,
  });
  batch.set(context.db.doc(pathFor(context, "insurance_companies/live-insurance")), {
    status: "فعال", code: "LIVE", discountPercentage: 25,
  });
  batch.set(context.db.doc(`users/${context.userUid}/insurances/live-card`), {
    companyCode: "LIVE", cardNumber: "LIVE-CARD", isActive: true,
    startDate: "2020-01-01", endDate: "2099-01-01",
  });
  for (const shiftId of [context.shiftA, context.shiftB]) {
    batch.set(context.db.doc(pathFor(context, `shifts/${shiftId}`)), {
      status: "open",
      cashTotal: 0,
      cardTotal: 0,
      salesCount: 0,
      updatedAt: now,
    });
  }
  await batch.commit();
  await writeEvidence(context, "running");
}

async function seedOrder(context, label, options = {}) {
  const orderId = `live-accounting-${label}-${context.runId}`;
  const medicineId = `live-accounting-med-${label}-${context.runId}`;
  const medicine = {
    id: medicineId,
    name: `Live Accounting ${label}`,
    quantity: 10,
    reservedQuantity: 0,
    pieceQuantity: 0,
    reservedPieceQuantity: 0,
    isActive: true,
    expiryDate: admin.firestore.Timestamp.fromDate(new Date("2099-01-01T00:00:00Z")),
  };
  const order = testOrder(context, orderId, [{
    matchedMedicineId: medicineId,
    matchedMedicineName: medicine.name,
    quantity: 2,
    soldByPiece: false,
  }], options);
  order.insurance = {enabled: true, companyCodes: ["LIVE"], companyNames: ["Live Insurance"], cardNumbers: ["LIVE-CARD"]};
  order.insuranceSelection = {companyId: "live-insurance", companyCode: "LIVE", cardId: "live-card", cardNumber: "LIVE-CARD"};
  const batch = context.db.batch();
  batch.set(context.db.doc(pathFor(context, `medicines/${medicineId}`)), medicine);
  batch.set(context.db.doc(`orders/${orderId}`), order);
  await batch.commit();
  return {orderId, medicineId};
}

function invoicePayload(context, orderId, medicineId, invoiceId) {
  return {
    invoiceId,
    invoice: {
      invoiceNumber: `LIVE-INV-${context.runId}`,
      shiftId: context.shiftA,
      subtotal: 20,
      discount: 0,
      insuranceDiscount: 5,
      insuranceCompanyId: "live-insurance",
      insuranceCompanyName: "Live Insurance",
      total: 15,
      paymentMethod: "cash",
      items: [{
        medicineId,
        name: "Live Accounting Medicine",
        quantity: 2,
        sellAsPiece: false,
        unitPrice: 10,
        unitCost: 4,
      }],
      orderId,
    },
  };
}

test("F03 atomic accounting on the live Firebase project", {
  timeout: 300000,
}, async (t) => {
  const context = await initializeLiveSuite(SUITE_NAME);
  await seedBase(context);
  await context.callFunction(
    "pharmacy",
    "managePharmacyEmployeeCredential",
    {
      pharmacyId: context.pharmacyUid,
      employeeId: context.accountingEmployeeId,
      username: context.accountingEmployeeId,
      password: "LiveEmployee-2026",
    },
  );
  const accountingLogin = await context.callFunction(
    "pharmacy",
    "createPharmacyEmployeeSession",
    {
      pharmacyId: context.pharmacyUid,
      username: context.accountingEmployeeId,
      password: "LiveEmployee-2026",
    },
  );
  context.accountingEmployeeActor = {
    employeeId: context.accountingEmployeeId,
    employeeSession: accountingLogin.sessionToken,
  };
  try {
    await t.test("invoice in shift A and delivery in shift B post exactly once", async () => {
      const {orderId, medicineId} = await seedOrder(context, "delivery");
      await context.call("pharmacy", "confirmFullOrder", orderId);
      const invoiceId = `live-accounting-invoice-${context.runId}`;
      const operationId = `live:${context.runId}:invoice:fixed`;
      const options = {
        operationId,
        payload: invoicePayload(context, orderId, medicineId, invoiceId),
      };
      const first = await context.call("pharmacy", "startPreparing", orderId, options);
      const retry = await context.call("pharmacy", "startPreparing", orderId, options);
      assert.deepEqual(retry, first);

      const invoiceBefore = await readDocument(
        context,
        pathFor(context, `sales/${invoiceId}`),
      );
      const medicineBefore = await readDocument(
        context,
        pathFor(context, `medicines/${medicineId}`),
      );
      assert.equal(invoiceBefore.creationShiftId, context.shiftA);
      assert.equal(invoiceBefore.paidAmount, 0);
      assert.equal(invoiceBefore.paymentState, "pendingDelivery");
      assert.equal(medicineBefore.quantity, 8);
      assert.equal(medicineBefore.reservedQuantity, 0);

      await context.call("pharmacy", "markReady", orderId);
      await context.call("pharmacy", "completeOrder", orderId, {
        payload: {collectionShiftId: context.shiftB},
      });
      const invoiceAfter = await readDocument(
        context,
        pathFor(context, `sales/${invoiceId}`),
      );
      assert.equal(invoiceAfter.creationShiftId, context.shiftA);
      assert.equal(invoiceAfter.collectionShiftId, context.shiftB);
      assert.equal(invoiceAfter.paidAmount, 15);
      assert.equal(invoiceAfter.insuranceClaimStatus, "due");
      assert.equal(
        (await readDocument(context, pathFor(context, `shifts/${context.shiftA}`))).cashTotal,
        0,
      );
      assert.equal(
        (await readDocument(context, pathFor(context, `shifts/${context.shiftB}`))).cashTotal,
        15,
      );
      assert.equal(
        (await readDocument(
          context,
          pathFor(context, `financial_transactions/order-customer-${orderId}`),
        )).amount,
        15,
      );
      assert.equal(
        (await readDocument(
          context,
          pathFor(context, `financial_transactions/order-insurance-${orderId}`),
        )).amount,
        5,
      );
    });

    await t.test("pre-delivery reversal restores stock and pays no refund", async () => {
      const {orderId, medicineId} = await seedOrder(context, "reversal");
      await context.call("pharmacy", "confirmFullOrder", orderId);
      const invoiceId = `live-reversal-invoice-${context.runId}`;
      await context.call("pharmacy", "startPreparing", orderId, {
        payload: invoicePayload(context, orderId, medicineId, invoiceId),
      });
      await context.call("pharmacy", "cancelAfterInvoice", orderId, {
        payload: {reason: "live automated reversal"},
      });
      const medicine = await readDocument(
        context,
        pathFor(context, `medicines/${medicineId}`),
      );
      const reversal = await readDocument(
        context,
        pathFor(context, `sales/order-reversal-${orderId}`),
      );
      assert.equal(medicine.quantity, 10);
      assert.equal(reversal.cashOut, 0);
      assert.equal(reversal.cardOut, 0);
    });

    await t.test("new partial-offer version rejects the stale version", async () => {
      const {orderId, medicineId} = await seedOrder(context, "revision");
      const items = [{medicineId, quantity: 2, soldByPiece: false}];
      await context.call("pharmacy", "createPartialOffer", orderId, {
        payload: {items},
      });
      await context.call("pharmacy", "revisePartialOffer", orderId, {
        payload: {items, offerVersion: 1},
      });
      await assert.rejects(
        context.call("user", "acceptPartialOffer", orderId, {
          payload: {offerVersion: 1},
        }),
        {code: "aborted"},
      );
      await context.call("user", "acceptPartialOffer", orderId, {
        payload: {offerVersion: 2},
      });
      const order = await readDocument(context, `orders/${orderId}`);
      assert.equal(order.status, "confirmedReserved");
      assert.equal(order.acceptedOfferVersion, 2);
    });

    for (const decision of ["acceptPartialOffer", "rejectPartialOffer"]) {
      await t.test(`reopened confirmed offer requires new consent: ${decision}`, async () => {
        const {orderId, medicineId} = await seedOrder(context, `reopened-${decision}`);
        await context.call("pharmacy", "createPartialOffer", orderId, {
          payload: {items: [{medicineId, quantity: 2}]},
        });
        await context.call("user", "acceptPartialOffer", orderId, {payload: {offerVersion: 1}});
        const first = await readDocument(context, `orders/${orderId}`);
        const revision = {payload: {items: [{medicineId, quantity: 1}], offerVersion: 1},
          operationId: `live:${context.runId}:reopen:${decision}`};
        await context.call("pharmacy", "revisePartialOffer", orderId, revision);
        await context.call("pharmacy", "revisePartialOffer", orderId, revision);
        const waiting = await readDocument(context, `orders/${orderId}`);
        assert.equal(waiting.status, "partialOfferPending");
        assert.equal(waiting.offerVersion, 2);
        assert.equal(waiting.acceptedOfferVersion, null);
        assert.equal((await readDocument(context, pathFor(context, `medicines/${medicineId}`))).reservedQuantity, 0);
        const oldPath = `orders/${orderId}/reservations/${first.reservationId}`;
        const released = await readDocument(context, oldPath);
        assert.equal(released.state, "released");
        await assert.rejects(context.call("user", "acceptPartialOffer", orderId,
          {payload: {offerVersion: 1}}), {code: "aborted"});
        await context.call("user", decision, orderId, {payload: {offerVersion: 2}});
        const final = await readDocument(context, `orders/${orderId}`);
        const accepted = decision === "acceptPartialOffer";
        assert.equal(final.status, accepted ? "confirmedReserved" : "cancelled");
        assert.equal(final.userDecisionStartedAt, null);
        assert.ok(final.userDecisionWaitMs >= first.userDecisionWaitMs);
        assert.equal((await readDocument(context, pathFor(context, `medicines/${medicineId}`))).reservedQuantity,
          accepted ? 1 : 0);
        assert.deepEqual(await readDocument(context, oldPath), released);
        if (accepted) {
          assert.notEqual(final.reservationId, first.reservationId);
          assert.equal(final.acceptedOfferVersion, 2);
        }
      });
    }

    await t.test("user explicitly continues an unresolved insured order", async () => {
      const {orderId} = await seedOrder(context, "insurance-decision", {
        status: "received",
        statusLabel: "مستلم",
        reviewStartedAt: null,
        insurance: {
          enabled: true,
          companyCodes: ["UNRESOLVED-LIVE"],
        },
      });
      await context.call("user", "continueWithoutInsurance", orderId);
      const order = await readDocument(context, `orders/${orderId}`);
      assert.equal(order.status, "underReview");
      assert.equal(order.insuranceDecision, "continueWithoutInsurance");
      assert.ok(order.reviewStartedAt);
      assert.ok(order.pharmacyDelayAt);
    });

    await t.test("expired pickup makes one incident and restores stock", async () => {
      const {orderId, medicineId} = await seedOrder(context, "not-collected");
      await context.call("pharmacy", "confirmFullOrder", orderId);
      const invoiceId = `live-not-collected-invoice-${context.runId}`;
      await context.call("pharmacy", "startPreparing", orderId, {
        payload: invoicePayload(context, orderId, medicineId, invoiceId),
      });
      await context.call("pharmacy", "markReady", orderId);
      await context.db.doc(`orders/${orderId}`).update({
        pickupDeadline: admin.firestore.Timestamp.fromMillis(Date.now() - 1000),
      });
      await context.call("pharmacy", "markNotCollected", orderId, {
        actor: context.accountingEmployeeActor,
      });
      assert.equal(
        (await readDocument(context, `orders/${orderId}`)).status,
        "notCollected",
      );
      assert.equal(
        (await readDocument(
          context,
          `users/${context.userUid}/orderIncidents/${orderId}`,
        )).occurrenceCount,
        1,
      );
      assert.equal(
        (await readDocument(context, pathFor(context, `medicines/${medicineId}`))).quantity,
        10,
      );
    });

    await writeEvidence(context, "passed", {assertions: 5});
  } catch (error) {
    await writeEvidence(context, "failed", {error: String(error)});
    throw error;
  } finally {
    await context.app.delete();
  }
});
