"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {Timestamp} = require("firebase-admin/firestore");
const {buildOrderCommandHandler} = require("../../src/domain/order-commands");
const {processOrderTimer} = require("../../src/domain/order-timers");
const {FakeFirestore} = require("./helpers/fake-firestore");

const HOUR = 60 * 60 * 1000;
const START = Date.UTC(2026, 8, 14, 8);
const ORDER = "orders/order-one";
const STOCK = "pharmacies/pharmacy-one/medicines/medicine-a";
const RESERVATIONS = `${ORDER}/reservations/`;

class HttpError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

function setup() {
  let instant = START;
  let sequence = 0;
  const db = new FakeFirestore({
    [ORDER]: {schemaVersion: 3, orderId: "order-one", orderNumber: "TEST-ONE",
      status: "underReview", statusHistory: [], user: {userId: "user-one"},
      pharmacy: {pharmacyId: "pharmacy-one"}, insurance: {enabled: false},
      medicines: [{matchedMedicineId: "medicine-a", matchedMedicineName: "Drug", quantity: 3}],
      offerVersion: 0, reservationId: null, pharmacyReviewActiveMs: 0,
      reviewStartedAt: Timestamp.fromMillis(START)},
    [STOCK]: {quantity: 10, reservedQuantity: 0, pieceQuantity: 0,
      reservedPieceQuantity: 0, isActive: true,
      expiryDate: Timestamp.fromDate(new Date("2099-01-01T00:00:00Z"))},
    "pharmacies/pharmacy-one/shifts/shift-one": {status: "open", cashTotal: 0,
      cardTotal: 0, salesCount: 0},
  });
  const handler = buildOrderCommandHandler({db, HttpsError: HttpError,
    onCall: (callback) => callback, clock: () => instant});
  const call = (command, payload = {}, operationId, uid) => handler({
    auth: {uid: uid || (["acceptPartialOffer", "rejectPartialOffer", "cancelOrder"].includes(command) ?
      "user-one" : "pharmacy-one")},
    data: {schemaVersion: 3, orderId: "order-one", command, payload, actor: {},
      operationId: operationId || `repeat-offer-operation-${++sequence}`},
  });
  return {db, call, at: (hours) => { instant = START + hours * HOUR; },
    timer: () => processOrderTimer({db, orderId: "order-one", clock: () => instant})};
}

const items = (quantity) => [{medicineId: "medicine-a", quantity, soldByPiece: false}];
const invoice = (quantity) => ({invoiceId: "invoice-one", invoice: {
  invoiceNumber: "INV-ONE", shiftId: "shift-one", subtotal: 10 * quantity,
  discount: 0, insuranceDiscount: 0, total: 10 * quantity, paymentMethod: "cash",
  items: [{medicineId: "medicine-a", name: "Drug", quantity, unitPrice: 10, unitCost: 4}],
}});

async function firstAcceptance(h) {
  h.at(2);
  await h.call("createPartialOffer", {items: items(2)});
  h.at(5);
  await h.call("acceptPartialOffer", {offerVersion: 1});
  return h.db.read(ORDER).reservationId;
}

test("INT-13 two real command decision cycles produce 26h and one alert per kind", async () => {
  const h = setup();
  const oldReservation = await firstAcceptance(h);
  h.at(10);
  const revision = {items: items(1), offerVersion: 1};
  await h.call("revisePartialOffer", revision, "second-offer-stable-operation");
  const pending = h.db.read(ORDER);
  assert.equal(pending.status, "partialOfferPending");
  assert.equal(pending.pharmacyReviewActiveMs, 7 * HOUR);
  assert.equal(pending.userDecisionWaitMs, 3 * HOUR);
  assert.equal(pending.reviewStartedAt, null);
  assert.equal(pending.acceptedOfferVersion, null);
  assert.equal(h.db.read(STOCK).reservedQuantity, 0);
  const released = h.db.read(`${RESERVATIONS}${oldReservation}`);
  assert.equal(released.state, "released");
  assert.equal(released.items[0].quantity, 2);
  const beforeReplay = [...h.db.documents.entries()];
  await h.call("revisePartialOffer", revision, "second-offer-stable-operation");
  assert.deepEqual([...h.db.documents.entries()], beforeReplay);

  h.at(12);
  await h.call("acceptPartialOffer", {offerVersion: 2});
  const accepted = h.db.read(ORDER);
  assert.notEqual(accepted.reservationId, oldReservation);
  assert.equal(accepted.userDecisionWaitMs, 5 * HOUR);
  assert.equal(accepted.userDecisionStartedAt, null);
  assert.equal(accepted.userDecisionDeadline, null);
  assert.equal(h.db.read(STOCK).reservedQuantity, 1);
  assert.deepEqual(h.db.read(`${RESERVATIONS}${oldReservation}`), released);
  h.at(13);
  await h.call("startPreparing", invoice(1));
  h.at(29 - 1 / HOUR);
  await h.timer();
  assert.notEqual(h.db.read(ORDER).pharmacyDelayed, true);
  h.at(29);
  await h.timer();
  assert.equal(h.db.read(ORDER).pharmacyDelayed, true);
  h.at(31);
  await h.call("markReady");
  const ready = h.db.read(ORDER);
  assert.equal(ready.pharmacyReviewActiveMs, 26 * HOUR);
  assert.equal(ready.userDecisionWaitMs, 5 * HOUR);
  assert.equal(ready.pickupDeadline.toMillis(), START + 55 * HOUR);
  await h.timer();
  await h.timer();
  assert.equal(h.db.paths(`${ORDER}/timerEvents/`).length, 1);
  h.at(55);
  await h.timer();
  await h.timer();
  assert.equal(h.db.read(ORDER).status, "ready");
  assert.equal(h.db.read(ORDER).pickupOverdue, true);
  assert.equal(h.db.paths(`${ORDER}/timerEvents/`).length, 2);
  assert.equal(h.db.paths("pharmacies/pharmacy-one/notifications/").length, 2);
  assert.equal(h.db.paths("users/user-one/orderIncidents/").length, 0);
  assert.equal(h.db.read(STOCK).quantity, 9);
  assert.equal(h.db.read(STOCK).reservedQuantity, 0);
});

test("an old revision dialog or user decision cannot replace current consent", async () => {
  const h = setup();
  await firstAcceptance(h);
  const before = [...h.db.documents.entries()];
  await assert.rejects(h.call("revisePartialOffer", {items: items(1), offerVersion: 0}), {code: "aborted"});
  assert.deepEqual([...h.db.documents.entries()], before);
  await h.call("revisePartialOffer", {items: items(1), offerVersion: 1});
  const pending = [...h.db.documents.entries()];
  await assert.rejects(h.call("acceptPartialOffer", {offerVersion: 1}), {code: "aborted"});
  assert.deepEqual([...h.db.documents.entries()], pending);
});

for (const command of ["rejectPartialOffer", "cancelOrder"]) {
  test(`${command} after reopening leaves no active reservation`, async () => {
    const h = setup();
    await firstAcceptance(h);
    h.at(10);
    await h.call("revisePartialOffer", {items: items(1), offerVersion: 1});
    h.at(12);
    await h.call(command, {offerVersion: 2});
    const order = h.db.read(ORDER);
    assert.equal(order.status, "cancelled");
    assert.equal(order.userDecisionWaitMs, 5 * HOUR);
    assert.equal(order.userDecisionStartedAt, null);
    assert.equal(h.db.read(STOCK).reservedQuantity, 0);
    assert.ok(h.db.paths(RESERVATIONS).every((path) => h.db.read(path).state === "released"));
  });
}

test("failed release rolls back the revised offer and all counters", async () => {
  const h = setup();
  await firstAcceptance(h);
  h.db.write(STOCK, {...h.db.read(STOCK), reservedQuantity: 1});
  const before = [...h.db.documents.entries()];
  await assert.rejects(h.call("revisePartialOffer", {items: items(1), offerVersion: 1}),
    {code: "failed-precondition"});
  assert.deepEqual([...h.db.documents.entries()], before);
});

test("invalid revised quantities never release the valid existing reservation", async () => {
  const h = setup();
  await firstAcceptance(h);
  const before = [...h.db.documents.entries()];
  await assert.rejects(h.call("revisePartialOffer", {items: items(4), offerVersion: 1}),
    {code: "invalid-argument"});
  assert.deepEqual([...h.db.documents.entries()], before);
});

test("reopening is forbidden once the invoice is created", async () => {
  const h = setup();
  await firstAcceptance(h);
  await h.call("startPreparing", invoice(2));
  const before = [...h.db.documents.entries()];
  await assert.rejects(h.call("revisePartialOffer", {items: items(1), offerVersion: 1}),
    {code: "failed-precondition"});
  assert.deepEqual([...h.db.documents.entries()], before);
});

test("full confirmation can reopen without colliding with its original reservation ID", async () => {
  const h = setup();
  await h.call("confirmFullOrder");
  const oldId = h.db.read(ORDER).reservationId;
  await h.call("revisePartialOffer", {items: items(2), offerVersion: 0});
  await h.call("acceptPartialOffer", {offerVersion: 1});
  assert.notEqual(h.db.read(ORDER).reservationId, oldId);
  assert.equal(h.db.read(`${RESERVATIONS}${oldId}`).state, "released");
  assert.equal(h.db.read(STOCK).reservedQuantity, 2);
});

test("changed inventory never silently reduces revised accepted quantities", async () => {
  const h = setup();
  await firstAcceptance(h);
  await h.call("revisePartialOffer", {items: items(2), offerVersion: 1});
  h.db.write(STOCK, {...h.db.read(STOCK), quantity: 1});
  const before = [...h.db.documents.entries()];
  await assert.rejects(h.call("acceptPartialOffer", {offerVersion: 2}, "revised-accept-operation"),
    {code: "failed-precondition"});
  assert.deepEqual([...h.db.documents.entries()], before);
  h.db.write(STOCK, {...h.db.read(STOCK), quantity: 3});
  await h.call("acceptPartialOffer", {offerVersion: 2}, "revised-accept-operation");
  assert.equal(h.db.read(STOCK).reservedQuantity, 2);
  assert.equal(h.db.read(ORDER).acceptedOfferVersion, 2);
});
