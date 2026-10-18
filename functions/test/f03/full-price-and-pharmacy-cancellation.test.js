"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {Timestamp} = require("firebase-admin/firestore");
const {buildOrderCommandHandler} = require("../../src/domain/order-commands");
const {processOrderTimer} = require("../../src/domain/order-timers");
const {FakeFirestore} = require("./helpers/fake-firestore");
const {seedEmployeeSession} = require("./helpers/employee-session");

const HOUR = 60 * 60 * 1000;
const START = Date.UTC(2026, 8, 14, 8);
const ORDER = "orders/order-one";
const STOCK = "pharmacies/pharmacy-one/medicines/medicine-a";

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
    "pharmacies/pharmacy-one": {status: "approved", isActive: true},
    "pharmacies/pharmacy": {status: "approved", isActive: true},
    [ORDER]: {schemaVersion: 3, orderId: "order-one", orderNumber: "TEST-ONE",
      status: "underReview", statusHistory: [], user: {userId: "user-one"},
      pharmacy: {pharmacyId: "pharmacy-one"}, insurance: {enabled: false},
      medicines: [{matchedMedicineId: "medicine-a", matchedMedicineName: "Drug", quantity: 3}],
      offerVersion: 0, reservationId: null, pharmacyReviewActiveMs: 0,
      reviewStartedAt: Timestamp.fromMillis(START)},
    [STOCK]: {quantity: 10, reservedQuantity: 0, pieceQuantity: 0,
      reservedPieceQuantity: 0, isActive: true,
      sellingPrice: 10,
      expiryDate: Timestamp.fromDate(new Date("2099-01-01T00:00:00Z"))},
    "pharmacies/pharmacy-one/shift_states/owner:pharmacy-one": {activeShiftId: "shift-one"},
    "pharmacies/pharmacy-one/shifts/shift-one": {status: "open", pharmacyId: "pharmacy-one", openedByKey: "owner:pharmacy-one", cashTotal: 0,
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


const ALT = "pharmacies/pharmacy-one/medicines/medicine-b";
function replacement(h, version = 0) {
  h.db.write(ALT, {name: "Alternative", imageUrl: "https://example.test/alt.png", scientificName: "Ingredient", quantity: 10, reservedQuantity: 0, pieceQuantity: 0, reservedPieceQuantity: 0, isActive: true, sellingPrice: 15, expiryDate: Timestamp.fromDate(new Date("2099-01-01"))});
  return {offerVersion: version, reason: "Agreed in chat", items: [{medicineId: "medicine-b", quantity: 2, soldByPiece: false, replacesMedicineId: "medicine-a", replacesSoldByPiece: false, medicineName: "Forged"}]};
}

test("full price proposal reserves only after user consent and enforces the agreed ceiling", async () => {
  const h = setup(); await h.call("proposeFullOffer", {offerVersion: 0});
  assert.equal(h.db.read(ORDER).partialOffer.kind, "full");
  assert.equal(h.db.read(ORDER).partialOffer.quote.customerTotal, 30);
  assert.equal(h.db.read(STOCK).reservedQuantity, 0);
  await h.call("acceptPartialOffer", {offerVersion: 1});
  assert.equal(h.db.read(STOCK).reservedQuantity, 3);
  const input = invoice(3); input.invoice.total = 33; input.invoice.subtotal = 33; input.invoice.items[0].unitPrice = 11;
  await assert.rejects(h.call("startPreparing", input), {code: "aborted"});
  await h.call("startPreparing", invoice(3));
  assert.equal(h.db.read(ORDER).status, "preparing");
});
test("legacy full confirmation needs consent when the price exceeds submitted total", async () => {
  const h = setup(); h.db.write(ORDER, {...h.db.read(ORDER), estimatedTotalPrice: 20});
  await h.call("confirmFullOrder");
  assert.equal(h.db.read(ORDER).status, "partialOfferPending");
  assert.equal(h.db.read(STOCK).reservedQuantity, 0);
  await h.call("acceptPartialOffer", {offerVersion: 1});
  assert.equal(h.db.read(STOCK).reservedQuantity, 3);
});
test("unchanged legacy confirmation captures a quote and blocks a later invoice increase", async () => {
  const h = setup(); h.db.write(ORDER, {...h.db.read(ORDER), estimatedTotalPrice: 30});
  await h.call("confirmFullOrder");
  assert.equal(h.db.read(ORDER).status, "confirmedReserved");
  assert.equal(h.db.read(ORDER).fullOrderQuote.customerTotal, 30);
  const input = invoice(3); input.invoice.total = 33; input.invoice.subtotal = 33; input.invoice.items[0].unitPrice = 11;
  await assert.rejects(h.call("startPreparing", input), {code: "aborted"});
});

test("legacy reserved order with unknown price requires a quote before invoicing", async () => {
  const h = setup(); h.db.write(ORDER, {...h.db.read(ORDER), estimatedTotalPrice: 30});
  await h.call("confirmFullOrder");
  const order = h.db.read(ORDER); delete order.fullOrderQuote; delete order.estimatedTotalPrice; delete order.customerEstimatedTotalPrice;
  h.db.write(ORDER, order);
  await assert.rejects(h.call("startPreparing", invoice(3)), {code: "aborted"});
  assert.equal(h.db.read(STOCK).reservedQuantity, 3);
  await h.call("proposeFullOffer", {offerVersion: 0});
  await h.call("acceptPartialOffer", {offerVersion: 1});
  await h.call("startPreparing", invoice(3));
  assert.equal(h.db.read(ORDER).status, "preparing");
});
test("full quote price change fails acceptance atomically and a revision requires new consent", async () => {
  const h = setup(); await h.call("proposeFullOffer", {offerVersion: 0});
  h.db.write(STOCK, {...h.db.read(STOCK), sellingPrice: 15});
  await assert.rejects(h.call("acceptPartialOffer", {offerVersion: 1}), {code: "aborted"});
  assert.equal(h.db.read(STOCK).reservedQuantity, 0);
  await h.call("proposeFullOffer", {offerVersion: 1});
  await assert.rejects(h.call("acceptPartialOffer", {offerVersion: 1}), {code: "aborted"});
  await h.call("acceptPartialOffer", {offerVersion: 2});
  assert.equal(h.db.read(ORDER).estimatedTotalPrice, 45);
});
test("pharmacy cancels pending replacement with one reversal and releases original invoice stock", async () => {
  const h = setup(); await firstAcceptance(h); await h.call("startPreparing", invoice(2));
  await h.call("proposeReplacementOffer", replacement(h, 1));
  const payload = {offerVersion: 2, reason: "Alternative unavailable"};
  await assert.rejects(h.call("cancelPendingReplacement", {...payload, offerVersion: 1}), {code: "aborted"});
  await assert.rejects(h.call("cancelPendingReplacement", payload, undefined, "user-one"), {code: "failed-precondition"});
  await h.call("cancelPendingReplacement", payload, "cancel-replacement-once");
  await h.call("cancelPendingReplacement", payload, "cancel-replacement-once");
  assert.equal(h.db.read(ORDER).status, "cancelled");
  assert.equal(h.db.read(STOCK).quantity, 10);
  assert.equal(h.db.read(ALT).reservedQuantity, 0);
  assert.equal(h.db.read(ORDER).userDecisionDeadline, null);
  assert.equal(h.db.paths("pharmacies/pharmacy-one/sales/order-reversal-").length, 1);
});
test("pharmacy cancellation cannot target a full offer or replace a missing invoice", async () => {
  const h = setup(); await h.call("proposeFullOffer", {offerVersion: 0});
  await assert.rejects(h.call("cancelPendingReplacement", {offerVersion: 1, reason: "Cancel"}), {code: "failed-precondition"});
  assert.equal(h.db.read(ORDER).status, "partialOfferPending");
});

test("pending replacement cancellation requires employee refund permission", async () => {
  const h = setup(); await firstAcceptance(h); await h.call("startPreparing", invoice(2));
  await h.call("proposeReplacementOffer", replacement(h, 1));
  const auth = seedEmployeeSession(h.db, "pharmacy-one", "staff", {isActive: true,
    permissions: {"orders.update_status": true}});
  const handler = buildOrderCommandHandler({db: h.db, HttpsError: HttpError, onCall: (fn) => fn, clock: () => START + 5 * HOUR});
  const request = {auth, data: {schemaVersion: 3, orderId: "order-one", command: "cancelPendingReplacement",
    operationId: "staff-cancel-no-refund-permission", payload: {offerVersion: 2, reason: "Cancel"}}};
  await assert.rejects(handler(request), {code: "permission-denied"});
  assert.equal(h.db.read(ORDER).status, "partialOfferPending");
  assert.equal(h.db.read(STOCK).quantity, 8);
  seedEmployeeSession(h.db, "pharmacy-one", "staff", {isActive: true,
    permissions: {"orders.update_status": true, "sales.refund": true}});
  request.data.operationId = "staff-cancel-with-refund-permission";
  await handler(request);
  assert.equal(h.db.read(ORDER).status, "cancelled");
  assert.equal(h.db.read(STOCK).quantity, 10);
});
