"use strict";

const crypto = require("node:crypto");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const {
  clean,
  employeeClaims,
  resolvePharmacyPrincipal,
} = require("./authorization");

const SCRYPT_COST = 16384;
const SCRYPT_BLOCK_SIZE = 8;
const SCRYPT_PARALLELIZATION = 1;
const KEY_LENGTH = 64;
const SESSION_MS = 12 * 60 * 60 * 1000;
const MAX_FAILURES = 5;
const LOCK_MS = 5 * 60 * 1000;

class EmployeeSessionError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function documentHash(value) {
  return crypto.createHash("sha256").update(String(value)).digest("hex");
}

function usernameKey(value) {
  const result = clean(value).toLowerCase().replace(/\s+/g, " ");
  const hasControlCharacter = [...result].some((character) => character.charCodeAt(0) < 32);
  if (result.length < 2 || result.length > 64 || result.includes("/") || hasControlCharacter) {
    throw new EmployeeSessionError("invalid-argument", "اسم المستخدم غير صالح.");
  }
  return result;
}

function passwordRecord(password, version, salt = crypto.randomBytes(16)) {
  const value = String(password ?? "");
  if (value.length < 6 || value.length > 256) {
    throw new EmployeeSessionError("invalid-argument", "كلمة المرور يجب ألا تقل عن 6 أحرف.");
  }
  const options = {
    N: SCRYPT_COST,
    r: SCRYPT_BLOCK_SIZE,
    p: SCRYPT_PARALLELIZATION,
    maxmem: 64 * 1024 * 1024,
  };
  return {
    algorithm: "scrypt",
    cost: SCRYPT_COST,
    blockSize: SCRYPT_BLOCK_SIZE,
    parallelization: SCRYPT_PARALLELIZATION,
    keyLength: KEY_LENGTH,
    salt: salt.toString("base64"),
    passwordHash: crypto.scryptSync(value, salt, KEY_LENGTH, options).toString("base64"),
    credentialVersion: version,
  };
}

function passwordMatches(password, record) {
  try {
    if (record?.algorithm !== "scrypt" || record.cost !== SCRYPT_COST ||
        record.blockSize !== SCRYPT_BLOCK_SIZE ||
        record.parallelization !== SCRYPT_PARALLELIZATION ||
        record.keyLength !== KEY_LENGTH) return false;
    const salt = Buffer.from(record.salt, "base64");
    const expected = Buffer.from(record.passwordHash, "base64");
    const actual = crypto.scryptSync(String(password ?? ""), salt, record.keyLength, {
      N: record.cost,
      r: record.blockSize,
      p: record.parallelization,
      maxmem: 64 * 1024 * 1024,
    });
    return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
  } catch (_) {
    return false;
  }
}

function employeeActorUid(pharmacyId, employeeId) {
  return `pharmacy-employee-${documentHash(`${pharmacyId}:${employeeId}`).slice(0, 56)}`;
}

function publicEmployee(id, data) {
  return {
    id,
    name: clean(data.name),
    username: clean(data.username),
    phone: clean(data.phone),
    roleId: clean(data.roleId),
    roleDisplay: clean(data.roleDisplay),
    isActive: data.isActive === true,
  };
}

function failure(error, HttpsError) {
  if (error instanceof HttpsError) return error;
  const allowed = new Set([
    "invalid-argument", "permission-denied", "failed-precondition",
    "resource-exhausted", "not-found", "already-exists",
  ]);
  const code = allowed.has(error?.code) ? error.code : "internal";
  const message = code === "internal" ? "تعذر تنفيذ عملية حساب الموظف." : error.message;
  return new HttpsError(code, message);
}

function safeId(value, name) {
  const result = clean(value);
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(result)) {
    throw new EmployeeSessionError("invalid-argument", `${name} غير صالح.`);
  }
  return result;
}

function cleanOverrides(value) {
  if (value === undefined) return undefined;
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new EmployeeSessionError("invalid-argument", "تجاوزات الصلاحية غير صالحة.");
  }
  const result = {};
  for (const [key, allowed] of Object.entries(value)) {
    if (!/^[a-z_]+(?:\.[a-z_]+)+$/.test(key) || typeof allowed !== "boolean") {
      throw new EmployeeSessionError("invalid-argument", "تجاوزات الصلاحية غير صالحة.");
    }
    result[key] = allowed;
  }
  return result;
}

function profilePatch(data) {
  const source = data.profile && typeof data.profile === "object" ? data.profile : data;
  const result = {};
  for (const key of ["name", "phone", "roleId", "roleDisplay", "contractType",
    "idCardImageUrl", "certificateImageUrl"]) {
    if (source[key] !== undefined) result[key] = clean(source[key]);
  }
  if (source.isActive !== undefined) result.isActive = source.isActive === true;
  if (source.hiringDate !== undefined) result.hiringDate = source.hiringDate;
  const overrides = cleanOverrides(source.permissionOverrides);
  if (overrides !== undefined) {
    result.permissionOverrides = overrides;
    result.hasCustomPermissions = Object.keys(overrides).length > 0;
  } else if (source.hasCustomPermissions === false) {
    result.permissionOverrides = {};
    result.hasCustomPermissions = false;
  }
  return result;
}

function buildEmployeeSessionHandlers({
  db,
  auth,
  onCall,
  HttpsError,
  clock = () => Date.now(),
  randomBytes = crypto.randomBytes,
  createCustomToken = (uid, claims) => auth.createCustomToken(uid, claims),
}) {
  const manageAccount = onCall(async (request) => {
    try {
      const data = request.data || {};
      const pharmacyId = safeId(data.pharmacyId, "معرف الصيدلية");
      const employeeId = safeId(data.employeeId, "معرف الموظف");
      const action = clean(data.action || "update");
      if (!["create", "update", "disable"].includes(action)) {
        throw new EmployeeSessionError("invalid-argument", "عملية حساب الموظف غير صالحة.");
      }
      const permission = action === "create" ? "employees.create" :
        (action === "disable" ? "employees.delete" : "employees.update");
      const patch = profilePatch(data);
      const instant = clock();
      const result = await db.runTransaction(async (transaction) => {
        const principal = await resolvePharmacyPrincipal({
          db, auth: request.auth, pharmacyId, permission, instant, transaction,
        });
        const pharmacyRef = db.collection("pharmacies").doc(pharmacyId);
        const employeeRef = pharmacyRef.collection("employees").doc(employeeId);
        const credentialRef = pharmacyRef.collection("employeeCredentials").doc(employeeId);
        const employeeSnapshot = await transaction.get(employeeRef);
        const credentialSnapshot = await transaction.get(credentialRef);
        if (action === "create" && employeeSnapshot.exists) {
          throw new EmployeeSessionError("already-exists", "حساب الموظف موجود بالفعل.");
        }
        if (action !== "create" && !employeeSnapshot.exists) {
          throw new EmployeeSessionError("not-found", "حساب الموظف غير موجود.");
        }
        if (principal.type === "employee" && principal.employeeId === employeeId &&
            action === "disable") {
          throw new EmployeeSessionError("failed-precondition", "لا يمكن للموظف تعطيل حسابه الحالي.");
        }

        const existing = employeeSnapshot.exists ? employeeSnapshot.data() : {};
        const username = clean(data.username !== undefined ? data.username : existing.username);
        const key = usernameKey(username);
        const oldKey = clean(existing.usernameKey);
        const usernameRef = pharmacyRef.collection("employeeUsernames").doc(documentHash(key));
        const usernameSnapshot = await transaction.get(usernameRef);
        if (usernameSnapshot.exists && clean(usernameSnapshot.data().employeeId) !== employeeId) {
          throw new EmployeeSessionError("already-exists", "اسم المستخدم مستخدم بالفعل.");
        }
        const oldUsernameRef = oldKey && oldKey !== key ?
          pharmacyRef.collection("employeeUsernames").doc(documentHash(oldKey)) : null;
        const oldUsernameSnapshot = oldUsernameRef ? await transaction.get(oldUsernameRef) : null;

        const credentialChanged = action === "create" || oldKey !== key ||
          String(data.password ?? "").length > 0 || action === "disable";
        const nextVersion = Number(existing.credentialVersion || 0) + (credentialChanged ? 1 : 0);
        let credential = credentialSnapshot.exists ? credentialSnapshot.data() : null;
        if (String(data.password ?? "").length > 0) {
          credential = passwordRecord(data.password, nextVersion);
        } else if (action === "create") {
          throw new EmployeeSessionError("invalid-argument", "كلمة المرور مطلوبة للموظف الجديد.");
        } else if (credentialChanged && credential) {
          credential = {...credential, credentialVersion: nextVersion};
        }
        if (!credential) {
          throw new EmployeeSessionError(
            "failed-precondition",
            "يلزم ترحيل بيانات دخول هذا الموظف أو تعيين كلمة مرور جديدة.",
          );
        }

        if (oldUsernameRef && oldUsernameSnapshot?.exists &&
            clean(oldUsernameSnapshot.data().employeeId) === employeeId) {
          transaction.delete(oldUsernameRef);
        }
        transaction.set(usernameRef, {
          employeeId, usernameKey: key, updatedAt: Timestamp.fromMillis(instant),
        });
        transaction.set(credentialRef, {
          ...credential,
          credentialVersion: nextVersion,
          failedAttempts: 0,
          lockedUntil: null,
          updatedAt: Timestamp.fromMillis(instant),
        });
        const actor = {type: principal.type, id: principal.id, actorUid: principal.actorUid};
        const employeeData = {
          ...patch,
          id: employeeId,
          username,
          usernameKey: key,
          credentialVersion: nextVersion,
          isActive: action === "disable" ? false : (patch.isActive ?? existing.isActive ?? true),
          updatedAt: Timestamp.fromMillis(instant),
          updatedBy: actor,
        };
        if (action === "create") employeeData.createdAt = Timestamp.fromMillis(instant);
        if (action === "create") employeeData.createdBy = actor;
        if (employeeSnapshot.exists) {
          employeeData.password = FieldValue.delete();
          employeeData.passwordHash = FieldValue.delete();
        }
        transaction.set(employeeRef, employeeData, {merge: action !== "create"});
        return {success: true, employee: publicEmployee(employeeId, {...existing, ...employeeData})};
      });
      return result;
    } catch (error) {
      throw failure(error, HttpsError);
    }
  });

  // Compatibility export for clients deployed during F03. Both names execute
  // the same server-authorized account command; no credential logic lives in
  // the client.
  const manageCredential = manageAccount;

  const migrateLegacyCredential = onCall(async (request) => {
    try {
      const data = request.data || {};
      const pharmacyId = safeId(data.pharmacyId, "معرف الصيدلية");
      const employeeId = safeId(data.employeeId, "معرف الموظف");
      const instant = clock();
      return await db.runTransaction(async (transaction) => {
        await resolvePharmacyPrincipal({
          db, auth: request.auth, pharmacyId, permission: "employees.update",
          instant, transaction,
        });
        const pharmacyRef = db.collection("pharmacies").doc(pharmacyId);
        const employeeRef = pharmacyRef.collection("employees").doc(employeeId);
        const credentialRef = pharmacyRef.collection("employeeCredentials").doc(employeeId);
        const employeeSnapshot = await transaction.get(employeeRef);
        const credentialSnapshot = await transaction.get(credentialRef);
        if (!employeeSnapshot.exists) {
          throw new EmployeeSessionError("not-found", "حساب الموظف غير موجود.");
        }
        const employee = employeeSnapshot.data();
        if (credentialSnapshot.exists) {
          transaction.update(employeeRef, {
            password: FieldValue.delete(), passwordHash: FieldValue.delete(),
            updatedAt: Timestamp.fromMillis(instant),
          });
          return {success: true, migrated: false, employeeId};
        }
        if (typeof employee.password !== "string" || employee.password.length < 6) {
          throw new EmployeeSessionError(
            "failed-precondition", "لا توجد بيانات قديمة قابلة للترحيل؛ عيّن كلمة مرور جديدة.",
          );
        }
        const key = usernameKey(employee.username);
        const usernameRef = pharmacyRef.collection("employeeUsernames").doc(documentHash(key));
        const usernameSnapshot = await transaction.get(usernameRef);
        if (usernameSnapshot.exists && clean(usernameSnapshot.data().employeeId) !== employeeId) {
          throw new EmployeeSessionError("already-exists", "اسم المستخدم مستخدم بالفعل.");
        }
        const version = Number(employee.credentialVersion || 0) + 1;
        transaction.set(credentialRef, {
          ...passwordRecord(employee.password, version),
          failedAttempts: 0,
          lockedUntil: null,
          updatedAt: Timestamp.fromMillis(instant),
        });
        transaction.set(usernameRef, {
          employeeId, usernameKey: key, updatedAt: Timestamp.fromMillis(instant),
        });
        transaction.update(employeeRef, {
          usernameKey: key,
          credentialVersion: version,
          password: FieldValue.delete(),
          passwordHash: FieldValue.delete(),
          updatedAt: Timestamp.fromMillis(instant),
        });
        return {success: true, migrated: true, employeeId};
      });
    } catch (error) {
      throw failure(error, HttpsError);
    }
  });

  const loginEmployee = onCall(async (request) => {
    let sessionRef = null;
    try {
      const data = request.data || {};
      const pharmacyId = safeId(data.pharmacyId, "معرف الصيدلية");
      const key = usernameKey(data.username);
      const instant = clock();
      await resolvePharmacyPrincipal({db, auth: request.auth, pharmacyId, instant});
      const pharmacyRef = db.collection("pharmacies").doc(pharmacyId);
      const indexRef = pharmacyRef.collection("employeeUsernames").doc(documentHash(key));
      const attemptRef = pharmacyRef.collection("employeeLoginAttempts").doc(documentHash(key));
      const rawSession = randomBytes(32).toString("base64url");
      const sessionId = documentHash(rawSession);
      const result = await db.runTransaction(async (transaction) => {
        const attemptSnapshot = await transaction.get(attemptRef);
        const indexSnapshot = await transaction.get(indexRef);
        const attempt = attemptSnapshot.exists ? attemptSnapshot.data() : {};
        const lockedUntil = attempt.lockedUntil?.toMillis?.() || 0;
        if (lockedUntil > instant) return {error: "locked"};
        const employeeId = indexSnapshot.exists ? clean(indexSnapshot.data().employeeId) : "";
        const employeeRef = employeeId ? pharmacyRef.collection("employees").doc(employeeId) : null;
        const credentialRef = employeeId ?
          pharmacyRef.collection("employeeCredentials").doc(employeeId) : null;
        const employeeSnapshot = employeeRef ? await transaction.get(employeeRef) : null;
        const credentialSnapshot = credentialRef ? await transaction.get(credentialRef) : null;
        const employee = employeeSnapshot?.exists ? employeeSnapshot.data() : null;
        const credential = credentialSnapshot?.exists ? credentialSnapshot.data() : null;
        const valid = employee?.isActive === true &&
          clean(employee.usernameKey) === key && passwordMatches(data.password, credential);
        if (!valid) {
          const failures = Number(attempt.failedAttempts || 0) + 1;
          const lock = failures >= MAX_FAILURES ? Timestamp.fromMillis(instant + LOCK_MS) : null;
          transaction.set(attemptRef, {
            failedAttempts: failures,
            lockedUntil: lock,
            lastFailedAt: Timestamp.fromMillis(instant),
          }, {merge: true});
          if (credentialRef && credentialSnapshot?.exists) {
            transaction.update(credentialRef, {
              failedAttempts: failures, lockedUntil: lock,
              lastFailedAt: Timestamp.fromMillis(instant),
            });
          }
          return {error: "invalid"};
        }
        const actorUid = employeeActorUid(pharmacyId, employeeId);
        sessionRef = pharmacyRef.collection("employeeSessions").doc(sessionId);
        transaction.set(attemptRef, {failedAttempts: 0, lockedUntil: null,
          lastLoginAt: Timestamp.fromMillis(instant)}, {merge: true});
        transaction.update(credentialRef, {failedAttempts: 0, lockedUntil: null,
          lastLoginAt: Timestamp.fromMillis(instant)});
        transaction.create(sessionRef, {
          sessionId,
          actorUid,
          pharmacyId,
          employeeId,
          credentialVersion: Number(employee.credentialVersion),
          createdAt: Timestamp.fromMillis(instant),
          expiresAt: Timestamp.fromMillis(instant + SESSION_MS),
          revokedAt: null,
        });
        return {
          actorUid,
          pharmacyId,
          employeeId,
          sessionId,
          credentialVersion: Number(employee.credentialVersion),
          employee: publicEmployee(employeeId, employee),
          expiresAt: instant + SESSION_MS,
        };
      });
      if (result.error === "locked") {
        throw new EmployeeSessionError("resource-exhausted", "تعذر تسجيل الدخول مؤقتًا؛ حاول لاحقًا.");
      }
      if (result.error) {
        throw new EmployeeSessionError("permission-denied", "بيانات الدخول غير صحيحة أو الحساب غير متاح.");
      }
      let customToken;
      try {
        customToken = await createCustomToken(result.actorUid, {
          actorType: "pharmacy_employee",
          pharmacyId: result.pharmacyId,
          employeeId: result.employeeId,
          sessionId: result.sessionId,
          credentialVersion: result.credentialVersion,
        });
      } catch (error) {
        if (sessionRef) {
          await sessionRef.update({revokedAt: Timestamp.fromMillis(clock())}).catch(() => {});
        }
        throw error;
      }
      return {...result, customToken};
    } catch (error) {
      throw failure(error, HttpsError);
    }
  });

  const revokeSession = onCall(async (request) => {
    try {
      const claims = employeeClaims(request.auth);
      const instant = clock();
      if (claims) {
        const ref = db.collection("pharmacies").doc(claims.pharmacyId)
          .collection("employeeSessions").doc(claims.sessionId);
        await db.runTransaction(async (transaction) => {
          const snapshot = await transaction.get(ref);
          if (snapshot.exists && snapshot.data().actorUid === claims.actorUid &&
              snapshot.data().employeeId === claims.employeeId) {
            transaction.update(ref, {revokedAt: Timestamp.fromMillis(instant)});
          }
        });
        return {success: true};
      }
      const pharmacyId = safeId(request.data?.pharmacyId, "معرف الصيدلية");
      const sessionId = clean(request.data?.sessionId);
      await resolvePharmacyPrincipal({db, auth: request.auth, pharmacyId, instant});
      if (!/^[a-f0-9]{64}$/.test(sessionId)) {
        throw new EmployeeSessionError("invalid-argument", "معرف الجلسة غير صالح.");
      }
      const ref = db.collection("pharmacies").doc(pharmacyId)
        .collection("employeeSessions").doc(sessionId);
      const snapshot = await ref.get();
      if (snapshot.exists) await ref.update({revokedAt: Timestamp.fromMillis(instant)});
      return {success: true};
    } catch (error) {
      throw failure(error, HttpsError);
    }
  });

  return {loginEmployee, manageAccount, manageCredential, migrateLegacyCredential, revokeSession};
}

module.exports = {
  EmployeeSessionError,
  buildEmployeeSessionHandlers,
  documentHash,
  employeeActorUid,
  passwordMatches,
  passwordRecord,
  usernameKey,
};
