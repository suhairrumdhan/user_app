"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {spawnSync} = require("node:child_process");
const root = path.resolve(__dirname, "../../..");
const projectId = "demo-roshita-admin-nf";
const resultPath = path.join(__dirname, "..", "results", "TC-ADM-NF06-emulator.json");
const firebaseCli = require.resolve("firebase-tools/lib/bin/firebase.js");
const command = "node --test --test-concurrency=1 functions/test/admin_panel/TC-ADM-NF06-partial-broadcast.test.cjs";
const javaHome = "C:\\Program Files\\Android\\Android Studio\\jbr";
const env = {...process.env, GCLOUD_PROJECT: projectId, GOOGLE_CLOUD_PROJECT: projectId,
  FIREBASE_PROJECT_ID: projectId, ROSHITA_TEST_PROJECT_ID: projectId,
  FIREBASE_EMULATORS_PATH: path.join(root, ".firebase", "emulators"),
  XDG_CONFIG_HOME: path.join(root, ".firebase", "config"),
  JAVA_HOME: fs.existsSync(path.join(javaHome, "bin", "java.exe")) ? javaHome : process.env.JAVA_HOME};
env.PATH = [path.dirname(process.execPath), env.JAVA_HOME ? path.join(env.JAVA_HOME, "bin") : null, env.PATH].filter(Boolean).join(path.delimiter);
const result = spawnSync(process.execPath, [firebaseCli, "--config", path.join(root, "firebase.admin-test.json"),
  "--project", projectId, "emulators:exec", "--only", "auth,firestore", command],
{cwd: root, env, encoding: "utf8", maxBuffer: 8 * 1024 * 1024});
const output = `${result.stdout || ""}${result.stderr || ""}`;
process.stdout.write(output);
const exitCode = result.status ?? 1;
fs.mkdirSync(path.dirname(resultPath), {recursive: true});
fs.writeFileSync(resultPath, `${JSON.stringify({testCase: "TC-ADM-NF06", projectId, exitCode,
  status: exitCode === 0 ? "passed" : "failed", output: output.replace(/Bearer\s+[^\s"]+/gi, "Bearer [REDACTED]")}, null, 2)}\n`);
process.exitCode = exitCode;
