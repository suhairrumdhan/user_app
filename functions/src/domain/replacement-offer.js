"use strict";

const {OrderContractError} = require("./order-contract");
const key = (id, piece) => `${String(id || "").trim()}:${piece === true}`;

function replacementItems(order, rawItems, reason) {
  if (!String(reason || "").trim()) throw new OrderContractError("invalid-argument", "Replacement reason is required.");
  if (!Array.isArray(rawItems) || !rawItems.length) throw new OrderContractError("invalid-argument", "Replacement offer items are required.");
  const originals = new Map();
  for (const line of order.medicines || []) {
    const id = line.matchedMedicineId || line.medicineId;
    const sourceKey = key(id, line.soldByPiece);
    const prior = originals.get(sourceKey);
    originals.set(sourceKey, {...line, medicineId: String(id || "").trim(),
      quantity: Number(line.quantity) + Number(prior?.quantity || 0)});
  }
  const seen = new Set();
  const items = rawItems.map((line) => {
    const id = String(line.medicineId || line.matchedMedicineId || "").trim();
    const sourceId = String(line.replacesMedicineId || id).trim();
    const sourcePiece = line.replacesSoldByPiece === true;
    const sourceKey = key(sourceId, sourcePiece);
    const original = originals.get(sourceKey);
    const replaced = id !== sourceId || (line.soldByPiece === true) !== sourcePiece;
    if (!original || seen.has(sourceKey) || !id || id.includes("/") ||
        !Number.isSafeInteger(line.quantity) || line.quantity < 1 || line.quantity > 10000 ||
        (!replaced && line.quantity > original.quantity)) {
      throw new OrderContractError("invalid-argument", "Invalid replacement source, unit or quantity.");
    }
    seen.add(sourceKey);
    return {...original, medicineId: id, matchedMedicineId: id, soldByPiece: line.soldByPiece === true,
      quantity: line.quantity, replacesMedicineId: sourceId, replacesSoldByPiece: sourcePiece,
      originalMedicineName: original.matchedMedicineName || original.medicineName || original.requestedName || sourceId,
      originalImageUrl: original.imageUrl || null, originalQuantity: original.quantity, isReplacement: replaced, replacementReason: String(reason).trim()};
  });
  if (!items.some((item) => item.isReplacement) && order.partialOffer?.kind !== "replacement") {
    throw new OrderContractError("invalid-argument", "Select at least one replacement medicine or unit.");
  }
  return items;
}

function snapshotReplacementNames(items, plans) {
  return items.map((item) => {
    const medicine = plans.find(({demand}) => demand.medicineId === item.medicineId)?.stock.medicine;
    if (item.isReplacement && !String(medicine?.name || "").trim()) {
      throw new OrderContractError("failed-precondition", "Replacement medicine must have a stock name.");
    }
    const name = medicine?.name || item.originalMedicineName;
    return {...item, medicineName: name, matchedMedicineName: name,
      ...(item.isReplacement ? {strength: null, dosageForm: null, imageUrl: medicine.imageUrl || null,
        scientificName: medicine.scientificName || null} : {}),
      unit: item.soldByPiece ? "piece" : "package"};
  });
}

function previewInvoiceReturn(plans, invoice, timestamp, saleable) {
  for (const {demand, stock} of plans) {
    for (const part of invoice.batchAllocations || []) {
      if (part.medicineId !== demand.medicineId) continue;
      const batch = stock.batches.find((value) => value.id === part.batchId);
      if (!batch) throw new OrderContractError("failed-precondition", "Original invoice batch is missing.");
      if (stock.medicine.isActive !== false && saleable(batch, timestamp.toMillis())) {
        batch.quantity += part.packages;
        batch.pieceQuantity += part.pieces;
        stock.changed.add(batch.id);
      }
    }
  }
}

module.exports = {replacementItems, snapshotReplacementNames, previewInvoiceReturn};
