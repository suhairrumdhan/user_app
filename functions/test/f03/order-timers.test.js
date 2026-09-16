"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {Timestamp} = require("firebase-admin/firestore");
const {timerState, processOrderTimer} = require("../../src/domain/order-timers");
const {FakeFirestore} = require("./helpers/fake-firestore");
const HOUR = 60 * 60 * 1000;
const START = Date.UTC(2026, 8, 14, 8);
const ts = (hours) => Timestamp.fromMillis(START + hours * HOUR);

function setup(overrides = {}) {
  const order = {orderId: "one", status: "underReview", pharmacy: {pharmacyId: "pharmacy"},
    user: {userId: "user"}, reviewStartedAt: ts(0), pharmacyReviewActiveMs: 0, ...overrides};
  const db = new FakeFirestore({"orders/one": order,
    "pharmacies/pharmacy/medicines/medicine": {quantity: 10, reservedQuantity: 2},
    "pharmacies/pharmacy/sales/invoice": {paymentState: "pendingDelivery", paidAmount: 0},
  });
  const run = (hours) => processOrderTimer({db, orderId: "one", clock: () => START + hours * HOUR});
  return {db, run};
}

test("review is delayed at exactly 24 hours, not one millisecond before", async () => {
  const {db, run} = setup();
  await run(24 - 1 / HOUR);
  assert.equal(db.read("orders/one").pharmacyDelayed, undefined);
  await run(24);
  assert.equal(db.read("orders/one").pharmacyDelayed, true);
  assert.equal(db.read("orders/one").status, "underReview");
  assert.equal(db.paths("pharmacies/pharmacy/notifications/").length, 1);
});

test("decision waits are excluded even when a stale review-start field remains", () => {
  const state = timerState({status: "partialOfferPending", reviewStartedAt: ts(0),
    pharmacyReviewActiveMs: 2 * HOUR}, START + 50 * HOUR);
  assert.equal(state.activeMs, 2 * HOUR);
  assert.equal(state.pharmacyDelayed, false);
});

test("documented two waiting periods leave 26 hours of review at readiness", () => {
  // 08-10 = 2h, 13-18 = 5h, 20-next day 15 = 19h; waiting totals 5h.
  const active = timerState({status: "preparing", pharmacyReviewActiveMs: 7 * HOUR,
    reviewStartedAt: ts(12)}, START + 31 * HOUR);
  assert.equal(active.activeMs, 26 * HOUR);
  assert.equal(active.pharmacyDelayed, true);
});

test("repeated scans preserve notification read/deleted flags and timestamp", async () => {
  const {db, run} = setup();
  await run(24);
  const path = "pharmacies/pharmacy/notifications/timer_review_one";
  const read = {...db.read(path), isRead: true, isDeleted: true};
  db.write(path, read);
  await run(48);
  assert.deepEqual(db.read(path), read);
  assert.equal(db.paths("orders/one/timerEvents/").length, 1);
  assert.equal(db.read("orders/one").pharmacyReviewActiveMs, 0);
});

test("pickup deadline creates alerts but no cancellation, reversal, stock change or incident", async () => {
  const {db, run} = setup({status: "ready", reviewStartedAt: null, readyAt: ts(1), pickupDeadline: ts(25)});
  const stock = db.read("pharmacies/pharmacy/medicines/medicine");
  const invoice = db.read("pharmacies/pharmacy/sales/invoice");
  await run(25 - 1 / HOUR);
  assert.equal(db.read("orders/one").pickupOverdue, undefined);
  await run(25);
  await run(50);
  assert.equal(db.read("orders/one").pickupOverdue, true);
  assert.equal(db.read("orders/one").status, "ready");
  assert.deepEqual(db.read("pharmacies/pharmacy/medicines/medicine"), stock);
  assert.deepEqual(db.read("pharmacies/pharmacy/sales/invoice"), invoice);
  assert.equal(db.paths("users/user/notifications/").length, 1);
  assert.equal(db.paths("pharmacies/pharmacy/notifications/").length, 1);
  assert.equal(db.paths("orders/one/timerEvents/").length, 1);
  assert.equal(db.paths("users/user/orderIncidents/").length, 0);
});

test("terminal status reread wins over an earlier scan candidate", async () => {
  for (const status of ["completed", "cancelled", "notCollected", "rejected"]) {
    const {db, run} = setup({status, readyAt: ts(1), pickupDeadline: ts(25)});
    const before = [...db.documents.entries()];
    await run(50);
    assert.deepEqual([...db.documents.entries()], before);
  }
});

test("invalid or absent deadline never creates a pickup alert", async () => {
  const {db, run} = setup({status: "ready", reviewStartedAt: null, pickupDeadline: "invalid"});
  await run(100);
  assert.equal(db.read("orders/one").pickupOverdue, undefined);
  assert.equal(db.paths("users/user/notifications/").length, 0);
});
