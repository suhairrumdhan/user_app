"use strict";

const assert = require("node:assert/strict");
const {after, before, test} = require("node:test");
const {buildAdminBroadcast} = require("../../src/domain/admin-broadcast");
const {app, auth, createAccount, db, projectId, suffix} = require("./emulator-helpers.cjs");

let reviewer;
let service;
let deliveryCalls;
const userIds = [`nf06_ok_${suffix}`, `nf06_bad_${suffix}`];

before(async () => {
  assert.equal(process.env.GCLOUD_PROJECT, projectId);
  reviewer = await createAccount("nf06_reviewer");
  await db.doc(`adminEmployees/${reviewer.uid}`).set({isActive: true, role: "super_admin", name: "NF06 Reviewer"});
  await Promise.all(userIds.map((id) => db.doc(`users/${id}`).set({fullName: id, createdAt: new Date()})));
  deliveryCalls = new Map();
  service = buildAdminBroadcast({db, auth, sendUser: async ({userId}) => {
    deliveryCalls.set(userId, (deliveryCalls.get(userId) || 0) + 1);
    return userId === userIds[0] ? {success: true} : {success: false, reason: "invalid-token"};
  }});
});

after(async () => {
  const removals = [];
  for (const id of userIds) {
    const snapshot = await db.collection(`users/${id}/notifications`).get();
    snapshot.docs.forEach((entry) => removals.push(entry.ref.delete()));
    removals.push(db.doc(`users/${id}`).delete());
  }
  await Promise.all(removals);
  const broadcasts = await db.collection("adminBroadcastNotifications").where("createdBy", "==", reviewer?.uid || "").get();
  for (const doc of broadcasts.docs) {
    const recipients = await doc.ref.collection("recipients").get();
    await Promise.all(recipients.docs.map((entry) => entry.ref.delete()));
    await doc.ref.delete();
  }
  for (const collection of ["adminAuditLogs", "adminOperations"]) {
    const owned = await db.collection(collection).where(collection === "adminOperations" ? "actorUid" : "performedByUid", "==", reviewer?.uid || "").get();
    await Promise.all(owned.docs.map((entry) => entry.ref.delete()));
  }
  await Promise.all([
    reviewer?.uid ? auth.deleteUser(reviewer.uid).catch(() => {}) : Promise.resolve(),
    reviewer?.uid ? db.doc(`adminEmployees/${reviewer.uid}`).delete().catch(() => {}) : Promise.resolve(),
    app.delete(),
  ]);
});

test("TC-ADM-NF06 counts mixed delivery accurately and does not resend successful recipients", async () => {
  const operationId = `nf06_${suffix}`;
  const request = {auth: {uid: reviewer.uid, token: {auth_time: Math.floor(Date.now() / 1000)}}, data: {
    action: "create", operationId, title: "NF06 synthetic", body: "Partial delivery fixture", targetType: "users",
  }};
  const queued = await service.command(request);
  await service.process(queued.broadcastId);
  const broadcastRef = db.doc(`adminBroadcastNotifications/${queued.broadcastId}`);
  const broadcast = (await broadcastRef.get()).data();
  assert.equal(broadcast.status, "partial");
  assert.equal(broadcast.total, 2);
  assert.equal(broadcast.succeeded, 1);
  assert.equal(broadcast.failed, 1);
  const recipients = await broadcastRef.collection("recipients").get();
  assert.deepEqual(recipients.docs.map((doc) => doc.data().status).sort(), ["failed", "succeeded"]);
  const successPath = `users/${userIds[0]}/notifications/admin_${queued.broadcastId}`;
  const failedPath = `users/${userIds[1]}/notifications/admin_${queued.broadcastId}`;
  assert.equal((await db.doc(successPath).get()).exists, true);
  assert.equal((await db.doc(failedPath).get()).exists, true);
  assert.equal(deliveryCalls.get(userIds[0]), 1);
  assert.equal(deliveryCalls.get(userIds[1]), 1);
  await service.process(queued.broadcastId);
  assert.equal(deliveryCalls.get(userIds[0]), 1, "successful recipient must not receive a duplicate push");
  assert.equal(deliveryCalls.get(userIds[1]), 1, "same-generation failed recipient must not be retried automatically");
  assert.equal((await broadcastRef.get()).data().succeeded, 1);
  assert.equal((await broadcastRef.get()).data().failed, 1);
});
