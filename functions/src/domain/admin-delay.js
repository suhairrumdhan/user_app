"use strict";

const {parseOrderStatus} = require("./order-contract");
const DAY_MS = 86400000;
const ACTIVE = new Set(["underReview", "confirmedReserved", "preparing"]);
const TERMINAL = new Set(["completed", "cancelled", "rejected", "notCollected"]);
function time(value) {
  if (value === null || value === undefined || value === "") return null;
  const result = value?.toMillis?.() ?? (typeof value === "number" ? value : Date.parse(value));
  return Number.isFinite(result) ? result : null;
}
const iso = (value) => value === null ? null : new Date(value).toISOString();
function status(value) { try { return parseOrderStatus(value).status; } catch (_) { return "unknown"; } }
function earliest(values) { const valid = values.map(time).filter((value) => value !== null); return valid.length ? Math.min(...valid) : null; }

// Pure, server-clock calculation. Only processing intervals before FIRST ready
// count; every partial-offer interval is excluded, including repeated offers.
function delaySummary(order, instant = Date.now()) {
  const current = status(order.status);
  const cycle = time(order.fulfillmentCycleStartedAt);
  const history = (Array.isArray(order.statusHistory) ? order.statusHistory : [])
    .map((entry, index) => ({status: status(entry.status), at: time(entry.changedAt), index}))
    .filter((entry) => entry.at !== null && entry.at <= instant && (cycle === null || entry.at >= cycle))
    .sort((a, b) => a.at - b.at || a.index - b.index);
  const ready = earliest([order.firstReadyAt, order.readyAt, ...history.filter((entry) => entry.status === "ready").map((entry) => entry.at)]);
  const terminal = TERMINAL.has(current) ? earliest([order.completedAt, order.cancelledAt, order.rejectedAt,
    order.notCollectedAt, ...history.filter((entry) => TERMINAL.has(entry.status)).map((entry) => entry.at)]) : null;
  const stop = ready ?? terminal ?? instant;
  const coverageWaits = (order.insuranceDecisionWaitIntervals || []).map((interval) =>
    ({start: time(interval.start), end: time(interval.end) ?? instant}))
    .filter((interval) => interval.start !== null).sort((a, b) => a.start - b.start);
  const firstReview = history.find((entry) => entry.status === "underReview");
  let activeMs = 0;
  let crossed = null;
  let measured = false;
  if (firstReview) {
    measured = true;
    for (let i = 0; i < history.length; i++) {
      const entry = history[i];
      if (!ACTIVE.has(entry.status) || entry.at >= stop) continue;
      const end = Math.min(stop, history[i + 1]?.at ?? instant);
      let cursor = entry.at;
      const segments = [];
      for (const wait of coverageWaits) {
        if (wait.end <= cursor || wait.start >= end) continue;
        if (wait.start > cursor) segments.push([cursor, Math.min(wait.start, end)]);
        cursor = Math.max(cursor, wait.end);
      }
      if (cursor < end) segments.push([cursor, end]);
      for (const [start, finish] of segments) {
        const elapsed = Math.max(0, finish - start);
        if (crossed === null && activeMs < DAY_MS && activeMs + elapsed >= DAY_MS) crossed = start + DAY_MS - activeMs;
        activeMs += elapsed;
      }
    }
  } else {
    const stored = order.pharmacyReviewActiveMs === null || order.pharmacyReviewActiveMs === undefined ? NaN : Number(order.pharmacyReviewActiveMs);
    const frozen = order.pharmacyReadyDurationMs === null || order.pharmacyReadyDurationMs === undefined ? NaN : Number(order.pharmacyReadyDurationMs);
    const started = time(order.reviewStartedAt);
    if (ready !== null && Number.isFinite(frozen) && frozen >= 0) { activeMs = frozen; measured = true; }
    else if (Number.isFinite(stored) && stored >= 0) {
      activeMs = stored + (ACTIVE.has(current) && started !== null ? Math.max(0, stop - started) : 0);
      measured = true;
    }
    if (activeMs >= DAY_MS) crossed = time(order.pharmacyDelayAt) ?? time(order.pharmacyDelayDetectedAt);
  }
  const pharmacyOccurred = measured ? activeMs >= DAY_MS : order.pharmacyDelayed === true;
  const pharmacyResolved = pharmacyOccurred && (ready !== null || TERMINAL.has(current));
  const deadline = coverageWaits.length ? time(order.pickupDeadline) : ready === null ? time(order.pickupDeadline) : ready + DAY_MS;
  const pickupEnd = terminal ?? instant;
  const pickupOccurred = order.insuranceRemoval?.status !== "pending" && deadline !== null && pickupEnd >= deadline &&
    (ready !== null || current === "ready" || order.pickupOverdue === true);
  return {
    firstReadyAt: iso(ready), pickupDeadline: iso(deadline),
    pharmacyDelay: {occurred: pharmacyOccurred, active: pharmacyOccurred && !pharmacyResolved,
      startedAt: pharmacyOccurred ? iso(crossed) : null, resolvedAt: pharmacyResolved ? iso(ready ?? terminal) : null,
      processingMs: measured ? activeMs : null, overdueMs: measured ? Math.max(0, activeMs - DAY_MS) : null,
      measured, evaluatedAt: iso(instant)},
    userDelay: {occurred: pickupOccurred, active: pickupOccurred && current === "ready",
      startedAt: pickupOccurred ? iso(deadline) : null, resolvedAt: pickupOccurred && TERMINAL.has(current) ? iso(terminal) : null,
      overdueMs: pickupOccurred ? Math.max(0, pickupEnd - deadline) : 0, evaluatedAt: iso(instant)},
  };
}

module.exports = {DAY_MS, ACTIVE, TERMINAL, time, iso, status, delaySummary};
