"use strict";

const {createHash} = require("node:crypto");
const {FieldValue} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const {authorize, project, rowsRef} = require("./admin-lists");
const fail = (code, message) => { throw new HttpsError(code, message); };
const hash = (value) => createHash("sha256").update(value).digest("hex");

function buildAdminVisibilityCommand({db, auth}) {
  return async (request) => {
    await authorize({db, auth, request, permission: "pharmacies.manage"});
    const {pharmacyId, operationId, hidden, expectedRevision, expectedHidden} = request.data || {};
    const reason = String(request.data?.reason || "").trim();
    if (![pharmacyId, operationId].every((id) => typeof id === "string" && /^[a-zA-Z0-9_-]{1,128}$/.test(id)) ||
      typeof hidden !== "boolean" || typeof expectedHidden !== "boolean" || !Number.isInteger(expectedRevision) || expectedRevision < 0 ||
      !reason || reason.length > 500) fail("invalid-argument", "يلزم سبب لا يتجاوز 500 حرف وحالة ونسخة متوقعتان.");
    const actorUid = request.auth.uid;
    const fingerprint = hash(JSON.stringify({pharmacyId, hidden, reason, expectedRevision, expectedHidden}));
    const operationRef = db.doc(`adminOperations/${hash(`${actorUid}:${operationId}`)}`);
    const ref = db.doc(`pharmacies/${pharmacyId}`);
    return db.runTransaction(async (tx) => {
      const [actor, operation, snapshot] = await Promise.all([
        tx.get(db.doc(`adminEmployees/${actorUid}`)), tx.get(operationRef), tx.get(ref),
      ]);
      const profile = actor.data();
      if (profile?.isActive !== true) {
        fail("permission-denied", "الحساب غير مخول لهذا الإجراء.");
      }
      if (operation.exists) {
        if (operation.data().fingerprint !== fingerprint) fail("already-exists", "معرف العملية مستخدم لمحتوى مختلف.");
        return operation.data().result;
      }
      if (!snapshot.exists) fail("not-found", "الصيدلية غير موجودة.");
      const current = snapshot.data();
      const revision = Number.isInteger(current.visibilityRevision) ? current.visibilityRevision : 0;
      if (revision !== expectedRevision || (current.isBlocked === true) !== expectedHidden) {
        fail("aborted", "تغير ظهور الصيدلية. حدّث بياناتها وراجع القرار مجددًا.");
      }
      if (current.status !== "approved") fail("failed-precondition", "الظهور متاح للصيدلية المعتمدة فقط.");
      if (hidden === expectedHidden) fail("failed-precondition", "القرار لا يغير حالة الظهور.");
      const stamp = FieldValue.serverTimestamp();
      const before = {isBlocked: current.isBlocked === true, visibilityRevision: revision};
      const after = {isBlocked: hidden, visibilityRevision: revision + 1};
      const update = {...after, visibilityReason: reason, visibilityChangedBy: actorUid, visibilityChangedAt: stamp};
      tx.update(ref, update);
      // The operational list updates atomically. The existing retried stock-index
      // trigger propagates isBlocked; order creation checks the pharmacy source.
      const projected = project("pharmacies", pharmacyId, {...current, ...update});
      projected.row.visibilityChangedAt = new Date().toISOString();
      tx.set(rowsRef(db, "pharmacies").doc(pharmacyId), {...projected, projectedAt: stamp});
      const auditId = `visibility_${hash(`${actorUid}:${operationId}`)}`;
      tx.create(db.doc(`adminAuditLogs/${auditId}`), {action: hidden ? "hide_pharmacy" : "show_pharmacy",
        module: "pharmacies", targetType: "pharmacy", targetId: pharmacyId,
        targetName: current.pharmacyName || current.name || "", reason, before, after,
        performedByUid: actorUid, performedByName: profile.name || "", operationId,
        createdAt: stamp, status: "success", source: "adminVisibilityCommand"});
      const result = {pharmacyId, ...after, operationId, auditId};
      tx.create(operationRef, {fingerprint, result, actorUid, createdAt: stamp});
      return result;
    });
  };
}

module.exports = {buildAdminVisibilityCommand};
