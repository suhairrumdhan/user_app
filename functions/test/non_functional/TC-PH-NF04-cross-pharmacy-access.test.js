"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {before, after, test} = require("node:test");
const {assertFails, assertSucceeds, initializeTestEnvironment} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc} = require("firebase/firestore");
const {getBytes, ref, uploadString} = require("firebase/storage");
const {assertIsolatedEnvironment, buildEmulatorEnvironment} = require("../helpers/environment");

Object.assign(process.env, buildEmulatorEnvironment(process.env));
const config = assertIsolatedEnvironment();
const root = path.resolve(__dirname, "..", "..", "..");
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: config.projectId,
    firestore: {host: "127.0.0.1", port: 8080, rules: fs.readFileSync(path.join(root, "firestore.rules"), "utf8")},
    storage: {host: "127.0.0.1", port: 9199, rules: fs.readFileSync(path.join(root, "storage.rules"), "utf8")},
  });
});

after(async () => { if (env) await env.cleanup(); });

test("TC-PH-NF04 isolates pharmacy records, beneficiary data, and protected files", async () => {
  const medicineA = "pharmacies/nf04-pharmacy-a/medicines/medicine-a";
  const medicineB = "pharmacies/nf04-pharmacy-b/medicines/medicine-b";
  const orderB = "orders/nf04-order-b";
  const fileB = "pharmacies/nf04-pharmacy-b/private/beneficiary-b.pdf";
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const id of ["nf04-pharmacy-a", "nf04-pharmacy-b"]) {
      await setDoc(doc(db, `pharmacies/${id}`), {id, pharmacyId: id, name: id, status: "approved", isActive: true});
    }
    await setDoc(doc(db, medicineA), {id: "medicine-a", name: "A", quantity: 5, reservedQuantity: 0, isActive: true});
    await setDoc(doc(db, medicineB), {id: "medicine-b", name: "B", quantity: 7, reservedQuantity: 0, isActive: true});
    await setDoc(doc(db, orderB), {schemaVersion: 3, orderId: "nf04-order-b", user: {userId: "nf04-user-b", name: "Private Beneficiary B"}, pharmacy: {pharmacyId: "nf04-pharmacy-b", pharmacyName: "B"}, status: "underReview", medicines: [], statusHistory: []});
    await uploadString(ref(context.storage(), fileB), "NF04 private beneficiary file", "raw", {contentType: "application/pdf"});
  });

  const pharmacyA = env.authenticatedContext("nf04-pharmacy-a", {email_verified: true});
  await assertSucceeds(getDoc(doc(pharmacyA.firestore(), medicineA)));
  await assertFails(getDoc(doc(pharmacyA.firestore(), medicineB)));
  await assertFails(setDoc(doc(pharmacyA.firestore(), medicineB), {quantity: 999}, {merge: true}));
  await assertFails(getDoc(doc(pharmacyA.firestore(), orderB)));
  await assertFails(getBytes(ref(pharmacyA.storage(), fileB)));

  const pharmacyB = env.authenticatedContext("nf04-pharmacy-b", {email_verified: true});
  await assertSucceeds(getDoc(doc(pharmacyB.firestore(), medicineB)));
  await assertSucceeds(getDoc(doc(pharmacyB.firestore(), orderB)));
  await assertSucceeds(getBytes(ref(pharmacyB.storage(), fileB)));

  let medicineAfter;
  await env.withSecurityRulesDisabled(async context => { medicineAfter = await getDoc(doc(context.firestore(), medicineB)); });
  assert.equal(medicineAfter.data().quantity, 7);
});

