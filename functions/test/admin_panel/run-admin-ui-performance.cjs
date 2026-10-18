"use strict";

const fs = require("node:fs");
const path = require("node:path");
const net = require("node:net");
const {spawnSync} = require("node:child_process");
const {randomUUID} = require("node:crypto");
const admin = require("firebase-admin");

const projectId = "demo-roshita-admin-nf";
const panelRoot = "C:\\Users\\hp\\OneDrive\\Desktop\\مشروع التخرج\\Roshita_Admin_Panel";
const suffix = randomUUID().replaceAll("-", "");
const email = `admin-ui-${suffix}@example.invalid`;
const password = `Ui-${suffix.slice(0, 16)}!z`;
const resultsDir = path.join(__dirname, "..", "results");
const resultPath = path.join(resultsDir, "TC-ADM-P01-P04-browser.json");
const checkpointPath = path.join(panelRoot, "test-results", "TC-ADM-P01-P04-browser-checkpoint.json");
const authUrl = "http://127.0.0.1:19099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key";
const app = admin.initializeApp({projectId}, `admin-ui-perf-${suffix}`);
const db = admin.firestore(app);
const auth = admin.auth(app);
const generated = [];
let user;
let details = "";

async function freePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      const {port} = server.address();
      server.close((error) => error ? reject(error) : resolve(port));
    });
  });
}

function record(collection, id, data, pending) {
  const documentPath = `${collection}/${id}`;
  generated.push(documentPath);
  pending.push({documentPath, data});
}

async function writeBatches(pending) {
  for (let start = 0; start < pending.length; start += 350) {
    const batch = db.batch();
    for (const item of pending.slice(start, start + 350)) batch.set(db.doc(item.documentPath), item.data);
    await batch.commit();
  }
}

async function seed() {
  if (process.env.GCLOUD_PROJECT !== projectId) throw new Error("Isolated demo project required.");
  const response = await fetch(authUrl, {method: "POST", headers: {"content-type": "application/json"},
    body: JSON.stringify({email, password, returnSecureToken: true})});
  const authData = await response.json();
  if (!response.ok) throw new Error(`Auth Emulator account creation failed: ${authData.error?.message || response.status}`);
  user = {uid: authData.localId};

  const pending = [];
  record("adminEmployees", user.uid, {isActive: true, role: "super_admin", name: "Synthetic UI Benchmark Admin", email}, pending);
  for (const kind of ["requests", "orders", "pharmacies"]) {
    record("adminLists", kind, {schemaVersion: 1, ready: true, total: 1000}, pending);
    for (let i = 0; i < 1000; i += 1) {
      const id = `${kind}_admperf_${suffix}_${String(i).padStart(4, "0")}`;
      const pharmacyId = `admperf_pharmacy_${suffix}_${i % 200}`;
      const row = kind === "requests" ? {id, pharmacyName: `admperf pharmacy ${i}`, ownerName: `Synthetic owner ${i}`,
        licenseNumber: `LIC-${i}`, status: "pending", revision: 0, version: 1, createdAt: new Date(Date.now() - i * 1000).toISOString(),
        requestDate: new Date(Date.now() - i * 1000).toISOString(), location: {address: "Test", latitude: 32.3, longitude: 13.2}} :
        kind === "orders" ? {id, orderNumber: `ADM-${i}`, pharmacyId, pharmacyName: `admperf pharmacy ${i % 200}`,
          status: i % 2 ? "completed" : "ready", createdAt: new Date(Date.now() - i * 1000).toISOString(), totalItemsCount: 1, statusHistory: []} :
          {id, pharmacyName: `admperf pharmacy ${i}`, name: `admperf pharmacy ${i}`, ownerName: `Synthetic owner ${i}`,
            licenseNumber: `LIC-${i}`, status: "approved", isBlocked: i % 2 === 1, isOnline: i % 2 === 0, isActive: true,
            location: {address: `Synthetic Street ${i}`, latitude: 32.3, longitude: 13.2}};
      record(`adminLists/${kind}/adminListRows`, id, {schemaVersion: 1, sortAt: Date.now() - i,
        state: kind === "requests" ? "pending" : kind === "pharmacies" ? "visible" : row.status,
        group: kind === "orders" ? pharmacyId : "", searchKeys: ["admperf", `${kind}_unique_${String(i).padStart(4, "0")}`], row}, pending);
    }
  }

  for (let i = 0; i < 1000; i += 1) {
    const id = `admperf_order_${suffix}_${String(i).padStart(4, "0")}`;
    record("adminOrderSummaries", id, {id, orderNumber: `ADM-${i}`, pharmacyId: `admperf_pharmacy_${suffix}_${i % 200}`,
      pharmacyName: `Synthetic pharmacy ${i % 200}`, status: i % 4 === 0 ? "completed" : "ready",
      createdAt: new Date(Date.now() - i * 60000), updatedAt: new Date(), totalItemsCount: 1}, pending);
  }
  for (let i = 0; i < 200; i += 1) {
    const id = `admperf_pharmacy_${suffix}_${i}`;
    record("pharmacies", id, {pharmacyName: `Synthetic pharmacy ${i}`, name: `Synthetic pharmacy ${i}`,
      status: "approved", isOnline: i % 2 === 0, isBlocked: i % 2 === 1, isActive: true,
      location: {address: `Synthetic Street ${i}`, latitude: 32.3 + i / 10000, longitude: 13.2 + i / 10000},
      createdAt: new Date(), approvedDate: new Date()}, pending);
    record("medicine_search_index", `admperf_medicine_${suffix}_${i}`, {pharmacyId: id, pharmacyName: `Synthetic pharmacy ${i}`,
      medicineName: `Synthetic medicine ${i}`, scientificName: `Synthetic ${i}`, isActive: true, isExpired: false,
      invalidExpiry: false, invalidStock: false, sellByPiece: false, availableQuantity: 100,
      availablePieceQuantity: 0, pharmacyVisible: true, updatedAt: new Date()}, pending);
  }
  for (let i = 0; i < 20; i += 1) {
    record("pharmacyRequests", `admperf_request_${suffix}_${i}`, {pharmacyName: `Synthetic registration ${i}`,
      status: "pending", requestDate: new Date(), createdAt: new Date()}, pending);
  }
  await writeBatches(pending);
  details = `Seeded ${pending.length} synthetic Firestore documents with direct list fixtures; ${suffix}.`;
}

async function cleanup() {
  for (let start = 0; start < generated.length; start += 350) {
    const batch = db.batch();
    for (const documentPath of generated.slice(start, start + 350)) batch.delete(db.doc(documentPath));
    await batch.commit().catch(() => {});
  }
  await Promise.all([user?.uid ? auth.deleteUser(user.uid).catch(() => {}) : Promise.resolve(),
    app.delete().catch((error) => { if (error?.code !== "app/app-deleted") throw error; })]);
}

async function main() {
  const startedAt = new Date().toISOString();
  let exitCode = 1;
  let output = "";
  try {
    await seed();
    fs.mkdirSync(path.dirname(checkpointPath), {recursive: true});
    fs.rmSync(checkpointPath, {force: true});
    const uiPort = await freePort();
    const cli = path.join(panelRoot, "node_modules", "@playwright", "test", "cli.js");
    const env = {...process.env, ADMIN_TEST_EMAIL: email, ADMIN_TEST_PASSWORD: password,
      ADMIN_PERF_PRODUCTION_UI: "true",
      ADMIN_PERF_PORT: String(uiPort),
      ADMIN_BROWSER_CHANNEL: "chrome", VITE_FIREBASE_USE_EMULATORS: "true", VITE_FIREBASE_PROJECT_ID: projectId,
      VITE_FIREBASE_AUTH_EMULATOR_PORT: "19099", VITE_FIREBASE_FIRESTORE_EMULATOR_PORT: "18080",
      VITE_FIREBASE_FUNCTIONS_EMULATOR_PORT: "15001", VITE_FIREBASE_STORAGE_EMULATOR_PORT: "19199",
      ADMIN_UI_RESULT_PATH: checkpointPath};
    const result = spawnSync(process.execPath, [cli, "test", "e2e/admin-ui-performance.spec.js", "--reporter=line"],
      {cwd: panelRoot, env, encoding: "utf8", maxBuffer: 8 * 1024 * 1024, timeout: 10 * 60 * 1000});
    output = `${result.stdout || ""}${result.stderr || ""}`;
    process.stdout.write(output);
    exitCode = result.status ?? 1;
  } finally {
    await cleanup();
  }
  fs.mkdirSync(resultsDir, {recursive: true});
  let measurements = null;
  if (fs.existsSync(checkpointPath)) { try { measurements = JSON.parse(fs.readFileSync(checkpointPath, "utf8")); } catch {} }
  fs.writeFileSync(resultPath, `${JSON.stringify({testSuite: "TC-ADM-P01..P04 browser rendering", projectId,
    browser: "Chrome", viewport: "1920x1080", fixture: details, startedAt, finishedAt: new Date().toISOString(),
    exitCode, status: exitCode === 0 ? "passed" : "failed", measurements,
    output: output.replace(/admin-ui-[^\s@]+@example\.invalid/g, "[synthetic-admin]"),
    notes: "Measurements are local browser + local Emulator; map tiles were blocked; never use for production latency."}, null, 2)}\n`);
  process.exitCode = exitCode;
}

main().catch(async (error) => { await cleanup(); console.error(error.stack || error.message); process.exitCode = 1; });
