"use strict";

const {Timestamp, FieldPath} = require("firebase-admin/firestore");
const DAY_MS = 24 * 60 * 60 * 1000;
const ACTIVE_REVIEW = new Set(["underReview", "confirmedReserved", "preparing"]);
const SCANNED_STATUSES = [...ACTIVE_REVIEW, "partialOfferPending", "ready"];

function millis(value) {
  const result = value?.toMillis?.() ?? (value instanceof Date ? value.getTime() : Date.parse(value));
  return Number.isFinite(result) ? result : null;
}

function timerState(order, instant) {
  const stored = Number(order.pharmacyReviewActiveMs || 0);
  const started = millis(order.reviewStartedAt);
  const elapsed = Number.isFinite(stored) && stored >= 0 ? stored : 0;
  // Decision waiting never contributes, even if an old snapshot retained start.
  const activeMs = elapsed + (ACTIVE_REVIEW.has(order.status) && started !== null ?
    Math.max(0, instant - started) : 0);
  const ready = millis(order.readyAt);
  const deadline = ready === null ? millis(order.pickupDeadline) : ready + DAY_MS;
  return {
    activeMs,
    pharmacyDelayed: SCANNED_STATUSES.includes(order.status) && activeMs >= DAY_MS,
    pickupOverdue: order.status === "ready" && deadline !== null && instant >= deadline,
    deadline,
  };
}

function notification({order, orderId, kind, timestamp, userId, pharmacyId}) {
  const pickup = kind === "pickup";
  const message = pickup ? "تجاوز الطلب مهلة الاستلام. تواصل مع الصيدلية؛ الطلب ما زال جاهزًا للاستلام." :
    "تجاوزت مدة معالجة الطلب 24 ساعة بعد استبعاد انتظار قرار المستخدم.";
  return {
    userId, pharmacyId, orderId, type: "orderUpdate", referenceType: "order",
    referenceId: orderId, actionRoute: "/orders", actionId: orderId,
    title: pickup ? "تأخر استلام الطلب" : "تأخر معالجة الطلب", message, body: message,
    priority: "high", isRead: false, isDeleted: false, isActionable: true,
    createdAt: timestamp, readAt: null,
    extraData: {source: "orderTimer", kind, status: order.status},
  };
}

async function processOrderTimer({db, orderId, clock = () => Date.now()}) {
  const orderRef = db.collection("orders").doc(orderId);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(orderRef);
    if (!snapshot.exists) return {changed: false};
    const order = snapshot.data();
    if (!SCANNED_STATUSES.includes(order.status)) return {changed: false};
    const instant = clock();
    const state = timerState(order, instant);
    const timestamp = Timestamp.fromMillis(instant);
    const pharmacyId = String(order.pharmacy?.pharmacyId || order.pharmacyId || "");
    const userId = String(order.user?.userId || order.userId || "");
    if (!pharmacyId || !userId) return {changed: false, invalidOwner: true};
    const alerts = [];
    for (const [kind, due] of [["review", state.pharmacyDelayed], ["pickup", state.pickupOverdue]]) {
      if (!due) continue;
      const id = `timer_${kind}_${orderId}`;
      const marker = orderRef.collection("timerEvents").doc(kind);
      const markerSnapshot = await transaction.get(marker);
      const pharmacyNotice = db.collection("pharmacies").doc(pharmacyId).collection("notifications").doc(id);
      const userNotice = kind === "pickup" ? db.collection("users").doc(userId).collection("notifications").doc(id) : null;
      const pharmacySnapshot = await transaction.get(pharmacyNotice);
      const userSnapshot = userNotice ? await transaction.get(userNotice) : null;
      alerts.push({kind, marker, markerSnapshot, pharmacyNotice, pharmacySnapshot, userNotice, userSnapshot});
    }
    const update = {};
    if (state.pharmacyDelayed && order.pharmacyDelayed !== true) {
      update.pharmacyDelayed = true;
      update.pharmacyDelayDetectedAt = timestamp;
    }
    if (state.pickupOverdue && order.pickupOverdue !== true) {
      update.pickupOverdue = true;
      update.pickupOverdueAt = Timestamp.fromMillis(state.deadline);
    }
    for (const alert of alerts) {
      const value = notification({order, orderId, kind: alert.kind, timestamp, pharmacyId, userId});
      if (!alert.markerSnapshot.exists) transaction.create(alert.marker, {
        kind: alert.kind, detectedAt: timestamp, status: order.status,
        pharmacyReviewActiveMs: state.activeMs, pickupDeadline: order.pickupDeadline || null,
      });
      if (!alert.pharmacySnapshot.exists) transaction.create(alert.pharmacyNotice, value);
      if (alert.userNotice && !alert.userSnapshot.exists) transaction.create(alert.userNotice, value);
    }
    if (Object.keys(update).length) transaction.update(orderRef, {...update, updatedAt: timestamp});
    // No status, stock, invoice, receipt or not-collected incident is mutated.
    return {changed: Object.keys(update).length > 0};
  });
}

async function scanOrderTimers({db, clock = () => Date.now()}) {
  let cursor;
  let checked = 0;
  do {
    let query = db.collection("orders").where("status", "in", SCANNED_STATUSES)
      .orderBy(FieldPath.documentId()).limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const doc of page.docs) {
      await processOrderTimer({db, orderId: doc.id, clock});
      checked++;
    }
    cursor = page.size === 100 ? page.docs[page.docs.length - 1] : null;
  } while (cursor);
  return {checked};
}

module.exports = {timerState, processOrderTimer, scanOrderTimers};
