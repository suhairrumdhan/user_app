"use strict";

// Never connect to a real project. Invoke with the isolated emulator config.
const test = require("node:test");
const assert = require("node:assert/strict");
const enabled = process.env.FINANCE_EMULATOR_TESTS === "1";
if (enabled && process.env.FIRESTORE_EMULATOR_HOST !== "127.0.0.1:8187") {
  throw new Error("Financial tests require the isolated local Firestore emulator on port 8187.");
}
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {initializeTestEnvironment, assertFails, assertSucceeds} = require("@firebase/rules-unit-testing");
const {doc, setDoc, updateDoc, deleteDoc, getDoc, onSnapshot} = require("firebase/firestore");
const {buildPharmacyFinanceCommand} = require("../../src/domain/pharmacy-finance");
const projectId = "demo-financial-cycle";
const pharmacyId = "financial-emulator-pharmacy";
let app; let db; let pharmacy;
test.before(async () => {
  if (!enabled) return;
  app = initializeApp({projectId}, "finance-emulator-tests");
  db = getFirestore(app);
  pharmacy = db.collection("pharmacies").doc(pharmacyId);
});
test.after(async () => { if (app) await deleteApp(app); });
async function fixture(quantity = 1) {
  await db.recursiveDelete(pharmacy);
  const batch = db.batch();
  batch.set(pharmacy, {status: "approved", isActive: true});
  batch.set(pharmacy.collection("medicines").doc("medicine"), {
    name: "Test medicine", quantity, pieceQuantity: 0, reservedQuantity: 0, reservedPieceQuantity: 0,
    sellingPrice: 10, purchasePrice: 4, unitsPerPackage: 10, sellByPiece: true,
    piecePrice: 1, expiryDate: Timestamp.fromMillis(Date.now() + 86400000 * 365), isActive: true,
  });
  batch.set(pharmacy.collection("suppliers").doc("supplier"), {name: "Test supplier"});
  batch.set(pharmacy.collection("shifts").doc("shift"), {status: "open", pharmacyId, openedByKey: `owner:${pharmacyId}`, openingCash: 0});
  batch.set(pharmacy.collection("shift_states").doc(`owner:${pharmacyId}`), {activeShiftId: "shift"});
  await batch.commit();
}
function command(name, payload, operationId) {
  return buildPharmacyFinanceCommand({db})({auth: {uid: pharmacyId, token: {email_verified: true}},
    data: {pharmacyId, command: name, operationId, payload}});
}
function sale(invoiceId) {
  return {invoiceId, sale: {source: "pos", shiftId: "shift", paymentMethod: "cash",
    subtotal: 10, total: 10, insuranceDiscount: 0, discount: 0,
    items: [{medicineId: "medicine", quantity: 1, unitPrice: 10}]}};
}
test("real transactions: competing checkouts cannot sell the last pack twice", {skip: !enabled}, async () => {
  await fixture();
  const results = await Promise.allSettled([
    command("postSale", sale("sale-a"), "concurrent-sale-a"),
    command("postSale", sale("sale-b"), "concurrent-sale-b"),
  ]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal((await pharmacy.collection("sales").get()).size, 1);
  assert.equal((await pharmacy.collection("financial_transactions").get()).size, 1);
  assert.equal((await pharmacy.collection("medicines").doc("medicine").get()).data().quantity, 0);
});
test("real transactions: concurrent retries return one durable invoice and receipt", {skip: !enabled}, async () => {
  await fixture(5);
  const results = await Promise.all([command("postSale", sale("same-sale"), "same-operation-id"),
    command("postSale", sale("same-sale"), "same-operation-id")]);
  assert.deepEqual(results[0], results[1]);
  assert.equal((await pharmacy.collection("medicines").doc("medicine").get()).data().quantity, 4);
  assert.equal((await pharmacy.collection("financial_transactions").get()).size, 1);
  assert.equal((await pharmacy.collection("audit_logs").get()).size, 1);
});
test("real transactions: concurrent supplier payments cannot exceed invoice balance", {skip: !enabled}, async () => {
  await fixture();
  const purchase = await command("receivePurchase", {supplierId: "supplier", items: [
    {medicineId: "medicine", quantity: 2, price: 5}], stockEntries: [
    {medicineId: "medicine", packageQty: 2, pieceQty: 0, purchasePrice: 5, unitsPerPackage: 10}]}, "purchase-operation");
  const payload = {invoiceId: purchase.invoiceId, amount: 7, paymentMethod: "cash"};
  const results = await Promise.allSettled([command("payPurchase", payload, "payment-operation-a"),
    command("payPurchase", payload, "payment-operation-b")]);
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  const invoice = pharmacy.collection("purchase_invoices").doc(purchase.invoiceId);
  assert.equal((await invoice.get()).data().paid, 7);
  assert.equal((await invoice.collection("payments").get()).size, 1);
  assert.equal((await pharmacy.collection("suppliers").doc("supplier").get()).data().currentBalance, 3);
});
test("real transactions: shift closure and checkout serialize to one consistent drawer", {skip: !enabled}, async () => {
  await fixture();
  const results = await Promise.allSettled([
    command("postSale", sale("closing-sale"), "closing-sale-operation"),
    command("closeShift", {shiftId: "shift", closingCash: 0, notes: "Concurrency test"}, "close-shift-operation"),
  ]);
  assert.equal(results[1].status, "fulfilled");
  const shift = (await pharmacy.collection("shifts").doc("shift").get()).data();
  const saleCount = (await pharmacy.collection("sales").get()).size;
  assert.equal(shift.status, "closed");
  assert.equal(shift.expectedDrawerCash, saleCount * 10);
  assert.equal(shift.drawerDiff, 0 - saleCount * 10);
});
test("security rules: owner can read but cannot bypass financial commands or mutate audit history", {skip: !enabled}, async () => {
  await fixture();
  const env = await initializeTestEnvironment({projectId, firestore: {host: "127.0.0.1", port: 8187}});
  try {
    const owner = env.authenticatedContext(pharmacyId, {email_verified: true}).firestore();
    await assertSucceeds(getDoc(doc(owner, `pharmacies/${pharmacyId}/medicines/medicine`)));
    for (const path of ["medicines/medicine", "medicines/medicine/batches/fake", "sales/fake", "sales/fake/returns/return",
      "purchase_invoices/fake", "purchase_invoices/fake/payments/fake", "financial_transactions/fake", "financial_operations/fake",
      "insurance_ledger/fake", "insurance_collections/fake", "suppliers/supplier", "insurance_companies/fake",
      "shifts/shift", `shift_states/owner:${pharmacyId}`, "expenses/fake", "quarantinedReturns/fake"] ) {
      await assertFails(setDoc(doc(owner, `pharmacies/${pharmacyId}/${path}`), {amount: 999, quantity: 999}));
    }
    const audit = doc(owner, `pharmacies/${pharmacyId}/audit_logs/client-event`);
    await assertSucceeds(setDoc(audit, {action: "view", timestamp: new Date()}));
    await assertFails(updateDoc(audit, {action: "changed"}));
    await assertFails(deleteDoc(audit));
    const stranger = env.authenticatedContext("different-pharmacy", {email_verified: true}).firestore();
    await assertFails(getDoc(doc(stranger, `pharmacies/${pharmacyId}/financial_transactions/fake`)));
  } finally { await env.cleanup(); }
});

test("manual entry then POS sale updates the authorized live inventory reader", {skip: !enabled}, async () => {
  await fixture();
  await command("createMedicine", {medicineId: "manual-live", medicine: {
    name: "Manual entry", quantity: 5, pieceQuantity: 0, purchasePrice: 4,
    sellingPrice: 10, unitsPerPackage: 10, sellByPiece: true, piecePrice: 1,
    expiryDate: "2030-01-01", supplierId: "supplier", isActive: true}}, "manual-live-create");
  const env = await initializeTestEnvironment({projectId, firestore: {host: "127.0.0.1", port: 8187}});
  let unsubscribe;
  try {
    const owner = env.authenticatedContext(pharmacyId, {email_verified: true}).firestore();
    const seen = [];
    let changed; let first;
    const initial = new Promise((resolve) => { first = resolve; });
    const updated = new Promise((resolve, reject) => {
      changed = resolve;
      unsubscribe = onSnapshot(doc(owner, `pharmacies/${pharmacyId}/medicines/manual-live`), (snapshot) => {
        seen.push(snapshot.data().quantity);
        if (snapshot.data().quantity === 5) first();
        if (snapshot.data().quantity === 4) changed();
      }, reject);
    });
    await initial;
    const request = sale("manual-live-sale"); request.sale.items[0].medicineId = "manual-live";
    await command("postSale", request, "manual-live-checkout");
    let timeout;
    try {
      await Promise.race([updated, new Promise((_, reject) => {
        timeout = setTimeout(() => reject(new Error("Stock reader did not receive the sale")), 10000);
      })]);
    } finally { clearTimeout(timeout); }
    assert.equal(seen[0], 5); assert.equal(seen.at(-1), 4);
    assert.equal((await pharmacy.collection("purchase_invoices").get()).size, 0);
    const batches = await pharmacy.collection("medicines").doc("manual-live").collection("batches").get();
    assert.equal(batches.docs[0].data().quantity, 4);
  } finally { if (unsubscribe) unsubscribe(); await env.cleanup(); }
});
