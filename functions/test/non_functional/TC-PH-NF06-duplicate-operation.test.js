"use strict";

const assert = require("node:assert/strict");
const {test, before, after} = require("node:test");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {buildPharmacyFinanceCommand} = require("../../src/domain/pharmacy-finance");
const {assertIsolatedEnvironment, buildEmulatorEnvironment} = require("../helpers/environment");

Object.assign(process.env, buildEmulatorEnvironment(process.env));
const config = assertIsolatedEnvironment();
let app; let db; let command;
const pharmacyId = "nf06-pharmacy";
const operationId = "nf06-same-operation";
const invoiceId = "nf06-same-invoice";

before(async () => {
  app = initializeApp({projectId: config.projectId}, `nf06-${Date.now()}`);
  db = getFirestore(app);
  command = buildPharmacyFinanceCommand({db});
});
after(async () => { if (app) await deleteApp(app); });

function postSale() {
  return command({
    auth: {uid: pharmacyId, token: {email_verified: true}},
    data: {
      pharmacyId,
      command: "postSale",
      operationId,
      payload: {invoiceId, sale: {
        source: "pos", shiftId: "nf06-shift", paymentMethod: "cash",
        subtotal: 10, total: 10, insuranceDiscount: 0, discount: 0,
        items: [{medicineId: "nf06-medicine", quantity: 1, unitPrice: 10}],
      }},
    },
  });
}

test("TC-PH-NF06 duplicate concurrent sale creates one invoice and one stock effect", async () => {
  const pharmacy = db.collection("pharmacies").doc(pharmacyId);
  const batch = db.batch();
  batch.set(pharmacy, {id: pharmacyId, pharmacyId, status: "approved", isActive: true});
  batch.set(pharmacy.collection("medicines").doc("nf06-medicine"), {name: "NF06 Medicine", quantity: 5, pieceQuantity: 0, reservedQuantity: 0, reservedPieceQuantity: 0, sellingPrice: 10, purchasePrice: 4, unitsPerPackage: 10, sellByPiece: false, isActive: true, expiryDate: Timestamp.fromDate(new Date("2099-01-01T00:00:00Z"))});
  batch.set(pharmacy.collection("shifts").doc("nf06-shift"), {status: "open", pharmacyId, openedByKey: `owner:${pharmacyId}`, cashTotal: 0, cardTotal: 0, salesCount: 0});
  batch.set(pharmacy.collection("shift_states").doc(`owner:${pharmacyId}`), {activeShiftId: "nf06-shift"});
  await batch.commit();

  const results = await Promise.all([postSale(), postSale()]);
  assert.deepEqual(results[0], results[1]);
  assert.equal((await pharmacy.collection("sales").get()).size, 1);
  assert.equal((await pharmacy.collection("financial_transactions").get()).size, 1);
  assert.equal((await pharmacy.collection("audit_logs").get()).size, 1);
  const medicine = (await pharmacy.collection("medicines").doc("nf06-medicine").get()).data();
  assert.equal(medicine.quantity, 4);
  const shift = (await pharmacy.collection("shifts").doc("nf06-shift").get()).data();
  assert.equal(shift.salesCount, 1);
  assert.equal(shift.cashTotal, 10);
});
