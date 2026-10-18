"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {Timestamp} = require("firebase-admin/firestore");
const {buildOrderCommandHandler} = require("../../src/domain/order-commands");
const {FakeFirestore} = require("./helpers/fake-firestore");
const {seedEmployeeSession} = require("./helpers/employee-session");

class FakeHttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

let sequence = 0;
function invoke(handler, command, payload = {}, operationId = null, auth = null) {
  sequence += 1;
  return handler({
    auth: auth?.uid ? auth : {uid: "pharmacy-one"},
    data: {
      schemaVersion: 3,
      command,
      operationId: operationId || `canonical-accounting-${sequence}`,
      orderId: "order-one",
      payload,
      actor: {},
    },
  });
}

function seed() {
  return new FakeFirestore({
    "pharmacies/pharmacy": {status: "approved", isActive: true},
    "orders/order-one": {
      schemaVersion: 3,
      orderId: "order-one",
      orderNumber: "260913-1000",
      status: "confirmedReserved",
      estimatedTotalPrice: 15,
      statusHistory: [],
      user: {userId: "user-one"},
      insurance: {enabled: true},
      insuranceSelection: {companyId: "insurance-one", companyCode: "TEST", cardId: "card", cardNumber: "CARD", coveragePercentage: 25},
      beneficiary: {type: "self"},
      pharmacy: {pharmacyId: "pharmacy-one"},
      medicines: [{matchedMedicineId: "medicine-a", quantity: 2}],
      reservationId: "order-order-one",
      reservationState: "active",
      pharmacyReviewActiveMs: 1000,
      reviewStartedAt: Timestamp.now(),
    },
    "orders/order-one/reservations/order-order-one": {
      reservationId: "order-order-one",
      state: "active",
      items: [{medicineId: "medicine-a", quantity: 2, soldByPiece: false}],
    },
    "pharmacies/pharmacy-one/medicines/medicine-a": {
      quantity: 10,
      reservedQuantity: 2,
      pieceQuantity: 0,
      reservedPieceQuantity: 0,
      sellingPrice: 100,
      piecePrice: 10,
      unitsPerPackage: 10,
      isActive: true,
      expiryDate: Timestamp.fromDate(new Date("2099-01-01T00:00:00Z")),
    },
    "pharmacies/pharmacy-one/shift_states/owner:pharmacy-one": {activeShiftId: "shift-a"},
    "pharmacies/pharmacy-one/shifts/shift-a": {
      status: "open", pharmacyId: "pharmacy-one", openedByKey: "owner:pharmacy-one",
      cashTotal: 0,
      cardTotal: 0,
      salesCount: 0,
    },
    "pharmacies/pharmacy-one": {status: "approved", isActive: true, acceptedInsuranceCodes: ["TEST"]},
    "users/user-one/insurances/card": {
      companyCode: "TEST", cardNumber: "CARD", startDate: "2020-01-01", endDate: "2099-01-01",
    },
    "pharmacies/pharmacy-one/insurance_companies/insurance-one": {
      status: "فعال", code: "TEST", discountPercentage: 25,
    },
    "pharmacies/pharmacy-one/shifts/shift-b": {
      status: "open", pharmacyId: "pharmacy-one", openedByKey: "owner:pharmacy-one",
      cashTotal: 0,
      cardTotal: 0,
      salesCount: 0,
    },
  });
}

function invoicePayload() {
  return {
    invoiceId: "invoice-one",
    invoice: {
      invoiceNumber: "INV-ORDER-1",
      shiftId: "shift-a",
      subtotal: 20,
      discount: 0,
      insuranceDiscount: 5,
      insuranceCompanyId: "insurance-one",
      insuranceCompanyName: "شركة الاختبار",
      total: 15,
      paymentMethod: "cash",
      items: [{
        medicineId: "medicine-a",
        name: "Medicine A",
        quantity: 2,
        sellAsPiece: false,
        unitPrice: 10,
        unitCost: 4,
      }],
    },
  };
}

function buildHandler(database) {
  return buildOrderCommandHandler({
    db: database,
    onCall: (handler) => handler,
    HttpsError: FakeHttpsError,
  });
}

test("precreated invoice cannot consume reservation without atomic invoice payload", async () => {
  const database = seed();
  database.write("pharmacies/pharmacy-one/sales/invoice-one", {orderId: "order-one"});
  const before = [...database.documents.entries()];
  await assert.rejects(invoke(buildHandler(database), "startPreparing", {invoiceId: "invoice-one"}),
    {code: "failed-precondition"});
  assert.deepEqual([...database.documents.entries()], before);
});

test("invoice input cannot inject future collection or refund state", async () => {
  const database = seed();
  const payload = invoicePayload();
  Object.assign(payload.invoice, {refundedQuantities: {"medicine-a|pack": 2},
    refundedCustomerAmount: 15, insuranceCollectedAmount: 5, reversedAt: Timestamp.now(),
    sourceOrderId: "other", source: "pos", pharmacyId: "other"});
  await invoke(buildHandler(database), "startPreparing", payload);
  const saved = database.read("pharmacies/pharmacy-one/sales/invoice-one");
  assert.equal(saved.source, "order");
  assert.equal(saved.pharmacyId, "pharmacy-one");
  assert.equal(saved.sourceOrderId, "order-one");
  for (const key of ["refundedQuantities", "refundedCustomerAmount", "insuranceCollectedAmount", "reversedAt"]) {
    assert.equal(saved[key], undefined);
  }
  await invoke(buildHandler(database), "markReady");
});

for (const command of ["markReady", "completeOrder", "cancelAfterInvoice", "markNotCollected"]) {
  for (const variant of ["foreign-order", "foreign-pharmacy", "pos-source", "missing-invoice",
    "missing-reservation", "active-reservation", "extra-quantity", "different-unit", "paid-before-delivery"]) {
    test(`${command} rejects ${variant} invoice without partial effects`, async () => {
      const database = seed();
      const handler = buildHandler(database);
      let employeeActor = {};
      await invoke(handler, "startPreparing", invoicePayload());
      if (["completeOrder", "markNotCollected"].includes(command)) await invoke(handler, "markReady");
      if (command === "markNotCollected") {
        employeeActor = seedEmployeeSession(database, "pharmacy-one", "manager",
          {isActive: true, roleId: "admin", permissions: {"orders.update_status": true, "sales.create": true, "sales.refund": true, "sales.override_price": true}});
        database.write("orders/order-one", {...database.read("orders/order-one"),
          pickupDeadline: Timestamp.fromDate(new Date("2020-01-01"))});
      }
      const invoicePath = "pharmacies/pharmacy-one/sales/invoice-one";
      const reservationPath = "orders/order-one/reservations/order-order-one";
      const invoice = database.read(invoicePath);
      if (variant === "foreign-order") invoice.orderId = "other";
      if (variant === "foreign-pharmacy") invoice.pharmacyId = "other";
      if (variant === "pos-source") invoice.source = "pos";
      if (variant === "extra-quantity") invoice.items[0].quantity += 1;
      if (variant === "different-unit") invoice.items[0].sellAsPiece = true;
      if (variant === "paid-before-delivery") invoice.paidAmount = 1;
      database.write(invoicePath, invoice);
      if (variant === "missing-invoice") database.delete(invoicePath);
      if (variant === "missing-reservation") database.delete(reservationPath);
      if (variant === "active-reservation") database.write(reservationPath,
        {...database.read(reservationPath), state: "active"});
      const before = [...database.documents.entries()];
      await assert.rejects(invoke(handler, command, {
        collectionShiftId: "shift-b", reason: "test cancellation",
      }, null, employeeActor), {code: "failed-precondition"});
      assert.deepEqual([...database.documents.entries()], before);
    });
  }
}

test("missing or non-payable invoice cannot silently complete an order", async () => {
  for (const invoice of [null, {paymentState: "delivered"}]) {
    const database = seed();
    database.write("orders/order-one", {...database.read("orders/order-one"), status: "ready", invoiceId: "invoice-one"});
    if (invoice) database.write("pharmacies/pharmacy-one/sales/invoice-one", invoice);
    const before = [...database.documents.entries()];
    await assert.rejects(invoke(buildHandler(database), "completeOrder", {collectionShiftId: "shift-b"}),
      {code: "failed-precondition"});
    assert.deepEqual([...database.documents.entries()], before);
  }
});

for (const variant of ["expired-card", "inactive-card", "missing-card", "changed-card-number",
  "uncovered-member", "removed-company", "omitted-coverage", "changed-rate"]) {
  test(`invoice rejects ${variant} without consuming its reservation`, async () => {
    const database = seed();
    const cardPath = "users/user-one/insurances/card";
    const card = database.read(cardPath);
    const payload = invoicePayload();
    if (variant === "expired-card") database.write(cardPath, {...card, endDate: "2020-01-01"});
    if (variant === "inactive-card") database.write(cardPath, {...card, isActive: false});
    if (variant === "missing-card") database.delete(cardPath);
    if (variant === "changed-card-number") database.write(cardPath, {...card, cardNumber: "OTHER"});
    if (variant === "uncovered-member") database.write("orders/order-one", {
      ...database.read("orders/order-one"), beneficiary: {type: "family", familyMemberId: "not-covered"},
    });
    if (variant === "removed-company") database.write("pharmacies/pharmacy-one", {...database.read("pharmacies/pharmacy-one"), acceptedInsuranceCodes: []});
    if (variant === "omitted-coverage") {
      payload.invoice.insuranceCompanyId = null;
      payload.invoice.insuranceDiscount = 0;
      payload.invoice.total = 20;
    }
    if (variant === "changed-rate") database.write("pharmacies/pharmacy-one/insurance_companies/insurance-one", {
      ...database.read("pharmacies/pharmacy-one/insurance_companies/insurance-one"), discountPercentage: 70,
    });
    const before = [...database.documents.entries()];
    await assert.rejects(invoke(buildHandler(database), "startPreparing", payload), {code: "failed-precondition"});
    assert.deepEqual([...database.documents.entries()], before);
  });
}

test("partial piece offer completes invoice using only accepted quantities from unopened stock", async () => {
  const database = seed();
  database.delete("orders/order-one/reservations/order-order-one");
  database.write("orders/order-one", {
    ...database.read("orders/order-one"), status: "underReview", reservationId: null,
    medicines: [{matchedMedicineId: "medicine-a", quantity: 4, soldByPiece: true}],
  });
  database.write("pharmacies/pharmacy-one/medicines/medicine-a", {
    quantity: 1, pieceQuantity: 0, unitsPerPackage: 10, reservedPieceQuantity: 1,
    sellingPrice: 100, piecePrice: 10,
  });
  const handler = buildHandler(database);
  await invoke(handler, "createPartialOffer", {
    items: [{medicineId: "medicine-a", quantity: 2, soldByPiece: true}],
  });
  assert.equal(database.read("pharmacies/pharmacy-one/medicines/medicine-a").reservedPieceQuantity, 1);
  await handler({auth: {uid: "user-one"}, data: {
    schemaVersion: 3, command: "acceptPartialOffer", operationId: "pieces-accept",
    orderId: "order-one", payload: {offerVersion: 1},
  }});
  const payload = invoicePayload();
  payload.invoice.items[0].sellAsPiece = true;
  await invoke(handler, "startPreparing", payload, "pieces-invoice");
  const stock = database.read("pharmacies/pharmacy-one/medicines/medicine-a");
  assert.equal(stock.quantity, 0);
  assert.equal(stock.pieceQuantity, 8);
  assert.equal(stock.reservedPieceQuantity, 1);
  assert.equal(database.read("pharmacies/pharmacy-one/sales/invoice-one").paidAmount, 0);
  await invoke(handler, "startPreparing", payload, "pieces-invoice");
  assert.deepEqual(database.read("pharmacies/pharmacy-one/medicines/medicine-a"), stock);
  await invoke(handler, "markReady");
  database.write("pharmacies/pharmacy-one/shift_states/owner:pharmacy-one", {activeShiftId: "shift-b"});
  await invoke(handler, "completeOrder", {collectionShiftId: "shift-b"});
  assert.equal(database.read("orders/order-one").status, "completed");
});

test("pre-delivery reversal quarantines stock that expired after invoice creation", async () => {
  const database = seed();
  const handler = buildHandler(database);
  await invoke(handler, "startPreparing", invoicePayload());
  const path = "pharmacies/pharmacy-one/medicines/medicine-a";
  database.write(`${path}/batches/legacy-opening`, {...database.read(`${path}/batches/legacy-opening`), expiryDate: "2020-01-01"});
  await invoke(handler, "cancelAfterInvoice", {reason: "Expired before pickup"});
  assert.equal(database.read(path).quantity, 8);
  const quarantines = database.paths("pharmacies/pharmacy-one/quarantinedReturns/");
  assert.equal(quarantines.length, 1);
  assert.equal(database.read(quarantines[0]).quantity, 2);
  assert.equal(database.read(quarantines[0]).availableForSale, false);
  assert.equal(database.read("orders/order-one").status, "cancelled");
});

test("order invoice consumes reservation and stock once without collecting money", async () => {
  const database = seed();
  const handler = buildHandler(database);
  const operationId = "canonical-invoice-fixed";
  const first = await invoke(handler, "startPreparing", invoicePayload(), operationId);
  const retry = await invoke(handler, "startPreparing", invoicePayload(), operationId);
  assert.deepEqual(retry, first);

  const medicine = database.read("pharmacies/pharmacy-one/medicines/medicine-a");
  const invoice = database.read("pharmacies/pharmacy-one/sales/invoice-one");
  assert.equal(medicine.quantity, 8);
  assert.equal(medicine.reservedQuantity, 0);
  assert.equal(invoice.creationShiftId, "shift-a");
  assert.equal(invoice.paymentState, "pendingDelivery");
  assert.equal(invoice.paidAmount, 0);
  assert.equal(invoice.financialPosted, false);
  assert.equal(database.read("pharmacies/pharmacy-one/shifts/shift-a").cashTotal, 0);
});

test("delivery collects customer in shift B and records insurance once", async () => {
  const database = seed();
  const handler = buildHandler(database);
  await invoke(handler, "startPreparing", invoicePayload());
  await invoke(handler, "markReady");
  database.write("pharmacies/pharmacy-one/shift_states/owner:pharmacy-one", {activeShiftId: "shift-b"});
  const operationId = "canonical-delivery-fixed";
  const first = await invoke(
    handler,
    "completeOrder",
    {collectionShiftId: "shift-b"},
    operationId,
  );
  const retry = await invoke(
    handler,
    "completeOrder",
    {collectionShiftId: "shift-b"},
    operationId,
  );
  assert.deepEqual(retry, first);

  const invoice = database.read("pharmacies/pharmacy-one/sales/invoice-one");
  assert.equal(invoice.creationShiftId, "shift-a");
  assert.equal(invoice.collectionShiftId, "shift-b");
  assert.equal(invoice.paidAmount, 15);
  assert.equal(invoice.insuranceClaimStatus, "due");
  assert.equal(database.read("pharmacies/pharmacy-one/shifts/shift-a").cashTotal, 0);
  assert.equal(database.read("pharmacies/pharmacy-one/shifts/shift-b").cashTotal, 15);
  assert.equal(database.read("pharmacies/pharmacy-one/shifts/shift-b").salesCount, 1);
  assert.equal(database.read("pharmacies/pharmacy-one/shifts/shift-b").insuranceBilledTotal, 5);
  assert.equal(database.read("pharmacies/pharmacy-one/shifts/shift-a").insuranceBilledTotal || 0, 0);
  assert.equal(
    database.read("pharmacies/pharmacy-one/financial_transactions/order-customer-order-one").amount,
    15,
  );
  assert.equal(
    database.read("pharmacies/pharmacy-one/financial_transactions/order-insurance-order-one").amount,
    5,
  );
});

test("pre-delivery cancellation reverses original stock with no cash refund", async () => {
  const database = seed();
  const handler = buildHandler(database);
  const duplicateInvoice = invoicePayload();
  duplicateInvoice.invoice.items = [
    {...duplicateInvoice.invoice.items[0], quantity: 1},
    {...duplicateInvoice.invoice.items[0], quantity: 1},
  ];
  await invoke(handler, "startPreparing", duplicateInvoice);
  const operationId = "canonical-reversal-fixed";
  const first = await invoke(
    handler,
    "cancelAfterInvoice",
    {reason: "تعذر توفير الطلب"},
    operationId,
  );
  const retry = await invoke(
    handler,
    "cancelAfterInvoice",
    {reason: "تعذر توفير الطلب"},
    operationId,
  );
  assert.deepEqual(retry, first);

  assert.equal(
    database.read("pharmacies/pharmacy-one/medicines/medicine-a").quantity,
    10,
  );
  const reversal = database.read(
    "pharmacies/pharmacy-one/sales/order-reversal-order-one",
  );
  assert.equal(reversal.type, "refund");
  assert.equal(reversal.cashOut, 0);
  assert.equal(reversal.cardOut, 0);
  assert.equal(database.paths("pharmacies/pharmacy-one/financial_transactions/").length, 0);
});
