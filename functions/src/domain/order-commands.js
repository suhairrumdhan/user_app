"use strict";

const {pharmacyAcceptsNewOrders} = require("./availability-policy");

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
const {stockUnits} = require("./stock-units");
const {loadStock, allocate, changeReserved, legacyAllocations, writeStock, saleable} = require("./batch-stock");
const {cents, refundDeliveredOrder, collectInsurancePayment} = require("./order-ledger");
const {readCanonicalOrderInvoice} = require("./order-invoice");
const {employeeClaims, resolveEmployeePrincipal, resolvePharmacyPrincipal, permissionAllowed} = require("../auth/authorization");

const {validateOrderShift} = require("./financial-authorization");
const {INSURANCE_REMOVAL_COMMANDS, handleInsuranceRemoval} = require("./order-insurance-removal");
const {replacementItems, snapshotReplacementNames, previewInvoiceReturn} = require("./replacement-offer");

const COMMAND_TARGET = Object.freeze({
  cancelOrder: ORDER_STATUS.CANCELLED,
  continueWithoutInsurance: ORDER_STATUS.UNDER_REVIEW,
  confirmFullOrder: ORDER_STATUS.CONFIRMED_RESERVED,
  createPartialOffer: ORDER_STATUS.PARTIAL_OFFER_PENDING,
  revisePartialOffer: ORDER_STATUS.PARTIAL_OFFER_PENDING,
  proposeReplacementOffer: ORDER_STATUS.PARTIAL_OFFER_PENDING,
  proposeFullOffer: ORDER_STATUS.PARTIAL_OFFER_PENDING,
  cancelPendingReplacement: ORDER_STATUS.CANCELLED,
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
      beneficiaryId: cleanText(insurance.beneficiaryId) || null,
      insuranceDocumentId: cleanText(insurance.insuranceDocumentId) || null,
      companyCode: cleanText(insurance.companyCode).toUpperCase() || null,
      companyName: cleanText(insurance.companyName) || null,
      policyNumber: cleanText(insurance.policyNumber || insurance.cardNumber) || null,
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
  if (!order.insurance.enabled) return {resolved: true, selection: null, reasons: []};
  const reasons = [];
  const reason = (code, source, message) => {
    if (!reasons.some((item) => item.code === code)) reasons.push({code, source, message});
  };
  const beneficiaryKey = order.beneficiary.type === "self" ?
    "self" : cleanText(order.beneficiary.familyMemberId);
  if (!beneficiaryKey || (order.insurance.beneficiaryId &&
      order.insurance.beneficiaryId !== beneficiaryKey)) {
    return {resolved: false, selection: null, reasons: [{code: "beneficiary-mismatch", source: "user",
      message: "وثيقة التأمين لا تخص المستفيد المحدد."}]};
  }
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
    const card = cards.docs.find((doc) => {
      const data = doc.data();
      const policyNumber = cleanText(data.policyNumber || data.cardNumber);
      const storedBeneficiary = cleanText(data.beneficiaryId);
      const belongsToBeneficiary = storedBeneficiary ?
        storedBeneficiary === beneficiaryKey :
        (Array.isArray(data.coveredMemberIds) ?
          data.coveredMemberIds.length === 1 && data.coveredMemberIds[0] === beneficiaryKey :
          beneficiaryKey === "self");
      return cleanText(data.companyCode).toUpperCase() === code &&
        (!order.insurance.insuranceDocumentId || doc.id === order.insurance.insuranceDocumentId) &&
        (order.insurance.policyNumber ? policyNumber === order.insurance.policyNumber :
          order.insurance.cardNumbers.includes(policyNumber)) &&
        belongsToBeneficiary;
    });
    const company = companies.docs.find((doc) => {
      const data = doc.data();
      return cleanText(data.code).toUpperCase() === code;
    });
    const before = reasons.length;
    if (!card) reason("card-mismatch", "user", "وثيقة التأمين غير موجودة أو لا تطابق بيانات المستفيد.");
    else {
      const data = card.data();
      const start = toMillis(data.startDate);
      const end = toMillis(data.endDate);
      if (data.isActive === false) reason("card-inactive", "user", "وثيقة تأمين المستفيد غير مفعلة.");
      if (start === null || end === null) reason("card-dates-missing", "user", "تواريخ صلاحية وثيقة المستفيد غير مكتملة.");
      else if (end < instant) reason("card-expired", "user", "انتهت صلاحية وثيقة تأمين المستفيد.");
      else if (start > instant) reason("card-not-started", "user", "لم تبدأ صلاحية وثيقة تأمين المستفيد بعد.");
    }
    if (!accepted.has(code)) reason("company-not-accepted", "pharmacy", "الصيدلية لا تقبل شركة التأمين المحددة.");
    if (!company) reason("company-missing", "pharmacy", "لا يوجد عقد لشركة التأمين المحددة لدى الصيدلية.");
    else if (!activeInsuranceCompany(company.data(), instant)) {
      const data = company.data();
      const end = toMillis(data.contractEndDate);
      const start = toMillis(data.contractStartDate);
      if (end !== null && end < instant) reason("company-contract-expired", "pharmacy", "انتهى عقد شركة التأمين لدى الصيدلية.");
      else if (start !== null && start > instant) reason("company-contract-not-started", "pharmacy", "لم يبدأ عقد شركة التأمين لدى الصيدلية بعد.");
      else reason("company-inactive", "pharmacy", "عقد شركة التأمين لدى الصيدلية غير مفعّل.");
    }
    if (card && company && reasons.length === before && accepted.has(code) &&
        card.data().isActive !== false && toMillis(card.data().startDate) !== null &&
        toMillis(card.data().endDate) !== null && toMillis(card.data().startDate) <= instant &&
        toMillis(card.data().endDate) >= instant && activeInsuranceCompany(company.data(), instant)) {
      return {resolved: true, reasons: [], selection: {
      companyId: company.id, companyCode: code, companyName: cleanText(company.data().name),
      cardId: card.id,
      insuranceDocumentId: card.id,
      beneficiaryId: beneficiaryKey,
      policyNumber: cleanText(card.data().policyNumber || card.data().cardNumber),
      cardNumber: cleanText(card.data().policyNumber || card.data().cardNumber),
      coveragePercentage: Number(company.data().discountPercentage || 0),
    }};
    }
  }
  return {resolved: false, selection: null, reasons};
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
    "stale-offer-price": "aborted",
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
    await resolvePharmacyPrincipal({db, auth: {uid: principal.actorUid}, pharmacyId, transaction, instant});
    return {type: "pharmacy", id: principal.actorUid, employeeId: null, canOverridePrices: true};
  }
  if (principal.pharmacyId !== pharmacyId) {
    throw new OrderContractError("permission-denied", "Employee session belongs to another pharmacy.");
  }
  const permission = command === "refundOrder" ? "sales.refund" :
    (command === "collectInsurancePayment" ? "insurance.collect" : "orders.update_status");
  try {
    const resolved = await resolveEmployeePrincipal({
      db, auth: principal.auth, pharmacyId, permission, instant, transaction,
    });
    if (["startPreparing", "completeOrder"].includes(command)) {
      await resolveEmployeePrincipal({db, auth: principal.auth, pharmacyId,
        permission: "sales.create", instant, transaction});
    }
    if (["cancelAfterInvoice", "markNotCollected", "cancelPendingReplacement"].includes(command)) {
      await resolveEmployeePrincipal({db, auth: principal.auth, pharmacyId,
        permission: "sales.refund", instant, transaction});
    }
    principal.canOverridePrices = permissionAllowed(resolved.employee, resolved.permissionDoc, "sales.override_price");
  } catch (_) {
    throw new OrderContractError("permission-denied", "Employee cannot update orders.");
  }
  return {type: "pharmacy", id: principal.employeeId, employeeId: principal.employeeId, canOverridePrices: principal.canOverridePrices};
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
async function stockPlans({transaction, db, order, items, timestamp}) {
  const plans = [];
  for (const demand of stockDemands(items)) {
    const ref = db.collection("pharmacies").doc(order.pharmacy.pharmacyId)
      .collection("medicines").doc(demand.medicineId);
    plans.push({demand, stock: await loadStock(transaction, ref, timestamp)});
  }
  return plans;
}

async function assertStockAvailable({transaction, db, order, items, releaseCurrent = false, restoringInvoice = null, timestamp}) {
  let reservation = null;
  if (releaseCurrent) {
    const snap = await transaction.get(db.collection("orders").doc(order.orderId)
      .collection("reservations").doc(requiredText(order.reservationId, "reservationId")));
    reservation = snap.data();
    if (!reservation || reservation.state !== "active") throw new OrderContractError("failed-precondition", "Active reservation not found.");
  }
  const plans = await stockPlans({transaction, db, order, items, timestamp});
  if (restoringInvoice) previewInvoiceReturn(plans, restoringInvoice, timestamp, saleable);
  for (const {demand, stock} of plans) {
    if (reservation) {
      const previous = stockDemands(reservation.items).find((v) => v.medicineId === demand.medicineId);
      if (previous) changeReserved(stock, reservation.allocations?.filter((v) => v.medicineId === demand.medicineId) ||
        legacyAllocations(stock, previous.packages, previous.pieces), "release");
    }
    allocate(stock, demand.packages, demand.pieces, "reserve");
  }
  return plans;
}

function partialOfferQuote(order, items, plans) {
  const byMedicine = new Map(plans.map(({demand, stock}) => [demand.medicineId, stock.medicine]));
  let grossCents = 0;
  const quotedItems = items.map((item) => {
    const medicineId = requiredText(item.medicineId || item.matchedMedicineId, "offer medicineId");
    const medicine = byMedicine.get(medicineId);
    const packagePrice = Number(medicine?.sellingPrice);
    const configuredPiecePrice = Number(medicine?.piecePrice);
    const units = Number(medicine?.unitsPerPackage);
    const price = item.soldByPiece === true ?
      (configuredPiecePrice > 0 ? configuredPiecePrice : packagePrice / units) : packagePrice;
    if (!Number.isFinite(price) || price <= 0) {
      throw new OrderContractError("failed-precondition", "Set a valid medicine price before sending a partial offer.");
    }
    const unitCents = cents(price);
    const lineCents = unitCents * positiveInteger(item.quantity, "offer quantity");
    if (!Number.isSafeInteger(lineCents) || !Number.isSafeInteger(grossCents + lineCents)) {
      throw new OrderContractError("failed-precondition", "Partial offer total is invalid.");
    }
    grossCents += lineCents;
    return {medicineId, soldByPiece: item.soldByPiece === true,
      quantity: item.quantity, unitPrice: unitCents / 100, lineTotal: lineCents / 100,
      ...(item.replacesMedicineId ? {replacesMedicineId: item.replacesMedicineId,
        replacesSoldByPiece: item.replacesSoldByPiece === true} : {})};
  });
  const coverage = order.insurance?.enabled === true ?
    Number(order.insuranceSelection?.coveragePercentage) : 0;
  if (!Number.isFinite(coverage) || coverage < 0 || coverage > 100) {
    throw new OrderContractError("failed-precondition", "Resolved insurance coverage is missing or invalid.");
  }
  const insuranceCents = Math.round(grossCents * coverage / 100);
  return {currency: "LYD", items: quotedItems, grossTotal: grossCents / 100,
    insuranceShare: insuranceCents / 100,
    customerTotal: (grossCents - insuranceCents) / 100};
}

function assertOfferQuoteCurrent(order, plans) {
  const quoted = order.partialOffer?.quote;
  if (!quoted) return; // Existing offers issued before price quotes remain compatible.
  const current = partialOfferQuote(order, order.partialOffer.items, plans);
  const key = (item) => `${item.medicineId}:${item.soldByPiece === true}`;
  const currentPrices = new Map(current.items.map((item) => [key(item), cents(item.unitPrice)]));
  if (quoted.items?.length !== current.items.length ||
      quoted.items.some((item) => currentPrices.get(key(item)) !== cents(item.unitPrice)) ||
      cents(quoted.customerTotal) !== cents(current.customerTotal)) {
    throw new OrderContractError("stale-offer-price", "stale-offer-price: The partial offer price changed and must be reviewed again.");
  }
}

async function reserveStock({transaction, db, order, items, timestamp, preloadedPlans = null}) {
  const plans = preloadedPlans || await stockPlans({transaction, db, order, items, timestamp});
  const allocations = plans.flatMap(({demand, stock}) => allocate(stock, demand.packages, demand.pieces, "reserve"));
  for (const {stock} of plans) writeStock(transaction, stock);
  const reservationId = order.reservationId ?
    `order-${order.orderId}-offer-${order.offerVersion}` : `order-${order.orderId}`;
  transaction.create(db.collection("orders").doc(order.orderId).collection("reservations").doc(reservationId), {
    schemaVersion: ORDER_SCHEMA_VERSION, reservationId, orderId: order.orderId,
    pharmacyId: order.pharmacy.pharmacyId, items, allocations, state: "active", reservedAt: timestamp,
  });
  return reservationId;
}

async function changeReservationState({transaction, db, order, nextState, timestamp}) {
  const ref = db.collection("orders").doc(order.orderId)
    .collection("reservations").doc(requiredText(order.reservationId, "reservationId"));
  const snapshot = await transaction.get(ref); const reservation = snapshot.data();
  if (!reservation || reservation.state !== "active") throw new OrderContractError("failed-precondition", "Active reservation not found.");
  const plans = await stockPlans({transaction, db, order, items: reservation.items, timestamp});
  for (const {demand, stock} of plans) {
    const parts = reservation.allocations?.filter((v) => v.medicineId === demand.medicineId) ||
      legacyAllocations(stock, demand.packages, demand.pieces);
    changeReserved(stock, parts, "release");
  }
  for (const {stock} of plans) writeStock(transaction, stock);
  transaction.update(ref, {state: nextState, [`${nextState}At`]: timestamp});
}

function nonNegativeNumber(value, name) {
  const result = Number(value || 0);
  if (!Number.isFinite(result) || result < 0 || result > 1e12) {
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
  const subtotal = cents(invoice.subtotal) / 100;
  const discount = cents(invoice.discount) / 100;
  const companyShare = cents(invoice.insuranceDiscount) / 100;
  const customerShare = cents(invoice.total) / 100;
  const itemNet = items.reduce((sum, item) => {
    item.unitPrice = cents(item.unitPrice) / 100;
    const gross = cents(item.unitPrice) * item.quantity;
    if (item.discountPercentage > 100 || cents(item.discountAmount) > gross) {
      throw new OrderContractError("invalid-argument", "Discount exceeds the invoice line value.");
    }
    const lineDiscount = cents(item.discountAmount) || Math.round(gross * item.discountPercentage / 100);
    item.discountAmount = lineDiscount / 100;
    item.discountPercentage = 0;
    return sum + gross - lineDiscount;
  }, 0);
  if (itemNet !== cents(subtotal) || discount > subtotal ||
      cents(subtotal) - cents(discount) !== cents(customerShare) + cents(companyShare)) {
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
  if (Number(order.invoiceGeneration || 0) > 0 &&
      invoiceId !== `order-${order.orderId}-replacement-${order.invoiceGeneration}`) {
    throw new OrderContractError("failed-precondition", "Refresh the order replacement invoice before saving.");
  }
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
    const beneficiaryKey = order.beneficiary?.type === "self" ?
      "self" : cleanText(order.beneficiary?.familyMemberId);
    const storedBeneficiary = cleanText(card.beneficiaryId);
    const covered = storedBeneficiary ? storedBeneficiary === beneficiaryKey :
      (Array.isArray(card.coveredMemberIds) ?
        card.coveredMemberIds.length === 1 && card.coveredMemberIds[0] === beneficiaryKey :
        beneficiaryKey === "self");
    const policyNumber = cleanText(card.policyNumber || card.cardNumber);
    const selectedPolicy = cleanText(selection.policyNumber || selection.cardNumber);
    if (!cardSnapshot.exists || card.isActive === false || !code ||
        cleanText(card.companyCode).toUpperCase() !== code ||
        cleanText(company.code).toUpperCase() !== code ||
        policyNumber !== selectedPolicy ||
        start === null || end === null || start > timestamp.toMillis() || end < timestamp.toMillis() ||
        !covered || !Array.isArray(accepted) || !accepted.some((value) => cleanText(value).toUpperCase() === code)) {
      throw new OrderContractError("failed-precondition", "Order insurance coverage is no longer valid. Renew coverage or cancel the order.");
    }
    const rate = nonNegativeNumber(company.discountPercentage, "insurance coverage percentage");
    if (rate > 100 || cents(invoice.companyShare) !==
        Math.round((cents(invoice.subtotal) - cents(invoice.discount)) * rate / 100)) {
      throw new OrderContractError("failed-precondition", "Invoice insurance amount does not match current coverage.");
    }
    invoice.insuranceCoveragePercentage = rate;
  }
  const acceptedQuote = order.acceptedOfferVersion != null &&
    Number(order.acceptedOfferVersion) === Number(order.offerVersion) ?
    order.partialOffer?.quote : order.insuranceRemoval?.status === "accepted" ? order.insuranceRemoval.quote : order.fullOrderQuote || null;
  const originalTotal = Number(order.customerEstimatedTotalPrice ?? order.estimatedTotalPrice);
  if (!acceptedQuote && (!Number.isFinite(originalTotal) || cents(invoice.total) > cents(originalTotal))) {
    throw new OrderContractError("stale-offer-price", "stale-offer-price: Send a full price offer before increasing the order amount.");
  }
  if (acceptedQuote) {
    const quotedPrices = new Map(acceptedQuote.items.map((item) => [
      invoiceReservationKey(item), cents(item.unitPrice),
    ]));
    if (invoice.items.some((item) => cents(item.unitPrice) >
        (quotedPrices.get(invoiceReservationKey(item)) ?? -1)) ||
        cents(invoice.total) > cents(acceptedQuote.customerTotal)) {
      throw new OrderContractError("stale-offer-price", "stale-offer-price: Invoice price exceeds the accepted partial offer.");
    }
  }
  const shiftRef = db.collection("pharmacies").doc(pharmacyId)
    .collection("shifts").doc(invoice.creationShiftId);
  const {snapshot: shiftSnapshot} = await validateOrderShift({transaction, db, pharmacyId, actor, shiftId: shiftRef.id});
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
  const plans = await stockPlans({transaction, db, order, items: reservation.items, timestamp});
  const allocations = [];
  for (const {demand, stock} of plans) {
    const parts = reservation.allocations?.filter((v) => v.medicineId === demand.medicineId) ||
      legacyAllocations(stock, demand.packages, demand.pieces);
    changeReserved(stock, parts, "consume");
    allocations.push(...parts);
  }
  if (!actor.canOverridePrices) {
    if (invoice.discount > 0) throw new OrderContractError("permission-denied", "صلاحية الخصم مطلوبة");
    for (const line of invoice.items) {
      const medicine = plans.find((p) => p.demand.medicineId === line.medicineId).stock.medicine;
      const expected = Number(line.sellAsPiece ?
        (medicine.piecePrice ?? Number(medicine.sellingPrice || 0) / Number(medicine.unitsPerPackage || 1)) : medicine.sellingPrice);
      if (!Number.isFinite(expected) || Math.round(line.unitPrice * 100) !== Math.round(expected * 100) ||
          line.discountAmount > 0 || line.discountPercentage > 0) {
        throw new OrderContractError("permission-denied", "سعر الصنف أو خصمه يحتاج صلاحية تعديل السعر");
      }
    }
  }
  invoice.batchAllocations = allocations;
  const remainingParts = allocations.map((part) => ({...part}));
  for (const line of invoice.items) {
    let remaining = line.quantity;
    const unit = line.sellAsPiece ? "pieces" : "packages";
    line.batchAllocations = [];
    for (const part of remainingParts.filter((p) => p.medicineId === line.medicineId)) {
      const taken = Math.min(remaining, part[unit]);
      if (taken) line.batchAllocations.push({...part, packages: line.sellAsPiece ? 0 : taken,
        pieces: line.sellAsPiece ? taken : 0});
      remaining -= taken; part[unit] -= taken;
    }
    if (remaining) throw new OrderContractError("failed-precondition", "Invoice line does not match its reserved batches.");
    line.unitCost = line.batchAllocations.reduce((sum, part) => sum + part.unitCost *
      (part.packages + (part.unitsPerPackage ? part.pieces / part.unitsPerPackage : 0)), 0) / line.quantity;
  }
  invoice.cogsTotal = Math.round(allocations.reduce((sum, part) => sum + Number(part.unitCost || 0) *
    (part.packages + (part.unitsPerPackage ? part.pieces / part.unitsPerPackage : 0)), 0) * 100) / 100;
  invoice.grossProfit = Math.round((invoice.subtotal - invoice.discount - invoice.cogsTotal) * 100) / 100;
  for (const {stock} of plans) writeStock(transaction, stock);
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
  const plans = await stockPlans({transaction, db, order,
    items: [...restoreItems.values()].map((v) => ({...v, soldByPiece: v.sellAsPiece})), timestamp});
  for (const {demand, stock} of plans) {
    const parts = invoice.batchAllocations?.filter((v) => v.medicineId === demand.medicineId) ||
      legacyAllocations(stock, demand.packages, demand.pieces);
    for (const [index, part] of parts.entries()) {
      const batch = stock.batches.find((b) => b.id === part.batchId);
      if (!batch) throw new OrderContractError("failed-precondition", "Original batch is missing.");
      if (!saleable(batch, timestamp.toMillis()) || stock.medicine.isActive === false) {
        transaction.create(db.collection("pharmacies").doc(pharmacyId).collection("quarantinedReturns")
          .doc(`order-${order.orderId}-${order.invoiceGeneration || 0}-${demand.medicineId}-${index}`), {
            orderId: order.orderId, invoiceId: order.invoiceId, medicineId: demand.medicineId,
            batchId: part.batchId, quantity: part.packages, pieceQuantity: part.pieces,
            reason: "not-saleable-at-reversal", createdAt: timestamp, availableForSale: false,
          });
      } else {
        batch.quantity += part.packages; batch.pieceQuantity += part.pieces;
        stockUnits(batch); stock.changed.add(batch.id);
      }
    }
    writeStock(transaction, stock);
  }
  const reversalId = `order-reversal-${order.orderId}${Number(order.invoiceGeneration || 0) > 0 ? `-invoice-${order.invoiceGeneration}` : ""}`;
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
  const {snapshot: shiftSnapshot} = await validateOrderShift({transaction, db, pharmacyId, actor, shiftId: shiftRef.id});
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
      currentReceivable: (cents(company.currentReceivable) + cents(companyShare)) / 100,
      totalClaims: (cents(company.totalClaims) + cents(companyShare)) / 100,
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
  if (companyShare > 0) transaction.create(db.collection("pharmacies").doc(pharmacyId)
    .collection("insurance_ledger").doc(insuranceTxId), {
      type: "claim", invoiceId: order.invoiceId, orderId: order.orderId,
      insuranceCompanyId: invoice.insuranceCompanyId, amount: companyShare,
      direction: "receivable", createdAt: timestamp, createdBy: actor.id,
    });
  const shift = shiftSnapshot.data() || {};
  transaction.update(shiftRef, {
    [method === "card" ? "cardTotal" : "cashTotal"]:
      (cents(shift[method === "card" ? "cardTotal" : "cashTotal"]) + cents(customerShare)) / 100,
    salesCount: Number(shift.salesCount || 0) + 1,
    insuranceBilledTotal: (cents(shift.insuranceBilledTotal) + cents(companyShare)) / 100,
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
            let cleanOrder = safeOrderInput(data.payload?.order);
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
              const family = familySnapshot.data() || {};
              // Freeze an authoritative beneficiary snapshot in the order. This
              // keeps historical orders stable if the family record changes and
              // prevents stale/tampered client health data from being persisted.
              const allergies = Array.isArray(family.allergies) ? family.allergies : [];
              const healthConditions = Array.isArray(family.healthConditions) ?
                family.healthConditions : [];
              const currentMedications = Array.isArray(family.currentMedications) ?
                family.currentMedications : [];
              const hasHealthData = allergies.length > 0 || healthConditions.length > 0 ||
                currentMedications.length > 0 || Boolean(cleanText(family.bloodType)) ||
                Boolean(cleanText(family.gender)) || family.dateOfBirth != null ||
                (family.age != null && Number.isInteger(Number(family.age)));
              cleanOrder = {
                ...cleanOrder,
                beneficiary: {
                  ...cleanOrder.beneficiary,
                  beneficiaryId: familyId,
                  familyMemberId: familyId,
                  type: "family",
                  name: cleanText(family.name) || cleanOrder.beneficiary.name,
                  relationLabel: cleanText(family.relation) || "فرد من العائلة",
                  gender: cleanText(family.gender) || null,
                  bloodType: cleanText(family.bloodType) || null,
                  age: family.age != null && Number.isInteger(Number(family.age)) ?
                    Number(family.age) : null,
                  dateOfBirth: family.dateOfBirth || null,
                  allergies,
                  healthConditions,
                  currentMedications,
                  hasHealthData,
                },
                hasSensitiveHealthData: hasHealthData,
              };
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
            const grossEstimatedCents = cents(cleanOrder.estimatedTotalPrice);
            const coveragePercentage = isResolved ?
              Number(insuranceResolution.selection?.coveragePercentage || 0) : 0;
            const insuranceEstimatedCents = Math.round(
              grossEstimatedCents * coveragePercentage / 100,
            );
            const customerEstimatedCents = grossEstimatedCents - insuranceEstimatedCents;
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
              insuranceResolution: {resolved: isResolved, reasons: insuranceResolution.reasons, checkedAt: committedAt},
              grossEstimatedTotalPrice: grossEstimatedCents / 100,
              insuranceEstimatedShare: insuranceEstimatedCents / 100,
              customerEstimatedTotalPrice: customerEstimatedCents / 100,
              initialCustomerEstimatedTotalPrice: customerEstimatedCents / 100,
              // Compatibility display field: both apps historically render
              // this value as the amount due from the customer.
              estimatedTotalPrice: customerEstimatedCents / 100,
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
            return {
              success: true, orderId: orderRef.id, orderNumber, status,
              estimatedTotalPrice: customerEstimatedCents / 100,
              grossEstimatedTotalPrice: grossEstimatedCents / 100,
              insuranceEstimatedShare: insuranceEstimatedCents / 100,
              insuranceResolution: {resolved: isResolved, reasons: insuranceResolution.reasons},
            };
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
          let target = COMMAND_TARGET[command];
          if (INSURANCE_REMOVAL_COMMANDS.has(command)) {
            return handleInsuranceRemoval({transaction, db, order, orderRef, actor, command,
              payload: data.payload || {}, timestamp: committedAt, operationId: operationRef.id,
              cancelOrder: async () => {
                if (hasTrustedInvoice(order)) {
                  const result = await reverseCanonicalInvoice({transaction, db, order, actor,
                    reason: "user-declined-uninsured-payment", timestamp: committedAt});
                  return {reversalId: result.reversalId, reversalReason: "user-declined-uninsured-payment"};
                }
                if (order.status === ORDER_STATUS.CONFIRMED_RESERVED) {
                  await changeReservationState({transaction, db, order, nextState: "released", timestamp: committedAt});
                  return {reservationState: "released"};
                }
                return {};
              },
              quoteForOrder: async () => {
                const items = reservationItems(order, order.status === ORDER_STATUS.PARTIAL_OFFER_PENDING ||
                  order.acceptedOfferVersion != null ? order.partialOffer : null);
                const plans = await stockPlans({transaction, db, order, items, timestamp: committedAt});
                return partialOfferQuote({...order, insurance: {...order.insurance, enabled: false}}, items, plans);
              }});
          }
          if (command === "rejectPartialOffer" && order.insuranceRemoval?.status === "pending" &&
              hasTrustedInvoice(order) && order.partialOffer?.kind === "replacement") {
            throw new OrderContractError("failed-precondition", "insurance-removal-pending: Wait for the user coverage decision.");
          }
          if (order.insuranceRemoval?.status === "pending" &&
              !["cancelOrder", "rejectOrder", "rejectPartialOffer", "cancelAfterInvoice", "cancelPendingReplacement"].includes(command)) {
            throw new OrderContractError("failed-precondition", "insurance-removal-pending: Wait for the user coverage decision.");
          }
          if (command === "refundOrder") {
            return refundDeliveredOrder({transaction, db, order, actor,
              payload: data.payload || {}, operationKey: operationRef.id, timestamp: committedAt});
          }
          if (!target) throw new OrderContractError("invalid-argument", "Unknown order command.");
          const current = parseOrderStatus(order.status).status;
          let fullQuote = null;
          if (command === "confirmFullOrder" && current === ORDER_STATUS.UNDER_REVIEW) {
            const plans = await assertStockAvailable({transaction, db, order, items: reservationItems(order), timestamp: committedAt});
            fullQuote = partialOfferQuote(order, reservationItems(order), plans);
            const baseline = Number(order.customerEstimatedTotalPrice ?? order.estimatedTotalPrice);
            // The original submitted amount is the ceiling; a missing amount needs explicit consent.
            const increasedUnit = order.medicines.some((line) => Number(line.estimatedPrice) > 0 &&
              fullQuote.items.some((item) => item.medicineId === (line.matchedMedicineId || line.medicineId) &&
                item.soldByPiece === (line.soldByPiece === true) && cents(item.unitPrice) > cents(line.estimatedPrice)));
            if (!Number.isFinite(baseline) || cents(fullQuote.customerTotal) > cents(baseline) || increasedUnit) {
              target = ORDER_STATUS.PARTIAL_OFFER_PENDING;
            }
          }
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

          if (target === ORDER_STATUS.CANCELLED && order.insuranceRemoval?.status === "pending" &&
              !(command === "rejectPartialOffer" && hasTrustedInvoice(order) && order.partialOffer?.kind === "replacement")) {
            update.insuranceRemoval = {...order.insuranceRemoval, status: "cancelled", decidedAt: committedAt};
            update.insuranceDecisionWaitIntervals = (order.insuranceDecisionWaitIntervals || []).map((interval) =>
              interval.end == null ? {...interval, end: committedAt} : interval);
          }

          const started = toMillis(order.reviewStartedAt);
          const decisionStarted = toMillis(order.userDecisionStartedAt);
          if (command === "continueWithoutInsurance") {
            update.requestedInsurance = order.insurance || null;
            update.insurance = {...order.insurance, enabled: false};
            update.containsInsurance = false;
            update.insuranceSelection = null;
            update.insuranceEstimatedShare = 0;
            update.customerEstimatedTotalPrice = Number(order.grossEstimatedTotalPrice ?? order.estimatedTotalPrice ?? 0);
            update.estimatedTotalPrice = update.customerEstimatedTotalPrice;
            update.insuranceDecision = "continueWithoutInsurance";
            update.insuranceDecisionAt = committedAt;
            update.reviewStartedAt = committedAt;
            update.pharmacyDelayAt = Timestamp.fromMillis(
              committedAt.toMillis() + 24 * 60 * 60 * 1000,
            );
          }
          if (["createPartialOffer", "revisePartialOffer", "proposeReplacementOffer", "proposeFullOffer"].includes(command) || (command === "confirmFullOrder" && target === ORDER_STATUS.PARTIAL_OFFER_PENDING)) {
            const full = command === "proposeFullOffer" || command === "confirmFullOrder";
            const replacing = command === "proposeReplacementOffer";
            let originalInvoice = null;
            if (command === "revisePartialOffer" || replacing || (full && command !== "confirmFullOrder")) {
              if (!Number.isSafeInteger(commandData.offerVersion) || commandData.offerVersion < 0 ||
                  commandData.offerVersion !== Number(order.offerVersion || 0)) {
                throw new OrderContractError("stale-offer-version", "The partial offer changed and must be reviewed again.");
              }
              if (cleanText(order.invoiceId) && !replacing) {
                throw new OrderContractError("failed-precondition", "An invoiced order cannot reopen its offer.");
              }
              if (replacing && cleanText(order.invoiceId)) {
                originalInvoice = (await readCanonicalOrderInvoice({transaction, db, order, paymentState: "pendingDelivery"})).invoice;
              }
            }
            const rawItems = full ? reservationItems(order) : Array.isArray(commandData.items) ? commandData.items : [];
            const requested = new Map(reservationItems(order).map((item) => [
              `${item.medicineId}:${item.soldByPiece}`, item.quantity,
            ]));
            const demands = reservationItems(order, {items: rawItems});
            let items = replacing ? replacementItems(order, rawItems, commandData.reason) : demands.map((item) => {
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
            const pricePlans = await assertStockAvailable({
              transaction,
              db,
              order,
              items,
              releaseCurrent: current === ORDER_STATUS.CONFIRMED_RESERVED,
              restoringInvoice: originalInvoice,
              timestamp: committedAt,
            });
            if (replacing) items = snapshotReplacementNames(items, pricePlans);
            const quote = partialOfferQuote(order, items, pricePlans);
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
            update.partialOffer = {version, items, quote, createdAt: committedAt,
              ...(full ? {kind: "full", reason: "مراجعة سعر جميع أصناف الطلب"} : {}),
              ...(replacing ? {kind: "replacement", reason: commandData.reason,
                previousInvoiceId: order.invoiceId || null,
                previousStatus: current === ORDER_STATUS.PARTIAL_OFFER_PENDING ? order.partialOffer?.previousStatus || current : current,
                ...(hasTrustedInvoice(order) ? {
                  previousOffer: current === ORDER_STATUS.PARTIAL_OFFER_PENDING ? order.partialOffer?.previousOffer || null : order.partialOffer || null,
                  previousAcceptedOfferVersion: current === ORDER_STATUS.PARTIAL_OFFER_PENDING ? order.partialOffer?.previousAcceptedOfferVersion ?? null : order.acceptedOfferVersion ?? null,
                  previousFullOrderQuote: current === ORDER_STATUS.PARTIAL_OFFER_PENDING ? order.partialOffer?.previousFullOrderQuote || null : order.fullOrderQuote || null,
                } : {})} : {})};
            if (full) update.statusLabel = "بانتظار موافقة سعر الطلب الكامل";
            if (replacing) update.statusLabel = "بانتظار موافقة تبديل الأصناف";
            update.acceptedOfferVersion = null;
            update.fullOrderQuote = null;
            update.userDecisionStartedAt = committedAt;
            update.userDecisionDeadline = Timestamp.fromMillis(
              committedAt.toMillis() + 24 * 60 * 60 * 1000,
            );
          }
          if ((command === "confirmFullOrder" && target === ORDER_STATUS.CONFIRMED_RESERVED) || command === "acceptPartialOffer") {
            if (fullQuote) {
              update.fullOrderQuote = fullQuote;
              update.estimatedTotalPrice = fullQuote.customerTotal;
              update.customerEstimatedTotalPrice = fullQuote.customerTotal;
              update.grossEstimatedTotalPrice = fullQuote.grossTotal;
              update.insuranceEstimatedShare = fullQuote.insuranceShare;
            }
            let offer = null;
            let restoredPlans = null;
            if (command === "acceptPartialOffer") {
              assertCurrentOfferVersion(commandData.offerVersion, order.offerVersion);
              offer = order.partialOffer;
              if (!offer || Number(offer.version) !== Number(order.offerVersion)) {
                throw new OrderContractError("stale-offer-version", "Current partial offer is missing.");
              }
              if (offer.kind === "replacement" && hasTrustedInvoice(order)) {
                const original = await readCanonicalOrderInvoice({transaction, db, order, paymentState: "pendingDelivery"});
                restoredPlans = await stockPlans({transaction, db, order, items: reservationItems(order, offer), timestamp: committedAt});
                previewInvoiceReturn(restoredPlans, original.invoice, committedAt, saleable);
                assertOfferQuoteCurrent(order, restoredPlans);
                // Check all replacement stock before reversing the old invoice. The transaction is atomic.
                for (const {demand, stock} of restoredPlans) {
                  allocate(stock, demand.packages, demand.pieces, "reserve");
                }
                // Reload clean plans: the availability check above must not reserve twice.
                restoredPlans = await stockPlans({transaction, db, order, items: reservationItems(order, offer), timestamp: committedAt});
                previewInvoiceReturn(restoredPlans, original.invoice, committedAt, saleable);
                const reversal = await reverseCanonicalInvoice({transaction, db, order, actor,
                  reason: "accepted-replacement-offer", timestamp: committedAt});
                update.invoiceRevisions = [...(order.invoiceRevisions || []), {invoiceId: order.invoiceId,
                  reversalId: reversal.reversalId, offerVersion: order.offerVersion, changedAt: committedAt,
                  firstReadyAt: order.firstReadyAt || null}];
                Object.assign(update, {invoiceId: null, invoiceNumber: null, invoiceCreatedAt: null,
                  invoiceCreatedBy: null, invoiceGeneration: Number(order.invoiceGeneration || 0) + 1,
                  finalCustomerTotalPrice: null, finalGrossTotalPrice: null, finalInsuranceShare: null,
                  preparingAt: null, readyAt: null, firstReadyAt: null, pickupDeadline: null,
                  pickupOverdue: false, pickupOverdueAt: null, pharmacyDelayed: false,
                  pharmacyDelayDetectedAt: null, fulfillmentCycleStartedAt: committedAt,
                  pharmacyReviewActiveMs: 0, pharmacyReadyDurationMs: null});
              } else if (offer.quote) {
                assertOfferQuoteCurrent(order, await stockPlans({
                  transaction, db, order, items: reservationItems(order, offer), timestamp: committedAt,
                }));
              }
              if (offer.quote) {
                update.grossEstimatedTotalPrice = offer.quote.grossTotal;
                update.insuranceEstimatedShare = offer.quote.insuranceShare;
                update.customerEstimatedTotalPrice = offer.quote.customerTotal;
                update.estimatedTotalPrice = offer.quote.customerTotal;
                update.totalItemsCount = offer.quote.items.reduce((sum, item) => sum + item.quantity, 0);
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
                  24 * 60 * 60 * 1000 - Number(update.pharmacyReviewActiveMs ?? order.pharmacyReviewActiveMs ?? 0),
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
              preloadedPlans: restoredPlans,
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
            if (hasTrustedInvoice(order) && order.partialOffer?.kind === "replacement") {
              const previous = order.partialOffer;
              target = previous.previousStatus === ORDER_STATUS.READY ? ORDER_STATUS.READY : ORDER_STATUS.PREPARING;
              update.status = target;
              update.statusLabel = statusLabel(target);
              update.statusHistory[update.statusHistory.length - 1] =
                historyEntry(target, actor, command, committedAt, "رفض التبديل؛ استمرار الطلب الأصلي");
              update.partialOffer = previous.previousOffer ? {...previous.previousOffer, version: order.offerVersion} : {};
              update.acceptedOfferVersion = previous.previousAcceptedOfferVersion != null ? order.offerVersion : null;
              update.fullOrderQuote = previous.previousFullOrderQuote || null;
              update.rejectedReplacementVersion = order.offerVersion;
            }
            update.userDecisionStartedAt = null;
            update.userDecisionDeadline = null;
            if (target === ORDER_STATUS.CANCELLED) update.cancelledAt = committedAt;
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
            update.finalGrossTotalPrice = invoice.subtotal - invoice.discount;
            update.finalInsuranceShare = invoice.companyShare;
            update.finalCustomerTotalPrice = invoice.customerShare;
            update.estimatedTotalPrice = invoice.customerShare;
            update.reservationState = "consumed";
            update.preparingAt = committedAt;
          }
          if (command === "markReady") {
            if (!hasTrustedInvoice(order)) {
              throw new OrderContractError("failed-precondition", "Trusted invoice is required.");
            }
            await readCanonicalOrderInvoice({transaction, db, order, paymentState: "pendingDelivery"});
            const firstReady = order.firstReadyAt || order.readyAt || committedAt;
            const timing = buildReadyTiming(firstReady.toDate?.() || new Date(firstReady));
            update.firstReadyAt = firstReady;
            update.readyAt = firstReady;
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
          if (command === "cancelPendingReplacement") {
            if (order.partialOffer?.kind !== "replacement" || !hasTrustedInvoice(order)) {
              throw new OrderContractError("failed-precondition", "An invoiced pending replacement is required.");
            }
            assertCurrentOfferVersion(commandData.offerVersion, order.offerVersion);
            const reason = requiredText(commandData.reason, "reason");
            const result = await reverseCanonicalInvoice({transaction, db, order, actor, reason, timestamp: committedAt});
            Object.assign(update, {cancelledAt: committedAt, reversalId: result.reversalId,
              reversalReason: reason, userDecisionStartedAt: null, userDecisionDeadline: null});
            if (decisionStarted !== null) update.userDecisionWaitMs = Number(order.userDecisionWaitMs || 0) + Math.max(0, committedAt.toMillis() - decisionStarted);
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
          const auditRef = db.collection("pharmacies")
            .doc(requiredText(order.pharmacy?.pharmacyId, "pharmacyId"))
            .collection("audit_logs").doc(`order-${operationRef.id}`);
          transaction.create(auditRef, {
            schemaVersion: ORDER_SCHEMA_VERSION,
            module: "orders",
            action: command,
            operationId,
            targetId: orderId,
            orderId,
            invoiceId: update.invoiceId || cleanText(order.invoiceId) || null,
            fromStatus: current,
            toStatus: target,
            actor: {id: actor.id, type: actor.type},
            createdBy: actor.id,
            createdAt: committedAt,
            timestamp: committedAt,
          });
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
