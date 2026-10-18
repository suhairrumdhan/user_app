"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {after, before, test} = require("node:test");
const {performance} = require("node:perf_hooks");
const {app, auth, createAccount, db, projectId, suffix} = require("./emulator-helpers.cjs");
const {buildAdminInsights} = require("../../src/domain/admin-insights");
const {buildAdminList} = require("../../src/domain/admin-lists");

let reviewer;
const generated = [];
const measured = {};
const fixtureWrites = new Map();
const add = (collection, id, data) => {
  const documentPath = `${collection}/${id}`;
  generated.push(documentPath);
  const writes = fixtureWrites.get(collection) || [];
  writes.push({documentPath, data}); fixtureWrites.set(collection, writes);
};
const hashId = (n) => `admperf_${suffix}_${String(n).padStart(4, "0")}`;

let insights;
let list;
const request = (data) => ({auth: {uid: reviewer.uid, token: {auth_time: Math.floor(Date.now() / 1000)}}, data});

async function measure(label, count, fn) {
  const samples = [];
  for (let i = 0; i < count; i += 1) {
    const start = performance.now();
    await fn();
    samples.push(performance.now() - start);
  }
  const sorted = [...samples].sort((a, b) => a - b);
  measured[label] = {runs: count, averageMs: Number((samples.reduce((a, b) => a + b, 0) / count).toFixed(2)),
    maxMs: Number(Math.max(...samples).toFixed(2)), p95Ms: Number(sorted[Math.ceil(sorted.length * 0.95) - 1].toFixed(2)),
    errorRate: 0, samplesMs: samples.map((v) => Number(v.toFixed(2)))};
}

before(async () => {
  assert.equal(process.env.GCLOUD_PROJECT, projectId);
  reviewer = await createAccount("adm_perf");
  add("adminEmployees", reviewer.uid, {isActive: true, role: "super_admin", name: "Synthetic benchmark account"});

  const jobs = [];
  // P01/P04: representative 1,000-row dashboard/report datasets.
  for (let i = 0; i < 1000; i += 1) {
    const id = hashId(i);
    jobs.push(add("users", id, {fullName: `Synthetic user ${i}`, createdAt: new Date(Date.now() - i * 60000)}));
    const order = {id, orderNumber: id, pharmacyId: `ph_${i % 200}`, pharmacyName: `Synthetic pharmacy ${i % 200}`,
      createdAt: new Date(Date.now() - i * 60000), updatedAt: new Date(), status: i % 4 === 0 ? "completed" : "ready",
      medicines: [{medicineId: `m_${i}`, quantity: 1}], totalItemsCount: 1};
    jobs.push(add("adminOrderSummaries", id, order));
    jobs.push(add("orders", id, order));
    if (i < 1000) {
      const row = {schemaVersion: 1, sortAt: Date.now() - i, state: i % 2 ? "pending" : "approved", group: "",
        searchKeys: ["admperf"], row: {id, pharmacyName: `admperf pharmacy ${i}`, ownerName: `Synthetic owner ${i}`, status: "pending"}};
      for (const kind of ["requests", "orders", "pharmacies"]) {
        jobs.push(add(`adminLists/${kind}/adminListRows`, `${kind}_${id}`, row));
      }
    }
  }
  for (let i = 0; i < 200; i += 1) {
    const id = `admperf_pharmacy_${suffix}_${i}`;
    jobs.push(add("pharmacies", id, {pharmacyName: `Synthetic pharmacy ${i}`, name: `Synthetic ${i}`, status: "approved",
      isOnline: i % 2 === 0, isBlocked: false, isActive: true,
      location: {address: `Test street ${i}`, latitude: 32 + (i % 10) / 100, longitude: 13 + (i % 10) / 100},
      createdAt: new Date(), approvedDate: new Date()}));
    jobs.push(add("medicine_search_index", `admperf_medicine_${suffix}_${i}`, {pharmacyId: id, pharmacyName: `Synthetic pharmacy ${i}`,
      medicineName: `Synthetic medicine ${i}`, scientificName: `synthetic-${i}`, isActive: true, isExpired: false,
      invalidExpiry: false, invalidStock: false, sellByPiece: false, availableQuantity: 100, pharmacyVisible: true, updatedAt: new Date()}));
  }
  for (const kind of ["requests", "orders", "pharmacies"]) {
    generated.push(`adminLists/${kind}`);
    jobs.push(db.doc(`adminLists/${kind}`).set({schemaVersion: 1, ready: true, total: 1000}));
  }
  for (const [collection, writes] of fixtureWrites) {
    for (let start = 0; start < writes.length; start += 350) {
      const batch = db.batch();
      for (const write of writes.slice(start, start + 350)) batch.set(db.doc(write.documentPath), write.data);
      await batch.commit();
    }
  }
  insights = buildAdminInsights({db, auth});
  list = buildAdminList({db, auth});
});

after(async () => {
  for (let start = 0; start < generated.length; start += 400) {
    const batch = db.batch();
    generated.slice(start, start + 400).forEach((path) => batch.delete(db.doc(path)));
    await batch.commit().catch(() => {});
  }
  await Promise.all([reviewer?.uid ? auth.deleteUser(reviewer.uid).catch(() => {}) : Promise.resolve(), app.delete()]);
});

test("TC-ADM-P01 dashboard metrics: 10 measured calls", async () => {
  await measure("TC-ADM-P01 dashboard", 10, async () => {
    const value = await insights(request({mode: "dashboard"}));
    assert.equal(value.orders, 1000);
    assert.equal(value.users, 1000);
  });
  assert.ok(measured["TC-ADM-P01 dashboard"].maxMs <= 3000, JSON.stringify(measured["TC-ADM-P01 dashboard"]));
});

test("TC-ADM-P02 search/filter: 10 measured calls per list over 1,000 synthetic rows", async () => {
  for (const kind of ["requests", "orders", "pharmacies"]) {
    await measure(`TC-ADM-P02 ${kind}`, 10, async () => {
      const value = await list(request({kind, q: "admperf"}));
      assert.ok(value.rows.length > 0);
      assert.equal(value.total, 1000);
    });
    assert.ok(measured[`TC-ADM-P02 ${kind}`].maxMs <= 3000, JSON.stringify(measured[`TC-ADM-P02 ${kind}`]));
  }
});

test("TC-ADM-P03 map coverage: 5 measured calls over 200 geocoded pharmacies", async () => {
  await measure("TC-ADM-P03 coverage", 5, async () => {
    const value = await insights(request({mode: "coverage"}));
    assert.ok(value.total >= 200);
    assert.equal(value.invalidCoordinates, 0);
  });
  assert.ok(measured["TC-ADM-P03 coverage"].maxMs <= 10000, JSON.stringify(measured["TC-ADM-P03 coverage"]));
});

test("TC-ADM-P04 report aggregation: 5 measured calls over 1,000 orders", async () => {
  await measure("TC-ADM-P04 reports", 5, async () => {
    const value = await insights(request({mode: "reports", days: 30}));
    assert.equal(value.total, 1000);
  });
  assert.ok(measured["TC-ADM-P04 reports"].maxMs <= 10000, JSON.stringify(measured["TC-ADM-P04 reports"]));
});

after(() => {
  const resultPath = path.join(__dirname, "..", "results", "TC-ADM-P01-P04-benchmarks.json");
  fs.mkdirSync(path.dirname(resultPath), {recursive: true});
  fs.writeFileSync(resultPath, `${JSON.stringify({projectId, fixture: "synthetic emulator data", measurementScope: "domain handler + Firestore Emulator; excludes HTTP transport, UI rendering, browser and external network latency", measured}, null, 2)}\n`);
});
