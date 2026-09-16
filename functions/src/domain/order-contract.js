"use strict";

const ORDER_SCHEMA_VERSION = 3;
const PICKUP_WINDOW_MS = 24 * 60 * 60 * 1000;
const PHARMACY_REVIEW_LIMIT_MS = 24 * 60 * 60 * 1000;

const ORDER_STATUS = Object.freeze({
  RECEIVED: "received",
  UNDER_REVIEW: "underReview",
  PARTIAL_OFFER_PENDING: "partialOfferPending",
  CONFIRMED_RESERVED: "confirmedReserved",
  PREPARING: "preparing",
  READY: "ready",
  COMPLETED: "completed",
  CANCELLED: "cancelled",
  REJECTED: "rejected",
  NOT_COLLECTED: "notCollected",
});

const STATUS_LABELS = Object.freeze({
  [ORDER_STATUS.RECEIVED]: "مستلم",
  [ORDER_STATUS.UNDER_REVIEW]: "قيد المراجعة",
  [ORDER_STATUS.PARTIAL_OFFER_PENDING]: "بانتظار قرار العرض الجزئي",
  [ORDER_STATUS.CONFIRMED_RESERVED]: "مؤكد ومحجوز",
  [ORDER_STATUS.PREPARING]: "قيد التجهيز",
  [ORDER_STATUS.READY]: "جاهز للاستلام",
  [ORDER_STATUS.COMPLETED]: "مكتمل",
  [ORDER_STATUS.CANCELLED]: "ملغي",
  [ORDER_STATUS.REJECTED]: "مرفوض",
  [ORDER_STATUS.NOT_COLLECTED]: "لم يستلم",
});

const LEGACY_STATUS_ALIASES = Object.freeze({
  pending: ORDER_STATUS.RECEIVED,
  reviewing: ORDER_STATUS.UNDER_REVIEW,
  partiallyConfirmed: ORDER_STATUS.PARTIAL_OFFER_PENDING,
  partially_confirmed: ORDER_STATUS.PARTIAL_OFFER_PENDING,
  confirmed: ORDER_STATUS.CONFIRMED_RESERVED,
  accepted: ORDER_STATUS.CONFIRMED_RESERVED,
  delivered: ORDER_STATUS.COMPLETED,
  canceled: ORDER_STATUS.CANCELLED,
});

const TERMINAL_STATUSES = new Set([
  ORDER_STATUS.COMPLETED,
  ORDER_STATUS.CANCELLED,
  ORDER_STATUS.REJECTED,
  ORDER_STATUS.NOT_COLLECTED,
]);

const TRANSITIONS = Object.freeze({
  [ORDER_STATUS.RECEIVED]: Object.freeze({
    [ORDER_STATUS.UNDER_REVIEW]: Object.freeze({
      system: Object.freeze(["resolveInsurance"]),
      user: Object.freeze(["continueWithoutInsurance"]),
    }),
    [ORDER_STATUS.CANCELLED]: Object.freeze({
      user: Object.freeze(["cancelOrder"]),
    }),
  }),
  [ORDER_STATUS.UNDER_REVIEW]: Object.freeze({
    [ORDER_STATUS.CONFIRMED_RESERVED]: Object.freeze({
      pharmacy: Object.freeze(["confirmFullOrder"]),
    }),
    [ORDER_STATUS.PARTIAL_OFFER_PENDING]: Object.freeze({
      pharmacy: Object.freeze(["createPartialOffer"]),
    }),
    [ORDER_STATUS.REJECTED]: Object.freeze({
      pharmacy: Object.freeze(["rejectOrder"]),
    }),
    [ORDER_STATUS.CANCELLED]: Object.freeze({
      user: Object.freeze(["cancelOrder"]),
    }),
  }),
  [ORDER_STATUS.PARTIAL_OFFER_PENDING]: Object.freeze({
    [ORDER_STATUS.PARTIAL_OFFER_PENDING]: Object.freeze({
      pharmacy: Object.freeze(["revisePartialOffer"]),
    }),
    [ORDER_STATUS.CONFIRMED_RESERVED]: Object.freeze({
      user: Object.freeze(["acceptPartialOffer"]),
    }),
    [ORDER_STATUS.CANCELLED]: Object.freeze({
      user: Object.freeze(["rejectPartialOffer", "cancelOrder"]),
    }),
  }),
  [ORDER_STATUS.CONFIRMED_RESERVED]: Object.freeze({
    [ORDER_STATUS.PARTIAL_OFFER_PENDING]: Object.freeze({
      pharmacy: Object.freeze(["revisePartialOffer"]),
    }),
    [ORDER_STATUS.PREPARING]: Object.freeze({
      pharmacy: Object.freeze(["startPreparing"]),
    }),
    [ORDER_STATUS.CANCELLED]: Object.freeze({
      user: Object.freeze(["cancelOrder"]),
    }),
  }),
  [ORDER_STATUS.PREPARING]: Object.freeze({
    [ORDER_STATUS.READY]: Object.freeze({
      pharmacy: Object.freeze(["markReady"]),
    }),
    [ORDER_STATUS.CANCELLED]: Object.freeze({
      pharmacy: Object.freeze(["cancelAfterInvoice"]),
    }),
  }),
  [ORDER_STATUS.READY]: Object.freeze({
    [ORDER_STATUS.COMPLETED]: Object.freeze({
      pharmacy: Object.freeze(["completeOrder"]),
    }),
    [ORDER_STATUS.CANCELLED]: Object.freeze({
      pharmacy: Object.freeze(["cancelAfterInvoice"]),
    }),
    [ORDER_STATUS.NOT_COLLECTED]: Object.freeze({
      pharmacy: Object.freeze(["markNotCollected"]),
    }),
  }),
  [ORDER_STATUS.COMPLETED]: Object.freeze({}),
  [ORDER_STATUS.CANCELLED]: Object.freeze({}),
  [ORDER_STATUS.REJECTED]: Object.freeze({}),
  [ORDER_STATUS.NOT_COLLECTED]: Object.freeze({}),
});

class OrderContractError extends Error {
  constructor(code, message, details = {}) {
    super(message);
    this.name = "OrderContractError";
    this.code = code;
    this.details = details;
  }
}

function cleanText(value) {
  return String(value ?? "").trim();
}

function parseOrderStatus(value, options = {}) {
  const raw = cleanText(value);
  const canonical = Object.values(ORDER_STATUS);
  if (canonical.includes(raw)) {
    return Object.freeze({status: raw, source: "canonical", legacyValue: null});
  }
  if (options.allowLegacy !== false && LEGACY_STATUS_ALIASES[raw]) {
    return Object.freeze({
      status: LEGACY_STATUS_ALIASES[raw],
      source: "legacy",
      legacyValue: raw,
    });
  }
  throw new OrderContractError(
    "unknown-order-status",
    `Unknown order status: ${raw || "<empty>"}`,
    {value: raw},
  );
}

function statusLabel(status) {
  const canonical = parseOrderStatus(status).status;
  return STATUS_LABELS[canonical];
}

function transitionRule(from, to) {
  const fromStatus = parseOrderStatus(from).status;
  const toStatus = parseOrderStatus(to, {allowLegacy: false}).status;
  return TRANSITIONS[fromStatus]?.[toStatus] || null;
}

function assertTransition({from, to, actorType, command}) {
  const fromStatus = parseOrderStatus(from).status;
  const toStatus = parseOrderStatus(to, {allowLegacy: false}).status;
  if (TERMINAL_STATUSES.has(fromStatus)) {
    throw new OrderContractError(
      "terminal-order",
      `Terminal order ${fromStatus} cannot be reopened by a status command.`,
      {from: fromStatus, to: toStatus},
    );
  }
  const actorCommands = TRANSITIONS[fromStatus]?.[toStatus]?.[actorType];
  if (!actorCommands || !actorCommands.includes(command)) {
    throw new OrderContractError(
      "invalid-order-transition",
      `Command ${command} cannot move ${fromStatus} to ${toStatus} as ${actorType}.`,
      {from: fromStatus, to: toStatus, actorType, command},
    );
  }
  return Object.freeze({from: fromStatus, to: toStatus, actorType, command});
}

function assertCurrentOfferVersion(expected, actual) {
  const expectedVersion = Number(expected);
  const actualVersion = Number(actual);
  if (!Number.isInteger(expectedVersion) || expectedVersion <= 0 ||
      expectedVersion !== actualVersion) {
    throw new OrderContractError(
      "stale-offer-version",
      "The partial offer changed and must be reviewed again.",
      {expected: expectedVersion, actual: actualVersion},
    );
  }
  return actualVersion;
}

function hasTrustedInvoice(order) {
  return Number(order?.schemaVersion) >= ORDER_SCHEMA_VERSION &&
    cleanText(order?.invoiceId).length > 0;
}

function buildReadyTiming(firstReadyAt) {
  const readyAt = firstReadyAt instanceof Date ?
    firstReadyAt : new Date(firstReadyAt);
  if (Number.isNaN(readyAt.getTime())) {
    throw new OrderContractError("invalid-ready-time", "readyAt is invalid.");
  }
  return Object.freeze({
    readyAt,
    pickupDeadline: new Date(readyAt.getTime() + PICKUP_WINDOW_MS),
  });
}

module.exports = {
  LEGACY_STATUS_ALIASES,
  ORDER_SCHEMA_VERSION,
  ORDER_STATUS,
  PHARMACY_REVIEW_LIMIT_MS,
  PICKUP_WINDOW_MS,
  STATUS_LABELS,
  TERMINAL_STATUSES,
  TRANSITIONS,
  OrderContractError,
  assertCurrentOfferVersion,
  assertTransition,
  buildReadyTiming,
  hasTrustedInvoice,
  parseOrderStatus,
  statusLabel,
  transitionRule,
};
