"use strict";

const fs = require("node:fs");
const net = require("node:net");
const path = require("node:path");
const {spawnSync} = require("node:child_process");
const root = path.resolve(__dirname, "../../..");
const projectId = "demo-roshita-admin-nf";
const ports = [19099, 18080, 15001, 19199];
const resultPath = path.join(__dirname, "..", "results", "TC-ADM-P01-P04-browser-run.json");

async function assertPortsFree() {
  for (const port of ports) await new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once("error", () => reject(new Error(`Isolated test port ${port} is occupied; no process was stopped.`)));
    server.listen(port, "127.0.0.1", () => server.close(resolve));
  });
}

async function main() {
  const config = JSON.parse(fs.readFileSync(path.join(root, "firebase.admin-test.json"), "utf8"));
  if (!projectId.startsWith("demo-") || JSON.stringify([config.emulators.auth.port, config.emulators.firestore.port,
    config.emulators.functions.port, config.emulators.storage.port]) !== JSON.stringify(ports)) {
    throw new Error("Refusing to run browser benchmarks without isolated demo Emulator ports.");
  }
  await assertPortsFree();
  const startedAt = new Date().toISOString();
  const firebaseCli = require.resolve("firebase-tools/lib/bin/firebase.js");
  const javaHome = "C:\\Program Files\\Android\\Android Studio\\jbr";
  const env = {...process.env, GCLOUD_PROJECT: projectId, GOOGLE_CLOUD_PROJECT: projectId, FIREBASE_PROJECT_ID: projectId,
    ROSHITA_TEST_PROJECT_ID: projectId, FIREBASE_EMULATORS_PATH: path.join(root, ".firebase", "emulators"),
    ROSHITA_ADMIN_PERF_TEST: "true",
    XDG_CONFIG_HOME: path.join(root, ".firebase", "config"),
    JAVA_HOME: fs.existsSync(path.join(javaHome, "bin", "java.exe")) ? javaHome : process.env.JAVA_HOME};
  env.PATH = [path.dirname(process.execPath), env.JAVA_HOME ? path.join(env.JAVA_HOME, "bin") : null, env.PATH].filter(Boolean).join(path.delimiter);
  const command = "node functions/test/admin_panel/run-admin-ui-performance.cjs";
  const run = spawnSync(process.execPath, [firebaseCli, "--config", path.join(root, "firebase.admin-test.json"),
    "--project", projectId, "emulators:exec", "--only", "auth,firestore,storage,functions", command],
  {cwd: root, env, encoding: "utf8", maxBuffer: 16 * 1024 * 1024, timeout: 12 * 60 * 1000});
  const output = `${run.stdout || ""}${run.stderr || ""}`;
  process.stdout.write(output);
  const exitCode = run.status ?? 1;
  fs.mkdirSync(path.dirname(resultPath), {recursive: true});
  fs.writeFileSync(resultPath, `${JSON.stringify({suite: "TC-ADM-P01..P04 browser rendering", projectId, ports,
    startedAt, finishedAt: new Date().toISOString(), exitCode, status: exitCode === 0 ? "passed" : "failed",
    output: output.replace(/admin-ui-[^\s@]+@example\.invalid/g, "[synthetic-admin]")}, null, 2)}\n`);
  process.exitCode = exitCode;
}

main().catch((error) => { console.error(error.stack || error.message); process.exitCode = 1; });
