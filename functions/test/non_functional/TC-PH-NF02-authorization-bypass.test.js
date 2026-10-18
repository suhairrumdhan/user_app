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

test("TC-PH-NF02 rejects forged pharmacy ownership and keeps the authorized control working", async () => {
  const pharmacyB = "pharmacies/nf02-pharmacy-b";
  const protectedFile = "pharmacies/nf02-pharmacy-b/private/nf02.pdf";
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), pharmacyB), {
      id: "nf02-pharmacy-b", pharmacyId: "nf02-pharmacy-b", name: "NF02 Pharmacy B", status: "approved", isActive: true, phone: "before",
    });
    await uploadString(ref(context.storage(), protectedFile), "NF02 protected", "raw", {contentType: "application/pdf"});
  });

  const forged = env.authenticatedContext("nf02-employee-a", {
    actorType: "pharmacy_employee", pharmacyId: "nf02-pharmacy-b", employeeId: "forged-owner", sessionId: "forged-session", credentialVersion: 1, role: "owner",
  });
  const forgedDb = forged.firestore();
  await assertFails(getDoc(doc(forgedDb, pharmacyB)));
  await assertFails(setDoc(doc(forgedDb, pharmacyB), {phone: "tampered"}, {merge: true}));
  await assertFails(getBytes(ref(forged.storage(), protectedFile)));

  const owner = env.authenticatedContext("nf02-pharmacy-b");
  await assertSucceeds(getDoc(doc(owner.firestore(), pharmacyB)));
  await assertSucceeds(setDoc(doc(owner.firestore(), pharmacyB), {phone: "authorized-control"}, {merge: true}));
  await assertSucceeds(getBytes(ref(owner.storage(), protectedFile)));

  let after;
  await env.withSecurityRulesDisabled(async context => { after = await getDoc(doc(context.firestore(), pharmacyB)); });
  assert.equal(after.data().phone, "authorized-control");
  assert.equal(after.data().role, undefined);
});
