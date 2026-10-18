"use strict";

const {createHash, randomUUID} = require("node:crypto");
const {FieldPath, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const {authorize} = require("./admin-lists");
const hash = (value) => createHash("sha256").update(value).digest("hex");
const stamp = () => FieldValue.serverTimestamp();
const fail = (code, message) => { throw new HttpsError(code, message); };

function buildAdminBroadcast({db, auth, sendUser, clock = () => Date.now()}) {
  async function command(request) {
    await authorize({db, auth, request, permission: "notifications.send"});
    const input = request.data || {};
    const actorUid = request.auth.uid;
    const operationId = input.operationId;
    if (typeof operationId !== "string" || !/^[a-zA-Z0-9_-]{1,128}$/.test(operationId)) fail("invalid-argument", "معرف العملية مطلوب.");
    const action = input.action || "create";
    if (!["create", "retry"].includes(action)) fail("invalid-argument", "الإجراء غير صالح.");
    const title = String(input.title || "").trim();
    const body = String(input.body || "").trim();
    const targetType = input.targetType;
    if (action === "create" && (!title || title.length > 80 || !body || body.length > 500 || !["users", "pharmacies", "all"].includes(targetType))) {
      fail("invalid-argument", "يلزم عنوان حتى 80 حرفًا ونص حتى 500 حرف وفئة معتمدة.");
    }
    const broadcastId = action === "create" ? hash(`${actorUid}:${operationId}`) : input.broadcastId;
    if (typeof broadcastId !== "string" || !/^[a-zA-Z0-9_-]{1,128}$/.test(broadcastId)) fail("invalid-argument", "معرف الإشعار غير صالح.");
    const ref = db.doc(`adminBroadcastNotifications/${broadcastId}`);
    const op = db.doc(`adminOperations/${hash(`${actorUid}:${operationId}`)}`);
    const fingerprint = hash(JSON.stringify({action, broadcastId, title, body, targetType: targetType || null}));
    return db.runTransaction(async (tx) => {
      const [actor, replay, existing] = await Promise.all([tx.get(db.doc(`adminEmployees/${actorUid}`)), tx.get(op), tx.get(ref)]);
      const profile = actor.data();
      if (profile?.isActive !== true) fail("permission-denied", "الحساب غير مخول.");
      if (replay.exists) {
        if (replay.data().fingerprint !== fingerprint) fail("already-exists", "معرف العملية مستخدم لمحتوى مختلف.");
        return replay.data().result;
      }
      const current = existing.data();
      if (action === "create" && existing.exists) fail("already-exists", "الإشعار موجود.");
      if (action === "retry" && (!current || current.schemaVersion !== 2 || !["partial", "failed"].includes(current.status))) {
        fail("failed-precondition", "إعادة المحاولة متاحة لإشعار مكتمل المعالجة وله تعذر فقط.");
      }
      const generation = action === "retry" ? Number(current.generation || 1) + 1 : 1;
      if (action === "create") tx.create(ref, {schemaVersion: 2, title, body, targetType, status: "queued", generation,
        createdAt: stamp(), createdBy: actorUid, createdByName: profile.name || "", audienceComplete: false,
        succeeded: 0, failed: 0, pending: 0, total: 0, operationId});
      else {
        tx.update(ref, {status: "queued", generation, leaseOwner: null, leaseUntil: Timestamp.fromMillis(0), retriedAt: stamp()});
        tx.create(db.doc(`adminBroadcastJobs/${broadcastId}_${generation}`), {broadcastId, generation, createdAt: stamp()});
      }
      const auditId = `broadcast_${hash(`${actorUid}:${operationId}`)}`;
      tx.create(db.doc(`adminAuditLogs/${auditId}`), {action: action === "create" ? "notification_queued" : "notification_retry",
        module: "notifications", targetType: "broadcast", targetId: broadcastId, targetName: title || current.title,
        reason: action === "create" ? `الفئة: ${targetType}` : "إعادة المستلمين المتعثرين فقط",
        before: current ? {status: current.status} : null, after: {status: "queued", title: title || current.title, targetType: targetType || current.targetType},
        performedByUid: actorUid, performedByName: profile.name || "", operationId, status: "success", source: "adminBroadcastCommand", createdAt: stamp()});
      const result = {broadcastId, status: "queued", generation, operationId, auditId};
      tx.create(op, {actorUid, fingerprint, result, createdAt: stamp()});
      return result;
    });
  }

  async function process(broadcastId) {
    const ref = db.doc(`adminBroadcastNotifications/${broadcastId}`);
    const recipients = ref.collection("recipients");
    const leaseOwner = randomUUID();
    const started = clock();
    const broadcast = await db.runTransaction(async (tx) => {
      const source = await tx.get(ref);
      const value = source.data();
      if (!value || value.schemaVersion !== 2 || !["queued", "processing"].includes(value.status) ||
        (value.leaseUntil?.toMillis?.() || 0) > clock()) return null;
      tx.update(ref, {status: "processing", leaseOwner, leaseUntil: Timestamp.fromMillis(clock() + 600000), processingAt: stamp()});
      return value;
    });
    if (!broadcast) return;
    async function checkpoint(update) {
      return db.runTransaction(async (tx) => {
        const current = await tx.get(ref);
        if (current.data()?.leaseOwner !== leaseOwner) throw new Error("Broadcast lease changed");
        tx.update(ref, {leaseUntil: Timestamp.fromMillis(clock() + 600000), ...update});
      });
    }
    try {
      if (!["users", "pharmacies", "all"].includes(broadcast.targetType) || !broadcast.title?.trim() || broadcast.title.length > 80 || !broadcast.body?.trim() || broadcast.body.length > 500) {
        await checkpoint({status: "failed", failureReason: "invalid_payload", leaseOwner: null}); return;
      }
      if (!broadcast.audienceComplete) {
        const groups = broadcast.targetType === "all" ? ["users", "pharmacies"] : [broadcast.targetType];
        for (const group of groups) {
          if ((broadcast.audienceGroupsDone || []).includes(group)) continue;
          let cursor = broadcast.audienceGroup === group ? broadcast.audienceCursor : null;
          do {
            let query = db.collection(group).orderBy(FieldPath.documentId()).select().limit(200);
            if (cursor) query = query.startAfter(cursor);
            const page = await query.get();
            for (let offset = 0; offset < page.docs.length; offset += 20) {
              await Promise.all(page.docs.slice(offset, offset + 20).map((doc) => db.runTransaction(async (tx) => {
                const recipient = recipients.doc(hash(`${group}/${doc.id}`));
                const existing = await tx.get(recipient);
                if (!existing.exists) tx.create(recipient, {group, recipientId: doc.id, status: "pending", attempts: 0, lastGeneration: 0, createdAt: stamp()});
              })));
            }
            cursor = page.size === 200 ? page.docs.at(-1).id : null;
            await checkpoint({audienceGroup: group, audienceCursor: cursor,
              ...(!cursor ? {audienceGroupsDone: FieldValue.arrayUnion(group)} : {})});
            if (clock() - started > 450000) { await checkpoint({status: "queued", leaseOwner: null, leaseUntil: Timestamp.fromMillis(0)}); return; }
          } while (cursor);
        }
        await checkpoint({audienceComplete: true});
      }
      let cursor;
      do {
        let query = recipients.orderBy(FieldPath.documentId()).limit(100);
        if (cursor) query = query.startAfter(cursor);
        const page = await query.get();
        for (const doc of page.docs) {
          const recipient = doc.data();
          if (recipient.status === "succeeded" || recipient.lastGeneration === broadcast.generation) continue;
          const noticeId = `admin_${broadcastId}`;
          const notice = db.doc(`${recipient.group}/${recipient.recipientId}/notifications/${noticeId}`);
          let success = false;
          let failureReason = "delivery_failed";
          try {
            await db.runTransaction(async (tx) => {
              const [existing, account] = await Promise.all([tx.get(notice), tx.get(db.doc(`${recipient.group}/${recipient.recipientId}`))]);
              if (!account.exists) throw new Error("Recipient account removed");
              if (!existing.exists) tx.create(notice, {title: broadcast.title, message: broadcast.body, body: broadcast.body,
                type: recipient.group === "users" ? "adminMessage" : "adminBroadcast", referenceType: "system", referenceId: broadcastId,
                actionId: broadcastId, actionRoute: null, isActionable: false, isDeleted: false, isRead: false, readAt: null,
                userId: recipient.group === "users" ? recipient.recipientId : null,
                pharmacyId: recipient.group === "pharmacies" ? recipient.recipientId : null,
                priority: "normal", pushHandledBy: "sendAdminBroadcast", eventId: noticeId, createdAt: stamp()});
            });
            if (recipient.group === "pharmacies") success = true;
            else {
              const result = await sendUser({userId: recipient.recipientId, broadcastId, noticeId, title: broadcast.title, body: broadcast.body});
              success = result.success === true; failureReason = result.reason || failureReason;
            }
          } catch (_) { failureReason = "delivery_failed"; }
          await db.runTransaction(async (tx) => {
            const [current, recipientState] = await Promise.all([tx.get(ref), tx.get(doc.ref)]);
            if (current.data()?.leaseOwner !== leaseOwner) throw new Error("Broadcast lease changed");
            if (recipientState.data()?.status === "succeeded") return;
            tx.update(doc.ref, {status: success ? "succeeded" : "failed", lastGeneration: broadcast.generation,
              attempts: FieldValue.increment(1), failureReason: success ? null : failureReason, completedAt: stamp()});
          });
          if (clock() - started > 450000) { await checkpoint({status: "queued", leaseOwner: null, leaseUntil: Timestamp.fromMillis(0)}); return; }
        }
        cursor = page.size === 100 ? page.docs.at(-1) : null;
        const [done, failures, size] = await Promise.all([recipients.where("status", "==", "succeeded").count().get(),
          recipients.where("status", "==", "failed").count().get(), recipients.count().get()]);
        await checkpoint({succeeded: done.data().count, failed: failures.data().count, total: size.data().count,
          pending: size.data().count - done.data().count - failures.data().count});
      } while (cursor);
      const [total, succeeded, failed] = await Promise.all([recipients.count().get(), recipients.where("status", "==", "succeeded").count().get(), recipients.where("status", "==", "failed").count().get()]);
      const ok = succeeded.data().count, bad = failed.data().count;
      await checkpoint({total: total.data().count, succeeded: ok, failed: bad, pending: total.data().count - ok - bad,
        status: bad ? ok ? "partial" : "failed" : "sent", completedAt: stamp(), leaseOwner: null});
    } catch (error) {
      // An infrastructure interruption stays recoverable; confirmed recipients
      // are never resent. A provider acknowledgement lost before persistence
      // can repeat transport, so the stable event ID is also used by the client.
      await db.runTransaction(async (tx) => {
        const current = await tx.get(ref);
        if (current.data()?.leaseOwner === leaseOwner) tx.update(ref, {leaseUntil: Timestamp.fromMillis(0)});
      });
      throw error;
    }
  }
  async function recover() {
    let cursor;
    do {
      let query = db.collection("adminBroadcastNotifications").where("status", "in", ["queued", "processing"])
        .orderBy(FieldPath.documentId()).limit(100);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (const doc of page.docs) {
        if (doc.data().schemaVersion === 2 && (doc.data().leaseUntil?.toMillis?.() || 0) <= clock()) {
          await process(doc.id); return;
        }
      }
      cursor = page.size === 100 ? page.docs.at(-1) : null;
    } while (cursor);
  }
  return {command, process, recover};
}
module.exports = {buildAdminBroadcast};
