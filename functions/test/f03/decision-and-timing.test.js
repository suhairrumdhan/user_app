"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {Timestamp} = require("firebase-admin/firestore");
const {buildOrderCommandHandler} = require("../../src/domain/order-commands");
const {FakeFirestore} = require("./helpers/fake-firestore");

class FakeHttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

function handler(database) {
  return buildOrderCommandHandler({
    db: database,
    onCall: (value) => value,
    HttpsError: FakeHttpsError,
  });
}

let sequence = 0;
function call(activeHandler, uid, command, payload = {}) {
  sequence += 1;
  return activeHandler({
    auth: {uid},
    data: {
      schemaVersion: 3,
      command,
      operationId: `decision-${sequence}`,
      orderId: "order-one",
      payload,
      actor: {},
    },
  });
}

function baseOrder(status, extra = {}) {
  return {
    schemaVersion: 3,
    orderId: "order-one",
    user: {userId: "user-one"},
    pharmacy: {pharmacyId: "pharmacy-one"},
    status,
    statusHistory: [],
    medicines: [{matchedMedicineId: "medicine-a", quantity: 1}],
    offerVersion: 0,
    pharmacyReviewActiveMs: 0,
    ...extra,
  };
}

test("user can explicitly continue an unresolved insured order", async () => {
  const database = new FakeFirestore({
    "pharmacies/pharmacy-one": {status: "approved", isActive: true},
    "pharmacies/pharmacy": {status: "approved", isActive: true},
    "orders/order-one": baseOrder("received", {
      estimatedTotalPrice: 15, grossEstimatedTotalPrice: 20,
      insuranceEstimatedShare: 5, containsInsurance: true,
    }),
  });
  await call(handler(database), "user-one", "continueWithoutInsurance");
  const order = database.read("orders/order-one");
  assert.equal(order.status, "underReview");
  assert.equal(order.insuranceDecision, "continueWithoutInsurance");
  assert.equal(order.estimatedTotalPrice, 20);
  assert.equal(order.customerEstimatedTotalPrice, 20);
  assert.equal(order.insuranceEstimatedShare, 0);
  assert.ok(order.reviewStartedAt);
  assert.equal(
    order.pharmacyDelayAt.toMillis() - order.reviewStartedAt.toMillis(),
    24 * 60 * 60 * 1000,
  );
});

test("revising a partial offer invalidates the old version and counts user wait", async () => {
  const oldDecisionStart = Timestamp.fromDate(new Date("2026-01-01T00:00:00Z"));
  const items = [{medicineId: "medicine-a", quantity: 1, soldByPiece: false}];
  const database = new FakeFirestore({
    "pharmacies/pharmacy-one": {status: "approved", isActive: true},
    "pharmacies/pharmacy": {status: "approved", isActive: true},
    "orders/order-one": baseOrder("partialOfferPending", {
      offerVersion: 1,
      partialOffer: {version: 1, items},
      userDecisionStartedAt: oldDecisionStart,
      userDecisionWaitMs: 0,
      pharmacyReviewActiveMs: 5000,
    }),
    "pharmacies/pharmacy-one/medicines/medicine-a": {
      quantity: 5,
      reservedQuantity: 0,
      isActive: true,
      sellingPrice: 10,
      expiryDate: Timestamp.fromDate(new Date("2099-01-01T00:00:00Z")),
    },
  });
  const activeHandler = handler(database);
  await call(activeHandler, "pharmacy-one", "revisePartialOffer", {items, offerVersion: 1});
  const revised = database.read("orders/order-one");
  assert.equal(revised.status, "partialOfferPending");
  assert.equal(revised.offerVersion, 2);
  assert.ok(revised.userDecisionWaitMs > 0);

  await assert.rejects(
    call(activeHandler, "user-one", "acceptPartialOffer", {offerVersion: 1}),
    {code: "aborted"},
  );
  await call(activeHandler, "user-one", "acceptPartialOffer", {offerVersion: 2});
  const accepted = database.read("orders/order-one");
  assert.equal(accepted.status, "confirmedReserved");
  assert.equal(accepted.acceptedOfferVersion, 2);
  assert.ok(accepted.reviewStartedAt);
  assert.equal(
    accepted.pharmacyDelayAt.toMillis() - accepted.reviewStartedAt.toMillis(),
    24 * 60 * 60 * 1000 - 5000,
  );
});
