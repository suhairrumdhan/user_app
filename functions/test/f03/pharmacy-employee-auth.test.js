"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {buildEmployeeAuthHandlers, passwordMatches,
  usernameKey} = require("../../src/domain/pharmacy-employee-auth");
const {FakeFirestore} = require("./helpers/fake-firestore");

class HttpsError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

function setup(seed = {}) {
  let now = Date.UTC(2026, 8, 14);
  let random = 0;
  const issued = new Map();
  const db = new FakeFirestore({"pharmacies/pharmacy": {status: "approved", isActive: true}, ...seed});
  const handlers = buildEmployeeAuthHandlers({db, auth: {}, HttpsError, onCall: (fn) => fn,
    clock: () => now, randomBytes: () => Buffer.alloc(32, ++random),
    createCustomToken: async (uid, claims) => {
      const token = `custom-token-${issued.size + 1}`;
      issued.set(token, {uid, token: claims});
      return token;
    }});
  const owner = (handler, data) => handler({auth: {uid: "pharmacy"}, data: {pharmacyId: "pharmacy", ...data}});
  const authFor = (login) => issued.get(login.customToken);
  return {db, handlers, owner, authFor, advance: (ms) => { now += ms; }};
}

async function provision(h, employeeId = "employee", username = "Staff", password = "secret1") {
  await h.owner(h.handlers.manageAccount, {action: "create", employeeId, username, password,
    profile: {name: "Staff", roleId: "pharmacist", isActive: true}});
  h.db.write("pharmacies/pharmacy/permissions/pharmacist", {
    permissions: {"orders.update_status": true, "employees.update": true},
  });
}

test("username normalization is stable and rejects path/control characters", () => {
  assert.equal(usernameKey("  Staff   One "), "staff one");
  for (const value of ["", "a", "a/b", `a${String.fromCharCode(1)}b`]) {
    assert.throws(() => usernameKey(value), {code: "invalid-argument"});
  }
});

test("credential management stores a one-way password record and enforces unique usernames", async () => {
  const h = setup();
  await provision(h);
  const credential = h.db.read("pharmacies/pharmacy/employeeCredentials/employee");
  assert.equal(passwordMatches("secret1", credential), true);
  assert.equal(passwordMatches("wrong", credential), false);
  assert.notEqual(credential.passwordHash, "secret1");
  assert.equal(h.db.read("pharmacies/pharmacy/employees/employee").password, undefined);
  await assert.rejects(h.owner(h.handlers.manageAccount,
    {action: "create", employeeId: "second", username: "staff", password: "secret2",
      profile: {roleId: "pharmacist", isActive: true}}), {code: "already-exists"});
});

test("successful login returns a custom token bound to a server session", async () => {
  const h = setup();
  await provision(h);
  const login = await h.owner(h.handlers.loginEmployee, {username: " STAFF ", password: "secret1"});
  assert.equal(login.employee.id, "employee");
  assert.ok(login.customToken.startsWith("custom-token-"));
  const session = h.db.read(`pharmacies/pharmacy/employeeSessions/${login.sessionId}`);
  assert.equal(session.employeeId, "employee");
  assert.equal(session.actorUid, login.actorUid);
  assert.equal(JSON.stringify(login).includes("secret1"), false);
});

test("five failed logins lock the credential and expiry releases that lock", async () => {
  const h = setup();
  await provision(h);
  for (let attempt = 0; attempt < 4; attempt++) {
    await assert.rejects(h.owner(h.handlers.loginEmployee,
      {username: "Staff", password: "wrong1"}), {code: "permission-denied"});
  }
  await assert.rejects(h.owner(h.handlers.loginEmployee,
    {username: "Staff", password: "wrong1"}), {code: "permission-denied"});
  await assert.rejects(h.owner(h.handlers.loginEmployee,
    {username: "Staff", password: "secret1"}), {code: "resource-exhausted"});
  h.advance(5 * 60 * 1000 + 1);
  assert.equal((await h.owner(h.handlers.loginEmployee,
    {username: "Staff", password: "secret1"})).employee.id, "employee");
});

test("credential change invalidates old sessions and supports editable usernames", async () => {
  const h = setup();
  await provision(h);
  const old = await h.owner(h.handlers.loginEmployee, {username: "Staff", password: "secret1"});
  await h.owner(h.handlers.manageAccount,
    {action: "update", employeeId: "employee", username: "New Staff", password: "secret2"});
  await assert.rejects(h.owner(h.handlers.loginEmployee,
    {username: "Staff", password: "secret1"}), {code: "permission-denied"});
  assert.equal((await h.owner(h.handlers.loginEmployee,
    {username: "new staff", password: "secret2"})).employee.id, "employee");
  const employee = h.db.read("pharmacies/pharmacy/employees/employee");
  const session = h.db.read(`pharmacies/pharmacy/employeeSessions/${old.sessionId}`);
  assert.notEqual(session.credentialVersion, employee.credentialVersion);
});

test("protected migration hashes legacy plaintext once and removes it", async () => {
  const h = setup({"pharmacies/pharmacy/employees/legacy": {
    username: "legacy", password: "oldpass", isActive: true, roleId: "pharmacist",
  }});
  await h.owner(h.handlers.migrateLegacyCredential, {employeeId: "legacy"});
  assert.equal(h.db.read("pharmacies/pharmacy/employees/legacy").password, undefined);
  assert.equal((await h.owner(h.handlers.loginEmployee,
    {username: "legacy", password: "oldpass"})).employee.id, "legacy");
});

test("a migrated account can change username without exposing its password", async () => {
  const h = setup({"pharmacies/pharmacy/employees/legacy": {
    username: "legacy", password: "oldpass", isActive: true, roleId: "pharmacist",
  }});
  await h.owner(h.handlers.migrateLegacyCredential, {employeeId: "legacy"});
  await h.owner(h.handlers.manageAccount, {action: "update", employeeId: "legacy",
    username: "renamed legacy"});
  assert.equal(h.db.read("pharmacies/pharmacy/employees/legacy").password, undefined);
  assert.equal((await h.owner(h.handlers.loginEmployee,
    {username: "renamed legacy", password: "oldpass"})).employee.id, "legacy");
});

test("logout revokes the session bound to the employee Firebase principal", async () => {
  const h = setup();
  await provision(h);
  const login = await h.owner(h.handlers.loginEmployee, {username: "Staff", password: "secret1"});
  await h.handlers.revokeSession({auth: h.authFor(login), data: {}});
  const session = h.db.read(`pharmacies/pharmacy/employeeSessions/${login.sessionId}`);
  assert.ok(session.revokedAt);
  await assert.rejects(h.handlers.revokeSession({auth: {uid: "outsider"}, data: {
    pharmacyId: "pharmacy", sessionId: login.sessionId,
  }}), {code: "permission-denied"});
});
