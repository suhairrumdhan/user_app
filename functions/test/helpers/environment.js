"use strict";

const PRODUCTION_PROJECT_IDS = new Set(["pharma-apps"]);
const TEST_PROJECT_ID = "demo-roshita-f02";

const LOCAL_HOSTS = Object.freeze({
  FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:9099",
  FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080",
  FIREBASE_STORAGE_EMULATOR_HOST: "127.0.0.1:9199",
  STORAGE_EMULATOR_HOST: "http://127.0.0.1:9199",
  ROSHITA_FUNCTIONS_EMULATOR_HOST: "127.0.0.1:5001",
});

function normalizeEndpoint(value) {
  return String(value || "")
    .trim()
    .replace(/^https?:\/\//i, "")
    .replace(/\/$/, "");
}

function isLoopbackEndpoint(value) {
  const endpoint = normalizeEndpoint(value);
  const host = endpoint.startsWith("[") ?
    endpoint.slice(1, endpoint.indexOf("]")) :
    endpoint.split(":")[0];
  return host === "127.0.0.1" || host === "localhost" || host === "::1";
}

function buildEmulatorEnvironment(base = process.env) {
  return {
    ...base,
    GCLOUD_PROJECT: TEST_PROJECT_ID,
    GOOGLE_CLOUD_PROJECT: TEST_PROJECT_ID,
    FIREBASE_PROJECT_ID: TEST_PROJECT_ID,
    ROSHITA_TEST_PROJECT_ID: TEST_PROJECT_ID,
    ...LOCAL_HOSTS,
  };
}

function assertIsolatedEnvironment(environment = process.env) {
  const projectId = String(
    environment.ROSHITA_TEST_PROJECT_ID ||
    environment.GCLOUD_PROJECT ||
    environment.GOOGLE_CLOUD_PROJECT ||
    environment.FIREBASE_PROJECT_ID ||
    "",
  ).trim();

  if (!projectId) {
    throw new Error("F02 requires an explicit Firebase test project ID.");
  }
  if (PRODUCTION_PROJECT_IDS.has(projectId) || !projectId.startsWith("demo-")) {
    throw new Error(`Refusing non-demo Firebase project: ${projectId}`);
  }

  const requiredHosts = [
    "FIREBASE_AUTH_EMULATOR_HOST",
    "FIRESTORE_EMULATOR_HOST",
    "FIREBASE_STORAGE_EMULATOR_HOST",
    "ROSHITA_FUNCTIONS_EMULATOR_HOST",
  ];
  for (const variable of requiredHosts) {
    const endpoint = environment[variable];
    if (!endpoint || !isLoopbackEndpoint(endpoint)) {
      throw new Error(`F02 requires local ${variable}; received ${endpoint || "empty"}`);
    }
  }

  return Object.freeze({
    projectId,
    authHost: normalizeEndpoint(environment.FIREBASE_AUTH_EMULATOR_HOST),
    firestoreHost: normalizeEndpoint(environment.FIRESTORE_EMULATOR_HOST),
    storageHost: normalizeEndpoint(
      environment.FIREBASE_STORAGE_EMULATOR_HOST,
    ),
    functionsHost: normalizeEndpoint(
      environment.ROSHITA_FUNCTIONS_EMULATOR_HOST,
    ),
  });
}

module.exports = {
  LOCAL_HOSTS,
  PRODUCTION_PROJECT_IDS,
  TEST_PROJECT_ID,
  assertIsolatedEnvironment,
  buildEmulatorEnvironment,
  isLoopbackEndpoint,
};
