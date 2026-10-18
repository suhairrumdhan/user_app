"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {randomUUID} = require("node:crypto");
const {spawnSync} = require("node:child_process");
const admin = require("firebase-admin");

const projectId = "demo-roshita-admin-nf";
const suffix = randomUUID().replaceAll("-", "");
const markerPath = "adminLists/orders";
const rowCollection = "adminLists/orders/adminListRows";
const authEndpoint = "http://127.0.0.1:19099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key";
const resultPath = path.join(__dirname, "..", "results", "TC-ADM-P05-adminList-k6.json");
const panelRoot = "C:\\Users\\hp\\OneDrive\\Desktop\\مشروع التخرج\\Roshita_Admin_Panel";
const k6 = process.env.K6_BIN || "C:\\Program Files\\k6\\k6.exe";
const summaryPath = resultPath.replace(/\.json$/, "-summary.json");
const app = admin.initializeApp({projectId}, `adm-p05-${suffix}`);
const db = admin.firestore(app);
const auth = admin.auth(app);
let user;
let seededIds = [];

async function seed() {
  assert.equal(process.env.GCLOUD_PROJECT, projectId, "isolated demo project required");
  if (!fs.existsSync(k6)) throw new Error(`k6 executable not found: ${k6}`);
  const response = await fetch(authEndpoint, {method: "POST", headers: {"content-type": "application/json"},
    body: JSON.stringify({email: `load-${suffix}@example.invalid`, password: `Load-${suffix.slice(0, 14)}!x`, returnSecureToken: true})});
  const authBody = await response.json();
  assert.equal(response.ok, true, `Load-test Auth Emulator account creation failed (${response.status}).`);
  user = {uid: authBody.localId, idToken: authBody.idToken};
  await db.doc(`adminEmployees/${user.uid}`).set({isActive: true, role: "super_admin", name: "TC-ADM-P05 synthetic load fixture"});
  await db.doc(markerPath).set({ready: true, schemaVersion: 1, total: 1000, fixture: `TC-ADM-P05-${suffix}`});
  for (let start = 0; start < 1000; start += 400) {
    const batch = db.batch();
    for (let i = start; i < Math.min(start + 400, 1000); i += 1) {
      const id = `admload_${suffix}_${String(i).padStart(4, "0")}`;
      seededIds.push(id);
      batch.set(db.doc(`${rowCollection}/${id}`), {schemaVersion: 1, sortAt: Date.now() - i,
        state: "completed", group: "", searchKeys: ["tcadmload"],
        row: {id, status: "completed", pharmacyName: "TC ADM synthetic pharmacy", userName: "Load fixture"}});
    }
    await batch.commit();
  }
}

async function cleanup() {
  for (let start = 0; start < seededIds.length; start += 400) {
    const batch = db.batch();
    for (const id of seededIds.slice(start, start + 400)) batch.delete(db.doc(`${rowCollection}/${id}`));
    await batch.commit().catch(() => {});
  }
  await Promise.all([db.doc(markerPath).delete().catch(() => {}),
    user?.uid ? db.doc(`adminEmployees/${user.uid}`).delete().catch(() => {}) : Promise.resolve(),
    user?.uid ? auth.deleteUser(user.uid).catch(() => {}) : Promise.resolve()]);
  await app.delete().catch(() => {});
}

async function main() {
  const startedAt = new Date().toISOString();
  let exitCode = 1;
  let k6Output = "";
  try {
    await seed();
    const payloadPath = path.join(panelRoot, "scripts", "non_functional", "TC-ADM-P05-orders-search-payload.json");
    const scriptPath = path.join(panelRoot, "scripts", "admin-callable-load.js");
    const output = spawnSync(k6, ["run", "--summary-export", summaryPath, scriptPath], {
      cwd: process.cwd(), encoding: "utf8", maxBuffer: 10 * 1024 * 1024, timeout: 7 * 60 * 1000,
      env: {...process.env,
        ADMIN_CALLABLE_URL: `http://127.0.0.1:15001/${projectId}/us-central1/adminList`,
        ADMIN_ID_TOKEN: user.idToken,
        ADMIN_PAYLOAD_FILE: payloadPath,
        ADMIN_COMMAND_NAME: "adminList_orders_search",
      },
    });
    k6Output = `${output.stdout || ""}${output.stderr || ""}`;
    process.stdout.write(k6Output);
    exitCode = output.status ?? 1;
  } finally {
    await cleanup();
  }
  const summary = fs.existsSync(summaryPath) ? JSON.parse(fs.readFileSync(summaryPath, "utf8")) : null;
  const metrics = summary?.metrics || {};
  const result = {testCase: "TC-ADM-P05", operation: "read-only adminList search/filter on 1,000 synthetic indexed rows",
    projectId, vusStages: [{duration: "30s", target: 10}, {duration: "60s", target: 10},
      {duration: "30s", target: 25}, {duration: "180s", target: 25}],
    startedAt, finishedAt: new Date().toISOString(), exitCode,
    averageMs: metrics.http_req_duration?.values?.avg ?? null,
    p95Ms: metrics.http_req_duration?.values?.['p(95)'] ?? null,
    unexpectedErrorRate: metrics.unexpected_errors?.values?.rate ?? null,
    thresholdsMet: exitCode === 0, status: exitCode === 0 ? "partial_pass" : "failed",
    coverageNote: "Only the read-only adminList orders search/filter callable was load-tested; registration decisions, visibility changes, and broadcast mutations require isolated per-VU fixtures and were not included.",
    output: k6Output.replace(/Bearer\s+[^\s"]+/gi, "Bearer [REDACTED]")};
  fs.mkdirSync(path.dirname(resultPath), {recursive: true});
  fs.writeFileSync(resultPath, `${JSON.stringify(result, null, 2)}\n`);
  process.exitCode = exitCode;
}

main().catch(async (error) => { await cleanup(); console.error(error.stack || error.message); process.exitCode = 1; });
