"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");

const LIVE_PROJECT_ID = "pharma-apps";

function functionUrl(name = "executeOrderCommand") {
  return `https://us-central1-${LIVE_PROJECT_ID}.cloudfunctions.net/` +
    name;
}

function requireLiveOptIn() {
  assert.equal(process.env.ROSHITA_LIVE_TEST, "1");
  assert.equal(process.env.ROSHITA_LIVE_PROJECT_ID, LIVE_PROJECT_ID);
  for (const variable of ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST",
    "FIREBASE_STORAGE_EMULATOR_HOST", "STORAGE_EMULATOR_HOST", "FUNCTIONS_EMULATOR"] ) {
    assert.ok(!process.env[variable], `Live tests must not use emulator environment: ${variable}`);
  }
  const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  assert.ok(credentialsPath && path.isAbsolute(credentialsPath));
  assert.ok(fs.existsSync(credentialsPath));
  return credentialsPath;
}

function readApiKey() {
  const configPath = path.resolve(
    __dirname,
    "..",
    "..",
    "..",
    "..",
    "android",
    "app",
    "google-services.json",
  );
  const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
  assert.equal(config.project_info.project_id, LIVE_PROJECT_ID);
  return config.client[0].api_key[0].current_key;
}

async function ensureUser(auth, uid, email, name) {
  try {
    await auth.getUser(uid);
    await auth.updateUser(uid, {displayName: name, disabled: false});
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    await auth.createUser({
      uid,
      email,
      displayName: name,
      emailVerified: true,
    });
  }
}

async function tokenFor(auth, apiKey, uid) {
  const customToken = await auth.createCustomToken(uid);
  return exchangeCustomToken(apiKey, customToken);
}

async function exchangeCustomToken(apiKey, customToken) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:` +
      `signInWithCustomToken?key=${apiKey}`,
    {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({token: customToken, returnSecureToken: true}),
    },
  );
  const body = await response.json();
  assert.equal(response.ok, true, body.error?.message || "Authentication failed");
  return body.idToken;
}

class LiveCallableError extends Error {
  constructor(error) {
    super(error?.message || "Live callable failed");
    this.code = String(error?.status || "unknown")
      .toLowerCase()
      .replaceAll("_", "-");
    this.details = error?.details;
  }
}

async function callFunctionRaw(name, idToken, data) {
  const headers = {"Content-Type": "application/json; charset=utf-8"};
  if (idToken) headers.Authorization = `Bearer ${idToken}`;
  const response = await fetch(functionUrl(name), {
    method: "POST",
    headers,
    body: JSON.stringify({data}),
  });
  const body = await response.json();
  if (body.error) throw new LiveCallableError(body.error);
  assert.equal(response.ok, true, `Callable returned HTTP ${response.status}`);
  return body.result;
}

async function callRaw(idToken, data) {
  return callFunctionRaw("executeOrderCommand", idToken, data);
}

async function initializeLiveSuite(suiteName, {isolatedIdentities = false} = {}) {
  const credentialsPath = requireLiveOptIn();
  const serviceAccount = JSON.parse(
    fs.readFileSync(credentialsPath, "utf8"),
  );
  assert.equal(serviceAccount.project_id, LIVE_PROJECT_ID);
  const app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: LIVE_PROJECT_ID,
  }, `live-${process.pid}-${crypto.randomBytes(3).toString("hex")}`);
  const auth = app.auth();
  const apiKey = readApiKey();
  const runId = `${Date.now()}-${crypto.randomBytes(3).toString("hex")}`;
  const identities = {
    user: {
      uid: "roshita-live-user-f03",
      email: "roshita-live-user-f03@example.invalid",
      name: "Roshita Live Test User",
    },
    pharmacy: {
      uid: "roshita-live-pharmacy-f03",
      email: "roshita-live-pharmacy-f03@example.invalid",
      name: "Roshita Live Test Pharmacy",
    },
    outsider: {
      uid: "roshita-live-outsider-f03",
      email: "roshita-live-outsider-f03@example.invalid",
      name: "Roshita Live Test Outsider",
    },
  };
  if (isolatedIdentities) {
    for (const identity of Object.values(identities)) {
      identity.uid = `${identity.uid}-${runId}`;
      identity.email = `${identity.uid}@example.invalid`;
    }
  }
  const tokens = {};
  for (const [key, identity] of Object.entries(identities)) {
    await ensureUser(
      auth,
      identity.uid,
      identity.email,
      identity.name,
    );
    tokens[key] = await tokenFor(auth, apiKey, identity.uid);
  }
  const context = {
    admin,
    app,
    auth,
    apiKey,
    db: app.firestore(),
    suiteName,
    runId,
    identities,
    tokens,
    pharmacyUid: identities.pharmacy.uid,
    userUid: identities.user.uid,
    outsiderUid: identities.outsider.uid,
  };
  context.call = (actor, command, orderId, options = {}) => callRaw(
    actor ? tokens[actor === "pharmacy" && context.employeeTokenKey ?
      context.employeeTokenKey : actor] : null,
    {
      schemaVersion: options.schemaVersion ?? 3,
      command,
      operationId: options.operationId ||
        `live:${runId}:${command}:${crypto.randomBytes(4).toString("hex")}`,
      orderId,
      payload: options.payload || {},
      actor: options.actor || {},
    },
  );
  context.callRaw = (actor, data) => callRaw(
    actor ? tokens[actor] : null,
    data,
  );
  context.callFunction = (actor, name, data) => callFunctionRaw(
    name,
    actor ? tokens[actor] : null,
    data,
  );
  return context;
}

async function readDocument(context, documentPath) {
  const result = await context.db.doc(documentPath).get();
  assert.equal(result.exists, true, `Missing document ${documentPath}`);
  return result.data();
}

function testOrder(context, orderId, medicines, extra = {}) {
  const now = admin.firestore.Timestamp.now();
  return {
    schemaVersion: 3,
    orderId,
    orderNumber: `LIVE-${context.runId}-${orderId}`,
    user: {userId: context.userUid, name: "Live Test User"},
    pharmacy: {
      pharmacyId: context.pharmacyUid,
      pharmacyName: "Roshita Automated Test Pharmacy",
    },
    beneficiary: {
      beneficiaryId: context.userUid,
      ownerUserId: context.userUid,
      type: "self",
      name: "Live Test User",
    },
    status: "underReview",
    statusLabel: "قيد المراجعة",
    statusHistory: [],
    medicines,
    offerVersion: 0,
    reservationId: null,
    pharmacyReviewActiveMs: 0,
    reviewStartedAt: now,
    createdAt: now,
    updatedAt: now,
    liveTest: {suite: context.suiteName, runId: context.runId},
    ...extra,
  };
}

async function writeEvidence(context, status, extra = {}) {
  await context.db.doc(
    `_liveTestRuns/${context.suiteName}-${context.runId}`,
  ).set({
    suite: context.suiteName,
    runId: context.runId,
    projectId: LIVE_PROJECT_ID,
    status,
    ...extra,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}

module.exports = {
  LIVE_PROJECT_ID,
  LiveCallableError,
  exchangeCustomToken,
  initializeLiveSuite,
  readDocument,
  testOrder,
  writeEvidence,
};
