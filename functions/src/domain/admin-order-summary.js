"use strict";

const {delaySummary, status} = require("./admin-delay");
const {FieldValue} = require("firebase-admin/firestore");
function safeSummary(order, id, instant = Date.now()) {
  const summary = {
    schemaVersion: 2, orderId: id, orderNumber: String(order.orderNumber || id),
    pharmacyId: String(order.pharmacyId || order.pharmacy?.pharmacyId || ""),
    pharmacyName: String(order.pharmacyName || order.pharmacy?.pharmacyName || ""),
    status: status(order.status), totalItemsCount: Number(order.totalItemsCount || 0),
    pharmacyReviewActiveMs: Number.isFinite(order.pharmacyReviewActiveMs) ? order.pharmacyReviewActiveMs : null,
    pharmacyReadyDurationMs: order.pharmacyReadyDurationMs ?? null,
    pharmacyDelayed: order.pharmacyDelayed === true, pickupOverdue: order.pickupOverdue === true,
    statusHistory: (Array.isArray(order.statusHistory) ? order.statusHistory : []).map((entry) => ({
      status: status(entry.status), changedByType: String(entry.changedByType || "system"), changedAt: entry.changedAt || null,
    })),
  };
  for (const key of ["createdAt", "updatedAt", "reviewStartedAt", "readyAt", "pickupDeadline", "pharmacyDelayAt",
    "pharmacyDelayDetectedAt", "pickupOverdueAt", "completedAt", "cancelledAt", "rejectedAt", "notCollectedAt"]) {
    summary[key] = order[key] || null;
  }
  return {...summary, ...delaySummary(order, instant)};
}
async function refreshAdminOrderSummary({db, orderId, clock = () => Date.now()}) {
  return db.runTransaction(async (tx) => {
    const source = await tx.get(db.doc(`orders/${orderId}`));
    const ref = db.doc(`adminOrderSummaries/${orderId}`);
    if (!source.exists) { tx.delete(ref); return; }
    tx.set(ref, {...safeSummary(source.data(), orderId, clock()), projectedAt: FieldValue.serverTimestamp()});
  });
}
module.exports = {safeSummary, refreshAdminOrderSummary};
