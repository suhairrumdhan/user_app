"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {buildOrderCommandHandler} = require("../../src/domain/order-commands");
const {FakeFirestore} = require("./helpers/fake-firestore");

class HttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function fixture() {
  const data = {
    "pharmacies/pharmacy": {status: "approved", isActive: true, isOnline: true, acceptedInsuranceCodes: ["C1"]},
    "pharmacies/pharmacy/insurance_companies/company": {
      code: "C1", status: "فعال", name: "Test insurance", discountPercentage: 70,
      contractStartDate: "2020-01-01", contractEndDate: "2099-01-01",
    },
    "users/user/insurances/card": {
      companyCode: "C1", policyNumber: "CARD", cardNumber: "CARD",
      beneficiaryId: "self", beneficiaryType: "self",
      startDate: "2020-01-01", endDate: "2099-01-01", coveredMemberIds: ["self"],
    },
    "users/user/familyMembers/child": {name: "Child"},
  };
  const order = {
    user: {userId: "user", name: "User"},
    pharmacy: {pharmacyId: "pharmacy"},
    beneficiary: {beneficiaryId: "user", ownerUserId: "user", type: "self"},
    insurance: {
      enabled: true, beneficiaryId: "self", insuranceDocumentId: "card",
      companyCode: "C1", companyCodes: ["C1"], companyNames: ["Test insurance"],
      policyNumber: "CARD", cardNumbers: ["CARD"],
    },
    estimatedTotalPrice: 100,
    medicines: [
      {matchedMedicineId: "medicine", quantity: 1, soldByPiece: true},
      {matchedMedicineId: "medicine", quantity: 1, soldByPiece: true},
    ],
  };
  return {data, order};
}

async function create(data, order) {
  const db = new FakeFirestore(data);
  const handler = buildOrderCommandHandler({db, onCall: (fn) => fn, HttpsError});
  const request = {auth: {uid: "user"}, data: {
    schemaVersion: 3, command: "createOrder", operationId: "create-insured-order",
    payload: {order},
  }};
  const first = await handler(request);
  assert.deepEqual(await handler(request), first);
  return {db, handler, orderId: first.result.orderId, order: db.read(`orders/${first.result.orderId}`)};
}

test("owned active insurance resolves coverage and duplicate medicine becomes one line quantity two", async () => {
  const {data, order} = fixture();
  const result = await create(data, order);
  assert.equal(result.order.status, "underReview");
  assert.equal(result.order.insuranceSelection.companyId, "company");
  assert.equal(result.order.insuranceSelection.beneficiaryId, "self");
  assert.equal(result.order.insuranceSelection.policyNumber, "CARD");
  assert.equal(result.order.grossEstimatedTotalPrice, 100);
  assert.equal(result.order.insuranceEstimatedShare, 70);
  assert.equal(result.order.customerEstimatedTotalPrice, 30);
  assert.equal(result.order.estimatedTotalPrice, 30);
  assert.equal(result.order.medicines.length, 1);
  assert.equal(result.order.medicines[0].quantity, 2);
  assert.equal(result.order.reservationId, null);
  assert.equal(result.db.paths("orders/").length, 1);
});

test("a family beneficiary resolves only its own policy document", async () => {
  const {data, order} = fixture();
  order.beneficiary.type = "family";
  order.beneficiary.familyMemberId = "child";
  order.insurance.beneficiaryId = "child";
  order.insurance.insuranceDocumentId = "child";
  order.insurance.policyNumber = "CHILD-POLICY";
  order.insurance.cardNumbers = ["CHILD-POLICY"];
  delete data["users/user/insurances/card"];
  data["users/user/insurances/child"] = {
    companyCode: "C1", policyNumber: "CHILD-POLICY",
    beneficiaryId: "child", beneficiaryType: "family",
    startDate: "2020-01-01", endDate: "2099-01-01",
    coveredMemberIds: ["child"],
  };
  const result = await create(data, order);
  assert.equal(result.order.status, "underReview");
  assert.equal(result.order.insuranceSelection.beneficiaryId, "child");
  assert.equal(result.order.insuranceSelection.cardId, "child");
  assert.equal(result.order.insuranceSelection.policyNumber, "CHILD-POLICY");
});

for (const variant of ["inactive company", "expired company", "expired card", "different card", "uncovered child"]) {
  test(`${variant} waits for an explicit uninsured decision`, async () => {
    const {data, order} = fixture();
    if (variant === "inactive company") data["pharmacies/pharmacy/insurance_companies/company"].status = "غير فعال";
    if (variant === "expired company") data["pharmacies/pharmacy/insurance_companies/company"].contractEndDate = "2020-01-01";
    if (variant === "expired card") data["users/user/insurances/card"].endDate = "2020-01-01";
    if (variant === "different card") order.insurance.policyNumber = "SOMEONE-ELSE";
    if (variant === "uncovered child") {
      order.beneficiary.type = "family";
      order.beneficiary.familyMemberId = "child";
      order.insurance.beneficiaryId = "child";
    }
    const result = await create(data, order);
    assert.equal(result.order.status, "received");
    assert.equal(result.order.reviewStartedAt, null);
    assert.equal(result.order.insuranceSelection, null);
    await result.handler({auth: {uid: "user"}, data: {
      schemaVersion: 3, command: "continueWithoutInsurance", operationId: "continue-no-insurance",
      orderId: result.orderId, payload: {},
    }});
    const updated = result.db.read(`orders/${result.orderId}`);
    assert.equal(updated.status, "underReview");
    assert.equal(updated.insurance.enabled, false);
    assert.equal(updated.containsInsurance, false);
    assert.equal(updated.requestedInsurance.enabled, true);
  });
}

test("pharmacy that stopped accepting requests rejects creation", async () => {
  const {data, order} = fixture();
  data["pharmacies/pharmacy"].isOnline = false;
  await assert.rejects(create(data, order), {code: "failed-precondition"});
});

for (const [name, patch] of Object.entries({
  hidden: {isBlocked: true}, inactive: {isActive: false}, unapproved: {status: "pending"},
  missingApproval: {status: undefined}, missingReceiving: {isOnline: undefined},
})) {
  test(`${name} pharmacy rejects a new order from a saved search result`, async () => {
    const {data, order} = fixture();
    Object.assign(data["pharmacies/pharmacy"], patch);
    await assert.rejects(create(data, order), {code: "failed-precondition"});
  });
}

for (const [name, patch] of Object.entries({hidden: {isBlocked: true}, stopped: {isOnline: false}})) {
  test(`${name} pharmacy can continue an existing order without creating a duplicate`, async () => {
    const {data, order} = fixture();
    data["pharmacies/pharmacy/medicines/medicine"] = {
      quantity: 2, sellingPrice: 10, unitsPerPackage: 10, pieceQuantity: 0, reservedQuantity: 0,
      reservedPieceQuantity: 0, sellByPiece: true, isActive: true,
      expiryDate: "2099-01-01T00:00:00Z",
    };
    const result = await create(data, order);
    result.db.write("pharmacies/pharmacy", {...data["pharmacies/pharmacy"], ...patch});
    const replay = await result.handler({auth: {uid: "user"}, data: {
      schemaVersion: 3, command: "createOrder", operationId: "create-insured-order", payload: {order},
    }});
    assert.equal(replay.result.orderId, result.orderId);
    assert.equal(result.db.paths("orders/").length, 1);
    await assert.rejects(result.handler({auth: {uid: "user"}, data: {
      schemaVersion: 3, command: "createOrder", operationId: "new-order-after-switch", payload: {order},
    }}), {code: "failed-precondition"});
    await result.handler({auth: {uid: "pharmacy"}, data: {
      schemaVersion: 3, command: "confirmFullOrder", operationId: "confirm-after-switch",
      orderId: result.orderId, payload: {}, actor: {},
    }});
    assert.equal(result.db.read(`orders/${result.orderId}`).status, "confirmedReserved");
    assert.equal(result.db.read("pharmacies/pharmacy/medicines/medicine").reservedPieceQuantity, 2);
    await result.handler({auth: {uid: "user"}, data: {
      schemaVersion: 3, command: "cancelOrder", operationId: "cancel-after-switch",
      orderId: result.orderId, payload: {},
    }});
    assert.equal(result.db.read("pharmacies/pharmacy/medicines/medicine").reservedPieceQuantity, 0);
  });
}

for (const scenario of ["user", "pharmacy", "both"]) {
  test(`coverage failure identifies ${scenario} expiry independently`, async () => {
    const {data, order} = fixture();
    if (scenario !== "pharmacy") data["users/user/insurances/card"].endDate = "2020-01-01";
    if (scenario !== "user") data["pharmacies/pharmacy/insurance_companies/company"].contractEndDate = "2020-01-01";
    const result = await create(data, order);
    assert.equal(result.order.status, "received");
    const reasons = result.order.insuranceResolution.reasons;
    assert.equal(reasons.some((r) => r.code === "card-expired"), scenario !== "pharmacy");
    assert.equal(reasons.some((r) => r.code === "company-contract-expired"), scenario !== "user");
    assert.equal(result.order.insuranceResolution.resolved, false);
  });
}
