"use strict";

const fs = require("node:fs");
const net = require("node:net");
const path = require("node:path");
const {spawnSync} = require("node:child_process");

const root = path.resolve(__dirname, "../../..");
const projectId = "demo-roshita-admin-nf";
const ports = [19099, 18080, 15001, 19199];
const resultPath = path.join(__dirname, "..", "results", "admin-panel-nf-latest.json");

function assertDemoConfiguration() {
  const config = JSON.parse(fs.readFileSync(path.join(root, "firebase.admin-test.json"), "utf8"));
  const configured = [config.emulators.auth.port, config.emulators.firestore.port, config.emulators.functions.port, config.emulators.storage.port];
  if (JSON.stringify(configured) !== JSON.stringify(ports)) throw new Error("Admin test emulator ports do not match the isolated runner.");
  if (!projectId.startsWith("demo-")) throw new Error("Refusing to run admin emulator tests outside an isolated demo project.");
  return config;
}

async function assertPortsFree() {
  for (const port of ports) await new Promise((resolve, reject) => {
    const server = net.createServer();
    server.once("error", () => reject(new Error(`Port ${port} is occupied; no process was stopped. Free it or change the isolated test ports.`)));
    server.listen(port, "127.0.0.1", () => server.close(resolve));
  });
}

async function main() {
  assertDemoConfiguration();
  await assertPortsFree();
  const startedAt = new Date().toISOString();
  const firebaseCli = require.resolve("firebase-tools/lib/bin/firebase.js");
  const command = "node --test --test-concurrency=1 functions/test/admin_panel/TC-ADM-NF01-rules.test.cjs functions/test/admin_panel/TC-ADM-NF02-callable-auth.test.cjs functions/test/admin_panel/TC-ADM-NF03-privacy.test.cjs functions/test/admin_panel/TC-ADM-NF04-concurrent-decisions.test.cjs functions/test/admin_panel/TC-ADM-NF05-idempotent-retry.test.cjs";
  const javaHome = "C:\\Program Files\\Android\\Android Studio\\jbr";
  const childEnv = {
    ...process.env,
    GCLOUD_PROJECT: projectId,
    GOOGLE_CLOUD_PROJECT: projectId,
    FIREBASE_PROJECT_ID: projectId,
    ROSHITA_TEST_PROJECT_ID: projectId,
    FIREBASE_EMULATORS_PATH: path.join(root, ".firebase", "emulators"),
    XDG_CONFIG_HOME: path.join(root, ".firebase", "config"),
    JAVA_HOME: fs.existsSync(path.join(javaHome, "bin", "java.exe")) ? javaHome : process.env.JAVA_HOME,
  };
  childEnv.PATH = [
    path.dirname(process.execPath),
    childEnv.JAVA_HOME ? path.join(childEnv.JAVA_HOME, "bin") : null,
    childEnv.PATH,
  ].filter(Boolean).join(path.delimiter);
  const args = [firebaseCli, "--config", path.join(root, "firebase.admin-test.json"), "--project", projectId,
    "emulators:exec", "--only", "auth,firestore,storage,functions", command];
  const result = spawnSync(process.execPath, args, {cwd: root, env: childEnv, encoding: "utf8", maxBuffer: 20 * 1024 * 1024});
  const output = `${result.stdout || ""}${result.stderr || ""}`;
  process.stdout.write(output);
  const exitCode = result.status ?? 1;
  fs.mkdirSync(path.dirname(resultPath), {recursive: true});
  fs.writeFileSync(resultPath, `${JSON.stringify({suite: "TC-ADM-NF01..NF05 except NF06..NF11", projectId, ports, startedAt,
    finishedAt: new Date().toISOString(), status: exitCode === 0 ? "passed" : "failed", exitCode,
    output: output.replace(/Bearer\s+[^\s"]+/gi, "Bearer [REDACTED]")}, null, 2)}\n`);
  process.exitCode = exitCode;
}

main().catch((error) => { console.error(error.message); process.exitCode = 1; });
