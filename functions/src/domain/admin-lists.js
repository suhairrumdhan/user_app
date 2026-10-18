"use strict";

const {FieldPath, FieldValue} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const {createHash} = require("node:crypto");
const {statusOf} = require("./registration-commands");
const {delaySummary} = require("./admin-delay");

const PAGE_SIZE = 50;
const VERSION = 1;
const SOURCES = Object.freeze({requests: "pharmacyRequests", pharmacies: "pharmacies",
  users: "users", orders: "adminOrderSummaries", notifications: "adminBroadcastNotifications",
  audit: "adminAuditLogs"});
const PERMISSIONS = {requests: "requests.view", pharmacies: "pharmacies.view",
  users: "users.view", orders: "orders.view", notifications: "notifications.view", audit: "audit.view"};
const fail = (code, message) => { throw new HttpsError(code, message); };
const normalize = (value) => String(value ?? "").normalize("NFKC").trim().toLowerCase().replace(/\s+/g, " ");
const string = (value, length = 500) => typeof value === "string" ? value.slice(0, length) : "";
const number = (value) => Number.isFinite(Number(value)) ? Number(value) : 0;
function millis(value) {
  if (value === null || value === undefined || value === "") return null;
  const time = value?.toMillis?.() ?? (typeof value === "number" ? value : Date.parse(value));
  return Number.isFinite(time) ? time : null;
}
function date(value) { const time = millis(value); return time === null ? null : new Date(time).toISOString(); }
function pick(data, fields) {
  return Object.fromEntries(fields.map((key) => [key, string(data[key])]));
}
function dates(data, fields) {
  return Object.fromEntries(fields.map((key) => [key, date(data[key])]));
}
function location(data) {
  const value = data.location || data;
  return {address: string(value.address), latitude: typeof value.latitude === "number" ? value.latitude : null,
    longitude: typeof value.longitude === "number" ? value.longitude : null};
}
// This allowlist is the entire public list response; raw user/order objects are never returned.
function project(kind, id, data) {
  let row = {id};
  let time = data.createdAt;
  let state = "unknown";
  let group = "";
  if (kind === "requests") {
    row = {...row, ...pick(data, ["pharmacyName", "ownerName", "licenseNumber", "ownerIdNumber", "email",
      "phoneNumber", "ownerUid", "pharmacyId", "licenseFilePath", "ownerIdFilePath", "licenseFileUrl",
      "ownerIdFileUrl", "decisionReason"]), ...dates(data, ["createdAt", "requestDate", "updatedAt"]),
    revision: number(data.revision), version: number(data.version) || 1, location: location(data),
    status: statusOf(data.status)};
    if (row.status === "draft") row.pharmacyName = row.pharmacyName || string(data.draft?.pharmacyName);
    time = data.requestDate || data.createdAt;
    state = row.status;
  } else if (kind === "pharmacies") {
    row = {...row, ...pick(data, ["pharmacyName", "name", "ownerName", "licenseNumber", "phoneNumber", "email",
      "status", "visibilityReason", "visibilityChangedBy"]), ...dates(data, ["createdAt", "approvedDate", "visibilityChangedAt"]),
    location: location(data), isOnline: data.isOnline === true, isBlocked: data.isBlocked === true,
    isActive: data.isActive !== false, is24Hours: data.is24Hours === true,
    visibilityRevision: Number.isInteger(data.visibilityRevision) ? data.visibilityRevision : 0};
    state = row.isBlocked ? "hidden" : "visible";
    group = row.isOnline ? "online" : "offline";
    time = data.approvedDate || data.createdAt;
  } else if (kind === "users") {
    row = {...row, ...pick(data, ["fullName", "name", "email", "phoneNumber", "phone"]),
      ...dates(data, ["createdAt", "lastActivityAt"]), totalOrders: Number.isFinite(data.totalOrders) ? data.totalOrders : null,
      accountStatus: data.isActive === false || data.isBlocked === true || data.accountStatus === "blocked" ? "disabled" : "active"};
    state = row.accountStatus;
  } else if (kind === "orders") {
    row = {...row, ...pick(data, ["orderNumber", "pharmacyId", "pharmacyName", "status"]),
      ...dates(data, ["createdAt", "updatedAt", "reviewStartedAt", "readyAt", "pickupDeadline", "pharmacyDelayAt",
        "pickupOverdueAt", "pharmacyDelayDetectedAt", "completedAt", "cancelledAt", "rejectedAt", "notCollectedAt"]),
      totalItemsCount: number(data.totalItemsCount), pharmacyReviewActiveMs: data.pharmacyReviewActiveMs ?? null,
      pharmacyReadyDurationMs: data.pharmacyReadyDurationMs ?? null, pharmacyDelayed: data.pharmacyDelayed === true,
      pickupOverdue: data.pickupOverdue === true,
      statusHistory: (Array.isArray(data.statusHistory) ? data.statusHistory : []).map((entry) => ({
        ...pick(entry, ["status", "changedByType"]), changedAt: date(entry.changedAt),
      })), ...delaySummary(data)};
    state = row.status;
    group = row.pharmacyId;
  } else if (kind === "notifications") {
    row = {...row, ...pick(data, ["title", "body", "targetType", "status", "createdByName"]),
      ...dates(data, ["createdAt", "completedAt"]), deliveredCount: number(data.deliveredCount),
      pushSuccessCount: number(data.pushSuccessCount), pushFailureCount: number(data.pushFailureCount),
      schemaVersion: number(data.schemaVersion), total: number(data.total), succeeded: number(data.succeeded), failed: number(data.failed), pending: number(data.pending)};
    state = row.status;
    group = row.targetType;
  } else if (kind === "audit") {
    row = {...row, ...pick(data, ["action", "module", "targetId", "targetType", "targetName", "reason",
      "performedByUid", "performedByName", "status", "operationId", "source"]), ...dates(data, ["createdAt"])};
    // Old audit payloads may contain arbitrary private data: do not spread them.
    const fields = ["status", "revision", "version", "isBlocked", "visibilityRevision", "targetType", "title"];
    for (const side of ["before", "after"]) {
      row[side] = data[side] ? Object.fromEntries(fields.filter((key) =>
        ["string", "number", "boolean"].includes(typeof data[side][key])).map((key) => [key, data[side][key]])) : null;
    }
    state = row.status || "success";
    group = row.module;
  } else fail("invalid-argument", "القائمة غير معروفة.");
  const sortAt = millis(time);
  row.dateUnknown = sortAt === null;
  const searchable = [id, row.pharmacyName, row.name, row.fullName, row.ownerName, row.email, row.phone,
    row.phoneNumber, row.licenseNumber, row.orderNumber, row.title, row.action, row.targetName,
    row.performedByName, row.reason, row.location?.address];
  const tokens = new Set();
  for (const value of searchable.filter(Boolean)) {
    const normalized = normalize(value);
    for (const term of [normalized, ...normalized.split(" ")]) {
      for (let i = 1; i <= Math.min(80, term.length); i++) tokens.add(term.slice(0, i));
    }
  }
  return {schemaVersion: VERSION, sortAt: sortAt ?? -1, state, group, searchKeys: [...tokens], row};
}

function rowsRef(db, kind) { return db.collection("adminLists").doc(kind).collection("adminListRows"); }
async function refreshRow({db, kind, id}) {
  if (!SOURCES[kind]) throw new Error("Unknown admin list");
  return db.runTransaction(async (tx) => {
    const source = await tx.get(db.collection(SOURCES[kind]).doc(id));
    const target = rowsRef(db, kind).doc(id);
    if (!source.exists) { tx.delete(target); return; }
    // Replace, never merge, to remove old fields when the allowlist changes.
    tx.set(target, {...project(kind, id, source.data()), projectedAt: FieldValue.serverTimestamp()});
  });
}

async function authorize({db, auth, request}) {
  if (!request.auth || typeof request.auth.uid !== "string" || !request.auth.uid.trim()) {
    fail("unauthenticated", "سجّل الدخول أولًا.");
  }
  const [user, profile] = await Promise.all([auth.getUser(request.auth.uid), db.doc(`adminEmployees/${request.auth.uid}`).get()]);
  const data = profile.data();
  if (user.disabled || data?.isActive !== true || request.auth.token?.actorType === "pharmacy_employee") {
    fail("permission-denied", "الحساب غير مخول لهذا الإجراء.");
  }
  const issued = Number(request.auth.token?.auth_time || 0) * 1000;
  if (user.tokensValidAfterTime && issued < Date.parse(user.tokensValidAfterTime)) fail("unauthenticated", "انتهت جلسة الحساب.");
  return data;
}
function dayBoundary(value, next = false) {
  if (!value) return null;
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) fail("invalid-argument", "التاريخ غير صالح.");
  const utc = Date.parse(`${value}T00:00:00Z`);
  if (!Number.isFinite(utc) || new Date(utc).toISOString().slice(0, 10) !== value) fail("invalid-argument", "التاريخ غير صالح.");
  // Modern Libya is UTC+02:00; UI formatting is explicitly Africa/Tripoli.
  return utc - 2 * 60 * 60 * 1000 + (next ? 86400000 : 0);
}
function buildAdminList({db, auth}) {
  return async (request) => {
    const input = request.data || {};
    const kind = input.kind;
    if (!Object.hasOwn(SOURCES, kind)) fail("invalid-argument", "القائمة غير معروفة.");
    await authorize({db, auth, request, permission: PERMISSIONS[kind]});
    const ready = (await db.doc(`adminLists/${kind}`).get()).data();
    if (ready?.schemaVersion !== VERSION || ready?.ready !== true) {
      fail("failed-precondition", "فهرس القائمة لم يُجهز بعد. يلزم إكمال تهيئة القوائم الإدارية من مصدر البيانات.");
    }
    const q = normalize(input.q);
    const state = string(input.state, 80);
    const group = string(input.group, 128);
    const delay = string(input.delay, 30);
    if (delay && !["any", "pharmacy", "pickup", "pharmacy_active", "pickup_active"].includes(delay)) fail("invalid-argument", "نوع التأخر غير معروف.");
    if (q.length > 80) fail("invalid-argument", "البحث بحد أقصى 80 حرفًا.");
    const from = dayBoundary(input.from);
    const until = dayBoundary(input.to, true);
    if (from !== null && until !== null && from >= until) fail("invalid-argument", "بداية الفترة بعد نهايتها.");
    let query = rowsRef(db, kind);
    if (q) query = query.where("searchKeys", "array-contains", q);
    if (state && state !== "all") query = query.where("state", "==", state);
    if (group) query = query.where("group", "==", group);
    if (from !== null) query = query.where("sortAt", ">=", from);
    if (until !== null) query = query.where("sortAt", "<", until);
    const signature = createHash("sha256").update(JSON.stringify({kind, q, state, group, from, until, delay})).digest("hex");
    const ordered = query.orderBy("sortAt", "desc").orderBy(FieldPath.documentId(), "desc");
    let page = ordered;
    if (input.cursor) {
      const cursor = input.cursor;
      if (cursor.signature !== signature || !Number.isFinite(cursor.time) || typeof cursor.id !== "string" ||
        !cursor.id || cursor.id.includes("/")) fail("invalid-argument", "مؤشر الصفحة لا يطابق المرشحات.");
      page = page.startAfter(cursor.time, cursor.id);
    }
    if (kind === "orders" && delay) {
      // Delay can cross its threshold without a write. Compute it against one
      // server instant over the filtered projection, never over the first page.
      const instant = Date.now();
      const matched = [];
      let last;
      do {
        const scan = await (last ? ordered.startAfter(last) : ordered).limit(250).get();
        for (const doc of scan.docs) {
          const row = {...doc.data().row, ...delaySummary(doc.data().row, instant), id: doc.id};
          const qualifies = delay === "any" ? row.pharmacyDelay.occurred || row.userDelay.occurred :
            delay === "pharmacy" ? row.pharmacyDelay.occurred : delay === "pickup" ? row.userDelay.occurred :
              delay === "pharmacy_active" ? row.pharmacyDelay.active : row.userDelay.active;
          if (qualifies) matched.push({row, time: doc.data().sortAt});
        }
        last = scan.size === 250 ? scan.docs.at(-1) : null;
      } while (last);
      const cursor = input.cursor;
      const remaining = cursor ? matched.filter((entry) => entry.time < cursor.time || entry.time === cursor.time &&
        Buffer.compare(Buffer.from(entry.row.id), Buffer.from(cursor.id)) < 0) : matched;
      const selected = remaining.slice(0, PAGE_SIZE);
      const end = selected.at(-1);
      return {rows: selected.map((entry) => entry.row), total: matched.length, hasMore: remaining.length > PAGE_SIZE,
        next: end ? {signature, time: end.time, id: end.row.id} : null, pageSize: PAGE_SIZE, projectionVersion: VERSION};
    }
    const [snapshot, count] = await Promise.all([page.limit(PAGE_SIZE + 1).get(), ordered.count().get()]);
    const docs = snapshot.docs.slice(0, PAGE_SIZE);
    const last = docs.at(-1);
    return {rows: docs.map((doc) => {
      const row = {...doc.data().row, id: doc.id};
      return kind === "orders" ? {...row, ...delaySummary(row)} : row;
    }), total: count.data().count,
      hasMore: snapshot.size > PAGE_SIZE, next: last ? {signature, time: last.data().sortAt, id: last.id} : null,
      pageSize: PAGE_SIZE, projectionVersion: VERSION};
  };
}

module.exports = {PAGE_SIZE, VERSION, SOURCES, project, refreshRow, rowsRef, authorize, buildAdminList};
