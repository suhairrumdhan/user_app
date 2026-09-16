"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {Timestamp} = require("firebase-admin/firestore");
const {
  buildOrderCommandHandler,
} = require("../../src/domain/order-commands");
const {PICKUP_WINDOW_MS} = require("../../src/domain/order-contract");
const {FakeFirestore} = require("./helpers/fake-firestore");
const {seedEmployeeSession} = require("./helpers/employee-session");

class FakeHttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

const validExpiry = Timestamp.fromDate(
  new Date("2099-01-01T00:00:00.000Z"),
);

function orderFixture({
  orderId = "order-one",
  userId = "user-one",
  status = "underReview",
  medicines = [{matchedMedicineId: "medicine-a", quantity: 2}],
  extra = {},
} = {}) {
  return {
    schemaVersion: 3,
    orderId,
    orderNumber: `TEST-${orderId}`,
    user: {userId},
    pharmacy: {pharmacyId: "pharmacy-one"},
    status,
    statusHistory: [],
    medicines,
    offerVersion: 0,
    reservationId: null,
    pharmacyReviewActiveMs: 0,
    reviewStartedAt: Timestamp.fromDate(
      new Date("2026-01-01T00:00:00.000Z"),
    ),
    ...extra,
  };
}

function medicineFixture({quantity = 10, reservedQuantity = 0} = {}) {
  return {
    id: "medicine-a",
    quantity,
    reservedQuantity,
    isActive: true,
    expiryDate: validExpiry,
  };
}

function buildDatabase({order, medicine} = {}) {
  return new FakeFirestore({
    "orders/order-one": order || orderFixture(),
    "pharmacies/pharmacy-one/medicines/medicine-a":
      medicine || medicineFixture(),
  });
}

function buildHandler(database) {
  return buildOrderCommandHandler({
    db: database,
    onCall: (handler) => handler,
    HttpsError: FakeHttpsError,
  });
}

function seedPendingInvoice(database) {
  database.write("orders/order-one", {...database.read("orders/order-one"),
    reservationId: "order-order-one", reservationState: "consumed"});
  database.write("orders/order-one/reservations/order-order-one", {
    state: "consumed", items: [{medicineId: "medicine-a", quantity: 2, soldByPiece: false}],
  });
  database.write("pharmacies/pharmacy-one/sales/invoice-one", {
    schemaVersion: 3, source: "order", orderId: "order-one", invoiceNumber: "INV-001",
    sourceOrderId: "order-one", pharmacyId: "pharmacy-one", invoiceId: "invoice-one",
    type: "sale", status: "completed", isSaved: true, isDeleted: false,
    inventoryPosted: true, reservationConsumed: true, financialPosted: false,
    total: 20, insuranceDiscount: 0, insuranceClaimAmount: 0, cashIn: 0, cardIn: 0, paymentMethod: "cash",
    paymentState: "pendingDelivery", customerShare: 20, companyShare: 0, paidAmount: 0,
    items: [{medicineId: "medicine-a", quantity: 2, unitPrice: 10}], createdAt: Timestamp.now(),
  });
  database.write("pharmacies/pharmacy-one/medicines/medicine-a", medicineFixture({quantity: 8}));
}

let operationSequence = 0;

function invoke(handler, {
  uid = "pharmacy-one",
  command,
  orderId = "order-one",
  payload = {},
  actor = {},
  operationId,
}) {
  operationSequence += 1;
  return handler({
    auth: actor?.uid ? actor : {uid},
    data: {
      schemaVersion: 3,
      command,
      operationId: operationId || `lifecycle-operation-${operationSequence}`,
      orderId,
      payload,
      actor: {},
    },
  });
}

test("full order lifecycle reserves once and ends completed", async () => {
  const database = buildDatabase();
  const handler = buildHandler(database);
  const confirmOperation = "lifecycle-confirm-fixed-001";

  const confirmed = await invoke(handler, {
    command: "confirmFullOrder",
    operationId: confirmOperation,
  });
  const confirmedRetry = await invoke(handler, {
    command: "confirmFullOrder",
    operationId: confirmOperation,
  });

  assert.deepEqual(confirmedRetry, confirmed);
  assert.equal(confirmed.result.status, "confirmedReserved");
  assert.equal(database.read("orders/order-one").statusHistory.length, 1);
  assert.equal(
    database.read("pharmacies/pharmacy-one/medicines/medicine-a")
      .reservedQuantity,
    2,
  );
  assert.equal(
    database.paths("orders/order-one/reservations/").length,
    1,
  );

  await assert.rejects(
    invoke(handler, {command: "confirmFullOrder"}),
    {code: "failed-precondition"},
  );
  assert.equal(
    database.read("pharmacies/pharmacy-one/medicines/medicine-a")
      .reservedQuantity,
    2,
  );

  database.write("pharmacies/pharmacy-one/shifts/shift-one", {status: "open"});
  await invoke(handler, {
    command: "startPreparing",
    payload: {invoiceId: "invoice-one", invoice: {
      invoiceNumber: "INV-001", shiftId: "shift-one", subtotal: 20,
      total: 20, discount: 0, insuranceDiscount: 0, paymentMethod: "cash",
      items: [{medicineId: "medicine-a", name: "Medicine A", quantity: 2, unitPrice: 10, unitCost: 4}],
    }},
  });
  assert.equal(database.read("orders/order-one").status, "preparing");
  assert.equal(
    database.read("orders/order-one/reservations/order-order-one").state,
    "consumed",
  );
  assert.equal(
    database.read("pharmacies/pharmacy-one/medicines/medicine-a")
      .reservedQuantity,
    0,
  );

  const readyOperation = "lifecycle-ready-fixed-001";
  await invoke(handler, {
    command: "markReady",
    operationId: readyOperation,
  });
  const firstReady = database.read("orders/order-one");
  const firstReadyAt = firstReady.readyAt.toMillis();
  const firstDeadline = firstReady.pickupDeadline.toMillis();
  assert.equal(firstDeadline - firstReadyAt, PICKUP_WINDOW_MS);

  await invoke(handler, {
    command: "markReady",
    operationId: readyOperation,
  });
  const readyRetry = database.read("orders/order-one");
  assert.equal(readyRetry.readyAt.toMillis(), firstReadyAt);
  assert.equal(readyRetry.pickupDeadline.toMillis(), firstDeadline);

  assert.equal(database.read("pharmacies/pharmacy-one/medicines/medicine-a").quantity, 8);
  assert.equal(database.read("pharmacies/pharmacy-one/sales/invoice-one").paidAmount, 0);
  await invoke(handler, {command: "completeOrder", payload: {collectionShiftId: "shift-one"}});
  assert.equal(database.read("pharmacies/pharmacy-one/sales/invoice-one").paidAmount, 20);
  const completed = database.read("orders/order-one");
  assert.equal(completed.status, "completed");
  assert.equal(completed.invoiceId, "invoice-one");
  assert.deepEqual(
    completed.statusHistory.map((entry) => entry.command),
    ["confirmFullOrder", "startPreparing", "markReady", "completeOrder"],
  );
});

test("cancelling before invoice releases a reservation exactly once", async () => {
  const database = buildDatabase();
  const handler = buildHandler(database);
  await invoke(handler, {command: "confirmFullOrder"});
  const cancelOperation = "lifecycle-cancel-fixed-001";

  const cancelled = await invoke(handler, {
    uid: "user-one",
    command: "cancelOrder",
    operationId: cancelOperation,
  });
  const cancelledRetry = await invoke(handler, {
    uid: "user-one",
    command: "cancelOrder",
    operationId: cancelOperation,
  });

  assert.deepEqual(cancelledRetry, cancelled);
  assert.equal(database.read("orders/order-one").status, "cancelled");
  assert.equal(
    database.read("pharmacies/pharmacy-one/medicines/medicine-a")
      .reservedQuantity,
    0,
  );
  assert.equal(
    database.read("orders/order-one/reservations/order-order-one").state,
    "released",
  );
  assert.equal(database.read("orders/order-one").statusHistory.length, 2);
});

test("two orders cannot over-reserve the same medicine", async () => {
  const database = buildDatabase({
    medicine: medicineFixture({quantity: 3}),
  });
  database.write(
    "orders/order-two",
    orderFixture({orderId: "order-two", userId: "user-two"}),
  );
  const handler = buildHandler(database);

  await invoke(handler, {command: "confirmFullOrder"});
  await assert.rejects(
    invoke(handler, {
      command: "confirmFullOrder",
      orderId: "order-two",
    }),
    {code: "failed-precondition"},
  );

  assert.equal(database.read("orders/order-one").status, "confirmedReserved");
  assert.equal(database.read("orders/order-two").status, "underReview");
  assert.equal(
    database.read("pharmacies/pharmacy-one/medicines/medicine-a")
      .reservedQuantity,
    2,
  );
  assert.equal(
    database.paths("orders/order-two/reservations/").length,
    0,
  );
});

test("duplicate lines for one medicine are combined into one reservation", async () => {
  const database = buildDatabase({
    order: orderFixture({
      medicines: [
        {matchedMedicineId: "medicine-a", quantity: 2},
        {matchedMedicineId: "medicine-a", quantity: 2},
      ],
    }),
    medicine: medicineFixture({quantity: 4}),
  });
  const handler = buildHandler(database);

  await invoke(handler, {command: "confirmFullOrder"});

  const reservation = database.read(
    "orders/order-one/reservations/order-order-one",
  );
  assert.deepEqual(reservation.items, [{
    medicineId: "medicine-a",
    quantity: 4,
    soldByPiece: false,
  }]);
  assert.equal(
    database.read("pharmacies/pharmacy-one/medicines/medicine-a")
      .reservedQuantity,
    4,
  );
});

test("repeated medicine lines cannot exceed available stock", async () => {
  const database = buildDatabase({
    order: orderFixture({
      medicines: [
        {matchedMedicineId: "medicine-a", quantity: 2},
        {matchedMedicineId: "medicine-a", quantity: 2},
      ],
    }),
    medicine: medicineFixture({quantity: 3}),
  });
  const handler = buildHandler(database);

  await assert.rejects(
    invoke(handler, {command: "confirmFullOrder"}),
    {code: "failed-precondition"},
  );

  assert.equal(database.read("orders/order-one").status, "underReview");
  assert.equal(
    database.read("pharmacies/pharmacy-one/medicines/medicine-a")
      .reservedQuantity,
    0,
  );
  assert.equal(database.paths("orders/order-one/reservations/").length, 0);
});

test("inactive expired and missing medicines never create reservations", async () => {
  const cases = [
    {
      name: "inactive",
      configure: (database) => database.write(
        "pharmacies/pharmacy-one/medicines/medicine-a",
        {...medicineFixture(), isActive: false},
      ),
    },
    {
      name: "expired",
      configure: (database) => database.write(
        "pharmacies/pharmacy-one/medicines/medicine-a",
        {
          ...medicineFixture(),
          expiryDate: Timestamp.fromDate(
            new Date("2020-01-01T00:00:00.000Z"),
          ),
        },
      ),
    },
    {
      name: "missing",
      configure: (database) => database.delete(
        "pharmacies/pharmacy-one/medicines/medicine-a",
      ),
    },
  ];

  for (const current of cases) {
    const database = buildDatabase();
    current.configure(database);
    const handler = buildHandler(database);
    await assert.rejects(
      invoke(handler, {command: "confirmFullOrder"}),
      {code: "failed-precondition"},
      current.name,
    );
    assert.equal(database.read("orders/order-one").status, "underReview");
    assert.equal(database.paths("orders/order-one/reservations/").length, 0);
  }
});

test("not-collected requires deadline employee and successful reversal", async () => {
  const futureDatabase = buildDatabase({
    order: orderFixture({
      status: "ready",
      extra: {
        invoiceId: "invoice-one",
        pickupDeadline: Timestamp.fromDate(
          new Date("2099-01-01T00:00:00.000Z"),
        ),
      },
    }),
  });
  const futureActor = seedEmployeeSession(futureDatabase, "pharmacy-one", "employee-manager",
    {isActive: true, roleId: "admin", permissions: {"orders.update_status": true}});
  futureDatabase.write("pharmacies/pharmacy-one/sales/reversal-one", {
    type: "refund",
    refSaleId: "invoice-one",
  });
  const futureHandler = buildHandler(futureDatabase);
  seedPendingInvoice(futureDatabase);
  await assert.rejects(
    invoke(futureHandler, {
      command: "markNotCollected",
      actor: futureActor,
      payload: {reversalId: "reversal-one"},
    }),
    {code: "failed-precondition"},
  );
  assert.equal(futureDatabase.read("orders/order-one").status, "ready");

  const expiredDatabase = buildDatabase({
    order: orderFixture({
      status: "ready",
      extra: {
        invoiceId: "invoice-one",
        pickupDeadline: Timestamp.fromDate(
          new Date("2020-01-01T00:00:00.000Z"),
        ),
      },
    }),
  });
  const expiredActor = seedEmployeeSession(expiredDatabase, "pharmacy-one", "employee-manager",
    {isActive: true, roleId: "admin", permissions: {"orders.update_status": true}});
  expiredDatabase.write("pharmacies/pharmacy-one/sales/reversal-one", {
    type: "refund",
    refSaleId: "invoice-one",
  });
  const expiredHandler = buildHandler(expiredDatabase);
  seedPendingInvoice(expiredDatabase);
  await invoke(expiredHandler, {
    command: "markNotCollected",
    actor: expiredActor,
    payload: {reversalId: "reversal-one"},
  });

  const notCollected = expiredDatabase.read("orders/order-one");
  assert.equal(notCollected.status, "notCollected");
  assert.equal(notCollected.reversalReason, "pickup-deadline-expired");
  assert.ok(notCollected.notCollectedAt);
});

test("post-invoice cancellation requires a reason and valid reversal", async () => {
  const database = buildDatabase({
    order: orderFixture({
      status: "preparing",
      extra: {invoiceId: "invoice-one"},
    }),
  });
  database.write("pharmacies/pharmacy-one/sales/reversal-one", {
    type: "refund",
    originalSaleId: "invoice-one",
  });
  const handler = buildHandler(database);

  await assert.rejects(
    invoke(handler, {
      command: "cancelAfterInvoice",
      payload: {reversalId: "reversal-one"},
    }),
    {code: "invalid-argument"},
  );
  assert.equal(database.read("orders/order-one").status, "preparing");

  await assert.rejects(invoke(handler, {
    command: "cancelAfterInvoice", payload: {reversalId: "reversal-one", reason: "precreated refund cannot authorize cancellation"},
  }), {code: "failed-precondition"});
  seedPendingInvoice(database);

  await invoke(handler, {
    command: "cancelAfterInvoice",
    payload: {
      reversalId: "reversal-one",
      reason: "تعذر إكمال الصرف",
    },
  });
  assert.equal(database.read("orders/order-one").status, "cancelled");
  assert.equal(database.read("orders/order-one").reversalId, "order-reversal-order-one");
  assert.equal(database.read("pharmacies/pharmacy-one/medicines/medicine-a").quantity, 10);
});
