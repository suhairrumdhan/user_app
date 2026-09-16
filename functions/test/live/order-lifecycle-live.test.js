"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const admin = require("firebase-admin");

const LIVE_PROJECT_ID = "pharma-apps";
const SUITE_NAME = "f03-live-order-lifecycle";
const FUNCTION_URL =
  `https://us-central1-${LIVE_PROJECT_ID}.cloudfunctions.net/` +
  "executeOrderCommand";

function callableUrl(name) {
  return `https://us-central1-${LIVE_PROJECT_ID}.cloudfunctions.net/${name}`;
}

function requireLiveOptIn() {
  assert.equal(
    process.env.ROSHITA_LIVE_TEST,
    "1",
    "Set ROSHITA_LIVE_TEST=1 to authorize writes to the live project.",
  );
  assert.equal(
    process.env.ROSHITA_LIVE_PROJECT_ID,
    LIVE_PROJECT_ID,
    `ROSHITA_LIVE_PROJECT_ID must be exactly ${LIVE_PROJECT_ID}.`,
  );
  const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  assert.ok(
    credentialsPath && path.isAbsolute(credentialsPath),
    "GOOGLE_APPLICATION_CREDENTIALS must be an absolute service-account path.",
  );
  assert.ok(fs.existsSync(credentialsPath), "Service-account file was not found.");
  return credentialsPath;
}

function readServiceAccount(credentialsPath) {
  const account = JSON.parse(fs.readFileSync(credentialsPath, "utf8"));
  assert.equal(
    account.project_id,
    LIVE_PROJECT_ID,
    "The service account belongs to a different Firebase project.",
  );
  return account;
}

function readWebApiKey() {
  const configPath = path.resolve(
    __dirname,
    "..",
    "..",
    "..",
    "android",
    "app",
    "google-services.json",
  );
  const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
  assert.equal(config.project_info.project_id, LIVE_PROJECT_ID);
  const apiKey = config.client?.[0]?.api_key?.[0]?.current_key;
  assert.ok(apiKey, "Firebase Web API key is missing from google-services.json.");
  return apiKey;
}

async function ensureAuthUser(auth, uid, email, displayName) {
  try {
    await auth.getUser(uid);
    await auth.updateUser(uid, {displayName, disabled: false});
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
    await auth.createUser({uid, email, displayName, emailVerified: true});
  }
}

async function exchangeCustomToken(customToken, apiKey) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:` +
      `signInWithCustomToken?key=${apiKey}`,
    {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({token: customToken, returnSecureToken: true}),
    },
  );
  const payload = await response.json();
  assert.equal(
    response.ok,
    true,
    `Custom-token sign-in failed: ${payload.error?.message || response.status}`,
  );
  return payload.idToken;
}

class LiveCallableError extends Error {
  constructor(error) {
    super(error?.message || "Live callable failed.");
    this.code = String(error?.status || "unknown")
      .toLowerCase()
      .replaceAll("_", "-");
    this.details = error?.details;
  }
}

async function callOrderCommand(idToken, data) {
  return callFunction(FUNCTION_URL, idToken, data);
}

async function callFunction(url, idToken, data) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${idToken}`,
      "Content-Type": "application/json; charset=utf-8",
    },
    body: JSON.stringify({data}),
  });
  const envelope = await response.json();
  if (envelope.error) throw new LiveCallableError(envelope.error);
  assert.equal(response.ok, true, `Callable HTTP status: ${response.status}`);
  assert.ok(envelope.result, "Callable response has no result envelope.");
  return envelope.result;
}

function orderCommand(context, actor, command, orderId, options = {}) {
  const operationId = options.operationId ||
    `live:${context.runId}:${command}:${crypto.randomBytes(4).toString("hex")}`;
  return callOrderCommand(context.tokens[actor], {
    schemaVersion: 3,
    command,
    operationId,
    orderId,
    payload: options.payload || {},
    actor: options.actor || {},
  });
}

function orderDocument(context, id, medicines, extra = {}) {
  const now = admin.firestore.Timestamp.now();
  return {
    schemaVersion: 3,
    orderId: id,
    orderNumber: `LIVE-${context.runId}-${id}`,
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
    liveTest: {suite: SUITE_NAME, runId: context.runId},
    ...extra,
  };
}

async function seedLiveRun(context) {
  const db = context.db;
  const now = admin.firestore.Timestamp.now();
  const expiredDeadline = admin.firestore.Timestamp.fromDate(
    new Date("2020-01-01T00:00:00.000Z"),
  );
  const batch = db.batch();
  batch.set(db.doc(`users/${context.userUid}`), {
    userId: context.userUid,
    name: "Live Test User",
    isActive: true,
    liveTest: true,
    updatedAt: now,
  }, {merge: true});
  batch.set(db.doc(`pharmacies/${context.pharmacyUid}`), {
    id: context.pharmacyUid,
    pharmacyId: context.pharmacyUid,
    name: "Roshita Automated Test Pharmacy",
    status: "approved",
    isOnline: true,
    isActive: true,
    liveTest: true,
    updatedAt: now,
  }, {merge: true});
  batch.set(
    db.doc(
      `pharmacies/${context.pharmacyUid}/employees/` +
      context.employeeId,
    ),
    {
      id: context.employeeId,
      roleId: "admin",
      isActive: true,
      liveTest: true,
      updatedAt: now,
    },
  );
  batch.set(db.doc(context.medicineRef), {
    id: context.medicineId,
    name: "Live Test Medicine Shared",
    quantity: 6,
    reservedQuantity: 0,
    isActive: true,
    expiryDate: admin.firestore.Timestamp.fromDate(
      new Date("2099-01-01T00:00:00.000Z"),
    ),
    liveTest: {suite: SUITE_NAME, runId: context.runId},
    updatedAt: now,
  });
  batch.set(db.doc(context.partialMedicineRef), {
    id: context.partialMedicineId,
    name: "Live Test Medicine Partial",
    quantity: 5,
    reservedQuantity: 0,
    isActive: true,
    expiryDate: admin.firestore.Timestamp.fromDate(
      new Date("2099-01-01T00:00:00.000Z"),
    ),
    liveTest: {suite: SUITE_NAME, runId: context.runId},
    updatedAt: now,
  });
  batch.set(db.doc(context.unavailableMedicineRef), {
    id: context.unavailableMedicineId,
    name: "Live Test Medicine Unavailable Offer",
    quantity: 2,
    reservedQuantity: 1,
    isActive: true,
    expiryDate: admin.firestore.Timestamp.fromDate(
      new Date("2099-01-01T00:00:00.000Z"),
    ),
    liveTest: {suite: SUITE_NAME, runId: context.runId},
    updatedAt: now,
  });
  batch.set(db.doc(`orders/${context.primaryOrderId}`), orderDocument(
    context,
    context.primaryOrderId,
    [
      {matchedMedicineId: context.medicineId, quantity: 2},
      {matchedMedicineId: context.medicineId, quantity: 2},
    ],
  ));
  batch.set(db.doc(`orders/${context.competingOrderId}`), orderDocument(
    context,
    context.competingOrderId,
    [{matchedMedicineId: context.medicineId, quantity: 3}],
  ));
  batch.set(db.doc(`orders/${context.partialOrderId}`), orderDocument(
    context,
    context.partialOrderId,
    [{matchedMedicineId: context.partialMedicineId, quantity: 4}],
  ));
  batch.set(db.doc(`orders/${context.unavailableOfferOrderId}`), orderDocument(
    context,
    context.unavailableOfferOrderId,
    [{matchedMedicineId: context.unavailableMedicineId, quantity: 2}],
  ));
  batch.set(db.doc(`orders/${context.notCollectedOrderId}`), orderDocument(
    context,
    context.notCollectedOrderId,
    [{matchedMedicineId: context.partialMedicineId, quantity: 1}],
    {
      status: "ready",
      statusLabel: "جاهز للاستلام",
      invoiceId: context.notCollectedInvoiceId,
      reservationId: `order-${context.notCollectedOrderId}`, reservationState: "consumed",
      pickupDeadline: expiredDeadline,
    },
  ));
  batch.set(db.doc(`pharmacies/${context.pharmacyUid}/shifts/${context.shiftId}`), {
    status: "open", cashTotal: 0, cardTotal: 0, salesCount: 0,
  });
  batch.set(db.doc(`pharmacies/${context.pharmacyUid}/sales/${context.notCollectedInvoiceId}`), {
    schemaVersion: 3, source: "order", orderId: context.notCollectedOrderId,
    sourceOrderId: context.notCollectedOrderId, pharmacyId: context.pharmacyUid, invoiceId: context.notCollectedInvoiceId,
    type: "sale", status: "completed", isSaved: true, isDeleted: false,
    inventoryPosted: true, reservationConsumed: true, financialPosted: false,
    total: 10, insuranceDiscount: 0, insuranceClaimAmount: 0, cashIn: 0, cardIn: 0, paymentMethod: "cash",
    invoiceNumber: `INV-NC-${context.runId}`, paymentState: "pendingDelivery",
    customerShare: 10, companyShare: 0, paidAmount: 0,
    items: [{medicineId: context.partialMedicineId, quantity: 1, unitPrice: 10}],
    createdAt: now,
    liveTest: true,
  });
  batch.set(db.doc(`orders/${context.notCollectedOrderId}/reservations/order-${context.notCollectedOrderId}`), {
    state: "consumed", items: [{medicineId: context.partialMedicineId, quantity: 1, soldByPiece: false}],
  });
  batch.set(db.doc(context.reversalRef), {
    type: "refund",
    refSaleId: context.notCollectedInvoiceId,
    createdAt: now,
    liveTest: true,
  });
  batch.set(db.doc(context.evidenceRef), {
    suite: SUITE_NAME,
    runId: context.runId,
    projectId: LIVE_PROJECT_ID,
    status: "running",
    orderIds: [
      context.primaryOrderId,
      context.competingOrderId,
      context.partialOrderId,
      context.unavailableOfferOrderId,
      context.notCollectedOrderId,
    ],
    startedAt: now,
  });
  await batch.commit();
}

async function documentData(db, documentPath) {
  const snapshot = await db.doc(documentPath).get();
  assert.equal(snapshot.exists, true, `Missing live document: ${documentPath}`);
  return snapshot.data();
}

function buildContext(db, auth, apiKey) {
  const runId = `${Date.now()}-${crypto.randomBytes(3).toString("hex")}`;
  const pharmacyUid = "roshita-live-pharmacy-f03";
  const userUid = "roshita-live-user-f03";
  const medicineId = `live-shared-${runId}`;
  const partialMedicineId = `live-partial-${runId}`;
  const unavailableMedicineId = `live-unavailable-offer-${runId}`;
  const primaryOrderId = `live-primary-${runId}`;
  const notCollectedInvoiceId = `live-old-invoice-${runId}`;
  return {
    db,
    auth,
    apiKey,
    runId,
    pharmacyUid,
    userUid,
    employeeId: `live-test-manager-${runId}`,
    medicineId,
    partialMedicineId,
    unavailableMedicineId,
    primaryOrderId,
    competingOrderId: `live-competing-${runId}`,
    partialOrderId: `live-partial-order-${runId}`,
    unavailableOfferOrderId: `live-unavailable-offer-order-${runId}`,
    notCollectedOrderId: `live-not-collected-${runId}`,
    notCollectedInvoiceId,
    shiftId: `live-shift-${runId}`,
    medicineRef: `pharmacies/${pharmacyUid}/medicines/${medicineId}`,
    partialMedicineRef:
      `pharmacies/${pharmacyUid}/medicines/${partialMedicineId}`,
    unavailableMedicineRef:
      `pharmacies/${pharmacyUid}/medicines/${unavailableMedicineId}`,
    invoiceRef:
      `pharmacies/${pharmacyUid}/sales/live-invoice-${runId}`,
    reversalRef:
      `pharmacies/${pharmacyUid}/sales/live-reversal-${runId}`,
    evidenceRef: `_liveTestRuns/${SUITE_NAME}-${runId}`,
    tokens: {},
  };
}

test("F03 complete lifecycle on the live Firebase project", {
  timeout: 180000,
}, async (t) => {
  const credentialsPath = requireLiveOptIn();
  const serviceAccount = readServiceAccount(credentialsPath);
  const apiKey = readWebApiKey();
  const app = admin.apps.length > 0 ? admin.app() : admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: LIVE_PROJECT_ID,
  });
  const db = app.firestore();
  const auth = app.auth();
  const context = buildContext(db, auth, apiKey);

  await ensureAuthUser(
    auth,
    context.userUid,
    "roshita-live-user-f03@example.invalid",
    "Roshita Live Test User",
  );
  await ensureAuthUser(
    auth,
    context.pharmacyUid,
    "roshita-live-pharmacy-f03@example.invalid",
    "Roshita Live Test Pharmacy",
  );
  context.tokens.user = await exchangeCustomToken(
    await auth.createCustomToken(context.userUid),
    apiKey,
  );
  context.tokens.pharmacy = await exchangeCustomToken(
    await auth.createCustomToken(context.pharmacyUid),
    apiKey,
  );
  await seedLiveRun(context);
  await callFunction(
    callableUrl("managePharmacyEmployeeCredential"),
    context.tokens.pharmacy,
    {
      pharmacyId: context.pharmacyUid,
      employeeId: context.employeeId,
      username: context.employeeId,
      password: "LiveEmployee-2026",
    },
  );
  const employeeLogin = await callFunction(
    callableUrl("createPharmacyEmployeeSession"),
    context.tokens.pharmacy,
    {
      pharmacyId: context.pharmacyUid,
      username: context.employeeId,
      password: "LiveEmployee-2026",
    },
  );
  context.employeeActor = {
    employeeId: context.employeeId,
    employeeSession: employeeLogin.sessionToken,
  };

  try {
    await t.test("duplicate medicine lines reserve their total once", async () => {
      const operationId = `live:${context.runId}:confirm:fixed`;
      const first = await orderCommand(
        context,
        "pharmacy",
        "confirmFullOrder",
        context.primaryOrderId,
        {operationId},
      );
      const retry = await orderCommand(
        context,
        "pharmacy",
        "confirmFullOrder",
        context.primaryOrderId,
        {operationId},
      );
      assert.deepEqual(retry, first);
      const inventory = await documentData(db, context.medicineRef);
      assert.equal(inventory.reservedQuantity, 4);
      const order = await documentData(
        db,
        `orders/${context.primaryOrderId}`,
      );
      assert.equal(order.status, "confirmedReserved");
      assert.equal(order.statusHistory.length, 1);
      const reservation = await documentData(
        db,
        `orders/${context.primaryOrderId}/reservations/` +
        `order-${context.primaryOrderId}`,
      );
      assert.deepEqual(reservation.items, [{
        medicineId: context.medicineId,
        quantity: 4,
        soldByPiece: false,
      }]);
    });

    await t.test("a competing order cannot over-reserve the drug", async () => {
      await assert.rejects(
        orderCommand(
          context,
          "pharmacy",
          "confirmFullOrder",
          context.competingOrderId,
        ),
        (error) => error.code === "failed-precondition",
      );
      const inventory = await documentData(db, context.medicineRef);
      assert.equal(inventory.reservedQuantity, 4);
      const order = await documentData(
        db,
        `orders/${context.competingOrderId}`,
      );
      assert.equal(order.status, "underReview");
      const reservation = await db.doc(
        `orders/${context.competingOrderId}/reservations/` +
        `order-${context.competingOrderId}`,
      ).get();
      assert.equal(reservation.exists, false);
    });

    await t.test("partial offer waits for acceptance before reserving", async () => {
      const items = [{
        medicineId: context.partialMedicineId,
        quantity: 2,
        soldByPiece: false,
      }];
      await orderCommand(
        context,
        "pharmacy",
        "createPartialOffer",
        context.partialOrderId,
        {payload: {items}},
      );
      let inventory = await documentData(db, context.partialMedicineRef);
      assert.equal(inventory.reservedQuantity, 0);

      await orderCommand(
        context,
        "user",
        "acceptPartialOffer",
        context.partialOrderId,
        {payload: {offerVersion: 1}},
      );
      inventory = await documentData(db, context.partialMedicineRef);
      assert.equal(inventory.reservedQuantity, 2);

      await orderCommand(
        context,
        "user",
        "cancelOrder",
        context.partialOrderId,
      );
      inventory = await documentData(db, context.partialMedicineRef);
      assert.equal(inventory.reservedQuantity, 0);
      const order = await documentData(
        db,
        `orders/${context.partialOrderId}`,
      );
      assert.equal(order.status, "cancelled");
    });

    await t.test("an already-unavailable partial offer is never published", async () => {
      const before = await documentData(
        db,
        `orders/${context.unavailableOfferOrderId}`,
      );
      await assert.rejects(
        orderCommand(
          context,
          "pharmacy",
          "createPartialOffer",
          context.unavailableOfferOrderId,
          {payload: {items: [{
            medicineId: context.unavailableMedicineId,
            quantity: 2,
            soldByPiece: false,
          }]}},
        ),
        (error) => error.code === "failed-precondition" &&
          error.message.includes("insufficient stock"),
      );
      const after = await documentData(
        db,
        `orders/${context.unavailableOfferOrderId}`,
      );
      assert.deepEqual(after, before);
      const inventory = await documentData(db, context.unavailableMedicineRef);
      assert.equal(inventory.quantity, 2);
      assert.equal(inventory.reservedQuantity, 1);
      const reservation = await db.doc(
        `orders/${context.unavailableOfferOrderId}/reservations/` +
        `order-${context.unavailableOfferOrderId}`,
      ).get();
      assert.equal(reservation.exists, false);
    });

    await t.test("confirmed order reaches completed with a fixed deadline", async () => {
      const invoiceId = context.invoiceRef.split("/").at(-1);
      await orderCommand(
        context,
        "pharmacy",
        "startPreparing",
        context.primaryOrderId,
        {payload: {invoiceId, invoice: {
          invoiceNumber: `INV-${context.runId}`, shiftId: context.shiftId,
          subtotal: 40, total: 40, discount: 0, insuranceDiscount: 0, paymentMethod: "cash",
          items: [{medicineId: context.medicineId, name: "Live medicine", quantity: 4, unitPrice: 10, unitCost: 4}],
        }}},
      );
      const readyOperation = `live:${context.runId}:ready:fixed`;
      await orderCommand(
        context,
        "pharmacy",
        "markReady",
        context.primaryOrderId,
        {operationId: readyOperation},
      );
      const firstReady = await documentData(
        db,
        `orders/${context.primaryOrderId}`,
      );
      const readyAt = firstReady.readyAt.toMillis();
      const deadline = firstReady.pickupDeadline.toMillis();
      assert.equal(deadline - readyAt, 24 * 60 * 60 * 1000);

      await orderCommand(
        context,
        "pharmacy",
        "markReady",
        context.primaryOrderId,
        {operationId: readyOperation},
      );
      const readyRetry = await documentData(
        db,
        `orders/${context.primaryOrderId}`,
      );
      assert.equal(readyRetry.readyAt.toMillis(), readyAt);
      assert.equal(readyRetry.pickupDeadline.toMillis(), deadline);

      await orderCommand(
        context,
        "pharmacy",
        "completeOrder",
        context.primaryOrderId,
        {payload: {collectionShiftId: context.shiftId}},
      );
      const completed = await documentData(
        db,
        `orders/${context.primaryOrderId}`,
      );
      assert.equal(completed.status, "completed");
      const invoice = await documentData(db, context.invoiceRef);
      assert.equal(invoice.paidAmount, 40);
      assert.equal(invoice.paymentState, "delivered");
      assert.equal((await documentData(db, context.medicineRef)).reservedQuantity, 0);
      assert.deepEqual(
        completed.statusHistory.map((entry) => entry.command),
        ["confirmFullOrder", "startPreparing", "markReady", "completeOrder"],
      );
    });

    await t.test("expired pickup becomes not-collected without a note", async () => {
      await orderCommand(
        context,
        "pharmacy",
        "markNotCollected",
        context.notCollectedOrderId,
        {
          actor: context.employeeActor,
          payload: {
            reversalId: context.reversalRef.split("/").at(-1),
          },
        },
      );
      const order = await documentData(
        db,
        `orders/${context.notCollectedOrderId}`,
      );
      assert.equal(order.status, "notCollected");
      assert.equal(order.reversalReason, "pickup-deadline-expired");
    });

    await db.doc(context.evidenceRef).set({
      status: "passed",
      finishedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  } catch (error) {
    await db.doc(context.evidenceRef).set({
      status: "failed",
      errorCode: error.code || "unknown",
      errorMessage: String(error.message || error).slice(0, 500),
      finishedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    throw error;
  } finally {
    await app.delete();
  }
});
