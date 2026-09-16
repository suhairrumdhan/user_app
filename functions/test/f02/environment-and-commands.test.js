"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  TEST_PROJECT_ID,
  assertIsolatedEnvironment,
  buildEmulatorEnvironment,
} = require("../helpers/environment");
const {
  configureRuntimeEnvironment,
  createInjectableClock,
  executeWithOperationReplay,
  runConcurrently,
  withLostResponseAfterCommit,
} = require("../helpers/commands");
const { buildFixtureDocuments } = require("../helpers/fixtures");

test("F02 rejects production and non-demo Firebase projects", () => {
  assert.throws(
    () => assertIsolatedEnvironment({
      ...buildEmulatorEnvironment(),
      ROSHITA_TEST_PROJECT_ID: "pharma-apps",
    }),
    /Refusing non-demo Firebase project/,
  );
  assert.throws(
    () => assertIsolatedEnvironment({
      ...buildEmulatorEnvironment(),
      FIRESTORE_EMULATOR_HOST: "firestore.googleapis.com:443",
    }),
    /requires local FIRESTORE_EMULATOR_HOST/,
  );
});

test("F02 accepts only the reviewed demo project and loopback hosts", () => {
  const environment = assertIsolatedEnvironment(buildEmulatorEnvironment());
  assert.equal(environment.projectId, TEST_PROJECT_ID);
  assert.equal(environment.firestoreHost, "127.0.0.1:8080");
});

test("fixture generation is deterministic", () => {
  assert.deepEqual(buildFixtureDocuments(), buildFixtureDocuments());
});

test("runtime environment exposes one PATH containing the active Node binary", () => {
  const environment = configureRuntimeEnvironment({
    Path: "C:\\Windows\\System32",
    PATH: "C:\\tools",
  });
  const pathKeys = Object.keys(environment).filter(
    (key) => key.toLowerCase() === "path",
  );
  assert.deepEqual(pathKeys, ["PATH"]);
  assert.equal(
    environment.PATH.split(require("node:path").delimiter)[0],
    require("node:path").dirname(process.execPath),
  );
});

test("lost response is recovered by the same operationId without a replay", async () => {
  const committed = new Map();
  let commitCount = 0;
  const execute = withLostResponseAfterCommit(async (operationId) => {
    commitCount += 1;
    const result = { operationId, invoiceId: "invoice-one" };
    committed.set(operationId, result);
    return result;
  });
  const outcome = await executeWithOperationReplay({
    operationId: "operation-one",
    execute,
    readCommitted: async (operationId) => committed.get(operationId),
  });
  assert.equal(commitCount, 1);
  assert.equal(outcome.recovered, true);
  assert.equal(outcome.result.invoiceId, "invoice-one");
});

test("two operations can be released through one race barrier", async () => {
  const results = await runConcurrently([
    async () => "first",
    async () => "second",
  ]);
  assert.deepEqual(results.map((result) => result.status), ["fulfilled", "fulfilled"]);
  assert.deepEqual(results.map((result) => result.value), ["first", "second"]);
});

test("injectable clock advances without consulting wall time", () => {
  const clock = createInjectableClock("2026-01-15T09:00:00.000Z");
  assert.equal(clock.now().toISOString(), "2026-01-15T09:00:00.000Z");
  clock.advanceBy(24 * 60 * 60 * 1000);
  assert.equal(clock.now().toISOString(), "2026-01-16T09:00:00.000Z");
});
