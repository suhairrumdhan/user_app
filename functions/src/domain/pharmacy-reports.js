"use strict";

const {resolvePharmacyPrincipal, permissionAllowed} = require("../auth/authorization");
const {OrderContractError} = require("./order-contract");

const sources = {sales: "sales", inventory: "medicines", purchases: "purchase_invoices",
  shifts: "shifts", finance: "financial_transactions"};
const titles = {sales: "تقرير المبيعات", inventory: "تقرير المخزون الحالي", purchases: "تقرير المشتريات",
  shifts: "تقرير الورديات", finance: "تقرير العمليات المالية"};
const column = (key, label, kind = "text") => ({key, label, kind});
const columns = {
  sales: [column("date", "التاريخ", "date"), column("reference", "الفاتورة"), column("name", "الموظف"),
    column("state", "النوع"), column("method", "الدفع"), column("customer", "حصة العميل", "money"),
    column("insurance", "حصة التأمين", "money"), column("amount", "صافي البيع", "money")],
  inventory: [column("name", "الدواء"), column("barcode", "الباركود"), column("quantity", "العبوات", "number"),
    column("pieces", "القطع", "number"), column("reserved", "المحجوز عبوات", "number"),
    column("reservedPieces", "المحجوز قطع", "number"), column("expiry", "الصلاحية", "date")],
  purchases: [column("date", "تاريخ الفاتورة", "date"), column("reference", "الفاتورة"), column("name", "المورد"),
    column("state", "الحالة"), column("amount", "الإجمالي", "money"), column("paid", "المدفوع حتى الآن", "money"),
    column("remaining", "المتبقي", "money")],
  shifts: [column("date", "بداية الوردية", "date"), column("name", "المستخدم"), column("state", "الحالة"),
    column("opening", "الافتتاحي", "money"), column("expected", "النقد المتوقع", "money"),
    column("closing", "نقد الإغلاق", "money"), column("difference", "فرق الإغلاق", "money")],
  finance: [column("date", "التاريخ", "date"), column("name", "الحركة"), column("reference", "المرجع"),
    column("state", "الاتجاه"), column("method", "طريقة الدفع"), column("amount", "المبلغ", "money")],
};
function reject(message) { throw new OrderContractError("failed-precondition", message); }
function cents(value) {
  if (value == null) return 0;
  if (typeof value !== "number" || !Number.isFinite(value)) reject("توجد قيمة مالية غير صالحة في مصدر التقرير. يلزم تصحيح السجل قبل اعتماده.");
  const result = Math.round(value * 100);
  if (!Number.isSafeInteger(result)) reject("القيمة المالية تتجاوز الدقة العددية المسموحة للتقرير.");
  return result;
}
function number(value) { return typeof value === "number" && Number.isFinite(value) ? value : 0; }
function label(value) { return String(value ?? ""); }
function instant(value) {
  if (value?.toMillis) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "string") return Date.parse(value);
  return NaN;
}
function iso(value) { const time = instant(value); return Number.isFinite(time) ? new Date(time).toISOString() : null; }
function payment(value) {
  return ({cash: "نقدي", card: "بطاقة", bank: "مصرفي", insurance: "تأمين", transfer: "مصرفي"})[value] || label(value) || "—";
}
function normalized(value) {
  return label(value).toLowerCase().replace(/[\u064b-\u065f\u0670]/g, "").replace(/[أإآ]/g, "ا")
    .replace(/[٠-٩]/g, (digit) => String("٠١٢٣٤٥٦٧٨٩".indexOf(digit)))
    .replace(/[۰-۹]/g, (digit) => String("۰۱۲۳۴۵۶۷۸۹".indexOf(digit))).trim();
}
function project(type, id, data) {
  if (type === "inventory") {
    if (data.isDeleted === true || data.isActive === false) return null;
    return {id, name: label(data.name), barcode: label(data.barcode), quantity: number(data.quantity),
      pieces: number(data.pieceQuantity), reserved: number(data.reservedQuantity),
      reservedPieces: number(data.reservedPieceQuantity), expiry: iso(data.expiryDate), state: "current",
      search: `${id} ${label(data.name)} ${label(data.scientificName)} ${label(data.barcode)}`};
  }
  if (type === "sales") {
    if (data.isDeleted === true || data.status !== "completed" || ["orderReversal", "openingBalance"].includes(data.source) ||
      (data.source === "order" && data.paymentState !== "delivered")) return null;
    const refund = data.type === "refund";
    const customer = refund ? -cents(data.customerRefund ?? data.subtotal) : cents(data.total);
    const insurance = refund ? -cents(data.insuranceRefund) : cents(data.insuranceDiscount);
    return {id, date: iso((data.source === "order" ? data.deliveredAt : data.completedAt) ?? data.saleDate ?? data.createdAt),
      reference: label(data.invoiceNumber || id), name: label(data.employeeName || data.createdByName || data.employeeId || data.createdBy),
      state: refund ? "مرتجع" : "بيع", method: payment(data.paymentMethod), customer: customer / 100,
      insurance: insurance / 100, amount: (customer + insurance) / 100,
      search: `${id} ${label(data.invoiceNumber)} ${label(data.employeeName)} ${label(data.customerName)} ${label(data.insuranceCompanyName)}`};
  }
  if (type === "purchases") {
    if (["draft", "cancelled"].includes(data.status) || data.source === "openingBalance") return null;
    const amount = cents(data.total); const paid = cents(data.paid);
    if (paid < 0 || paid > amount) reject("مدفوعات فاتورة مشتريات غير متزنة. يلزم مطابقتها قبل اعتماد التقرير.");
    return {id, date: iso(data.invoiceDate ?? data.createdAt), reference: label(data.invoiceNumber || id),
      name: label(data.supplierName), state: amount === paid ? "مسددة" : paid ? "مسددة جزئيًا" : "غير مسددة",
      amount: amount / 100, paid: paid / 100, remaining: (amount - paid) / 100,
      search: `${id} ${label(data.invoiceNumber)} ${label(data.supplierName)}`};
  }
  if (type === "shifts") {
    const expected = cents(data.openingCash) + cents(data.cashTotal) - cents(data.cashRefunds) -
      cents(data.shiftExpenses) - cents(data.supplierPayments) - cents(data.salaryPayments) +
      cents(data.manualCashIn) - cents(data.manualCashOut);
    const closed = data.status === "closed";
    return {id, date: iso(data.openedAt ?? data.createdAt), name: label(data.openedByName || data.openedBy?.name || data.openedById),
      state: closed ? "مغلقة" : "مفتوحة", opening: cents(data.openingCash) / 100, expected: expected / 100,
      closing: closed ? cents(data.closingCash) / 100 : null,
      difference: closed ? (cents(data.closingCash) - expected) / 100 : null,
      search: `${id} ${label(data.openedByName)} ${label(data.openedById)}`};
  }
  if (data.isPosted === false || data.isVoided === true) return null;
  const direction = ({inflow: "قبض", outflow: "صرف", payable: "التزام", receivable: "استحقاق", neutral: "غير نقدي"})[data.direction] || "غير نقدي";
  return {id, date: iso(data.transactionDate ?? data.createdAt), name: label(data.title || data.description || data.type),
    reference: label(data.referenceNumber || data.referenceId || id), state: direction, method: payment(data.paymentMethod),
    amount: cents(data.amount) / 100, direction: data.direction || "neutral",
    search: `${id} ${label(data.title)} ${label(data.referenceId)} ${label(data.referenceNumber)} ${label(data.employeeName)} ${label(data.supplierName)} ${label(data.insuranceCompanyName)}`};
}
function summarize(type, rows) {
  const sum = (key, predicate = () => true) => {
    const value = rows.filter(predicate).reduce((total, row) => total + BigInt(cents(row[key])), 0n);
    if (value > BigInt(Number.MAX_SAFE_INTEGER) || value < -BigInt(Number.MAX_SAFE_INTEGER)) reject("مجموع التقرير يتجاوز الدقة العددية المسموحة. اختر فترة أصغر.");
    return Number(value) / 100;
  };
  if (type === "sales") return {"عدد الحركات": rows.length, "حصة العملاء الصافية": sum("customer"), "حصة التأمين الصافية": sum("insurance"), "صافي المبيعات بعد المرتجعات": sum("amount")};
  if (type === "purchases") return {"عدد الفواتير": rows.length, "المشتريات المعتمدة": sum("amount"), "المسدد حتى الآن": sum("paid"), "المتبقي حتى الآن": sum("remaining")};
  if (type === "shifts") return {"عدد الورديات": rows.length, "المغلقة": rows.filter((row) => row.state === "مغلقة").length,
    "فروق إغلاق الورديات": sum("difference", (row) => row.state === "مغلقة")};
  if (type === "inventory") return {"عدد الأدوية": rows.length};
  return {"عدد الحركات": rows.length, "القبض خلال الفترة": sum("amount", (row) => row.direction === "inflow"),
    "الصرف خلال الفترة": sum("amount", (row) => row.direction === "outflow"),
    "صافي التدفق خلال الفترة": (cents(sum("amount", (row) => row.direction === "inflow")) - cents(sum("amount", (row) => row.direction === "outflow"))) / 100};
}

function buildPharmacyReport({db}) {
  return async (request) => {
    const input = request.data || {}; const type = input.type;
    if (!Object.hasOwn(sources, type)) reject("اختر نوع تقرير صحيحًا.");
    const search = normalized(input.search);
    if (search.length > 120) reject("نص البحث لا يتجاوز 120 حرفًا.");
    const start = input.startAt; const end = input.endAt;
    if (type !== "inventory" && (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start >= end ||
      start < Date.UTC(2000, 0, 1) || end > Date.UTC(9999, 11, 31))) reject("حدد بداية ونهاية صحيحتين لفترة التقرير.");
    // One server read snapshot: report rows and totals cannot combine versions
    // from either side of a concurrent sale, payment, or stock transaction.
    return db.runTransaction(async (transaction) => {
      const actor = await resolvePharmacyPrincipal({db, auth: request.auth, pharmacyId: input.pharmacyId,
        permission: "finance.view", transaction});
      if (actor.type !== "owner" && !permissionAllowed(actor.employee, actor.permissionDoc, "finance.reports.export")) {
        throw new OrderContractError("permission-denied", "ليس لديك صلاحية عرض وتصدير هذه التقارير المالية.");
      }
      const snapshot = await transaction.get(actor.pharmacyRef.collection(sources[type]));
      const rows = [];
      for (const doc of snapshot.docs) {
        const row = project(type, doc.id, doc.data());
        if (!row) continue;
        if (type !== "inventory") {
          const time = Date.parse(row.date);
          if (!Number.isFinite(time)) reject("توجد حركة بلا تاريخ صالح. يلزم مطابقتها قبل اعتماد التقرير.");
          if (time < start || time >= end) continue;
        }
        if (search && !normalized(`${row.search} ${row.state} ${row.method || ""}`).includes(search)) continue;
        delete row.search;
        rows.push(row);
      }
      if (rows.length > 10000) reject("التقرير يتجاوز 10000 سجل. ضيّق الفترة أو البحث ثم أعد العرض؛ لم تُصدّر نتائج ناقصة.");
      rows.sort((a, b) => type === "inventory" ? a.name.localeCompare(b.name, "ar") : label(a.date).localeCompare(label(b.date)) || a.id.localeCompare(b.id));
      const notes = type === "inventory" ? "مخزون حالي وقت إعداد التقرير؛ الكمية المحجوزة جزء من الرصيد وليست كمية إضافية. تاريخ الصلاحية هو التاريخ المسجل على بطاقة الدواء."
        : type === "sales" ? "مبيعات مكتملة وطلبات مسلّمة فقط، مطروحًا منها المرتجعات. حصة التأمين استحقاق وليست قبضًا نقديًا. تاريخ الطلب هو تاريخ التسليم."
          : type === "purchases" ? "فواتير مشتريات معتمدة؛ تستبعد المسودات والملغاة والأرصدة الافتتاحية. المدفوع والمتبقي حتى وقت إعداد التقرير، وليسا حركة الصرف خلال الفترة."
            : type === "shifts" ? "تحدد الفترة بحسب بداية الوردية. لا يُعرض نقد إغلاق للورديات المفتوحة. فروق الورديات لا تجمع الأرصدة الافتتاحية للصندوق."
              : "حركات دفتر المالية المعتمدة بتاريخها، بما فيها القيود غير النقدية. القبض والصرف فقط يدخلان في صافي التدفق؛ الاستحقاق أو الالتزام لا يعني تحصيلًا أو دفعًا.";
      const result = {type, title: titles[type], columns: columns[type], rows, totals: summarize(type, rows), notes,
        generatedAt: snapshot.readTime.toDate().toISOString(), startAt: type === "inventory" ? null : start,
        endAt: type === "inventory" ? null : end, search: label(input.search).trim(), pharmacyId: actor.pharmacyId};
      if (Buffer.byteLength(JSON.stringify(result), "utf8") > 8 * 1024 * 1024) reject("حجم التقرير كبير. ضيّق الفترة أو البحث قبل الحفظ؛ لم تُحذف سجلات من النتيجة.");
      return result;
    }, {readOnly: true});
  };
}

module.exports = {buildPharmacyReport};
