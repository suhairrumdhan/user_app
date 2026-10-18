"use strict";
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {before, after, test} = require("node:test");
const {assertFails, initializeTestEnvironment} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc} = require("firebase/firestore");
const {getBytes, ref, uploadString} = require("firebase/storage");
const {assertIsolatedEnvironment, buildEmulatorEnvironment} = require("../helpers/environment");
Object.assign(process.env, buildEmulatorEnvironment(process.env));
const config = assertIsolatedEnvironment();
const root = path.resolve(__dirname, "..", "..", "..");
let env;
before(async () => { env = await initializeTestEnvironment({projectId: config.projectId, firestore: {host: "127.0.0.1", port: 8080, rules: fs.readFileSync(path.join(root, "firestore.rules"), "utf8")}, storage: {host: "127.0.0.1", port: 9199, rules: fs.readFileSync(path.join(root, "storage.rules"), "utf8")}}); });
after(async () => { if (env) await env.cleanup(); });
test("TC-PH-NF01 rejects unauthenticated Firestore and Storage access", async () => {
  const pharmacy = "pharmacies/nf01-pharmacy"; const file = "users/nf01-user/prescriptions/nf01.txt";
  await env.withSecurityRulesDisabled(async c => { await setDoc(doc(c.firestore(), pharmacy), {marker: "nf01"}); await uploadString(ref(c.storage(), file), "NF01", "raw"); });
  let before; await env.withSecurityRulesDisabled(async c => { before = await getDoc(doc(c.firestore(), pharmacy)); });
  const db = env.unauthenticatedContext().firestore(); const storage = env.unauthenticatedContext().storage();
  await assertFails(getDoc(doc(db, pharmacy))); await assertFails(setDoc(doc(db, pharmacy + "/probes/nf01-probe"), {probe: true})); await assertFails(getBytes(ref(storage, file)));
  let after; let probe; await env.withSecurityRulesDisabled(async c => { after = await getDoc(doc(c.firestore(), pharmacy)); probe = await getDoc(doc(c.firestore(), pharmacy + "/probes/nf01-probe")); }); assert.deepEqual(after.data(), before.data()); assert.equal(probe.exists(), false);
  const endpoint = "http://127.0.0.1:5001/demo-roshita-f02/us-central1/executeOrderCommand";
  for (const authorization of [undefined, "Bearer expired.invalid.token"]) {
    const headers = {"content-type": "application/json"};
    if (authorization) headers.authorization = authorization;
    const response = await fetch(endpoint, {method: "POST", headers, body: JSON.stringify({data: {command: "confirmFullOrder", orderId: "nf01-order"}})});
    assert.ok([401, 403].includes(response.status), `Unexpected HTTP ${response.status}`);
  }
});

