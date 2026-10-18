"use strict";

const {FieldPath} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const {authorize, project} = require("./admin-lists");
const {delaySummary, time, iso, status} = require("./admin-delay");
const {statusOf} = require("./registration-commands");
const normalize = (value) => String(value ?? "").normalize("NFKC").trim().toLowerCase();
const day = (instant) => new Date(instant + 7200000).toISOString().slice(0, 10);
const validPoint = (location) => typeof location?.latitude === "number" && typeof location?.longitude === "number" &&
  Number.isFinite(location.latitude) && Number.isFinite(location.longitude) && Math.abs(location.latitude) <= 90 && Math.abs(location.longitude) <= 180;

async function scan(db, collection, fields) {
  const result = [];
  let cursor;
  do {
    let query = db.collection(collection).orderBy(FieldPath.documentId()).limit(250);
    if (fields) query = query.select(...fields);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    result.push(...snapshot.docs.map((doc) => ({...doc.data(), id: doc.id})));
    cursor = snapshot.size === 250 ? snapshot.docs.at(-1) : null;
  } while (cursor);
  return result;
}
function stockState(medicine, instant) {
  const valid = medicine.isActive === true && medicine.isExpired !== true && medicine.invalidExpiry !== true &&
    medicine.invalidStock !== true && (time(medicine.expiryAt || medicine.expiryDate) ?? Infinity) > instant;
  const available = valid && (Number(medicine.availableQuantity) > 0 ||
    medicine.sellByPiece === true && Number(medicine.availablePieceQuantity) > 0);
  return {valid, available, out: valid && !available && medicine.pharmacyVisible === true};
}
function report(orders, users, pharmacies, requested, days, instant) {
  const today = day(instant);
  const until = Date.parse(`${today}T00:00:00Z`) - 7200000 + 86400000;
  const from = until - days * 86400000;
  const within = (value) => { const date = time(value); return date !== null && date >= from && date < until; };
  const selected = orders.filter((order) => within(order.createdAt));
  const trend = Array.from({length: days}, (_, index) => ({day: day(from + index * 86400000), orders: 0, completed: 0, newUsers: 0}));
  const byDay = new Map(trend.map((entry) => [entry.day, entry]));
  const activity = new Map();
  const delays = {pharmacy: {count: 0, overdueMs: 0, unknownDuration: 0}, user: {count: 0, overdueMs: 0, unknownDuration: 0}};
  let completed = 0;
  let cancelled = 0;
  for (const order of selected) {
    const state = status(order.status);
    completed += Number(state === "completed"); cancelled += Number(state === "cancelled");
    const bucket = byDay.get(day(time(order.createdAt)));
    bucket.orders++; bucket.completed += Number(state === "completed");
    const pharmacyId = order.pharmacyId || "unknown";
    const pharmacy = activity.get(pharmacyId) || {id: pharmacyId, name: order.pharmacyName || "غير محددة", total: 0, completed: 0, cancelled: 0};
    pharmacy.total++; pharmacy.completed += Number(state === "completed"); pharmacy.cancelled += Number(state === "cancelled");
    activity.set(pharmacyId, pharmacy);
    const summary = delaySummary(order, instant);
    for (const [key, value] of [["pharmacy", summary.pharmacyDelay], ["user", summary.userDelay]]) {
      if (!value.occurred) continue;
      delays[key].count++;
      if (value.overdueMs === null) delays[key].unknownDuration++; else delays[key].overdueMs += value.overdueMs;
    }
  }
  let newUsers = 0;
  for (const user of users) {
    if (within(user.createdAt)) { newUsers++; byDay.get(day(time(user.createdAt))).newUsers++; }
  }
  const medicines = new Map();
  for (const order of requested) {
    if (!within(order.createdAt)) continue;
    const distinct = new Map();
    for (const medicine of Array.isArray(order.medicines) ? order.medicines : []) {
      const name = String(medicine.medicineName || medicine.name || medicine.scientificName || "").trim();
      if (name) distinct.set(normalize(name), name);
    }
    // Unit: number of distinct orders requesting a medicine, not package count.
    for (const [key, name] of distinct) {
      const value = medicines.get(key) || {name, orders: 0}; value.orders++; medicines.set(key, value);
    }
  }
  const regions = new Map();
  for (const pharmacy of pharmacies) {
    const name = String(pharmacy.location?.city || pharmacy.city || pharmacy.region || "مدينة غير مسجلة");
    regions.set(name, (regions.get(name) || 0) + 1);
  }
  return {from: iso(from), until: iso(until), days, total: selected.length, completed, cancelled,
    completionRate: selected.length ? completed / selected.length * 100 : 0,
    cancellationRate: selected.length ? cancelled / selected.length * 100 : 0,
    newUsers, delays, trend, activity: [...activity.values()].sort((a, b) => b.completed - a.completed || a.id.localeCompare(b.id)),
    medicines: [...medicines.values()].sort((a, b) => b.orders - a.orders || a.name.localeCompare(b.name)),
    regions: [...regions].map(([name, count]) => ({name, count})),
    missingOrderDates: orders.filter((order) => time(order.createdAt) === null).length,
    missingUserDates: users.filter((user) => time(user.createdAt) === null).length,
    generatedAt: iso(instant), method: "source_recomputed"};
}
function alerts(orders, pharmacies, requests, medicines, instant) {
  const rows = [];
  for (const order of orders) {
    const summary = delaySummary(order, instant);
    for (const [kind, title, value] of [["pharmacy", "تأخر الصيدلية", summary.pharmacyDelay], ["pickup", "تأخر الاستلام", summary.userDelay]]) {
      if (value.occurred) rows.push({id: `${kind}_${order.id}`, kind, title, name: order.orderNumber || order.id,
        description: order.pharmacyName || "", active: value.active, startedAt: value.startedAt,
        resolvedAt: value.resolvedAt, overdueMs: value.overdueMs, href: `/orders?q=${encodeURIComponent(order.id)}`});
    }
  }
  for (const request of requests.filter((row) => statusOf(row.status) === "pending")) {
    rows.push({id: `registration_${request.id}`, kind: "registration", title: "طلب تسجيل ينتظر القرار", name: request.pharmacyName || "",
      active: true, startedAt: iso(time(request.requestDate || request.createdAt)), href: `/requests?q=${encodeURIComponent(request.id)}`});
  }
  for (const pharmacy of pharmacies.filter((row) => row.status === "approved" && row.isOnline !== true)) {
    rows.push({id: `offline_${pharmacy.id}`, kind: "offline", title: "استقبال الصيدلية متوقف", name: pharmacy.pharmacyName || pharmacy.name || "",
      active: true, startedAt: iso(time(pharmacy.lastStatusUpdate)), href: `/pharmacies?q=${encodeURIComponent(pharmacy.id)}`});
  }
  for (const medicine of medicines.filter((row) => stockState(row, instant).out)) {
    rows.push({id: `stock_${medicine.id}`, kind: "stock", title: "نفاد التوفر", name: medicine.medicineName || medicine.scientificName || "",
      description: medicine.pharmacyName || "", active: true, startedAt: iso(time(medicine.updatedAt)),
      href: `/pharmacies?q=${encodeURIComponent(medicine.pharmacyId || "")}`});
  }
  const expiryLimit = instant + 30 * 86400000;
  for (const medicine of medicines.filter((row) => {
    const expiry = time(row.expiryAt || row.expiryDate);
    return expiry !== null && expiry > instant && expiry <= expiryLimit && stockState(row, instant).available;
  })) {
    const expiry = time(medicine.expiryAt || medicine.expiryDate);
    rows.push({id: `expiry_${medicine.id}`, kind: "expiry", title: "دواء قارب على انتهاء الصلاحية",
      name: medicine.medicineName || medicine.scientificName || "", description: medicine.pharmacyName || "",
      active: true, startedAt: iso(instant), dueAt: iso(expiry), overdueMs: null,
      href: `/pharmacies?q=${encodeURIComponent(medicine.pharmacyId || "")}`});
  }
  return rows.sort((a, b) => (time(b.startedAt) ?? -1) - (time(a.startedAt) ?? -1) || b.id.localeCompare(a.id));
}
function operationalRecommendations(orders, pharmacies, requests, medicines, instant) {
  const DAY = 86400000;
  const since = instant - 30 * DAY;
  const rows = [];
  const orderGroups = new Map();
  for (const order of orders.filter((row) => (time(row.createdAt) ?? 0) >= since)) {
    const id = order.pharmacyId;
    if (!id) continue;
    const group = orderGroups.get(id) || {id, name: order.pharmacyName || "صيدلية غير مسماة", total: 0, rejected: 0, delays: 0};
    group.total++;
    group.rejected += Number(status(order.status) === "rejected");
    group.delays += Number(delaySummary(order, instant).pharmacyDelay.occurred);
    orderGroups.set(id, group);
  }
  for (const group of orderGroups.values()) {
    if (group.delays >= 3) rows.push({id: `repeat-delay_${group.id}`, priority: group.delays >= 5 ? "critical" : "high",
      title: "تأخر متكرر من الصيدلية", entity: group.name,
      reason: `سُجل ${group.delays} تأخيرات خلال آخر 30 يومًا من أصل ${group.total} طلبًا.`,
      recommendation: group.delays >= 5 ? "راجع سجل الطلبات ثم قيّم إخفاء الصيدلية مؤقتًا إذا استمر الأثر على المستخدمين." : "تواصل مع الصيدلية وحدد سبب التأخر قبل اتخاذ قرار الظهور.",
      actionLabel: "مراجعة الصيدلية", href: `/pharmacies?q=${encodeURIComponent(group.id)}`});
    if (group.total >= 5 && group.rejected >= 3 && group.rejected / group.total >= .3) rows.push({id: `repeat-reject_${group.id}`, priority: "high",
      title: "رفض طلبات بمعدل مرتفع", entity: group.name,
      reason: `رُفض ${group.rejected} من ${group.total} طلبات خلال آخر 30 يومًا.`,
      recommendation: "راجع أسباب الرفض والتوفر الفعلي، ثم قيّم إيقاف الظهور إذا كانت الصيدلية تعرض خدمة لا تستطيع تقديمها.",
      actionLabel: "فتح الطلبات", href: `/orders?group=${encodeURIComponent(group.id)}`});
  }
  for (const pharmacy of pharmacies) {
    if (pharmacy.status !== "approved" || pharmacy.isBlocked === true || pharmacy.isOnline === true) continue;
    const stoppedAt = time(pharmacy.lastStatusUpdate);
    const stoppedDays = stoppedAt === null ? null : Math.floor((instant - stoppedAt) / DAY);
    if (stoppedDays === null || stoppedDays < 1) continue;
    rows.push({id: `offline-long_${pharmacy.id}`, priority: stoppedDays >= 7 ? "critical" : stoppedDays >= 3 ? "high" : "medium",
      title: "توقف استقبال الطلبات مدة طويلة", entity: pharmacy.pharmacyName || pharmacy.name || "صيدلية غير مسماة",
      reason: `الاستقبال متوقف منذ ${stoppedDays} يومًا.`,
      recommendation: stoppedDays >= 3 ? "تحقق من سبب التوقف، ثم قيّم إخفاء الصيدلية حتى تعود جاهزة للاستقبال." : "تابع الصيدلية وتأكد من أن التوقف مقصود.",
      actionLabel: "متابعة الصيدلية", href: `/pharmacies?q=${encodeURIComponent(pharmacy.id)}`});
  }
  const stock = new Map();
  const expiry = new Map();
  for (const medicine of medicines) {
    const id = medicine.pharmacyId;
    if (!id) continue;
    if (stockState(medicine, instant).out) {
      const value = stock.get(id) || {count: 0, name: medicine.pharmacyName || "صيدلية غير مسماة"}; value.count++; stock.set(id, value);
    }
    const at = time(medicine.expiryAt || medicine.expiryDate);
    if (at !== null && at > instant && at <= instant + 30 * DAY && stockState(medicine, instant).available) {
      const value = expiry.get(id) || {count: 0, earliest: at, name: medicine.pharmacyName || "صيدلية غير مسماة"};
      value.count++; value.earliest = Math.min(value.earliest, at); expiry.set(id, value);
    }
  }
  for (const [id, value] of stock) if (value.count >= 3) rows.push({id: `stock-cluster_${id}`, priority: value.count >= 10 ? "high" : "medium",
    title: "نفاد عدة أصناف", entity: value.name, reason: `${value.count} أصناف ظاهرة بلا كمية متاحة.`,
    recommendation: "اطلب تحديث المخزون أو إخفاء الأصناف غير المتاحة حتى لا تظهر نتائج غير قابلة للطلب.",
    actionLabel: "فتح الصيدلية", href: `/pharmacies?q=${encodeURIComponent(id)}`});
  for (const [id, value] of expiry) rows.push({id: `expiry-cluster_${id}`, priority: value.earliest - instant <= 7 * DAY ? "high" : "medium",
    title: "أدوية قاربت انتهاء الصلاحية", entity: value.name,
    reason: `${value.count} أصناف متاحة تنتهي خلال 30 يومًا؛ أقرب صلاحية ${iso(value.earliest)?.slice(0, 10)}.`,
    recommendation: "اطلب من الصيدلية مراجعة الكميات وإيقاف عرض أي دفعة غير صالحة قبل انتهائها.",
    actionLabel: "متابعة الصيدلية", href: `/pharmacies?q=${encodeURIComponent(id)}`});
  const oldRequests = requests.filter((row) => statusOf(row.status) === "pending" && instant - (time(row.requestDate || row.createdAt) ?? instant) >= 2 * DAY);
  if (oldRequests.length) rows.push({id: "registration-backlog", priority: oldRequests.length >= 5 ? "high" : "medium",
    title: "طلبات تسجيل متراكمة", entity: "فريق المراجعة", reason: `${oldRequests.length} طلبات تنتظر القرار منذ 48 ساعة أو أكثر.`,
    recommendation: "ابدأ بالأقدم وراجع اكتمال المستندات قبل إصدار القرار.", actionLabel: "فتح طلبات التسجيل", href: "/requests?state=pending"});
  const rank = {critical: 3, high: 2, medium: 1};
  rows.sort((a, b) => rank[b.priority] - rank[a.priority] || a.id.localeCompare(b.id));
  return {rows, summary: {critical: rows.filter((row) => row.priority === "critical").length,
    high: rows.filter((row) => row.priority === "high").length, medium: rows.filter((row) => row.priority === "medium").length}};
}
function buildAdminInsights({db, auth, clock = () => Date.now()}) {
  return async (request) => {
    const input = request.data || {};
    const mode = input.mode;
    const permissions = {dashboard: "dashboard.view", reports: "reports.view", coverage: "coverage.view", alerts: "alerts.view"};
    if (!Object.hasOwn(permissions, mode)) throw new HttpsError("invalid-argument", "البيانات المطلوبة غير معروفة.");
    await authorize({db, auth, request, permission: permissions[mode]});
    const instant = clock();
    // No arbitrary 1,000/3,000 cap: page through sources on the server. Only safe
    // aggregate values or pharmacy locations reach the administrative client.
    const [pharmacies, medicines] = await Promise.all([
      scan(db, "pharmacies", ["pharmacyName", "name", "status", "isOnline", "isBlocked", "isActive", "location", "city", "region", "lastStatusUpdate"]),
      mode === "reports" ? [] : scan(db, "medicine_search_index", ["medicineName", "scientificName", "pharmacyId", "pharmacyName", "isActive", "isExpired", "invalidExpiry", "invalidStock", "expiryAt", "expiryDate", "sellByPiece", "availableQuantity", "availablePieceQuantity", "pharmacyVisible", "updatedAt"]),
    ]);
    if (mode === "coverage") {
      const available = new Set(medicines.filter((row) => stockState(row, instant).available).map((row) => row.pharmacyId));
      const rows = pharmacies.map((row) => ({...project("pharmacies", row.id, row).row,
        hasAvailableStock: available.has(row.id), coordinatesValid: validPoint(row.location)}));
      return {rows, total: rows.length, invalidCoordinates: rows.filter((row) => !row.coordinatesValid).length, generatedAt: iso(instant)};
    }
    const orders = await scan(db, "adminOrderSummaries");
    if (mode === "reports") {
      const days = Number(input.days || 30);
      if (![7, 30, 90, 365].includes(days)) throw new HttpsError("invalid-argument", "الفترة غير مدعومة.");
      const [users, requested] = await Promise.all([scan(db, "users", ["createdAt"]), scan(db, "orders", ["createdAt", "medicines"])]);
      return report(orders, users, pharmacies, requested, days, instant);
    }
    const requests = await scan(db, "pharmacyRequests", ["status", "pharmacyName", "requestDate", "createdAt"]);
    const allAlerts = alerts(orders, pharmacies, requests, medicines, instant);
    const decisions = operationalRecommendations(orders, pharmacies, requests, medicines, instant);
    if (mode === "alerts") {
      const kind = String(input.kind || "all");
      const state = String(input.state || "active");
      const q = normalize(input.q);
      const rows = allAlerts.filter((row) => (kind === "all" || row.kind === kind || kind === "delay" && ["pharmacy", "pickup"].includes(row.kind)) &&
        (state === "all" || row.active === (state === "active")) && normalize(`${row.title} ${row.name} ${row.description || ""}`).includes(q));
      const offset = Number(input.offset || 0);
      if (!Number.isSafeInteger(offset) || offset < 0) throw new HttpsError("invalid-argument", "الصفحة غير صالحة.");
      return {rows: rows.slice(offset, offset + 50), total: rows.length, hasMore: rows.length > offset + 50,
        recommendations: decisions.rows, decisionSummary: decisions.summary, generatedAt: iso(instant)};
    }
    const users = await db.collection("users").count().get();
    const statuses = {};
    for (const order of orders) statuses[status(order.status)] = (statuses[status(order.status)] || 0) + 1;
    const today = day(instant);
    const trend = Array.from({length: 7}, (_, index) => {
      const value = day(instant - (6 - index) * 86400000);
      return {day: value, orders: 0, completed: 0};
    });
    const trendByDay = new Map(trend.map((entry) => [entry.day, entry]));
    const recent = orders.filter((order) => (time(order.createdAt) ?? 0) >= instant - 30 * 86400000);
    for (const order of orders) {
      const created = time(order.createdAt);
      const bucket = created === null ? null : trendByDay.get(day(created));
      if (bucket) { bucket.orders++; bucket.completed += Number(status(order.status) === "completed"); }
    }
    const completed30 = recent.filter((order) => status(order.status) === "completed").length;
    const unsuccessful30 = recent.filter((order) => ["cancelled", "rejected", "notCollected"].includes(status(order.status))).length;
    const approved = pharmacies.filter((row) => row.status === "approved");
    const onlineApproved = approved.filter((row) => row.isOnline === true && row.isBlocked !== true).length;
    return {today, todayOrders: orders.filter((order) => time(order.createdAt) !== null && day(time(order.createdAt)) === today).length,
      orders: orders.length, users: users.data().count, pharmacies: pharmacies.length,
      online: pharmacies.filter((row) => row.isOnline === true).length,
      approvedPharmacies: approved.length, onlineApproved, offlineApproved: approved.length - onlineApproved,
      pending: requests.filter((row) => statusOf(row.status) === "pending").length,
      delays: allAlerts.filter((row) => ["pharmacy", "pickup"].includes(row.kind) && row.active).length,
      pharmacyDelays: allAlerts.filter((row) => row.kind === "pharmacy" && row.active).length,
      pickupDelays: allAlerts.filter((row) => row.kind === "pickup" && row.active).length,
      outOfStock: allAlerts.filter((row) => row.kind === "stock").length,
      nearExpiry: allAlerts.filter((row) => row.kind === "expiry").length,
      completionRate30: recent.length ? completed30 / recent.length * 100 : 0,
      unsuccessfulRate30: recent.length ? unsuccessful30 / recent.length * 100 : 0,
      trend, statuses,
      recommendations: decisions.rows.slice(0, 5), decisionSummary: decisions.summary, generatedAt: iso(instant)};
  };
}
module.exports = {scan, report, alerts, operationalRecommendations, stockState, validPoint, buildAdminInsights};
