"use strict";
const {OrderContractError} = require("./order-contract");
const {loadStock, writeStock, saleable, millis} = require("./batch-stock");

function fail(message) { throw new OrderContractError("failed-precondition", message); }
function id(value) {
  if (typeof value !== "string" || !value || value.includes("/") || value.length > 500) fail("معرف المرتجع المعزول غير صالح.");
  return value;
}
function count(value) {
  if (!Number.isSafeInteger(value) || value < 0 || value > 1000000000) fail("كمية المعزول غير صالحة.");
  return value;
}

async function disposeQuarantinedReturn(ctx, payload, {ledger}) {
  const ref = ctx.pharmacy.collection("quarantinedReturns").doc(id(payload.returnId));
  const before = (await ctx.tx.get(ref)).data();
  if (!before) fail("سجل المعزول غير موجود.");
  const reversal = before.reason === "not-saleable-at-reversal";
  if (reversal && typeof payload.soldByPiece !== "boolean") fail("حدد وحدة الكمية المعزولة: عبوة أو قطعة.");
  const piece = reversal ? payload.soldByPiece : before.soldByPiece === true;
  const processedField = reversal && piece ? "processedPieceQuantity" : "processedQuantity";
  const restockedField = reversal && piece ? "restockedPieceQuantity" : "restockedQuantity";
  const disposedField = reversal && piece ? "disposedPieceQuantity" : "disposedQuantity";
  const version = Number(before.version || 0);
  if (!Number.isSafeInteger(payload.expectedVersion) || payload.expectedVersion !== version) fail("تغيرت الكمية المعزولة. أعد فتح السجل وراجع المتبقي.");
  const total = count(reversal && piece ? before.pieceQuantity : before.quantity);
  const processed = count(before[processedField] || 0);
  if (processed !== count(before[restockedField] || 0) + count(before[disposedField] || 0)) fail("مجاميع المعزول تحتاج مطابقة قبل اتخاذ قرار جديد.");
  const quantity = count(payload.quantity);
  if (!quantity || processed + quantity > total) fail("أدخل كمية موجبة لا تتجاوز المتبقي المعزول.");
  const disposition = payload.disposition;
  if (!["restock", "dispose"].includes(disposition)) fail("حدد الإعادة إلى الدفعة أو الاستبعاد النهائي.");
  const reason = String(payload.reason || "").trim();
  if (reason.length < 3 || reason.length > 500) fail("اكتب سبب القرار وفق سياسة الصيدلية، من 3 إلى 500 حرف.");
  const original = (await ctx.tx.get(ctx.pharmacy.collection("sales").doc(id(before.invoiceId)))).data();
  if (!original || original.type === "refund" || original.isDeleted === true) fail("الفاتورة الأصلية غير متاحة للمطابقة.");
  if (reversal ? original.status !== "cancelled" || original.paymentState !== "reversedBeforeDelivery" || original.orderId !== before.orderId :
    original.status !== "completed") fail("حالة الفاتورة الأصلية لا تطابق مصدر الكمية المعزولة.");
  const refundId = reversal ? original.reversalId : before.refundId;
  const refund = (await ctx.tx.get(ctx.pharmacy.collection("sales").doc(id(refundId)))).data();
  if (!refund || refund.type !== "refund" || refund.status !== "completed" || refund.isDeleted === true || refund.refSaleId !== before.invoiceId ||
    (reversal && (refund.source !== "orderReversal" || refund.orderId !== before.orderId))) {
    fail("فاتورة المرتجع المرتبطة غير معتمدة أو لا تطابق سجل المعزول.");
  }
  const allocations = reversal ? (original.batchAllocations || []).filter((part) =>
    part.medicineId === before.medicineId && part.batchId === before.batchId) : before.batchAllocations || [];
  const traced = reversal ? allocations.length > 0 &&
    allocations.reduce((sum, part) => sum + count(part.packages), 0) === count(before.quantity) &&
    allocations.reduce((sum, part) => sum + count(part.pieces), 0) === count(before.pieceQuantity) : before.batchTraceStatus === "allocated";
  if (reversal && allocations.length && !traced) fail("تتبع فاتورة الطلب لا يطابق عبوات وقطع المعزول. يلزم مطابقة السجل.");
  let skip = processed; let remaining = quantity; let cost = 0; let priorCost = 0;
  const selected = [];
  for (const part of allocations) {
    const allocated = count(piece ? part.pieces : part.packages);
    const ignored = Math.min(skip, allocated); skip -= ignored;
    const taken = Math.min(remaining, allocated - ignored);
    if (!taken && !ignored) continue;
    const units = Number(part.unitsPerPackage || 0);
    const unitCost = Number(part.unitCost);
    if (!Number.isFinite(unitCost) || unitCost < 0 || (piece && (!Number.isSafeInteger(units) || units <= 0))) fail("تكلفة أو وحدة الدفعة الأصلية غير صالحة؛ يلزم مطابقة السجل.");
    priorCost += ignored * unitCost / (piece ? units : 1);
    if (!taken) continue;
    cost += taken * unitCost / (piece ? units : 1);
    selected.push({...part, packages: piece ? 0 : taken, pieces: piece ? taken : 0});
    remaining -= taken;
  }
  if (disposition === "restock" && (remaining || !traced)) {
    fail("لا يمكن إعادة مرتجع دون تتبع كامل للدفعة الأصلية. يبقى معزولًا أو يُستبعد بقرار موثق.");
  }
  let stock = null;
  if (disposition === "restock") {
    stock = await loadStock(ctx.tx, ctx.pharmacy.collection("medicines").doc(id(before.medicineId)), ctx.timestamp);
    if (stock.medicine.isActive === false || stock.medicine.isDeleted === true) fail("الدواء غير فعال. لا يمكن إعادته إلى المتاح.");
    for (const part of selected) {
      const batch = stock.batches.find((row) => row.id === part.batchId);
      if (!batch || !saleable(batch, ctx.timestamp.toMillis()) || (part.expiryDate &&
          (!Number.isFinite(millis(part.expiryDate)) || millis(part.expiryDate) <= ctx.timestamp.toMillis()))) {
        fail("الدفعة الأصلية غير موجودة أو غير صالحة للبيع. لا يمكن إعادة الكمية إلى المتاح.");
      }
      if (Number(batch.unitsPerPackage || 0) !== Number(part.unitsPerPackage || 0) ||
          Number(batch.purchasePrice || 0) !== Number(part.unitCost || 0)) fail("تغيرت وحدة أو تكلفة الدفعة الأصلية؛ يلزم مطابقتها قبل إعادة الكمية.");
      batch.quantity = count(Number(batch.quantity || 0) + part.packages);
      batch.pieceQuantity = count(Number(batch.pieceQuantity || 0) + part.pieces);
      stock.changed.add(batch.id);
    }
    writeStock(ctx.tx, stock);
  }
  // Allocate the rounding remainder across successive decisions, so splitting
  // three pieces of a one-dinar pack still accounts for exactly one dinar.
  const amount = (Math.round((priorCost + cost) * 100) - Math.round(priorCost * 100)) / 100;
  if (!Number.isFinite(amount) || amount < 0 || amount > 1e12) fail("تكلفة الكمية المعزولة تتجاوز الدقة المالية المسموحة.");
  const decisionId = `disposition-${ctx.key}`;
  const otherRemaining = reversal ? count(piece ? before.quantity : before.pieceQuantity) -
    count(before[piece ? "processedQuantity" : "processedPieceQuantity"] || 0) : 0;
  if (otherRemaining < 0) fail("المعالج من الوحدة الأخرى يتجاوز كميتها المعزولة.");
  const newValues = {[processedField]: processed + quantity,
    [restockedField]: count(before[restockedField] || 0) + (disposition === "restock" ? quantity : 0),
    [disposedField]: count(before[disposedField] || 0) + (disposition === "dispose" ? quantity : 0),
    status: processed + quantity === total && otherRemaining === 0 ? "resolved" : "partial", version: version + 1,
    updatedAt: ctx.timestamp, lastDecisionId: decisionId};
  const decision = {decisionId, returnId: ref.id, medicineId: before.medicineId, refundId,
    invoiceId: before.invoiceId, disposition, quantity, soldByPiece: piece, reason, batchAllocations: selected,
    valuationComplete: remaining === 0, costAmount: amount, createdAt: ctx.timestamp,
    createdBy: ctx.actor.id, createdByActor: {id: ctx.actor.id, type: ctx.actor.type}, operationId: ctx.operationId};
  ctx.tx.create(ref.collection("dispositions").doc(decisionId), decision);
  ctx.tx.update(ref, newValues);
  ledger(ctx, "quarantine", {type: disposition === "restock" ? "inventoryAdjustment" : "inventoryLoss",
    accountType: disposition === "restock" ? "inventory" : "inventoryLoss", direction: "neutral", amount,
    referenceId: ref.id, referenceCollection: "quarantinedReturns", title: disposition === "restock" ? "إعادة مرتجع معزول إلى دفعته" : "استبعاد مرتجع معزول",
    metadata: {source: "quarantineDisposition", operationId: ctx.operationId, decisionId, refundId,
      medicineId: before.medicineId, quantity, soldByPiece: piece, disposition, reason, cashMovement: false,
      valuationComplete: remaining === 0, cogsReversal: !reversal && disposition === "restock" ? amount : 0,
      // Delivered returns retain their original COGS until restocked. An
      // undelivered cancelled order has no recognized COGS to expense twice.
      additionalExpense: reversal && disposition === "dispose"}});
  ctx.audit = {module: "inventory", targetType: "quarantinedReturn", targetId: ref.id,
    targetName: String(stock?.medicine.name || before.medicineId), source: "server", entityPath: ref.path,
    details: {oldValues: {[processedField]: processed, version}, newValues, decision}};
  return {returnId: ref.id, decisionId, remainingQuantity: total - processed - quantity, version: version + 1};
}

module.exports = {disposeQuarantinedReturn};
