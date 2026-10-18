"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {Timestamp} = require("firebase-admin/firestore");
const {buildOrderCommandHandler} = require("../../src/domain/order-commands");
const {FakeFirestore} = require("../f03/helpers/fake-firestore");

class HttpsError extends Error { constructor(code, message, details) { super(message); Object.assign(this, {code, details}); } }

function setup() {
  const db = new FakeFirestore({
    "pharmacies/nf07-pharmacy": {status: "approved", isActive: true},
    "orders/nf07-order": {orderId: "nf07-order", schemaVersion: 3, status: "completed", invoiceId: "nf07-invoice", reservationId: "nf07-reservation", reservationState: "consumed", pharmacy: {pharmacyId: "nf07-pharmacy"}, user: {userId: "nf07-user"}},
    "orders/nf07-order/reservations/nf07-reservation": {state: "consumed", items: [{medicineId: "nf07-medicine", quantity: 2, soldByPiece: false}]},
    "pharmacies/nf07-pharmacy/sales/nf07-invoice": {schemaVersion: 3, source: "order", status: "completed", paymentState: "delivered", sourceOrderId: "nf07-order", pharmacyId: "nf07-pharmacy", invoiceId: "nf07-invoice", type: "sale", isSaved: true, isDeleted: false, inventoryPosted: true, reservationConsumed: true, financialPosted: true, cashIn: 20, cardIn: 0, paymentMethod: "cash", invoiceNumber: "NF07", orderId: "nf07-order", creationShiftId: "nf07-shift", collectionShiftId: "nf07-shift", customerShare: 20, companyShare: 0, total: 20, paidAmount: 20, insuranceClaimAmount: 0, insuranceDiscount: 0, createdAt: Timestamp.now(), items: [{medicineId: "nf07-medicine", quantity: 2, unitPrice: 10, sellAsPiece: false}]},
    "pharmacies/nf07-pharmacy/medicines/nf07-medicine": {quantity: 8},
    "pharmacies/nf07-pharmacy/shift_states/owner:nf07-pharmacy": {activeShiftId: "nf07-shift"},
    "pharmacies/nf07-pharmacy/shifts/nf07-shift": {status: "open", pharmacyId: "nf07-pharmacy", openedByKey: "owner:nf07-pharmacy"},
  });
  const handler = buildOrderCommandHandler({db, onCall: fn => fn, HttpsError});
  const refund = (quantity, operationId) => handler({auth: {uid: "nf07-pharmacy"}, data: {schemaVersion: 3, orderId: "nf07-order", command: "refundOrder", operationId, payload: {items: [{medicineId: "nf07-medicine", quantity}], cashOut: quantity * 10, cardOut: 0, shiftId: "nf07-shift", reason: "NF07 return"}}});
  return {db, refund};
}

test("TC-PH-NF07 rejects a refund larger than the remaining sold quantity without extra effects", async () => {
  const {db, refund} = setup();
  await refund(1, "nf07-first-partial-refund");
  const before = [...db.documents.entries()];
  await assert.rejects(refund(2, "nf07-excess-refund"), /remaining sold quantity/);
  assert.deepEqual([...db.documents.entries()], before);
  const invoice = db.read("pharmacies/nf07-pharmacy/sales/nf07-invoice");
  assert.equal(invoice.refundedCustomerAmount, 10);
  assert.notEqual(invoice.refundState, "refunded");
  assert.equal(db.paths("pharmacies/nf07-pharmacy/quarantinedReturns/").length, 1);
});
