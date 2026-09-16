"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {Timestamp} = require("firebase-admin/firestore");
const {buildOrderCommandHandler} = require("../../src/domain/order-commands");
const {FakeFirestore} = require("./helpers/fake-firestore");
const {seedEmployeeSession} = require("./helpers/employee-session");

class HttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    Object.assign(this, {code, details});
  }
}

function setup() {
  const db = new FakeFirestore({
    "orders/order": {orderId: "order", schemaVersion: 3, status: "completed", invoiceId: "invoice",
      reservationId: "reservation", reservationState: "consumed",
      pharmacy: {pharmacyId: "pharmacy"}, user: {userId: "user"}},
    "orders/order/reservations/reservation": {state: "consumed",
      items: [{medicineId: "medicine", quantity: 2, soldByPiece: false}]},
    "pharmacies/pharmacy/sales/invoice": {
      schemaVersion: 3, source: "order", status: "completed", paymentState: "delivered",
      sourceOrderId: "order", pharmacyId: "pharmacy", invoiceId: "invoice",
      type: "sale", isSaved: true, isDeleted: false, inventoryPosted: true, reservationConsumed: true,
      financialPosted: true, cashIn: 30, cardIn: 0, paymentMethod: "cash",
      invoiceNumber: "INV", orderId: "order", creationShiftId: "shift-a", collectionShiftId: "shift-b",
      customerShare: 30, companyShare: 70, total: 30, paidAmount: 30, insuranceClaimAmount: 70,
      insuranceCompanyId: "company", insuranceDiscount: 70, createdAt: Timestamp.now(),
      items: [{medicineId: "medicine", quantity: 2, unitPrice: 50, sellAsPiece: false}],
    },
    "pharmacies/pharmacy/insurance_companies/company": {name: "Company", totalClaims: 70, currentReceivable: 70},
    "pharmacies/pharmacy/medicines/medicine": {quantity: 8},
    "pharmacies/pharmacy/shifts/shift-c": {status: "open"},
  });
  const handler = buildOrderCommandHandler({db, onCall: (fn) => fn, HttpsError});
  const call = (command, payload, operationId, uid = "pharmacy") => handler({
    auth: {uid}, data: {schemaVersion: 3, orderId: "order", command, operationId, payload},
  });
  return {db, call};
}

function refund(quantity = 2, cashOut = 30) {
  return {items: [{medicineId: "medicine", quantity}], cashOut, cardOut: 0, shiftId: "shift-c", reason: "Returned by customer"};
}

function collection(amount = 70) {
  return {pharmacyId: "pharmacy", companyId: "company", amount, paymentMethod: "bank", collectionYear: 2026, collectionMonth: 9};
}

for (const variant of ["foreign-order", "pos-source", "unconsumed-reservation", "excess-items", "unpaid-invoice"]) {
  test(`refund rejects ${variant} without stock financial or order changes`, async () => {
    const {db, call} = setup();
    const path = "pharmacies/pharmacy/sales/invoice";
    const invoice = db.read(path);
    if (variant === "foreign-order") invoice.orderId = "other";
    if (variant === "pos-source") invoice.source = "pos";
    if (variant === "excess-items") invoice.items[0].quantity = 3;
    if (variant === "unpaid-invoice") invoice.paidAmount = 0;
    db.write(path, invoice);
    if (variant === "unconsumed-reservation") db.write("orders/order/reservations/reservation", {
      ...db.read("orders/order/reservations/reservation"), state: "active",
    });
    const before = [...db.documents.entries()];
    await assert.rejects(call("refundOrder", refund(), `invalid-${variant}`), {code: "failed-precondition"});
    assert.deepEqual([...db.documents.entries()], before);
  });
}

test("unpaid insurance refund reduces the claim and refunds only the customer paid share once", async () => {
  const {db, call} = setup();
  const first = await call("refundOrder", refund(), "refund-unpaid-fixed");
  assert.deepEqual(await call("refundOrder", refund(), "refund-unpaid-fixed"), first);
  assert.equal(first.result.customerRefund, 30);
  assert.equal(first.result.insuranceDueReduction, 70);
  assert.equal(first.result.insuranceCredit, 0);
  assert.equal(db.read("pharmacies/pharmacy/insurance_companies/company").currentReceivable, 0);
  assert.equal(db.read("pharmacies/pharmacy/medicines/medicine").quantity, 8);
  assert.equal(db.paths("pharmacies/pharmacy/quarantinedReturns/").length, 1);
  assert.equal(db.read("orders/order").status, "completed");
  await assert.rejects(call("refundOrder", refund(), "refund-again-invalid"), /remaining sold quantity/);
});

test("paid insurance refund preserves the receipt and creates company credit", async () => {
  const {db, call} = setup();
  const receipt = await call("collectInsurancePayment", collection(), "insurance-collection-fixed");
  assert.deepEqual(await call("collectInsurancePayment", collection(), "insurance-collection-fixed"), receipt);
  const receiptPath = `pharmacies/pharmacy/insurance_collections/${receipt.result.collectionId}`;
  const before = db.read(receiptPath);
  const result = await call("refundOrder", refund(), "refund-paid-fixed");
  assert.equal(result.result.insuranceDueReduction, 0);
  assert.equal(result.result.insuranceCredit, 70);
  assert.deepEqual(db.read(receiptPath), before);
  const company = db.read("pharmacies/pharmacy/insurance_companies/company");
  assert.equal(company.totalCollected, 70);
  assert.equal(company.creditBalance, 70);
  assert.equal(company.currentReceivable, 0);
  const invoice = db.read("pharmacies/pharmacy/sales/invoice");
  assert.equal(invoice.creationShiftId, "shift-a");
  assert.equal(invoice.collectionShiftId, "shift-b");
  const refundShift = db.read("pharmacies/pharmacy/shifts/shift-c");
  assert.equal(refundShift.cashRefunds, 30);
  assert.equal(refundShift.cardRefunds, 0);
  assert.equal(refundShift.insuranceRefunds, 70);
  assert.equal(refundShift.refundsCount, 1);
});

test("partial refunds and intervening insurer collection never over-refund either payer", async () => {
  const {db, call} = setup();
  await call("refundOrder", refund(1, 15), "partial-refund-first");
  const receipt = await call("collectInsurancePayment", collection(35), "partial-insurance-collection");
  assert.equal(receipt.result.newReceivable, 0);
  const last = await call("refundOrder", refund(1, 15), "partial-refund-second");
  assert.equal(last.result.insuranceCredit, 35);
  const invoice = db.read("pharmacies/pharmacy/sales/invoice");
  assert.equal(invoice.refundedCustomerAmount, 30);
  assert.equal(invoice.insuranceRefundedAmount, 70);
  assert.equal(invoice.refundState, "refunded");
  await assert.rejects(call("collectInsurancePayment", collection(1), "excess-after-refund"), /outstanding claims/);
});

test("mixed customer refund updates the drawer contract once without touching the creation shift", async () => {
  const {db, call} = setup();
  db.write("pharmacies/pharmacy/shifts/shift-c", {
    status: "open", openingCash: 100, cashTotal: 50,
    cashRefunds: 5, cardRefunds: 2, insuranceRefunds: 3, refundsCount: 4,
  });
  const payload = {...refund(), cashOut: 10, cardOut: 20};
  const result = await call("refundOrder", payload, "mixed-refund-fixed");
  assert.deepEqual(await call("refundOrder", payload, "mixed-refund-fixed"), result);
  const shift = db.read("pharmacies/pharmacy/shifts/shift-c");
  assert.equal(shift.cashRefunds, 15);
  assert.equal(shift.cardRefunds, 22);
  assert.equal(shift.insuranceRefunds, 73);
  assert.equal(shift.refundsCount, 5);
  assert.equal(shift.openingCash + shift.cashTotal - shift.cashRefunds, 135);
  assert.equal(shift.cashRefundTotal, undefined);
  assert.equal(db.read("pharmacies/pharmacy/sales/invoice").creationShiftId, "shift-a");
});

test("wrong payout, quantity, user and pre-delivery refunds leave every document unchanged", async () => {
  for (const variant of ["payout", "quantity", "user", "pre-delivery"]) {
    const {db, call} = setup();
    if (variant === "pre-delivery") db.write("orders/order", {...db.read("orders/order"), status: "ready"});
    const before = [...db.documents.entries()];
    await assert.rejects(call("refundOrder", refund(variant === "quantity" ? 3 : 2, variant === "payout" ? 100 : 30),
      `bad-refund-${variant}`, variant === "user" ? "user" : "pharmacy"));
    assert.deepEqual([...db.documents.entries()], before);
  }
});

test("inactive or explicitly denied employees cannot fall back to a permissive role", async () => {
  for (const employee of [{isActive: false}, {isActive: true, permissionOverrides: {"sales.refund": false}}]) {
    const {db} = setup();
    const actor = seedEmployeeSession(db, "pharmacy", "employee", {...employee, roleId: "custom"});
    db.write("pharmacies/pharmacy/permissions/custom", {permissions: {"sales.refund": true}});
    const handler = buildOrderCommandHandler({db, onCall: (fn) => fn, HttpsError});
    await assert.rejects(handler({auth: actor, data: {
      schemaVersion: 3, command: "refundOrder", orderId: "order", operationId: "denied-employee-refund",
      actor, payload: refund(),
    }}), {code: "permission-denied"});
  }
});
