"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {Timestamp} = require("firebase-admin/firestore");
const {buildOrderCommandHandler} = require("../../src/domain/order-commands");
const {delaySummary} = require("../../src/domain/admin-delay");
const {FakeFirestore} = require("./helpers/fake-firestore");

test("insurance removal during invoiced replacement quotes new items and preserves old invoice until acceptance", async () => {
  const f = fixture();
  await f.call("startPreparing", f.invoice, "pharmacy");
  f.db.write("pharmacies/pharmacy/medicines/alternative", {name: "Alternative", quantity: 10,
    reservedQuantity: 0, pieceQuantity: 0, reservedPieceQuantity: 0, isActive: true,
    sellingPrice: 30, expiryDate: Timestamp.fromDate(new Date("2099-01-01"))});
  await f.call("proposeReplacementOffer", {offerVersion: 1, reason: "Agreed",
    items: [{medicineId: "alternative", quantity: 2, replacesMedicineId: "med"}]}, "pharmacy");
  await f.call("requestInsuranceRemoval", {reason: "Coverage unavailable"}, "pharmacy");
  assert.equal(f.order().insuranceRemoval.quote.customerTotal, 60);
  await f.call("acceptInsuranceRemoval", {version: 1});
  assert.equal(f.order().partialOffer.quote.customerTotal, 60);
  assert.equal(f.db.read("pharmacies/pharmacy/sales/invoice").paymentState, "pendingDelivery");
  assert.equal(f.db.read("pharmacies/pharmacy/sales/invoice").total, 15);
  await f.call("acceptPartialOffer", {offerVersion: f.order().offerVersion});
  assert.equal(f.db.read("pharmacies/pharmacy/sales/invoice").paymentState, "reversedBeforeDelivery");
  assert.equal(f.db.read("pharmacies/pharmacy/medicines/alternative").reservedQuantity, 2);
});

class HttpsError extends Error { constructor(code, message) { super(message); this.code = code; } }
let sequence = 0;
function fixture(status = "confirmedReserved") {
  let now = Date.parse("2026-09-26T00:00:00Z");
  const timestamp = () => Timestamp.fromMillis(now);
  const quote = {currency: "LYD", items: [{medicineId: "med", soldByPiece: false, quantity: 2, unitPrice: 10, lineTotal: 20}],
    grossTotal: 20, customerTotal: 15, insuranceShare: 5};
  const db = new FakeFirestore({
    "pharmacies/pharmacy": {status: "approved", isActive: true, acceptedInsuranceCodes: ["TEST"]},
    "pharmacies/pharmacy/medicines/med": {quantity: 10, reservedQuantity: 2, sellingPrice: 10,
      pieceQuantity: 0, reservedPieceQuantity: 0, isActive: true, unitsPerPackage: 10,
      expiryDate: Timestamp.fromDate(new Date("2099-01-01"))},
    "pharmacies/pharmacy/insurance_companies/company": {status: "فعال", code: "TEST", discountPercentage: 25},
    "users/user/insurances/card": {companyCode: "TEST", cardNumber: "CARD", startDate: "2020-01-01", endDate: "2099-01-01"},
    "pharmacies/pharmacy/shift_states/owner:pharmacy": {activeShiftId: "shift"},
    "pharmacies/pharmacy/shifts/shift": {status: "open", pharmacyId: "pharmacy", openedByKey: "owner:pharmacy",
      cashTotal: 0, cardTotal: 0, salesCount: 0},
    "orders/order": {schemaVersion: 3, orderId: "order", status,
      user: {userId: "user"}, pharmacy: {pharmacyId: "pharmacy"}, beneficiary: {type: "self"},
      insurance: {enabled: true}, containsInsurance: true,
      insuranceSelection: {companyId: "company", companyCode: "TEST", cardId: "card", cardNumber: "CARD", coveragePercentage: 25},
      medicines: [{matchedMedicineId: "med", quantity: 2}], partialOffer: {version: 1, items: [{medicineId: "med", quantity: 2}], quote},
      offerVersion: 1, acceptedOfferVersion: status === "confirmedReserved" ? 1 : null,
      grossEstimatedTotalPrice: 20, customerEstimatedTotalPrice: 15, estimatedTotalPrice: 15,
      insuranceEstimatedShare: 5, reservationId: status === "confirmedReserved" ? "reservation" : null,
      reservationState: status === "confirmedReserved" ? "active" : null,
      reviewStartedAt: timestamp(), pharmacyReviewActiveMs: 0, statusHistory: []},
    "orders/order/reservations/reservation": {state: "active", items: [{medicineId: "med", quantity: 2, soldByPiece: false}]},
  });
  const handler = buildOrderCommandHandler({db, onCall: (fn) => fn, HttpsError, clock: () => now});
  const call = (command, payload = {}, uid = "user", operationId = `removal-${++sequence}`) => handler({auth: {uid},
    data: {schemaVersion: 3, command, orderId: "order", operationId, payload}});
  const invoice = {invoiceId: "invoice", invoice: {shiftId: "shift", subtotal: 20, discount: 0,
    insuranceDiscount: 5, insuranceCompanyId: "company", total: 15, paymentMethod: "cash",
    items: [{medicineId: "med", quantity: 2, unitPrice: 10, unitCost: 1, sellAsPiece: false}]}};
  return {db, call, invoice, advance: (ms) => { now += ms; }, order: () => db.read("orders/order")};
}

for (const status of ["received", "underReview", "partialOfferPending", "confirmedReserved"]) {
  test(`uninsured consent in ${status} preserves stock and applies only after user consent`, async () => {
    const f = fixture(status);
    const stock = f.db.read("pharmacies/pharmacy/medicines/med");
    await f.call("requestInsuranceRemoval", {reason: "coverage unavailable"}, "pharmacy");
    assert.equal(f.order().insurance.enabled, true);
    assert.equal(f.order().estimatedTotalPrice, 15);
    assert.equal(f.order().insuranceRemoval.quote.customerTotal, 20);
    await assert.rejects(f.call("acceptInsuranceRemoval", {version: 1}, "pharmacy"), {code: "permission-denied"});
    await f.call("acceptInsuranceRemoval", {version: 1});
    assert.equal(f.order().insurance.enabled, false);
    assert.equal(f.order().estimatedTotalPrice, 20);
    assert.equal(f.order().insuranceSelection, null);
    assert.equal(f.order().status, status === "received" ? "underReview" : status);
    assert.deepEqual(f.db.read("pharmacies/pharmacy/medicines/med"), stock);
    if (status === "confirmedReserved") assert.equal(f.order().acceptedOfferVersion, 2);
    if (status === "partialOfferPending") {
      await assert.rejects(f.call("acceptPartialOffer", {offerVersion: 1}), {code: "aborted"});
      await f.call("acceptPartialOffer", {offerVersion: 2});
      assert.equal(f.order().status, "confirmedReserved");
    }
  });
}

test("user may initiate removal, reject it and request a new version", async () => {
  const f = fixture();
  await f.call("requestInsuranceRemoval");
  await f.call("rejectInsuranceRemoval", {version: 1});
  assert.equal(f.order().insurance.enabled, true);
  assert.equal(f.order().estimatedTotalPrice, 15);
  await f.call("requestInsuranceRemoval");
  await assert.rejects(f.call("acceptInsuranceRemoval", {version: 1}), {code: "aborted"});
  await f.call("acceptInsuranceRemoval", {version: 2});
});

for (const invoiceCreated of [false, true]) {
  test(`user can cancel a pending self-pay decision ${invoiceCreated ? "after invoicing" : "after reservation"}`, async () => {
    const f = fixture();
    if (invoiceCreated) await f.call("startPreparing", f.invoice, "pharmacy");
    await f.call("requestInsuranceRemoval", {}, "pharmacy");
    await assert.rejects(f.call("cancelInsuranceRemoval", {version: 1}, "pharmacy"), {code: "permission-denied"});
    const id = `cancel-removal-${++sequence}`;
    await f.call("cancelInsuranceRemoval", {version: 1}, "user", id);
    await f.call("cancelInsuranceRemoval", {version: 1}, "user", id);
    assert.equal(f.order().status, "cancelled");
    assert.equal(f.order().insuranceRemoval.status, "cancelled");
    assert.equal(f.db.read("pharmacies/pharmacy/medicines/med").quantity, 10);
    assert.equal(f.db.read("pharmacies/pharmacy/medicines/med").reservedQuantity, 0);
    if (invoiceCreated) assert.equal(f.db.read("pharmacies/pharmacy/sales/invoice").paymentState, "reversedBeforeDelivery");
    assert.equal(f.db.read("pharmacies/pharmacy/shifts/shift").cashTotal, 0);
  });
}

test("refreshing pending price creates new consent version without restarting waiting time", async () => {
  const f = fixture();
  await f.call("requestInsuranceRemoval");
  f.advance(3600000);
  f.db.write("pharmacies/pharmacy/medicines/med", {...f.db.read("pharmacies/pharmacy/medicines/med"), sellingPrice: 12});
  const requestedAt = f.order().insuranceRemoval.requestedAt.toMillis();
  await f.call("requestInsuranceRemoval", {version: 1});
  assert.equal(f.order().insuranceRemoval.version, 2);
  assert.equal(f.order().insuranceRemoval.quote.customerTotal, 24);
  assert.equal(f.order().insuranceRemoval.requestedAt.toMillis(), requestedAt);
  assert.equal(f.order().insuranceDecisionWaitIntervals.length, 1);
  await assert.rejects(f.call("acceptInsuranceRemoval", {version: 1}), {code: "aborted"});
  await f.call("acceptInsuranceRemoval", {version: 2});
  assert.equal(f.order().estimatedTotalPrice, 24);
});

test("changed price fails atomically; reject and requote restores a working decision", async () => {
  const f = fixture();
  await f.call("requestInsuranceRemoval");
  f.db.write("pharmacies/pharmacy/medicines/med", {...f.db.read("pharmacies/pharmacy/medicines/med"), sellingPrice: 12});
  const before = [...f.db.documents.entries()];
  await assert.rejects(f.call("acceptInsuranceRemoval", {version: 1}), {code: "aborted"});
  assert.deepEqual([...f.db.documents.entries()], before);
  await f.call("rejectInsuranceRemoval", {version: 1});
  await f.call("requestInsuranceRemoval");
  await f.call("acceptInsuranceRemoval", {version: 2});
  assert.equal(f.order().estimatedTotalPrice, 24);
});

test("pending decision blocks preparation and revision but allows user cancellation", async () => {
  const f = fixture();
  await f.call("requestInsuranceRemoval");
  await assert.rejects(f.call("startPreparing", f.invoice, "pharmacy"), /insurance-removal-pending/);
  await assert.rejects(f.call("revisePartialOffer", {offerVersion: 1, items: [{medicineId: "med", quantity: 1}]}, "pharmacy"), /insurance-removal-pending/);
  await f.call("cancelOrder");
  assert.equal(f.order().status, "cancelled");
  assert.equal(f.order().insuranceRemoval.status, "cancelled");
  assert.equal(f.db.read("orders/order/reservations/reservation").state, "released");
  await assert.rejects(f.call("acceptInsuranceRemoval", {version: 1}), {code: "failed-precondition"});
});

for (const ready of [false, true]) {
  test(`uncollected ${ready ? "ready" : "preparing"} invoice changes payer without stock effects and collects once`, async () => {
    const f = fixture();
    await f.call("startPreparing", f.invoice, "pharmacy");
    if (ready) await f.call("markReady", {}, "pharmacy");
    const stock = f.db.read("pharmacies/pharmacy/medicines/med");
    const deadline = f.order().pickupDeadline?.toMillis();
    await f.call("requestInsuranceRemoval", {}, "pharmacy");
    f.advance(3600000);
    await assert.rejects(f.call("completeOrder", {collectionShiftId: "shift"}, "pharmacy"), /insurance-removal-pending/);
    await f.call("acceptInsuranceRemoval", {version: 1});
    const invoice = f.db.read("pharmacies/pharmacy/sales/invoice");
    assert.equal(invoice.total, 20);
    assert.equal(invoice.companyShare, 0);
    assert.equal(invoice.insuranceClaimAmount, 0);
    assert.equal(invoice.financialPosted, false);
    assert.equal(f.order().finalCustomerTotalPrice, 20);
    assert.deepEqual(f.db.read("pharmacies/pharmacy/medicines/med"), stock);
    if (ready) assert.equal(f.order().pickupDeadline.toMillis(), deadline + 3600000);
    else await f.call("markReady", {}, "pharmacy");
    const id = `delivery-${++sequence}`;
    await f.call("completeOrder", {collectionShiftId: "shift"}, "pharmacy", id);
    await f.call("completeOrder", {collectionShiftId: "shift"}, "pharmacy", id);
    assert.equal(f.db.read("pharmacies/pharmacy/shifts/shift").cashTotal, 20);
    assert.equal(f.db.paths("pharmacies/pharmacy/insurance_ledger/").length, 0);
    await assert.rejects(f.call("requestInsuranceRemoval"), {code: "failed-precondition"});
  });
}

test("invoice removal rejection preserves insured invoice and stock", async () => {
  const f = fixture();
  await f.call("startPreparing", f.invoice, "pharmacy");
  const invoice = f.db.read("pharmacies/pharmacy/sales/invoice");
  await f.call("requestInsuranceRemoval", {}, "pharmacy");
  await f.call("rejectInsuranceRemoval", {version: 1});
  assert.deepEqual(f.db.read("pharmacies/pharmacy/sales/invoice"), invoice);
  assert.equal(f.order().insurance.enabled, true);
  await f.call("markReady", {}, "pharmacy");
});

test("already financially posted invoice cannot be repriced", async () => {
  const f = fixture();
  await f.call("startPreparing", f.invoice, "pharmacy");
  f.db.write("pharmacies/pharmacy/sales/invoice", {...f.db.read("pharmacies/pharmacy/sales/invoice"), paidAmount: 15});
  const before = [...f.db.documents.entries()];
  await assert.rejects(f.call("requestInsuranceRemoval", {}, "pharmacy"), {code: "failed-precondition"});
  assert.deepEqual([...f.db.documents.entries()], before);
});

test("converted invoice cancellation restores consumed stock without an insurer claim", async () => {
  const f = fixture();
  await f.call("startPreparing", f.invoice, "pharmacy");
  await f.call("requestInsuranceRemoval", {}, "pharmacy");
  await f.call("acceptInsuranceRemoval", {version: 1});
  await f.call("cancelAfterInvoice", {reason: "customer cancelled"}, "pharmacy");
  assert.equal(f.order().status, "cancelled");
  assert.equal(f.db.read("pharmacies/pharmacy/medicines/med").quantity, 10);
  assert.equal(f.db.read("pharmacies/pharmacy/shifts/shift").cashTotal, 0);
  assert.equal(f.db.paths("pharmacies/pharmacy/insurance_ledger/").length, 0);
});

test("converted delivered refund returns only the uninsured customer's payment", async () => {
  const f = fixture();
  await f.call("startPreparing", f.invoice, "pharmacy");
  await f.call("requestInsuranceRemoval", {}, "pharmacy");
  await f.call("acceptInsuranceRemoval", {version: 1});
  await f.call("markReady", {}, "pharmacy");
  await f.call("completeOrder", {collectionShiftId: "shift"}, "pharmacy");
  const result = await f.call("refundOrder", {items: [{medicineId: "med", quantity: 2}],
    cashOut: 20, cardOut: 0, shiftId: "shift", reason: "returned"}, "pharmacy");
  assert.equal(result.result.customerRefund, 20);
  assert.equal(result.result.insuranceDueReduction, 0);
  assert.equal(result.result.insuranceCredit, 0);
  assert.equal(f.db.read("pharmacies/pharmacy/sales/invoice").refundedCustomerAmount, 20);
});

test("unrelated caller cannot request or accept, replay does not duplicate notices", async () => {
  const f = fixture();
  await assert.rejects(f.call("requestInsuranceRemoval", {}, "outsider"), {code: "permission-denied"});
  const id = `request-${++sequence}`;
  await f.call("requestInsuranceRemoval", {}, "pharmacy", id);
  await f.call("requestInsuranceRemoval", {}, "pharmacy", id);
  assert.equal(f.db.paths("users/user/notifications/").length, 1);
  await assert.rejects(f.call("requestInsuranceRemoval"), {code: "failed-precondition"});
  await assert.rejects(f.call("acceptInsuranceRemoval", {version: 1}, "outsider"), {code: "permission-denied"});
});

test("insurance removal notifications address each recipient and only the user decides", async () => {
  const f = fixture();
  await f.call("requestInsuranceRemoval", {}, "pharmacy");
  const notices = (role) => f.db.paths(`${role}/${role === "users" ? "user" : "pharmacy"}/notifications/`)
    .map((path) => f.db.read(path));
  const user = notices("users")[0];
  const pharmacy = notices("pharmacies")[0];
  assert.equal(user.recipientRole, "user");
  assert.equal(user.recipientId, "user");
  assert.equal(user.isActionable, true);
  assert.match(user.message, /المبلغ عليك/);
  assert.equal(pharmacy.recipientRole, "pharmacy");
  assert.equal(pharmacy.isActionable, false);
  assert.match(pharmacy.message, /بانتظار موافقة المستخدم/);
  assert.doesNotMatch(pharmacy.message, /المبلغ عليك/);
  await f.call("acceptInsuranceRemoval", {version: 1});
  const acceptedUser = notices("users").find((n) => n.message.includes("موافقتك"));
  const acceptedPharmacy = notices("pharmacies").find((n) => n.message.includes("وافق المستخدم"));
  assert.equal(acceptedUser.isActionable, false);
  assert.equal(acceptedPharmacy.isActionable, true);
});

test("coverage decision waits are excluded from processing history and pickup alerts", () => {
  const hour = 3600000;
  const start = Date.parse("2026-09-01T00:00:00Z");
  const order = {status: "underReview", statusHistory: [{status: "underReview", changedAt: new Date(start)}],
    insuranceDecisionWaitIntervals: [{start: new Date(start + hour), end: new Date(start + 10 * hour)}]};
  assert.equal(delaySummary(order, start + 25 * hour).pharmacyDelay.processingMs, 16 * hour);
  const pickup = {status: "ready", firstReadyAt: new Date(start), pickupDeadline: new Date(start + 25 * hour),
    insuranceRemoval: {status: "pending"}, insuranceDecisionWaitIntervals: [{start: new Date(start + hour), end: null}]};
  assert.equal(delaySummary(pickup, start + 30 * hour).userDelay.active, false);
});
