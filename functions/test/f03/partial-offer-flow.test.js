"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {Timestamp} = require("firebase-admin/firestore");
const {
  buildOrderCommandHandler,
} = require("../../src/domain/order-commands");
const {FakeFirestore} = require("./helpers/fake-firestore");

class FakeHttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

function buildDatabase({
  status = "underReview",
  offerVersion = 0,
  partialOffer = null,
  medicines = {},
} = {}) {
  const validExpiry = Timestamp.fromDate(
    new Date("2099-01-01T00:00:00.000Z"),
  );
  const inventory = Object.fromEntries(
    Object.entries({
      "medicine-a": {quantity: 10, reservedQuantity: 0},
      ...medicines,
    }).map(([id, data]) => [
      `pharmacies/pharmacy-one/medicines/${id}`,
      {
        id,
        isActive: true,
        sellingPrice: 10,
        piecePrice: 1,
        unitsPerPackage: 10,
        expiryDate: validExpiry,
        reservedQuantity: 0,
        ...data,
      },
    ]),
  );
  return new FakeFirestore({
    "pharmacies/pharmacy-one": {status: "approved", isActive: true},
    "pharmacies/pharmacy": {status: "approved", isActive: true},
    "orders/order-one": {
      schemaVersion: 3,
      orderId: "order-one",
      user: {userId: "user-one"},
      pharmacy: {pharmacyId: "pharmacy-one"},
      status,
      statusHistory: [],
      medicines: [
        {matchedMedicineId: "medicine-a", quantity: 3},
      ],
      offerVersion,
      partialOffer,
      reservationId: null,
      pharmacyReviewActiveMs: 0,
      reviewStartedAt: Timestamp.fromDate(
        new Date("2026-01-01T00:00:00.000Z"),
      ),
    },
    ...inventory,
  });
}

function buildHandler(database) {
  return buildOrderCommandHandler({
    db: database,
    onCall: (handler) => handler,
    HttpsError: FakeHttpsError,
  });
}

let operationSequence = 0;

function invoke(handler, {
  uid,
  command,
  payload = {},
}) {
  operationSequence += 1;
  return handler({
    auth: {uid},
    data: {
      schemaVersion: 3,
      command,
      operationId: `partial-flow-operation-${operationSequence}`,
      orderId: "order-one",
      payload,
      actor: {},
    },
  });
}

test("partial offer creates no reservation until the user accepts", async () => {
  const database = buildDatabase();
  const handler = buildHandler(database);
  const items = [
    {medicineId: "medicine-a", quantity: 2, soldByPiece: false},
  ];

  const offered = await invoke(handler, {
    uid: "pharmacy-one",
    command: "createPartialOffer",
    payload: {items},
  });

  assert.equal(offered.result.status, "partialOfferPending");
  assert.deepEqual(database.read("orders/order-one").partialOffer.quote, {
    currency: "LYD",
    items: [{medicineId: "medicine-a", soldByPiece: false,
      quantity: 2, unitPrice: 10, lineTotal: 20}],
    grossTotal: 20, insuranceShare: 0, customerTotal: 20,
  });
  assert.equal(database.read("orders/order-one").offerVersion, 1);
  assert.equal(
    database.read("pharmacies/pharmacy-one/medicines/medicine-a")
      .reservedQuantity,
    0,
  );
  assert.equal(database.paths("orders/order-one/reservations/").length, 0);

  const accepted = await invoke(handler, {
    uid: "user-one",
    command: "acceptPartialOffer",
    payload: {offerVersion: 1},
  });

  const order = database.read("orders/order-one");
  assert.equal(accepted.result.status, "confirmedReserved");
  assert.equal(order.acceptedOfferVersion, 1);
  assert.equal(order.estimatedTotalPrice, 20);
  assert.equal(order.totalItemsCount, 2);
  assert.equal(order.reservationState, "active");
  assert.equal(
    database.read("pharmacies/pharmacy-one/medicines/medicine-a")
      .reservedQuantity,
    2,
  );
  const reservation = database.read(
    "orders/order-one/reservations/order-order-one",
  );
  assert.equal(reservation.state, "active");
  assert.deepEqual(reservation.items, items);
});

test("a changed stock price requires a new offer before the user accepts", async () => {
  const database = buildDatabase();
  const handler = buildHandler(database);
  await invoke(handler, {uid: "pharmacy-one", command: "createPartialOffer",
    payload: {items: [{medicineId: "medicine-a", quantity: 2, soldByPiece: false}]}});
  const stockPath = "pharmacies/pharmacy-one/medicines/medicine-a";
  database.write(stockPath, {...database.read(stockPath), sellingPrice: 12});
  await assert.rejects(invoke(handler, {uid: "user-one", command: "acceptPartialOffer",
    payload: {offerVersion: 1}}), {code: "aborted", message: /stale-offer-price/});
  assert.equal(database.read("orders/order-one").status, "partialOfferPending");
  assert.equal(database.paths("orders/order-one/reservations/").length, 0);
});

test("insured offer quotes the current unit price and customer share", async () => {
  const database = buildDatabase();
  database.write("orders/order-one", {...database.read("orders/order-one"),
    insurance: {enabled: true}, insuranceSelection: {coveragePercentage: 25}});
  await invoke(buildHandler(database), {uid: "pharmacy-one", command: "createPartialOffer",
    payload: {items: [{medicineId: "medicine-a", quantity: 2, soldByPiece: false}]}});
  const quote = database.read("orders/order-one").partialOffer.quote;
  assert.equal(quote.grossTotal, 20);
  assert.equal(quote.insuranceShare, 5);
  assert.equal(quote.customerTotal, 15);
});

test("unpriced inventory cannot be offered as a priced medicine", async () => {
  const database = buildDatabase({medicines: {"medicine-a": {sellingPrice: null, piecePrice: null}}});
  await assert.rejects(invoke(buildHandler(database), {uid: "pharmacy-one", command: "createPartialOffer",
    payload: {items: [{medicineId: "medicine-a", quantity: 1, soldByPiece: false}]}}),
  {code: "failed-precondition"});
  assert.equal(database.read("orders/order-one").status, "underReview");
});

test("pharmacy cannot publish a partial offer that is already unavailable", async () => {
  const database = buildDatabase({
    medicines: {
      "medicine-a": {quantity: 3, reservedQuantity: 2},
    },
  });
  const handler = buildHandler(database);
  const before = [...database.documents.entries()];

  await assert.rejects(
    invoke(handler, {
      uid: "pharmacy-one",
      command: "createPartialOffer",
      payload: {
        items: [
          {medicineId: "medicine-a", quantity: 2, soldByPiece: false},
        ],
      },
    }),
    {code: "failed-precondition"},
  );

  assert.deepEqual([...database.documents.entries()], before);
});

test("rejecting a partial offer cancels without reserving stock", async () => {
  const items = [{medicineId: "medicine-a", quantity: 2}];
  const database = buildDatabase({
    status: "partialOfferPending",
    offerVersion: 1,
    partialOffer: {version: 1, items},
  });
  const handler = buildHandler(database);

  const rejected = await invoke(handler, {
    uid: "user-one",
    command: "rejectPartialOffer",
    payload: {offerVersion: 1},
  });

  assert.equal(rejected.result.status, "cancelled");
  assert.equal(database.read("orders/order-one").reservationId, null);
  assert.equal(
    database.read("pharmacies/pharmacy-one/medicines/medicine-a")
      .reservedQuantity,
    0,
  );
  assert.equal(database.paths("orders/order-one/reservations/").length, 0);
});

test("accepting a stale offer version changes nothing", async () => {
  const items = [{medicineId: "medicine-a", quantity: 2}];
  const database = buildDatabase({
    status: "partialOfferPending",
    offerVersion: 2,
    partialOffer: {version: 2, items},
  });
  const handler = buildHandler(database);

  await assert.rejects(
    invoke(handler, {
      uid: "user-one",
      command: "acceptPartialOffer",
      payload: {offerVersion: 1},
    }),
    {code: "aborted"},
  );

  assert.equal(database.read("orders/order-one").status, "partialOfferPending");
  assert.equal(
    database.read("pharmacies/pharmacy-one/medicines/medicine-a")
      .reservedQuantity,
    0,
  );
  assert.equal(database.paths("orders/order-one/reservations/").length, 0);
});

test("insufficient stock rolls back every partial-offer reservation", async () => {
  const items = [
    {medicineId: "medicine-a", quantity: 2},
    {medicineId: "medicine-b", quantity: 2},
  ];
  const database = buildDatabase({
    status: "partialOfferPending",
    offerVersion: 1,
    partialOffer: {version: 1, items},
    medicines: {
      "medicine-a": {quantity: 10, reservedQuantity: 0},
      "medicine-b": {quantity: 1, reservedQuantity: 0},
    },
  });
  const handler = buildHandler(database);

  await assert.rejects(
    invoke(handler, {
      uid: "user-one",
      command: "acceptPartialOffer",
      payload: {offerVersion: 1},
    }),
    {code: "failed-precondition"},
  );

  assert.equal(database.read("orders/order-one").status, "partialOfferPending");
  assert.equal(
    database.read("pharmacies/pharmacy-one/medicines/medicine-a")
      .reservedQuantity,
    0,
  );
  assert.equal(
    database.read("pharmacies/pharmacy-one/medicines/medicine-b")
      .reservedQuantity,
    0,
  );
  assert.equal(database.paths("orders/order-one/reservations/").length, 0);
});

test("an unrelated user cannot decide on a partial offer", async () => {
  const items = [{medicineId: "medicine-a", quantity: 2}];
  const database = buildDatabase({
    status: "partialOfferPending",
    offerVersion: 1,
    partialOffer: {version: 1, items},
  });
  const handler = buildHandler(database);

  await assert.rejects(
    invoke(handler, {
      uid: "user-two",
      command: "acceptPartialOffer",
      payload: {offerVersion: 1},
    }),
    {code: "permission-denied"},
  );

  assert.equal(database.read("orders/order-one").status, "partialOfferPending");
  assert.equal(database.paths("orders/order-one/reservations/").length, 0);
});
