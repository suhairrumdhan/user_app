"use strict";
// Run explicitly against local emulators; never part of the offline unit glob.
const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const {test, before, after} = require("node:test");
const {initializeTestEnvironment, assertFails, assertSucceeds} = require("@firebase/rules-unit-testing");
const {doc, setDoc, getDoc, updateDoc, serverTimestamp} = require("firebase/firestore");
const {ref, uploadString} = require("firebase/storage");
const admin = require("firebase-admin");
const {buildRegistrationCommand} = require("../src/domain/registration-commands");
const projectId = "demo-roshita-f02";
let env, app;
before(async () => {
  if (process.env.FIRESTORE_EMULATOR_HOST !== "127.0.0.1:8080") throw new Error("Local emulator required");
  env = await initializeTestEnvironment({projectId,
    firestore: {host: "127.0.0.1", port: 8080, rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8")},
    storage: {host: "127.0.0.1", port: 9199, rules: fs.readFileSync(path.join(__dirname, "../../storage.rules"), "utf8")}});
  app = admin.initializeApp({projectId}, "registration-tests");
});
after(async () => {if (env) await env.cleanup(); if (app) await app.delete();});
test("pending owner can read their decisions, but cannot create/approve a request or access operations", async () => {
  const uid = "reg-pending";
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), `pharmacyRequests/${uid}`), {id: uid, status: "pending"});
    await setDoc(doc(context.firestore(), `pharmacyRequests/${uid}/notifications/n1`), {isRead: false, title: "استكمال"});
  });
  const owner = env.authenticatedContext(uid, {email_verified: true}).firestore();
  const other = env.authenticatedContext("reg-other", {email_verified: true}).firestore();
  await assertSucceeds(getDoc(doc(owner, `pharmacyRequests/${uid}`)));
  await assertFails(getDoc(doc(other, `pharmacyRequests/${uid}`)));
  await assertFails(updateDoc(doc(owner, `pharmacyRequests/${uid}`), {status: "approved"}));
  await assertFails(setDoc(doc(owner, `pharmacies/${uid}`), {status: "approved"}));
  await assertFails(setDoc(doc(owner, `pharmacies/${uid}/medicines/m1`), {name: "x"}));
  await assertSucceeds(updateDoc(doc(owner, `pharmacyRequests/${uid}/notifications/n1`), {isRead: true, readAt: serverTimestamp()}));
  await assertFails(updateDoc(doc(owner, `pharmacyRequests/${uid}/notifications/n1`), {title: "tampered"}));
});
test("verified approved hidden owner retains internal access; unverified/disabled pharmacy does not", async () => {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), "pharmacies/reg-approved"), {status: "approved", isActive: true, isBlocked: true});
    await setDoc(doc(context.firestore(), "pharmacies/reg-disabled"), {status: "approved", isActive: false});
  });
  const verified = env.authenticatedContext("reg-approved", {email_verified: true}).firestore();
  const unverified = env.authenticatedContext("reg-approved", {email_verified: false}).firestore();
  const disabled = env.authenticatedContext("reg-disabled", {email_verified: true}).firestore();
  await assertSucceeds(setDoc(doc(verified, "pharmacies/reg-approved/medicines/m1"), {name: "legacy without lastUpdated"}));
  await assertFails(getDoc(doc(unverified, "pharmacies/reg-approved/medicines/m1")));
  await assertFails(setDoc(doc(disabled, "pharmacies/reg-disabled/medicines/m1"), {name: "x"}));
});
test("registration documents require verified owner, permitted type and immutable paths", async () => {
  const verified = env.authenticatedContext("reg-docs", {email_verified: true}).storage();
  const unverified = env.authenticatedContext("reg-unverified", {email_verified: false}).storage();
  const name = `proof-${Date.now()}.pdf`;
  await assertSucceeds(uploadString(ref(verified, `registration/reg-docs/${name}`), "test pdf", "raw", {contentType: "application/pdf"}));
  await assertFails(uploadString(ref(verified, `registration/reg-docs/${name}`), "overwrite", "raw", {contentType: "application/pdf"}));
  await assertFails(uploadString(ref(verified, `registration/foreign/${name}`), "x", "raw", {contentType: "application/pdf"}));
  await assertFails(uploadString(ref(unverified, `registration/reg-unverified/${name}`), "x", "raw", {contentType: "application/pdf"}));
});
test("actual Firestore transaction race commits only one decision and notification", async () => {
  const db = app.firestore();
  const uid = `reg-race-${Date.now()}`;
  const profile = {id: uid, ownerUid: uid, status: "pending", revision: 1, version: 1,
    pharmacyName: "P", ownerName: "O", licenseNumber: uid, ownerIdNumber: "ID", phoneNumber: "123",
    location: {address: "A", latitude: 0, longitude: 0}, licenseFileUrl: "https://example.test/legacy-license", ownerIdFileUrl: "https://example.test/legacy-id"};
  await db.doc(`pharmacyRequests/${uid}`).set(profile);
  await db.doc("adminEmployees/reg-admin").set({isActive: true, role: "super_admin"});
  const command = buildRegistrationCommand({db, auth: {getUser: async id => ({uid: id, email: `${id}@example.test`, emailVerified: true})}, bucket: {}});
  const decide = (decision, operationId) => command({auth: {uid: "reg-admin", token: {}}, data: {
    action: "decision", requestId: uid, expectedRevision: 1, decision, reason: "سبب الاختبار", operationId}});
  const results = await Promise.allSettled([decide("approve", "a" + uid), decide("reject", "b" + uid)]);
  assert.equal(results.filter(r => r.status === "fulfilled").length, 1);
  assert.equal((await db.doc(`pharmacyRequests/${uid}`).get()).data().revision, 2);
  assert.equal((await db.collection(`pharmacyRequests/${uid}/notifications`).get()).size, 1);
  assert.equal((await db.collection(`pharmacyRequests/${uid}/history`).get()).size, 1);
});
