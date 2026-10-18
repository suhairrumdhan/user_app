"use strict";

const {createHash} = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");
const {FieldValue} = require("firebase-admin/firestore");
const defaultPermissions = require("./registration-default-permissions");

const STATUS_ALIASES = {
  draft: "draft", pending: "pending", submitted: "pending", new: "pending",
  under_review: "pending", reviewing: "pending", requires_changes: "requires_changes",
  needs_info: "requires_changes", approved: "approved", accepted: "approved",
  rejected: "rejected", declined: "rejected",
};
const statusOf = (value) => STATUS_ALIASES[String(value || "").toLowerCase()] || "unknown";
const hash = (value) => createHash("sha256").update(value).digest("hex");
function fail(code, message) { throw new HttpsError(code, message); }
function identifier(value) {
  if (typeof value !== "string" || !/^[a-zA-Z0-9_-]{1,128}$/.test(value)) {
    fail("invalid-argument", "معرف العملية أو الطلب غير صالح.");
  }
  return value;
}
function cleanProfile(input = {}, complete = false) {
  const result = {};
  for (const key of ["pharmacyName", "ownerName", "licenseNumber", "ownerIdNumber", "phoneNumber"]) {
    const value = String(input[key] ?? "").trim();
    if (value.length > 200 || (complete && !value)) fail("invalid-argument", `يرجى استكمال ${key}.`);
    result[key] = value;
  }
  const location = input.location || {};
  const address = String(location.address || "").trim();
  const latitude = location.latitude;
  const longitude = location.longitude;
  if (address.length > 500 || (complete && (!address || !Number.isFinite(latitude) ||
      !Number.isFinite(longitude) || latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180))) {
    fail("invalid-argument", "يرجى تحديد عنوان الصيدلية وموقعها الصحيح.");
  }
  result.location = {address, latitude: Number.isFinite(latitude) ? latitude : null,
    longitude: Number.isFinite(longitude) ? longitude : null};
  result.is24Hours = input.is24Hours === true;
  for (const kind of ["license", "ownerId"]) {
    for (const suffix of ["FilePath", "FileUrl"]) {
      const key = kind + suffix;
      result[key] = String(input[key] || "").trim();
      if (result[key].length > 2500) fail("invalid-argument", "مرجع المستند غير صالح.");
    }
    if (complete && !result[kind + "FilePath"] && !result[kind + "FileUrl"]) {
      fail("invalid-argument", "يرجى رفع الترخيص وهوية المالك.");
    }
  }
  return result;
}

// Reuse previously stored legacy URLs only. New uploads are immutable objects
// belonging to the verified owner, not arbitrary URLs supplied by a client.
async function validateDocuments(profile, ownerUid, previous, bucket) {
  for (const kind of ["license", "ownerId"]) {
    const path = profile[kind + "FilePath"];
    const url = profile[kind + "FileUrl"];
    if (!path && !url) continue;
    if (!path && url === previous?.[kind + "FileUrl"]) continue;
    if (!path.startsWith(`registration/${ownerUid}/`) || path.includes("..")) {
      fail("invalid-argument", "المستند لا يتبع صاحب الطلب.");
    }
    if (url) {
      let parsed;
      try { parsed = new URL(url); } catch (_) { fail("invalid-argument", "رابط المستند غير صالح."); }
      if (parsed.protocol !== "https:" || parsed.hostname !== "firebasestorage.googleapis.com" ||
          parsed.pathname !== `/v0/b/${bucket.name}/o/${encodeURIComponent(path)}`) {
        fail("invalid-argument", "رابط المستند لا يطابق الملف المرفوع.");
      }
    }
    const [metadata] = await bucket.file(path).getMetadata().catch(() =>
      fail("failed-precondition", "لم يكتمل رفع المستند. أعد المحاولة."));
    if (!(Number(metadata.size) > 0 && Number(metadata.size) < 10 * 1024 * 1024) ||
        !/^(image\/(png|jpeg|webp)|application\/pdf)$/.test(metadata.contentType || "")) {
      fail("invalid-argument", "المستند يجب أن يكون صورة أو PDF أصغر من 10 ميغابايت.");
    }
  }
}

// Approval verifies the stored objects, including legacy URL-only records.
async function validateApprovalDocuments(profile, ownerUid, bucket) {
  for (const kind of ["license", "ownerId"]) {
    let path = profile[kind + "FilePath"];
    if (!path) {
      let url;
      try { url = new URL(profile[kind + "FileUrl"]); } catch (_) {
        fail("failed-precondition", "مرجع مستند التسجيل غير صالح.");
      }
      const prefix = `/v0/b/${bucket.name}/o/`;
      if (url.protocol !== "https:" || url.hostname !== "firebasestorage.googleapis.com" || !url.pathname.startsWith(prefix)) {
        fail("failed-precondition", "المستند لا يتبع مساحة تخزين المشروع.");
      }
      try { path = decodeURIComponent(url.pathname.slice(prefix.length)); } catch (_) {
        fail("failed-precondition", "مسار المستند غير صالح.");
      }
    }
    if (path.includes("..") || !(path.startsWith(`registration/${ownerUid}/`) || path.startsWith("pharmacy_requests_uploads/"))) {
      fail("failed-precondition", "مسار مستند التسجيل غير معتمد.");
    }
    const [metadata] = await bucket.file(path).getMetadata().catch(() =>
      fail("failed-precondition", "أحد المستندات مفقود أو لم يكتمل رفعه. اطلب استكمال الطلب."));
    if (!(Number(metadata.size) > 0 && Number(metadata.size) < 10 * 1024 * 1024) ||
      !/^(image\/(png|jpeg|webp)|application\/pdf)$/.test(metadata.contentType || "")) {
      fail("failed-precondition", "أحد المستندات ليس صورة أو PDF صالحًا أصغر من 10 ميغابايت.");
    }
  }
}

function buildRegistrationCommand({db, auth, bucket}) {
  return async (request) => {
    if (!request.auth || typeof request.auth.uid !== "string" || !request.auth.uid.trim()) {
      fail("unauthenticated", "سجّل الدخول أولًا.");
    }
    const actorUid = request.auth.uid;
    const input = request.data || {};
    const {action} = input;
    if (!["saveDraft", "submit", "decision"].includes(action)) fail("invalid-argument", "الإجراء غير صالح.");
    const ownerAction = action !== "decision";
    const actor = await auth.getUser(actorUid);
    if (actor.disabled) fail("permission-denied", "الحساب معطل.");
    if (actor.tokensValidAfterTime && Number(request.auth.token?.auth_time || 0) * 1000 < Date.parse(actor.tokensValidAfterTime)) {
      fail("unauthenticated", "انتهت جلسة الحساب. سجّل الدخول مجددًا.");
    }
    const permission = {approve: "requests.approve", reject: "requests.reject", changes: "requests.review"}[input.decision];
    function authorizeAdmin(admin) {
      if (!permission || admin?.isActive !== true || request.auth.token?.actorType === "pharmacy_employee") {
        fail("permission-denied", "ليست لديك صلاحية اتخاذ هذا القرار.");
      }
    }
    if (!ownerAction) authorizeAdmin((await db.doc(`adminEmployees/${actorUid}`).get()).data());
    if (ownerAction && (!actor.emailVerified || request.auth.token?.actorType === "pharmacy_employee")) {
      fail("permission-denied", "يلزم تأكيد بريد حساب المالك.");
    }
    const requestId = ownerAction ? actorUid : identifier(input.requestId);
    const operationId = identifier(input.operationId);
    const expectedRevision = input.expectedRevision;
    if (!Number.isInteger(expectedRevision) || expectedRevision < 0) fail("invalid-argument", "نسخة الطلب مطلوبة.");
    const requestRef = db.doc(`pharmacyRequests/${requestId}`);
    const operationRef = db.doc(`registrationOperations/${hash(actorUid + ":" + operationId)}`);
    const fingerprint = hash(JSON.stringify({action, requestId, expectedRevision,
      profile: input.profile || null, decision: input.decision || null, reason: input.reason || ""}));
    const earlyReplay = await operationRef.get();
    if (earlyReplay.exists) {
      if (earlyReplay.data().fingerprint !== fingerprint) fail("already-exists", "معرف العملية مستخدم لبيانات مختلفة.");
      return earlyReplay.data().result;
    }
    const previous = (await requestRef.get()).data();
    const profile = ownerAction ? cleanProfile(input.profile, action === "submit") : null;
    if (ownerAction) await validateDocuments(profile, actorUid, previous, bucket);
    const ownerUid = ownerAction ? actorUid : String(previous?.ownerUid || previous?.id || requestId);
    if (!ownerAction && input.decision === "approve") {
      await validateApprovalDocuments(cleanProfile(previous, true), ownerUid, bucket);
    }
    const owner = ownerAction ? actor : await auth.getUser(ownerUid).catch(() =>
      fail("failed-precondition", "حساب صاحب الطلب غير موجود."));
    return db.runTransaction(async (tx) => {
      let admin = null;
      if (!ownerAction) {
        admin = (await tx.get(db.doc(`adminEmployees/${actorUid}`))).data();
        authorizeAdmin(admin);
      }
      const replay = await tx.get(operationRef);
      if (replay.exists) {
        if (replay.data().fingerprint !== fingerprint) fail("already-exists", "معرف العملية مستخدم لبيانات مختلفة.");
        return replay.data().result;
      }
      const snapshot = await tx.get(requestRef);
      const current = snapshot.data() || {};
      const currentOwner = String(current.ownerUid || current.id || requestId);
      if (currentOwner !== ownerUid) fail("aborted", "تغير صاحب الطلب. أعد تحميله.");
      const revision = Number.isInteger(current.revision) ? current.revision : 0;
      if (revision !== expectedRevision) fail("aborted", "تغيرت نسخة الطلب. راجع النسخة الحالية قبل المتابعة.");
      const status = snapshot.exists ? statusOf(current.status) : "draft";
      const version = Number.isInteger(current.version) ? current.version : (snapshot.exists && status !== "draft" ? 1 : 0);
      const pharmacyRef = db.doc(`pharmacies/${ownerUid}`);
      const pharmacy = await tx.get(pharmacyRef);
      let nextStatus;
      let reason = "";
      let nextVersion = version;
      let submittedProfile;
      if (ownerAction) {
        if (!["draft", "requires_changes", "rejected"].includes(status) ||
            (pharmacy.exists && statusOf(pharmacy.data().status) === "approved")) {
          fail("failed-precondition", "حالة الطلب لا تسمح بالتعديل أو إعادة الإرسال.");
        }
        nextStatus = action === "submit" ? "pending" : status;
        if (action === "submit") nextVersion++;
        submittedProfile = profile;
      } else {
        if (status !== "pending") fail("failed-precondition", "هذه النسخة لها قرار سابق أو لم تقدم للمراجعة.");
        reason = String(input.reason || "").trim();
        if (reason.length > 500 || (input.decision !== "approve" && !reason)) {
          fail("invalid-argument", "سبب الرفض أو الاستكمال مطلوب، بحد أقصى 500 حرف.");
        }
        if (input.decision === "approve" && (owner.disabled || !owner.emailVerified)) {
          fail("failed-precondition", "يلزم حساب مالك صالح ومؤكد البريد قبل الاعتماد.");
        }
        nextStatus = {approve: "approved", reject: "rejected", changes: "requires_changes"}[input.decision];
        submittedProfile = cleanProfile(current, nextStatus === "approved");
      }
      // Claim the license on submission and approval, including legacy requests.
      if (action === "submit" || nextStatus === "approved") {
        const licenseKey = hash(submittedProfile.licenseNumber.normalize("NFKC").replace(/\s+/g, "").toLowerCase());
        const licenseRef = db.doc(`registrationLicenses/${licenseKey}`);
        const license = await tx.get(licenseRef);
        if (license.exists && license.data().ownerUid !== ownerUid) fail("already-exists", "رقم الترخيص مرتبط بطلب آخر.");
        // Catch existing legacy pharmacies/requests before creating a new claim.
        for (const collection of ["pharmacies", "pharmacyRequests"]) {
          const duplicates = await tx.get(db.collection(collection).where("licenseNumber", "==", submittedProfile.licenseNumber).limit(2));
          if (duplicates.docs.some((doc) => doc.id !== requestId && doc.id !== ownerUid)) {
            fail("already-exists", "توجد صيدلية أو طلب بنفس رقم الترخيص.");
          }
        }
        tx.set(licenseRef, {ownerUid, requestId});
      }
      const stamp = FieldValue.serverTimestamp();
      const next = {...current, ...(ownerAction && action === "submit" ? profile : {}),
        id: requestId, ownerUid, pharmacyId: ownerUid, email: owner.email || "",
        status: nextStatus, version: nextVersion, revision: revision + 1,
        updatedAt: stamp, createdAt: current.createdAt || stamp};
      if (action === "saveDraft") next.draft = profile;
      if (action === "submit") {
        next.draft = null;
        next.requestDate = stamp;
        next.decisionReason = "";
      }
      if (action === "decision") {
        Object.assign(next, {decisionReason: reason, reviewedByUid: actorUid,
          reviewedBy: actor.email || actorUid, reviewedByName: admin.name || actor.email || "",
          reviewedAt: stamp, decisionVersion: version});
      }
      if (nextStatus === "approved") {
        if (pharmacy.exists && pharmacy.data().sourceRequestId && pharmacy.data().sourceRequestId !== requestId) {
          fail("already-exists", "حساب الصيدلية مرتبط بطلب آخر.");
        }
        tx.set(pharmacyRef, {...submittedProfile, id: ownerUid, pharmacyId: ownerUid, ownerUid,
          email: owner.email, sourceRequestId: requestId, status: "approved", isActive: true,
          isBlocked: pharmacy.data()?.isBlocked ?? false, isOnline: pharmacy.data()?.isOnline ?? false,
          approvedBy: actorUid, approvedDate: stamp, updatedAt: stamp,
          createdAt: pharmacy.data()?.createdAt || stamp}, {merge: true});
        if (!pharmacy.exists) {
          tx.set(pharmacyRef.collection("settings").doc("general"),
            {is24Hours: submittedProfile.is24Hours, notificationsEnabled: true, createdAt: stamp});
          // Match the existing desktop defaults; never overwrite existing roles.
          for (const [roleId, name] of [["admin", "مدير النظام"], ["pharmacist", "صيدلي"], ["cashier", "أمين صندوق"]]) {
            tx.set(pharmacyRef.collection("roles").doc(roleId), {id: roleId, name, isDefault: true, isSystem: true});
            tx.set(pharmacyRef.collection("permissions").doc(roleId), {permissions: defaultPermissions[roleId]});
          }
        }
        next.approvedDate = stamp;
      }
      tx.set(requestRef, next);
      const eventId = `r${revision + 1}`;
      if (action === "submit") {
        tx.create(requestRef.collection("versions").doc(`v${nextVersion}`),
          {...profile, version: nextVersion, submittedAt: stamp, submittedBy: actorUid});
      }
      if (snapshot.exists && version > 0 && !current.version) {
        tx.set(requestRef.collection("versions").doc(`v${version}`),
          {...cleanProfile(current), version, submittedAt: current.requestDate || current.createdAt || stamp, legacy: true});
      }
      tx.create(requestRef.collection("history").doc(eventId), {
        action, from: status, status: nextStatus, version: nextVersion, reason,
        actorUid, actorName: admin?.name || actor.displayName || actor.email || "",
        createdAt: stamp,
      });
      if (action === "decision") {
        tx.create(db.doc(`adminAuditLogs/registration_${hash(requestId)}_${eventId}`), {
          action: `request_${nextStatus}`, module: "requests", targetId: requestId,
          targetType: "pharmacy_request", targetName: current.pharmacyName || "",
          performedByUid: actorUid, performedByName: admin.name || "", reason,
          version, operationId,
          before: {status, version, revision},
          after: {status: nextStatus, version: nextVersion, revision: revision + 1},
          createdAt: stamp, status: "success", source: "registrationCommand",
        });
        tx.create(requestRef.collection("notifications").doc(eventId), {
          type: "registrationDecision", requestId, version, status: nextStatus,
          title: {approved: "تم اعتماد الصيدلية", rejected: "تم رفض طلب التسجيل", requires_changes: "طلب التسجيل يحتاج استكمالًا"}[nextStatus],
          message: reason || "يمكنك الدخول إلى نظام الصيدلية الآن.", isRead: false,
          readAt: null, createdAt: stamp,
        });
      }
      const result = {requestId, pharmacyId: ownerUid, status: nextStatus,
        version: nextVersion, revision: revision + 1};
      tx.create(operationRef, {actorUid, fingerprint, result, createdAt: stamp});
      return result;
    });
  };
}

module.exports = {buildRegistrationCommand, statusOf, cleanProfile, validateDocuments, validateApprovalDocuments};
