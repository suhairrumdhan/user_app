"use strict";

const {Timestamp} = require("firebase-admin/firestore");
const {documentHash, employeeActorUid} = require("../../../src/auth/employee-session");

const TEST_EMPLOYEE_SESSION = "test_employee_session_token_abcdefghijklmnopqrstuvwxyz123456";

function seedEmployeeSession(db, pharmacyId, employeeId, employee = {}) {
  const version = 1;
  const roleId = employee.roleId || "pharmacist";
  const actorUid = employeeActorUid(pharmacyId, employeeId);
  const sessionId = documentHash(TEST_EMPLOYEE_SESSION);
  db.write(`pharmacies/${pharmacyId}`, {
    status: "approved", isActive: true,
    ...(db.read(`pharmacies/${pharmacyId}`) || {}),
  });
  db.write(`pharmacies/${pharmacyId}/employees/${employeeId}`, {
    ...employee, roleId, credentialVersion: version,
  });
  db.write(`pharmacies/${pharmacyId}/permissions/${roleId}`, {
    permissions: employee.permissions || {},
  });
  db.write(`pharmacies/${pharmacyId}/employeeSessions/${sessionId}`, {
    actorUid, pharmacyId, employeeId, credentialVersion: version,
    expiresAt: Timestamp.fromDate(new Date("2099-01-01T00:00:00Z")), revokedAt: null,
  });
  return {uid: actorUid, token: {
    actorType: "pharmacy_employee", pharmacyId, employeeId, sessionId,
    credentialVersion: version,
  }};
}

module.exports = {seedEmployeeSession, TEST_EMPLOYEE_SESSION};
