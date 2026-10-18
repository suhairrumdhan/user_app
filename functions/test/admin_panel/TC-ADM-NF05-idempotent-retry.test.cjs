"use strict";

const assert = require("node:assert/strict");
const {after, before, test} = require("node:test");
const {app, auth, callRegistration, createAccount, db, projectId, suffix} = require("./emulator-helpers.cjs");

let reviewer;
let owner;
const requestId = `adm_nf05_${suffix}`;
const operationId = `nf05_retry_${suffix}`;

before(async () => {
  assert.equal(process.env.GCLOUD_PROJECT, projectId);
  reviewer = await createAccount("reviewer");
  owner = await createAccount("owner");
  await db.doc(`adminEmployees/${reviewer.uid}`).set({isActive: true, role: "super_admin", name: "NF05 Reviewer"});
  await db.doc(`pharmacyRequests/${requestId}`).set({id: requestId, ownerUid: owner.uid, status: "pending", revision: 0, version: 1, pharmacyName: "NF05 fixture"});
});

after(async () => {
  await Promise.all([
    reviewer?.uid ? auth.deleteUser(reviewer.uid).catch(() => {}) : Promise.resolve(),
    owner?.uid ? auth.deleteUser(owner.uid).catch(() => {}) : Promise.resolve(),
    reviewer?.uid ? db.doc(`adminEmployees/${reviewer.uid}`).delete().catch(() => {}) : Promise.resolve(),
    db.doc(`pharmacyRequests/${requestId}`).delete().catch(() => {}),
    app.delete(),
  ]);
});

test("TC-ADM-NF05 replay after an uncertain response returns the committed result without duplicate decision or audit", async () => {
  const command = {action: "decision", requestId, decision: "changes", reason: "إعادة محاولة اختبارية", expectedRevision: 0, operationId};
  const first = await callRegistration(command, reviewer.idToken);
  assert.equal(first.status, 200, JSON.stringify(first.body));
  assert.equal(first.body.result.status, "requires_changes");
  const replay = await callRegistration(command, reviewer.idToken);
  assert.equal(replay.status, 200, JSON.stringify(replay.body));
  assert.deepEqual(replay.body.result, first.body.result);

  const [request, history, notifications, audits] = await Promise.all([
    db.doc(`pharmacyRequests/${requestId}`).get(),
    db.collection(`pharmacyRequests/${requestId}/history`).get(),
    db.collection(`pharmacyRequests/${requestId}/notifications`).get(),
    db.collection("adminAuditLogs").where("targetId", "==", requestId).get(),
  ]);
  assert.equal(request.data().revision, 1);
  assert.equal(history.size, 1);
  assert.equal(notifications.size, 1);
  assert.equal(audits.size, 1);
  assert.equal(audits.docs[0].data().operationId, operationId);
});
