"use strict";

const {FieldValue, FieldPath, Timestamp} = require("firebase-admin/firestore");
const {stockUnits} = require("./stock-units");
const {pharmacyVisibleInSearch, pharmacyAcceptsNewOrders, medicineSaleState} = require("./availability-policy");
const INDEX_VERSION = 7;

function normalize(value) {
  return String(value || "").trim().toUpperCase().replace(/&/g, " AND ").replace(/\+/g, " PLUS ")
    .replace(/[_-]/g, " ").replace(/([A-Z])(\d)/g, "$1 $2").replace(/(\d)([A-Z])/g, "$1 $2")
    .replace(/[^A-Z0-9\s/%]/g, " ").replace(/\s+/g, " ").trim();
}

function searchTerms(...names) {
  const tokens = new Set();
  const prefixes = new Set();
  for (const name of names) {
    const value = normalize(name);
    if (!value) continue;
    tokens.add(value);
    value.split(" ").filter((word) => word.length >= 2).forEach((word) => tokens.add(word));
    const base = value.replace(/\b\d+(?:\.\d+)?\s*(?:MG|MCG|G|ML|IU|%)\b/g, " ")
      .replace(/\b(?:TABLET|TABLETS|TAB|TABS|CAPSULE|CAPSULES|CAP|CAPS|SYRUP|SYP|SUSPENSION|SUSP|DROPS|DROP|SPRAY|CREAM|OINTMENT|OINT|GEL|AMPOULE|AMP|VIAL|INHALER|SACHET|INJECTION|INJ|POWDER|LOTION|PATCH)\b/g, " ")
      .replace(/\s+/g, " ").trim();
    if (base) {
      const parts = base.split(" ");
      tokens.add(base);
      tokens.add(parts[0]);
      if (parts.length >= 2) tokens.add(parts.slice(0, 2).join(" "));
    }
    for (const word of [value.replace(/ /g, ""), ...value.split(" ")]) {
      for (let length = 2; length <= Math.min(24, word.length); length++) {
        prefixes.add(word.slice(0, length));
      }
    }
  }
  return {searchTokens: [...tokens], suggestionPrefixes: [...prefixes]};
}

function finite(value, fallback = 0) {
  const number = Number(value);
  return Number.isFinite(number) ? number : fallback;
}

function optionalText(value) {
  return typeof value === "string" ? value : null;
}

// Public projection only: never copy private employee, cost or patient fields.
function buildMedicineSearchIndex({pharmacyId, medicineId, pharmacy, medicine, instant = Date.now()}) {
  const sale = medicineSaleState(medicine, instant);
  let stock;
  try { stock = stockUnits(medicine); } catch (_) { stock = null; }
  const location = pharmacy.location && typeof pharmacy.location === "object" ? pharmacy.location : {};
  const sellingPrice = finite(medicine.sellingPrice);
  const piecesEnabled = medicine.sellByPiece === true;
  const configuredPiecePrice = finite(medicine.piecePrice);
  const piecePrice = configuredPiecePrice > 0 ? configuredPiecePrice :
    (piecesEnabled && stock?.units > 0 && sellingPrice > 0 ? sellingPrice / stock.units : 0);
  return {
    pharmacyId, medicineId, indexVersion: INDEX_VERSION,
    pharmacyName: String(pharmacy.pharmacyName || pharmacy.name || ""),
    status: String(pharmacy.status || ""), isOnline: pharmacy.isOnline === true,
    isBlocked: pharmacy.isBlocked === true, is24Hours: pharmacy.is24Hours === true,
    pharmacyAcceptingOrders: pharmacyAcceptsNewOrders(pharmacy),
    pharmacyVisible: pharmacyVisibleInSearch(pharmacy),
    latitude: finite(location.latitude ?? pharmacy.latitude),
    longitude: finite(location.longitude ?? pharmacy.longitude),
    acceptedInsuranceCodes: Array.isArray(pharmacy.acceptedInsuranceCodes) ?
      pharmacy.acceptedInsuranceCodes.filter((item) => typeof item === "string") : [],
    medicineName: String(medicine.name || ""), scientificName: String(medicine.scientificName || ""),
    normalizedName: normalize(medicine.name), normalizedScientificName: normalize(medicine.scientificName),
    ...searchTerms(medicine.name, medicine.scientificName),
    category: optionalText(medicine.category), supplier: optionalText(medicine.supplier),
    barcode: optionalText(medicine.barcode), unit: optionalText(medicine.unit),
    sellingPrice, piecePrice, sellByPiece: piecesEnabled,
    quantity: stock?.quantity ?? 0, pieceQuantity: stock?.pieceQuantity ?? 0,
    reservedQuantity: stock?.reservedQuantity ?? 0, reservedPieceQuantity: stock?.reservedPieceQuantity ?? 0,
    unitsPerPackage: stock?.units ?? 0, availableQuantity: stock?.availablePackages ?? 0,
    availablePieceQuantity: stock?.availablePieces ?? 0,
    available: !!stock && sale.saleable && pharmacyVisibleInSearch(pharmacy) &&
      (stock.availablePackages > 0 || (piecesEnabled && stock.availablePieces > 0)),
    isActive: sale.active, isExpired: sale.expired, invalidExpiry: sale.invalidExpiry,
    invalidStock: stock === null,
    isLowStock: medicine.minStockLevel != null && !!stock && stock.quantity <= finite(medicine.minStockLevel),
    expiryDate: sale.expiryMillis === null ? null : new Date(sale.expiryMillis).toISOString(),
    expiryAt: sale.expiryMillis === null ? null : Timestamp.fromMillis(sale.expiryMillis),
    imageUrl: optionalText(medicine.imageUrl),
  };
}

async function refreshMedicineSearchIndex({db, pharmacyId, medicineId, clock = () => Date.now()}) {
  const pharmacyRef = db.collection("pharmacies").doc(pharmacyId);
  const medicineRef = pharmacyRef.collection("medicines").doc(medicineId);
  const indexRef = db.collection("medicine_search_index").doc(`${pharmacyId}_${medicineId}`);
  return db.runTransaction(async (transaction) => {
    // Never trust the event's after snapshot: it can arrive after a newer write.
    const [pharmacy, medicine] = await Promise.all([
      transaction.get(pharmacyRef), transaction.get(medicineRef),
    ]);
    if (!pharmacy.exists || !medicine.exists) {
      transaction.delete(indexRef);
      return {removed: true};
    }
    transaction.set(indexRef, {...buildMedicineSearchIndex({pharmacyId, medicineId,
      pharmacy: pharmacy.data(), medicine: medicine.data(), instant: clock()}),
    updatedAt: FieldValue.serverTimestamp()});
    return {removed: false};
  });
}

function searchProfileChanged(before, after) {
  if (!before || !after) return true;
  const keys = ["pharmacyName", "name", "status", "isActive", "isBlocked", "isOnline", "is24Hours",
    "location", "latitude", "longitude", "acceptedInsuranceCodes"];
  return keys.some((key) => JSON.stringify(before[key] ?? null) !== JSON.stringify(after[key] ?? null));
}

async function refreshPharmacySearchIndex({db, pharmacyId}) {
  let cursor;
  do {
    let query = db.collection("pharmacies").doc(pharmacyId).collection("medicines")
      .orderBy(FieldPath.documentId()).limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const doc of page.docs) await refreshMedicineSearchIndex({db, pharmacyId, medicineId: doc.id});
    cursor = page.size === 100 ? page.docs[page.docs.length - 1] : null;
  } while (cursor);
}

async function refreshExpiredSearchIndexes({db, clock = () => Date.now()}) {
  let cursor;
  let checked = 0;
  const deadline = Timestamp.fromMillis(clock());
  do {
    let query = db.collection("medicine_search_index").where("available", "==", true)
      .where("expiryAt", "<=", deadline).orderBy("expiryAt").orderBy(FieldPath.documentId()).limit(100);
    if (cursor) query = query.startAfter(cursor);
    const page = await query.get();
    for (const doc of page.docs) {
      const {pharmacyId, medicineId} = doc.data();
      if (typeof pharmacyId === "string" && pharmacyId && !pharmacyId.includes("/") &&
          typeof medicineId === "string" && medicineId && !medicineId.includes("/") &&
          doc.id === `${pharmacyId}_${medicineId}`) {
        await refreshMedicineSearchIndex({db, pharmacyId, medicineId, clock});
        checked++;
      }
    }
    cursor = page.size === 100 ? page.docs[page.docs.length - 1] : null;
  } while (cursor);
  return {checked};
}

module.exports = {INDEX_VERSION, buildMedicineSearchIndex, refreshMedicineSearchIndex,
  refreshPharmacySearchIndex, refreshExpiredSearchIndexes, searchProfileChanged};
