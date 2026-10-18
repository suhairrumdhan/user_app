"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const net = require("node:net");
const os = require("node:os");
const path = require("node:path");
const {spawnSync} = require("node:child_process");
const {randomUUID} = require("node:crypto");
const admin = require("firebase-admin");

const root = path.resolve(__dirname, "../../..");
const projectId = "demo-roshita-admin-nf";
const ports = [19099, 18080, 15001, 19199];
const fixturesPerVu = 600;
const vuCount = 25;
const suffix = randomUUID().replaceAll("-", "").slice(0, 16);
const resultsDir = path.join(root, "test_results");
const resultPath = path.join(resultsDir, "TC-ADM-P05-full-emulator.json");
const firebaseConfigPath = path.join(root, "firebase.admin-test.json");
const k6Path = process.env.K6_BIN || "C:\\Program Files\\k6\\k6.exe";
const k6ScriptPath = path.join(__dirname, "TC-ADM-P05-full-load.js");
const authEndpoint = `http://127.0.0.1:${ports[0]}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`;
const records = [];
const accounts = [];
let app;
let db;
let auth;

function append(collection, id, data) { records.push({path: `${collection}/${id}`, data}); }

async function createAccounts() {
  for (let i = 1; i <= vuCount; i += 1) {
    const response = await fetch(authEndpoint, {method: "POST", headers: {"content-type": "application/json"},
      body: JSON.stringify({email: `adm-p05-${suffix}-${i}@example.invalid`,
        password: `P05-${suffix}-${String(i).padStart(2, "0")}!x`, returnSecureToken: true})});
    const body = await response.json();
    assert.equal(response.ok, true, `Auth Emulator account setup failed for virtual user ${i}: ${body.error?.message || response.status}`);
    accounts.push({uid: body.localId, token: body.idToken});
    append("adminEmployees", body.localId, {isActive: true, role: "super_admin", name: `P05 synthetic admin ${i}`});
  }
}

function buildFixtures() {
  append("adminLists", "orders", {schemaVersion: 1, ready: true, total: 1000});
  append("adminLists", "pharmacies", {schemaVersion: 1, ready: true, total: vuCount});
  for (let i = 0; i < 1000; i += 1) {
    const id = `admperf_p05order_${suffix}_${String(i).padStart(4, "0")}`;
    append("adminLists/orders/adminListRows", id, {schemaVersion: 1, sortAt: Date.now() - i, state: "completed",
      group: "", searchKeys: ["tcadmload"], row: {id, status: "completed", orderNumber: `P05-${i}`,
        pharmacyName: "TC-ADM-P05 synthetic pharmacy", totalItemsCount: 1}});
  }
  for (let vu = 1; vu <= vuCount; vu += 1) {
    const uid = accounts[vu - 1].uid;
    const pharmacyId = `admperf_p05ph_${suffix}_${vu}`;
    const pharmacy = {id: pharmacyId, pharmacyId, ownerUid: uid, pharmacyName: `P05 synthetic pharmacy ${vu}`,
      name: `P05 synthetic pharmacy ${vu}`, status: "approved", isActive: true, isOnline: true,
      isBlocked: false, visibilityRevision: 0, location: {address: "Emulator test location", latitude: 32.3, longitude: 13.2},
      createdAt: new Date(), approvedDate: new Date()};
    append("pharmacies", pharmacyId, pharmacy);
    append("adminLists/pharmacies/adminListRows", pharmacyId, {schemaVersion: 1, sortAt: Date.now(), state: "visible",
      group: "online", searchKeys: ["tcadmload"], row: {...pharmacy}});
    for (let iteration = 0; iteration < fixturesPerVu; iteration += 1) {
      const requestId = `admperf_p05reg_${suffix}_${vu}_${iteration}`;
      append("pharmacyRequests", requestId, {id: requestId, ownerUid: uid, pharmacyId: uid,
        pharmacyName: `P05 synthetic request ${vu}-${iteration}`, ownerName: `Synthetic owner ${vu}`,
        licenseNumber: `P05-${suffix}-${vu}-${iteration}`, status: "pending", version: 1, revision: 0,
        requestDate: new Date(), createdAt: new Date(), location: {address: "Emulator test location"}});
    }
  }
}

async function seed() {
  assert.equal(process.env.GCLOUD_PROJECT, projectId, "Refusing to seed outside the isolated demo Emulator.");
  assert.equal(process.env.ROSHITA_ADMIN_PERF_TEST, "true", "Synthetic-only trigger guard is required.");
  app = admin.initializeApp({projectId}, `tc-adm-p05-${suffix}`);
  db = admin.firestore(app);
  auth = admin.auth(app);
  await createAccounts();
  buildFixtures();
  for (let start = 0; start < records.length; start += 350) {
    const batch = db.batch();
    for (const record of records.slice(start, start + 350)) batch.set(db.doc(record.path), record.data);
    await batch.commit();
  }
}

async function cleanupFixtures() {
  if (!db) return;
  for (let start = 0; start < records.length; start += 350) {
    const batch = db.batch();
    for (const record of records.slice(start, start + 350)) batch.delete(db.doc(record.path));
    await batch.commit().catch(() => {});
  }
  await Promise.all(accounts.map(async ({uid}) => {
    await db.doc(`adminEmployees/${uid}`).delete().catch(() => {});
    await auth.deleteUser(uid).catch(() => {});
  }));
  await app?.delete().catch(() => {});
}

function summarizeK6(command, exitCode, summary, output) {
  const metrics = summary?.metrics || {};
  const value = (metric, key) => metrics[metric]?.values?.[key] ?? null;
  const avg = value("http_req_duration", "avg");
  const p95 = value("http_req_duration", "p(95)");
  const errorRate = value("unexpected_errors", "rate");
  const functionalFailureRate = value("functional_failures", "rate");
  const thresholdsMet = exitCode === 0 && typeof p95 === "number" && p95 <= 3000 &&
    typeof errorRate === "number" && errorRate <= 0.01 && functionalFailureRate === 0;
  return {operation: command, stages: [{duration: "30s", target: 10}, {duration: "60s", target: 10},
    {duration: "30s", target: 25}, {duration: "180s", target: 25}], duration: "5 minutes",
  virtualUsersMax: 25, averageMs: avg, p95Ms: p95, unexpectedErrorRate: errorRate,
  functionalFailureRate, requests: value("http_reqs", "count"), iterations: value("iterations", "count"),
  thresholdsMet, status: thresholdsMet ? "passed" : "failed",
  output: String(output || "").replace(/Bearer\s+[^\s"]+/gi, "Bearer [REDACTED]")};
}

async function executeK6() {
  assert.equal(fs.existsSync(k6Path), true, `k6 was not found at ${k6Path}.`);
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "tc-adm-p05-"));
  const results = [];
  const callableUrl = `http://127.0.0.1:${ports[2]}/${projectId}/us-central1/`;
  try {
    for (const command of ["search", "registration", "visibility", "broadcast"]) {
      const summaryPath = path.join(scratch, `${command}-summary.json`);
      const response = spawnSync(k6Path, ["run", "--summary-export", summaryPath, k6ScriptPath], {
        cwd: root, encoding: "utf8", maxBuffer: 16 * 1024 * 1024, timeout: 7 * 60 * 1000,
        env: {...process.env, ADMIN_CALLABLE_URL: callableUrl + ({search: "adminList", registration: "registrationCommand",
          visibility: "adminVisibilityCommand", broadcast: "adminBroadcastCommand"})[command],
          ADMIN_P05_COMMAND: command, ADMIN_P05_SUFFIX: suffix,
          ADMIN_ID_TOKENS_JSON: JSON.stringify(accounts.map((account) => account.token))},
      });
      const output = `${response.stdout || ""}${response.stderr || ""}`;
      let summary = null;
      if (fs.existsSync(summaryPath)) summary = JSON.parse(fs.readFileSync(summaryPath, "utf8"));
      const result = summarizeK6(command, response.status ?? 1, summary, output);
      results.push(result);
      process.stdout.write(`TC-ADM-P05 ${command}: ${JSON.stringify({...result, output: undefined})}\n`);
      if (response.error) process.stdout.write(`${response.error.message}\n`);
    }
  } finally {
    fs.rmSync(scratch, {recursive: true, force: true});
  }
  return results;
}

async function clearPorts() {
  const ps = `$ports=@(${ports.join(",")}); $ids=@(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $ports -contains $_.LocalPort } | Select-Object -ExpandProperty OwningProcess -Unique); foreach($id in $ids){ Stop-Process -Id $id -Force -ErrorAction SilentlyContinue };`;
  const stopped = spawnSync("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", ps], {encoding: "utf8", timeout: 20000});
  if (stopped.status !== 0) throw new Error("Could not clear dedicated Firebase Emulator ports. " + (stopped.stderr || stopped.stdout || ""));
  for (const port of ports) await new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once("error", () => reject(new Error(`Emulator port ${port} is still occupied after cleanup.`)));
    server.listen(port, "127.0.0.1", () => server.close(resolve));
  });
}

async function runInsideEmulator() {
  let results = [];
  let setupError = null;
  try {
    await seed();
    results = await executeK6();
  } catch (error) {
    setupError = error.message;
  } finally {
    await cleanupFixtures();
  }
  const result = {testCase: "TC-ADM-P05", projectId, environment: "Firebase Emulator; k6 on local workstation",
    network: "loopback Emulator; no production Firebase calls", cache: "no browser cache (HTTP k6 client)",
    fixture: {syntheticAdminSessions: accounts.length, indexedOrders: 1000, registrationRequestsPerVu: fixturesPerVu,
      visibilityPharmacies: vuCount, notificationRecipients: 0, syntheticRecipientTarget: "users"},
    setupError, operations: results, status: !setupError && results.length === 4 && results.every((item) => item.thresholdsMet) ? "passed" : "failed",
    startedAt: process.env.ADM_P05_STARTED_AT || null, finishedAt: new Date().toISOString()};
  fs.mkdirSync(resultsDir, {recursive: true});
  fs.writeFileSync(resultPath, `${JSON.stringify(result, null, 2)}\n`);
  console.log(`ADM_P05_RESULT_PATH=${resultPath}`);
  process.exitCode = result.status === "passed" ? 0 : 1;
}

async function runOuter() {
  const config = JSON.parse(fs.readFileSync(firebaseConfigPath, "utf8"));
  assert.equal(projectId.startsWith("demo-"), true);
  assert.deepEqual([config.emulators.auth.port, config.emulators.firestore.port,
    config.emulators.functions.port, config.emulators.storage.port], ports);
  await clearPorts();
  const javaHome = "C:\\Program Files\\Android\\Android Studio\\jbr";
  const env = {...process.env, GCLOUD_PROJECT: projectId, GOOGLE_CLOUD_PROJECT: projectId,
    FIREBASE_PROJECT_ID: projectId, ROSHITA_TEST_PROJECT_ID: projectId, ROSHITA_ADMIN_PERF_TEST: "true",
    ADM_P05_STARTED_AT: new Date().toISOString(), FIREBASE_EMULATORS_PATH: path.join(root, ".firebase", "emulators"),
    XDG_CONFIG_HOME: path.join(root, ".firebase", "config"),
    JAVA_HOME: fs.existsSync(path.join(javaHome, "bin", "java.exe")) ? javaHome : process.env.JAVA_HOME};
  env.PATH = [path.dirname(process.execPath), env.JAVA_HOME ? path.join(env.JAVA_HOME, "bin") : null, env.PATH]
    .filter(Boolean).join(path.delimiter);
  const firebaseCli = require.resolve("firebase-tools/lib/bin/firebase.js");
  const command = "node functions/test/admin_panel/run-p05-full-emulator.cjs --inside-emulator";
  const args = [firebaseCli, "--config", firebaseConfigPath, "--project", projectId,
    "emulators:exec", "--only", "auth,firestore,storage,functions", command];
  let run;
  try {
    run = spawnSync(process.execPath, args, {cwd: root, env, encoding: "utf8", maxBuffer: 64 * 1024 * 1024,
      timeout: 35 * 60 * 1000});
  } finally {
    await clearPorts();
  }
  const output = `${run?.stdout || ""}${run?.stderr || ""}`;
  const result = fs.existsSync(resultPath) ? JSON.parse(fs.readFileSync(resultPath, "utf8")) : null;
  process.stdout.write(output.split(/\r?\n/).filter((line) => line.includes("TC-ADM-P05 ") ||
    line.includes("ADM_P05_RESULT_PATH=") || line.startsWith("Error:") || line.startsWith("!  ")).join("\n"));
  if (result) {
    process.stdout.write("\nنتيجة TC-ADM-P05:\n");
    for (const item of result.operations) process.stdout.write(`${item.operation}: avg=${item.averageMs}ms, P95=${item.p95Ms}ms, errors=${item.unexpectedErrorRate}, status=${item.status}\n`);
    process.stdout.write(`الحالة الإجمالية: ${result.status}\nملف النتيجة: ${resultPath}\n`);
  }
  process.exitCode = run?.status === 0 && result?.status === "passed" ? 0 : 1;
}

if (process.argv.includes("--inside-emulator")) runInsideEmulator().catch((error) => {
  console.error(`TC-ADM-P05 setup failed: ${error.stack || error.message}`); process.exitCode = 1;
});
else runOuter().catch((error) => { console.error(`TC-ADM-P05 emulator runner failed: ${error.stack || error.message}`); process.exitCode = 1; });
