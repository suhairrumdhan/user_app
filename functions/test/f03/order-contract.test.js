"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  LEGACY_STATUS_ALIASES,
  ORDER_STATUS,
  PICKUP_WINDOW_MS,
  STATUS_LABELS,
  TRANSITIONS,
  assertCurrentOfferVersion,
  assertTransition,
  buildReadyTiming,
  hasTrustedInvoice,
  parseOrderStatus,
} = require("../../src/domain/order-contract");

test("canonical states and Arabic labels match the approved F03 contract", () => {
  assert.deepEqual(ORDER_STATUS, {
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
  assert.deepEqual(STATUS_LABELS, {
    received: "مستلم",
    underReview: "قيد المراجعة",
    partialOfferPending: "بانتظار قرار العرض الجزئي",
    confirmedReserved: "مؤكد ومحجوز",
    preparing: "قيد التجهيز",
    ready: "جاهز للاستلام",
    completed: "مكتمل",
    cancelled: "ملغي",
    rejected: "مرفوض",
    notCollected: "لم يستلم",
  });
});

test("transition matrix exactly matches the approved F03 workflow", () => {
  const expected = [
    "confirmedReserved|cancelled|user|cancelOrder",
    "confirmedReserved|partialOfferPending|pharmacy|revisePartialOffer",
    "confirmedReserved|preparing|pharmacy|startPreparing",
    "partialOfferPending|cancelled|user|cancelOrder",
    "partialOfferPending|cancelled|user|rejectPartialOffer",
    "partialOfferPending|confirmedReserved|user|acceptPartialOffer",
    "partialOfferPending|partialOfferPending|pharmacy|revisePartialOffer",
    "preparing|cancelled|pharmacy|cancelAfterInvoice",
    "preparing|ready|pharmacy|markReady",
    "ready|cancelled|pharmacy|cancelAfterInvoice",
    "ready|completed|pharmacy|completeOrder",
    "ready|notCollected|pharmacy|markNotCollected",
    "received|cancelled|user|cancelOrder",
    "received|underReview|system|resolveInsurance",
    "received|underReview|user|continueWithoutInsurance",
    "underReview|cancelled|user|cancelOrder",
    "underReview|confirmedReserved|pharmacy|confirmFullOrder",
    "underReview|partialOfferPending|pharmacy|createPartialOffer",
    "underReview|rejected|pharmacy|rejectOrder",
  ].sort();
  const actual = [];
  for (const [from, destinations] of Object.entries(TRANSITIONS)) {
    for (const [to, actorRules] of Object.entries(destinations)) {
      for (const [actor, commands] of Object.entries(actorRules)) {
        for (const command of commands) {
          actual.push(`${from}|${to}|${actor}|${command}`);
        }
      }
    }
  }
  assert.deepEqual(actual.sort(), expected);
});

test("every declared transition accepts only its declared actor and command", () => {
  const actors = ["user", "pharmacy", "system"];
  for (const [from, destinations] of Object.entries(TRANSITIONS)) {
    for (const [to, actorRules] of Object.entries(destinations)) {
      for (const [actor, commands] of Object.entries(actorRules)) {
        for (const command of commands) {
          assert.deepEqual(
            assertTransition({from, to, actorType: actor, command}),
            {from, to, actorType: actor, command},
          );
          for (const wrongActor of actors.filter((value) => value !== actor)) {
            assert.throws(
              () => assertTransition({from, to, actorType: wrongActor, command}),
              {code: "invalid-order-transition"},
            );
          }
        }
      }
    }
  }
});

test("undeclared destinations and commands are rejected", () => {
  const statuses = Object.values(ORDER_STATUS);
  const commands = [
    "resolveInsurance","continueWithoutInsurance","cancelOrder","confirmFullOrder","createPartialOffer","revisePartialOffer",
    "acceptPartialOffer","rejectPartialOffer","rejectOrder","startPreparing",
    "markReady","completeOrder","cancelAfterInvoice","markNotCollected",
  ];
  for (const [from, destinations] of Object.entries(TRANSITIONS)) {
    for (const to of statuses) {
      for (const actor of ["user", "pharmacy", "system"]) {
        for (const command of commands) {
          const allowed = destinations[to]?.[actor]?.includes(command) === true;
          if (!allowed) {
            assert.throws(
              () => assertTransition({from, to, actorType: actor, command}),
              (error) => ["invalid-order-transition", "terminal-order"].includes(error.code),
            );
          }
        }
      }
    }
  }
});

test("terminal states cannot be reopened", () => {
  for (const status of [
    ORDER_STATUS.COMPLETED,
    ORDER_STATUS.CANCELLED,
    ORDER_STATUS.REJECTED,
    ORDER_STATUS.NOT_COLLECTED,
  ]) {
    assert.throws(
      () => assertTransition({
        from: status,
        to: ORDER_STATUS.UNDER_REVIEW,
        actorType: "pharmacy",
        command: "reopen",
      }),
      {code: "terminal-order"},
    );
  }
});

test("legacy aliases are explicit and unknown values never become received", () => {
  for (const [legacy, canonical] of Object.entries(LEGACY_STATUS_ALIASES)) {
    assert.equal(parseOrderStatus(legacy).status, canonical);
    assert.equal(parseOrderStatus(legacy).source, "legacy");
  }
  assert.throws(() => parseOrderStatus("mystery"), {code: "unknown-order-status"});
  assert.throws(() => parseOrderStatus(""), {code: "unknown-order-status"});
});

test("stale partial offers are rejected", () => {
  assert.equal(assertCurrentOfferVersion(4, 4), 4);
  assert.throws(() => assertCurrentOfferVersion(3, 4), {
    code: "stale-offer-version",
  });
});

test("ready deadline is fixed at first ready time", () => {
  const first = new Date("2026-01-15T09:00:00.000Z");
  const timing = buildReadyTiming(first);
  assert.equal(timing.readyAt.toISOString(), first.toISOString());
  assert.equal(timing.pickupDeadline.getTime(), first.getTime() + PICKUP_WINDOW_MS);
});

test("legacy invoice-looking fields are not a trusted invoice", () => {
  assert.equal(hasTrustedInvoice({saleId: "old", invoiceNumber: "42"}), false);
  assert.equal(hasTrustedInvoice({schemaVersion: 3, invoiceId: "invoice-42"}), true);
});
