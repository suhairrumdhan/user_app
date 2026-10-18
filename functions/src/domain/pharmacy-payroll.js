"use strict";

const {createHash} = require("node:crypto");
const {Timestamp} = require("firebase-admin/firestore");
const {OrderContractError} = require("./order-contract");

function reject(message, code = "failed-precondition") {
  throw new OrderContractError(code, message);
}
function recordId(value) {
  if (typeof value !== "string" || !value.trim() || value.includes("/") || value.length > 128) {
    reject("معرف سجل الراتب غير صالح.", "invalid-argument");
  }
  return value.trim();
}
function expectedVersion(value, actual) {
  if (!Number.isSafeInteger(value) || value !== actual) {
    reject("تغيرت بيانات الراتب في جلسة أخرى. حدّث البيانات وراجعها قبل الاعتماد.");
  }
}
function audit(ctx, ref, name, before, after) {
  ctx.audit = {module: "payroll", targetType: "salary", targetId: ref.id,
    targetName: name, source: "server", entityPath: ref.path,
    details: {oldValues: before, newValues: after}};
}

function asDate(value) {
  if (value?.toDate) return value.toDate();
  if (value instanceof Date) return value;
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

async function workedUnitsFromShifts(ctx, employeeId, salaryType, year, month) {
  if (salaryType === "monthly") return {units: 1, shiftIds: []};
  const start = new Date(Date.UTC(year, month - 1, 1));
  const end = new Date(Date.UTC(year, month, 1));
  const now = asDate(ctx.timestamp) || new Date();
  const shifts = ctx.pharmacy.collection("shifts");
  const [byId, byKey] = await Promise.all([
    ctx.tx.get(shifts.where("openedById", "==", employeeId)),
    ctx.tx.get(shifts.where("openedByKey", "==", `employee:${employeeId}`)),
  ]);
  const documents = new Map([...byId.docs, ...byKey.docs].map((document) => [document.id, document]));
  let milliseconds = 0;
  const days = new Set();
  const shiftIds = [];
  for (const document of documents.values()) {
    const shift = document.data() || {};
    if (!["open", "closed"].includes(String(shift.status || "").toLowerCase())) continue;
    const openedAt = asDate(shift.openedAt);
    const closedAt = asDate(shift.closedAt) || (shift.status === "open" ? now : null);
    if (!openedAt || !closedAt || closedAt <= start || openedAt >= end) continue;
    const from = openedAt > start ? openedAt : start;
    const to = closedAt < end ? closedAt : end;
    if (to <= from) continue;
    shiftIds.push(document.id);
    milliseconds += to.getTime() - from.getTime();
    for (let cursor = Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), from.getUTCDate());
      cursor < to.getTime(); cursor += 86400000) days.add(new Date(cursor).toISOString().slice(0, 10));
  }
  const units = salaryType === "hourly" ? Math.round(milliseconds / 36000) / 100 : days.size;
  if (units <= 0) reject("لا توجد ورديات عمل مسجلة للموظف في الفترة المحددة.");
  return {units, shiftIds};
}

// Period entitlements are immutable snapshots. Payments settle an entitlement;
// they do not book its payroll expense a second time.
async function postPayroll(ctx, payload, command, {money, method, ledger, openShift, addAmount}) {
  if (ctx.actor.type !== "owner") {
    reject("إدارة الرواتب وصرفها متاحان لصاحب الصيدلية فقط.", "permission-denied");
  }
  if (command === "postSalaryPayment") {
    const periodRef = ctx.pharmacy.collection("payroll_periods").doc(recordId(payload.periodId));
    const period = (await ctx.tx.get(periodRef)).data();
    if (!period || period.financialPosted !== true) reject("استحقاق الراتب غير موجود أو غير معتمد.");
    expectedVersion(payload.expectedVersion, period.version);
    const total = money(period.amount); const paid = money(period.paidAmount);
    const remaining = money(period.remainingAmount);
    if (paid + remaining !== total) reject("رصيد استحقاق الراتب يحتاج إلى مطابقة قبل صرف دفعة.");
    const amount = money(payload.amount);
    if (!amount || amount > remaining) reject("أدخل مبلغًا أكبر من صفر لا يتجاوز المتبقي من استحقاق الراتب.", "invalid-argument");
    const paymentMethod = method(payload.paymentMethod);
    if (payload.shiftId && paymentMethod !== "cash") reject("الصرف من درج الوردية متاح للدفعات النقدية فقط.");
    const shift = payload.shiftId ? await openShift(ctx, payload.shiftId) : null;
    const employeeRef = ctx.pharmacy.collection("employees").doc(recordId(period.employeeId));
    const employee = (await ctx.tx.get(employeeRef)).data();
    if (!employee) reject("سجل الموظف المرتبط بالاستحقاق غير موجود.");
    const notes = String(payload.notes || "").trim();
    if (notes.length > 500) reject("ملاحظات الدفعة يجب ألا تتجاوز 500 حرف.", "invalid-argument");
    const paymentId = `salary-${ctx.key}`;
    const receipt = {id: paymentId, pharmacyId: ctx.pharmacy.id,
      periodId: periodRef.id, period: period.period, year: period.year, month: period.month,
      employeeId: period.employeeId, employeeName: period.employeeName,
      amount: amount / 100, paymentMethod, shiftId: shift?.ref.id || null,
      balanceBefore: remaining / 100, balanceAfter: (remaining - amount) / 100,
      notes, paidAt: ctx.timestamp, createdAt: ctx.timestamp, createdBy: ctx.actor.id,
      operationId: ctx.operationId, financialPosted: true};
    ctx.tx.create(ctx.pharmacy.collection("salary_payments").doc(paymentId), receipt);
    const newValues = {paidAmount: (paid + amount) / 100, remainingAmount: (remaining - amount) / 100,
      status: amount === remaining ? "paid" : "partial", version: period.version + 1,
      lastPaymentAt: ctx.timestamp, updatedAt: ctx.timestamp};
    ctx.tx.update(periodRef, newValues);
    ctx.tx.update(employeeRef, {totalPaidSalary: addAmount(employee, "totalPaidSalary", amount)});
    if (shift) ctx.tx.update(shift.ref, {salaryPayments: addAmount(shift.data, "salaryPayments", amount),
      updatedAt: ctx.timestamp});
    ledger(ctx, "salary-payment", {type: "salaryPayment", accountType: "payrollExpense", direction: "outflow",
      amount: amount / 100, paymentMethod, shiftId: shift?.ref.id || null,
      employeeId: period.employeeId, employeeName: period.employeeName,
      referenceId: paymentId, referenceNumber: period.period, referenceCollection: "salary_payments",
      title: `دفعة راتب ${period.employeeName} • ${period.period}`, notes,
      metadata: {source: "payroll", operationId: ctx.operationId, periodId: periodRef.id,
        payrollPeriod: period.period, settlesAccrual: true}});
    audit(ctx, periodRef, period.employeeName,
      {paidAmount: period.paidAmount, remainingAmount: period.remainingAmount, version: period.version},
      {...newValues, paymentId, amount: amount / 100, paymentMethod, shiftId: shift?.ref.id || null});
    return {periodId: periodRef.id, paymentId, paidAmount: newValues.paidAmount,
      remainingAmount: newValues.remainingAmount, status: newValues.status, version: newValues.version};
  }

  const employeeRef = ctx.pharmacy.collection("employees").doc(recordId(payload.employeeId));
  const employee = (await ctx.tx.get(employeeRef)).data();
  if (!employee) reject("الموظف غير موجود.", "not-found");
  if (employee.isActive !== true) reject("اختر موظفًا نشطًا لتسجيل بيانات راتبه أو استحقاق جديد.");
  const version = Number(employee.salaryProfileVersion || 0);
  expectedVersion(payload.expectedProfileVersion, version);
  if (command === "saveSalaryProfile") {
    const salaryType = payload.salaryType;
    if (!["monthly", "daily", "hourly"].includes(salaryType)) reject("اختر نوع راتب صحيحًا.", "invalid-argument");
    const rate = money(payload.rate);
    if (!rate) reject("قيمة الراتب أو الأجر يجب أن تكون أكبر من صفر.", "invalid-argument");
    if (typeof payload.affectsFinance !== "boolean") reject("حدد تفعيل استحقاقات الراتب.", "invalid-argument");
    const newValues = {salaryType, [salaryType === "hourly" ? "hourlyRate" : "baseSalary"]: rate / 100,
      affectsFinance: payload.affectsFinance, salaryProfileVersion: version + 1,
      salaryProfileUpdatedAt: ctx.timestamp, salaryProfileUpdatedBy: ctx.actor.id};
    ctx.tx.update(employeeRef, newValues);
    audit(ctx, employeeRef, employee.name, {salaryType: employee.salaryType || null,
      baseSalary: employee.baseSalary ?? null, hourlyRate: employee.hourlyRate ?? null,
      affectsFinance: employee.affectsFinance !== false, salaryProfileVersion: version}, newValues);
    return {employeeId: employeeRef.id, salaryProfileVersion: version + 1};
  }

  if (command !== "accrueSalary") reject("أمر رواتب غير معروف.", "invalid-argument");
  if (!version || employee.affectsFinance === false) reject("احفظ ملف الراتب وفعّل الاستحقاقات قبل اعتماد فترة.");
  const year = payload.year; const month = payload.month;
  if (!Number.isSafeInteger(year) || year < 2000 || year > 9999 || !Number.isSafeInteger(month) || month < 1 || month > 12) {
    reject("فترة الراتب غير صالحة.", "invalid-argument");
  }
  const period = `${year}-${String(month).padStart(2, "0")}`;
  const periodId = `${createHash("sha256").update(employeeRef.id).digest("hex").slice(0, 32)}-${period}`;
  const periodRef = ctx.pharmacy.collection("payroll_periods").doc(periodId);
  if ((await ctx.tx.get(periodRef)).exists) reject("استحقاق هذه الفترة مسجل بالفعل لهذا الموظف. افتحه لتسجيل دفعة.");
  const salaryType = employee.salaryType;
  if (!["monthly", "daily", "hourly"].includes(salaryType)) reject("نوع الراتب المحفوظ غير صالح. صحّح ملف الراتب.");
  const worked = await workedUnitsFromShifts(ctx, employeeRef.id, salaryType, year, month);
  const units = worked.units;
  const rate = money(salaryType === "hourly" ? employee.hourlyRate : employee.baseSalary);
  if (!rate) reject("قيمة الأجر المحفوظة غير صالحة. صحّح ملف الراتب.");
  const amountCents = (BigInt(rate) * BigInt(Math.round(units * 100)) + 50n) / 100n;
  if (amountCents > 100000000000000n) reject("مبلغ استحقاق الراتب يتجاوز الحد المالي المسموح.", "invalid-argument");
  const amount = Number(amountCents);
  if (!amount) reject("مبلغ الاستحقاق أقل من أصغر وحدة مالية.", "invalid-argument");
  const notes = String(payload.notes || "").trim();
  if (notes.length > 500) reject("ملاحظات الاستحقاق يجب ألا تتجاوز 500 حرف.", "invalid-argument");
  const entitlement = {id: periodId, pharmacyId: ctx.pharmacy.id, employeeId: employeeRef.id,
    employeeName: String(employee.name || ""), period, year, month, salaryType, rate: rate / 100,
    units, unitSource: salaryType === "monthly" ? "monthly" : "shifts",
    sourceShiftIds: worked.shiftIds, salaryProfileVersion: version,
    amount: amount / 100, paidAmount: 0, remainingAmount: amount / 100,
    status: "unpaid", version: 1, notes, financialPosted: true, operationId: ctx.operationId,
    createdAt: ctx.timestamp, updatedAt: ctx.timestamp, createdBy: ctx.actor.id};
  ctx.tx.create(periodRef, entitlement);
  ledger(ctx, "salary-accrual", {type: "salaryAccrual", accountType: "payrollExpense", direction: "payable",
    amount: amount / 100, employeeId: employeeRef.id, employeeName: entitlement.employeeName,
    referenceId: periodId, referenceNumber: period, referenceCollection: "payroll_periods",
    transactionDate: Timestamp.fromDate(new Date(Date.UTC(year, month - 1, 1))),
    title: `استحقاق راتب ${entitlement.employeeName} • ${period}`, notes,
    metadata: {source: "payroll", operationId: ctx.operationId, payrollPeriod: period, cashMovement: false}});
  audit(ctx, periodRef, entitlement.employeeName, null, entitlement);
  return {periodId, amount: amount / 100, paidAmount: 0, remainingAmount: amount / 100, version: 1};
}

module.exports = {postPayroll};
