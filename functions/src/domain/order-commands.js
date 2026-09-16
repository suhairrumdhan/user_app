"use strict";

const {pharmacyAcceptsNewOrders, medicineSaleState} = require("./availability-policy");

const {
  ORDER_SCHEMA_VERSION,
  ORDER_STATUS,
  OrderContractError,
  assertCurrentOfferVersion,
  assertTransition,
  buildReadyTiming,
  hasTrustedInvoice,
  parseOrderStatus,
  statusLabel,
} = require("./order-contract");
const {
  executeIdempotentTransaction,
} = require("../common/idempotency");
const {Timestamp} = require("firebase-admin/firestore");
const {stockUnits, reserveUnits, consumeUnits} = require("./stock-units");
const {refundDeliveredOrder, collectInsurancePayment} = require("./order-ledger");
const {readCanonicalOrderInvoice} = require("./order-invoice");
const {employeeClaims, resolveEmployeePrincipal} = require("../auth/authorization");

const COMMAND_TARGET = Object.freeze({
  cancelOrder: ORDER_STATUS.CANCELLED,
  continueWithoutInsurance: ORDER_STATUS.UNDER_REVIEW,
  confirmFullOrder: ORDER_STATUS.CONFIRMED_RESERVED,
  createPartialOffer: ORDER_STATUS.PARTIAL_OFFER_PENDING,
  revisePartialOffer: ORDER_STATUS.PARTIAL_OFFER_PENDING,
  acceptPartialOffer: ORDER_STATUS.CONFIRMED_RESERVED,
  rejectPartialOffer: ORDER_STATUS.CANCELLED,
  rejectOrder: ORDER_STATUS.REJECTED,
  startPreparing: ORDER_STATUS.PREPARING,
  markReady: ORDER_STATUS.READY,
  completeOrder: ORDER_STATUS.COMPLETED,
  cancelAfterInvoice: ORDER_STATUS.CANCELLED,
  markNotCollected: ORDER_STATUS.NOT_COLLECTED,
});

function cleanText(value) {
  return String(value ?? "").trim();
}

function requiredText(value, name) {
  const result = cleanText(value);
  if (!result) {
    throw new OrderContractError("invalid-argument", `${name} is required.`);
  }
  return result;
}

function positiveInteger(value, name) {
  const result = Number(value);
  if (!Number.isInteger(result) || result <= 0) {
    throw new OrderContractError("invalid-argument", `${name} must be positive.`);
  }
  return result;
}

function toMillis(value) {
  if (!value) return null;
  if (typeof value.toMillis === "function") return value.toMillis();
  const millis = new Date(value).getTime();
  return Number.isFinite(millis) ? millis : null;
}

function canonicalCommandPayload(data) {
  return {
    schemaVersion: Number(data.schemaVersion),
    command: cleanText(data.command),
    orderId: cleanText(data.orderId) || null,
    payload: data.payload && typeof data.payload === "object" ? data.payload : {},
    // Actor identity is derived exclusively from the verified Firebase token.
    actor: {},
  };
}

function safeOrderInput(raw) {
  const order = raw && typeof raw === "object" ? raw : {};
  const user = order.user && typeof order.user === "object" ? order.user : {};
  const pharmacy = order.pharmacy && typeof order.pharmacy === "object" ?
    order.pharmacy : {};
  const beneficiary = order.beneficiary && typeof order.beneficiary === "object" ?
    order.beneficiary : {};
  const insurance = order.insurance && typeof order.insurance === "object" ?
    order.insurance : {};
  const lines = Array.isArray(order.medicines) ? order.medicines.map((item) => ({
    requestedName: cleanText(item?.requestedName),
    normalizedName: cleanText(item?.normalizedName),
    strength: cleanText(item?.strength) || null,
    dosageForm: cleanText(item?.dosageForm) || null,
    quantity: positiveInteger(item?.quantity, "medicine.quantity"),
    note: cleanText(item?.note) || null,
    matchedMedicineId: requiredText(item?.matchedMedicineId, "matchedMedicineId"),
    matchedMedicineName: cleanText(item?.matchedMedicineName),
    estimatedPrice: Number(item?.estimatedPrice || 0),
    availableAtSelection: item?.availableAtSelection === true,
    soldByPiece: item?.soldByPiece === true,
    unit: cleanText(item?.unit) || null,
    imageUrl: cleanText(item?.imageUrl) || null,
  })) : [];
  const grouped = new Map();
  for (const item of lines) {
    const key = `${item.matchedMedicineId}:${item.soldByPiece}`;
    const previous = grouped.get(key);
    grouped.set(key, {...item, quantity: positiveInteger(
      (previous?.quantity || 0) + item.quantity, "medicine.quantity",
    )});
  }
  const medicines = [...grouped.values()];
  if (medicines.length === 0) {
    throw new OrderContractError("invalid-argument", "At least one medicine is required.");
  }
  return {
    user: {
      userId: requiredText(user.userId, "user.userId"),
      name: cleanText(user.name),
      phone: cleanText(user.phone) || null,
      email: cleanText(user.email) || null,
      profileImageUrl: cleanText(user.profileImageUrl) || null,
    },
    pharmacy: {
      pharmacyId: requiredText(pharmacy.pharmacyId, "pharmacy.pharmacyId"),
      pharmacyName: cleanText(pharmacy.pharmacyName),
      phoneNumber: cleanText(pharmacy.phoneNumber) || null,
      imageUrl: cleanText(pharmacy.imageUrl) || null,
      address: cleanText(pharmacy.address) || null,
    },
    beneficiary: {
      beneficiaryId: requiredText(beneficiary.beneficiaryId, "beneficiaryId"),
      ownerUserId: requiredText(beneficiary.ownerUserId, "beneficiary.ownerUserId"),
      type: cleanText(beneficiary.type) === "family" ? "family" : "self",
      name: cleanText(beneficiary.name),
      relationLabel: cleanText(beneficiary.relationLabel) || null,
      familyMemberId: cleanText(beneficiary.familyMemberId) || null,
      gender: cleanText(beneficiary.gender) || null,
      bloodType: cleanText(beneficiary.bloodType) || null,
      age: Number.isInteger(Number(beneficiary.age)) ? Number(beneficiary.age) : null,
      dateOfBirth: beneficiary.dateOfBirth || null,
      allergies: Array.isArray(beneficiary.allergies) ? beneficiary.allergies : [],
      healthConditions: Array.isArray(beneficiary.healthConditions) ? beneficiary.healthConditions : [],
      currentMedications: Array.isArray(beneficiary.currentMedications) ? beneficiary.currentMedications : [],
      hasHealthData: beneficiary.hasHealthData === true,
    },
    insurance: {
      enabled: insurance.enabled === true,
      companyCodes: Array.isArray(insurance.companyCodes) ?
        insurance.companyCodes.map((x) => cleanText(x).toUpperCase()).filter(Boolean) : [],
      companyNames: Array.isArray(insurance.companyNames) ? insurance.companyNames : [],
      cardNumbers: Array.isArray(insurance.cardNumbers) ? insurance.cardNumbers : [],
    },
    requestSource: cleanText(order.requestSource) === "prescription" ?
      "prescription" : "manual",
    requestSourceLabel: cleanText(order.requestSourceLabel),
    medicines,
    userNote: cleanText(order.userNote) || null,
    chatId: cleanText(order.chatId) || null,
    totalItemsCount: medicines.reduce((sum, item) => sum + item.quantity, 0),
    estimatedTotalPrice: Number(order.estimatedTotalPrice || 0),
    hasSensitiveHealthData: order.hasSensitiveHealthData === true,
    containsInsurance: insurance.enabled === true && Array.isArray(insurance.companyCodes) && insurance.companyCodes.length > 0,
    prescriptionId: cleanText(order.prescriptionId) || null,
    prescriptionImageUrl: cleanText(order.prescriptionImageUrl) || null,
    prescriptionText: cleanText(order.prescriptionText) || null,
    metadata: order.metadata && typeof order.metadata === "object" ? order.metadata : {},
  };
}

function dateKey(timestamp) {
  const date = timestamp.toDate();
  return `${String(date.getUTCFullYear()).slice(-2)}` +
    `${String(date.getUTCMonth() + 1).padStart(2, "0")}` +
    `${String(date.getUTCDate()).padStart(2, "0")}`;
}

function historyEntry(status, actor, command, timestamp, note = null) {
  return {
    status,
    label: statusLabel(status),
    changedById: actor.id,
    changedByType: actor.type,
    command,
    note: cleanText(note) || null,
    changedAt: timestamp,
  };
}

async function resolveInsurance({transaction, db, order, pharmacy, timestamp}) {
  if (!order.insurance.enabled) return {resolved: true, selection: null};
  const accepted = new Set(
    (Array.isArray(pharmacy.acceptedInsuranceCodes) ?
      pharmacy.acceptedInsuranceCodes : [])
      .map((code) => cleanText(code).toUpperCase()),
  );
  const [companies, cards] = await Promise.all([
    transaction.get(db.collection("pharmacies").doc(order.pharmacy.pharmacyId)
      .collection("insurance_companies")),
    transaction.get(db.collection("users").doc(order.user.userId).collection("insurances")),
  ]);
  const instant = timestamp.toMillis();
  for (const code of order.insurance.companyCodes) {
    if (!accepted.has(code)) continue;
    const card = cards.docs.find((doc) => {
      const data = doc.data();
      const start = toMillis(data.startDate);
      const end = toMillis(data.endDate);
      return data.isActive !== false && cleanText(data.companyCode).toUpperCase() === code &&
        order.insurance.cardNumbers.includes(cleanText(data.cardNumber)) &&
        start !== null && end !== null && start <= instant && end >= instant &&
        (order.beneficiary.type === "self" ||
          (Array.isArray(data.coveredMemberIds) &&
            data.coveredMemberIds.includes(order.beneficiary.familyMemberId)));
    });
    const company = companies.docs.find((doc) => {
      const data = doc.data();
      return cleanText(data.code).toUpperCase() === code && activeInsuranceCompany(data, instant);
    });
    if (card && company) return {resolved: true, selection: {
      companyId: company.id, companyCode: code, companyName: cleanText(company.data().name),
      cardId: card.id, cardNumber: cleanText(card.data().cardNumber),
    }};
  }
  return {resolved: false, selection: null};
}

function activeInsuranceCompany(company, instant) {
  const start = toMillis(company.contractStartDate);
  const end = toMillis(company.contractEndDate);
  return ["فعال", "active"].includes(cleanText(company.status)) &&
    company.isActive !== false && (start === null || start <= instant) &&
    (end === null || end >= instant);
}

function commandError(error, HttpsError) {
  if (error instanceof HttpsError) return error;
  const mapping = {
    "invalid-argument": "invalid-argument",
    "unknown-order-status": "failed-precondition",
    "invalid-order-transition": "failed-precondition",
    "terminal-order": "failed-precondition",
    "stale-offer-version": "aborted",
    "idempotency-conflict": "already-exists",
    "not-found": "not-found",
    "permission-denied": "permission-denied",
    "failed-precondition": "failed-precondition",
  };
  return new HttpsError(mapping[error.code] || "internal", error.message, error.details);
}

function employeeCanUpdate(employee, permission = "orders.update_status") {
  if (!employee || employee.isActive !== true) return false;
  if (typeof employee.permissionOverrides?.[permission] === "boolean") {
    return employee.permissionOverrides[permission];
  }
  if (["admin", "manager", "owner"].includes(cleanText(employee.roleId).toLowerCase())) {
    return true;
  }
  return employee.permissions?.[permission] === true;
}

async function resolveCommandPrincipal({db, auth, instant}) {
  const uid = cleanText(auth?.uid);
  if (!uid) throw new OrderContractError("permission-denied", "Authentication is required.");
  if (!employeeClaims(auth)) {
    return {type: "account", actorId: uid, actorUid: uid};
  }
  try {
    const principal = await resolveEmployeePrincipal({db, auth, instant});
    return {...principal, auth};
  } catch (_) {
    throw new OrderContractError("permission-denied", "Employee session is unavailable.");
  }
}

async function resolveActor({transaction, db, order, principal, command, instant}) {
  const userId = cleanText(order.user?.userId || order.userId);
  const pharmacyId = cleanText(order.pharmacy?.pharmacyId || order.pharmacyId);
  if (principal.type === "account" && principal.actorUid === userId) {
    return {type: "user", id: principal.actorUid};
  }
  if (principal.type === "account") {
    if (principal.actorUid !== pharmacyId) {
      throw new OrderContractError("permission-denied", "Caller is not related to this order.");
    }
    if (command === "markNotCollected") {
      throw new OrderContractError(
        "permission-denied",
        "An authorized employee is required for not-collected orders.",
      );
    }
    return {type: "pharmacy", id: principal.actorUid, employeeId: null};
  }
  if (principal.pharmacyId !== pharmacyId) {
    throw new OrderContractError("permission-denied", "Employee session belongs to another pharmacy.");
  }
  const permission = command === "refundOrder" ? "sales.refund" :
    (command === "collectInsurancePayment" ? "insurance.collect" : "orders.update_status");
  try {
    await resolveEmployeePrincipal({
      db, auth: principal.auth, pharmacyId, permission, instant, transaction,
    });
  } catch (_) {
    throw new OrderContractError("permission-denied", "Employee cannot update orders.");
  }
  return {type: "pharmacy", id: principal.employeeId, employeeId: principal.employeeId};
}

function reservationItems(order, partialOffer = null) {
  const source = partialOffer?.items || order.medicines || [];
  const aggregated = new Map();
  for (const item of source) {
    const medicineId = requiredText(
      item.medicineId || item.matchedMedicineId,
      "reservation medicineId",
    );
    const quantity = positiveInteger(item.quantity, "reservation quantity");
    const soldByPiece = item.soldByPiece === true;
    const key = `${soldByPiece ? "piece" : "pack"}:${medicineId}`;
    const previous = aggregated.get(key);
    aggregated.set(key, {
      medicineId,
      quantity: Number(previous?.quantity || 0) + quantity,
      soldByPiece,
    });
  }
  return [...aggregated.values()];
}

function stockDemands(items) {
  const grouped = new Map();
  for (const item of items) {
    const demand = grouped.get(item.medicineId) ||
      {medicineId: item.medicineId, packages: 0, pieces: 0};
    demand[item.soldByPiece ? "pieces" : "packages"] += item.quantity;
    grouped.set(item.medicineId, demand);
  }
  return [...grouped.values()];
}

// A partial offer is only a promise of what the pharmacy can supply; it must
// not reserve stock before the user consents. Still validate the promise
// against live, unreserved stock so the pharmacy cannot knowingly publish an
// already-impossible offer. Acceptance repeats the same check transactionally
// because another order may win the stock in the meantime.
async function assertStockAvailable({transaction, db, order, items, releaseCurrent = false, timestamp}) {
  const pharmacyId = requiredText(order.pharmacy?.pharmacyId, "pharmacyId");
  let releasedDemands = new Map();
  if (releaseCurrent) {
    const reservationId = requiredText(order.reservationId, "reservationId");
    const reservationRef = db.collection("orders").doc(order.orderId)
      .collection("reservations").doc(reservationId);
    const reservationSnapshot = await transaction.get(reservationRef);
    if (!reservationSnapshot.exists || reservationSnapshot.data().state !== "active") {
      throw new OrderContractError("failed-precondition", "Active reservation not found.");
    }
    releasedDemands = new Map(stockDemands(reservationSnapshot.data().items || [])
      .map((item) => [item.medicineId, item]));
  }

  const reads = await Promise.all(stockDemands(items).map(async (item) => {
    const ref = db.collection("pharmacies").doc(pharmacyId)
      .collection("medicines").doc(item.medicineId);
    return {item, snapshot: await transaction.get(ref)};
  }));
  for (const {item, snapshot} of reads) {
    if (!snapshot.exists) {
      throw new OrderContractError("failed-precondition", `Medicine ${item.medicineId} is missing.`);
    }
    const medicine = snapshot.data() || {};
    if (!medicineSaleState(medicine, timestamp.toMillis()).saleable) {
      throw new OrderContractError("failed-precondition", `Medicine ${item.medicineId} is inactive or expired.`);
    }
    const released = releasedDemands.get(item.medicineId) || {packages: 0, pieces: 0};
    const reservedQuantity = Number(medicine.reservedQuantity || 0) - released.packages;
    const reservedPieceQuantity = Number(medicine.reservedPieceQuantity || 0) - released.pieces;
    if (!Number.isSafeInteger(reservedQuantity) || reservedQuantity < 0 ||
        !Number.isSafeInteger(reservedPieceQuantity) || reservedPieceQuantity < 0) {
      throw new OrderContractError("failed-precondition", "Reservation counters are inconsistent.");
    }
    reserveUnits({...medicine, reservedQuantity, reservedPieceQuantity}, item.packages, item.pieces);
  }
}

async function reserveStock({transaction, db, order, items, timestamp}) {
  const pharmacyId = requiredText(order.pharmacy?.pharmacyId, "pharmacyId");
  const reads = await Promise.all(stockDemands(items).map(async (item) => {
    const ref = db.collection("pharmacies").doc(pharmacyId)
      .collection("medicines").doc(item.medicineId);
    return {item, ref, snapshot: await transaction.get(ref)};
  }));
  for (const {item, ref, snapshot} of reads) {
    if (!snapshot.exists) {
      throw new OrderContractError("failed-precondition", `Medicine ${item.medicineId} is missing.`);
    }
    const medicine = snapshot.data() || {};
    if (!medicineSaleState(medicine, timestamp.toMillis()).saleable) {
      throw new OrderContractError("failed-precondition", `Medicine ${item.medicineId} is inactive or expired.`);
    }
    transaction.update(ref, {
      ...reserveUnits(medicine, item.packages, item.pieces),
      reservationUpdatedAt: timestamp,
    });
  }
  // A new consent cycle must not overwrite its earlier released reservation.
  const reservationId = order.reservationId ?
    `order-${order.orderId}-offer-${order.offerVersion}` : `order-${order.orderId}`;
  const reservationRef = db.collection("orders").doc(order.orderId)
    .collection("reservations").doc(reservationId);
  transaction.create(reservationRef, {
    schemaVersion: ORDER_SCHEMA_VERSION,
    reservationId,
    orderId: order.orderId,
    pharmacyId,
    items,
    state: "active",
    reservedAt: timestamp,
  });
  return reservationId;
}

async function changeReservationState({transaction, db, order, nextState, timestamp}) {
  const reservationId = requiredText(order.reservationId, "reservationId");
  const reservationRef = db.collection("orders").doc(order.orderId)
    .collection("reservations").doc(reservationId);
  const reservationSnapshot = await transaction.get(reservationRef);
  if (!reservationSnapshot.exists || reservationSnapshot.data().state !== "active") {
    throw new OrderContractError("failed-precondition", "Active reservation not found.");
  }
  const reservation = reservationSnapshot.data();
  const medicineReads = await Promise.all(reservation.items.map(async (item) => {
    const ref = db.collection("pharmacies").doc(order.pharmacy.pharmacyId)
      .collection("medicines").doc(item.medicineId);
    return {item, ref, snapshot: await transaction.get(ref)};
  }));
  for (const {item, ref, snapshot} of medicineReads) {
    if (!snapshot.exists) {
      throw new OrderContractError("failed-precondition", "Reserved medicine is missing.");
    }
    const data = snapshot.data();
    const field = item.soldByPiece ? "reservedPieceQuantity" : "reservedQuantity";
    const reserved = Number(data[field] || 0);
    if (!Number.isSafeInteger(reserved) || reserved < Number(item.quantity)) {
      throw new OrderContractError("failed-precondition", "Reservation counters are inconsistent.");
    }
    transaction.update(ref, {
      [field]: reserved - Number(item.quantity),
      reservationUpdatedAt: timestamp,
    });
  }
  transaction.update(reservationRef, {
    state: nextState,
    [`${nextState}At`]: timestamp,
  });
}

function nonNegativeNumber(value, name) {
  const result = Number(value || 0);
  if (!Number.isFinite(result) || result < 0) {
    throw new OrderContractError("invalid-argument", `${name} must be non-negative.`);
  }
  return result;
}

function canonicalInvoiceInput(raw, order, actor, invoiceId, timestamp) {
  const invoice = raw && typeof raw === "object" ? raw : {};
  const items = Array.isArray(invoice.items) ? invoice.items.map((item) => ({
    medicineId: requiredText(item?.medicineId, "invoice item medicineId"),
    name: cleanText(item?.name),
    quantity: positiveInteger(item?.quantity, "invoice item quantity"),
    sellAsPiece: item?.sellAsPiece === true,
    unitPrice: nonNegativeNumber(item?.unitPrice, "invoice item unitPrice"),
    unitCost: nonNegativeNumber(item?.unitCost, "invoice item unitCost"),
    batchNumber: cleanText(item?.batchNumber) || null,
    expiryDate: item?.expiryDate || null,
    unitsPerPackageSnapshot: Number(item?.unitsPerPackageSnapshot || 0) || null,
    discountPercentage: nonNegativeNumber(
      item?.discountPercentage,
      "invoice item discountPercentage",
    ),
    discountAmount: nonNegativeNumber(item?.discountAmount, "invoice item discountAmount"),
  })) : [];
  if (items.length === 0) {
    throw new OrderContractError("invalid-argument", "Invoice items are required.");
  }
  const subtotal = nonNegativeNumber(invoice.subtotal, "invoice subtotal");
  const discount = nonNegativeNumber(invoice.discount, "invoice discount");
  const companyShare = nonNegativeNumber(
    invoice.insuranceDiscount,
    "invoice insuranceDiscount",
  );
  const customerShare = nonNegativeNumber(invoice.total, "invoice total");
  const itemNet = items.reduce((sum, item) => {
    const lineSubtotal = item.unitPrice * item.quantity;
    const percentageDiscount = Math.min(100, item.discountPercentage) / 100 * lineSubtotal;
    const lineDiscount = item.discountAmount > 0 ?
      Math.min(item.discountAmount, lineSubtotal) : percentageDiscount;
    return sum + lineSubtotal - lineDiscount;
  }, 0);
  if (Math.abs(itemNet - subtotal) > 0.01 ||
      discount > subtotal ||
      Math.abs((subtotal - discount) - (customerShare + companyShare)) > 0.01) {
    throw new OrderContractError("failed-precondition", "Invoice totals are inconsistent.");
  }
  if (companyShare > 0 && !cleanText(invoice.insuranceCompanyId)) {
    throw new OrderContractError(
      "failed-precondition",
      "Insurance company is required when the company share is positive.",
    );
  }
  const pharmacyId = requiredText(order.pharmacy?.pharmacyId, "pharmacyId");
  const shiftId = requiredText(invoice.shiftId, "invoice shiftId");
  return {
    customerName: cleanText(invoice.customerName) || null,
    customerPhone: cleanText(invoice.customerPhone) || null,
    notes: cleanText(invoice.notes) || null,
    insuranceCompanyId: cleanText(invoice.insuranceCompanyId) || null,
    insuranceCompanyName: cleanText(invoice.insuranceCompanyName) || null,
    schemaVersion: ORDER_SCHEMA_VERSION,
    invoiceId,
    invoiceNumber: cleanText(invoice.invoiceNumber) || invoiceId,
    pharmacyId,
    source: "order",
    sourceOrderId: order.orderId,
    orderId: order.orderId,
    orderNumber: cleanText(order.orderNumber) || null,
    items,
    subtotal,
    discount,
    insuranceDiscount: companyShare,
    total: customerShare,
    customerShare,
    companyShare,
    paymentMethod: ["cash", "card"].includes(cleanText(invoice.paymentMethod)) ?
      cleanText(invoice.paymentMethod) : "cash",
    shiftId,
    creationShiftId: shiftId,
    employeeId: actor.employeeId || cleanText(invoice.employeeId) || null,
    employeeName: cleanText(invoice.employeeName) || null,
    status: "completed",
    type: "sale",
    isSaved: true,
    isDeleted: false,
    draft: false,
    inventoryPosted: true,
    reservationConsumed: true,
    paymentState: "pendingDelivery",
    paidAmount: 0,
    remainingAmount: customerShare,
    cashIn: 0,
    cardIn: 0,
    cashOut: 0,
    cardOut: 0,
    insuranceClaimAmount: companyShare,
    insuranceClaimStatus: companyShare > 0 ? "pendingDelivery" : "notApplicable",
    financialPosted: false,
    createdAt: timestamp,
    saleDate: timestamp,
    completedAt: timestamp,
    performedById: actor.id,
    performedBy: {id: actor.id, type: actor.type},
  };
}

function invoiceReservationKey(item) {
  return `${item.sellAsPiece === true || item.soldByPiece === true ? "piece" : "pack"}:` +
    requiredText(item.medicineId, "medicineId");
}

async function consumeReservationAndCreateInvoice({
  transaction,
  db,
  order,
  actor,
  invoiceId,
  invoiceInput,
  timestamp,
}) {
  const pharmacyId = requiredText(order.pharmacy?.pharmacyId, "pharmacyId");
  const reservationId = requiredText(order.reservationId, "reservationId");
  const reservationRef = db.collection("orders").doc(order.orderId)
    .collection("reservations").doc(reservationId);
  const invoiceRef = db.collection("pharmacies").doc(pharmacyId)
    .collection("sales").doc(invoiceId);
  const reservationSnapshot = await transaction.get(reservationRef);
  const invoiceSnapshot = await transaction.get(invoiceRef);
  if (!reservationSnapshot.exists || reservationSnapshot.data().state !== "active") {
    throw new OrderContractError("failed-precondition", "Active reservation not found.");
  }
  if (invoiceSnapshot.exists) {
    throw new OrderContractError("failed-precondition", "Invoice already exists.");
  }
  const invoice = canonicalInvoiceInput(invoiceInput, order, actor, invoiceId, timestamp);
  if (order.insurance?.enabled === true || invoice.companyShare > 0 || cleanText(invoice.insuranceCompanyId)) {
    if (order.insurance?.enabled !== true ||
        !cleanText(order.insuranceSelection?.companyId) ||
        cleanText(order.insuranceSelection?.companyId) !== cleanText(invoice.insuranceCompanyId)) {
      throw new OrderContractError("failed-precondition", "Invoice insurance must match the resolved order coverage.");
    }
    const companySnapshot = await transaction.get(db.collection("pharmacies").doc(pharmacyId)
      .collection("insurance_companies").doc(invoice.insuranceCompanyId));
    const company = companySnapshot.data();
    if (!companySnapshot.exists || !activeInsuranceCompany(company, timestamp.toMillis())) {
      throw new OrderContractError("failed-precondition", "Insurance company is no longer active.");
    }
    const selection = order.insuranceSelection;
    const cardId = cleanText(selection.cardId);
    if (!cardId) throw new OrderContractError("failed-precondition", "Resolved insurance card is missing.");
    const cardSnapshot = await transaction.get(db.collection("users").doc(order.user.userId)
      .collection("insurances").doc(cardId));
    const pharmacySnapshot = await transaction.get(db.collection("pharmacies").doc(pharmacyId));
    const card = cardSnapshot.data() || {};
    const code = cleanText(selection.companyCode).toUpperCase();
    const start = toMillis(card.startDate);
    const end = toMillis(card.endDate);
    const accepted = pharmacySnapshot.data()?.acceptedInsuranceCodes;
    const covered = order.beneficiary?.type === "self" ||
      (Array.isArray(card.coveredMemberIds) &&
        card.coveredMemberIds.includes(order.beneficiary?.familyMemberId));
    if (!cardSnapshot.exists || card.isActive === false || !code ||
        cleanText(card.companyCode).toUpperCase() !== code ||
        cleanText(company.code).toUpperCase() !== code ||
        cleanText(card.cardNumber) !== cleanText(selection.cardNumber) ||
        start === null || end === null || start > timestamp.toMillis() || end < timestamp.toMillis() ||
        !covered || !Array.isArray(accepted) || !accepted.some((value) => cleanText(value).toUpperCase() === code)) {
      throw new OrderContractError("failed-precondition", "Order insurance coverage is no longer valid. Renew coverage or cancel the order.");
    }
    const rate = nonNegativeNumber(company.discountPercentage, "insurance coverage percentage");
    if (rate > 100 || Math.abs(invoice.companyShare -
        Math.round((invoice.subtotal - invoice.discount) * rate) / 100) > 0.01) {
      throw new OrderContractError("failed-precondition", "Invoice insurance amount does not match current coverage.");
    }
    invoice.insuranceCoveragePercentage = rate;
  }
  const shiftRef = db.collection("pharmacies").doc(pharmacyId)
    .collection("shifts").doc(invoice.creationShiftId);
  const shiftSnapshot = await transaction.get(shiftRef);
  if (!shiftSnapshot.exists || cleanText(shiftSnapshot.data().status).toLowerCase() !== "open") {
    throw new OrderContractError("failed-precondition", "Invoice creation requires an open shift.");
  }
  const reservation = reservationSnapshot.data();
  const expected = new Map();
  for (const item of reservation.items || []) {
    expected.set(invoiceReservationKey(item), Number(item.quantity));
  }
  const offered = new Map();
  for (const item of invoice.items) {
    const key = invoiceReservationKey(item);
    offered.set(key, Number(offered.get(key) || 0) + Number(item.quantity));
  }
  if (expected.size !== offered.size ||
      [...expected].some(([key, quantity]) => offered.get(key) !== quantity)) {
    throw new OrderContractError(
      "failed-precondition",
      "Invoice items must exactly match the active reservation.",
    );
  }
  const medicineReads = await Promise.all(stockDemands(reservation.items || []).map(async (item) => {
    const ref = db.collection("pharmacies").doc(pharmacyId)
      .collection("medicines").doc(item.medicineId);
    return {item, ref, snapshot: await transaction.get(ref)};
  }));
  for (const {item, ref, snapshot} of medicineReads) {
    if (!snapshot.exists) {
      throw new OrderContractError("failed-precondition", "Reserved medicine is missing.");
    }
    const medicine = snapshot.data() || {};
    if (!medicineSaleState(medicine, timestamp.toMillis()).saleable) {
      throw new OrderContractError("failed-precondition", "Reserved medicine is inactive or expired.");
    }
    transaction.update(ref, {
      ...consumeUnits(medicine, item.packages, item.pieces),
      reservationUpdatedAt: timestamp,
      updatedAt: timestamp,
    });
  }
  transaction.update(reservationRef, {state: "consumed", consumedAt: timestamp});
  transaction.create(invoiceRef, invoice);
  return invoice;
}

async function reverseCanonicalInvoice({transaction, db, order, actor, reason, timestamp}) {
  const pharmacyId = requiredText(order.pharmacy?.pharmacyId, "pharmacyId");
  const {invoice, invoiceRef} = await readCanonicalOrderInvoice({
    transaction, db, order, paymentState: "pendingDelivery",
  });
  const items = Array.isArray(invoice.items) ? invoice.items : [];
  const restoreItems = new Map();
  for (const item of items) {
    const key = invoiceReservationKey(item);
    const previous = restoreItems.get(key);
    restoreItems.set(key, {
      medicineId: requiredText(item.medicineId, "medicineId"),
      sellAsPiece: item.sellAsPiece === true,
      quantity: Number(previous?.quantity || 0) + positiveInteger(
        item.quantity,
        "invoice item quantity",
      ),
    });
  }
  const medicineReads = await Promise.all([...restoreItems.values()].map(async (item) => {
    const ref = db.collection("pharmacies").doc(pharmacyId)
      .collection("medicines").doc(requiredText(item.medicineId, "medicineId"));
    return {item, ref, snapshot: await transaction.get(ref)};
  }));
  for (const {item, ref, snapshot} of medicineReads) {
    if (!snapshot.exists) {
      throw new OrderContractError("failed-precondition", "Invoice medicine is missing.");
    }
    const field = item.sellAsPiece === true ? "pieceQuantity" : "quantity";
    const medicine = snapshot.data();
    const expiry = toMillis(medicine.expiryDate);
    if (medicine.isActive === false || (medicine.expiryDate != null && expiry === null) ||
        (expiry !== null && expiry < timestamp.toMillis())) {
      const quarantineRef = db.collection("pharmacies").doc(pharmacyId)
        .collection("quarantinedReturns")
        .doc(`order-${order.orderId}-${item.medicineId}-${item.sellAsPiece ? "piece" : "pack"}`);
      transaction.create(quarantineRef, {
        orderId: order.orderId,
        invoiceId: order.invoiceId,
        medicineId: item.medicineId,
        quantity: item.quantity,
        soldByPiece: item.sellAsPiece,
        reason: "not-saleable-at-reversal",
        createdAt: timestamp,
        availableForSale: false,
      });
      continue;
    }
    const restored = stockUnits(medicine)[field] + item.quantity;
    stockUnits({...medicine, [field]: restored});
    transaction.update(ref, {
      [field]: restored,
      updatedAt: timestamp,
    });
  }
  const reversalId = `order-reversal-${order.orderId}`;
  const reversalRef = db.collection("pharmacies").doc(pharmacyId)
    .collection("sales").doc(reversalId);
  transaction.create(reversalRef, {
    schemaVersion: ORDER_SCHEMA_VERSION,
    id: reversalId,
    pharmacyId,
    type: "refund",
    status: "completed",
    source: "orderReversal",
    orderId: order.orderId,
    refSaleId: order.invoiceId,
    originalSaleId: order.invoiceId,
    refInvoiceNumber: cleanText(invoice.invoiceNumber) || order.invoiceId,
    items,
    total: 0,
    cashOut: 0,
    cardOut: 0,
    financialPosted: false,
    reason,
    createdAt: timestamp,
    completedAt: timestamp,
    performedById: actor.id,
  });
  transaction.update(invoiceRef, {
    paymentState: "reversedBeforeDelivery",
    status: "cancelled",
    reversedAt: timestamp,
    reversalId,
    reversalReason: reason,
    updatedAt: timestamp,
  });
  return {reversalId, invoice};
}

async function collectCanonicalInvoice({transaction, db, order, actor, shiftId, timestamp}) {
  const pharmacyId = requiredText(order.pharmacy?.pharmacyId, "pharmacyId");
  const {invoice, invoiceRef} = await readCanonicalOrderInvoice({
    transaction, db, order, paymentState: "pendingDelivery",
  });
  const shiftRef = db.collection("pharmacies").doc(pharmacyId)
    .collection("shifts").doc(requiredText(shiftId, "collectionShiftId"));
  const shiftSnapshot = await transaction.get(shiftRef);
  if (!shiftSnapshot.exists || cleanText(shiftSnapshot.data().status).toLowerCase() !== "open") {
    throw new OrderContractError("failed-precondition", "Collection requires an open shift.");
  }
  const customerShare = nonNegativeNumber(invoice.customerShare ?? invoice.total, "customer share");
  const companyShare = nonNegativeNumber(
    invoice.companyShare ?? invoice.insuranceDiscount,
    "company share",
  );
  const companyRef = companyShare > 0 ? db.collection("pharmacies").doc(pharmacyId)
    .collection("insurance_companies").doc(requiredText(invoice.insuranceCompanyId, "insuranceCompanyId")) : null;
  const companySnapshot = companyRef ? await transaction.get(companyRef) : null;
  if (companyRef && !companySnapshot.exists) {
    throw new OrderContractError("failed-precondition", "Insurance company is missing.");
  }
  const method = cleanText(invoice.paymentMethod) === "card" ? "card" : "cash";
  const customerTxId = `order-customer-${order.orderId}`;
  const insuranceTxId = `order-insurance-${order.orderId}`;
  if (customerShare > 0) {
    transaction.create(
      db.collection("pharmacies").doc(pharmacyId)
        .collection("financial_transactions").doc(customerTxId),
      {
        pharmacyId,
        type: "sale",
        accountType: "salesRevenue",
        direction: "inflow",
        amount: customerShare,
        transactionDate: timestamp,
        referenceId: order.invoiceId,
        referenceNumber: cleanText(invoice.invoiceNumber) || order.invoiceId,
        referenceCollection: "sales",
        paymentMethod: method,
        shiftId,
        createdBy: actor.id,
        title: "عملية بيع طلب",
        description: "تحصيل حصة المستخدم عند التسليم",
        metadata: {source: "order", orderId: order.orderId},
      },
    );
  }
  if (companyShare > 0) {
    const company = companySnapshot.data();
    transaction.update(companyRef, {
      currentReceivable: Number(company.currentReceivable || 0) + companyShare,
      totalClaims: Number(company.totalClaims || 0) + companyShare,
      updatedAt: timestamp,
    });
    transaction.create(
      db.collection("pharmacies").doc(pharmacyId)
        .collection("financial_transactions").doc(insuranceTxId),
      {
        pharmacyId,
        type: "insuranceClaim",
        accountType: "insuranceReceivable",
        direction: "receivable",
        amount: companyShare,
        transactionDate: timestamp,
        insuranceCompanyId: cleanText(invoice.insuranceCompanyId) || null,
        insuranceCompanyName: cleanText(invoice.insuranceCompanyName) || null,
        referenceId: order.invoiceId,
        referenceNumber: cleanText(invoice.invoiceNumber) || order.invoiceId,
        referenceCollection: "sales",
        createdBy: actor.id,
        title: "مطالبة تأمين",
        description: "استحقاق شركة التأمين عند تسليم الطلب",
        metadata: {source: "order", orderId: order.orderId},
      },
    );
  }
  const shift = shiftSnapshot.data() || {};
  transaction.update(shiftRef, {
    [method === "card" ? "cardTotal" : "cashTotal"]:
      Number(shift[method === "card" ? "cardTotal" : "cashTotal"] || 0) + customerShare,
    salesCount: Number(shift.salesCount || 0) + 1,
    insuranceBilledTotal: Number(shift.insuranceBilledTotal || 0) + companyShare,
    updatedAt: timestamp,
  });
  transaction.update(invoiceRef, {
    paymentState: "delivered",
    paidAmount: customerShare,
    remainingAmount: 0,
    cashIn: method === "cash" ? customerShare : 0,
    cardIn: method === "card" ? customerShare : 0,
    insuranceClaimAmount: companyShare,
    insuranceClaimStatus: companyShare > 0 ? "due" : "notApplicable",
    financialPosted: customerShare > 0 || companyShare > 0,
    financialTransactionId: customerShare > 0 ? customerTxId : null,
    insuranceTransactionId: companyShare > 0 ? insuranceTxId : null,
    collectionShiftId: shiftId,
    deliveredAt: timestamp,
    postedAt: timestamp,
    updatedAt: timestamp,
  });
  return {customerTxId, insuranceTxId, customerShare, companyShare};
}

function buildOrderCommandHandler({db, onCall, HttpsError, clock = () => Date.now()}) {
  return onCall(async (request) => {
    try {
      const uid = cleanText(request.auth?.uid);
      if (!uid) throw new OrderContractError("permission-denied", "Authentication is required.");
      const data = request.data || {};
      if (Number(data.schemaVersion) !== ORDER_SCHEMA_VERSION) {
        throw new OrderContractError("failed-precondition", "Unsupported order command schemaVersion.");
      }
      const command = requiredText(data.command, "command");
      const operationId = requiredText(data.operationId, "operationId");
      const committedAt = Timestamp.fromMillis(clock());
      const principal = await resolveCommandPrincipal({
        db, auth: request.auth, instant: committedAt.toMillis(),
      });
      const payload = canonicalCommandPayload(data);
      const result = await executeIdempotentTransaction({
        db,
        actorId: principal.actorId,
        operationId,
        declaredPayloadHash: cleanText(data.payloadHash) || null,
        payload,
        schemaVersion: ORDER_SCHEMA_VERSION,
        command,
        committedAt,
        execute: async ({transaction, operationRef, payloadHash}) => {
          if (command === "collectInsurancePayment") {
            const pharmacyId = requiredText(data.payload?.pharmacyId, "pharmacyId");
            const actor = await resolveActor({transaction, db,
              order: {pharmacy: {pharmacyId}}, principal, command,
              instant: committedAt.toMillis()});
            return collectInsurancePayment({transaction, db, pharmacyId, actor,
              payload: data.payload, operationKey: operationRef.id, timestamp: committedAt});
          }
          if (command === "createOrder") {
            if (principal.type === "employee") {
              throw new OrderContractError("permission-denied", "Employees cannot create user orders.");
            }
            const cleanOrder = safeOrderInput(data.payload?.order);
            if (cleanOrder.user.userId !== principal.actorUid ||
                cleanOrder.beneficiary.ownerUserId !== principal.actorUid) {
              throw new OrderContractError("permission-denied", "Order owner must match caller.");
            }
            const pharmacyRef = db.collection("pharmacies").doc(cleanOrder.pharmacy.pharmacyId);
            const pharmacySnapshot = await transaction.get(pharmacyRef);
            if (!pharmacySnapshot.exists || !pharmacyAcceptsNewOrders(pharmacySnapshot.data())) {
              throw new OrderContractError("failed-precondition", "Pharmacy is not approved, active and accepting new orders.");
            }
            if (cleanOrder.beneficiary.type === "family") {
              const familyId = requiredText(cleanOrder.beneficiary.familyMemberId, "familyMemberId");
              const familyRef = db.collection("users").doc(principal.actorUid)
                .collection("familyMembers").doc(familyId);
              const familySnapshot = await transaction.get(familyRef);
              if (!familySnapshot.exists) {
                throw new OrderContractError("permission-denied", "Beneficiary is not owned by caller.");
              }
            }
            const key = dateKey(committedAt);
            const counterRef = pharmacyRef.collection("order_counters").doc(key);
            const counterSnapshot = await transaction.get(counterRef);
            const insuranceResolution = await resolveInsurance({
              transaction, db, order: cleanOrder,
              pharmacy: pharmacySnapshot.data(), timestamp: committedAt,
            });
            const sequence = counterSnapshot.exists ?
              Number(counterSnapshot.data().lastSequence || 1000) + 1 : 1000;
            transaction.set(counterRef, {
              lastSequence: sequence,
              dateKey: key,
              updatedAt: committedAt,
            }, {merge: true});
            const orderRef = db.collection("orders").doc();
            const actor = {type: "user", id: principal.actorUid};
            const isResolved = insuranceResolution.resolved;
            const status = isResolved ? ORDER_STATUS.UNDER_REVIEW : ORDER_STATUS.RECEIVED;
            const history = [historyEntry(
              ORDER_STATUS.RECEIVED,
              actor,
              "createOrder",
              committedAt,
              "تم استلام الطلب",
            )];
            if (isResolved) {
              history.push(historyEntry(
                ORDER_STATUS.UNDER_REVIEW,
                {type: "system", id: "order-engine"},
                "resolveInsurance",
                committedAt,
                "تم حسم مسار التأمين",
              ));
            }
            const orderNumber = `${key}-${sequence}`;
            transaction.create(orderRef, {
              ...cleanOrder,
              insuranceSelection: insuranceResolution.selection,
              schemaVersion: ORDER_SCHEMA_VERSION,
              orderId: orderRef.id,
              orderNumber,
              orderDateKey: key,
              dailySequence: sequence,
              status,
              statusLabel: statusLabel(status),
              statusHistory: history,
              createdAt: committedAt,
              submittedAt: committedAt,
              updatedAt: committedAt,
              reviewStartedAt: isResolved ? committedAt : null,
              pharmacyDelayAt: isResolved ?
                Timestamp.fromMillis(committedAt.toMillis() + 24 * 60 * 60 * 1000) : null,
              pharmacyReviewActiveMs: 0,
              operationId,
              payloadHash,
              commandResultRef: operationRef.path,
              invoiceId: null,
              offerVersion: 0,
              reservationId: null,
            });
            return {success: true, orderId: orderRef.id, orderNumber, status};
          }

          const orderId = requiredText(data.orderId, "orderId");
          const orderRef = db.collection("orders").doc(orderId);
          const orderSnapshot = await transaction.get(orderRef);
          if (!orderSnapshot.exists) throw new OrderContractError("not-found", "Order not found.");
          const order = {...orderSnapshot.data(), orderId};
          const actor = await resolveActor({
            transaction,
            db,
            order,
            principal,
            command,
            instant: committedAt.toMillis(),
          });
          const target = COMMAND_TARGET[command];
          if (command === "refundOrder") {
            return refundDeliveredOrder({transaction, db, order, actor,
              payload: data.payload || {}, operationKey: operationRef.id, timestamp: committedAt});
          }
          if (!target) throw new OrderContractError("invalid-argument", "Unknown order command.");
          const current = parseOrderStatus(order.status).status;
          assertTransition({from: current, to: target, actorType: actor.type, command});
          const commandData = data.payload || {};
          const update = {
            schemaVersion: ORDER_SCHEMA_VERSION,
            status: target,
            statusLabel: statusLabel(target),
            updatedAt: committedAt,
            operationId,
            payloadHash,
            commandResultRef: operationRef.path,
            statusHistory: [
              ...(Array.isArray(order.statusHistory) ? order.statusHistory : []),
              historyEntry(target, actor, command, committedAt, commandData.reason || commandData.note),
            ],
          };

          const started = toMillis(order.reviewStartedAt);
          const decisionStarted = toMillis(order.userDecisionStartedAt);
          if (command === "continueWithoutInsurance") {
            update.requestedInsurance = order.insurance || null;
            update.insurance = {...order.insurance, enabled: false};
            update.containsInsurance = false;
            update.insuranceSelection = null;
            update.insuranceDecision = "continueWithoutInsurance";
            update.insuranceDecisionAt = committedAt;
            update.reviewStartedAt = committedAt;
            update.pharmacyDelayAt = Timestamp.fromMillis(
              committedAt.toMillis() + 24 * 60 * 60 * 1000,
            );
          }
          if (["createPartialOffer", "revisePartialOffer"].includes(command)) {
            if (command === "revisePartialOffer") {
              if (!Number.isSafeInteger(commandData.offerVersion) || commandData.offerVersion < 0 ||
                  commandData.offerVersion !== Number(order.offerVersion || 0)) {
                throw new OrderContractError("stale-offer-version", "The partial offer changed and must be reviewed again.");
              }
              if (cleanText(order.invoiceId)) {
                throw new OrderContractError("failed-precondition", "An invoiced order cannot reopen its offer.");
              }
            }
            const rawItems = Array.isArray(commandData.items) ? commandData.items : [];
            const requested = new Map(reservationItems(order).map((item) => [
              `${item.medicineId}:${item.soldByPiece}`, item.quantity,
            ]));
            const demands = reservationItems(order, {items: rawItems});
            const items = demands.map((item) => {
              const key = `${item.medicineId}:${item.soldByPiece}`;
              if (!requested.has(key) || item.quantity > requested.get(key)) {
                throw new OrderContractError("invalid-argument", "Partial offer exceeds requested items or quantities.");
              }
              const original = order.medicines.find((line) =>
                cleanText(line.matchedMedicineId || line.medicineId) === item.medicineId &&
                (line.soldByPiece === true) === item.soldByPiece);
              return {...original, ...item, matchedMedicineId: item.medicineId};
            });
            if (items.length === 0) {
              throw new OrderContractError("invalid-argument", "Partial offer items are required.");
            }
            await assertStockAvailable({
              transaction,
              db,
              order,
              items,
              releaseCurrent: current === ORDER_STATUS.CONFIRMED_RESERVED,
              timestamp: committedAt,
            });
            if (current === ORDER_STATUS.CONFIRMED_RESERVED) {
              await changeReservationState({transaction, db, order,
                nextState: "released", timestamp: committedAt});
              update.reservationState = "released";
              update.reservedAt = null;
              update.acceptedOfferVersion = null;
            }
            if (current !== ORDER_STATUS.PARTIAL_OFFER_PENDING && started !== null) {
              update.pharmacyReviewActiveMs = Number(order.pharmacyReviewActiveMs || 0) +
                Math.max(0, committedAt.toMillis() - started);
            }
            update.reviewStartedAt = null;
            update.pharmacyDelayAt = null;
            if (current === ORDER_STATUS.PARTIAL_OFFER_PENDING && decisionStarted !== null) {
              update.userDecisionWaitMs = Number(order.userDecisionWaitMs || 0) +
                Math.max(0, committedAt.toMillis() - decisionStarted);
            }
            const version = Number(order.offerVersion || 0) + 1;
            update.offerVersion = version;
            update.partialOffer = {version, items, createdAt: committedAt};
            update.userDecisionStartedAt = committedAt;
            update.userDecisionDeadline = Timestamp.fromMillis(
              committedAt.toMillis() + 24 * 60 * 60 * 1000,
            );
          }
          if (command === "confirmFullOrder" || command === "acceptPartialOffer") {
            let offer = null;
            if (command === "acceptPartialOffer") {
              assertCurrentOfferVersion(commandData.offerVersion, order.offerVersion);
              offer = order.partialOffer;
              if (!offer || Number(offer.version) !== Number(order.offerVersion)) {
                throw new OrderContractError("stale-offer-version", "Current partial offer is missing.");
              }
              update.acceptedOfferVersion = Number(order.offerVersion);
              update.userDecisionAt = committedAt;
              update.userDecisionStartedAt = null;
              update.userDecisionDeadline = null;
              if (decisionStarted !== null) {
                update.userDecisionWaitMs = Number(order.userDecisionWaitMs || 0) +
                  Math.max(0, committedAt.toMillis() - decisionStarted);
              }
              update.reviewStartedAt = committedAt;
              update.pharmacyDelayAt = Timestamp.fromMillis(
                committedAt.toMillis() + Math.max(
                  0,
                  24 * 60 * 60 * 1000 - Number(order.pharmacyReviewActiveMs || 0),
                ),
              );
            }
            const items = reservationItems(order, offer);
            update.reservationId = await reserveStock({
              transaction,
              db,
              order,
              items,
              timestamp: committedAt,
            });
            update.reservationState = "active";
            update.reservedAt = committedAt;
          }
          if (["cancelOrder", "rejectOrder"].includes(command) &&
              [ORDER_STATUS.UNDER_REVIEW, ORDER_STATUS.CONFIRMED_RESERVED]
                .includes(current) && started !== null) {
            update.pharmacyReviewActiveMs = Number(order.pharmacyReviewActiveMs || 0) +
              Math.max(0, committedAt.toMillis() - started);
            update.reviewStartedAt = null;
          }
          if (command === "cancelOrder") {
            update.userDecisionStartedAt = null;
            update.userDecisionDeadline = null;
            if (hasTrustedInvoice(order)) {
              throw new OrderContractError("failed-precondition", "User cancellation is closed after invoice creation.");
            }
            if (current === ORDER_STATUS.CONFIRMED_RESERVED) {
              await changeReservationState({
                transaction,
                db,
                order,
                nextState: "released",
                timestamp: committedAt,
              });
              update.reservationState = "released";
            }
            update.cancelledAt = committedAt;
            if (current === ORDER_STATUS.PARTIAL_OFFER_PENDING && decisionStarted !== null) {
              update.userDecisionWaitMs = Number(order.userDecisionWaitMs || 0) +
                Math.max(0, committedAt.toMillis() - decisionStarted);
            }
          }
          if (command === "rejectPartialOffer") {
            assertCurrentOfferVersion(commandData.offerVersion, order.offerVersion);
            update.userDecisionStartedAt = null;
            update.userDecisionDeadline = null;
            update.cancelledAt = committedAt;
            if (decisionStarted !== null) {
              update.userDecisionWaitMs = Number(order.userDecisionWaitMs || 0) +
                Math.max(0, committedAt.toMillis() - decisionStarted);
            }
          }
          if (command === "rejectOrder") {
            update.rejectedAt = committedAt;
            update.rejectionReason = requiredText(commandData.reason, "reason");
          }
          if (command === "startPreparing") {
            const invoiceId = requiredText(commandData.invoiceId, "invoiceId");
            if (!commandData.invoice || typeof commandData.invoice !== "object" || Array.isArray(commandData.invoice)) {
              throw new OrderContractError("failed-precondition", "Invoice payload is required for atomic reservation consumption.");
            }
            const invoice = await consumeReservationAndCreateInvoice({
              transaction, db, order, actor, invoiceId,
              invoiceInput: commandData.invoice, timestamp: committedAt,
            });
            update.invoiceId = invoiceId;
            update.invoiceNumber = cleanText(invoice.invoiceNumber) || invoiceId;
            update.invoiceCreatedAt = invoice.createdAt || committedAt;
            update.invoiceCreatedBy = actor.id;
            update.reservationState = "consumed";
            update.preparingAt = committedAt;
          }
          if (command === "markReady") {
            if (!hasTrustedInvoice(order)) {
              throw new OrderContractError("failed-precondition", "Trusted invoice is required.");
            }
            await readCanonicalOrderInvoice({transaction, db, order, paymentState: "pendingDelivery"});
            const timing = buildReadyTiming(committedAt.toDate());
            update.readyAt = committedAt;
            update.pickupDeadline = Timestamp.fromDate(timing.pickupDeadline);
            if (started !== null) {
              const activeMs = Number(order.pharmacyReviewActiveMs || 0) +
                Math.max(0, committedAt.toMillis() - started);
              update.pharmacyReviewActiveMs = activeMs;
              update.pharmacyReadyDurationMs = activeMs;
              update.pharmacyDelayed = activeMs >= 24 * 60 * 60 * 1000;
              update.reviewStartedAt = null;
            }
          }
          if (["cancelAfterInvoice", "markNotCollected"].includes(command)) {
            if (!hasTrustedInvoice(order)) {
              throw new OrderContractError("failed-precondition", "Trusted invoice is required.");
            }
            const reason = command === "markNotCollected" ?
              cleanText(commandData.reason) || "pickup-deadline-expired" :
              requiredText(commandData.reason, "reason");
            const reversalResult = await reverseCanonicalInvoice({
              transaction, db, order, actor, reason, timestamp: committedAt,
            });
            const reversalId = reversalResult.reversalId;
            if (command === "markNotCollected") {
              const deadline = toMillis(order.pickupDeadline);
              if (deadline === null || committedAt.toMillis() < deadline) {
                throw new OrderContractError("failed-precondition", "Pickup deadline has not expired.");
              }
              update.notCollectedAt = committedAt;
              const incidentRef = db.collection("users").doc(order.user.userId)
                .collection("orderIncidents").doc(orderId);
              transaction.set(incidentRef, {
                schemaVersion: ORDER_SCHEMA_VERSION,
                type: "notCollected",
                orderId,
                pharmacyId: order.pharmacy.pharmacyId,
                createdAt: committedAt,
                occurrenceCount: 1,
              }, {merge: false});
            } else {
              update.cancelledAt = committedAt;
            }
            update.reversalId = reversalId;
            update.reversalReason = reason;
          }
          if (command === "completeOrder") {
            if (!hasTrustedInvoice(order)) {
              throw new OrderContractError("failed-precondition", "Trusted invoice is required.");
            }
            const collection = await collectCanonicalInvoice({
              transaction, db, order, actor,
              shiftId: commandData.collectionShiftId, timestamp: committedAt,
            });
            update.collectionShiftId = requiredText(commandData.collectionShiftId, "collectionShiftId");
            update.customerCollectedAmount = collection.customerShare;
            update.insuranceDueAmount = collection.companyShare;
            update.completedAt = committedAt;
            update.deliveredAt = committedAt;
            update.collectedAt = committedAt;
            update.deliveredBy = actor.id;
          }
          transaction.update(orderRef, update);
          return {success: true, orderId, status: target};
        },
      });
      return result;
    } catch (error) {
      throw commandError(error, HttpsError);
    }
  });
}

module.exports = {
  COMMAND_TARGET,
  buildOrderCommandHandler,
  canonicalCommandPayload,
  commandError,
  employeeCanUpdate,
  safeOrderInput,
};
