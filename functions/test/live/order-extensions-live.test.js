"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const admin = require("firebase-admin");
const {
  initializeLiveSuite,
  readDocument,
  testOrder,
  writeEvidence,
} = require("./helpers/live-firebase");

const SUITE_NAME = "f03-live-order-extensions";

function medicinePath(context, medicineId) {
  return `pharmacies/${context.pharmacyUid}/medicines/${medicineId}`;
}

function orderPath(orderId) {
  return `orders/${orderId}`;
}

function validMedicine(context, medicineId, extra = {}) {
  return {
    id: medicineId,
    name: `Live Extension Medicine ${medicineId}`,
    quantity: 10,
    reservedQuantity: 0,
    isActive: true,
    expiryDate: admin.firestore.Timestamp.fromDate(
      new Date("2099-01-01T00:00:00.000Z"),
    ),
    liveTest: {suite: SUITE_NAME, runId: context.runId},
    ...extra,
  };
}

function createOrderPayload(context, medicineId, options = {}) {
  return {
    order: {
      user: {
        userId: options.userId || context.userUid,
        name: "Live Test User",
      },
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
      insurance: options.insurance || {
        enabled: false,
        companyCodes: [],
      },
      requestSource: "manual",
      medicines: [{
        requestedName: "Live Test Medicine",
        normalizedName: "LIVE TEST MEDICINE",
        matchedMedicineId: medicineId,
        matchedMedicineName: "Live Test Medicine",
        quantity: 1,
        soldByPiece: false,
      }],
      metadata: {liveTest: true, suite: SUITE_NAME, runId: context.runId},
    },
  };
}

async function seedBase(context) {
  const now = admin.firestore.Timestamp.now();
  context.activeEmployeeId = `active-manager-${context.runId}`;
  context.inactiveEmployeeId = `inactive-manager-${context.runId}`;
  const batch = context.db.batch();
  batch.set(context.db.doc(`users/${context.userUid}`), {
    userId: context.userUid,
    name: "Live Test User",
    isActive: true,
    liveTest: true,
    updatedAt: now,
  }, {merge: true});
  batch.set(context.db.doc(`pharmacies/${context.pharmacyUid}`), {
    id: context.pharmacyUid,
    pharmacyId: context.pharmacyUid,
    name: "Roshita Automated Test Pharmacy",
    status: "approved",
    isOnline: true,
    isActive: true,
    acceptedInsuranceCodes: ["ACCEPTED-LIVE"],
    liveTest: true,
    updatedAt: now,
  }, {merge: true});
  batch.set(context.db.doc(
    `pharmacies/${context.pharmacyUid}/employees/${context.activeEmployeeId}`,
  ), {
    id: context.activeEmployeeId,
    roleId: "admin",
    isActive: true,
    liveTest: true,
  });
  batch.set(context.db.doc(
    `pharmacies/${context.pharmacyUid}/employees/${context.inactiveEmployeeId}`,
  ), {
    id: context.inactiveEmployeeId,
    roleId: "admin",
    // Enabled only long enough to obtain a server session; it is disabled below.
    isActive: true,
    liveTest: true,
  });
  await batch.commit();
  await writeEvidence(context, "running");
}

async function seedOrder(context, label, options = {}) {
  const orderId = `live-${label}-${context.runId}`;
  const medicines = options.medicines || [{
    matchedMedicineId: options.medicineId,
    quantity: options.quantity || 1,
    soldByPiece: options.soldByPiece === true,
  }];
  await context.db.doc(orderPath(orderId)).set(testOrder(
    context,
    orderId,
    medicines,
    options.extra || {},
  ));
  return orderId;
}

test("F03 extensions and failures on the live Firebase project", {
  timeout: 300000,
}, async (t) => {
  const context = await initializeLiveSuite(SUITE_NAME);
  await seedBase(context);
  for (const employeeId of [context.activeEmployeeId, context.inactiveEmployeeId]) {
    await context.callFunction(
      "pharmacy",
      "managePharmacyEmployeeCredential",
      {
        pharmacyId: context.pharmacyUid,
        employeeId,
        username: employeeId,
        password: "LiveEmployee-2026",
      },
    );
  }
  const activeLogin = await context.callFunction(
    "pharmacy",
    "createPharmacyEmployeeSession",
    {
      pharmacyId: context.pharmacyUid,
      username: context.activeEmployeeId,
      password: "LiveEmployee-2026",
    },
  );
  const inactiveLogin = await context.callFunction(
    "pharmacy",
    "createPharmacyEmployeeSession",
    {
      pharmacyId: context.pharmacyUid,
      username: context.inactiveEmployeeId,
      password: "LiveEmployee-2026",
    },
  );
  context.activeEmployeeActor = {
    employeeId: context.activeEmployeeId,
    employeeSession: activeLogin.sessionToken,
  };
  context.inactiveEmployeeActor = {
    employeeId: context.inactiveEmployeeId,
    employeeSession: inactiveLogin.sessionToken,
  };
  await context.db.doc(
    `pharmacies/${context.pharmacyUid}/employees/${context.inactiveEmployeeId}`,
  ).update({isActive: false});

  try {
    await t.test("createOrder is idempotent and creates no reservation", async () => {
      const medicineId = `create-${context.runId}`;
      await context.db.doc(medicinePath(context, medicineId)).set(
        validMedicine(context, medicineId),
      );
      const operationId = `live:${context.runId}:create:fixed`;
      const data = {
        schemaVersion: 3,
        command: "createOrder",
        operationId,
        payload: createOrderPayload(context, medicineId),
        actor: {},
      };
      const first = await context.callRaw("user", data);
      const retry = await context.callRaw("user", data);
      assert.deepEqual(retry, first);
      const createdId = first.result.orderId;
      const order = await readDocument(context, orderPath(createdId));
      assert.equal(order.status, "underReview");
      assert.equal(order.statusHistory.length, 2);
      const reservation = await context.db.doc(
        `orders/${createdId}/reservations/order-${createdId}`,
      ).get();
      assert.equal(reservation.exists, false);
      const matching = await context.db.collection("orders")
        .where("operationId", "==", operationId).get();
      assert.equal(matching.size, 1);
    });

    await t.test("insurance mismatch keeps a new order received", async () => {
      const medicineId = `insurance-${context.runId}`;
      await context.db.doc(medicinePath(context, medicineId)).set(
        validMedicine(context, medicineId),
      );
      const result = await context.callRaw("user", {
        schemaVersion: 3,
        command: "createOrder",
        operationId: `live:${context.runId}:insurance:mismatch`,
        payload: createOrderPayload(context, medicineId, {
          insurance: {
            enabled: true,
            companyCodes: ["NOT-ACCEPTED-LIVE"],
          },
        }),
        actor: {},
      });
      const order = await readDocument(
        context,
        orderPath(result.result.orderId),
      );
      assert.equal(order.status, "received");
      assert.equal(order.statusHistory.length, 1);
    });

    await t.test("user can cancel every pre-invoice waiting state", async () => {
      const statuses = ["received", "underReview", "partialOfferPending"];
      for (const status of statuses) {
        const medicineId = `cancel-${status}-${context.runId}`;
        await context.db.doc(medicinePath(context, medicineId)).set(
          validMedicine(context, medicineId),
        );
        const orderId = await seedOrder(context, `cancel-${status}`, {
          medicineId,
          extra: status === "partialOfferPending" ? {
            status,
            offerVersion: 1,
            partialOffer: {
              version: 1,
              items: [{medicineId, quantity: 1}],
            },
          } : {status},
        });
        await context.call("user", "cancelOrder", orderId);
        const cancelled = await readDocument(context, orderPath(orderId));
        assert.equal(cancelled.status, "cancelled", status);
      }
    });

    await t.test("stale offer and changed idempotency payload are rejected", async () => {
      const medicineId = `stale-${context.runId}`;
      await context.db.doc(medicinePath(context, medicineId)).set(
        validMedicine(context, medicineId),
      );
      const staleOrderId = await seedOrder(context, "stale-offer", {
        medicineId,
        extra: {
          status: "partialOfferPending",
          offerVersion: 2,
          partialOffer: {
            version: 2,
            items: [{medicineId, quantity: 2}],
          },
        },
      });
      await assert.rejects(
        context.call("user", "acceptPartialOffer", staleOrderId, {
          payload: {offerVersion: 1},
        }),
        (error) => error.code === "aborted",
      );
      assert.equal(
        (await readDocument(context, orderPath(staleOrderId))).status,
        "partialOfferPending",
      );

      const conflictOrderId = await seedOrder(context, "payload-conflict", {
        medicineId,
      });
      const operationId = `live:${context.runId}:payload:fixed`;
      await context.call("pharmacy", "createPartialOffer", conflictOrderId, {
        operationId,
        payload: {items: [{medicineId, quantity: 1}]},
      });
      await assert.rejects(
        context.call("pharmacy", "createPartialOffer", conflictOrderId, {
          operationId,
          payload: {items: [{medicineId, quantity: 2}]},
        }),
        (error) => error.code === "already-exists",
      );
      const conflictOrder = await readDocument(
        context,
        orderPath(conflictOrderId),
      );
      assert.equal(conflictOrder.partialOffer.items[0].quantity, 1);
      assert.equal(conflictOrder.offerVersion, 1);
    });

    await t.test("simultaneous orders reserve stock only once", async () => {
      const medicineId = `race-${context.runId}`;
      const medicineRef = medicinePath(context, medicineId);
      await context.db.doc(medicineRef).set(validMedicine(
        context,
        medicineId,
        {quantity: 3},
      ));
      const firstId = await seedOrder(context, "race-one", {
        medicineId,
        quantity: 2,
      });
      const secondId = await seedOrder(context, "race-two", {
        medicineId,
        quantity: 2,
      });
      const results = await Promise.allSettled([
        context.call("pharmacy", "confirmFullOrder", firstId),
        context.call("pharmacy", "confirmFullOrder", secondId),
      ]);
      assert.equal(
        results.filter((result) => result.status === "fulfilled").length,
        1,
      );
      assert.equal(
        results.filter((result) => result.status === "rejected").length,
        1,
      );
      assert.equal(
        (await readDocument(context, medicineRef)).reservedQuantity,
        2,
      );
      const statuses = await Promise.all([
        readDocument(context, orderPath(firstId)),
        readDocument(context, orderPath(secondId)),
      ]);
      assert.deepEqual(
        statuses.map((order) => order.status).sort(),
        ["confirmedReserved", "underReview"],
      );
    });

    await t.test("piece reservations use only reservedPieceQuantity", async () => {
      const medicineId = `piece-${context.runId}`;
      const medicineRef = medicinePath(context, medicineId);
      await context.db.doc(medicineRef).set(validMedicine(
        context,
        medicineId,
        {
          quantity: 9,
          reservedQuantity: 0,
          pieceQuantity: 5,
          reservedPieceQuantity: 0,
        },
      ));
      const orderId = await seedOrder(context, "piece", {
        medicineId,
        quantity: 3,
        soldByPiece: true,
      });
      await context.call("pharmacy", "confirmFullOrder", orderId);
      let inventory = await readDocument(context, medicineRef);
      assert.equal(inventory.reservedPieceQuantity, 3);
      assert.equal(inventory.reservedQuantity, 0);
      await context.call("user", "cancelOrder", orderId);
      inventory = await readDocument(context, medicineRef);
      assert.equal(inventory.reservedPieceQuantity, 0);
      assert.equal(inventory.reservedQuantity, 0);
    });

    await t.test("invalid inventory never changes an order", async () => {
      const cases = [
        {label: "missing", medicine: null},
        {label: "inactive", medicine: {isActive: false}},
        {
          label: "expired",
          medicine: {
            expiryDate: admin.firestore.Timestamp.fromDate(
              new Date("2020-01-01T00:00:00.000Z"),
            ),
          },
        },
        {label: "insufficient", medicine: {quantity: 0}},
      ];
      for (const current of cases) {
        const medicineId = `${current.label}-${context.runId}`;
        if (current.medicine) {
          await context.db.doc(medicinePath(context, medicineId)).set({
            ...validMedicine(context, medicineId),
            ...current.medicine,
          });
        }
        const orderId = await seedOrder(context, current.label, {medicineId});
        await assert.rejects(
          context.call("pharmacy", "confirmFullOrder", orderId),
          (error) => error.code === "failed-precondition",
        );
        assert.equal(
          (await readDocument(context, orderPath(orderId))).status,
          "underReview",
        );
        const reservation = await context.db.doc(
          `orders/${orderId}/reservations/order-${orderId}`,
        ).get();
        assert.equal(reservation.exists, false);
      }
    });

    await t.test("authentication authorization and schema are enforced", async () => {
      const medicineId = `security-${context.runId}`;
      await context.db.doc(medicinePath(context, medicineId)).set(
        validMedicine(context, medicineId),
      );
      const orderId = await seedOrder(context, "security", {medicineId});
      await assert.rejects(
        context.call(null, "confirmFullOrder", orderId),
        (error) => error.code === "permission-denied",
      );
      await assert.rejects(
        context.call("outsider", "confirmFullOrder", orderId),
        (error) => error.code === "permission-denied",
      );
      await assert.rejects(
        context.call("pharmacy", "confirmFullOrder", orderId, {
          actor: context.inactiveEmployeeActor,
        }),
        (error) => error.code === "permission-denied",
      );
      await assert.rejects(
        context.call("pharmacy", "confirmFullOrder", orderId, {
          schemaVersion: 2,
        }),
        (error) => error.code === "failed-precondition",
      );
      await assert.rejects(
        context.call("pharmacy", "unknownCommand", orderId),
        (error) => error.code === "invalid-argument",
      );
      await assert.rejects(
        context.call(
          "pharmacy",
          "confirmFullOrder",
          `missing-${context.runId}`,
        ),
        (error) => error.code === "not-found",
      );
      assert.equal(
        (await readDocument(context, orderPath(orderId))).status,
        "underReview",
      );
    });

    await t.test("invoice and reversal guards preserve the prior state", async () => {
      const medicineId = `invoice-${context.runId}`;
      const medicineRef = medicinePath(context, medicineId);
      await context.db.doc(medicineRef).set(
        validMedicine(context, medicineId),
      );
      const orderId = await seedOrder(context, "invoice-guard", {medicineId});
      await context.call("pharmacy", "confirmFullOrder", orderId);
      await assert.rejects(
        context.call("pharmacy", "startPreparing", orderId, {
          payload: {invoiceId: `missing-invoice-${context.runId}`},
        }),
        (error) => error.code === "failed-precondition",
      );
      let order = await readDocument(context, orderPath(orderId));
      assert.equal(order.status, "confirmedReserved");
      assert.equal(order.reservationState, "active");
      assert.equal(
        (await readDocument(context, medicineRef)).reservedQuantity,
        1,
      );

      const preparingId = await seedOrder(context, "reversal-guard", {
        medicineId,
        extra: {status: "preparing", invoiceId: `invoice-${context.runId}`},
      });
      await assert.rejects(
        context.call("pharmacy", "cancelAfterInvoice", preparingId, {
          payload: {
            reason: "Live invalid reversal",
            reversalId: `missing-reversal-${context.runId}`,
          },
        }),
        (error) => error.code === "failed-precondition",
      );
      order = await readDocument(context, orderPath(preparingId));
      assert.equal(order.status, "preparing");
    });

    await t.test("not-collected rejects early or unauthorized attempts", async () => {
      const medicineId = `pickup-${context.runId}`;
      const invoiceId = `pickup-invoice-${context.runId}`;
      const reversalId = `pickup-reversal-${context.runId}`;
      const orderId = await seedOrder(context, "pickup-guard", {
        medicineId,
        extra: {
          status: "ready",
          invoiceId,
          pickupDeadline: admin.firestore.Timestamp.fromDate(
            new Date("2099-01-01T00:00:00.000Z"),
          ),
        },
      });
      await context.db.doc(
        `pharmacies/${context.pharmacyUid}/sales/${reversalId}`,
      ).set({type: "refund", refSaleId: invoiceId, liveTest: true});
      await context.db.doc(`pharmacies/${context.pharmacyUid}/sales/${invoiceId}`).set({
        schemaVersion: 3, source: "order", orderId, paymentState: "pendingDelivery",
        sourceOrderId: orderId, pharmacyId: context.pharmacyUid, invoiceId,
        type: "sale", status: "completed", isSaved: true, isDeleted: false,
        inventoryPosted: true, reservationConsumed: true, financialPosted: false,
        total: 10, insuranceDiscount: 0, insuranceClaimAmount: 0, cashIn: 0, cardIn: 0, paymentMethod: "cash",
        items: [{medicineId, quantity: 1, unitPrice: 10}], customerShare: 10, companyShare: 0, paidAmount: 0,
        liveTest: true,
      });
      await context.db.doc(`orders/${orderId}`).update({reservationId: `order-${orderId}`, reservationState: "consumed"});
      await context.db.doc(`orders/${orderId}/reservations/order-${orderId}`).set({
        state: "consumed", items: [{medicineId, quantity: 1, soldByPiece: false}],
      });
      await assert.rejects(
        context.call("pharmacy", "markNotCollected", orderId, {
          payload: {reversalId},
        }),
        (error) => error.code === "permission-denied",
      );
      await assert.rejects(
        context.call("pharmacy", "markNotCollected", orderId, {
          actor: context.activeEmployeeActor,
          payload: {reversalId},
        }),
        (error) => error.code === "failed-precondition",
      );
      assert.equal(
        (await readDocument(context, orderPath(orderId))).status,
        "ready",
      );
    });

    await writeEvidence(context, "passed");
  } catch (error) {
    await writeEvidence(context, "failed", {
      errorCode: error.code || "unknown",
      errorMessage: String(error.message || error).slice(0, 500),
    });
    throw error;
  } finally {
    await context.app.delete();
  }
});
