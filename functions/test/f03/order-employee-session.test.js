"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {Timestamp} = require("firebase-admin/firestore");
const {buildOrderCommandHandler} = require("../../src/domain/order-commands");
const {documentHash} = require("../../src/auth/employee-session");
const {FakeFirestore} = require("./helpers/fake-firestore");
const {seedEmployeeSession, TEST_EMPLOYEE_SESSION} =
  require("./helpers/employee-session");

class HttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

const now = Date.UTC(2026, 8, 14, 12);

function setup(employee = {}) {
  const db = new FakeFirestore({
    "orders/order-one": {
      schemaVersion: 3,
      orderId: "order-one",
      user: {userId: "user-one"},
      pharmacy: {pharmacyId: "pharmacy-one"},
      status: "underReview", estimatedTotalPrice: 10,
      statusHistory: [],
      medicines: [{matchedMedicineId: "medicine-one", quantity: 1}],
      offerVersion: 0,
      pharmacyReviewActiveMs: 0,
      reviewStartedAt: Timestamp.fromMillis(now - 1000),
    },
    "pharmacies/pharmacy-one/medicines/medicine-one": {
      id: "medicine-one", sellingPrice: 10,
      quantity: 5,
      reservedQuantity: 0,
      isActive: true,
      expiryDate: Timestamp.fromDate(new Date("2099-01-01T00:00:00Z")),
    },
  });
  const actor = seedEmployeeSession(db, "pharmacy-one", "employee-one", {
    isActive: true,
    roleId: "pharmacist",
    permissions: {"orders.update_status": true},
    ...employee,
  });
  const handler = buildOrderCommandHandler({
    db,
    onCall: (fn) => fn,
    HttpsError,
    clock: () => now,
  });
  return {db, actor, handler};
}

let sequence = 0;
function confirm(context, auth = context.actor, forgedActor = {}) {
  sequence += 1;
  return context.handler({
    auth,
    data: {
      schemaVersion: 3,
      command: "confirmFullOrder",
      operationId: `employee-session-${sequence}`,
      orderId: "order-one",
      payload: {},
      actor: forgedActor,
    },
  });
}

function sessionPath() {
  return "pharmacies/pharmacy-one/employeeSessions/" +
    documentHash(TEST_EMPLOYEE_SESSION);
}

test("a verified employee session authorizes and audits the employee", async () => {
  const context = setup();
  const result = await confirm(context);
  assert.equal(result.result.status, "confirmedReserved");
  const history = context.db.read("orders/order-one").statusHistory.at(-1);
  assert.equal(history.changedById, "employee-one");
  assert.equal(history.changedByType, "pharmacy");
});

test("client-supplied employee identity cannot authorize an unrelated caller", async () => {
  const context = setup();
  await assert.rejects(confirm(context, {uid: "outsider", token: {}}, {
    employeeId: "employee-one", roleId: "admin",
    permissionOverrides: {"orders.update_status": true},
  }), {
    code: "permission-denied",
  });
  assert.equal(context.db.read("orders/order-one").status, "underReview");
});

test("an incomplete employee claim set is rejected", async () => {
  const context = setup();
  await assert.rejects(confirm(context, {uid: context.actor.uid, token: {
    actorType: "pharmacy_employee",
    pharmacyId: "pharmacy-one",
  }}), {code: "permission-denied"});
});

test("revoked expired and credential-version-stale sessions are rejected", async (t) => {
  await t.test("revoked", async () => {
    const context = setup();
    context.db.write(sessionPath(), {
      ...context.db.read(sessionPath()),
      revokedAt: Timestamp.fromMillis(now - 1),
    });
    await assert.rejects(confirm(context), {code: "permission-denied"});
  });
  await t.test("expired", async () => {
    const context = setup();
    context.db.write(sessionPath(), {
      ...context.db.read(sessionPath()),
      expiresAt: Timestamp.fromMillis(now),
    });
    await assert.rejects(confirm(context), {code: "permission-denied"});
  });
  await t.test("credential changed", async () => {
    const context = setup();
    context.db.write("pharmacies/pharmacy-one/employees/employee-one", {
      ...context.db.read("pharmacies/pharmacy-one/employees/employee-one"),
      credentialVersion: 2,
    });
    await assert.rejects(confirm(context), {code: "permission-denied"});
  });
});

test("disabled or permission-denied employees cannot mutate an order", async (t) => {
  await t.test("disabled", async () => {
    const context = setup({isActive: false});
    await assert.rejects(confirm(context), {code: "permission-denied"});
  });
  await t.test("explicitly denied", async () => {
    const context = setup({
      permissionOverrides: {"orders.update_status": false},
    });
    await assert.rejects(confirm(context), {code: "permission-denied"});
  });
});

test("a session cannot be replayed by another Firebase principal", async () => {
  const context = setup();
  await assert.rejects(confirm(context, {...context.actor, uid: "forged-actor"}), {
    code: "permission-denied",
  });
});
