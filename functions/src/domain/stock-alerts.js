"use strict";

const {Timestamp, FieldPath} = require("firebase-admin/firestore");
const {createHash} = require("node:crypto");
const logger = require("firebase-functions/logger");
const {loadStock, stockProjection, millis} = require("./batch-stock");
const DAY = 24 * 60 * 60 * 1000;
const TYPES = ["lowStock", "nearExpiry", "expiredStock"];

async function refreshStockAlerts({db, pharmacyId, medicineId, clock = () => Date.now()}) {
  const pharmacy = db.collection("pharmacies").doc(pharmacyId);
  const medicineRef = pharmacy.collection("medicines").doc(medicineId);
  return db.runTransaction(async (transaction) => {
    const timestamp = Timestamp.fromMillis(clock());
    const pharmacySnapshot = await transaction.get(pharmacy);
    if (pharmacySnapshot.data()?.status !== "approved" || pharmacySnapshot.data()?.isActive === false) return;
    const snapshot = await transaction.get(medicineRef);
    const active = snapshot.exists && snapshot.data().isActive !== false && snapshot.data().isDeleted !== true;
    const stock = active ? await loadStock(transaction, medicineRef, timestamp, snapshot) : null;
    const projection = stock ? stockProjection(stock) : null;
    const medicine = snapshot.data() || {};
    const threshold = medicine.minStockLevel;
    const available = projection ? (medicine.unitsPerPackage > 0 ?
      projection.availablePieceQuantity / medicine.unitsPerPackage : projection.availableQuantity) : 0;
    const expiring = stock?.batches.filter((batch) => batch.isActive !== false && batch.quarantined !== true &&
      (Number(batch.quantity || 0) > 0 || Number(batch.pieceQuantity || 0) > 0) && Number.isFinite(millis(batch.expiryDate))) || [];
    const expired = expiring.filter((batch) => millis(batch.expiryDate) <= timestamp.toMillis());
    const soon = expiring.filter((batch) => millis(batch.expiryDate) > timestamp.toMillis() && millis(batch.expiryDate) <= timestamp.toMillis() + 30 * DAY);
    const conditions = {lowStock: active && typeof threshold === "number" && threshold >= 0 && available <= threshold,
      nearExpiry: soon.length > 0, expiredStock: expired.length > 0};
    const states = [];
    const key = createHash("sha256").update(medicineId).digest("hex").slice(0, 32);
    for (const type of TYPES) {
      const ref = pharmacy.collection("stockAlertStates").doc(`${type}_${key}`);
      const previous = (await transaction.get(ref)).data() || {};
      const noticeRef = previous.notificationId ? pharmacy.collection("notifications").doc(previous.notificationId) : null;
      const notice = noticeRef ? await transaction.get(noticeRef) : null;
      states.push({type, ref, previous, noticeRef, notice});
    }
    if (projection) {
      const summary = {};
      for (const field of ["earliestStockExpiryDate", "expiredBatchCount", "nearExpiryBatchCount", "expiredCostValue", "expirySummaryVersion"]) {
        if (JSON.stringify(medicine[field]) !== JSON.stringify(projection[field])) summary[field] = projection[field];
      }
      // Only derived, changed fields: no stock movement and no trigger loop.
      if (Object.keys(summary).length) transaction.update(medicineRef, summary);
    }
    for (const {type, ref, previous, noticeRef, notice} of states) {
      const due = conditions[type];
      if (!due) {
        if (previous.active === true) {
          transaction.update(ref, {active: false, resolvedAt: timestamp});
          if (notice?.exists) transaction.update(noticeRef, {"extraData.resolved": true, "extraData.resolvedAt": timestamp});
        }
        continue;
      }
      if (previous.active === true) continue;
      const cycle = Number(previous.cycle || 0) + 1;
      const notificationId = `stock_${type}_${key}_${cycle}`;
      const name = String(medicine.name || medicineId);
      const title = type === "lowStock" ? "نقص في المخزون المتاح" : type === "nearExpiry" ? "دفعات قريبة الانتهاء" : "دفعات منتهية الصلاحية";
      const message = type === "lowStock" ? `${name}: المتاح للبيع ${projection.availableQuantity} عبوة${medicine.unitsPerPackage > 0 ? ` أو ما يعادل ${projection.availablePieceQuantity} قطعة` : ""}؛ حد التنبيه ${threshold} عبوة.` :
        `${name}: توجد ${type === "nearExpiry" ? soon.length : expired.length} دفعة ${type === "nearExpiry" ? "تنتهي خلال 30 يومًا" : "منتهية الصلاحية"}. افتح دفعات الدواء للمراجعة.`;
      transaction.create(pharmacy.collection("notifications").doc(notificationId), {
        pharmacyId, type, title, message, body: message, referenceType: "medicine", referenceId: medicineId,
        actionRoute: "/inventory", actionId: medicineId, isRead: false, isDeleted: false, isActionable: true,
        priority: type === "expiredStock" ? "high" : "normal", createdAt: timestamp, readAt: null,
        extraData: {source: "stockAlerts", cycle, medicineId, resolved: false,
          batchIds: (type === "nearExpiry" ? soon : expired).map((batch) => batch.id)},
      });
      transaction.set(ref, {medicineId, type, active: true, cycle, notificationId, detectedAt: timestamp});
    }
  });
}

async function scanStockAlerts({db}) {
  let pharmacyCursor; let checked = 0; let failed = 0;
  do {
    let query = db.collection("pharmacies").where("status", "==", "approved").orderBy(FieldPath.documentId()).limit(50);
    if (pharmacyCursor) query = query.startAfter(pharmacyCursor);
    const pharmacies = await query.get();
    for (const pharmacy of pharmacies.docs) {
      if (pharmacy.data().isActive === false) continue;
      let cursor;
      do {
        let source = pharmacy.ref.collection("medicines").orderBy(FieldPath.documentId()).limit(100);
        if (cursor) source = source.startAfter(cursor);
        const medicines = await source.get();
        for (const medicine of medicines.docs) {
          try {
            await refreshStockAlerts({db, pharmacyId: pharmacy.id, medicineId: medicine.id}); checked++;
          } catch (error) {
            failed++;
            logger.error("Stock alert refresh failed", {pharmacyId: pharmacy.id, medicineId: medicine.id,
              code: error.code || "unknown"});
          }
        }
        cursor = medicines.size === 100 ? medicines.docs.at(-1) : null;
      } while (cursor);
    }
    pharmacyCursor = pharmacies.size === 50 ? pharmacies.docs.at(-1) : null;
  } while (pharmacyCursor);
  // A damaged medicine must not starve all later pharmacies of expiry alerts.
  // Fail the completed scan so monitoring/retries still see the missed records.
  if (failed) throw new Error(`Stock alerts failed for ${failed} medicines; ${checked} refreshed.`);
  return {checked};
}

module.exports = {refreshStockAlerts, scanStockAlerts};
