"use strict";

const {OrderContractError} = require("./order-contract");

async function validateOrderShift({transaction, db, pharmacyId, actor, shiftId}) {
  const key = `${actor.employeeId ? "employee" : "owner"}:${actor.id}`;
  const pharmacy = db.collection("pharmacies").doc(pharmacyId);
  const ref = pharmacy.collection("shifts").doc(shiftId);
  const snapshot = await transaction.get(ref);
  const state = await transaction.get(pharmacy.collection("shift_states").doc(key));
  const shift = snapshot.data();
  if (!shift || shift.status !== "open" || shift.isFinanciallyClosed === true ||
      shift.pharmacyId !== pharmacyId || shift.openedByKey !== key || state.data()?.activeShiftId !== shiftId) {
    throw new OrderContractError("failed-precondition", "الوردية مغلقة أو لا تخص منفذ العملية");
  }
  return {ref, snapshot};
}

module.exports = {validateOrderShift};
