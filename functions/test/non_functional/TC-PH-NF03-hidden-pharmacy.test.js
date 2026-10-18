"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {before, after, test} = require("node:test");
const {assertSucceeds, initializeTestEnvironment} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc} = require("firebase/firestore");
const {pharmacyVisibleInSearch, pharmacyAcceptsNewOrders} = require("../../src/domain/availability-policy");
const {buildMedicineSearchIndex} = require("../../src/domain/medicine-search-index");
const {assertIsolatedEnvironment, buildEmulatorEnvironment} = require("../helpers/environment");

Object.assign(process.env, buildEmulatorEnvironment(process.env));
const config = assertIsolatedEnvironment();
const root = path.resolve(__dirname, "..", "..", "..");
let env;

before(async () => {
  env = await initializeTestEnvironment({projectId: config.projectId, firestore: {host: "127.0.0.1", port: 8080, rules: fs.readFileSync(path.join(root, "firestore.rules"), "utf8")}});
});
after(async () => { if (env) await env.cleanup(); });

test("TC-PH-NF03 hidden pharmacy keeps internal access but disappears from search and new orders", async () => {
  const pharmacy = {id: "nf03-pharmacy", pharmacyId: "nf03-pharmacy", pharmacyName: "NF03", status: "approved", isActive: true, isOnline: true, isBlocked: true};
  const medicine = {id: "medicine", name: "NF03 medicine", scientificName: "NF03", quantity: 5, reservedQuantity: 0, isActive: true, sellingPrice: 10, expiryDate: new Date("2099-01-01T00:00:00Z")};
  assert.equal(pharmacyVisibleInSearch(pharmacy), false);
  assert.equal(pharmacyAcceptsNewOrders(pharmacy), false);
  const index = buildMedicineSearchIndex({pharmacyId: pharmacy.id, medicineId: medicine.id, pharmacy, medicine, instant: Date.now()});
  assert.equal(index.pharmacyVisible, false);
  assert.equal(index.pharmacyAcceptingOrders, false);
  assert.equal(index.available, false);

  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), `pharmacies/${pharmacy.id}`), pharmacy);
    await setDoc(doc(context.firestore(), `pharmacies/${pharmacy.id}/medicines/${medicine.id}`), medicine);
  });
  const owner = env.authenticatedContext(pharmacy.id, {email_verified: true}).firestore();
  await assertSucceeds(getDoc(doc(owner, `pharmacies/${pharmacy.id}/medicines/${medicine.id}`)));
  await assertSucceeds(setDoc(doc(owner, `pharmacies/${pharmacy.id}`), {phone: "internal-operation-ok"}, {merge: true}));
});

