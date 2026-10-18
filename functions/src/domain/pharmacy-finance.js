"use strict";

const {Timestamp, FieldValue} = require("firebase-admin/firestore");
const {createHash} = require("node:crypto");
const {resolvePharmacyPrincipal, permissionAllowed} = require("../auth/authorization");
const {payloadHash, operationDocumentId} = require("../common/idempotency");
const {OrderContractError} = require("./order-contract");
const {loadStock, allocate, writeStock, stockProjection, millis, orderedBatches} = require("./batch-stock");
const {stockUnits} = require("./stock-units");
const {refundDeliveredOrder} = require("./order-ledger");
const {savePharmacyRole} = require("./pharmacy-roles");
const {postPayroll} = require("./pharmacy-payroll");
const {disposeQuarantinedReturn} = require("./quarantine");

function fail(message, code = "failed-precondition") { throw new OrderContractError(code, message); }
function text(value) { return String(value ?? "").trim(); }
function id(value) {
  const result = text(value);
  if (!result || result.includes("/") || result.length > 500) fail("معرف غير صالح", "invalid-argument");
  return result;
}
function money(value = 0) {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > 1e12) {
    fail("قيمة مالية غير صالحة", "invalid-argument");
  }
  return Math.round(value * 100);
}
function count(value = 0) {
  if (!Number.isSafeInteger(value) || value < 0 || value > 1000000000) fail("الكمية غير صالحة", "invalid-argument");
  return value;
}
function date(value, fallback = null) {
  if (value == null) return fallback;
  const time = millis(value);
  if (!Number.isFinite(time)) fail("التاريخ غير صالح", "invalid-argument");
  return Timestamp.fromMillis(time);
}
function method(value) {
  const aliases = {"نقدي": "cash", "كاش": "cash", "بطاقة": "card", "معاملة مصرفية": "bank",
    "تحويل": "bank", "تحويل بنكي": "bank", "شيك": "bank", "بنك": "bank", transfer: "bank", bank_transfer: "bank"};
  const result = aliases[value] || value;
  if (!["cash", "card", "bank"].includes(result)) fail("طريقة الدفع غير صالحة", "invalid-argument");
  return result;
}
async function requirePermission(ctx, permission) {
  return resolvePharmacyPrincipal({db: ctx.db, auth: ctx.auth, pharmacyId: ctx.pharmacy.id,
    permission, instant: ctx.timestamp.toMillis(), transaction: ctx.tx});
}
function ledger(ctx, suffix, data) {
  const transactionId = `${ctx.key}-${suffix}`;
  ctx.tx.create(ctx.pharmacy.collection("financial_transactions").doc(transactionId), {
    pharmacyId: ctx.pharmacy.id, currency: "LYD", amount: 0, isPosted: true, isVoided: false,
    createdBy: ctx.actor.id, createdByActor: {id: ctx.actor.id, type: ctx.actor.type},
    operationId: ctx.operationId, transactionDate: ctx.timestamp, createdAt: ctx.timestamp,
    postedAt: ctx.timestamp, metadata: {source: "pharmacyFinance", operationId: ctx.operationId}, ...data,
  });
  return transactionId;
}
function insuranceLedger(ctx, suffix, data) {
  ctx.tx.create(ctx.pharmacy.collection("insurance_ledger").doc(`${ctx.key}-${suffix}`), {
    ...data, operationId: ctx.operationId, createdBy: ctx.actor.id,
    createdAt: ctx.timestamp, pharmacyId: ctx.pharmacy.id,
  });
}
async function openShift(ctx, shiftId) {
  const ref = ctx.pharmacy.collection("shifts").doc(id(shiftId));
  const snapshot = await ctx.tx.get(ref);
  const actorKey = `${ctx.actor.type === "employee" ? "employee" : "owner"}:${ctx.actor.id}`;
  const state = await ctx.tx.get(ctx.pharmacy.collection("shift_states").doc(actorKey));
  const data = snapshot.data();
  if (!data || data.status !== "open" || data.isFinanciallyClosed === true ||
      data.pharmacyId !== ctx.pharmacy.id || data.openedByKey !== actorKey ||
      state.data()?.activeShiftId !== ref.id) fail("الوردية مغلقة أو لا تخص المستخدم الحالي");
  return {ref, data};
}
function addAmount(data, field, delta) { return (money(data[field] ?? 0) + delta) / 100; }

async function supplierSummary(ctx, supplierId, invoices) {
  const ref = ctx.pharmacy.collection("suppliers").doc(id(supplierId));
  const snapshot = await ctx.tx.get(ref);
  if (!snapshot.exists) fail("المورد غير موجود");
  const docs = invoices || (await ctx.tx.get(ctx.pharmacy.collection("purchase_invoices")
    .where("supplierId", "==", supplierId))).docs.map((doc) => ({id: doc.id, ...doc.data()}));
  return {ref, data: snapshot.data(), invoices: docs};
}
function writeSupplier(ctx, supplier, replacement) {
  const invoices = supplier.invoices.filter((v) => v.id !== replacement.id).concat(replacement)
    .filter((v) => !["cancelled", "draft"].includes(v.status));
  let purchases = 0; let paid = 0; let due = 0; let overdue = 0; let unpaidCount = 0; let overdueCount = 0;
  for (const invoice of invoices) {
    const total = money(invoice.total); const received = money(invoice.paid ?? 0);
    if (received > total) fail("مدفوعات المورد السابقة تحتاج إلى مطابقة");
    if (invoice.source !== "openingBalance") purchases += total;
    paid += received; due += total - received;
    if (total > received) {
      unpaidCount++;
      if (invoice.dueDate && millis(invoice.dueDate) < ctx.timestamp.toMillis()) {
        overdue += total - received; overdueCount++;
      }
    }
  }
  const opening = supplier.invoices.some((v) => v.source === "openingBalance") ? 0 : money(supplier.data.openingBalance ?? 0);
  ctx.tx.update(supplier.ref, {totalPurchases: purchases / 100, totalPaid: paid / 100,
    totalDue: (opening + due) / 100, currentBalance: (opening + due) / 100,
    outstandingBalance: (opening + due) / 100, overdueBalance: overdue / 100,
    unpaidInvoicesCount: unpaidCount, overdueInvoicesCount: overdueCount,
    updatedAt: ctx.timestamp});
}

async function receivePurchase(ctx, payload) {
  const entries = payload.stockEntries; const items = payload.items;
  if (!Array.isArray(entries) || !Array.isArray(items) || !entries.length ||
      entries.length !== items.length || entries.length > 100) fail("بنود المشتريات غير مكتملة", "invalid-argument");
  // New clients keep this key stable across network retries. Legacy callers
  // still receive operation-level idempotency instead of failing outright.
  const clientDraftId = text(payload.clientDraftId) || `operation-${ctx.operationId}`;
  if (clientDraftId.length < 16 || clientDraftId.length > 200 || clientDraftId.includes("/")) {
    fail("معرف مسودة فاتورة الشراء غير صالح", "invalid-argument");
  }
  const submissionId = createHash("sha256").update(`${ctx.actor.id}:${clientDraftId}`).digest("hex").slice(0, 40);
  const submissionRef = ctx.pharmacy.collection("purchase_submission_keys").doc(submissionId);
  const previousSubmission = await ctx.tx.get(submissionRef);
  if (previousSubmission.exists) {
    const previous = previousSubmission.data();
    if (previous.payloadHash !== ctx.requestHash) fail("معرف مسودة الشراء استُخدم ببيانات مختلفة. افتح فاتورة جديدة.");
    const previousInvoiceId = id(previous.invoiceId);
    const previousInvoice = await ctx.tx.get(ctx.pharmacy.collection("purchase_invoices").doc(previousInvoiceId));
    if (!previousInvoice.exists) fail("مفتاح فاتورة الشراء لا يطابق سجلًا معتمدًا؛ يلزم تدقيق البيانات.");
    ctx.skipBusinessAudit = true;
    return {invoiceId: previousInvoiceId, invoiceNumber: previous.invoiceNumber, alreadyCommitted: true};
  }
  if (money(payload.discount ?? 0) !== 0) fail("الخصم غير معتمد في فاتورة الشراء.", "invalid-argument");
  const supplier = await supplierSummary(ctx, id(payload.supplierId));
  const stocks = new Map();
  for (const entry of entries) {
    const medicineId = id(entry.medicineId);
    if (!stocks.has(medicineId)) stocks.set(medicineId,
      await loadStock(ctx.tx, ctx.pharmacy.collection("medicines").doc(medicineId), ctx.timestamp));
  }
  const invoiceId = `purchase-${submissionId}`;
  const counterRef = ctx.pharmacy.collection("purchase_counters").doc("sequence");
  const counter = await ctx.tx.get(counterRef);
  const sequence = count(counter.data()?.value ?? 0) + 1;
  const invoiceNumber = `PINV-${ctx.timestamp.toDate().getUTCFullYear()}-${String(sequence).padStart(6, "0")}`;
  let subtotal = 0;
  const lines = entries.map((entry, index) => {
    const item = items[index]; const stock = stocks.get(entry.medicineId);
    const packages = count(entry.packageQty); const pieces = count(entry.pieceQty);
    const free = count(item.freeQuantity ?? 0); const qty = count(item.quantity);
    const purchaseUnit = text(entry.purchaseUnit || (pieces ? "piece" : "package"));
    const packagesPerBox = purchaseUnit === "box" ? count(entry.packagesPerBox) : 1;
    const expectedPackages = purchaseUnit === "box" ? qty * packagesPerBox : purchaseUnit === "package" ? qty : 0;
    const expectedPieces = purchaseUnit === "piece" ? qty : 0;
    if (!Number.isSafeInteger(expectedPackages) || expectedPackages > 1000000000) {
      fail("عدد العبوات الناتج من الصناديق غير صالح", "invalid-argument");
    }
    if (!["box", "package", "piece"].includes(purchaseUnit) || free !== 0 ||
        (!packages && !pieces) || (packages && pieces) || !qty ||
        item.medicineId !== entry.medicineId || packages !== expectedPackages || pieces !== expectedPieces) {
      fail("كمية الدفعة لا تطابق بند الفاتورة", "invalid-argument");
    }
    const price = money(item.price);
    if (!price) fail("تكلفة وحدة الشراء يجب أن تكون أكبر من صفر", "invalid-argument");
    if (price !== money(entry.purchasePrice)) fail("تكلفة الدفعة لا تطابق سعر الشراء");
    const lineDiscount = money(item.itemDiscount ?? 0);
    if (lineDiscount !== 0) fail("خصم الصنف غير معتمد في فاتورة الشراء.", "invalid-argument");
    const net = price * qty; subtotal += net;
    const configuredUnits = count(stock.medicine.unitsPerPackage ?? 0);
    const receivedUnits = entry.unitsPerPackage == null ? 0 : count(entry.unitsPerPackage);
    const units = configuredUnits || receivedUnits;
    if (configuredUnits && receivedUnits && configuredUnits !== receivedUnits) {
      fail("لا يمكن تغيير وحدة المخزون من فاتورة الشراء");
    }
    if (pieces && (!units || stock.medicine.sellByPiece !== true)) fail("إعداد بيع القطعة غير مكتمل");
    const expiryDate = date(entry.expiryDate ?? item.expiryDate);
    if (expiryDate && expiryDate.toMillis() <= ctx.timestamp.toMillis()) fail("لا يمكن استلام دفعة منتهية الصلاحية");
    const batchId = `${invoiceId}-${index}`;
    const unitCost = net / 100 / (packages || pieces) * (purchaseUnit === "piece" ? units : 1);
    stock.batches.push({id: batchId, quantity: packages, pieceQuantity: pieces,
      reservedQuantity: 0, reservedPieceQuantity: 0, unitsPerPackage: units,
      purchasePrice: unitCost, expiryDate, batchNumber: text(entry.batchNumber || item.batchNumber) || batchId,
      sellingPrice: entry.sellingPrice == null ? Number(stock.medicine.sellingPrice || 0) : money(entry.sellingPrice) / 100,
      piecePrice: entry.piecePrice == null ? Number(stock.medicine.piecePrice || 0) : money(entry.piecePrice) / 100,
      purchaseInvoiceId: invoiceId, supplierId: supplier.ref.id, supplierName: supplier.data.name || null,
      receivedAt: ctx.timestamp});
    stock.changed.add(batchId);
    return {...item, quantity: qty, price: price / 100, freeQuantity: free,
      itemDiscount: 0, subtotal: net / 100, batchId, purchaseUnit,
      packagesPerBox: purchaseUnit === "box" ? packagesPerBox : null,
      receivedPackageQuantity: packages, receivedPieceQuantity: pieces, unitsPerPackage: units,
      expiryDate, medicineName: text(stock.medicine.name), supplierId: supplier.ref.id};
  });
  const discount = 0;
  const initialPaid = money(payload.initialPaymentAmount ?? 0);
  if (initialPaid > subtotal - discount) fail("الدفعة الأولى تتجاوز إجمالي الفاتورة");
  const initialMethod = initialPaid ? method(payload.paymentMethod) : null;
  if (initialPaid) await requirePermission(ctx, "purchases.payment");
  const initialShift = initialPaid && payload.shiftId ? await openShift(ctx, payload.shiftId) : null;
  // Receiving stock must not silently discard edited prices from the purchase form.
  const metadataChanges = new Map();
  for (const entry of entries) {
    const stock = stocks.get(entry.medicineId);
    const changes = metadataChanges.get(entry.medicineId) || {};
    // Selling prices belong to the received batch. Keep only product-wide
    // configuration here; stockProjection exposes the current priority price.
    for (const field of ["sellByPiece", "barcode", "unitsPerPackage"]) {
      if (entry[field] == null || entry[field] === stock.medicine[field]) continue;
      if (field.endsWith("Price")) money(entry[field]);
      if (field === "sellByPiece" && typeof entry[field] !== "boolean") fail("إعداد وحدة البيع غير صالح");
      if (field === "unitsPerPackage" && !count(entry[field])) fail("عدد القطع داخل العبوة غير صالح");
      if (changes[field] !== undefined && changes[field] !== entry[field]) fail("إعدادات الصنف متعارضة بين بنود الفاتورة");
      changes[field] = entry[field];
    }
    if (Object.keys(changes).length) metadataChanges.set(entry.medicineId, changes);
  }
  if (metadataChanges.size) await requirePermission(ctx, "inventory.update");
  const invoice = {id: invoiceId, invoiceNumber, supplierId: supplier.ref.id,
    supplierName: text(supplier.data.name), items: lines, stockEntries: entries,
    invoiceDate: date(payload.invoiceDate, ctx.timestamp), receivedDate: ctx.timestamp,
    dueDate: date(payload.dueDate), subtotal: subtotal / 100, discount: discount / 100,
    total: (subtotal - discount) / 100, paid: 0, cashPaid: 0, bankPaid: 0,
    remainingAmount: (subtotal - discount) / 100, paymentStatus: subtotal === discount ? "paid" : "unpaid",
    status: "received", financialPosted: true, inventoryPosted: true,
    financialTransactionId: `${ctx.key}-purchase`, postedAt: ctx.timestamp,
    operationId: ctx.operationId, clientDraftId, submissionId, createdBy: ctx.actor.id, createdAt: ctx.timestamp,
    notes: text(payload.notes), referenceNumber: text(payload.referenceNumber)};
  if (initialPaid) Object.assign(invoice, {paid: initialPaid / 100,
    remainingAmount: (subtotal - discount - initialPaid) / 100,
    cashPaid: initialMethod === "cash" ? initialPaid / 100 : 0,
    bankPaid: initialMethod !== "cash" ? initialPaid / 100 : 0,
    paymentMethod: initialMethod, paymentCount: 1, lastPaidAt: ctx.timestamp,
    paymentStatus: initialPaid === subtotal - discount ? "paid" : "partiallyPaid",
    lastPaymentTransactionId: `${ctx.key}-supplier`});
  for (const stock of stocks.values()) {
    writeStock(ctx.tx, stock);
    if (metadataChanges.has(stock.ref.id)) ctx.tx.update(stock.ref, metadataChanges.get(stock.ref.id));
  }
  ctx.tx.set(counterRef, {value: sequence, updatedAt: ctx.timestamp});
  ctx.tx.create(ctx.pharmacy.collection("purchase_invoices").doc(invoiceId), invoice);
  ctx.tx.create(submissionRef, {invoiceId, invoiceNumber, payloadHash: ctx.requestHash,
    createdAt: ctx.timestamp, createdBy: ctx.actor.id});
  ledger(ctx, "purchase", {type: "purchaseInvoice", accountType: "supplierPayable", direction: "payable",
    amount: invoice.total, supplierId: invoice.supplierId, supplierName: invoice.supplierName,
    referenceId: invoiceId, referenceCollection: "purchase_invoices", referenceNumber: invoiceNumber,
    title: "استلام مشتريات وإثبات التزام المورد"});
  if (initialPaid) {
    const paymentId = `${ctx.key}-payment`;
    ctx.tx.create(ctx.pharmacy.collection("purchase_invoices").doc(invoiceId).collection("payments").doc(paymentId), {
      id: paymentId, invoiceId, supplierId: invoice.supplierId, amount: initialPaid / 100,
      paymentMethod: initialMethod, previousPaid: 0, newPaid: initialPaid / 100,
      remainingAmount: invoice.remainingAmount, sequence: 1, operationId: ctx.operationId,
      createdBy: ctx.actor.id, paidAt: ctx.timestamp, shiftId: initialShift?.ref.id || null,
      financialTransactionId: `${ctx.key}-supplier`,
    });
    ledger(ctx, "supplier", {type: "supplierPayment", accountType: "supplierPayable", direction: "outflow",
      amount: initialPaid / 100, paymentMethod: initialMethod, supplierId: invoice.supplierId,
      supplierName: invoice.supplierName, referenceId: invoiceId, referenceCollection: "purchase_invoices",
      referenceNumber: invoiceNumber, shiftId: initialShift?.ref.id || null, title: "دفعة أولى عند استلام مشتريات",
      metadata: {paymentId, sequence: 1}});
    if (initialShift && initialMethod === "cash") ctx.tx.update(initialShift.ref,
      {supplierPayments: addAmount(initialShift.data, "supplierPayments", initialPaid), updatedAt: ctx.timestamp});
  }
  writeSupplier(ctx, supplier, invoice);
  return {invoiceId, invoiceNumber};
}

async function payPurchase(ctx, payload) {
  const ref = ctx.pharmacy.collection("purchase_invoices").doc(id(payload.invoiceId));
  const snapshot = await ctx.tx.get(ref); const invoice = snapshot.data();
  if (!invoice || ["cancelled", "draft"].includes(invoice.status)) fail("الفاتورة غير متاحة للسداد");
  const amount = money(payload.amount); const paymentMethod = method(payload.paymentMethod);
  const previousPaid = money(invoice.paid ?? 0); const total = money(invoice.total);
  if (!amount || previousPaid + amount > total) fail("الدفعة يجب أن تكون موجبة ولا تتجاوز المتبقي");
  const supplier = await supplierSummary(ctx, invoice.supplierId);
  const shift = payload.shiftId ? await openShift(ctx, payload.shiftId) : null;
  const paymentId = `${ctx.key}-payment`; const paid = previousPaid + amount;
  const update = {paid: paid / 100, remainingAmount: (total - paid) / 100,
    cashPaid: addAmount(invoice, "cashPaid", paymentMethod === "cash" ? amount : 0),
    bankPaid: addAmount(invoice, "bankPaid", paymentMethod !== "cash" ? amount : 0),
    paymentStatus: paid === total ? "paid" : "partiallyPaid", paymentMethod,
    paymentCount: count(invoice.paymentCount ?? 0) + 1, lastPaymentTransactionId: `${ctx.key}-supplier`,
    lastPaidAt: ctx.timestamp, updatedAt: ctx.timestamp};
  const payment = {id: paymentId, invoiceId: ref.id, supplierId: invoice.supplierId,
    amount: amount / 100, paymentMethod, previousPaid: previousPaid / 100, newPaid: paid / 100,
    remainingAmount: update.remainingAmount, sequence: update.paymentCount,
    operationId: ctx.operationId, createdBy: ctx.actor.id, paidAt: ctx.timestamp,
    shiftId: shift?.ref.id || null, financialTransactionId: `${ctx.key}-supplier`};
  ctx.tx.create(ref.collection("payments").doc(paymentId), payment);
  ctx.tx.update(ref, update);
  ledger(ctx, "supplier", {type: "supplierPayment", accountType: "supplierPayable", direction: "outflow",
    amount: amount / 100, paymentMethod, supplierId: invoice.supplierId, supplierName: invoice.supplierName,
    referenceId: ref.id, referenceCollection: "purchase_invoices", referenceNumber: invoice.invoiceNumber,
    shiftId: shift?.ref.id || null, title: "سداد فاتورة مورد", metadata: {paymentId, sequence: update.paymentCount}});
  if (shift && paymentMethod === "cash") ctx.tx.update(shift.ref,
    {supplierPayments: addAmount(shift.data, "supplierPayments", amount), updatedAt: ctx.timestamp});
  writeSupplier(ctx, supplier, {...invoice, ...update, id: ref.id});
  return {invoiceId: ref.id, paymentId};
}

async function reversePurchase(ctx, payload) {
  const ref = ctx.pharmacy.collection("purchase_invoices").doc(id(payload.invoiceId));
  const snapshot = await ctx.tx.get(ref); const invoice = snapshot.data();
  if (!invoice) fail("الفاتورة غير موجودة");
  if (invoice.source === "openingBalance") fail("الرصيد الافتتاحي يُصحح بقيد تسوية ولا يعكس كاستلام مشتريات");
  if (invoice.status === "cancelled") return {invoiceId: ref.id};
  if (money(invoice.paid ?? 0) > 0) fail("الفاتورة مسددة كليًا أو جزئيًا؛ يلزم تسوية الدفعات قبل عكسها");
  const supplier = await supplierSummary(ctx, invoice.supplierId);
  const stocks = new Map();
  for (const item of invoice.items || []) {
    if (!item.batchId) fail("الفاتورة القديمة تحتاج إلى مطابقة دفعاتها قبل العكس");
    if (!stocks.has(item.medicineId)) stocks.set(item.medicineId,
      await loadStock(ctx.tx, ctx.pharmacy.collection("medicines").doc(item.medicineId), ctx.timestamp));
  }
  for (const item of invoice.items) {
    const stock = stocks.get(item.medicineId); const batch = stock.batches.find((v) => v.id === item.batchId);
    const expectedPackages = count(item.receivedPackageQuantity ??
      (item.purchaseUnit === "box" ? count(item.quantity) * count(item.packagesPerBox) :
        item.purchaseUnit === "piece" ? 0 : count(item.quantity) + count(item.freeQuantity ?? 0)));
    const expectedPieces = count(item.receivedPieceQuantity ??
      (item.purchaseUnit === "piece" ? count(item.quantity) + count(item.freeQuantity ?? 0) : 0));
    if (!batch || count(batch.reservedQuantity) || count(batch.reservedPieceQuantity) ||
        batch.quantity !== expectedPackages || batch.pieceQuantity !== expectedPieces) {
      fail("استُخدمت أو حُجزت دفعة من الفاتورة؛ لا يمكن عكس استلامها بالكامل");
    }
    batch.quantity = 0; batch.pieceQuantity = 0; batch.reversedAt = ctx.timestamp;
    stock.changed.add(batch.id);
  }
  for (const stock of stocks.values()) writeStock(ctx.tx, stock);
  ctx.tx.update(ref, {status: "cancelled", reversedAt: ctx.timestamp, reversedBy: ctx.actor.id,
    reversalTransactionId: `${ctx.key}-purchase-reversal`, remainingAmount: 0});
  ledger(ctx, "purchase-reversal", {type: "purchaseReversal", accountType: "supplierPayable",
    direction: "receivable", amount: invoice.total, referenceId: ref.id,
    referenceCollection: "purchase_invoices", supplierId: invoice.supplierId,
    title: "عكس استلام مشتريات", metadata: {reverses: invoice.financialTransactionId}});
  writeSupplier(ctx, supplier, {...invoice, id: ref.id, status: "cancelled"});
  return {invoiceId: ref.id};
}

async function linkMedicineSupplier(ctx, medicineId, oldId, newId) {
  if (text(oldId) === text(newId)) return;
  for (const supplierId of new Set([text(oldId), text(newId)].filter(Boolean))) {
    const ref = ctx.pharmacy.collection("suppliers").doc(id(supplierId));
    if (!ctx.supplierLinks.has(supplierId)) {
      const snapshot = await ctx.tx.get(ref);
      if (!snapshot.exists) {
        if (supplierId === text(newId)) fail("المورد المحدد غير موجود");
        continue;
      }
      const data = snapshot.data();
      if (supplierId === text(newId) && data.isActive === false) fail("المورد المحدد مؤرشف");
      ctx.supplierLinks.set(supplierId, {ref, ids: new Set(data.suppliedMedications || [])});
    }
    const link = ctx.supplierLinks.get(supplierId);
    if (supplierId === text(newId)) link.ids.add(medicineId);
    else link.ids.delete(medicineId);
  }
}

async function saveMedicine(ctx, payload, command) {
  const medicineId = payload.medicineId ? id(payload.medicineId) : `medicine-${ctx.key}`;
  const ref = ctx.pharmacy.collection("medicines").doc(medicineId);
  const snapshot = await ctx.tx.get(ref); const old = snapshot.data();
  if (command === "createMedicine" && old) fail("الصنف موجود بالفعل؛ استخدم التعديل");
  if (command !== "createMedicine" && !old) fail("الصنف غير موجود");
  if (command === "deleteMedicine") {
    const stock = await loadStock(ctx.tx, ref, ctx.timestamp, snapshot);
    if (stock.batches.some((b) => b.reservedQuantity || b.reservedPieceQuantity)) fail("الصنف مرتبط بحجوزات نشطة");
    ctx.tx.update(ref, {isActive: false, archivedAt: ctx.timestamp, archivedBy: ctx.actor.id});
    return {medicineId};
  }
  const input = payload.medicine || {};
  const fields = ["name", "scientificName", "description", "category", "purchasePrice", "sellingPrice", "unit",
    "unitsPerPackage", "sellByPiece", "piecePrice", "minStockLevel", "supplier", "supplierId", "supplierName",
    "barcode", "imageUrl", "isActive"];
  const clean = Object.fromEntries(fields.filter((k) => input[k] !== undefined).map((k) => [k, input[k]]));
  for (const field of ["purchasePrice", "sellingPrice", "piecePrice"]) if (clean[field] != null) money(clean[field]);
  if (clean.unitsPerPackage != null) count(clean.unitsPerPackage);
  if (command !== "adjustStock" && Object.hasOwn(clean, "supplierId")) {
    await linkMedicineSupplier(ctx, medicineId, old?.supplierId, clean.supplierId);
  }
  if (command === "createMedicine") {
    if (!text(clean.name)) fail("اسم الدواء مطلوب", "invalid-argument");
    const quantity = count(input.quantity); const pieceQuantity = count(input.pieceQuantity);
    const units = count(clean.unitsPerPackage ?? 0);
    if (pieceQuantity && (!units || clean.sellByPiece !== true)) fail("وحدة القطعة غير صالحة");
    const batch = {id: `opening-${ctx.key}`, quantity, pieceQuantity, reservedQuantity: 0,
      reservedPieceQuantity: 0, unitsPerPackage: units, purchasePrice: clean.purchasePrice || 0,
      expiryDate: date(input.expiryDate), batchNumber: text(input.batchNumber) || "رصيد افتتاحي",
      source: "opening", createdAt: ctx.timestamp};
    const stock = {ref, medicine: clean, batches: [batch], timestamp: ctx.timestamp};
    ctx.tx.create(ref, {...clean, id: medicineId, ...stockProjection(stock), createdAt: ctx.timestamp});
    const {id: batchId, ...batchData} = batch;
    ctx.tx.create(ref.collection("batches").doc(batchId), batchData);
    ledger(ctx, "opening-stock", {type: "inventoryOpening", accountType: "adjustment", direction: "neutral",
      amount: stockProjection(stock).costValue, referenceId: medicineId, referenceCollection: "medicines",
      title: "رصيد مخزون افتتاحي", metadata: {batchId, quantity, pieceQuantity, cashMovement: false}});
  } else if (command === "adjustStock") {
    if (text(payload.reason).length < 3 || text(payload.reason).length > 500) fail("سبب التسوية مطلوب من 3 إلى 500 حرف.");
    const stock = await loadStock(ctx.tx, ref, ctx.timestamp, snapshot);
    const targetPackages = count(payload.quantity); const targetPieces = count(payload.pieceQuantity);
    const current = stockProjection(stock);
    if (payload.expectedQuantity !== current.quantity || payload.expectedPieceQuantity !== current.pieceQuantity) {
      fail("تغير المخزون منذ فتح الشاشة؛ حدّث الكميات ثم أعد المحاولة");
    }
    const packageDelta = targetPackages - current.quantity; const pieceDelta = targetPieces - current.pieceQuantity;
    if (packageDelta < 0 || pieceDelta < 0) allocate(stock, Math.max(0, -packageDelta), Math.max(0, -pieceDelta));
    if (packageDelta > 0 || pieceDelta > 0) {
      const batchId = `adjustment-${ctx.key}`;
      stock.batches.push({id: batchId, quantity: Math.max(0, packageDelta), pieceQuantity: Math.max(0, pieceDelta),
        reservedQuantity: 0, reservedPieceQuantity: 0, unitsPerPackage: old.unitsPerPackage || 0,
        purchasePrice: old.purchasePrice || 0, expiryDate: date(payload.expiryDate, old.expiryDate || null),
        source: "adjustment", createdAt: ctx.timestamp});
      stock.changed.add(batchId);
    }
    const adjusted = stockProjection(stock);
    if (adjusted.quantity !== targetPackages || adjusted.pieceQuantity !== targetPieces) {
      fail("الكميات المطلوبة لا تطابق العبوات والقطع بعد التسوية؛ راجع تحويل العبوات إلى قطع");
    }
    writeStock(ctx.tx, stock);
    const valueDelta = money(stockProjection(stock).costValue) - money(current.costValue);
    ledger(ctx, "stock-adjustment", {type: "inventoryAdjustment", accountType: "adjustment", direction: "neutral",
      amount: Math.abs(valueDelta) / 100, referenceId: medicineId, referenceCollection: "medicines",
      title: "تسوية مخزون", metadata: {packageDelta, pieceDelta, valueDelta: valueDelta / 100, reason: text(payload.reason), cashMovement: false}});
    ctx.audit = {module: "inventory", targetType: "medicine", targetId: medicineId,
      targetName: old.name || medicineId, source: "server", entityPath: ref.path,
      details: {reason: text(payload.reason), oldValues: {quantity: current.quantity, pieceQuantity: current.pieceQuantity, costValue: current.costValue},
        newValues: {quantity: adjusted.quantity, pieceQuantity: adjusted.pieceQuantity, costValue: adjusted.costValue}}};
  } else {
    const stock = await loadStock(ctx.tx, ref, ctx.timestamp, snapshot);
    if (input.quantity !== undefined && (input.quantity !== (old.quantity || 0) || input.pieceQuantity !== (old.pieceQuantity || 0))) {
      fail("تعديل الكميات يتم من إجراء تسوية المخزون");
    }
    if (clean.unitsPerPackage !== undefined && Number(clean.unitsPerPackage || 0) !== Number(old.unitsPerPackage || 0) &&
        stock.batches.some((b) => b.quantity || b.pieceQuantity || b.reservedQuantity || b.reservedPieceQuantity)) {
      fail("لا يمكن تغيير حجم العبوة مع وجود مخزون أو حجوزات");
    }
    if (input.expiryDate !== undefined && millis(input.expiryDate) !== millis(old.expiryDate)) {
      await requirePermission(ctx, "inventory.expiry.manage");
      const batches = stock.batches.filter((b) => b.quantity || b.pieceQuantity);
      if (batches.length > 1) fail("الصنف يحتوي على عدة دفعات؛ عدّل صلاحية الدفعة من سجل الدفعات");
      if (batches.length === 1) {
        const batch = batches[0];
        if (batch.reservedQuantity || batch.reservedPieceQuantity) fail("لا يمكن تغيير صلاحية دفعة مرتبطة بحجز نشط");
        batch.expiryDate = date(input.expiryDate);
        stock.changed.add(batch.id);
        writeStock(ctx.tx, stock);
      }
    }
    ctx.tx.update(ref, {...clean, lastUpdated: ctx.timestamp});
  }
  return {medicineId};
}

async function postSale(ctx, payload) {
  const input = payload.sale || {};
  if (!Array.isArray(input.items) || !input.items.length || input.items.length > 100 || input.source !== "pos") {
    fail("فاتورة نقطة البيع غير مكتملة", "invalid-argument");
  }
  const invoiceId = id(payload.invoiceId); const invoiceRef = ctx.pharmacy.collection("sales").doc(invoiceId);
  const existing = await ctx.tx.get(invoiceRef);
  const fingerprint = payloadHash({sale: input});
  if (existing.exists) {
    if (existing.data().financeFingerprint !== fingerprint) fail("الفاتورة موجودة ببيانات مختلفة");
    return {invoiceId};
  }
  const shift = await openShift(ctx, input.shiftId);
  const priceActor = await requirePermission(ctx, "sales.create");
  // Load the price permission separately because overrides may change during checkout.
  let canOverride = ctx.actor.type === "owner";
  if (!canOverride) {
    const role = await ctx.tx.get(ctx.pharmacy.collection("permissions").doc(priceActor.employee.roleId));
    canOverride = permissionAllowed(priceActor.employee, role.data(), "sales.override_price");
  }
  const stocks = new Map();
  for (const line of input.items) {
    const medicineId = id(line.medicineId);
    if (!stocks.has(medicineId)) stocks.set(medicineId,
      await loadStock(ctx.tx, ctx.pharmacy.collection("medicines").doc(medicineId), ctx.timestamp));
  }
  const companyId = text(input.insuranceCompanyId);
  const companyRef = companyId ? ctx.pharmacy.collection("insurance_companies").doc(id(companyId)) : null;
  const company = companyRef ? (await ctx.tx.get(companyRef)).data() : null;
  let subtotal = 0; let cogs = 0; const allocations = [];
  const lines = input.items.flatMap((line) => {
    const quantity = count(line.quantity); if (!quantity) fail("الكمية يجب أن تكون موجبة");
    const stock = stocks.get(line.medicineId); const piece = line.sellAsPiece === true;
    const price = money(line.unitPrice);
    const percentage = line.discountPercentage ?? 0;
    if (typeof percentage !== "number" || !Number.isFinite(percentage) || percentage < 0 || percentage > 100) fail("نسبة خصم غير صالحة");
    const discount = money(line.discountAmount ?? 0) || Math.round(price * quantity * percentage / 100);
    const parts = allocate(stock, piece ? 0 : quantity, piece ? quantity : 0, "sell", text(line.batchId) || null);
    allocations.push(...parts);
    const lineCost = parts.reduce((sum, part) => sum + part.unitCost *
      (part.packages + (part.unitsPerPackage ? part.pieces / part.unitsPerPackage : 0)), 0);
    const gross = parts.reduce((sum, part) => sum + part.unitPrice *
      (part.packages + part.pieces), 0);
    const grossCents = Math.round(gross * 100);
    if (!canOverride && (parts.some((part) => money(part.unitPrice) !== price) || discount > 0)) {
      fail("ليست لديك صلاحية تعديل السعر أو الخصم", "permission-denied");
    }
    if (discount > grossCents) fail("الخصم يتجاوز قيمة الصنف");
    subtotal += grossCents - discount; cogs += Math.round(lineCost * 100);
    const split = new Set(parts.map((part) => part.unitPrice)).size > 1;
    if (!split) return [{medicineId: line.medicineId, name: text(stock.medicine.name), quantity,
      sellAsPiece: piece, unitPrice: (parts[0]?.unitPrice ?? price / 100), discountAmount: discount / 100,
      discountPercentage: 0, unitCost: lineCost / quantity,
      unitsPerPackageSnapshot: stock.medicine.unitsPerPackage || null, batchAllocations: parts}];
    return parts.map((part) => {
      const partQuantity = piece ? part.pieces : part.packages;
      const partGross = part.unitPrice * partQuantity;
      return {medicineId: line.medicineId, name: text(stock.medicine.name), quantity: partQuantity,
        sellAsPiece: piece, unitPrice: part.unitPrice, discountAmount: gross ? discount * partGross / gross / 100 : 0,
        discountPercentage: 0, unitCost: piece && part.unitsPerPackage ? part.unitCost / part.unitsPerPackage : part.unitCost,
        unitsPerPackageSnapshot: part.unitsPerPackage || null, batchAllocations: [part]};
    });
  });
  const discount = money(input.discount ?? 0);
  if (discount > subtotal) fail("الخصم يتجاوز إجمالي الفاتورة");
  if (discount && !canOverride) fail("ليست لديك صلاحية الخصم", "permission-denied");
  const net = subtotal - discount;
  let rate = 0;
  if (companyId) {
    if (!company || company.isActive === false || !["active", "فعال"].includes(company.status) ||
        (company.contractStartDate && !(millis(company.contractStartDate) <= ctx.timestamp.toMillis())) ||
        (company.contractEndDate && !(millis(company.contractEndDate) >= ctx.timestamp.toMillis()))) fail("عقد شركة التأمين غير متاح");
    rate = company.discountPercentage;
    if (typeof rate !== "number" || !Number.isFinite(rate) || rate < 0 || rate > 100) fail("نسبة التأمين غير صالحة");
  }
  const companyShare = Math.round(net * rate / 100); const customerShare = net - companyShare;
  if (money(input.total) !== customerShare || money(input.insuranceDiscount ?? 0) !== companyShare ||
      money(input.subtotal) !== subtotal) fail("تغيرت الأسعار أو التغطية؛ راجع إجمالي الفاتورة");
  const paymentMethod = method(input.paymentMethod);
  if (paymentMethod === "bank") fail("اختر النقد أو البطاقة لنقطة البيع");
  const sale = {id: invoiceId, invoiceNumber: text(input.invoiceNumber) || invoiceId,
    pharmacyId: ctx.pharmacy.id, employeeId: ctx.actor.type === "employee" ? ctx.actor.id : null,
    employeeName: text(ctx.actor.employee?.name), performedById: ctx.actor.id,
    performedBy: {id: ctx.actor.id, type: ctx.actor.type}, source: "pos", type: "sale",
    status: "completed", isSaved: true, isDeleted: false, inventoryPosted: true, financialPosted: true,
    operationId: ctx.operationId, financeFingerprint: fingerprint, postingVersion: 2,
    createdAt: ctx.timestamp, completedAt: ctx.timestamp, saleDate: ctx.timestamp, postedAt: ctx.timestamp,
    shiftId: shift.ref.id, creationShiftId: shift.ref.id, collectionShiftId: shift.ref.id,
    items: lines, batchAllocations: allocations, subtotal: subtotal / 100, discount: discount / 100,
    total: customerShare / 100, customerShare: customerShare / 100, companyShare: companyShare / 100,
    insuranceDiscount: companyShare / 100, insuranceCoveragePercentage: rate,
    insuranceCompanyId: companyId || null, insuranceCompanyName: company?.name || null,
    insuranceClaimAmount: companyShare / 100, insuranceClaimStatus: companyShare ? "due" : "notApplicable",
    paymentMethod, paymentState: "delivered", paidAmount: customerShare / 100, remainingAmount: 0,
    cashIn: paymentMethod === "cash" ? customerShare / 100 : 0,
    cardIn: paymentMethod === "card" ? customerShare / 100 : 0, cashOut: 0, cardOut: 0,
    cogsTotal: cogs / 100, grossProfit: (net - cogs) / 100, netProfit: (net - cogs) / 100,
    customerName: text(input.customerName), customerPhone: text(input.customerPhone), notes: text(input.notes),
    financialTransactionId: customerShare ? `${ctx.key}-sale` : null};
  for (const stock of stocks.values()) writeStock(ctx.tx, stock);
  ctx.tx.create(invoiceRef, sale);
  ctx.tx.update(shift.ref, {salesCount: count(shift.data.salesCount ?? 0) + 1,
    cashTotal: addAmount(shift.data, "cashTotal", paymentMethod === "cash" ? customerShare : 0),
    cardTotal: addAmount(shift.data, "cardTotal", paymentMethod === "card" ? customerShare : 0),
    insuranceBilledTotal: addAmount(shift.data, "insuranceBilledTotal", companyShare), updatedAt: ctx.timestamp});
  if (customerShare) ledger(ctx, "sale", {type: "sale", accountType: "salesRevenue", direction: "inflow",
    amount: customerShare / 100, referenceId: invoiceId, referenceCollection: "sales",
    referenceNumber: sale.invoiceNumber, paymentMethod, shiftId: shift.ref.id, title: "تحصيل نقطة البيع"});
  if (companyShare) {
    ctx.tx.update(companyRef, {totalClaims: addAmount(company, "totalClaims", companyShare),
      currentReceivable: addAmount(company, "currentReceivable", companyShare),
      insuranceInvoicesCount: count(company.insuranceInvoicesCount ?? 0) + 1, updatedAt: ctx.timestamp});
    ledger(ctx, "claim", {type: "insuranceClaim", accountType: "insuranceReceivable", direction: "receivable",
      amount: companyShare / 100, referenceId: invoiceId, referenceCollection: "sales",
      insuranceCompanyId: companyId, insuranceCompanyName: company.name, title: "مطالبة تأمين نقطة البيع"});
    insuranceLedger(ctx, "claim", {type: "claim", invoiceId, insuranceCompanyId: companyId,
      amount: companyShare / 100, direction: "receivable"});
  }
  return {invoiceId};
}

async function refundPos(ctx, payload) {
  await openShift(ctx, payload.shiftId);
  const invoiceRef = ctx.pharmacy.collection("sales").doc(id(payload.invoiceId));
  const snapshot = await ctx.tx.get(invoiceRef); const invoice = snapshot.data();
  if (!invoice || invoice.source !== "pos" || invoice.type !== "sale" || invoice.status !== "completed" || invoice.isDeleted) {
    fail("فاتورة البيع الأصلية غير متاحة للمرتجع");
  }
  return refundDeliveredOrder({transaction: ctx.tx, db: ctx.db,
    order: {status: "completed", pharmacy: {pharmacyId: ctx.pharmacy.id}},
    actor: {type: "pharmacy", id: ctx.actor.id, employeeId: ctx.actor.employeeId}, payload,
    operationKey: ctx.key, timestamp: ctx.timestamp, directInvoice: {invoice, invoiceRef}});
}

async function postExpense(ctx, payload, command) {
  const expenseId = command === "createExpense" ? `expense-${ctx.key}` : id(payload.expenseId);
  const ref = ctx.pharmacy.collection("expenses").doc(expenseId);
  const snapshot = await ctx.tx.get(ref); const previous = snapshot.data();
  if (command !== "createExpense" && (!previous || previous.isVoided)) fail("المصروف غير متاح للتعديل");
  const cancelling = command === "reverseExpense";
  const amount = cancelling ? 0 : money(payload.amount);
  if (!cancelling && (!amount || !text(payload.title))) fail("عنوان المصروف ومبلغ موجب مطلوبان");
  const paymentMethod = cancelling ? method(previous.paymentMethod) : method(payload.paymentMethod);
  const shiftId = previous?.shiftId || payload.shiftId || null;
  const shift = shiftId ? await openShift(ctx, shiftId) : null;
  const oldAmount = previous ? money(previous.amount) : 0;
  if (previous && previous.financialPosted !== true) fail("المصروف السابق يحتاج إلى مطابقة قيده قبل تعديله");
  const revision = count(previous?.revision ?? 0) + 1;
  const updated = {id: expenseId, title: cancelling ? previous.title : text(payload.title),
    category: cancelling ? previous.category : text(payload.category), amount: amount / 100,
    date: cancelling ? previous.date : date(payload.date, ctx.timestamp), paymentMethod,
    notes: text(payload.notes), shiftId, isVoided: cancelling, revision,
    financialPosted: true, financialTransactionId: cancelling ? `${ctx.key}-expense-reversal` : `${ctx.key}-expense`,
    createdAt: previous?.createdAt || ctx.timestamp, createdBy: previous?.createdBy || ctx.actor.id,
    updatedAt: ctx.timestamp, updatedBy: ctx.actor.id, postedAt: ctx.timestamp};
  if (previous) ledger(ctx, "expense-reversal", {type: "expenseReversal", accountType: "operatingExpense",
    direction: "inflow", amount: oldAmount / 100, paymentMethod: method(previous.paymentMethod),
    referenceId: expenseId, referenceCollection: "expenses", shiftId,
    title: `عكس مصروف: ${previous.title}`, metadata: {reverses: previous.financialTransactionId, revision}});
  if (!cancelling) ledger(ctx, "expense", {type: "expense", accountType: "operatingExpense", direction: "outflow",
    amount: amount / 100, paymentMethod, referenceId: expenseId, referenceCollection: "expenses", shiftId,
    title: updated.title, metadata: {revision, category: updated.category}});
  ctx.tx.set(ref, updated);
  ctx.tx.create(ref.collection("revisions").doc(ctx.key), {
    before: previous || null, after: updated, createdAt: ctx.timestamp, createdBy: ctx.actor.id,
  });
  if (shift) {
    const delta = (paymentMethod === "cash" ? amount : 0) -
      (previous && method(previous.paymentMethod) === "cash" ? oldAmount : 0);
    const next = money(shift.data.shiftExpenses ?? 0) + delta;
    if (next < 0) fail("مصروفات الوردية السابقة تحتاج إلى مطابقة");
    ctx.tx.update(shift.ref, {shiftExpenses: next / 100, updatedAt: ctx.timestamp});
  }
  return {expenseId};
}

async function bulkMedicines(ctx, payload, command) {
  if (!Array.isArray(payload.medicines) || !payload.medicines.length || payload.medicines.length > 100) {
    fail("يمكن اعتماد من 1 إلى 100 صنف في عملية واحدة", "invalid-argument");
  }
  const ids = new Set(); const result = [];
  for (const [index, medicine] of payload.medicines.entries()) {
    const medicineId = medicine.id || `medicine-${ctx.key}-${index}`;
    if (ids.has(medicineId)) fail("الصنف مكرر في الملف", "invalid-argument");
    ids.add(medicineId);
    result.push(await saveMedicine({...ctx, key: `${ctx.key}-${index}`}, {medicineId, medicine},
      command === "importMedicines" ? "createMedicine" : "updateMedicine"));
  }
  return {medicineIds: result.map((r) => r.medicineId)};
}

function assertBatchSnapshot(batch, expected) {
  if (!expected || typeof expected !== "object") fail("أعد فتح الدفعة لتحميل رصيدها وحالتها قبل التسوية.");
  for (const field of ["quantity", "pieceQuantity", "reservedQuantity", "reservedPieceQuantity", "unitsPerPackage", "purchasePrice"]) {
    if (expected[field] !== Number(batch[field] || 0)) fail("تغير رصيد الدفعة أو حجوزاتها أو تكلفتها. حدّث السجل وراجع الكمية.");
  }
  for (const field of ["expiryDate", "updatedAt"]) {
    if (millis(expected[field]) !== millis(batch[field])) fail("تغيرت بيانات الدفعة. حدّث السجل قبل اعتماد القرار.");
  }
  if (expected.isActive !== (batch.isActive !== false) || expected.quarantined !== (batch.quarantined === true)) {
    fail("تغيرت حالة الدفعة. حدّث السجل قبل اعتماد القرار.");
  }
}

async function adjustBatchStock(ctx, payload) {
  const ref = ctx.pharmacy.collection("medicines").doc(id(payload.medicineId));
  const stock = await loadStock(ctx.tx, ref, ctx.timestamp);
  const batch = stock.batches.find((row) => row.id === id(payload.batchId));
  if (!batch || batch.quarantined === true) fail("الدفعة غير موجودة أو معزولة؛ استخدم إجراء مصير المعزول.");
  assertBatchSnapshot(batch, payload.expected);
  const reason = text(payload.reason);
  if (reason.length < 3 || reason.length > 500) fail("سبب التسوية مطلوب من 3 إلى 500 حرف.");
  const category = payload.category;
  if (!["correction", "damage", "expiry"].includes(category)) fail("حدد سبب التسوية: جرد أو تلف أو انتهاء صلاحية.");
  const quantity = count(payload.quantity); const pieceQuantity = count(payload.pieceQuantity);
  const before = {...batch}; const previousProjection = stockProjection(stock);
  if (quantity === Number(batch.quantity || 0) && pieceQuantity === Number(batch.pieceQuantity || 0)) fail("لم تتغير كمية الدفعة.");
  if (category !== "correction" && (quantity > Number(batch.quantity || 0) || pieceQuantity > Number(batch.pieceQuantity || 0))) {
    fail("تسوية التلف أو الانتهاء تخفض الرصيد ولا تزيده.");
  }
  if (category === "expiry" && (millis(batch.expiryDate) === null ||
      !Number.isFinite(millis(batch.expiryDate)) || millis(batch.expiryDate) > ctx.timestamp.toMillis())) fail("الدفعة لم تنته صلاحيتها؛ راجع سبب التسوية.");
  if (pieceQuantity && !Number(batch.unitsPerPackage || 0)) fail("لا يمكن تسجيل قطع دون عدد قطع صالح في العبوة.");
  const after = {...batch, quantity, pieceQuantity};
  try { stockUnits(after); } catch (_) {
    fail("الكمية المتبقية لا تغطي حجوزات الطلبات. عالج الطلبات المحجوزة قبل تخفيض هذه الكمية.");
  }
  Object.assign(batch, after);
  stock.changed.add(batch.id);
  const projection = stockProjection(stock);
  const valueDelta = money(projection.costValue) - money(previousProjection.costValue);
  writeStock(ctx.tx, stock);
  const record = {medicineId: ref.id, batchId: batch.id, category, reason, before, after,
    valueDelta: valueDelta / 100, createdAt: ctx.timestamp, createdBy: ctx.actor.id,
    createdByActor: {id: ctx.actor.id, type: ctx.actor.type}, operationId: ctx.operationId};
  ctx.tx.create(ref.collection("batchAdjustments").doc(ctx.key), record);
  ledger(ctx, "batch-adjustment", {type: valueDelta < 0 ? "inventoryLoss" : "inventoryAdjustment",
    accountType: valueDelta < 0 ? "inventoryLoss" : "adjustment", direction: "neutral", amount: Math.abs(valueDelta) / 100,
    referenceId: ref.id, referenceCollection: "medicines", title: "تسوية كمية دفعة مخزنية",
    metadata: {source: "batchStockAdjustment", batchId: batch.id, category, reason,
      valueDelta: valueDelta / 100, cashMovement: false, additionalExpense: valueDelta < 0 && category !== "correction"}});
  ctx.audit = {module: "inventory", targetType: "medicineBatch", targetId: batch.id,
    targetName: stock.medicine.name || ref.id, source: "server", entityPath: ref.collection("batches").doc(batch.id).path,
    details: {reason, category, oldValues: before, newValues: after, valueDelta: valueDelta / 100}};
  return {medicineId: ref.id, batchId: batch.id, adjustmentId: ctx.key, quantity, pieceQuantity};
}

async function updateBatch(ctx, payload) {
  const ref = ctx.pharmacy.collection("medicines").doc(id(payload.medicineId));
  const stock = await loadStock(ctx.tx, ref, ctx.timestamp);
  const batch = stock.batches.find((b) => b.id === id(payload.batchId));
  if (!batch) fail("الدفعة غير موجودة");
  assertBatchSnapshot(batch, payload.expected);
  if (batch.reservedQuantity || batch.reservedPieceQuantity) fail("لا يمكن تعديل دفعة مرتبطة بحجز نشط");
  if (!text(payload.reason)) fail("سبب تصحيح بيانات الدفعة مطلوب");
  const previous = {...batch};
  batch.expiryDate = date(payload.expiryDate);
  batch.batchNumber = text(payload.batchNumber) || batch.batchNumber || batch.id;
  stock.changed.add(batch.id);
  writeStock(ctx.tx, stock);
  ctx.tx.create(ref.collection("batchCorrections").doc(ctx.key), {
    batchId: batch.id, before: previous, after: {...batch}, reason: text(payload.reason),
    createdAt: ctx.timestamp, createdBy: ctx.actor.id, operationId: ctx.operationId,
  });
  return {medicineId: ref.id, batchId: batch.id};
}

async function reorderBatches(ctx, payload) {
  const ref = ctx.pharmacy.collection("medicines").doc(id(payload.medicineId));
  const snapshot = await ctx.tx.get(ref);
  if (!snapshot.exists) fail("الصنف غير موجود");
  const stock = await loadStock(ctx.tx, ref, ctx.timestamp, snapshot);
  const requested = Array.isArray(payload.batchOrder) ? payload.batchOrder.map(id) : [];
  const available = new Set(stock.batches.map((batch) => batch.id));
  if (requested.length !== available.size || requested.some((batchId) => !available.has(batchId)) ||
      new Set(requested).size !== requested.length) {
    fail("ترتيب الدفعات غير صالح؛ حدّث القائمة ثم أعد المحاولة");
  }
  const previous = Array.isArray(snapshot.data().batchOrder) ? snapshot.data().batchOrder :
    orderedBatches(stock).map((batch) => batch.id);
  const mode = payload.mode === "fefo" ? "fefo" : "custom";
  const order = mode === "fefo" ? FieldValue.delete() : requested;
  ctx.tx.update(ref, {batchOrderMode: mode, batchOrder: order, updatedAt: ctx.timestamp});
  ctx.audit = {module: "inventory", targetType: "medicine", targetId: ref.id,
    targetName: stock.medicine.name || ref.id, source: "server", entityPath: ref.path,
    details: {action: mode === "fefo" ? "restore_fefo" : "reorder_batches", previousOrder: previous,
      newOrder: mode === "fefo" ? orderedBatches(stock).map((batch) => batch.id) : requested}};
  return {medicineId: ref.id, mode, batchOrder: mode === "fefo" ? orderedBatches(stock).map((batch) => batch.id) : requested};
}

async function saveCounterparty(ctx, payload, command) {
  const insurance = command.includes("Insurance");
  const creating = command.startsWith("create");
  const archiving = command.startsWith("archive");
  const collection = insurance ? "insurance_companies" : "suppliers";
  const recordId = creating ? `${insurance ? "company" : "supplier"}-${ctx.key}` : id(payload.id);
  const ref = ctx.pharmacy.collection(collection).doc(recordId);
  const snapshot = await ctx.tx.get(ref); const previous = snapshot.data();
  const pharmacySnapshot = insurance ? await ctx.tx.get(ctx.pharmacy) : null;
  function updateAcceptedCodes(code, active) {
    const codes = (pharmacySnapshot.data()?.acceptedInsuranceCodes || []).filter((v) =>
      text(v).toUpperCase() !== text(previous?.code).toUpperCase() && text(v).toUpperCase() !== code);
    if (active) codes.push(code);
    ctx.tx.update(ctx.pharmacy, {acceptedInsuranceCodes: [...new Set(codes)], updatedAt: ctx.timestamp});
  }
  if (!creating && !previous) fail("الجهة غير موجودة");
  if (archiving) {
    ctx.tx.update(ref, {status: "غير فعال", isActive: false, archivedAt: ctx.timestamp, updatedAt: ctx.timestamp});
    if (insurance) updateAcceptedCodes(text(previous.code).toUpperCase(), false);
    return {recordId};
  }
  const input = payload.data || {};
  const excluded = ["id", "createdAt", "createdBy", "updatedAt", "updatedBy", "pharmacyId", "financialPosted",
    "currentBalance", "totalPurchases", "totalPaid", "totalDue", "outstandingBalance", "overdueBalance",
    "unpaidInvoicesCount", "overdueInvoicesCount", "lastPurchaseDate", "lastPaymentDate", "openingBalance",
    "openingReceivable", "currentReceivable", "totalClaims", "totalCollected", "totalRejected", "totalRefundedClaims",
    "creditBalance", "insuranceInvoicesCount", "lastClaimDate", "lastCollectionId", "lastCollectionTransactionId", "lastCollectionDate"];
  const data = Object.fromEntries(Object.entries(input).filter(([key]) => !excluded.includes(key)));
  if (!text(data.name)) fail("اسم الجهة مطلوب", "invalid-argument");
  for (const field of ["contractStartDate", "contractEndDate"]) if (field in data) data[field] = date(data[field]);
  const openingField = insurance ? "openingReceivable" : "openingBalance";
  const opening = money(input[openingField] ?? 0);
  if (!creating && opening !== money(previous[openingField] ?? 0)) fail("لا يُعدل الرصيد الافتتاحي بعد الاعتماد؛ يلزم قيد تسوية موثق");
  if (insurance) {
    data.code = text(data.code).toUpperCase();
    if (!data.code || typeof data.discountPercentage !== "number" || !Number.isFinite(data.discountPercentage) ||
        data.discountPercentage < 0 || data.discountPercentage > 100) fail("كود شركة التأمين ونسبة تغطية صحيحة مطلوبان");
    const others = await ctx.tx.get(ctx.pharmacy.collection(collection).where("code", "==", data.code));
    if (others.docs.some((doc) => doc.id !== recordId)) fail("كود شركة التأمين مستخدم بالفعل");
    const codeRef = ctx.pharmacy.collection("insurance_codes").doc(payloadHash(data.code));
    const codeSnapshot = await ctx.tx.get(codeRef);
    if (codeSnapshot.exists && codeSnapshot.data().companyId !== recordId) fail("كود شركة التأمين مستخدم بالفعل");
    if (previous?.code && previous.code !== data.code) {
      const previousCodeRef = ctx.pharmacy.collection("insurance_codes").doc(payloadHash(previous.code));
      ctx.tx.delete(previousCodeRef);
    }
    ctx.tx.set(codeRef, {code: data.code, companyId: recordId});
    updateAcceptedCodes(data.code, data.isActive !== false && ["active", "فعال"].includes(data.status));
  }
  if (creating) {
    data[openingField] = opening / 100;
    if (insurance) Object.assign(data, {currentReceivable: opening / 100, totalClaims: 0, totalCollected: 0, creditBalance: 0});
    else Object.assign(data, {currentBalance: opening / 100, totalDue: opening / 100,
      outstandingBalance: opening / 100, totalPurchases: 0, totalPaid: 0});
    ctx.tx.create(ref, {...data, id: recordId, createdBy: ctx.actor.id, createdAt: ctx.timestamp, updatedAt: ctx.timestamp});
    if (opening) {
      ledger(ctx, "counterparty-opening", {type: "openingBalance", accountType: insurance ? "insuranceReceivable" : "supplierPayable",
        direction: insurance ? "receivable" : "payable", amount: opening / 100,
        referenceId: recordId, referenceCollection: collection, title: "رصيد افتتاحي",
        ...(insurance ? {insuranceCompanyId: recordId} : {supplierId: recordId})});
      // Opening balances get their own settlement document and never appear as sales revenue.
      const openingRef = ctx.pharmacy.collection(insurance ? "sales" : "purchase_invoices").doc(`opening-${recordId}`);
      ctx.tx.create(openingRef, insurance ? {
        invoiceNumber: `OPEN-${recordId}`, source: "openingBalance", type: "opening", status: "completed",
        insuranceCompanyId: recordId, insuranceCompanyName: data.name, insuranceClaimAmount: opening / 100,
        insuranceClaimStatus: "due", total: 0, paidAmount: 0, insuranceDiscount: opening / 100,
        items: [], createdAt: ctx.timestamp, financialPosted: true, isDeleted: false,
      } : {invoiceNumber: `OPEN-${recordId}`, source: "openingBalance", status: "received",
        supplierId: recordId, supplierName: data.name, total: opening / 100, subtotal: opening / 100,
        paid: 0, remainingAmount: opening / 100, paymentStatus: "unpaid", items: [],
        invoiceDate: ctx.timestamp, createdAt: ctx.timestamp, createdBy: ctx.actor.id, financialPosted: true});
      if (insurance) insuranceLedger(ctx, "opening", {insuranceCompanyId: recordId, type: "openingBalance", amount: opening / 100});
    }
  } else ctx.tx.update(ref, {...data, updatedBy: ctx.actor.id, updatedAt: ctx.timestamp});
  return {recordId};
}

async function postShift(ctx, payload, command) {
  const actorKey = `${ctx.actor.type}:${ctx.actor.id}`;
  if (command === "openShift") {
    const stateRef = ctx.pharmacy.collection("shift_states").doc(actorKey);
    const state = await ctx.tx.get(stateRef);
    if (state.data()?.activeShiftId) fail("توجد وردية مفتوحة بالفعل");
    const opening = money(payload.openingCash);
    const shiftId = `shift-${ctx.key}`;
    const actor = {id: ctx.actor.id, type: ctx.actor.type, name: text(ctx.actor.employee?.name)};
    ctx.tx.create(ctx.pharmacy.collection("shifts").doc(shiftId), {
      pharmacyId: ctx.pharmacy.id, status: "open", openedByKey: actorKey,
      openedBy: actor, openedById: actor.id, openedByType: actor.type, openedByName: actor.name,
      openingCash: opening / 100, notes: text(payload.notes), openedAt: ctx.timestamp,
      createdAt: ctx.timestamp, updatedAt: ctx.timestamp, salesCount: 0, refundsCount: 0,
      cashTotal: 0, cardTotal: 0, cashRefunds: 0, cardRefunds: 0, insuranceBilledTotal: 0,
      insuranceRefunds: 0, shiftExpenses: 0, supplierPayments: 0, salaryPayments: 0,
    });
    ctx.tx.set(stateRef, {actorKey, activeShiftId: shiftId, status: "open", updatedAt: ctx.timestamp});
    ledger(ctx, "shift-opening", {type: "openingBalance", accountType: "cashbox", direction: "neutral",
      amount: opening / 100, referenceId: shiftId, referenceCollection: "shifts", shiftId,
      title: "رصيد درج افتتاحي", metadata: {cashMovement: false}});
    return {shiftId};
  }
  const ref = ctx.pharmacy.collection("shifts").doc(id(payload.shiftId));
  const snapshot = await ctx.tx.get(ref); const shift = snapshot.data();
  if (!shift || shift.pharmacyId !== ctx.pharmacy.id) fail("الوردية غير موجودة");
  if (shift.openedByKey !== actorKey) await requirePermission(ctx, "shifts.close_any");
  const stateRef = ctx.pharmacy.collection("shift_states").doc(id(shift.openedByKey));
  const state = await ctx.tx.get(stateRef);
  const closing = money(payload.closingCash);
  if (shift.status === "closed" && money(shift.closingCash) === closing) return {shiftId: ref.id};
  if (shift.status !== "open" || state.data()?.activeShiftId !== ref.id) fail("تغيرت الوردية النشطة");
  const expected = money(shift.openingCash) + money(shift.cashTotal) - money(shift.cashRefunds) -
    money(shift.shiftExpenses) - money(shift.supplierPayments) - money(shift.salaryPayments) +
    money(shift.manualCashIn) - money(shift.manualCashOut);
  const diff = closing - expected; const notes = text(payload.notes);
  if (diff && !notes) fail("أدخل سبب الفرق قبل إغلاق الوردية");
  ctx.tx.update(ref, {status: "closed", isFinanciallyClosed: true, closedAt: ctx.timestamp,
    closedByKey: actorKey, closedById: ctx.actor.id, closedByType: ctx.actor.type,
    closingCash: closing / 100, expectedDrawerCash: expected / 100, drawerDiff: diff / 100,
    notes, updatedAt: ctx.timestamp});
  ctx.tx.update(stateRef, {status: "none", activeShiftId: null, closedAt: ctx.timestamp, updatedAt: ctx.timestamp});
  return {shiftId: ref.id, expectedDrawerCash: expected / 100, drawerDiff: diff / 100};
}

const permissions = {
  adjustBatchStock: "inventory.adjust_quantity",
  disposeQuarantinedReturn: "inventory.adjust_quantity",
  saveSalaryProfile: "finance.payroll.view", accrueSalary: "finance.payroll.view", postSalaryPayment: "finance.payroll.view",
  createRole: "roles.manage", updateRole: "roles.manage",
  receivePurchase: "purchases.create", payPurchase: "purchases.payment", reversePurchase: "purchases.delete",
  createMedicine: "inventory.create", updateMedicine: "inventory.update", adjustStock: "inventory.adjust_quantity",
  deleteMedicine: "inventory.delete", postSale: "sales.create", refundPos: "sales.refund",
  updateBatch: "inventory.expiry.manage",
  reorderBatches: "inventory.update",
  importMedicines: "inventory.create", bulkUpdateMedicines: "inventory.update",
  createExpense: "finance.expenses.create", updateExpense: "finance.expenses.update",
  reverseExpense: "finance.expenses.delete",
  createSupplier: "suppliers.create", updateSupplier: "suppliers.update", archiveSupplier: "suppliers.delete",
  createInsurance: "insurance.create", updateInsurance: "insurance.update", archiveInsurance: "insurance.delete",
  openShift: "shifts.open", closeShift: "shifts.close",
};

function buildPharmacyFinanceCommand({db, clock = () => Date.now(), testHooks = {}}) {
  return async (request) => {
    const data = request.data || {}; const command = text(data.command);
    if (!permissions[command]) fail("أمر غير معروف", "invalid-argument");
    const pharmacyId = id(data.pharmacyId); const operationId = text(data.operationId);
    let key;
    try { key = operationDocumentId(request.auth?.uid || "", operationId); } catch (_) { fail("معرف العملية غير صالح", "invalid-argument"); }
    const hash = payloadHash({pharmacyId, command, payload: data.payload || {}});
    return db.runTransaction(async (transaction) => {
      // Queue writes until every dependent record and permission has been read.
      // This also allows a CSV import to fail atomically on its last row.
      const writes = [];
      const tx = {get: (ref) => transaction.get(ref)};
      for (const verb of ["create", "set", "update", "delete"]) {
        tx[verb] = (...args) => writes.push(() => transaction[verb](...args));
      }
      const timestamp = Timestamp.fromMillis(clock());
      const actor = await resolvePharmacyPrincipal({db, auth: request.auth, pharmacyId,
        permission: permissions[command], instant: timestamp.toMillis(), transaction: tx});
      const pharmacy = db.collection("pharmacies").doc(pharmacyId);
      const operationRef = pharmacy.collection("financial_operations").doc(key);
      const prior = await tx.get(operationRef);
      if (prior.exists) {
        if (prior.data().payloadHash !== hash) fail("معرف العملية مستخدم لبيانات مختلفة");
        return prior.data().result;
      }
      const ctx = {db, tx, actor, pharmacy, timestamp, key, operationId, requestHash: hash,
        auth: request.auth, supplierLinks: new Map()};
      let result;
      const payload = data.payload || {};
      switch (command) {
        case "adjustBatchStock": result = await adjustBatchStock(ctx, payload); break;
        case "disposeQuarantinedReturn": result = await disposeQuarantinedReturn(ctx, payload, {ledger}); break;
        case "saveSalaryProfile": case "accrueSalary": case "postSalaryPayment":
          result = await postPayroll(ctx, payload, command, {money, method, ledger, openShift, addAmount}); break;
        case "createRole": case "updateRole": result = await savePharmacyRole(ctx, payload, command); break;
        case "receivePurchase": result = await receivePurchase(ctx, payload); break;
        case "payPurchase": result = await payPurchase(ctx, payload); break;
        case "reversePurchase": result = await reversePurchase(ctx, payload); break;
        case "postSale": result = await postSale(ctx, payload); break;
        case "refundPos": result = await refundPos(ctx, payload); break;
        case "updateBatch": result = await updateBatch(ctx, payload); break;
        case "reorderBatches": result = await reorderBatches(ctx, payload); break;
        case "openShift": case "closeShift": result = await postShift(ctx, payload, command); break;
        case "importMedicines": case "bulkUpdateMedicines": result = await bulkMedicines(ctx, payload, command); break;
        case "createExpense": case "updateExpense": case "reverseExpense": result = await postExpense(ctx, payload, command); break;
        case "createSupplier": case "updateSupplier": case "archiveSupplier":
        case "createInsurance": case "updateInsurance": case "archiveInsurance":
          result = await saveCounterparty(ctx, payload, command); break;
        default: result = await saveMedicine(ctx, payload, command);
      }
      for (const link of ctx.supplierLinks.values()) {
        tx.update(link.ref, {suppliedMedications: [...link.ids], updatedAt: timestamp});
      }
      result = {success: true, ...result, operationId};
      tx.create(operationRef, {command, operationId, payloadHash: hash, result,
        createdAt: timestamp, createdBy: actor.id});
      if (!ctx.skipBusinessAudit) {
        tx.create(pharmacy.collection("audit_logs").doc(`finance-${key}`), {
          action: command, module: "finance", operationId, actor: {id: actor.id, type: actor.type},
          createdBy: actor.id, createdAt: timestamp, timestamp, targetId: result.invoiceId || result.medicineId || null,
          details: result, pharmacyId, ...ctx.audit,
        });
      }
      if (writes.length > 450) fail("العملية تتجاوز حد الكتابة؛ قلل عدد الأصناف", "invalid-argument");
      if (typeof testHooks.beforeCommit === "function") {
        await testHooks.beforeCommit({command, operationId, pharmacyId, result});
      }
      for (const write of writes) write();
      return result;
    });
  };
}

module.exports = {buildPharmacyFinanceCommand, money, method, openShift, ledger, requirePermission};

