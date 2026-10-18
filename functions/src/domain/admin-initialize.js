"use strict";

const {randomUUID} = require("node:crypto");
const {FieldPath, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {SOURCES, VERSION, refreshRow, rowsRef} = require("./admin-lists");
const {refreshAdminOrderSummary} = require("./admin-order-summary");

const STATUS_PATH = "adminMaintenance/adminListInitialization";
const LEASE_MS = 10 * 60 * 1000;

async function scan(db, collection, consume) {
  let cursor = null;
  let processed = 0;
  do {
    let query = db.collection(collection).orderBy(FieldPath.documentId()).limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (let offset = 0; offset < page.docs.length; offset += 10) {
      await Promise.all(page.docs.slice(offset, offset + 10).map(consume));
    }
    processed += page.size;
    cursor = page.size === 100 ? page.docs.at(-1) : null;
  } while (cursor);
  return processed;
}

async function allReady(db) {
  const markers = await Promise.all(Object.keys(SOURCES).map((kind) => db.doc(`adminLists/${kind}`).get()));
  return markers.every((marker) => marker.data()?.ready === true && marker.data()?.schemaVersion === VERSION);
}

async function initializeAdminLists({db, clock = () => Date.now()}) {
  if (await allReady(db)) return {status: "already-ready"};
  const statusRef = db.doc(STATUS_PATH);
  const leaseOwner = randomUUID();
  const started = clock();
  const acquired = await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(statusRef);
    const current = snapshot.data();
    if (current?.state === "running" && (current.leaseUntil?.toMillis?.() || 0) > started) return false;
    tx.set(statusRef, {state: "running", schemaVersion: VERSION, leaseOwner,
      leaseUntil: Timestamp.fromMillis(started + LEASE_MS), startedAt: FieldValue.serverTimestamp(),
      completedAt: null, failure: null}, {merge: true});
    return true;
  });
  if (!acquired) return {status: "already-running"};
  const counts = {};
  try {
    // Create or replace privacy-safe summaries for every existing order, then
    // remove summaries whose operational order no longer exists.
    counts.orderSummaries = await scan(db, "orders", (doc) =>
      refreshAdminOrderSummary({db, orderId: doc.id}));
    await scan(db, "adminOrderSummaries", (doc) =>
      refreshAdminOrderSummary({db, orderId: doc.id}));

    for (const [kind, source] of Object.entries(SOURCES)) {
      await db.doc(`adminLists/${kind}`).set({ready: false, schemaVersion: VERSION,
        startedAt: FieldValue.serverTimestamp()}, {merge: true});
      counts[kind] = await scan(db, source, (doc) => refreshRow({db, kind, id: doc.id}));
      // Revisit old projections so deleted source rows are removed as well.
      await scan(db, rowsRef(db, kind).path, (doc) => refreshRow({db, kind, id: doc.id}));
      await db.doc(`adminLists/${kind}`).set({ready: true, schemaVersion: VERSION,
        projected: counts[kind], completedAt: FieldValue.serverTimestamp()}, {merge: true});
    }

    await db.doc("adminAuditLogs/admin_list_initialization_v1").set({
      action: "admin_lists_initialized", module: "audit", targetType: "adminLists",
      targetId: "all", targetName: "القوائم الإدارية", reason: "تهيئة نماذج القراءة من البيانات الحالية",
      before: null, after: {status: "ready", version: VERSION}, performedByUid: "system",
      performedByName: "ترحيل لوحة الإدارة", status: "success", source: "initializeAdminListsOnce",
      operationId: "admin_list_initialization_v1", createdAt: FieldValue.serverTimestamp(),
    });
    await statusRef.set({state: "complete", schemaVersion: VERSION, counts,
      leaseOwner: null, leaseUntil: Timestamp.fromMillis(0), completedAt: FieldValue.serverTimestamp(),
      failure: null}, {merge: true});
    return {status: "complete", counts};
  } catch (error) {
    await statusRef.set({state: "failed", leaseOwner: null, leaseUntil: Timestamp.fromMillis(0),
      failedAt: FieldValue.serverTimestamp(), failure: String(error?.message || error).slice(0, 500)}, {merge: true});
    throw error;
  }
}

module.exports = {STATUS_PATH, LEASE_MS, scan, allReady, initializeAdminLists};
