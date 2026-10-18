"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {Timestamp} = require("firebase-admin/firestore");
const {pharmacyVisibleInSearch, pharmacyAcceptsNewOrders, medicineSaleState} = require("../../src/domain/availability-policy");
const {buildMedicineSearchIndex, refreshMedicineSearchIndex,
  searchProfileChanged} = require("../../src/domain/medicine-search-index");
const {FakeFirestore} = require("./helpers/fake-firestore");

const instant = Date.UTC(2026, 8, 14);
const pharmacy = {status: "approved", isOnline: true, isActive: true, pharmacyName: "صيدلية",
  location: {latitude: 32.8, longitude: 13.2}, acceptedInsuranceCodes: ["TEST"]};
const medicine = {name: "LASILIX40 MG", scientificName: "Furosemide", quantity: 3,
  reservedQuantity: 1, pieceQuantity: 0, reservedPieceQuantity: 0, unitsPerPackage: 10,
  sellByPiece: true, sellingPrice: 20, isActive: true,
  expiryDate: Timestamp.fromMillis(instant + 1000)};
const STOCK = "pharmacies/pharmacy/medicines/medicine";
const INDEX = "medicine_search_index/pharmacy_medicine";
const project = (overrides = {}, profile = pharmacy) => buildMedicineSearchIndex({
  pharmacyId: "pharmacy", medicineId: "medicine", pharmacy: profile,
  medicine: {...medicine, ...overrides}, instant,
});

test("new index contains searchable tokens and current unreserved package/piece quantities", () => {
  const index = project();
  assert.equal(index.indexVersion, 8);
  assert.equal(index.available, true);
  assert.equal(index.availableQuantity, 2);
  assert.equal(index.availablePieceQuantity, 20);
  assert.equal(index.piecePrice, 2);
  assert.ok(index.searchTokens.includes("LASILIX"));
  assert.ok(index.searchTokens.includes("LASILIX 40 MG"));
  assert.ok(index.suggestionPrefixes.includes("LASILIX40"));
  assert.equal(index.expiryAt.toMillis(), instant + 1000);
});

for (const [label, change] of Object.entries({
  blocked: {isBlocked: true}, inactive: {isActive: false},
  pending: {status: "pending"}, missingApproval: {status: undefined},
})) {
  test(`${label} pharmacy cannot advertise or accept new orders`, () => {
    const profile = {...pharmacy, ...change};
    assert.equal(pharmacyAcceptsNewOrders(profile), false);
    assert.equal(project({}, profile).available, false);
  });
}

for (const isOnline of [false, undefined]) {
  test(`receiving ${isOnline} prevents new orders without hiding a visible pharmacy`, () => {
    const profile = {...pharmacy, isOnline};
    assert.equal(pharmacyVisibleInSearch(profile), true);
    assert.equal(pharmacyAcceptsNewOrders(profile), false);
    assert.equal(project({}, profile).available, true);
    assert.equal(project({}, profile).pharmacyAcceptingOrders, false);
  });
}

test("piece estimates use the configured price or package conversion, never the package price itself", () => {
  assert.equal(project({piecePrice: 0}).piecePrice, 2);
  assert.equal(project({piecePrice: null}).piecePrice, 2);
  assert.equal(project({piecePrice: 3}).piecePrice, 3);
  assert.equal(project({piecePrice: null, unitsPerPackage: 0}).piecePrice, 0);
});

test("exact expiry boundary is unavailable even without another stock write", () => {
  assert.equal(medicineSaleState(medicine, instant + 999).saleable, true);
  assert.equal(medicineSaleState(medicine, instant + 1000).saleable, false);
  assert.equal(project({expiryDate: Timestamp.fromMillis(instant)}).available, false);
});

for (const expiryDate of ["not-a-date", "", {}, 123]) {
  test(`malformed expiry ${JSON.stringify(expiryDate)} never advertises stock`, () => {
    assert.equal(project({expiryDate}).invalidExpiry, true);
    assert.equal(project({expiryDate}).available, false);
  });
}

test("absent expiry remains distinct from malformed supplied expiry", () => {
  assert.equal(project({expiryDate: null}).invalidExpiry, false);
  assert.equal(project({expiryDate: null}).available, true);
});

test("invalid and fully reserved counters never publish false availability", () => {
  assert.equal(project({reservedQuantity: 4}).invalidStock, true);
  assert.equal(project({reservedQuantity: 4}).available, false);
  assert.equal(project({reservedQuantity: 3}).available, false);
  assert.equal(project({reservedPieceQuantity: 11}).availableQuantity, 0);
});

test("private inventory fields cannot leak into a public index projection", () => {
  const index = project({purchasePrice: 7, internalNotes: "private", password: "not-public",
    supplier: {privateAccount: "not-public"}, imageUrl: {private: true}});
  assert.equal(index.supplier, null);
  assert.equal(index.imageUrl, null);
  for (const field of ["purchasePrice", "internalNotes", "password"]) {
    assert.equal(Object.hasOwn(index, field), false);
  }
});

test("stock event creates a missing index without opening the pharmacy app", async () => {
  const db = new FakeFirestore({"pharmacies/pharmacy": pharmacy, [STOCK]: medicine});
  await refreshMedicineSearchIndex({db, pharmacyId: "pharmacy", medicineId: "medicine", clock: () => instant});
  assert.equal(db.read(INDEX).availableQuantity, 2);
  assert.equal(db.read(INDEX).medicineName, medicine.name);
});

test("delayed refresh uses current stock and pharmacy profile instead of stale index values", async () => {
  const db = new FakeFirestore({"pharmacies/pharmacy": {...pharmacy, isBlocked: true},
    [STOCK]: {...medicine, reservedQuantity: 2},
    [INDEX]: {...project(), availableQuantity: 500, privateLegacyField: "remove"}});
  await refreshMedicineSearchIndex({db, pharmacyId: "pharmacy", medicineId: "medicine", clock: () => instant});
  assert.equal(db.read(INDEX).available, false);
  assert.equal(db.read(INDEX).availableQuantity, 1);
  assert.equal(Object.hasOwn(db.read(INDEX), "privateLegacyField"), false);
  db.write("pharmacies/pharmacy", pharmacy);
  await refreshMedicineSearchIndex({db, pharmacyId: "pharmacy", medicineId: "medicine", clock: () => instant});
  assert.equal(db.read(INDEX).available, true);
});

for (const missing of [STOCK, "pharmacies/pharmacy"]) {
  test(`deleted ${missing} removes its obsolete index`, async () => {
    const db = new FakeFirestore({"pharmacies/pharmacy": pharmacy, [STOCK]: medicine, [INDEX]: project()});
    db.delete(missing);
    await refreshMedicineSearchIndex({db, pharmacyId: "pharmacy", medicineId: "medicine", clock: () => instant});
    assert.equal(db.read(INDEX), undefined);
  });
}

test("profile index version markers do not recursively trigger full rebuilds", () => {
  assert.equal(searchProfileChanged(pharmacy, {...pharmacy, medicineSearchIndexVersion: 7}), false);
  assert.equal(searchProfileChanged(pharmacy, {...pharmacy, isOnline: false}), true);
  assert.equal(searchProfileChanged(pharmacy, {...pharmacy, isBlocked: true}), true);
  assert.equal(searchProfileChanged(pharmacy, {...pharmacy, location: {latitude: 31, longitude: 12}}), true);
});
