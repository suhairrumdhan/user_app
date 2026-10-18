"use strict";

// Operator-run migration only. Never imported by the deployed functions.
const admin = require("firebase-admin");
const {FieldPath, FieldValue} = require("firebase-admin/firestore");
const {SOURCES, VERSION, refreshRow, rowsRef} = require("../src/domain/admin-lists");
const {refreshAdminOrderSummary} = require("../src/domain/admin-order-summary");

async function main() {
  const args = process.argv.slice(2);
  const projectId = args.find((value) => value.startsWith("--project="))?.slice(10);
  if (!projectId || !args.includes("--apply") || process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("Use --project=YOUR_EXISTING_PROJECT --apply with operator credentials. This migrates existing data; it does not create a test environment.");
  }
  admin.initializeApp({projectId});
  const db = admin.firestore();
  // Replace old summaries, including legacy fields, before indexing the lists.
  for (const collection of ["orders", "adminOrderSummaries"]) {
    let cursor;
    do {
      let query = db.collection(collection).orderBy(FieldPath.documentId()).limit(100);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (let offset = 0; offset < page.docs.length; offset += 10) {
        await Promise.all(page.docs.slice(offset, offset + 10).map((doc) => refreshAdminOrderSummary({db, orderId: doc.id})));
      }
      cursor = page.size === 100 ? page.docs.at(-1) : null;
    } while (cursor);
  }
  for (const [kind, source] of Object.entries(SOURCES)) {
    await db.doc(`adminLists/${kind}`).set({ready: false, schemaVersion: VERSION, startedAt: FieldValue.serverTimestamp()});
    let cursor = null;
    let projected = 0;
    do {
      let query = db.collection(source).orderBy(FieldPath.documentId()).limit(100);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (let offset = 0; offset < page.docs.length; offset += 10) {
        await Promise.all(page.docs.slice(offset, offset + 10).map((doc) => refreshRow({db, kind, id: doc.id})));
      }
      projected += page.size;
      cursor = page.size === 100 ? page.docs.at(-1) : null;
    } while (cursor);
    // Refresh existing projections as well, removing orphaned rows transactionally.
    do {
      let query = rowsRef(db, kind).orderBy(FieldPath.documentId()).limit(100);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (let offset = 0; offset < page.docs.length; offset += 10) {
        await Promise.all(page.docs.slice(offset, offset + 10).map((doc) => refreshRow({db, kind, id: doc.id})));
      }
      cursor = page.size === 100 ? page.docs.at(-1) : null;
    } while (cursor);
    await db.doc(`adminLists/${kind}`).set({ready: true, schemaVersion: VERSION, projected,
      completedAt: FieldValue.serverTimestamp()}, {merge: true});
    console.log(`${kind}: ${projected} source records projected`);
  }
}
main().catch((error) => { console.error(error.message); process.exitCode = 1; });
