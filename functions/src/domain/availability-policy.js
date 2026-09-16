"use strict";

function pharmacyVisibleInSearch(pharmacy) {
  return !!pharmacy && String(pharmacy.status || "").trim().toLowerCase() === "approved" &&
    pharmacy.isActive !== false && pharmacy.isBlocked !== true;
}

function pharmacyAcceptsNewOrders(pharmacy) {
  return pharmacyVisibleInSearch(pharmacy) && pharmacy.isOnline === true;
}

function medicineSaleState(medicine, instant = Date.now()) {
  const raw = medicine.expiryDate;
  let expiryMillis = null;
  if (raw !== null && raw !== undefined) {
    if (typeof raw?.toMillis === "function") expiryMillis = raw.toMillis();
    else if (raw instanceof Date) expiryMillis = raw.getTime();
    else if (typeof raw === "string" && raw.trim()) expiryMillis = Date.parse(raw);
  }
  const invalidExpiry = raw !== null && raw !== undefined && !Number.isFinite(expiryMillis);
  const expired = Number.isFinite(expiryMillis) && expiryMillis <= instant;
  const active = medicine.isActive === undefined || medicine.isActive === null || medicine.isActive === true;
  return {expiryMillis: Number.isFinite(expiryMillis) ? expiryMillis : null,
    invalidExpiry, expired, active, saleable: active && !invalidExpiry && !expired};
}

module.exports = {pharmacyVisibleInSearch, pharmacyAcceptsNewOrders, medicineSaleState};
