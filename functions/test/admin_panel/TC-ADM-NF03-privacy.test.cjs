"use strict";

const assert = require("node:assert/strict");
const {after, before, test} = require("node:test");
const {app, auth, createAccount, db, projectId, suffix} = require("./emulator-helpers.cjs");

let reviewer;
const listPath = "adminLists/users";
const rowPath = `adminLists/users/adminListRows/adm_nf03_${suffix}`;
const userPath = `users/adm_nf03_${suffix}`;

before(async () => {
  assert.equal(process.env.GCLOUD_PROJECT, projectId);
  reviewer = await createAccount("nf03_reviewer");
  await db.doc(`adminEmployees/${reviewer.uid}`).set({isActive: true, role: "super_admin", name: "NF03 Reviewer"});
  await db.doc(listPath).set({schemaVersion: 1, ready: true});
  await db.doc(userPath).set({fullName: "Synthetic account", isActive: true, createdAt: new Date(),
    medicalHistory: "PRIVATE_MEDICAL_SENTINEL", medicines: ["PRIVATE_MEDICINE_SENTINEL"], passwordHash: "PRIVATE_HASH_SENTINEL"});
  const deadline = Date.now() + 12000;
  while (!(await db.doc(rowPath).get()).exists && Date.now() < deadline) await new Promise((resolve) => setTimeout(resolve, 100));
  assert.equal((await db.doc(rowPath).get()).exists, true, "user privacy projection trigger did not complete");
});

after(async () => {
  await Promise.all([
    reviewer?.uid ? auth.deleteUser(reviewer.uid).catch(() => {}) : Promise.resolve(),
    reviewer?.uid ? db.doc(`adminEmployees/${reviewer.uid}`).delete().catch(() => {}) : Promise.resolve(),
    db.doc(rowPath).delete().catch(() => {}),
    db.doc(userPath).delete().catch(() => {}),
    db.doc(listPath).delete().catch(() => {}),
    app.delete(),
  ]);
});

test("TC-ADM-NF03 returns only allowlisted account-summary fields to the admin client", async () => {
  const response = await fetch(`http://127.0.0.1:15001/${projectId}/us-central1/adminList`, {
    method: "POST", headers: {"content-type": "application/json", authorization: `Bearer ${reviewer.idToken}`},
    body: JSON.stringify({data: {kind: "users"}}),
  });
  const body = await response.json();
  assert.equal(response.status, 200, JSON.stringify(body));
  const serialized = JSON.stringify(body);
  for (const sentinel of ["PRIVATE_MEDICAL_SENTINEL", "PRIVATE_MEDICINE_SENTINEL", "PRIVATE_HASH_SENTINEL"]) {
    assert.equal(serialized.includes(sentinel), false, `private sentinel leaked: ${sentinel}`);
  }
  assert.equal(body.result.rows[0].fullName, "Synthetic account");
  assert.equal(body.result.rows[0].accountStatus, "active");
});
