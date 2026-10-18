"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const {
  TEST_PROJECT_ID,
  assertIsolatedEnvironment,
  buildEmulatorEnvironment,
} = require("./environment");

class LostResponseAfterCommitError extends Error {
  constructor(operationId) {
    super(`Response lost after commit for ${operationId}`);
    this.name = "LostResponseAfterCommitError";
    this.operationId = operationId;
  }
}

function withLostResponseAfterCommit(commit) {
  let responseLost = false;
  return async (operationId) => {
    const result = await commit(operationId);
    if (!responseLost) {
      responseLost = true;
      throw new LostResponseAfterCommitError(operationId);
    }
    return result;
  };
}

async function executeWithOperationReplay(options) {
  const operationId = String(options.operationId || "").trim();
  if (!operationId) throw new Error("operationId is required for safe retry.");
  const maxAttempts = options.maxAttempts || 2;
  let lastError;

  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      const result = await options.execute(operationId);
      return { operationId, result, recovered: attempt > 1, attempts: attempt };
    } catch (error) {
      lastError = error;
      const committed = await options.readCommitted(operationId);
      if (committed !== undefined && committed !== null) {
        return { operationId, result: committed, recovered: true, attempts: attempt };
      }
    }
  }

  throw lastError;
}

async function runConcurrently(operations) {
  if (!Array.isArray(operations) || operations.length < 2) {
    throw new Error("At least two operations are required for a race test.");
  }
  let release;
  const barrier = new Promise((resolve) => {
    release = resolve;
  });
  const pending = operations.map((operation) => (async () => {
    await barrier;
    return operation();
  })());
  release();
  return Promise.allSettled(pending);
}

function createInjectableClock(initialValue) {
  let current = new Date(initialValue).getTime();
  if (!Number.isFinite(current)) throw new Error("Clock requires a valid date.");
  return Object.freeze({
    now: () => new Date(current),
    advanceBy: (milliseconds) => {
      current += milliseconds;
      return new Date(current);
    },
    set: (value) => {
      const next = new Date(value).getTime();
      if (!Number.isFinite(next)) throw new Error("Clock requires a valid date.");
      current = next;
      return new Date(current);
    },
  });
}

function resolveFirebaseCli() {
  if (process.env.FIREBASE_CLI_JS) {
    const configured = path.resolve(process.env.FIREBASE_CLI_JS);
    if (!fs.existsSync(configured)) {
      throw new Error(`FIREBASE_CLI_JS does not exist: ${configured}`);
    }
    return configured;
  }
  return require.resolve("firebase-tools/lib/bin/firebase.js");
}

function configureRuntimeEnvironment(environment) {
  const normalized = {...environment};
  const pathKeys = Object.keys(normalized).filter(
    (key) => key.toLowerCase() === "path",
  );
  const inheritedPath = pathKeys
    .map((key) => normalized[key])
    .filter(Boolean)
    .join(path.delimiter);
  for (const key of pathKeys) delete normalized[key];

  const candidates = [
    normalized.ROSHITA_JAVA_HOME,
    process.platform === "win32" ?
      "C:\\Program Files\\Android\\Android Studio\\jbr" : null,
    normalized.JAVA_HOME,
  ].filter(Boolean);
  const javaHome = candidates.find((candidate) => fs.existsSync(
    path.join(candidate, "bin", process.platform === "win32" ? "java.exe" : "java"),
  ));

  const executableDirectories = [path.dirname(process.execPath)];
  if (javaHome) executableDirectories.push(path.join(javaHome, "bin"));
  return {
    ...normalized,
    ...(javaHome ? {JAVA_HOME: javaHome} : {}),
    PATH: [...executableDirectories, inheritedPath]
      .filter(Boolean)
      .join(path.delimiter),
  };
}

function writeRealResult(startedAt, status, exitCode) {
  const resultDir = path.resolve(__dirname, "..", "results");
  fs.mkdirSync(resultDir, { recursive: true });
  const firebaseVersion = require("firebase-tools/package.json").version;
  const packageVersion = require("../../package.json").version;
  const payload = {
    task: "F02",
    harnessVersion: packageVersion,
    firebaseToolsVersion: firebaseVersion,
    nodeVersion: process.version,
    projectId: TEST_PROJECT_ID,
    startedAt,
    finishedAt: new Date().toISOString(),
    status,
    exitCode,
  };
  fs.writeFileSync(
    path.join(resultDir, "f02-latest.json"),
    `${JSON.stringify(payload, null, 2)}\n`,
  );
}

function runFirebase(command) {
  const functionsRoot = path.resolve(__dirname, "..", "..");
  const repositoryRoot = path.resolve(functionsRoot, "..");
  const emulatorCache = path.join(repositoryRoot, ".firebase", "emulators");
  const firebaseConfigHome = path.join(repositoryRoot, ".firebase", "config");
  const environment = configureRuntimeEnvironment(buildEmulatorEnvironment({
    ...process.env,
    XDG_CONFIG_HOME: firebaseConfigHome,
    FIREBASE_EMULATORS_PATH: emulatorCache,
  }));
  assertIsolatedEnvironment(environment);
  const common = [
    "--use-system-ca",
    resolveFirebaseCli(),
    "--config",
    path.join(repositoryRoot, "firebase.json"),
    "--project",
    TEST_PROJECT_ID,
  ];
  const args = command === "start" ?
    [...common, "emulators:start", "--only", "auth,firestore,storage,functions"] :
    [
      ...common,
      "emulators:exec",
      "--only",
      "auth,firestore,storage,functions",
      "node --test --test-concurrency=1 test/emulator/*.test.js",
    ];
  const startedAt = new Date().toISOString();
  const result = spawnSync(process.execPath, args, {
    cwd: functionsRoot,
    env: environment,
    stdio: "inherit",
    shell: false,
  });
  const exitCode = result.status === null ? 1 : result.status;
  if (command === "emulator-test") {
    writeRealResult(startedAt, exitCode === 0 ? "passed" : "failed", exitCode);
  }
  return exitCode;
}

async function openTestEnvironment() {
  Object.assign(process.env, buildEmulatorEnvironment(process.env));
  const environment = assertIsolatedEnvironment();
  const { initializeTestEnvironment } = require("@firebase/rules-unit-testing");
  const repositoryRoot = path.resolve(__dirname, "..", "..", "..");
  return initializeTestEnvironment({
    projectId: environment.projectId,
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: fs.readFileSync(path.join(repositoryRoot, "firestore.rules"), "utf8"),
    },
    storage: {
      host: "127.0.0.1",
      port: 9199,
      rules: fs.readFileSync(path.join(repositoryRoot, "storage.rules"), "utf8"),
    },
  });
}

async function changeFixtures(command) {
  const testEnvironment = await openTestEnvironment();
  try {
    const fixtures = require("./fixtures");
    if (command === "reset") {
      await fixtures.resetFixtureData(testEnvironment);
    } else {
      await fixtures.seedFixtureData(testEnvironment);
    }
    console.log(`${command} completed for ${TEST_PROJECT_ID}`);
  } finally {
    await testEnvironment.cleanup();
  }
}

async function main() {
  const command = process.argv[2];
  if (command === "start" || command === "emulator-test") {
    process.exitCode = runFirebase(command);
    return;
  }
  if (command === "seed" || command === "reset") {
    await changeFixtures(command);
    return;
  }
  throw new Error("Use start, emulator-test, seed, or reset.");
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

module.exports = {
  LostResponseAfterCommitError,
  configureRuntimeEnvironment,
  createInjectableClock,
  executeWithOperationReplay,
  runConcurrently,
  withLostResponseAfterCommit,
};
