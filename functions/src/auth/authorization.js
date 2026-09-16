"use strict";

class PharmacyAuthorizationError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function clean(value) {
  return String(value ?? "").trim();
}

function timestampMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  const result = new Date(value).getTime();
  return Number.isFinite(result) ? result : 0;
}

function employeeClaims(auth) {
  const token = auth?.token || {};
  if (token.actorType !== "pharmacy_employee") return null;
  return {
    actorUid: clean(auth?.uid),
    pharmacyId: clean(token.pharmacyId),
    employeeId: clean(token.employeeId),
    sessionId: clean(token.sessionId),
    credentialVersion: Number(token.credentialVersion),
  };
}

function permissionAllowed(employee, permissionDoc, permission) {
  if (!permission) return true;
  const override = employee?.permissionOverrides?.[permission];
  if (typeof override === "boolean") return override;
  return permissionDoc?.permissions?.[permission] === true;
}

async function readSnapshot(reference, transaction) {
  return transaction ? transaction.get(reference) : reference.get();
}

async function resolveEmployeePrincipal({
  db,
  auth,
  pharmacyId,
  permission = null,
  instant = Date.now(),
  transaction = null,
}) {
  const claims = employeeClaims(auth);
  if (!claims || !claims.actorUid || !claims.pharmacyId ||
      !claims.employeeId || !claims.sessionId ||
      !Number.isSafeInteger(claims.credentialVersion) ||
      (pharmacyId && claims.pharmacyId !== clean(pharmacyId))) {
    throw new PharmacyAuthorizationError("permission-denied", "جلسة الموظف غير صالحة.");
  }

  const pharmacyRef = db.collection("pharmacies").doc(claims.pharmacyId);
  const employeeRef = pharmacyRef.collection("employees").doc(claims.employeeId);
  const sessionRef = pharmacyRef.collection("employeeSessions").doc(claims.sessionId);
  const pharmacySnapshot = await readSnapshot(pharmacyRef, transaction);
  const employeeSnapshot = await readSnapshot(employeeRef, transaction);
  const sessionSnapshot = await readSnapshot(sessionRef, transaction);
  if (!pharmacySnapshot.exists || !employeeSnapshot.exists || !sessionSnapshot.exists) {
    throw new PharmacyAuthorizationError("permission-denied", "جلسة الموظف غير متاحة.");
  }

  const pharmacy = pharmacySnapshot.data();
  const employee = employeeSnapshot.data();
  const session = sessionSnapshot.data();
  if (pharmacy.status !== "approved" || pharmacy.isActive === false ||
      employee.isActive !== true || session.revokedAt ||
      session.actorUid !== claims.actorUid ||
      session.pharmacyId !== claims.pharmacyId ||
      session.employeeId !== claims.employeeId ||
      Number(session.credentialVersion) !== claims.credentialVersion ||
      Number(employee.credentialVersion) !== claims.credentialVersion ||
      timestampMillis(session.expiresAt) <= instant) {
    throw new PharmacyAuthorizationError("permission-denied", "انتهت جلسة الموظف أو أُلغيت.");
  }

  let permissionDoc = null;
  if (permission) {
    const roleId = clean(employee.roleId);
    if (!roleId) {
      throw new PharmacyAuthorizationError("permission-denied", "الدور الحالي لا يملك الصلاحية المطلوبة.");
    }
    const permissionSnapshot = await readSnapshot(
      pharmacyRef.collection("permissions").doc(roleId), transaction,
    );
    permissionDoc = permissionSnapshot.exists ? permissionSnapshot.data() : null;
    if (!permissionAllowed(employee, permissionDoc, permission)) {
      throw new PharmacyAuthorizationError("permission-denied", "الدور الحالي لا يملك الصلاحية المطلوبة.");
    }
  }

  return {
    type: "employee",
    id: claims.employeeId,
    actorUid: claims.actorUid,
    actorId: claims.actorUid,
    pharmacyId: claims.pharmacyId,
    employeeId: claims.employeeId,
    sessionId: claims.sessionId,
    credentialVersion: claims.credentialVersion,
    employee,
    permissionDoc,
    pharmacyRef,
    employeeRef,
    sessionRef,
  };
}

async function resolvePharmacyPrincipal({
  db,
  auth,
  pharmacyId,
  permission = null,
  instant = Date.now(),
  transaction = null,
}) {
  const expectedPharmacyId = clean(pharmacyId);
  const uid = clean(auth?.uid);
  if (!uid || !expectedPharmacyId) {
    throw new PharmacyAuthorizationError("permission-denied", "المصادقة مطلوبة.");
  }
  if (employeeClaims(auth)) {
    return resolveEmployeePrincipal({
      db, auth, pharmacyId: expectedPharmacyId, permission, instant, transaction,
    });
  }
  if (uid !== expectedPharmacyId) {
    throw new PharmacyAuthorizationError("permission-denied", "الحساب لا يتبع هذه الصيدلية.");
  }
  const pharmacyRef = db.collection("pharmacies").doc(expectedPharmacyId);
  const pharmacySnapshot = await readSnapshot(pharmacyRef, transaction);
  if (!pharmacySnapshot.exists || pharmacySnapshot.data().status !== "approved" ||
      pharmacySnapshot.data().isActive === false) {
    throw new PharmacyAuthorizationError("permission-denied", "حساب الصيدلية غير متاح.");
  }
  return {
    type: "owner",
    id: uid,
    actorUid: uid,
    actorId: uid,
    pharmacyId: expectedPharmacyId,
    employeeId: null,
    pharmacyRef,
  };
}

module.exports = {
  PharmacyAuthorizationError,
  clean,
  employeeClaims,
  permissionAllowed,
  resolveEmployeePrincipal,
  resolvePharmacyPrincipal,
  timestampMillis,
};
