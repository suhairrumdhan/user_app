"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {sessionHash} = require("../../src/domain/pharmacy-employee-auth");
const {
  initializeLiveSuite,
  readDocument,
  testOrder,
  writeEvidence,
} = require("./helpers/live-firebase");

const SUITE_NAME = "f03-live-employee-auth";
const PASSWORD_ONE = "LiveEmployee-2026-A";
const PASSWORD_TWO = "LiveEmployee-2026-B";

test("F03 internal employee identity on the live Firebase project", {
  timeout: 300000,
}, async (t) => {
  const context = await initializeLiveSuite(SUITE_NAME, {
    isolatedIdentities: true,
  });
  const employeeId = `employee-${context.runId}`;
  const secondEmployeeId = `second-${context.runId}`;
  const username = `staff-${context.runId}`;
  const renamedUsername = `staff-renamed-${context.runId}`;
  const medicineId = `medicine-${context.runId}`;
  const employeePath =
    `pharmacies/${context.pharmacyUid}/employees/${employeeId}`;

  await context.db.doc(`pharmacies/${context.pharmacyUid}`).set({
    pharmacyId: context.pharmacyUid,
    name: "Roshita Live Employee Auth Pharmacy",
    status: "approved",
    isActive: true,
    isOnline: true,
    liveTest: true,
  });
  for (const id of [employeeId, secondEmployeeId]) {
    await context.db.doc(
      `pharmacies/${context.pharmacyUid}/employees/${id}`,
    ).set({id, name: "Live Employee", roleId: "admin", isActive: true});
  }
  await writeEvidence(context, "running", {employeeId});

  try {
    await t.test("credential storage is one-way and username is unique", async () => {
      await context.callFunction(
        "pharmacy",
        "managePharmacyEmployeeCredential",
        {
          pharmacyId: context.pharmacyUid,
          employeeId,
          username,
          password: PASSWORD_ONE,
        },
      );
      const employee = await readDocument(context, employeePath);
      const credential = await readDocument(
        context,
        `pharmacies/${context.pharmacyUid}/employeeCredentials/${employeeId}`,
      );
      assert.equal(employee.password, undefined);
      assert.equal(credential.passwordHash === PASSWORD_ONE, false);
      assert.equal(credential.algorithm, "pbkdf2-sha256");
      await assert.rejects(
        context.callFunction(
          "pharmacy",
          "managePharmacyEmployeeCredential",
          {
            pharmacyId: context.pharmacyUid,
            employeeId: secondEmployeeId,
            username,
            password: PASSWORD_ONE,
          },
        ),
        (error) => error.code === "already-exists",
      );
    });

    let firstLogin;
    await t.test("login rejects a wrong password and returns an opaque session", async () => {
      await assert.rejects(
        context.callFunction(
          "pharmacy",
          "createPharmacyEmployeeSession",
          {
            pharmacyId: context.pharmacyUid,
            username,
            password: "WrongEmployee-2026",
          },
        ),
        (error) => error.code === "permission-denied",
      );
      firstLogin = await context.callFunction(
        "pharmacy",
        "createPharmacyEmployeeSession",
        {
          pharmacyId: context.pharmacyUid,
          username: username.toUpperCase(),
          password: PASSWORD_ONE,
        },
      );
      assert.equal(firstLogin.employee.id, employeeId);
      assert.ok(firstLogin.sessionToken.length >= 40);
      const stored = await readDocument(
        context,
        `pharmacies/${context.pharmacyUid}/employeeSessions/` +
          sessionHash(firstLogin.sessionToken),
      );
      assert.equal(JSON.stringify(stored).includes(firstLogin.sessionToken), false);
    });

    let replacementLogin;
    await t.test("a credential edit invalidates the former employee session", async () => {
      await context.callFunction(
        "pharmacy",
        "managePharmacyEmployeeCredential",
        {
          pharmacyId: context.pharmacyUid,
          employeeId,
          username: renamedUsername,
          password: PASSWORD_TWO,
        },
      );
      await assert.rejects(
        context.callFunction(
          "pharmacy",
          "createPharmacyEmployeeSession",
          {
            pharmacyId: context.pharmacyUid,
            username,
            password: PASSWORD_ONE,
          },
        ),
        (error) => error.code === "permission-denied",
      );
      replacementLogin = await context.callFunction(
        "pharmacy",
        "createPharmacyEmployeeSession",
        {
          pharmacyId: context.pharmacyUid,
          username: renamedUsername,
          password: PASSWORD_TWO,
        },
      );
    });

    await t.test("only the current non-revoked session can mutate an order", async () => {
      await context.db.doc(
        `pharmacies/${context.pharmacyUid}/medicines/${medicineId}`,
      ).set({
        id: medicineId,
        name: "Live Employee Auth Medicine",
        quantity: 3,
        reservedQuantity: 0,
        isActive: true,
        expiryDate: context.admin.firestore.Timestamp.fromDate(
          new Date("2099-01-01T00:00:00Z"),
        ),
      });
      const oldOrderId = `old-session-${context.runId}`;
      const currentOrderId = `current-session-${context.runId}`;
      const revokedOrderId = `revoked-session-${context.runId}`;
      for (const orderId of [oldOrderId, currentOrderId, revokedOrderId]) {
        await context.db.doc(`orders/${orderId}`).set(testOrder(
          context,
          orderId,
          [{matchedMedicineId: medicineId, quantity: 1}],
        ));
      }
      await assert.rejects(
        context.call("pharmacy", "confirmFullOrder", oldOrderId, {
          actor: {employeeId, employeeSession: firstLogin.sessionToken},
        }),
        (error) => error.code === "permission-denied",
      );
      await context.call("pharmacy", "confirmFullOrder", currentOrderId, {
        actor: {employeeId, employeeSession: replacementLogin.sessionToken},
      });
      await context.callFunction(
        "pharmacy",
        "revokePharmacyEmployeeSession",
        {
          pharmacyId: context.pharmacyUid,
          sessionToken: replacementLogin.sessionToken,
        },
      );
      await assert.rejects(
        context.call("pharmacy", "confirmFullOrder", revokedOrderId, {
          actor: {employeeId, employeeSession: replacementLogin.sessionToken},
        }),
        (error) => error.code === "permission-denied",
      );
    });

    await writeEvidence(context, "passed", {employeeId});
  } catch (error) {
    await writeEvidence(context, "failed", {
      employeeId,
      errorCode: error.code || "unknown",
      errorMessage: String(error.message || error).slice(0, 500),
    });
    throw error;
  } finally {
    await context.app.delete();
  }
});
