"use strict";

const assert = require("node:assert/strict");
const {test, before, after} = require("node:test");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {buildOrderCommandHandler} = require("../../src/domain/order-commands");
const {processOrderTimer} = require("../../src/domain/order-timers");
const {documentHash, employeeActorUid} = require("../../src/auth/employee-session");
const {assertIsolatedEnvironment, buildEmulatorEnvironment} = require("../helpers/environment");

Object.assign(process.env, buildEmulatorEnvironment(process.env));
const config = assertIsolatedEnvironment();

const pharmacyId = "nf12-pharmacy";
const employeeId = "nf12-manager";
const shiftId = "nf12-shift";
const sessionId = documentHash("nf12_employee_session_token_abcdefghijklmnopqrstuvwxyz");
const actorUid = employeeActorUid(pharmacyId, employeeId);
const expiredDeadline = Timestamp.fromDate(new Date("2020-01-01T00:00:00.000Z"));
const validExpiry = Timestamp.fromDate(new Date("2099-01-01T00:00:00.000Z"));

let app;
let db;
let handler;

class HttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

before(async () => {
  app = initializeApp({projectId: config.projectId}, `nf12-${Date.now()}`);
  db = getFirestore(app);
  handler = buildOrderCommandHandler({db, onCall: (fn) => fn, HttpsError});

  const pharmacy = db.collection("pharmacies").doc(pharmacyId);
  const batch = db.batch();
  batch.set(pharmacy, {pharmacyId, status: "approved", isActive: true});
  batch.set(pharmacy.collection("employees").doc(employeeId), {
    id: employeeId,
    roleId: "admin",
    isActive: true,
    credentialVersion: 1,
    permissions: {
      "orders.update_status": true,
      "sales.create": true,
      "sales.refund": true,
    },
  });
  batch.set(pharmacy.collection("permissions").doc("admin"), {
    permissions: {
      "orders.update_status": true,
      "sales.create": true,
      "sales.refund": true,
    },
  });
  batch.set(pharmacy.collection("employeeSessions").doc(sessionId), {
    actorUid,
    pharmacyId,
    employeeId,
    credentialVersion: 1,
    expiresAt: validExpiry,
    revokedAt: null,
  });
  await batch.commit();
});

after(async () => {
  if (app) await deleteApp(app);
});

function actor() {
  return {
    uid: actorUid,
    token: {
      actorType: "pharmacy_employee",
      pharmacyId,
      employeeId,
      sessionId,
      credentialVersion: 1,
    },
  };
}

function invoke(command, orderId, operationId, payload = {}) {
  return handler({
    auth: actor(),
    data: {schemaVersion: 3, command, orderId, operationId, payload, actor: {}},
  });
}

function refs(caseId) {
  const orderId = `nf12-${caseId}-order`;
  const invoiceId = `nf12-${caseId}-invoice`;
  const medicineId = `nf12-${caseId}-medicine`;
  return {
    orderId,
    invoiceId,
    medicineId,
    order: db.collection("orders").doc(orderId),
    invoice: db.collection("pharmacies").doc(pharmacyId).collection("sales").doc(invoiceId),
    medicine: db.collection("pharmacies").doc(pharmacyId).collection("medicines").doc(medicineId),
    reservation: db.collection("orders").doc(orderId).collection("reservations").doc(`order-${orderId}`),
  };
}

async function seedReadyCase(caseId, {includeInvoice = true} = {}) {
  const value = refs(caseId);
  const pharmacy = db.collection("pharmacies").doc(pharmacyId);
  const batch = db.batch();
  batch.set(value.order, {
    schemaVersion: 3,
    orderId: value.orderId,
    orderNumber: value.orderId,
    user: {userId: `nf12-${caseId}-user`},
    pharmacy: {pharmacyId},
    status: "ready",
    statusHistory: [],
    medicines: [{matchedMedicineId: value.medicineId, quantity: 2}],
    invoiceId: value.invoiceId,
    reservationId: `order-${value.orderId}`,
    reservationState: "consumed",
    pickupDeadline: expiredDeadline,
    readyAt: expiredDeadline,
    offerVersion: 0,
    pharmacyReviewActiveMs: 0,
  });
  batch.set(value.medicine, {
    id: value.medicineId,
    name: `NF12 ${caseId}`,
    quantity: 8,
    pieceQuantity: 0,
    reservedQuantity: 0,
    reservedPieceQuantity: 0,
    unitsPerPackage: 10,
    sellByPiece: false,
    sellingPrice: 10,
    purchasePrice: 4,
    isActive: true,
    expiryDate: validExpiry,
  });
  batch.set(value.reservation, {
    state: "consumed",
    items: [{medicineId: value.medicineId, quantity: 2, soldByPiece: false}],
  });
  if (includeInvoice) {
    batch.set(value.invoice, {
      schemaVersion: 3,
      source: "order",
      orderId: value.orderId,
      sourceOrderId: value.orderId,
      pharmacyId,
      invoiceId: value.invoiceId,
      invoiceNumber: `INV-${caseId}`,
      type: "sale",
      status: "completed",
      isSaved: true,
      isDeleted: false,
      inventoryPosted: true,
      reservationConsumed: true,
      financialPosted: false,
      total: 20,
      customerShare: 20,
      companyShare: 0,
      insuranceDiscount: 0,
      insuranceClaimAmount: 0,
      cashIn: 0,
      cardIn: 0,
      paymentMethod: "cash",
      paymentState: "pendingDelivery",
      paidAmount: 0,
      items: [{medicineId: value.medicineId, quantity: 2, unitPrice: 10}],
      createdAt: Timestamp.now(),
    });
  }
  batch.set(pharmacy.collection("shifts").doc(shiftId), {
    status: "open",
    pharmacyId,
    openedByKey: `employee:${employeeId}`,
    cashTotal: 0,
    cardTotal: 0,
    salesCount: 0,
  });
  batch.set(pharmacy.collection("shift_states").doc(`employee:${employeeId}`), {
    activeShiftId: shiftId,
  });
  await batch.commit();
  return value;
}

test("TC-PH-NF12 repeated timeout scan creates one overdue event and one alert per recipient", async () => {
  const value = await seedReadyCase("timer");
  const clock = () => Date.parse("2026-09-19T00:00:00.000Z");

  await processOrderTimer({db, orderId: value.orderId, clock});
  await processOrderTimer({db, orderId: value.orderId, clock});

  const order = (await value.order.get()).data();
  assert.equal(order.status, "ready");
  assert.equal(order.pickupOverdue, true);
  assert.equal((await value.order.collection("timerEvents").get()).size, 1);
  assert.equal((await db.collection("users").doc(`nf12-timer-user`).collection("notifications").get()).size, 1);
  assert.equal((await db.collection("pharmacies").doc(pharmacyId).collection("notifications").get()).size, 1);
});

test("TC-PH-NF12 same not-collected operation reverses and records the incident once", async () => {
  const value = await seedReadyCase("retry");
  const operationId = "nf12-not-collected-same-operation";

  const first = await invoke("markNotCollected", value.orderId, operationId);
  const retry = await invoke("markNotCollected", value.orderId, operationId);

  assert.deepEqual(retry, first);
  assert.equal((await value.order.get()).data().status, "notCollected");
  assert.equal((await value.invoice.get()).data().paymentState, "reversedBeforeDelivery");
  assert.equal((await value.medicine.get()).data().quantity, 10);
  const reversal = await db.collection("pharmacies").doc(pharmacyId)
    .collection("sales").where("source", "==", "orderReversal")
    .where("orderId", "==", value.orderId).get();
  assert.equal(reversal.size, 1);
  const incident = await db.collection("users").doc("nf12-retry-user")
    .collection("orderIncidents").doc(value.orderId).get();
  assert.equal(incident.exists, true);
  assert.equal(incident.data().occurrenceCount, 1);
});

test("TC-PH-NF12 reversal failure leaves the ready order and related data unchanged", async () => {
  const value = await seedReadyCase("failure", {includeInvoice: false});
  const beforeOrder = (await value.order.get()).data();
  const beforeMedicine = (await value.medicine.get()).data();

  await assert.rejects(
    invoke("markNotCollected", value.orderId, "nf12-failed-reversal-operation"),
    (error) => error.code === "failed-precondition",
  );

  assert.deepEqual((await value.order.get()).data(), beforeOrder);
  assert.deepEqual((await value.medicine.get()).data(), beforeMedicine);
  assert.equal((await db.collection("pharmacies").doc(pharmacyId)
    .collection("sales").doc(`order-reversal-${value.orderId}`).get()).exists, false);
  assert.equal((await db.collection("users").doc("nf12-failure-user")
    .collection("orderIncidents").doc(value.orderId).get()).exists, false);
});

test("TC-PH-NF12 concurrent delivery and not-collected commit exactly one terminal outcome", async () => {
  const value = await seedReadyCase("race");

  const results = await Promise.allSettled([
    invoke("completeOrder", value.orderId, "nf12-race-complete", {collectionShiftId: shiftId}),
    invoke("markNotCollected", value.orderId, "nf12-race-not-collected"),
  ]);

  assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
  assert.equal(results.filter((result) => result.status === "rejected").length, 1);

  const order = (await value.order.get()).data();
  const invoice = (await value.invoice.get()).data();
  const stock = (await value.medicine.get()).data();
  const shift = (await db.collection("pharmacies").doc(pharmacyId)
    .collection("shifts").doc(shiftId).get()).data();
  const reversalExists = (await db.collection("pharmacies").doc(pharmacyId)
    .collection("sales").doc(`order-reversal-${value.orderId}`).get()).exists;
  const incidentExists = (await db.collection("users").doc("nf12-race-user")
    .collection("orderIncidents").doc(value.orderId).get()).exists;
  const collectionTransactionExists = (await db.collection("pharmacies").doc(pharmacyId)
    .collection("financial_transactions").doc(`order-customer-${value.orderId}`).get()).exists;

  assert.ok(["completed", "notCollected"].includes(order.status));
  if (order.status === "completed") {
    assert.equal(invoice.paymentState, "delivered");
    assert.equal(stock.quantity, 8);
    assert.equal(shift.salesCount, 1);
    assert.equal(reversalExists, false);
    assert.equal(incidentExists, false);
    assert.equal(collectionTransactionExists, true);
  } else {
    assert.equal(invoice.paymentState, "reversedBeforeDelivery");
    assert.equal(stock.quantity, 10);
    assert.equal(shift.salesCount, 0);
    assert.equal(reversalExists, true);
    assert.equal(incidentExists, true);
    assert.equal(collectionTransactionExists, false);
  }
});
