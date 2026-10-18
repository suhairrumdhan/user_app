"use strict";

const assert = require("node:assert/strict");
const {test, before, after} = require("node:test");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {buildOrderCommandHandler} = require("../../src/domain/order-commands");
const {assertIsolatedEnvironment, buildEmulatorEnvironment} = require("../helpers/environment");

Object.assign(process.env, buildEmulatorEnvironment(process.env));
const config = assertIsolatedEnvironment();
let app; let db; let handler;
const pharmacyId = "nf05-pharmacy";
const medicineId = "nf05-last-pack";

class HttpsError extends Error {
  constructor(code, message, details) { super(message); this.code = code; this.details = details; }
}

before(async () => {
  app = initializeApp({projectId: config.projectId}, `nf05-${Date.now()}`);
  db = getFirestore(app);
  handler = buildOrderCommandHandler({db, onCall: fn => fn, HttpsError});
});
after(async () => { if (app) await deleteApp(app); });

function order(orderId, userId) {
  return {schemaVersion: 3, orderId, user: {userId}, pharmacy: {pharmacyId}, status: "underReview", statusHistory: [], medicines: [{matchedMedicineId: medicineId, quantity: 1}], offerVersion: 0, pharmacyReviewActiveMs: 0, reviewStartedAt: Timestamp.now()};
}

function confirm(orderId, operationId) {
  return handler({auth: {uid: pharmacyId, token: {email_verified: true}}, data: {schemaVersion: 3, command: "confirmFullOrder", operationId, orderId, payload: {}, actor: {}}});
}

test("TC-PH-NF05 only one concurrent order reserves the last available quantity", async () => {
  const pharmacy = db.collection("pharmacies").doc(pharmacyId);
  const medicine = pharmacy.collection("medicines").doc(medicineId);
  const batch = db.batch();
  batch.set(pharmacy, {id: pharmacyId, pharmacyId, status: "approved", isActive: true, isOnline: true});
  batch.set(medicine, {id: medicineId, name: "NF05 Last Pack", quantity: 1, reservedQuantity: 0, pieceQuantity: 0, reservedPieceQuantity: 0, unitsPerPackage: 1, sellByPiece: false, sellingPrice: 10, isActive: true, expiryDate: Timestamp.fromDate(new Date("2099-01-01T00:00:00Z"))});
  batch.set(db.collection("orders").doc("nf05-order-a"), order("nf05-order-a", "nf05-user-a"));
  batch.set(db.collection("orders").doc("nf05-order-b"), order("nf05-order-b", "nf05-user-b"));
  await batch.commit();

  const results = await Promise.allSettled([
    confirm("nf05-order-a", "nf05-operation-a"),
    confirm("nf05-order-b", "nf05-operation-b"),
  ]);
  assert.equal(results.filter(result => result.status === "fulfilled").length, 1);
  assert.equal(results.filter(result => result.status === "rejected").length, 1);
  const stock = (await medicine.get()).data();
  assert.equal(stock.quantity, 1);
  assert.equal(stock.reservedQuantity, 1);
  assert.ok(stock.quantity - stock.reservedQuantity >= 0);
  const statuses = await Promise.all(["nf05-order-a", "nf05-order-b"].map(async id => (await db.collection("orders").doc(id).get()).data().status));
  assert.equal(statuses.filter(status => status === "confirmedReserved").length, 1);
  assert.equal(statuses.filter(status => status === "underReview").length, 1);
});
