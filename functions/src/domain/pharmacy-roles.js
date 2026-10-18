"use strict";

const defaults = require("./registration-default-permissions");
const {OrderContractError} = require("./order-contract");

function reject(message, code = "invalid-argument") {
  throw new OrderContractError(code, message);
}

// The owner manages role definitions; a role never grants owner identity.
// Role metadata and its effective permission map share one transaction/version.
async function savePharmacyRole(ctx, payload, command) {
  if (ctx.actor.type !== "owner") {
    reject("إدارة تعريفات الأدوار متاحة لصاحب الصيدلية فقط.", "permission-denied");
  }
  const roleId = String(payload.roleId || "").trim();
  const name = String(payload.name || "").trim();
  const description = String(payload.description || "").trim();
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(roleId) || ["owner", "super_admin"].includes(roleId)) {
    reject("معرف الدور غير صالح.");
  }
  if (!name || name.length > 80 || description.length > 240) {
    reject("أدخل اسم دور من 1 إلى 80 حرفًا ووصفًا لا يتجاوز 240 حرفًا.");
  }
  const source = payload.permissions;
  if (!source || typeof source !== "object" || Array.isArray(source)) {
    reject("اختر صلاحيات الدور قبل الحفظ.");
  }
  const roleRef = ctx.pharmacy.collection("roles").doc(roleId);
  const permissionsRef = ctx.pharmacy.collection("permissions").doc(roleId);
  const roleSnapshot = await ctx.tx.get(roleRef);
  const permissionSnapshot = await ctx.tx.get(permissionsRef);
  const before = roleSnapshot.data() || {};
  const oldPermissions = permissionSnapshot.data()?.permissions || {};
  const creating = command === "createRole";
  if (creating && (roleSnapshot.exists || permissionSnapshot.exists)) {
    reject("الدور موجود بالفعل. افتحه من القائمة لتعديله.", "already-exists");
  }
  if (!creating && !roleSnapshot.exists) reject("الدور لم يعد موجودًا.", "not-found");
  const version = Number(before.version || 0);
  if (!Number.isSafeInteger(payload.expectedVersion) || payload.expectedVersion !== version) {
    reject("تغير الدور في جلسة أخرى. أعد تحميله وراجع صلاحياته قبل الحفظ.", "failed-precondition");
  }
  const known = new Set([...Object.values(defaults).flatMap((role) => Object.keys(role)),
    "messages.view", ...Object.keys(oldPermissions)]);
  for (const [key, value] of Object.entries(source)) {
    if (!known.has(key) || typeof value !== "boolean") reject("توجد صلاحية غير معروفة أو قيمة غير صحيحة.");
  }
  const permissions = Object.fromEntries([...known].map((key) => [key, source[key] === true]));
  const newValues = {name, description, permissions, version: version + 1};
  const roleData = {id: roleId, name, description, version: version + 1,
    isSystem: before.isSystem === true, updatedAt: ctx.timestamp, updatedBy: ctx.actor.id};
  if (creating) Object.assign(roleData, {createdAt: ctx.timestamp, createdBy: ctx.actor.id});
  ctx.tx.set(roleRef, roleData, {merge: !creating});
  ctx.tx.set(permissionsRef, {permissions, roleName: name, version: version + 1,
    updatedAt: ctx.timestamp, updatedBy: ctx.actor.id});
  ctx.audit = {module: "employees", targetType: "role", targetId: roleId, targetName: name,
    source: "server", entityPath: roleRef.path,
    details: {oldValues: creating ? null : {name: before.name || "", description: before.description || "",
      permissions: oldPermissions, version}, newValues}};
  return {roleId, name, version: version + 1};
}

module.exports = {savePharmacyRole};
