"use strict";
const assert = require("node:assert/strict");
const test = require("node:test");
const {buildRegistrationCommand, statusOf, cleanProfile} = require("../src/domain/registration-commands");
const {FakeFirestore} = require("./f03/helpers/fake-firestore");
const profile = (uid = "owner") => ({pharmacyName: "صيدلية", ownerName: "المالك", licenseNumber: "L-1", ownerIdNumber: "ID-1", phoneNumber: "12345",
  location: {address: "طرابلس", latitude: 32, longitude: 13},
  licenseFilePath: `registration/${uid}/license.pdf`, ownerIdFilePath: `registration/${uid}/owner.pdf`});
function setup(seed = {}, users = {}) {
  const db = new FakeFirestore({"adminEmployees/admin": {isActive: true, role: "super_admin", name: "Admin"}, ...seed});
  db.doc = (path) => {const parts = path.split("/"); const id = parts.pop(); return db.collection(parts.join("/")).doc(id);};
  const auth = {getUser: async (uid) => ({uid, email: `${uid}@example.test`, emailVerified: true, disabled: false, ...users[uid]})};
  const bucket = {name: "demo.test", file: () => ({getMetadata: async () => [{size: "50", contentType: "application/pdf"}]})};
  const command = buildRegistrationCommand({db, auth, bucket});
  let id = 0;
  const call = (data, uid = "owner") => command({auth: {uid, token: {}}, data: {operationId: `op_${++id}`, expectedRevision: 0, ...data}});
  return {db, command, call};
}
test("status aliases and complete profile validation", () => {
  assert.equal(statusOf("needs_info"), "requires_changes");
  assert.equal(statusOf("accepted"), "approved");
  assert.equal(statusOf("unexpected"), "unknown");
  assert.throws(() => cleanProfile({}, true), {code: "invalid-argument"});
  assert.throws(() => cleanProfile({...profile(), location: {address: "x", latitude: 91, longitude: 0}}, true), {code: "invalid-argument"});
});
test("unverified owner cannot save or submit and cannot decide", async () => {
  const h = setup({}, {owner: {emailVerified: false}});
  await assert.rejects(h.call({action: "saveDraft", profile: {}}), {code: "permission-denied"});
  await assert.rejects(h.call({action: "submit", profile: profile()}), {code: "permission-denied"});
  await assert.rejects(h.call({action: "decision", requestId: "owner", decision: "approve"}), {code: "permission-denied"});
});
test("draft -> submit -> changes -> draft -> resubmit same request -> approve", async () => {
  const h = setup();
  await h.call({action: "saveDraft", profile: {pharmacyName: "مسودة"}});
  await h.call({action: "submit", profile: profile(), expectedRevision: 1});
  await h.call({action: "decision", requestId: "owner", decision: "changes", reason: "صحح الاسم", expectedRevision: 2}, "admin");
  await h.call({action: "saveDraft", profile: {...profile(), pharmacyName: "تصحيح"}, expectedRevision: 3});
  assert.equal(h.db.read("pharmacyRequests/owner").pharmacyName, "صيدلية");
  await h.call({action: "submit", profile: {...profile(), pharmacyName: "تصحيح"}, expectedRevision: 4});
  const result = await h.call({action: "decision", requestId: "owner", decision: "approve", expectedRevision: 5}, "admin");
  assert.equal(result.version, 2);
  assert.equal(result.status, "approved");
  assert.equal(h.db.read("pharmacies/owner").pharmacyName, "تصحيح");
  assert.equal(h.db.read("pharmacyRequests/owner/versions/v1").pharmacyName, "صيدلية");
  assert.equal(h.db.read("pharmacyRequests/owner/versions/v2").pharmacyName, "تصحيح");
  assert.equal(h.db.paths("pharmacyRequests/owner/notifications/").length, 2);
  assert.equal(h.db.paths("adminAuditLogs/").length, 2);
  assert.equal(h.db.read("pharmacies/owner/permissions/pharmacist").permissions["inventory.view"], true);
});
test("mandatory reason, immutable submitted version and stale decision", async () => {
  const h = setup(); await h.call({action: "submit", profile: profile()});
  await assert.rejects(h.call({action: "decision", requestId: "owner", decision: "reject", expectedRevision: 1}, "admin"), {code: "invalid-argument"});
  await assert.rejects(h.call({action: "saveDraft", profile: profile(), expectedRevision: 1}), {code: "failed-precondition"});
  await assert.rejects(h.call({action: "decision", requestId: "owner", decision: "approve", expectedRevision: 0}, "admin"), {code: "aborted"});
  assert.equal(h.db.paths("adminAuditLogs/").length, 0);
});
test("retry is idempotent across subsequent decisions; operation reuse with other data fails", async () => {
  const h = setup(); const submit = {action: "submit", profile: profile(), operationId: "same"};
  const first = await h.call(submit);
  assert.deepEqual(await h.call(submit), first);
  assert.equal(h.db.paths("pharmacyRequests/owner/versions/").length, 1);
  await assert.rejects(h.call({...submit, profile: {...profile(), pharmacyName: "different"}}), {code: "already-exists"});
  const decision = {action: "decision", requestId: "owner", decision: "approve", expectedRevision: 1, operationId: "approve_once"};
  const approved = await h.call(decision, "admin");
  assert.deepEqual(await h.call(decision, "admin"), approved);
  assert.equal(h.db.paths("adminAuditLogs/").length, 1);
  h.db.write("adminEmployees/admin", {isActive: false, role: "super_admin"});
  await assert.rejects(h.call(decision, "admin"), {code: "permission-denied"});
});
test("rejected request can resubmit; old version cannot be approved", async () => {
  const h = setup(); await h.call({action: "submit", profile: profile()});
  await h.call({action: "decision", requestId: "owner", decision: "reject", reason: "مستند غير واضح", expectedRevision: 1}, "admin");
  await h.call({action: "submit", profile: profile(), expectedRevision: 2});
  await assert.rejects(h.call({action: "decision", requestId: "owner", decision: "approve", expectedRevision: 1}, "admin"), {code: "aborted"});
  assert.equal(h.db.read("pharmacyRequests/owner").version, 2);
});
test("license collision and foreign documents are rejected", async () => {
  const h = setup(); await h.call({action: "submit", profile: profile()});
  await assert.rejects(h.call({action: "submit", profile: profile("other")}, "other"), {code: "already-exists"});
  await assert.rejects(h.call({action: "submit", profile: profile("foreign")}, "other"), {code: "invalid-argument"});
});
test("active administrative actor and current owner verification are required on approval", async () => {
  const seed = {"pharmacyRequests/owner": {...profile(), id: "owner", status: "pending", revision: 1, version: 1},
    "adminEmployees/reviewer": {isActive: true, role: "registration_reviewer", permissions: {"requests.review": true}}};
  const h = setup(seed, {owner: {emailVerified: false}});
  await assert.rejects(h.call({action: "decision", requestId: "owner", decision: "approve", expectedRevision: 1}, "reviewer"), {code: "failed-precondition"});
  h.db.write("adminEmployees/reviewer", {isActive: false});
  await assert.rejects(h.call({action: "decision", requestId: "owner", decision: "approve", expectedRevision: 1}, "reviewer"), {code: "permission-denied"});
  await assert.rejects(h.call({action: "decision", requestId: "owner", decision: "approve", expectedRevision: 1}, "admin"), {code: "failed-precondition"});
});
