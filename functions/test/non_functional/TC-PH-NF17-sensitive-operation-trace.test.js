"use strict";

const assert = require("node:assert/strict");
const {test, before, after} = require("node:test");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {buildOrderCommandHandler} = require("../../src/domain/order-commands");
const {assertIsolatedEnvironment, buildEmulatorEnvironment} = require("../helpers/environment");

Object.assign(process.env, buildEmulatorEnvironment(process.env));
const config = assertIsolatedEnvironment();
const runId = Date.now().toString(36);
const pharmacyId = "nf17-pharmacy";
const orderId = `nf17-order-${runId}`;
const invoiceId = `nf17-invoice-${runId}`;
const medicineId = `nf17-medicine-${runId}`;
const shiftId = `nf17-shift-${runId}`;

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
  app = initializeApp({projectId: config.projectId}, `nf17-${Date.now()}`);
  db = getFirestore(app);
  handler = buildOrderCommandHandler({db, onCall: (fn) => fn, HttpsError});
});

after(async () => {
  if (app) await deleteApp(app);
});

function invoke(command, operationId, payload = {}) {
  return handler({
    auth: {uid: pharmacyId, token: {email_verified: true}},
    data: {schemaVersion: 3, command, operationId, orderId, payload, actor: {}},
  });
}

test("TC-PH-NF17 traces an order sale across all linked records", async () => {
  const pharmacy = db.collection("pharmacies").doc(pharmacyId);
  const orderRef = db.collection("orders").doc(orderId);
  const medicineRef = pharmacy.collection("medicines").doc(medicineId);
  const batch = db.batch();
  batch.set(pharmacy, {pharmacyId, status: "approved", isActive: true});
  batch.set(medicineRef, {
    id: medicineId, name: "NF17 Medicine", quantity: 10,
    pieceQuantity: 0, reservedQuantity: 0, reservedPieceQuantity: 0,
    unitsPerPackage: 10, sellByPiece: false, sellingPrice: 10,
    purchasePrice: 4, isActive: true,
    expiryDate: Timestamp.fromDate(new Date("2099-01-01T00:00:00Z")),
  });
  batch.set(pharmacy.collection("shifts").doc(shiftId), {
    status: "open", pharmacyId, openedByKey: `owner:${pharmacyId}`,
    cashTotal: 0, cardTotal: 0, salesCount: 0,
  });
  batch.set(pharmacy.collection("shift_states").doc(`owner:${pharmacyId}`), {
    activeShiftId: shiftId,
  });
  batch.set(orderRef, {
    schemaVersion: 3, orderId, orderNumber: "NF17-ORDER",
    user: {userId: "nf17-user", name: "NF17 User"},
    pharmacy: {pharmacyId}, status: "underReview", statusHistory: [],
    medicines: [{matchedMedicineId: medicineId, quantity: 2}],
    offerVersion: 0, reservationId: null, pharmacyReviewActiveMs: 0,
    reviewStartedAt: Timestamp.now(),
  });
  await batch.commit();

  await invoke("confirmFullOrder", `nf17-confirm-${runId}`);
  await invoke("startPreparing", `nf17-invoice-${runId}`, {
    invoiceId,
    invoice: {
      invoiceNumber: "NF17-INVOICE", shiftId, subtotal: 20, total: 20,
      discount: 0, insuranceDiscount: 0, paymentMethod: "cash",
      items: [{medicineId, name: "NF17 Medicine", quantity: 2, unitPrice: 10, unitCost: 4}],
    },
  });
  await invoke("markReady", `nf17-ready-${runId}`);
  await invoke("completeOrder", `nf17-complete-${runId}`, {collectionShiftId: shiftId});

  const order = (await orderRef.get()).data();
  const invoice = (await pharmacy.collection("sales").doc(invoiceId).get()).data();
  const medicine = (await medicineRef.get()).data();
  const transaction = (await pharmacy.collection("financial_transactions")
    .doc(`order-customer-${orderId}`).get()).data();
  const audit = await pharmacy.collection("audit_logs")
    .where("targetId", "==", orderId).get();
  const operations = await db.collection("orderOperations").get();

  assert.equal(order.status, "completed");
  assert.equal(order.invoiceId, invoiceId);
  assert.equal(invoice.orderId, orderId);
  assert.equal(invoice.sourceOrderId, orderId);
  assert.equal(invoice.paymentState, "delivered");
  assert.equal(invoice.financialTransactionId, `order-customer-${orderId}`);
  assert.equal(medicine.quantity, 8);
  assert.equal(medicine.reservedQuantity, 0);
  assert.equal(transaction.referenceId, invoiceId);
  assert.equal(transaction.metadata.orderId, orderId);
  assert.equal(audit.size, 4);
  assert.deepEqual(
    new Set(audit.docs.map((doc) => doc.data().action)),
    new Set(["confirmFullOrder", "startPreparing", "markReady", "completeOrder"]),
  );
  assert.equal(
    operations.docs.filter((doc) => doc.data().result?.result?.orderId === orderId).length,
    4,
  );
});
