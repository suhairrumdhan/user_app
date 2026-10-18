"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {delaySummary} = require("../src/domain/admin-delay");
const {project} = require("../src/domain/admin-lists");
const {validPoint, stockState, report} = require("../src/domain/admin-insights");
const {safeSummary} = require("../src/domain/admin-order-summary");
const H = 3600000;
const base = Date.parse("2026-09-01T00:00:00Z");
const event = (status, hours) => ({status, changedAt: new Date(base + hours * H)});
test("34 total hours minus 10 waiting hours crosses 24 exactly and keeps first readiness", () => {
  const order = {status: "ready", readyAt: new Date(base + 34 * H), statusHistory: [
    event("underReview", 0), event("partialOfferPending", 10), event("confirmedReserved", 20), event("ready", 34),
  ]};
  const value = delaySummary(order, base + 34 * H);
  assert.equal(value.pharmacyDelay.processingMs, 24 * H);
  assert.equal(value.pharmacyDelay.occurred, true);
  assert.equal(value.pharmacyDelay.active, false);
  assert.equal(value.userDelay.occurred, false);
  const picked = delaySummary({...order, status: "completed", completedAt: new Date(base + 61 * H)}, base + 70 * H);
  assert.equal(picked.userDelay.overdueMs, 3 * H);
  assert.equal(picked.userDelay.active, false);
  assert.equal(picked.pharmacyDelay.processingMs, 24 * H);
});
test("multiple waiting intervals do not reset processing and partial offers are never pickup delay", () => {
  const order = {status: "preparing", statusHistory: [event("underReview", 0), event("partialOfferPending", 5),
    event("confirmedReserved", 7), event("partialOfferPending", 10), event("confirmedReserved", 13), event("preparing", 20)]};
  assert.equal(delaySummary(order, base + 30 * H).pharmacyDelay.processingMs, 25 * H);
  assert.equal(delaySummary({status: "partialOfferPending", userDecisionDeadline: new Date(base)}, base + 100 * H).userDelay.occurred, false);
});
test("one millisecond before and at the pickup threshold", () => {
  const order = {status: "ready", readyAt: new Date(base)};
  assert.equal(delaySummary(order, base + 24 * H - 1).userDelay.occurred, false);
  assert.equal(delaySummary(order, base + 24 * H).userDelay.occurred, true);
});
test("private user/order fields and spoofed identifiers never enter summaries", () => {
  const row = project("users", "real", {id: "spoof", name: "مستخدم", medicalHistory: "secret", medicines: ["secret"], createdAt: null});
  assert.equal(row.row.id, "real"); assert.equal(row.row.dateUnknown, true);
  assert.equal(row.sortAt, -1); assert.equal(JSON.stringify(row).includes("secret"), false);
  const summary = safeSummary({status: "ready", invoiceId: "private-invoice", user: {name: "secret"}, medicines: [{name: "secret"}]}, "order");
  assert.equal(JSON.stringify(summary).includes("secret"), false);
  assert.equal("invoiceId" in summary, false);
});
test("map bounds reject missing coordinates but accept actual zero", () => {
  for (const value of [null, "", "abc", 999]) assert.equal(validPoint({latitude: value, longitude: 0}), false);
  assert.equal(validPoint({latitude: 0, longitude: 0}), true);
  assert.equal(validPoint({latitude: -90, longitude: 180}), true);
});
test("piece availability is distinct from being hidden or expired", () => {
  const item = {isActive: true, pharmacyVisible: true, availableQuantity: 0, sellByPiece: true, availablePieceQuantity: 2};
  assert.equal(stockState(item, base).out, false);
  assert.equal(stockState({...item, availablePieceQuantity: 0}, base).out, true);
  assert.equal(stockState({...item, availablePieceQuantity: 0, pharmacyVisible: false}, base).out, false);
  assert.equal(stockState({...item, isExpired: true}, base).out, false);
});
test("report cohort of 12 gives 50% completion and 25% cancellation with a full 90-day trend", () => {
  const instant = Date.parse("2026-09-17T12:00:00Z");
  const orders = Array.from({length: 12}, (_, i) => ({id: String(i), createdAt: new Date(instant), status: i < 6 ? "completed" : i < 9 ? "cancelled" : "ready", pharmacyId: "p"}));
  const value = report(orders, [], [], [], 90, instant);
  assert.equal(value.total, 12); assert.equal(value.completionRate, 50); assert.equal(value.cancellationRate, 25);
  assert.equal(value.trend.length, 90);
});
