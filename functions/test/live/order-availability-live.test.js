"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {setTimeout: delay} = require("node:timers/promises");
const {initializeLiveSuite, readDocument, testOrder, writeEvidence} = require("./helpers/live-firebase");
const {INDEX_VERSION} = require("../../src/domain/medicine-search-index");

// This suite calls deployed functions. Admin writes only prepare its unique fixtures;
// it never invokes the local projection as a substitute for a deployed trigger.
async function waitForIndex(context, medicineId, predicate, label) {
  const ref = context.db.doc(`medicine_search_index/${context.pharmacyUid}_${medicineId}`);
  const deadline = Date.now() + 90000;
  do {
    const snapshot = await ref.get();
    if (snapshot.exists && predicate(snapshot.data())) return snapshot.data();
    await delay(1500);
  } while (Date.now() < deadline);
  assert.fail(`Deployed search projection did not reach: ${label}`);
}

test("F03 live search projection and new versus existing order eligibility", {
  timeout: 600000,
}, async (t) => {
  const context = await initializeLiveSuite("f03-live-availability", {isolatedIdentities: true});
  const root = `pharmacies/${context.pharmacyUid}`;
  const pharmacyRef = context.db.doc(root);
  const future = context.admin.firestore.Timestamp.fromDate(new Date("2099-01-01T00:00:00Z"));
  const scenarios = [];
  try {
    await pharmacyRef.set({pharmacyId: context.pharmacyUid, status: "approved",
      isActive: true, isBlocked: false, isOnline: true, pharmacyName: "Live availability fixture",
      liveTest: {suite: context.suiteName, runId: context.runId}});
    await context.db.doc(`users/${context.userUid}`).set({userId: context.userUid,
      name: "Live availability user", isActive: true});
    await writeEvidence(context, "running", {pharmacyId: context.pharmacyUid});

    await t.test("a stock event creates a missing index and malformed expiry removes availability", async () => {
      const medicineId = `projection-${context.runId}`;
      const ref = context.db.doc(`${root}/medicines/${medicineId}`);
      await ref.set({name: "Live projection medicine", quantity: 3, reservedQuantity: 1,
        pieceQuantity: 0, reservedPieceQuantity: 0, unitsPerPackage: 10,
        sellByPiece: true, sellingPrice: 20, expiryDate: future, isActive: true});
      const index = await waitForIndex(context, medicineId,
        (data) => data.indexVersion === INDEX_VERSION && data.available === true &&
          data.availableQuantity === 2,
        "missing index created from stock");
      assert.equal(index.availablePieceQuantity, 20);
      assert.equal(index.piecePrice, 2);
      await ref.update({expiryDate: "invalid-test-expiry"});
      await waitForIndex(context, medicineId,
        (data) => data.invalidExpiry === true && data.available === false,
        "invalid expiry is unavailable");
      await ref.update({expiryDate: future});
      await waitForIndex(context, medicineId,
        (data) => data.invalidExpiry === false && data.available === true,
        "source repair refreshes the index");
      scenarios.push("source projection and malformed expiry");
    });

    for (const mode of ["stopped", "hidden"]) {
      await t.test(`${mode} pharmacy rejects new requests but completes its existing order once`, async () => {
        await pharmacyRef.update({isBlocked: false, isOnline: true});
        const medicineId = `${mode}-${context.runId}`;
        const shiftId = `shift-${mode}-${context.runId}`;
        const stockRef = context.db.doc(`${root}/medicines/${medicineId}`);
        await stockRef.set({name: "Live order availability", quantity: 3,
          reservedQuantity: 0, pieceQuantity: 0, reservedPieceQuantity: 0,
          unitsPerPackage: 10, sellingPrice: 10, isActive: true, expiryDate: future});
        const ownerKey = `owner:${context.pharmacyUid}`;
        await context.db.doc(`${root}/shifts/${shiftId}`).set({status: "open",
          pharmacyId: context.pharmacyUid, openedByKey: ownerKey,
          cashTotal: 0, cardTotal: 0, salesCount: 0});
        await context.db.doc(`${root}/shift_states/${ownerKey}`).set({
          activeShiftId: shiftId,
        });
        const order = testOrder(context, "new", [
          {matchedMedicineId: medicineId, quantity: 1, soldByPiece: false},
          {matchedMedicineId: medicineId, quantity: 1, soldByPiece: false},
        ], {insurance: {enabled: false}});
        const createOptions = {payload: {order}, operationId: `${context.runId}:create:${mode}`};
        const created = await context.call("user", "createOrder", null, createOptions);
        const orderId = created.result.orderId;
        const saved = await readDocument(context, `orders/${orderId}`);
        assert.equal(saved.medicines.length, 1);
        assert.equal(saved.medicines[0].quantity, 2);
        assert.equal((await stockRef.get()).data().reservedQuantity, 0);
        await pharmacyRef.update(mode === "hidden" ? {isBlocked: true} : {isOnline: false});
        const visible = mode === "stopped";
        await waitForIndex(context, medicineId,
          (data) => data.indexVersion === INDEX_VERSION && data.pharmacyVisible === visible &&
            data.pharmacyAcceptingOrders === false && data.available === visible,
          `${mode} pharmacy projection`);
        await assert.rejects(context.call("user", "createOrder", null, {
          payload: {order}, operationId: `${context.runId}:rejected-new:${mode}`,
        }), {code: "failed-precondition"});
        assert.deepEqual(await context.call("user", "createOrder", null, createOptions), created);

        await context.call("pharmacy", "confirmFullOrder", orderId);
        assert.equal((await stockRef.get()).data().reservedQuantity, 2);
        await waitForIndex(context, medicineId, (data) => data.availableQuantity === 1,
          "reservation reflected without pharmacy application");
        const invoiceId = `invoice-${mode}-${context.runId}`;
        await context.call("pharmacy", "startPreparing", orderId, {payload: {invoiceId, invoice: {
          invoiceNumber: invoiceId, shiftId, subtotal: 20, discount: 0,
          insuranceDiscount: 0, total: 20, paymentMethod: "cash",
          items: [{medicineId, name: "Live order availability", quantity: 2,
            sellAsPiece: false, unitPrice: 10, unitCost: 4}],
        }}});
        await context.call("pharmacy", "markReady", orderId);
        const deliver = {payload: {collectionShiftId: shiftId},
          operationId: `${context.runId}:deliver:${mode}`};
        const first = await context.call("pharmacy", "completeOrder", orderId, deliver);
        assert.deepEqual(await context.call("pharmacy", "completeOrder", orderId, deliver), first);
        assert.equal((await readDocument(context, `orders/${orderId}`)).status, "completed");
        const stock = (await stockRef.get()).data();
        assert.equal(stock.quantity, 1);
        assert.equal(stock.reservedQuantity, 0);
        const shift = await readDocument(context, `${root}/shifts/${shiftId}`);
        assert.equal(shift.salesCount, 1);
        assert.equal(shift.cashTotal, 20);
        scenarios.push(`${mode} existing order delivered and replayed`);
      });
    }
    // A failed Node subtest does not necessarily throw into this parent callback.
    assert.equal(scenarios.length, 3, "Some live scenarios failed; do not record a passing run");
    await writeEvidence(context, "passed", {scenarios,
      limits: "Does not prove employee-session authorization, security rules, scheduler timing or native UI."});
  } catch (error) {
    await writeEvidence(context, "failed", {scenarios, error: String(error)});
    throw error;
  } finally {
    // Keep clearly identified fixtures and evidence, without changing another suite's identities.
    await context.app.delete();
  }
});
