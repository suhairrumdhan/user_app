"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {FakeFirestore} = require("../f03/helpers/fake-firestore");
const {buildPharmacyFinanceCommand} = require("../../src/domain/pharmacy-finance");
const {executeWithOperationReplay, withLostResponseAfterCommit} = require("../helpers/commands");

const root = "pharmacies/nf08-pharmacy";
const auth = {uid: "nf08-pharmacy", token: {email_verified: true}};

function fixture() {
  return new FakeFirestore({
    [root]: {status: "approved", isActive: true},
    [`${root}/suppliers/nf08-supplier`]: {name: "NF08 Supplier", openingBalance: 0},
    [`${root}/medicines/medicine-a`]: {name: "A", quantity: 10, pieceQuantity: 0, reservedQuantity: 0, reservedPieceQuantity: 0, unitsPerPackage: 10, purchasePrice: 5, sellingPrice: 10, isActive: true},
    [`${root}/medicines/medicine-b`]: {name: "B", quantity: 20, pieceQuantity: 0, reservedQuantity: 0, reservedPieceQuantity: 0, unitsPerPackage: 10, purchasePrice: 4, sellingPrice: 8, isActive: true},
    [`${root}/shifts/nf08-shift`]: {status: "open", pharmacyId: "nf08-pharmacy", openedByKey: "owner:nf08-pharmacy"},
    [`${root}/shift_states/owner:nf08-pharmacy`]: {activeShiftId: "nf08-shift"},
  });
}

function validPurchase() {
  return {supplierId: "nf08-supplier", clientDraftId: "nf08-purchase-draft-001", discount: 0,
    items: [{medicineId: "medicine-a", quantity: 2, price: 5}, {medicineId: "medicine-b", quantity: 3, price: 4}],
    stockEntries: [{medicineId: "medicine-a", packageQty: 2, pieceQty: 0, purchasePrice: 5, unitsPerPackage: 10, expiryDate: "2028-01-01", batchNumber: "A"}, {medicineId: "medicine-b", packageQty: 3, pieceQty: 0, purchasePrice: 4, unitsPerPackage: 10, expiryDate: "2028-01-01", batchNumber: "B"}]};
}

function command(db, payload, operationId) {
  return buildPharmacyFinanceCommand({db})({auth, data: {pharmacyId: "nf08-pharmacy", command: "receivePurchase", operationId, payload}});
}

test("TC-PH-NF08 invalid purchase line leaves every document unchanged", async () => {
  const db = fixture(); const request = validPurchase();
  request.items.push({medicineId: "missing", quantity: 1, price: 4});
  request.stockEntries.push({medicineId: "missing", packageQty: 1, pieceQty: 0, purchasePrice: 4});
  const before = [...db.documents.entries()];
  await assert.rejects(command(db, request, "nf08-invalid"));
  assert.deepEqual([...db.documents.entries()], before);
});

test("TC-PH-NF08 retry and lost response create one durable purchase effect", async () => {
  const db = fixture(); const request = validPurchase();
  const first = await command(db, request, "nf08-fixed-operation");
  assert.deepEqual(await command(db, request, "nf08-fixed-operation"), first);
  assert.equal(db.paths(`${root}/purchase_invoices/`).length, 1);
  assert.equal(db.paths(`${root}/financial_transactions/`).length, 1);
  assert.equal(db.read(`${root}/medicines/medicine-a`).quantity, 12);
  assert.equal(db.read(`${root}/medicines/medicine-b`).quantity, 23);
  assert.equal(db.read(`${root}/suppliers/nf08-supplier`).currentBalance, 22);

  const secondDb = fixture();
  const execute = withLostResponseAfterCommit(operationId => command(secondDb, validPurchase(), operationId));
  const recovered = await executeWithOperationReplay({operationId: "nf08-lost-response", execute, readCommitted: async () => null, maxAttempts: 2});
  assert.equal(recovered.recovered, true);
  assert.equal(recovered.attempts, 2);
  assert.equal(secondDb.paths(`${root}/purchase_invoices/`).length, 1);
  assert.equal(secondDb.paths(`${root}/financial_transactions/`).length, 1);
  assert.equal(secondDb.read(`${root}/medicines/medicine-a`).quantity, 12);
  assert.equal(secondDb.read(`${root}/medicines/medicine-b`).quantity, 23);
});


test("TC-PH-NF08 injected failure before commit leaves no partial effect and retry succeeds once", async () => {
  const db = fixture(); const request = validPurchase();
  const before = [...db.documents.entries()];
  const failingCommand = buildPharmacyFinanceCommand({db, testHooks: {
    beforeCommit: async () => { throw new Error("NF08 injected pre-commit failure"); },
  }});
  await assert.rejects(failingCommand({auth, data: {
    pharmacyId: "nf08-pharmacy", command: "receivePurchase",
    operationId: "nf08-failpoint-operation", payload: request,
  }}), /injected pre-commit failure/);
  assert.deepEqual([...db.documents.entries()], before);

  const recovered = await command(db, request, "nf08-failpoint-operation");
  assert.equal(recovered.success, true);
  assert.equal(db.paths(`${root}/purchase_invoices/`).length, 1);
  assert.equal(db.paths(`${root}/financial_transactions/`).length, 1);
  assert.equal(db.read(`${root}/medicines/medicine-a`).quantity, 12);
  assert.equal(db.read(`${root}/medicines/medicine-b`).quantity, 23);
  assert.equal(db.read(`${root}/suppliers/nf08-supplier`).currentBalance, 22);
});
