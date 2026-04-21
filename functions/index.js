const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Returns a date key in YYMMDD format.
 * @return {string}
 */
function getDateKey() {
  const now = new Date();
  const year = now.getFullYear().toString().slice(-2);
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");

  return `${year}${month}${day}`;
}

exports.reserveOrderNumber = functions.https.onCall(async (data, context) => {
  try {
    console.log("reserveOrderNumber called");
    console.log("pharmacyId:", data && data.pharmacyId);
    console.log("userId:", data && data.userId);

    const payload = data && data.data ? data.data : data;

    const pharmacyId = payload && payload.pharmacyId;
    const userId = payload && payload.userId;

    if (!pharmacyId || !userId) {
      throw new functions.https.HttpsError(
          "invalid-argument",
          "Missing required data",
      );
    }

    const dateKey = getDateKey();

    const counterRef = db
        .collection("pharmacies")
        .doc(pharmacyId)
        .collection("order_counters")
        .doc(dateKey);

    let newSequence = 1000;

    await db.runTransaction(async (tx) => {
      const counterSnap = await tx.get(counterRef);

      if (!counterSnap.exists) {
        newSequence = 1000;

        tx.set(counterRef, {
          lastSequence: newSequence,
          dateKey: dateKey,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        const last = counterSnap.data().lastSequence || 1000;
        newSequence = last + 1;

        tx.update(counterRef, {
          lastSequence: newSequence,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });

    const orderNumber = `${dateKey}-${newSequence}`;

    return {
      success: true,
      orderNumber: orderNumber,
      orderDateKey: dateKey,
      dailySequence: newSequence,
    };
  } catch (error) {
    console.error("reserveOrderNumber failed:", error);

    let errorMessage = "Failed to reserve order number";
    if (error && error.message) {
      errorMessage = error.message;
    }

    throw new functions.https.HttpsError(
        "internal",
        errorMessage,
    );
  }
});
