"use strict";

const {OrderContractError} = require("./order-contract");
const {stockUnits, reserveUnits, consumeUnits} = require("./stock-units");

function fail(message) {
  throw new OrderContractError("failed-precondition", message);
}

function millis(value) {
  if (value == null) return null;
  const n = value.toMillis ? value.toMillis() : new Date(value).getTime();
  return Number.isFinite(n) ? n : NaN;
}

function saleable(batch, instant) {
  const expiry = millis(batch.expiryDate);
  return batch.isActive !== false && batch.quarantined !== true &&
    (expiry === null || (Number.isFinite(expiry) && expiry > instant));
}

function orderedBatches(stock) {
  const batches = stock.batches.filter((batch) => batch.quarantined !== true);
  const fefo = (a, b) => (millis(a.expiryDate) ?? Infinity) - (millis(b.expiryDate) ?? Infinity) || a.id.localeCompare(b.id);
  if (stock.medicine.batchOrderMode !== "custom" || !Array.isArray(stock.medicine.batchOrder)) {
    return [...batches].sort(fefo);
  }
  const byId = new Map(batches.map((batch) => [batch.id, batch]));
  const custom = stock.medicine.batchOrder.map((id) => byId.get(id)).filter(Boolean);
  const rest = batches.filter((batch) => !stock.medicine.batchOrder.includes(batch.id)).sort(fefo);
  return [...custom, ...rest];
}

// No writes here: callers may load several medicines before planning any write.
// A legacy aggregate is preserved as one explicitly identified opening batch.
async function loadStock(transaction, ref, timestamp, supplied) {
  const snapshot = supplied || await transaction.get(ref);
  if (!snapshot.exists) fail("الصنف غير موجود في المخزون");
  const medicine = snapshot.data();
  const result = await transaction.get(ref.collection("batches"));
  const batches = result.docs.map((doc) => ({id: doc.id, ...doc.data()}));
  if (!batches.length && medicine.batchSchemaVersion !== 1) {
    batches.push({
      id: "legacy-opening", ...stockUnits(medicine),
      unitsPerPackage: Number(medicine.unitsPerPackage || 0),
      expiryDate: medicine.expiryDate || null,
      batchNumber: medicine.batchNumber || "رصيد سابق",
      purchasePrice: Number(medicine.averageCost ?? medicine.purchasePrice ?? 0),
      source: "legacyOpening", createdAt: timestamp,
    });
  }
  for (const batch of batches) {
    batch.unitsPerPackage = Number(batch.unitsPerPackage ?? medicine.unitsPerPackage ?? 0);
    stockUnits(batch);
  }
  if (medicine.batchSchemaVersion === 1) {
    for (const field of ["quantity", "pieceQuantity", "reservedQuantity", "reservedPieceQuantity"]) {
      const total = batches.filter((b) => b.quarantined !== true).reduce((sum, b) => sum + Number(b[field] || 0), 0);
      if (total !== Number(medicine[field] || 0)) fail("إجمالي الصنف لا يطابق دفعاته؛ يلزم تدقيق حركة المخزون");
    }
  }
  return {ref, medicine, batches, changed: new Set(), timestamp,
    migrated: medicine.batchSchemaVersion !== 1};
}

function allocate(stock, packages, pieces, mode = "sell", preferredBatchId = null) {
  if (stock.medicine.isActive === false) fail("الصنف غير فعال");
  if (pieces && (stock.medicine.sellByPiece === false || !stock.medicine.unitsPerPackage)) fail("بيع القطعة غير مفعل لهذا الصنف");
  let remainingPackages = packages;
  let remainingPieces = pieces;
  const allocations = [];
  const sorted = preferredBatchId ?
    orderedBatches(stock).filter((batch) => batch.id === preferredBatchId) : orderedBatches(stock);
  for (const batch of sorted) {
    if (!saleable(batch, stock.timestamp.toMillis())) continue;
    const units = stockUnits(batch);
    const takePackages = Math.min(remainingPackages, units.availablePackages);
    const takePieces = Math.min(remainingPieces, units.availablePieces - takePackages * units.units);
    if (!takePackages && !takePieces) continue;
    const reservation = reserveUnits(batch, takePackages, takePieces);
    Object.assign(batch, mode === "reserve" ? reservation :
      consumeUnits({...batch, ...reservation}, takePackages, takePieces));
    stock.changed.add(batch.id);
    const packagePrice = Number(batch.sellingPrice ?? stock.medicine.sellingPrice ?? 0);
    const piecePrice = Number(batch.piecePrice ??
      (units.units ? packagePrice / units.units : stock.medicine.piecePrice ?? 0));
    allocations.push({medicineId: stock.ref.id, batchId: batch.id,
      packages: takePackages, pieces: takePieces, unitsPerPackage: units.units,
      batchNumber: batch.batchNumber || null, expiryDate: batch.expiryDate || null,
      unitCost: Number(batch.purchasePrice || 0),
      unitPrice: pieces ? piecePrice : packagePrice});
    remainingPackages -= takePackages;
    remainingPieces -= takePieces;
  }
  if (remainingPackages || remainingPieces) fail("الكمية المتاحة في الدفعات الصالحة لا تكفي بعد استبعاد الحجوزات");
  return allocations;
}

function changeReserved(stock, allocations, mode) {
  for (const part of allocations) {
    const batch = stock.batches.find((b) => b.id === part.batchId);
    if (!batch) fail("دفعة الحجز الأصلية غير موجودة");
    const units = stockUnits(batch);
    if (mode === "consume") {
      if (!saleable(batch, stock.timestamp.toMillis()) || stock.medicine.isActive === false) {
        fail("إحدى دفعات الحجز لم تعد صالحة للصرف");
      }
      Object.assign(batch, consumeUnits(batch, part.packages, part.pieces));
    } else {
      if (units.reservedQuantity < part.packages || units.reservedPieceQuantity < part.pieces) {
        fail("كميات الحجز لا تتطابق مع الدفعة");
      }
      batch.reservedQuantity = units.reservedQuantity - part.packages;
      batch.reservedPieceQuantity = units.reservedPieceQuantity - part.pieces;
    }
    stock.changed.add(batch.id);
  }
}

function legacyAllocations(stock, packages, pieces) {
  const legacy = stock.batches.find((b) => b.id === "legacy-opening");
  if (!legacy) fail("الحجز القديم يحتاج إلى مطابقة مع دفعات المخزون");
  return [{medicineId: stock.ref.id, batchId: legacy.id, packages, pieces,
    unitsPerPackage: legacy.unitsPerPackage, unitCost: legacy.purchasePrice || 0,
    batchNumber: legacy.batchNumber || null, expiryDate: legacy.expiryDate || null}];
}

function stockProjection(stock) {
  let quantity = 0; let pieceQuantity = 0;
  let reservedQuantity = 0; let reservedPieceQuantity = 0;
  let availableQuantity = 0; let availablePieceQuantity = 0; let costValue = 0;
  let nextExpiry = null; let earliestStockExpiryDate = null;
  let expiredBatchCount = 0; let nearExpiryBatchCount = 0; let expiredCostValue = 0;
  for (const batch of stock.batches) {
    if (batch.quarantined === true) continue;
    const s = stockUnits(batch);
    quantity += s.quantity; pieceQuantity += s.pieceQuantity;
    reservedQuantity += s.reservedQuantity; reservedPieceQuantity += s.reservedPieceQuantity;
    const value = (s.quantity + (s.units ? s.pieceQuantity / s.units : 0)) * Number(batch.purchasePrice || 0);
    costValue += value;
    const expiry = millis(batch.expiryDate);
    const hasStock = s.quantity > 0 || s.pieceQuantity > 0;
    if (hasStock && expiry !== null && Number.isFinite(expiry)) {
      if (earliestStockExpiryDate === null || expiry < millis(earliestStockExpiryDate)) earliestStockExpiryDate = batch.expiryDate;
      if (expiry <= stock.timestamp.toMillis()) { expiredBatchCount++; expiredCostValue += value; }
      else if (expiry <= stock.timestamp.toMillis() + 30 * 86400000) nearExpiryBatchCount++;
    }
    if (saleable(batch, stock.timestamp.toMillis())) {
      availableQuantity += s.availablePackages;
      availablePieceQuantity += s.availablePieces;
      if (hasStock && expiry !== null && (nextExpiry === null || expiry < millis(nextExpiry))) nextExpiry = batch.expiryDate;
    }
  }
  const packageEquivalent = stock.batches
    .filter((batch) => batch.quarantined !== true)
    .reduce((sum, batch) => {
      const units = stockUnits(batch);
      return sum + units.quantity + (units.units ? units.pieceQuantity / units.units : 0);
    }, 0);
  const averageCost = packageEquivalent > 0 ? costValue / packageEquivalent : 0;
  const priorityBatch = orderedBatches(stock).find((batch) => saleable(batch, stock.timestamp.toMillis()) &&
    (Number(batch.quantity || 0) > 0 || Number(batch.pieceQuantity || 0) > 0));
  return {quantity, pieceQuantity, reservedQuantity, reservedPieceQuantity,
    availableQuantity, availablePieceQuantity, costValue: Math.round(costValue * 100) / 100,
    averageCost: Math.round(averageCost * 1000000) / 1000000,
    earliestStockExpiryDate, expiredBatchCount, nearExpiryBatchCount, expiredCostValue: Math.round(expiredCostValue * 100) / 100,
    expirySummaryVersion: 1,
    batchSchemaVersion: 1, expiryDate: nextExpiry,
    sellingPrice: priorityBatch?.sellingPrice ?? stock.medicine.sellingPrice ?? null,
    piecePrice: priorityBatch?.piecePrice ?? stock.medicine.piecePrice ?? null,
    updatedAt: stock.timestamp,
    lastUpdated: stock.timestamp, reservationUpdatedAt: stock.timestamp};
}

function writeStock(transaction, stock) {
  for (const batch of stock.batches) {
    if (stock.changed.has(batch.id) || (stock.migrated && batch.id === "legacy-opening")) {
      const {id, ...data} = batch;
      transaction.set(stock.ref.collection("batches").doc(id), {...data, updatedAt: stock.timestamp});
    }
  }
  transaction.update(stock.ref, stockProjection(stock));
}

module.exports = {loadStock, allocate, changeReserved, legacyAllocations,
  stockProjection, writeStock, saleable, millis, orderedBatches};
