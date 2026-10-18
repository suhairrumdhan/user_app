"use strict";

const assert = require("node:assert/strict");
const {after, before, test} = require("node:test");
const {app, auth, callRegistration, createAccount, db, projectId, suffix} = require("./emulator-helpers.cjs");

let reviewer;
let owner;
const requestId = `adm_nf04_${suffix}`;

before(async () => {
  assert.equal(process.env.GCLOUD_PROJECT, projectId);
  reviewer = await createAccount("reviewer");
  owner = await createAccount("owner");
  await db.doc(`adminEmployees/${reviewer.uid}`).set({isActive: true, role: "super_admin", name: "NF04 Reviewer"});
  await db.doc(`pharmacyRequests/${requestId}`).set({id: requestId, ownerUid: owner.uid, status: "pending", revision: 0, version: 1, pharmacyName: "NF04 fixture"});
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

test("TC-ADM-NF04 serializes competing approve/reject review commands into one committed decision and audit", async () => {
  const common = {action: "decision", requestId, expectedRevision: 0};
  const [first, second] = await Promise.all([
    callRegistration({...common, decision: "reject", reason: "اختبار رفض متزامن", operationId: `nf04_reject_${suffix}`}, reviewer.idToken),
    callRegistration({...common, decision: "changes", reason: "اختبار استكمال متزامن", operationId: `nf04_changes_${suffix}`}, reviewer.idToken),
  ]);
  const results = [first, second];
  const committed = results.filter((entry) => entry.status === 200 && entry.body.result);
  const denied = results.filter((entry) => entry.body.error && ["ABORTED", "FAILED_PRECONDITION"].includes(entry.body.error.status));
  assert.equal(committed.length, 1, JSON.stringify(results));
  assert.equal(denied.length, 1, JSON.stringify(results));

  const request = (await db.doc(`pharmacyRequests/${requestId}`).get()).data();
  assert.equal(request.revision, 1);
  assert.ok(["rejected", "requires_changes"].includes(request.status));
  const [history, notifications, audits] = await Promise.all([
    db.collection(`pharmacyRequests/${requestId}/history`).get(),
    db.collection(`pharmacyRequests/${requestId}/notifications`).get(),
    db.collection("adminAuditLogs").where("targetId", "==", requestId).get(),
  ]);
  assert.equal(history.size, 1);
  assert.equal(notifications.size, 1);
  assert.equal(audits.size, 1);
  const audit = audits.docs[0].data();
  assert.equal(audit.performedByUid, reviewer.uid);
  assert.equal(audit.before.revision, 0);
  assert.equal(audit.after.revision, 1);
  assert.equal(audit.after.status, request.status);
});
