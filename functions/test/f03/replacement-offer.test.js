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
test("replacement snapshots stock identity and reserves only after consent", async () => {
  const h=setup(); const payload=replacement(h);
  await h.call("proposeReplacementOffer", payload);
  const pending=h.db.read(ORDER);
  assert.equal(pending.partialOffer.kind, "replacement");
  assert.equal(pending.partialOffer.items[0].medicineName, "Alternative");
  assert.equal(pending.partialOffer.items[0].imageUrl, "https://example.test/alt.png");
  assert.equal(pending.partialOffer.items[0].originalMedicineName, "Drug");
  assert.equal(pending.partialOffer.quote.customerTotal, 30);
  assert.equal(h.db.read(ALT).reservedQuantity, 0);
  await h.call("acceptPartialOffer", {offerVersion: 1});
  assert.equal(h.db.read(ALT).reservedQuantity, 2);
  assert.equal(h.db.read(STOCK).reservedQuantity, 0);
  assert.equal(h.db.read(ORDER).medicines[0].matchedMedicineId, "medicine-a");
});
test("replacement releases existing reservation and rejects stale proposals", async () => {
  const h=setup(); await firstAcceptance(h);
  await h.call("proposeReplacementOffer", replacement(h, 1));
  assert.equal(h.db.read(STOCK).reservedQuantity, 0);
  await assert.rejects(h.call("proposeReplacementOffer", replacement(h, 1)), {code: "aborted"});
  await h.call("acceptPartialOffer", {offerVersion: 2});
  assert.equal(h.db.read(ALT).reservedQuantity, 2);
});
for (const invalid of ["source", "duplicate", "reason", "no-change", "unit"]) test(`invalid replacement ${invalid} is atomic`, async () => {
  const h=setup(); const payload=replacement(h);
  if (invalid === "source") payload.items[0].replacesMedicineId="unknown";
  if (invalid === "duplicate") payload.items.push({...payload.items[0]});
  if (invalid === "reason") payload.reason="";
  if (invalid === "no-change") payload.items[0].medicineId="medicine-a";
  if (invalid === "unit") payload.items[0].replacesSoldByPiece=true;
  await assert.rejects(h.call("proposeReplacementOffer", payload), {code: "invalid-argument"});
  assert.equal(h.db.read(ORDER).status, "underReview");
  assert.equal(h.db.read(ALT).reservedQuantity, 0);
});
for (const decision of ["acceptPartialOffer"]) test(`invoiced replacement ${decision} reverses only at decision`, async () => {
  const h=setup(); await firstAcceptance(h); await h.call("startPreparing", invoice(2));
  const old=h.db.read(ORDER).invoiceId;
  await h.call("proposeReplacementOffer", replacement(h, 1));
  assert.equal(h.db.read(STOCK).quantity, 8);
  assert.equal(h.db.read(ORDER).invoiceId, old);
  assert.equal(h.db.read(`pharmacies/pharmacy-one/sales/${old}`).paymentState, "pendingDelivery");
  await h.call(decision, {offerVersion: 2});
  assert.equal(h.db.read(STOCK).quantity, 10);
  assert.equal(h.db.read(`pharmacies/pharmacy-one/sales/${old}`).paymentState, "reversedBeforeDelivery");
  if (decision === "acceptPartialOffer") {
    assert.equal(h.db.read(ORDER).invoiceId, null);
    assert.equal(h.db.read(ORDER).invoiceGeneration, 1);
    assert.equal(h.db.read(ALT).reservedQuantity, 2);
    const next=invoice(2); next.invoiceId="order-order-one-replacement-1";
    next.invoice.items=[{medicineId: "medicine-b", name: "Alternative", quantity: 2, unitPrice: 15, unitCost: 4}];
    next.invoice.subtotal=30; next.invoice.total=30;
    await h.call("startPreparing", next);
    assert.equal(h.db.read(ALT).quantity, 8);
    await h.call("cancelAfterInvoice", {reason: "Cancel"});
    assert.equal(h.db.read(ALT).quantity, 10);
    assert.ok(h.db.read("pharmacies/pharmacy-one/sales/order-reversal-order-one-invoice-1"));
  } else {
    assert.equal(h.db.read(ORDER).status, "cancelled");
    assert.equal(h.db.read(ALT).reservedQuantity, 0);
  }
});
test("out of stock acceptance preserves the old invoice and all quantities", async () => {
  const h=setup(); await firstAcceptance(h); await h.call("startPreparing", invoice(2));
  await h.call("proposeReplacementOffer", replacement(h,1));
  h.db.write(ALT, {...h.db.read(ALT), quantity: 0});
  await assert.rejects(h.call("acceptPartialOffer", {offerVersion:2}));
  assert.equal(h.db.read(STOCK).quantity,8);
  assert.equal(h.db.read(ORDER).invoiceId,"invoice-one");
  assert.equal(h.db.paths("pharmacies/pharmacy-one/sales/order-reversal").length,0);
});

test("ready replacement starts a fresh fulfillment cycle with a new pickup deadline", async () => {
  const h = setup(); await firstAcceptance(h); await h.call("startPreparing", invoice(2));
  await h.call("markReady"); const oldDeadline = h.db.read(ORDER).pickupDeadline;
  h.at(10); await h.call("proposeReplacementOffer", replacement(h, 1));
  await h.call("acceptPartialOffer", {offerVersion: 2});
  assert.equal(h.db.read(ORDER).firstReadyAt, null);
  assert.equal(h.db.read(ORDER).pickupDeadline, null);
  assert.equal(h.db.read(ORDER).invoiceRevisions.length, 1);
  const next = invoice(2); next.invoiceId = "order-order-one-replacement-1";
  next.invoice.items = [{medicineId: "medicine-b", quantity: 2, unitPrice: 15, unitCost: 4}];
  next.invoice.subtotal = 30; next.invoice.total = 30;
  await h.call("startPreparing", next); h.at(12); await h.call("markReady");
  assert.ok(h.db.read(ORDER).pickupDeadline.toMillis() > oldDeadline.toMillis());
});

test("piece replacement, price changes and foreign callers are validated", async () => {
  const h = setup(); const payload = replacement(h);
  h.db.write(ALT, {...h.db.read(ALT), sellByPiece: true, unitsPerPackage: 10, piecePrice: 2});
  payload.items[0].soldByPiece = true; payload.items[0].quantity = 5;
  await assert.rejects(h.call("proposeReplacementOffer", payload, undefined, "stranger"), {code: "permission-denied"});
  await h.call("proposeReplacementOffer", payload);
  assert.equal(h.db.read(ORDER).partialOffer.quote.customerTotal, 10);
  h.db.write(ALT, {...h.db.read(ALT), piecePrice: 3});
  await assert.rejects(h.call("acceptPartialOffer", {offerVersion: 1}), {code: "aborted"});
  assert.equal(h.db.read(ALT).reservedQuantity, 0);
  assert.equal(h.db.read(ALT).reservedPieceQuantity, 0);
});

test("completed order never accepts a replacement proposal", async () => {
  const h = setup(); const payload = replacement(h);
  h.db.write(ORDER, {...h.db.read(ORDER), status: "completed"});
  await assert.rejects(h.call("proposeReplacementOffer", payload));
  assert.equal(h.db.read(ORDER).status, "completed");
});

for (const status of ["preparing", "ready"]) test(`rejecting an invoiced ${status} replacement preserves the original invoice and stock`, async () => {
  const h = setup(); await firstAcceptance(h); await h.call("startPreparing", invoice(2));
  if (status === "ready") await h.call("markReady");
  const original = h.db.read(ORDER);
  await h.call("proposeReplacementOffer", replacement(h, 1));
  await assert.rejects(h.call("cancelOrder"), {code: "failed-precondition"});
  assert.equal(h.db.read(ORDER).status, "partialOfferPending");
  await h.call("rejectPartialOffer", {offerVersion: 2});
  assert.equal(h.db.read(ORDER).status, status);
  assert.equal(h.db.read(ORDER).invoiceId, original.invoiceId);
  assert.equal(h.db.read(STOCK).quantity, 8);
  assert.equal(h.db.read(ALT).reservedQuantity, 0);
  assert.equal(h.db.read(`pharmacies/pharmacy-one/sales/${original.invoiceId}`).paymentState, "pendingDelivery");
  assert.equal(h.db.read(ORDER).partialOffer.items[0].medicineId, original.partialOffer.items[0].medicineId);
  assert.equal(h.db.read(ORDER).acceptedOfferVersion, 2);
  if (status === "ready") assert.deepEqual(h.db.read(ORDER).pickupDeadline, original.pickupDeadline);
  assert.equal(h.db.paths("pharmacies/pharmacy-one/sales/order-reversal").length, 0);
});

test("revising an invoiced replacement preserves the original ready cycle on rejection", async () => {
  const h = setup(); await firstAcceptance(h); await h.call("startPreparing", invoice(2)); await h.call("markReady");
  const original = h.db.read(ORDER);
  await h.call("proposeReplacementOffer", replacement(h, 1));
  await h.call("proposeReplacementOffer", replacement(h, 2));
  await assert.rejects(h.call("rejectPartialOffer", {offerVersion: 2}), {code: "aborted"});
  await h.call("rejectPartialOffer", {offerVersion: 3});
  assert.equal(h.db.read(ORDER).status, "ready");
  assert.equal(h.db.read(ORDER).invoiceId, original.invoiceId);
  assert.deepEqual(h.db.read(ORDER).pickupDeadline, original.pickupDeadline);
  assert.equal(h.db.read(ORDER).partialOffer.items[0].medicineId, original.partialOffer.items[0].medicineId);
});

test("rejecting an invoiced replacement waits for a pending insurance decision", async () => {
  const h = setup(); await firstAcceptance(h); await h.call("startPreparing", invoice(2));
  await h.call("proposeReplacementOffer", replacement(h, 1));
  h.db.write(ORDER, {...h.db.read(ORDER), insuranceRemoval: {status: "pending", version: 1}});
  await assert.rejects(h.call("rejectPartialOffer", {offerVersion: 2}), {code: "failed-precondition"});
  assert.equal(h.db.read(ORDER).status, "partialOfferPending");
  assert.equal(h.db.read(ORDER).insuranceRemoval.status, "pending");
  assert.equal(h.db.read(STOCK).quantity, 8);
});
