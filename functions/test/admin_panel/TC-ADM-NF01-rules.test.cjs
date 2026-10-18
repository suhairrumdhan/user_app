"use strict";

const assert = require("node:assert/strict");
const {after, before, test} = require("node:test");
const {randomUUID} = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const {assertFails, initializeTestEnvironment} = require("@firebase/rules-unit-testing");
const {deleteDoc, doc, getDoc, setDoc} = require("firebase/firestore");
const {deleteObject, getBytes, ref, uploadString} = require("firebase/storage");

const projectId = "demo-roshita-admin-nf";
const root = path.resolve(__dirname, "../../..");
const runId = randomUUID().replaceAll("-", "");
const auditPath = `adminAuditLogs/adm_nf01_${runId}`;
const employeePath = `adminEmployees/adm_nf01_${runId}`;
const objectPath = `pharmacy_requests_uploads/adm_nf01_${runId}/protected.txt`;
let environment;

before(async () => {
  assert.equal(process.env.GCLOUD_PROJECT, projectId, "isolated demo project required");
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {host: "127.0.0.1", port: 18080, rules: fs.readFileSync(path.join(root, "firestore.rules"), "utf8")},
    storage: {host: "127.0.0.1", port: 19199, rules: fs.readFileSync(path.join(root, "storage.rules"), "utf8")},
  });
});

after(async () => {
  if (!environment) return;
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const storage = context.storage();
    await Promise.all([deleteDoc(doc(db, auditPath)), deleteDoc(doc(db, employeePath))]);
    await deleteObject(ref(storage, objectPath)).catch(() => {});
  });
  await environment.cleanup();
});

test("TC-ADM-NF01 blocks unauthenticated and ordinary-user Firestore/Storage reads and writes without changing fixtures", async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), auditPath), {event: "baseline", runId});
    await setDoc(doc(context.firestore(), employeePath), {isActive: true, name: "test-only"});
    await uploadString(ref(context.storage(), objectPath), "baseline-" + runId, "raw", {contentType: "text/plain"});
  });

  const before = await environment.withSecurityRulesDisabled(async (context) => ({
    audit: (await getDoc(doc(context.firestore(), auditPath))).data(),
    employee: (await getDoc(doc(context.firestore(), employeePath))).data(),
    object: Array.from(await getBytes(ref(context.storage(), objectPath))),
  }));

  const contexts = [
    environment.unauthenticatedContext(),
    environment.authenticatedContext(`ordinary_${runId}`),
  ];
  for (const context of contexts) {
    const db = context.firestore();
    const storage = context.storage();
    await assertFails(getDoc(doc(db, auditPath)));
    await assertFails(getDoc(doc(db, employeePath)));
    await assertFails(setDoc(doc(db, auditPath), {event: "tampered", runId}));
    await assertFails(getBytes(ref(storage, objectPath)));
    await assertFails(uploadString(ref(storage, objectPath), "tampered", "raw", {contentType: "text/plain"}));
  }

  const after = await environment.withSecurityRulesDisabled(async (context) => ({
    audit: (await getDoc(doc(context.firestore(), auditPath))).data(),
    employee: (await getDoc(doc(context.firestore(), employeePath))).data(),
    object: Array.from(await getBytes(ref(context.storage(), objectPath))),
  }));
  assert.deepEqual(after, before, "denied attempts must leave Firestore and Storage unchanged");
});
