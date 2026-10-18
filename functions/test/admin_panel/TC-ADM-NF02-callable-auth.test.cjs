"use strict";

const assert = require("node:assert/strict");
const {after, before, test} = require("node:test");
const {randomUUID} = require("node:crypto");
const admin = require("firebase-admin");

const projectId = "demo-roshita-admin-nf";
const suffix = randomUUID().replaceAll("-", "");
const urls = Object.fromEntries(["registrationCommand", "adminVisibilityCommand", "adminBroadcastCommand"].map((name) =>
  [name, `http://127.0.0.1:15001/${projectId}/us-central1/${name}`]));
const pharmacyId = `adm_nf02_${suffix}`;
const requestId = `adm_nf02_${suffix}`;
const app = admin.initializeApp({projectId}, `adm-nf02-${suffix}`);
const db = admin.firestore(app);
const auth = admin.auth(app);
let users = {};
let beforeState;

async function createTestAccount(label) {
  const response = await fetch("http://127.0.0.1:19099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key", {
    method: "POST", headers: {"content-type": "application/json"},
    body: JSON.stringify({email: `${label}-${suffix}@example.invalid`, password: `Adm-${suffix.slice(0, 14)}!x`, returnSecureToken: true}),
  });
  const body = await response.json();
  assert.equal(response.ok, true, `Auth Emulator fixture creation failed: ${body.error?.message || response.status}`);
  return {uid: body.localId, idToken: body.idToken};
}

const payloads = {
  registrationCommand: {action: "decision", requestId, decision: "approve", expectedRevision: 0, operationId: `op_${suffix}`},
  adminVisibilityCommand: {pharmacyId, operationId: `op_${suffix}`, hidden: true, expectedHidden: false, expectedRevision: 0, reason: "TC-ADM-NF02 fixture"},
  adminBroadcastCommand: {action: "create", operationId: `op_${suffix}`, title: "اختبار أمني", body: "بيانات اختبار محلية", targetType: "users"},
};

async function call(name, token, data = payloads[name]) {
  const response = await fetch(urls[name], {
    method: "POST",
    headers: {"content-type": "application/json", ...(token ? {authorization: `Bearer ${token}`} : {})},
    body: JSON.stringify({data}),
  });
  const body = await response.json();
  return {httpStatus: response.status, code: body.error?.status || "OK", body};
}

async function expectRejected(name, token, expectedCode) {
  const result = await call(name, token);
  assert.equal(result.code, expectedCode, `${name} expected ${expectedCode}, got HTTP ${result.httpStatus} ${JSON.stringify(result.body)}`);
}

async function auditIds() {
  const snapshot = await db.collection("adminAuditLogs").get();
  return snapshot.docs.map((item) => item.id).sort();
}

before(async () => {
  assert.equal(process.env.GCLOUD_PROJECT, projectId, "isolated demo project required");
  users = {
    ordinary: await createTestAccount("ordinary"),
    inactive: await createTestAccount("inactive-admin"),
  };
  await db.doc(`adminEmployees/${users.inactive.uid}`).set({isActive: false, role: "super_admin", name: "TC-ADM-NF02"});
  await db.doc(`pharmacies/${pharmacyId}`).set({isBlocked: false, visibilityRevision: 0, name: "NF02 fixture"});
  await db.doc(`pharmacyRequests/${requestId}`).set({status: "pending", revision: 0, ownerUid: `owner_${suffix}`});
  beforeState = {
    pharmacy: (await db.doc(`pharmacies/${pharmacyId}`).get()).data(),
    request: (await db.doc(`pharmacyRequests/${requestId}`).get()).data(),
    auditIds: await auditIds(),
    broadcasts: (await db.collection("adminBroadcastNotifications").get()).docs.map((item) => item.id).sort(),
  };
});

after(async () => {
  for (const value of Object.values(users)) {
    if (value?.uid) await auth.deleteUser(value.uid).catch(() => {});
  }
  await Promise.all([
    db.doc(`adminEmployees/${users.inactive?.uid || "missing"}`).delete().catch(() => {}),
    db.doc(`pharmacies/${pharmacyId}`).delete().catch(() => {}),
    db.doc(`pharmacyRequests/${requestId}`).delete().catch(() => {}),
    app.delete(),
  ]);
});

test("TC-ADM-NF02 rejects unauthenticated and malformed/expired bearer calls for every critical admin command", async () => {
  for (const name of Object.keys(urls)) {
    await expectRejected(name, null, "UNAUTHENTICATED");
    await expectRejected(name, "not-a-valid-or-expired-firebase-token", "UNAUTHENTICATED");
  }
});

test("TC-ADM-NF02 rejects an authenticated ordinary account for every critical admin command", async () => {
  for (const name of Object.keys(urls)) await expectRejected(name, users.ordinary.idToken, "PERMISSION_DENIED");
});

test("TC-ADM-NF02 rejects an inactive admin account before applying any change", async () => {
  for (const name of Object.keys(urls)) await expectRejected(name, users.inactive.idToken, "PERMISSION_DENIED");
  assert.deepEqual((await db.doc(`pharmacies/${pharmacyId}`).get()).data(), beforeState.pharmacy);
  assert.deepEqual((await db.doc(`pharmacyRequests/${requestId}`).get()).data(), beforeState.request);
  assert.deepEqual(await auditIds(), beforeState.auditIds);
  assert.deepEqual((await db.collection("adminBroadcastNotifications").get()).docs.map((item) => item.id).sort(), beforeState.broadcasts);
});
