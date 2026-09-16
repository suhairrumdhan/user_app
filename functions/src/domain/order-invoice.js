"use strict";

const {OrderContractError, ORDER_SCHEMA_VERSION} = require("./order-contract");

function reject(message) {
  throw new OrderContractError("failed-precondition", message);
}

function quantities(items, reservation = false) {
  if (!Array.isArray(items) || items.length === 0) reject("Invoice reservation items are missing.");
  const result = new Map();
  for (const item of items) {
    const id = item?.medicineId;
    const quantity = item?.quantity;
    if (typeof id !== "string" || !id.trim() || !Number.isSafeInteger(quantity) || quantity <= 0) {
      reject("Invalid invoice reservation quantity.");
    }
    const piece = reservation ? item.soldByPiece === true : item.sellAsPiece === true;
    const key = `${id}|${piece ? "piece" : "pack"}`;
    const total = (result.get(key) || 0) + quantity;
    if (!Number.isSafeInteger(total)) reject("Invoice quantity exceeds the safe limit.");
    result.set(key, total);
  }
  return result;
}

function amount(value) {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0 ||
      !Number.isSafeInteger(Math.round(value * 100))) reject("Invalid canonical invoice amount.");
  return Math.round(value * 100);
}

async function readCanonicalOrderInvoice({transaction, db, order, paymentState}) {
  const {orderId, invoiceId, reservationId} = order;
  const pharmacyId = order.pharmacy?.pharmacyId;
  if (![orderId, invoiceId, reservationId, pharmacyId].every((value) =>
    typeof value === "string" && value.trim() && !value.includes("/"))) {
    reject("Canonical invoice and consumed reservation identifiers are required.");
  }
  const invoiceRef = db.collection("pharmacies").doc(pharmacyId).collection("sales").doc(invoiceId);
  const reservationRef = db.collection("orders").doc(orderId).collection("reservations").doc(reservationId);
  const invoiceSnapshot = await transaction.get(invoiceRef);
  const reservationSnapshot = await transaction.get(reservationRef);
  const invoice = invoiceSnapshot.data();
  const reservation = reservationSnapshot.data();
  if (!invoiceSnapshot.exists || !reservationSnapshot.exists ||
      order.schemaVersion !== ORDER_SCHEMA_VERSION || invoice.schemaVersion !== ORDER_SCHEMA_VERSION ||
      invoice.source !== "order" || invoice.orderId !== orderId || invoice.sourceOrderId !== orderId ||
      invoice.pharmacyId !== pharmacyId || invoice.invoiceId !== invoiceId ||
      invoice.type !== "sale" || invoice.status !== "completed" || invoice.isSaved !== true ||
      invoice.isDeleted !== false || invoice.inventoryPosted !== true || invoice.reservationConsumed !== true ||
      reservation.state !== "consumed" || order.reservationState !== "consumed") {
    reject("Invoice is not a canonical consumed invoice for this order.");
  }
  if (invoice.paymentState !== paymentState || invoice.reversedAt || invoice.reversalId) {
    reject("Invoice is not in the required payment state.");
  }
  const expected = quantities(reservation.items, true);
  const actual = quantities(invoice.items);
  if (expected.size !== actual.size || [...expected].some(([key, value]) => actual.get(key) !== value)) {
    reject("Invoice items do not match the consumed reservation.");
  }
  const customer = amount(invoice.customerShare);
  const company = amount(invoice.companyShare);
  const paid = amount(invoice.paidAmount);
  const cash = amount(invoice.cashIn);
  const card = amount(invoice.cardIn);
  if (amount(invoice.total) !== customer || amount(invoice.insuranceClaimAmount) !== company ||
      amount(invoice.insuranceDiscount) !== company ||
      !["cash", "card"].includes(invoice.paymentMethod)) {
    reject("Invoice payment snapshot is inconsistent.");
  }
  if (paymentState === "pendingDelivery" && (paid !== 0 || cash !== 0 || card !== 0 ||
      invoice.financialPosted !== false || amount(invoice.refundedCustomerAmount ?? 0) !== 0 ||
      amount(invoice.insuranceRefundedAmount ?? 0) !== 0 || amount(invoice.insuranceCollectedAmount ?? 0) !== 0)) {
    reject("Undelivered invoice already contains financial effects.");
  }
  if (paymentState === "delivered" && (paid !== customer || cash + card !== paid ||
      invoice.financialPosted !== (customer > 0 || company > 0))) {
    reject("Delivered invoice collection is inconsistent.");
  }
  return {invoice, invoiceRef};
}

module.exports = {readCanonicalOrderInvoice};
