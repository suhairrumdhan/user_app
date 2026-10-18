"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {Timestamp} = require("firebase-admin/firestore");
const {FakeFirestore} = require("./helpers/fake-firestore");
const {seedEmployeeSession} = require("./helpers/employee-session");
const {buildPharmacyFinanceCommand} = require("../../src/domain/pharmacy-finance");
const {loadStock, allocate, writeStock} = require("../../src/domain/batch-stock");
const {collectInsurancePayment} = require("../../src/domain/order-ledger");

const prefix = "pharmacies/pharmacy";
const instant = Date.parse("2026-09-16T09:00:00Z");
const expiry = "2027-01-01T00:00:00Z";
const auth = {uid: "pharmacy", token: {email_verified: true}};
function fixture() {
  return new FakeFirestore({
    [prefix]: {status: "approved", isActive: true},
    [`${prefix}/suppliers/supplier`]: {name: "Supplier", openingBalance: 5},
    [`${prefix}/medicines/medicine`]: {name: "Medicine", quantity: 10, pieceQuantity: 0,
      reservedQuantity: 0, reservedPieceQuantity: 0, unitsPerPackage: 10, sellByPiece: true,
      purchasePrice: 5, sellingPrice: 10, piecePrice: 1, expiryDate: expiry, isActive: true},
    [`${prefix}/shifts/shift`]: {status: "open", pharmacyId: "pharmacy", openedByKey: "owner:pharmacy"},
    [`${prefix}/shift_states/owner:pharmacy`]: {activeShiftId: "shift"},
  });
}
function command(db, name, payload, operationId = "finance-operation-001", identity = auth) {
  return buildPharmacyFinanceCommand({db, clock: () => instant})({auth: identity,
    data: {pharmacyId: "pharmacy", command: name, payload, operationId}});
}
function purchase() {
  return {supplierId: "supplier", clientDraftId: "purchase-test-draft-001", discount: 0,
    items: [{medicineId: "medicine", quantity: 2, price: 5}],
    stockEntries: [{medicineId: "medicine", packageQty: 2, pieceQty: 0, purchasePrice: 5,
      unitsPerPackage: 10, expiryDate: "2028-01-01T00:00:00Z", batchNumber: "NEW"}]};
}
function sale(quantity = 2) {
  return {invoiceId: "pos-test", sale: {source: "pos", invoiceNumber: "INV-1", shiftId: "shift",
    subtotal: quantity * 10, total: quantity * 10, insuranceDiscount: 0, discount: 0,
    paymentMethod: "cash", items: [{medicineId: "medicine", quantity, unitPrice: 10}]}};
}

test("purchase receipt posts its batch, payable, supplier balance and audit once", async () => {
  const db = fixture(); const request = purchase();
  const result = await command(db, "receivePurchase", request);
  assert.deepEqual(await command(db, "receivePurchase", request), result);
  const invoice = db.read(`${prefix}/purchase_invoices/${result.invoiceId}`);
  assert.equal(invoice.total, 10); assert.equal(invoice.paid, 0);
  assert.equal(db.read(`${prefix}/medicines/medicine`).quantity, 12);
  assert.equal(db.read(`${prefix}/suppliers/supplier`).currentBalance, 15);
  const batch = db.read(`${prefix}/medicines/medicine/batches/${invoice.items[0].batchId}`);
  assert.equal(batch.purchasePrice, 5);
  assert.equal(db.paths(`${prefix}/financial_transactions/`).length, 1);
  assert.equal(db.paths(`${prefix}/audit_logs/`).length, 1);
});

test("purchase draft retry with a new operation does not duplicate stock or payable", async () => {
  const db = fixture(); const request = purchase();
  const first = await command(db, "receivePurchase", request, "purchase-attempt-001");
  const retry = await command(db, "receivePurchase", request, "purchase-attempt-002");
  assert.equal(retry.invoiceId, first.invoiceId);
  assert.equal(retry.alreadyCommitted, true);
  assert.equal(db.read(`${prefix}/medicines/medicine`).quantity, 12);
  assert.equal(db.read(`${prefix}/suppliers/supplier`).currentBalance, 15);
  assert.equal(db.paths(`${prefix}/purchase_invoices/`).length, 1);
  assert.equal(db.paths(`${prefix}/financial_transactions/`).length, 1);
  assert.equal(db.paths(`${prefix}/audit_logs/`).length, 1);
});

test("box purchase converts boxes to packages and keeps package cost", async () => {
  const db = fixture();
  const medicine = db.read(`${prefix}/medicines/medicine`);
  db.write(`${prefix}/medicines/medicine`, {...medicine, unitsPerPackage: 3});
  const request = {supplierId: "supplier", clientDraftId: "box-purchase-draft-001",
    items: [{medicineId: "medicine", quantity: 2, price: 400}],
    stockEntries: [{medicineId: "medicine", packageQty: 80, pieceQty: 0,
      purchaseUnit: "box", purchaseUnitQty: 2, packagesPerBox: 40,
      purchasePrice: 400, unitsPerPackage: 3, expiryDate: "2028-01-01"}]};
  const result = await command(db, "receivePurchase", request, "box-purchase-operation-001");
  const invoice = db.read(`${prefix}/purchase_invoices/${result.invoiceId}`);
  const batch = db.read(`${prefix}/medicines/medicine/batches/${invoice.items[0].batchId}`);
  assert.equal(invoice.total, 800);
  assert.equal(invoice.items[0].receivedPackageQuantity, 80);
  assert.equal(batch.quantity, 80);
  assert.equal(batch.unitsPerPackage, 3);
  assert.equal(batch.purchasePrice, 10);
  assert.equal(db.read(`${prefix}/medicines/medicine`).quantity, 90);
});

test("reusing an operation for different purchase data never creates stock", async () => {
  const db = fixture(); await command(db, "receivePurchase", purchase());
  await assert.rejects(command(db, "receivePurchase", {...purchase(), referenceNumber: "changed"}), {code: "failed-precondition"});
  assert.equal(db.read(`${prefix}/medicines/medicine`).quantity, 12);
});

test("invalid last purchase line rolls back the entire invoice", async () => {
  const db = fixture(); const request = purchase();
  request.items.push({medicineId: "missing", quantity: 1, price: 4});
  request.stockEntries.push({medicineId: "missing", packageQty: 1, pieceQty: 0, purchasePrice: 4});
  const before = [...db.documents];
  await assert.rejects(command(db, "receivePurchase", request));
  assert.deepEqual([...db.documents], before);
});

test("successive supplier payments retain individual receipts and reject overpayment", async () => {
  const db = fixture(); const {invoiceId} = await command(db, "receivePurchase", purchase());
  const request = {invoiceId, amount: 4, paymentMethod: "cash"};
  await command(db, "payPurchase", request, "finance-payment-001");
  await command(db, "payPurchase", request, "finance-payment-001");
  assert.equal(db.read(`${prefix}/purchase_invoices/${invoiceId}`).paid, 4);
  await assert.rejects(command(db, "payPurchase", {...request, amount: 7}, "finance-payment-002"));
  await command(db, "payPurchase", {...request, amount: 6, paymentMethod: "bank"}, "finance-payment-003");
  const invoice = db.read(`${prefix}/purchase_invoices/${invoiceId}`);
  assert.equal(invoice.paid, 10); assert.equal(invoice.cashPaid, 4); assert.equal(invoice.bankPaid, 6);
  assert.equal(invoice.paymentStatus, "paid"); assert.equal(invoice.paymentCount, 2);
  assert.equal(db.paths(`${prefix}/purchase_invoices/${invoiceId}/payments/`).length, 2);
  assert.equal(db.read(`${prefix}/suppliers/supplier`).currentBalance, 5);
});

test("received unpaid purchase is reversed without deleting history", async () => {
  const db = fixture(); const {invoiceId} = await command(db, "receivePurchase", purchase());
  await command(db, "reversePurchase", {invoiceId}, "finance-reversal-001");
  assert.equal(db.read(`${prefix}/purchase_invoices/${invoiceId}`).status, "cancelled");
  assert.equal(db.read(`${prefix}/medicines/medicine`).quantity, 10);
  assert.equal(db.paths(`${prefix}/financial_transactions/`).length, 2);
  assert.equal(db.read(`${prefix}/suppliers/supplier`).currentBalance, 5);
});

test("POS consumes FEFO, posts actual cash once and keeps reservations", async () => {
  const db = fixture(); await command(db, "receivePurchase", purchase());
  await command(db, "postSale", sale(), "finance-pos-001");
  await command(db, "postSale", sale(), "finance-pos-001");
  const invoice = db.read(`${prefix}/sales/pos-test`);
  assert.equal(invoice.batchAllocations[0].batchId, "legacy-opening");
  assert.equal(invoice.cogsTotal, 10);
  assert.equal(db.read(`${prefix}/medicines/medicine`).quantity, 10);
  assert.equal(db.read(`${prefix}/shifts/shift`).cashTotal, 20);
  assert.equal(db.read(`${prefix}/shifts/shift`).salesCount, 1);
});

test("cashier can post UI-priced lines against their exact batches", async () => {
  const db = fixture(); const medicine = db.read(`${prefix}/medicines/medicine`);
  db.write(`${prefix}/medicines/medicine`, {...medicine, batchSchemaVersion: 1, quantity: 20,
    availableQuantity: 20, sellingPrice: 9});
  db.write(`${prefix}/medicines/medicine/batches/first`, {quantity: 10, pieceQuantity: 0,
    reservedQuantity: 0, reservedPieceQuantity: 0, unitsPerPackage: 10,
    expiryDate: "2027-01-01", purchasePrice: 4, sellingPrice: 7});
  db.write(`${prefix}/medicines/medicine/batches/later`, {quantity: 10, pieceQuantity: 0,
    reservedQuantity: 0, reservedPieceQuantity: 0, unitsPerPackage: 10,
    expiryDate: "2028-01-01", purchasePrice: 5, sellingPrice: 8});
  const employee = seedEmployeeSession(db, "pharmacy", "cashier", {
    isActive: true, permissions: {"sales.create": true}, roleId: "cashier"});
  db.write(`${prefix}/shifts/shift`, {status: "open", pharmacyId: "pharmacy",
    openedByKey: "employee:cashier"});
  db.write(`${prefix}/shift_states/employee:cashier`, {activeShiftId: "shift"});
  const request = sale(); request.invoiceId = "batch-priced-pos";
  request.sale.subtotal = 110; request.sale.total = 110;
  request.sale.items = [
    {medicineId: "medicine", batchId: "first", quantity: 10, unitPrice: 7},
    {medicineId: "medicine", batchId: "later", quantity: 5, unitPrice: 8},
  ];
  await command(db, "postSale", request, "batch-priced-pos-operation", employee);
  const invoice = db.read(`${prefix}/sales/batch-priced-pos`);
  assert.deepEqual(invoice.items.map((line) => [line.batchAllocations[0].batchId,
    line.quantity, line.unitPrice]), [["first", 10, 7], ["later", 5, 8]]);
  assert.equal(invoice.subtotal, 110);
  assert.equal(db.read(`${prefix}/medicines/medicine/batches/first`).quantity, 0);
  assert.equal(db.read(`${prefix}/medicines/medicine/batches/later`).quantity, 5);
});

test("FEFO skips expired stock and reserves actual batches", async () => {
  const db = fixture(); const medicine = db.read(`${prefix}/medicines/medicine`);
  db.write(`${prefix}/medicines/medicine`, {...medicine, batchSchemaVersion: 1, quantity: 6});
  for (const [batchId, exp] of [["expired", "2020-01-01"], ["later", "2029-01-01"], ["sooner", "2027-01-01"]]) {
    db.write(`${prefix}/medicines/medicine/batches/${batchId}`, {quantity: 2, pieceQuantity: 0,
      reservedQuantity: 0, reservedPieceQuantity: 0, unitsPerPackage: 10, expiryDate: exp, purchasePrice: 5});
  }
  await db.runTransaction(async (tx) => {
    const stock = await loadStock(tx, db.collection("pharmacies").doc("pharmacy").collection("medicines").doc("medicine"), Timestamp.fromMillis(instant));
    assert.deepEqual(allocate(stock, 3, 0, "reserve").map((v) => v.batchId), ["sooner", "later"]);
    writeStock(tx, stock);
  });
  assert.equal(db.read(`${prefix}/medicines/medicine`).availableQuantity, 1);
  await assert.rejects(command(db, "postSale", sale(2), "finance-pos-reserved"));
  assert.equal(db.read(`${prefix}/medicines/medicine`).quantity, 6);
});

test("closed or foreign shift prevents every sale effect", async () => {
  const db = fixture(); db.write(`${prefix}/shifts/shift`, {status: "closed"});
  const before = [...db.documents];
  await assert.rejects(command(db, "postSale", sale()));
  assert.deepEqual([...db.documents], before);
});

test("server permission denies stock posting and price override for cashier", async () => {
  const db = fixture(); const employee = seedEmployeeSession(db, "pharmacy", "cashier", {
    isActive: true, permissions: {"sales.create": true}, roleId: "cashier"});
  await assert.rejects(command(db, "receivePurchase", purchase(), "finance-forbidden-001", employee), {code: "permission-denied"});
  db.write(`${prefix}/shifts/shift`, {status: "open", pharmacyId: "pharmacy", openedByKey: "employee:cashier"});
  db.write(`${prefix}/shift_states/employee:cashier`, {activeShiftId: "shift"});
  const request = sale(); request.sale.items[0].unitPrice = 1; request.sale.subtotal = 2; request.sale.total = 2;
  await assert.rejects(command(db, "postSale", request, "finance-forbidden-002", employee), {code: "permission-denied"});
});

test("insured POS return refunds customer only, quarantines stock, creates company credit", async () => {
  const db = fixture();
  db.write(`${prefix}/insurance_companies/company`, {name: "Insurer", status: "active", discountPercentage: 50, currentReceivable: 0});
  const request = sale(); request.sale.insuranceCompanyId = "company";
  request.sale.total = 10; request.sale.insuranceDiscount = 10;
  await command(db, "postSale", request, "finance-insured-001");
  await db.runTransaction((transaction) => collectInsurancePayment({transaction, db, pharmacyId: "pharmacy",
    actor: {id: "pharmacy"}, payload: {companyId: "company", amount: 10, paymentMethod: "bank"},
    operationKey: "test-collection", timestamp: Timestamp.fromMillis(instant)}));
  const refund = {invoiceId: "pos-test", shiftId: "shift", reason: "Return", cashOut: 5, cardOut: 0,
    items: [{medicineId: "medicine", quantity: 1, sellAsPiece: false}]};
  const result = await command(db, "refundPos", refund, "finance-refund-001");
  await command(db, "refundPos", refund, "finance-refund-001");
  assert.equal(db.read(`${prefix}/medicines/medicine`).quantity, 8);
  assert.equal(db.read(`${prefix}/insurance_companies/company`).creditBalance, 5);
  assert.equal(db.read(`${prefix}/shifts/shift`).cashRefunds, 5);
  assert.equal(db.read(`${prefix}/sales/${result.refundId}`).inventoryDisposition, "quarantined");
  await assert.rejects(command(db, "refundPos", {...refund, cashOut: 10, items: [{medicineId: "medicine", quantity: 2}]}, "finance-refund-002"));
});

test("expense correction normalizes bank methods and retains compensating history", async () => {
  const db = fixture();
  const {expenseId} = await command(db, "createExpense", {title: "Rent", category: "rent", amount: 10, paymentMethod: "شيك"});
  await command(db, "updateExpense", {expenseId, title: "Rent", category: "rent", amount: 12, paymentMethod: "تحويل بنكي"}, "expense-correction-001");
  assert.equal(db.read(`${prefix}/expenses/${expenseId}`).amount, 12);
  const ledger = db.paths(`${prefix}/financial_transactions/`).map((p) => db.read(p));
  assert.equal(ledger.length, 3);
  assert.equal(ledger.reduce((sum, e) => sum + (e.direction === "inflow" ? e.amount : -e.amount), 0), -12);
});

test("NaN, negative money and mismatched purchase quantities are rejected atomically", async () => {
  for (const amount of [NaN, Infinity, -1, 1]) {
    const db = fixture(); const request = purchase(); request.discount = amount;
    const before = [...db.documents]; await assert.rejects(command(db, "receivePurchase", request));
    assert.deepEqual([...db.documents], before);
  }
  const db = fixture(); const request = purchase(); request.stockEntries[0].packageQty = 99;
  await assert.rejects(command(db, "receivePurchase", request));
  assert.equal(db.read(`${prefix}/medicines/medicine`).quantity, 10);
});

test("bulk import rolls back all rows when the final row is invalid", async () => {
  const db = fixture(); const before = [...db.documents];
  await assert.rejects(command(db, "importMedicines", {medicines: [
    {name: "Valid", quantity: 2, purchasePrice: 3}, {name: "Invalid", quantity: -1},
  ]}));
  assert.deepEqual([...db.documents], before);
});

test("shift closure includes supplier cash, expenses and receipts and remains immutable", async () => {
  const db = fixture();
  db.write(`${prefix}/shift_states/owner:pharmacy`, {activeShiftId: null});
  const opened = await command(db, "openShift", {openingCash: 50}, "shift-opening-001");
  assert.deepEqual(await command(db, "openShift", {openingCash: 50}, "shift-opening-001"), opened);
  await assert.rejects(command(db, "openShift", {openingCash: 10}, "shift-opening-002"));
  const request = sale(); request.sale.shiftId = opened.shiftId;
  await command(db, "postSale", request, "shift-sale-001");
  const {invoiceId} = await command(db, "receivePurchase", purchase(), "shift-purchase-001");
  await command(db, "payPurchase", {invoiceId, amount: 4, paymentMethod: "cash", shiftId: opened.shiftId}, "shift-payment-001");
  await command(db, "createExpense", {title: "Expense", amount: 3, paymentMethod: "cash", shiftId: opened.shiftId}, "shift-expense-001");
  await assert.rejects(command(db, "closeShift", {shiftId: opened.shiftId, closingCash: 62}, "shift-close-001"));
  const close = await command(db, "closeShift", {shiftId: opened.shiftId, closingCash: 63}, "shift-close-002");
  assert.equal(close.expectedDrawerCash, 63); assert.equal(close.drawerDiff, 0);
  assert.equal(db.read(`${prefix}/shift_states/owner:pharmacy`).activeShiftId, null);
  const before = [...db.documents];
  await assert.rejects(command(db, "payPurchase", {invoiceId, amount: 1, paymentMethod: "cash", shiftId: opened.shiftId}, "shift-payment-002"));
  assert.deepEqual([...db.documents], before);
});

test("supplier opening is payable and settleable without being a new purchase", async () => {
  const db = fixture();
  const {recordId} = await command(db, "createSupplier", {data: {name: "Opening supplier", openingBalance: 25}}, "supplier-opening-001");
  await command(db, "payPurchase", {invoiceId: `opening-${recordId}`, amount: 10, paymentMethod: "cash"}, "supplier-opening-payment");
  const supplier = db.read(`${prefix}/suppliers/${recordId}`);
  assert.equal(supplier.totalDue, 15); assert.equal(supplier.totalPaid, 10); assert.equal(supplier.totalPurchases, 0);
  await assert.rejects(command(db, "reversePurchase", {invoiceId: `opening-${recordId}`}, "supplier-opening-reversal"));
});

test("insurer credit can settle a later claim without recording new cash", async () => {
  const db = fixture();
  db.write(`${prefix}/insurance_companies/company`, {name: "Insurer", status: "active", discountPercentage: 50,
    currentReceivable: 0, creditBalance: 10, totalCollected: 30});
  const request = sale(); request.sale.insuranceCompanyId = "company";
  request.sale.total = 10; request.sale.insuranceDiscount = 10;
  await command(db, "postSale", request, "credit-sale-001");
  const countBefore = db.paths(`${prefix}/financial_transactions/`).length;
  await db.runTransaction((transaction) => collectInsurancePayment({transaction, db, pharmacyId: "pharmacy",
    actor: {id: "pharmacy"}, payload: {companyId: "company", amount: 0, paymentMethod: "bank"},
    operationKey: "credit-settlement", timestamp: Timestamp.fromMillis(instant)}));
  assert.equal(db.read(`${prefix}/insurance_companies/company`).creditBalance, 0);
  assert.equal(db.read(`${prefix}/insurance_companies/company`).totalCollected, 30);
  assert.equal(db.read(`${prefix}/sales/pos-test`).insuranceCreditAppliedAmount, 10);
  assert.equal(db.paths(`${prefix}/financial_transactions/`).length, countBefore + 1);
});

test("explicit insurer settlement applies only the approved credit amount", async () => {
  const db = fixture();
  db.write(`${prefix}/insurance_companies/company`, {name: "Insurer", status: "active", discountPercentage: 50,
    currentReceivable: 0, creditBalance: 10, totalCollected: 30});
  const request = sale(); request.sale.insuranceCompanyId = "company";
  request.sale.total = 10; request.sale.insuranceDiscount = 10;
  await command(db, "postSale", request, "credit-partial-sale-001");
  const countBefore = db.paths(`${prefix}/financial_transactions/`).length;
  const result = await db.runTransaction((transaction) => collectInsurancePayment({transaction, db,
    pharmacyId: "pharmacy", actor: {id: "pharmacy"},
    payload: {companyId: "company", amount: 0, creditAmount: 4, paymentMethod: "bank"},
    operationKey: "credit-partial-settlement", timestamp: Timestamp.fromMillis(instant)}));
  assert.equal(result.creditApplied, 4);
  assert.equal(result.remainingCreditBalance, 6);
  assert.equal(result.newReceivable, 6);
  assert.equal(db.read(`${prefix}/insurance_companies/company`).creditBalance, 6);
  assert.equal(db.read(`${prefix}/insurance_companies/company`).totalCollected, 30);
  assert.equal(db.read(`${prefix}/sales/pos-test`).insuranceCreditAppliedAmount, 4);
  assert.equal(db.paths(`${prefix}/financial_transactions/`).length, countBefore + 1);
  await assert.rejects(db.runTransaction((transaction) => collectInsurancePayment({transaction, db,
    pharmacyId: "pharmacy", actor: {id: "pharmacy"},
    payload: {companyId: "company", amount: 0, creditAmount: 7, paymentMethod: "bank"},
    operationKey: "credit-excess-settlement", timestamp: Timestamp.fromMillis(instant)})),
  /credit balance/);
});

test("cash collection never consumes return credit unless explicitly approved", async () => {
  const db = fixture();
  db.write(`${prefix}/insurance_companies/company`, {name: "Insurer", status: "active", discountPercentage: 50,
    currentReceivable: 0, creditBalance: 10, totalCollected: 30});
  const request = sale(); request.sale.insuranceCompanyId = "company";
  request.sale.total = 10; request.sale.insuranceDiscount = 10;
  await command(db, "postSale", request, "cash-with-credit-sale-001");
  const result = await db.runTransaction((transaction) => collectInsurancePayment({transaction, db,
    pharmacyId: "pharmacy", actor: {id: "pharmacy"},
    payload: {companyId: "company", amount: 4, creditAmount: 0, paymentMethod: "bank"},
    operationKey: "cash-without-credit", timestamp: Timestamp.fromMillis(instant)}));
  assert.equal(result.amount, 4);
  assert.equal(result.creditApplied, 0);
  assert.equal(result.remainingCreditBalance, 10);
  assert.equal(result.newReceivable, 6);
  assert.equal(db.read(`${prefix}/insurance_companies/company`).creditBalance, 10);
  assert.equal(db.read(`${prefix}/insurance_companies/company`).totalCollected, 34);
});

test("batch correction keeps history and recomputes expiry availability without altering quantities", async () => {
  const db = fixture(); await command(db, "receivePurchase", purchase());
  const batch = db.read(`${prefix}/medicines/medicine/batches/legacy-opening`);
  const expected = Object.fromEntries(["quantity", "pieceQuantity", "reservedQuantity", "reservedPieceQuantity",
    "unitsPerPackage", "purchasePrice", "expiryDate", "updatedAt"].map((field) => [field, batch[field]]));
  expected.isActive = batch.isActive !== false;
  expected.quarantined = batch.quarantined === true;
  await command(db, "updateBatch", {medicineId: "medicine", batchId: "legacy-opening", expected,
    expiryDate: "2020-01-01", reason: "Correct label"}, "batch-correction-001");
  assert.equal(db.read(`${prefix}/medicines/medicine`).quantity, 12);
  assert.equal(db.read(`${prefix}/medicines/medicine`).availableQuantity, 2);
  assert.equal(db.paths(`${prefix}/medicines/medicine/batchCorrections/`).length, 1);
  await assert.rejects(command(db, "updateMedicine", {medicineId: "medicine", medicine: {expiryDate: "2030-01-01"}}, "batch-correction-002"));
});

test("initial purchase payment commits with receipt, batches, supplier debt and drawer once", async () => {
  const db = fixture();
  const payload = {...purchase(), initialPaymentAmount: 4, paymentMethod: "cash", shiftId: "shift"};
  const result = await command(db, "receivePurchase", payload, "initial-payment-purchase");
  assert.deepEqual(await command(db, "receivePurchase", payload, "initial-payment-purchase"), result);
  const ref = `${prefix}/purchase_invoices/${result.invoiceId}`;
  assert.equal(db.read(ref).paid, 4); assert.equal(db.read(ref).remainingAmount, 6);
  assert.equal(db.read(`${prefix}/suppliers/supplier`).currentBalance, 11);
  assert.equal(db.read(`${prefix}/shifts/shift`).supplierPayments, 4);
  assert.equal(db.paths(`${ref}/payments/`).length, 1);
  assert.equal(db.paths(`${prefix}/financial_transactions/`).length, 2);
});

test("invalid initial payment or zero purchase cost leaves every record unchanged", async () => {
  for (const mode of ["overpaid", "closedShift", "zeroCost"]) {
    const db = fixture();
    const payload = {...purchase(), initialPaymentAmount: 4, paymentMethod: "cash", shiftId: "shift"};
    if (mode === "overpaid") payload.initialPaymentAmount = 11;
    if (mode === "closedShift") db.write(`${prefix}/shifts/shift`, {status: "closed"});
    if (mode === "zeroCost") { payload.items[0].price = 0; payload.stockEntries[0].purchasePrice = 0; }
    const before = [...db.documents];
    await assert.rejects(command(db, "receivePurchase", payload));
    assert.deepEqual([...db.documents], before);
  }
});

test("manually entered opening stock is consumed by POS without a purchase invoice", async () => {
  const db = fixture();
  await command(db, "createMedicine", {medicineId: "manual", medicine: {
    name: "Manual stock", quantity: 5, pieceQuantity: 0, purchasePrice: 5, sellingPrice: 10,
    unitsPerPackage: 10, sellByPiece: true, piecePrice: 1, supplierId: "supplier",
    expiryDate: "2028-01-01", isActive: true}}, "manual-create-001");
  const request = sale(2); request.sale.items[0].medicineId = "manual";
  await command(db, "postSale", request, "manual-sale-001");
  await command(db, "postSale", request, "manual-sale-001");
  const stock = db.read(`${prefix}/medicines/manual`);
  assert.equal(stock.quantity, 3); assert.equal(stock.availableQuantity, 3);
  const invoice = db.read(`${prefix}/sales/pos-test`);
  assert.equal(invoice.inventoryPosted, true); assert.equal(invoice.cogsTotal, 10);
  assert.equal(db.read(`${prefix}/medicines/manual/batches/${invoice.batchAllocations[0].batchId}`).quantity, 3);
  assert.equal(db.paths(`${prefix}/purchase_invoices/`).length, 0);
  assert.deepEqual(db.read(`${prefix}/suppliers/supplier`).suppliedMedications, ["manual"]);
});

test("stock entered by a manual adjustment also decreases after a POS sale", async () => {
  const db = fixture();
  db.write(`${prefix}/medicines/medicine`, {...db.read(`${prefix}/medicines/medicine`), quantity: 0});
  await command(db, "adjustStock", {medicineId: "medicine", quantity: 5, pieceQuantity: 0,
    expectedQuantity: 0, expectedPieceQuantity: 0, reason: "Counted stock"}, "manual-adjust-001");
  await command(db, "postSale", sale(2), "manual-adjust-sale");
  assert.equal(db.read(`${prefix}/medicines/medicine`).quantity, 3);
  const before = [...db.documents];
  await assert.rejects(command(db, "adjustStock", {medicineId: "medicine", quantity: 8, pieceQuantity: 0,
    expectedQuantity: 5, expectedPieceQuantity: 0}, "stale-adjust-001"));
  assert.deepEqual([...db.documents], before);
});

test("bulk manual creation keeps every supplier link and rolls back an invalid supplier", async () => {
  const db = fixture();
  await command(db, "importMedicines", {medicines: [
    {id: "manual-a", name: "A", quantity: 1, supplierId: "supplier"},
    {id: "manual-b", name: "B", quantity: 2, supplierId: "supplier"},
  ]}, "bulk-supplier-links");
  assert.equal(db.read(`${prefix}/suppliers/supplier`).suppliedMedications.length, 2);
  const before = [...db.documents];
  await assert.rejects(command(db, "createMedicine", {medicineId: "bad", medicine: {
    name: "Bad supplier", quantity: 2, supplierId: "missing"}}, "bad-supplier-link"));
  assert.deepEqual([...db.documents], before);
});
