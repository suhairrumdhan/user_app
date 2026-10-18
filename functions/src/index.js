const { onCall, HttpsError } = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {scanOrderTimers} = require("./domain/order-timers");
const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");

const admin = require("firebase-admin");
const crypto = require("node:crypto");
const {FieldValue, Timestamp} = require("firebase-admin/firestore");
const {
  ORDER_STATUS,
  parseOrderStatus,
  statusLabel,
} = require("./domain/order-contract");
const { buildOrderCommandHandler } = require("./domain/order-commands");
const {buildEmployeeSessionHandlers} = require("./auth/employee-session");
const {refreshMedicineSearchIndex, refreshPharmacySearchIndex,
  refreshExpiredSearchIndexes, searchProfileChanged} = require("./domain/medicine-search-index");

admin.initializeApp();
const db = admin.firestore();
const skipSyntheticAdminPerfEvent = (id) => process.env.ROSHITA_ADMIN_PERF_TEST === "true" &&
  String(process.env.GCLOUD_PROJECT || "").startsWith("demo-") && String(id || "").startsWith("admperf_");
const {refreshStockAlerts, scanStockAlerts} = require("./domain/stock-alerts");
exports.onMedicineAlertWritten = onDocumentWritten(
  {document: "pharmacies/{pharmacyId}/medicines/{medicineId}", retry: true},
  (event) => refreshStockAlerts({db, ...event.params}),
);
exports.refreshStockExpiryAlerts = onSchedule({schedule: "every 60 minutes", timeZone: "UTC", region: "us-central1",
  timeoutSeconds: 540, retryCount: 3}, () => scanStockAlerts({db}));
const {SOURCES: ADMIN_LIST_SOURCES, refreshRow: refreshAdminListRow,
  buildAdminList} = require("./domain/admin-lists");
const {buildAdminVisibilityCommand} = require("./domain/admin-visibility");
const {buildAdminInsights} = require("./domain/admin-insights");
const {initializeAdminLists} = require("./domain/admin-initialize");
exports.adminInsights = onCall({region: "us-central1", timeoutSeconds: 120, memory: "512MiB"},
  buildAdminInsights({db, auth: admin.auth()}));
exports.adminList = onCall({region: "us-central1"}, buildAdminList({db, auth: admin.auth()}));
exports.adminVisibilityCommand = onCall({region: "us-central1"},
  buildAdminVisibilityCommand({db, auth: admin.auth()}));
// Temporary migration endpoint. It is safe to rerun and becomes a no-op after
// every list marker reaches the current schema version. Delete after migration.
exports.initializeAdminListsOnce = onSchedule({schedule: "every 5 minutes", timeZone: "UTC",
  region: "us-central1", timeoutSeconds: 540, memory: "1GiB"}, async () => {
  console.log("Admin list initialization", await initializeAdminLists({db}));
});
for (const [kind, source] of Object.entries(ADMIN_LIST_SOURCES)) {
  exports[`adminList_${kind}`] = onDocumentWritten(
    {document: `${source}/{id}`, region: "us-central1", retry: true},
    async (event) => skipSyntheticAdminPerfEvent(event.params.id) ? undefined :
      refreshAdminListRow({db, kind, id: event.params.id}),
  );
}
const {buildPharmacyFinanceCommand} = require("./domain/pharmacy-finance");
const {buildPharmacyReport} = require("./domain/pharmacy-reports");
exports.getPharmacyReport = onCall({region: "us-central1", timeoutSeconds: 120, memory: "512MiB"}, async (request) => {
  try { return await buildPharmacyReport({db})(request); } catch (error) {
    const known = ["permission-denied", "failed-precondition", "invalid-argument"].includes(error.code);
    throw new HttpsError(known ? error.code : "internal", known ? error.message : "تعذر إعداد التقرير. أعد المحاولة بعد مراجعة الاتصال.");
  }
});
exports.pharmacyFinanceCommand = onCall({region: "us-central1"}, async (request) => {
  try { return await buildPharmacyFinanceCommand({db})(request); } catch (error) {
    throw new HttpsError(error.code || "internal", error.message || "تعذر حفظ العملية المالية");
  }
});

const {buildRegistrationCommand} = require("./domain/registration-commands");
exports.registrationCommand = onCall({region: "us-central1"}, (request) => buildRegistrationCommand({
  db, auth: admin.auth(), bucket: admin.storage().bucket(),
})(request));

exports.processOrderDeadlines = onSchedule({
  schedule: "every 5 minutes", timeZone: "UTC", region: "us-central1",
  timeoutSeconds: 540, retryCount: 3,
}, async () => {
  console.log("Order deadline scan", await scanOrderTimers({db}));
});

// Current-source projections also create missing index documents.
exports.onMedicineStockWritten = onDocumentWritten(
  {document: "pharmacies/{pharmacyId}/medicines/{medicineId}", retry: true},
  async (event) => refreshMedicineSearchIndex({db, ...event.params}),
);

exports.onPharmacySearchProfileWritten = onDocumentWritten(
  {document: "pharmacies/{pharmacyId}", retry: true},
  async (event) => {
    if (skipSyntheticAdminPerfEvent(event.params.pharmacyId)) return;
    if (!searchProfileChanged(event.data?.before.data(), event.data?.after.data())) return;
    await refreshPharmacySearchIndex({db, pharmacyId: event.params.pharmacyId});
  },
);

exports.refreshMedicineSearchAvailability = onSchedule({
  schedule: "every 15 minutes", timeZone: "UTC", region: "us-central1",
  timeoutSeconds: 540, retryCount: 3,
}, async () => {
  console.log("Expired medicine index scan", await refreshExpiredSearchIndexes({db}));
});

/* =========================================================
   Helpers
========================================================= */

function text(value, fallback = "") {
  if (value === null || value === undefined) return fallback;
  return value.toString().trim();
}

function shortText(value, max = 120) {
  const v = text(value);
  if (v.length <= max) return v;
  return v.substring(0, max) + "...";
}

function now() {
  return FieldValue.serverTimestamp();
}

function getOrderUserId(order) {
  return text(
    order.userId ||
    order.ownerUserId ||
    order.user?.userId ||
    order.user?.id,
  );
}

function getOrderPharmacyId(order) {
  return text(
    order.pharmacyId ||
    order.pharmacy?.pharmacyId ||
    order.pharmacy?.id,
  );
}

function getOrderPharmacyName(order) {
  return text(
    order.pharmacyName ||
    order.pharmacy?.pharmacyName ||
    order.pharmacy?.name,
    "الصيدلية",
  );
}

function getOrderPharmacyImage(order) {
  return text(
    order.pharmacyImageUrl ||
    order.pharmacy?.imageUrl ||
    order.pharmacy?.logoUrl,
  ) || null;
}

function getBeneficiaryName(order) {
  return text(
    order.beneficiaryName ||
    order.beneficiary?.name ||
    order.user?.name,
    "المستخدم",
  );
}

function getBeneficiaryId(order, fallbackUserId) {
  return text(
    order.beneficiaryId ||
    order.beneficiary?.id ||
    fallbackUserId,
  );
}

function getBeneficiaryType(order) {
  return text(
    order.beneficiaryType ||
    order.beneficiary?.type ||
    "self",
  );
}

function getOrderNumber(order, orderId) {
  return text(order.orderNumber, orderId);
}

function orderStatusLabel(status) {
  try {
    return statusLabel(parseOrderStatus(status).status);
  } catch {
    return "حالة غير معروفة";
  }
}

function orderNotificationTitle(status) {
  let canonical;
  try {
    canonical = parseOrderStatus(status).status;
  } catch {
    canonical = null;
  }
  switch (canonical) {
    case ORDER_STATUS.UNDER_REVIEW:
      return "طلبك قيد المراجعة";
    case ORDER_STATUS.CONFIRMED_RESERVED:
      return "تم تأكيد الطلب";
    case ORDER_STATUS.PARTIAL_OFFER_PENDING:
      return "الطلب متوفر جزئيًا";
    case ORDER_STATUS.PREPARING:
      return "بدأ تجهيز الطلب";
    case ORDER_STATUS.REJECTED:
      return "تم رفض الطلب";
    case ORDER_STATUS.READY:
      return "طلبك جاهز";
    case ORDER_STATUS.COMPLETED:
      return "تم إكمال الطلب";
    case ORDER_STATUS.CANCELLED:
      return "تم إلغاء الطلب";
    case ORDER_STATUS.NOT_COLLECTED:
      return "انتهت مهلة الاستلام";
    default:
      return "تحديث على الطلب";
  }
}

const {refreshAdminOrderSummary} = require("./domain/admin-order-summary");
async function writeAdminOrderSummary(orderId) {
  return refreshAdminOrderSummary({db, orderId});
}
exports.adminOrderProjection = onDocumentWritten(
  {document: "orders/{orderId}", region: "us-central1", retry: true},
  async (event) => skipSyntheticAdminPerfEvent(event.params.orderId) ? undefined :
    refreshAdminOrderSummary({db, orderId: event.params.orderId}),
);


function tokensFrom(data = {}) {
  return [...new Set([
    data.fcmToken,
    data.pushToken,
    data.deviceToken,
    ...(Array.isArray(data.fcmTokens) ? data.fcmTokens : []),
  ].map((value) => text(value)).filter(Boolean))];
}

function pushTokenDocId(token) {
  return crypto.createHash("sha256").update(token).digest("hex");
}

async function activeUserPushTokens(userId, userDoc) {
  if (!userDoc.exists) return [];

  const candidates = new Set(tokensFrom(userDoc.data()));
  const tokenDocs = await userDoc.ref.collection("fcmTokens").get();
  tokenDocs.docs.forEach((doc) => {
    const data = doc.data() || {};
    if (data.active !== true) return;
    const token = text(data.token);
    if (token) candidates.add(token);
  });

  const tokens = [...candidates];
  if (tokens.length === 0) return [];

  const ownerRefs = tokens.map((token) => db
    .collection("pushTokenOwners")
    .doc(pushTokenDocId(token)));
  const ownerDocs = await db.getAll(...ownerRefs);

  return tokens.filter((token, index) => {
    const owner = ownerDocs[index].data() || {};
    return owner.active === true &&
      text(owner.userId) === userId &&
      text(owner.token) === token;
  });
}

async function removeInvalidUserPushTokens(userId, tokens) {
  if (tokens.length === 0) return;

  const userRef = db.collection("users").doc(userId);
  const userDoc = await userRef.get();
  const userData = userDoc.data() || {};
  const invalid = new Set(tokens);
  const batch = db.batch();

  tokens.forEach((token) => {
    const tokenId = pushTokenDocId(token);
    batch.delete(db.collection("pushTokenOwners").doc(tokenId));
    batch.delete(userRef.collection("fcmTokens").doc(tokenId));
  });

  if (invalid.has(text(userData.fcmToken))) {
    batch.set(userRef, {
      fcmToken: FieldValue.delete(),
      fcmTokenActive: FieldValue.delete(),
      fcmTokenOwnerUid: FieldValue.delete(),
      lastTokenUpdate: now(),
    }, {merge: true});
  }

  await batch.commit();
}

exports.syncUserPushToken = onCall(
  {region: "us-central1"},
  async (request) => {
    const action = text(request.data?.action);
    const token = text(request.data?.token);

    if (!["register", "unregister"].includes(action) ||
        token.length < 20 || token.length > 4096) {
      throw new HttpsError("invalid-argument", "Invalid push token request.");
    }

    const tokenId = pushTokenDocId(token);
    const ownerRef = db.collection("pushTokenOwners").doc(tokenId);

    if (action === "register") {
      const userId = text(request.auth?.uid);
      if (!userId) {
        throw new HttpsError("unauthenticated", "Sign in is required.");
      }

      const userRef = db.collection("users").doc(userId);
      const previousUserId = await db.runTransaction(async (transaction) => {
        const ownerDoc = await transaction.get(ownerRef);
        const previousOwner = text(ownerDoc.data()?.userId);

        transaction.set(ownerRef, {
          token,
          userId,
          active: true,
          updatedAt: now(),
        });
        transaction.set(userRef, {
          fcmToken: token,
          fcmTokenActive: true,
          fcmTokenOwnerUid: userId,
          lastTokenUpdate: now(),
        }, {merge: true});
        transaction.set(userRef.collection("fcmTokens").doc(tokenId), {
          token,
          userId,
          active: true,
          updatedAt: now(),
        });
        return previousOwner;
      });

      if (previousUserId && previousUserId !== userId) {
        const previousRef = db.collection("users").doc(previousUserId);
        const previousDoc = await previousRef.get();
        const cleanup = db.batch();
        cleanup.delete(previousRef.collection("fcmTokens").doc(tokenId));
        if (text(previousDoc.data()?.fcmToken) === token) {
          cleanup.set(previousRef, {
            fcmToken: FieldValue.delete(),
            fcmTokenActive: FieldValue.delete(),
            fcmTokenOwnerUid: FieldValue.delete(),
            lastTokenUpdate: now(),
          }, {merge: true});
        }
        await cleanup.commit();
      }

      const legacyOwners = await db.collection("users")
        .where("fcmToken", "==", token)
        .get();
      const legacyCleanup = db.batch();
      let hasLegacyCleanup = false;
      legacyOwners.docs.forEach((doc) => {
        if (doc.id === userId) return;
        hasLegacyCleanup = true;
        legacyCleanup.set(doc.ref, {
          fcmToken: FieldValue.delete(),
          fcmTokenActive: FieldValue.delete(),
          fcmTokenOwnerUid: FieldValue.delete(),
          lastTokenUpdate: now(),
        }, {merge: true});
        legacyCleanup.delete(doc.ref.collection("fcmTokens").doc(tokenId));
      });
      if (hasLegacyCleanup) await legacyCleanup.commit();

      return {registered: true};
    }

    await db.runTransaction(async (transaction) => {
      const ownerDoc = await transaction.get(ownerRef);
      if (!ownerDoc.exists || text(ownerDoc.data()?.token) !== token) return;

      const ownerUserId = text(ownerDoc.data()?.userId);
      const ownerUserRef = db.collection("users").doc(ownerUserId);
      const ownerUserDoc = ownerUserId
        ? await transaction.get(ownerUserRef)
        : null;

      transaction.delete(ownerRef);
      if (!ownerUserId) return;

      transaction.delete(ownerUserRef.collection("fcmTokens").doc(tokenId));
      if (text(ownerUserDoc?.data()?.fcmToken) === token) {
        transaction.set(ownerUserRef, {
          fcmToken: FieldValue.delete(),
          fcmTokenActive: FieldValue.delete(),
          fcmTokenOwnerUid: FieldValue.delete(),
          lastTokenUpdate: now(),
        }, {merge: true});
      }
    });

    const legacyOwners = await db.collection("users")
      .where("fcmToken", "==", token)
      .get();
    if (!legacyOwners.empty) {
      const cleanup = db.batch();
      legacyOwners.docs.forEach((doc) => {
        cleanup.set(doc.ref, {
          fcmToken: FieldValue.delete(),
          fcmTokenActive: FieldValue.delete(),
          fcmTokenOwnerUid: FieldValue.delete(),
          lastTokenUpdate: now(),
        }, {merge: true});
        cleanup.delete(doc.ref.collection("fcmTokens").doc(tokenId));
      });
      await cleanup.commit();
    }

    return {unregistered: true};
  },
);

async function sendMulticastInChunks(tokens, message) {
  let successCount = 0;
  let failureCount = 0;

  for (let i = 0; i < tokens.length; i += 500) {
    const response = await admin.messaging().sendEachForMulticast({
      ...message,
      tokens: tokens.slice(i, i + 500),
    });
    successCount += response.successCount;
    failureCount += response.failureCount;
  }

  return { successCount, failureCount };
}

/* =========================================================
   1) Canonical Order Command
========================================================= */

exports.executeOrderCommand = buildOrderCommandHandler({
  db,
  onCall,
  HttpsError,
});

const employeeAuth = buildEmployeeSessionHandlers({
  db, auth: admin.auth(), onCall, HttpsError,
});
exports.loginEmployee = employeeAuth.loginEmployee;
exports.managePharmacyEmployeeAccount = employeeAuth.manageAccount;
exports.migrateLegacyEmployeeCredential = employeeAuth.migrateLegacyCredential;
// Compatibility names for a staged desktop/client rollout.
exports.managePharmacyEmployeeCredential = employeeAuth.manageCredential;
exports.createPharmacyEmployeeSession = employeeAuth.loginEmployee;
exports.revokePharmacyEmployeeSession = employeeAuth.revokeSession;

/* =========================================================
   3) Push Notification for User
   Trigger: users/{userId}/notifications/{notificationId}
========================================================= */

exports.onNotificationCreated = onDocumentCreated(
  {document: "users/{userId}/notifications/{notificationId}", retry: true},
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const notification = snapshot.data() || {};
    const userId = event.params.userId;

    if (notification.pushHandledBy === "sendAdminBroadcast") {
      console.log("Broadcast push already handled:", event.params.notificationId);
      return;
    }

    const notificationRef = snapshot.ref;
    const deliveryId = text(event.id, event.params.notificationId);
    const claimedAt = Timestamp.now();
    const claimed = await db.runTransaction(async (transaction) => {
      const current = await transaction.get(notificationRef);
      if (!current.exists) return false;
      const delivery = current.data()?.pushDelivery || {};
      if (["sent", "skipped"].includes(text(delivery.state))) return false;
      const previousClaim = delivery.claimedAt?.toMillis?.() || 0;
      if (text(delivery.state) === "sending" &&
          claimedAt.toMillis() - previousClaim < 5 * 60 * 1000) {
        return false;
      }
      transaction.update(notificationRef, {
        pushDelivery: {
          state: "sending",
          deliveryId,
          claimedAt,
          attempt: Number(delivery.attempt || 0) + 1,
        },
      });
      return true;
    });
    if (!claimed) {
      console.log("Push already claimed or delivered:", event.params.notificationId);
      return;
    }

    try {
      const userDoc = await db.collection("users").doc(userId).get();
      const tokens = await activeUserPushTokens(userId, userDoc);

      if (tokens.length === 0) {
        await notificationRef.update({
          pushDelivery: {
            state: "skipped",
            deliveryId,
            reason: "no-token",
            finishedAt: Timestamp.now(),
          },
        });
        console.log("No FCM token for user:", userId);
        return;
      }

      const title = text(notification.title, "إشعار جديد");
      const body = text(notification.message || notification.body, "");

      const payload = {
        notification: {
          title,
          body,
        },
        data: {
          type: text(notification.type, "general"),
          orderId: text(notification.orderId),
          chatId: text(notification.chatId),
          referenceId: text(notification.referenceId),
          referenceType: text(notification.referenceType),
          actionRoute: text(notification.actionRoute),
          actionId: text(notification.actionId),
          pharmacyId: text(notification.pharmacyId),
          userId,
        },
        android: {
          priority: "high",
          collapseKey: `notification-${event.params.notificationId}`,
          notification: {
            sound: "default",
            tag: `notification-${event.params.notificationId}`,
          },
        },
        tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(payload);

      console.log(
        `✅ Push sent for user ${userId}. Success: ${response.successCount}, Failed: ${response.failureCount}`,
      );

      const invalidTokens = [];

      response.responses.forEach((res, index) => {
        if (!res.success) {
          const code = res.error && res.error.code;

          if (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
          ) {
            invalidTokens.push(tokens[index]);
          }

          console.log("FCM error:", code);
        }
      });

      if (invalidTokens.length > 0) {
        await removeInvalidUserPushTokens(userId, invalidTokens);
        console.log("Deleted invalid tokens:", invalidTokens.length);
      }
      await notificationRef.update({
        pushDelivery: {
          state: "sent",
          deliveryId,
          successCount: response.successCount,
          failureCount: response.failureCount,
          finishedAt: Timestamp.now(),
        },
      });
    } catch (error) {
      console.error("❌ Push failed:", error);
      try {
        await notificationRef.update({
          pushDelivery: {
            state: "failed",
            deliveryId,
            errorCode: text(error?.code, "unknown").slice(0, 100),
            failedAt: Timestamp.now(),
          },
        });
      } catch (stateError) {
        console.error("Failed to record push delivery state:", stateError);
      }
      throw error;
    }
  },
);

/* =========================================================
   4) Chat Notifications
   pharmacy -> user notification + push
   user -> pharmacy internal notification
========================================================= */

exports.onChatMessageCreated = onDocumentCreated(
  {document: "chats/{chatId}/messages/{messageId}", retry: true},
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const messageData = snap.data() || {};
    const chatId = event.params.chatId;
    const messageId = event.params.messageId;

    const senderType = text(messageData.senderType);
    const messageText = text(messageData.text);

    if (!messageText) {
      console.log("Skipped empty message:", messageId);
      return;
    }

    const chatDoc = await db.collection("chats").doc(chatId).get();

    if (!chatDoc.exists) {
      console.log("Chat not found:", chatId);
      return;
    }

    const chatData = chatDoc.data() || {};

    const userId = text(chatData.userId);
    const pharmacyId = text(chatData.pharmacyId);
    const pharmacyName = text(
      chatData.pharmacyName || messageData.senderName,
      "الصيدلية",
    );
    const pharmacyImageUrl = text(
      chatData.pharmacyImageUrl ||
      chatData.imageUrl ||
      messageData.senderImageUrl,
    );
    const userName = text(chatData.userName, "المستخدم");
    const orderId = text(chatData.orderId);

    if (senderType === "pharmacy") {
      if (!userId) {
        console.log("Missing userId in chat:", chatId);
        return;
      }

      await db
        .collection("users")
        .doc(userId)
        .collection("notifications")
        .doc(`chat_${messageId}`)
        .set({
          userId,
          type: "pharmacyMessage",
          title: `رسالة جديدة من ${pharmacyName}`,
          message: shortText(messageText),
          body: shortText(messageText),

          referenceType: "chat",
          referenceId: chatId,
          actionRoute: "/chats",
          actionId: chatId,

          chatId,
          orderId: orderId || null,
          pharmacyId,
          pharmacyName,
          prescriptionId: null,

          beneficiaryId: null,
          beneficiaryName: null,
          beneficiaryType: null,

          iconName: "chat_message",
          imageUrl: pharmacyImageUrl || null,

          isActionable: true,
          isDeleted: false,
          isRead: false,
          priority: "high",

          createdAt: now(),
          readAt: null,
          expiresAt: null,

          extraData: {
            source: "chat",
            senderType,
            messageId,
          },
        }, { merge: true });

      console.log("✅ User chat notification created:", userId);
      return;
    }

    if (senderType === "user") {
      if (!pharmacyId) {
        console.log("Missing pharmacyId in chat:", chatId);
        return;
      }

      await db
        .collection("pharmacies")
        .doc(pharmacyId)
        .collection("notifications")
        .doc(`chat_${messageId}`)
        .set({
          pharmacyId,
          type: "chatMessage",
          title: `رسالة جديدة من ${userName}`,
          message: shortText(messageText),
          body: shortText(messageText),

          referenceType: "chat",
          referenceId: chatId,
          actionRoute: "/chat",
          actionId: chatId,

          chatId,
          orderId: orderId || null,
          userId,
          userName,

          iconName: "chat_message",
          imageUrl: null,

          isActionable: true,
          isDeleted: false,
          isRead: false,
          priority: "high",

          createdAt: now(),
          readAt: null,
          expiresAt: null,

          extraData: {
            source: "chat",
            senderType,
            messageId,
          },
        }, { merge: true });

      console.log("✅ Pharmacy chat notification created:", pharmacyId);
    }
  },
);

/* =========================================================
   5) New Order -> Pharmacy Internal Notification
   Trigger: orders/{orderId} created
========================================================= */

exports.onOrderCreated = onDocumentCreated(
  {document: "orders/{orderId}", retry: true},
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const order = snap.data() || {};
    const orderId = event.params.orderId;

    await writeAdminOrderSummary(orderId, order);

    let canonicalStatus;
    try {
      canonicalStatus = parseOrderStatus(order.status).status;
    } catch (error) {
      console.error("Unknown order status on create:", orderId, error.message);
      return;
    }
    if (canonicalStatus !== ORDER_STATUS.UNDER_REVIEW) {
      console.log("Order is not visible to pharmacy yet:", orderId, canonicalStatus);
      return;
    }

    const pharmacyId = getOrderPharmacyId(order);

    if (!pharmacyId) {
      console.log("Missing pharmacyId in order:", orderId);
      return;
    }

    const userId = getOrderUserId(order);
    const beneficiaryName = getBeneficiaryName(order);
    const orderNumber = getOrderNumber(order, orderId);

    const message = `وصل طلب جديد رقم ${orderNumber} باسم ${beneficiaryName}.`;

    await db
      .collection("pharmacies")
      .doc(pharmacyId)
      .collection("notifications")
      .doc(`new_order_${orderId}`)
      .set({
        pharmacyId,
        type: "newOrder",
        title: "طلب جديد",
        message,
        body: message,

        referenceType: "order",
        referenceId: orderId,
        actionRoute: "/orders",
        actionId: orderId,

        orderId,
        chatId: text(order.chatId) || null,
        userId,
        userName: beneficiaryName,

        iconName: "new_order",
        imageUrl: null,

        isActionable: true,
        isDeleted: false,
        isRead: false,
        priority: "high",

        createdAt: now(),
        readAt: null,
        expiresAt: null,

        extraData: {
          source: "order",
          orderNumber,
          status: canonicalStatus,
          statusLabel: text(order.statusLabel, statusLabel(canonicalStatus)),
        },
      }, { merge: true });

    console.log("✅ Pharmacy new order notification created:", pharmacyId);
  },
);

/* =========================================================
   6) Order Status Update -> User Notification + Push
   Trigger: orders/{orderId} updated
========================================================= */

exports.onOrderUpdated = onDocumentUpdated(
  {document: "orders/{orderId}", retry: true},
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    const orderId = event.params.orderId;

    const oldStatus = text(before.status);
    const newStatus = text(after.status);

    await writeAdminOrderSummary(orderId, after);

    const offerRevised = Number(after.offerVersion || 0) !== Number(before.offerVersion || 0);
    if (!newStatus || (oldStatus === newStatus && !offerRevised)) {
      return;
    }

    let canonicalNewStatus;
    try {
      canonicalNewStatus = parseOrderStatus(newStatus).status;
    } catch (error) {
      console.error("Unknown order status on update:", orderId, error.message);
      return;
    }

    if (canonicalNewStatus === ORDER_STATUS.UNDER_REVIEW) {
      const pharmacyId = getOrderPharmacyId(after);
      if (pharmacyId) {
        const orderNumber = getOrderNumber(after, orderId);
        const beneficiaryName = getBeneficiaryName(after);
        const message = `وصل طلب جديد رقم ${orderNumber} باسم ${beneficiaryName}.`;
        await db.collection("pharmacies").doc(pharmacyId)
          .collection("notifications").doc(`new_order_${orderId}`).set({
            pharmacyId,
            type: "newOrder",
            title: "طلب جديد",
            message,
            body: message,
            referenceType: "order",
            referenceId: orderId,
            actionRoute: "/orders",
            actionId: orderId,
            orderId,
            userId: getOrderUserId(after),
            userName: beneficiaryName,
            isActionable: true,
            isDeleted: false,
            isRead: false,
            priority: "high",
            createdAt: now(),
            extraData: {
              source: "order",
              orderNumber,
              status: canonicalNewStatus,
              statusLabel: statusLabel(canonicalNewStatus),
            },
          }, {merge: true});
      }
    }

    const userId = getOrderUserId(after);

    if (!userId) {
      console.log("Missing userId in order:", orderId);
      return;
    }

    const pharmacyId = getOrderPharmacyId(after);
    const pharmacyName = getOrderPharmacyName(after);
    const pharmacyImageUrl = getOrderPharmacyImage(after);

    const beneficiaryId = getBeneficiaryId(after, userId);
    const beneficiaryName = getBeneficiaryName(after);
    const beneficiaryType = getBeneficiaryType(after);

    const currentStatusLabel = text(after.statusLabel, orderStatusLabel(newStatus));
    const replacementPending = canonicalNewStatus === ORDER_STATUS.PARTIAL_OFFER_PENDING &&
      after.partialOffer?.kind === "replacement";
    const fullPending = canonicalNewStatus === ORDER_STATUS.PARTIAL_OFFER_PENDING && after.partialOffer?.kind === "full";
    const title = replacementPending ? "عرض تبديل الأصناف" : fullPending ? "عرض سعر الطلب الكامل" : orderNotificationTitle(newStatus);
    const message = replacementPending ?
      `أرسلت ${pharmacyName} عرض تبديل أصناف لطلب ${beneficiaryName}. راجع الأصناف والسعر قبل الموافقة.` :
      fullPending ? `أرسلت ${pharmacyName} سعر الطلب الكامل. راجع المبلغ والأصناف قبل الموافقة والحجز.` :
      `${currentStatusLabel} طلب ${beneficiaryName} من ${pharmacyName}.`;

    const historyLength = Array.isArray(after.statusHistory)
      ? after.statusHistory.length
      : Date.now();

    if (["replacement", "full"].includes(before.partialOffer?.kind) &&
        oldStatus === ORDER_STATUS.PARTIAL_OFFER_PENDING && pharmacyId &&
        [ORDER_STATUS.CONFIRMED_RESERVED, ORDER_STATUS.CANCELLED].includes(canonicalNewStatus)) {
      const accepted = canonicalNewStatus === ORDER_STATUS.CONFIRMED_RESERVED;
      const full = before.partialOffer?.kind === "full";
      const decisionMessage = accepted ? (full ? "وافق المستخدم على سعر الطلب الكامل. الأصناف محجوزة." :
        "وافق المستخدم على عرض تبديل الأصناف. الأصناف الجديدة محجوزة.") : "أُلغي الطلب أثناء انتظار قرار العرض.";
      await db.collection("pharmacies").doc(pharmacyId).collection("notifications")
        .doc(`${full ? "full_price" : "replacement"}_decision_${orderId}_${historyLength}`).set({
          pharmacyId, userId, orderId, type: "orderUpdate", referenceType: "order",
          referenceId: orderId, actionRoute: "/orders", actionId: orderId,
          title: accepted ? (full ? "تم قبول سعر الطلب الكامل" : "تم قبول عرض التبديل") : "تم إلغاء الطلب",
          message: decisionMessage, body: decisionMessage, isActionable: true,
          isRead: false, isDeleted: false, priority: "high", createdAt: now(),
          extraData: {source: "order", status: canonicalNewStatus, offerVersion: after.offerVersion},
        }, {merge: true});
    }

    await db
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .doc(`order_${orderId}_${newStatus}_${historyLength}`)
      .set({
        userId,
        type: "orderUpdate",
        title,
        message,
        body: message,

        referenceType: "order",
        referenceId: orderId,
        actionRoute: "/orders",
        actionId: orderId,

        orderId,
        chatId: text(after.chatId) || null,
        pharmacyId,
        pharmacyName,
        prescriptionId: text(after.prescriptionId) || null,

        beneficiaryId,
        beneficiaryName,
        beneficiaryType,

        iconName: `order_${newStatus}`,
        imageUrl: pharmacyImageUrl,

        isActionable: true,
        isDeleted: false,
        isRead: false,
        priority: "high",

        createdAt: now(),
        readAt: null,
        expiresAt: null,

        extraData: {
          source: "order",
          orderStatus: newStatus,
          orderStatusLabel: currentStatusLabel,
          status: newStatus,
          statusLabel: currentStatusLabel,
          beneficiaryRelationLabel: text(
            after.beneficiaryRelationLabel ||
            after.relationLabel ||
            after.beneficiary?.relationLabel,
          ),
          deliveredMedicines: after.deliveredMedicines || [],
        },
      }, { merge: true });

    console.log("✅ User order update notification created:", userId, newStatus);
  },
);

/* =========================================================
   7) Admin Broadcast
   Trigger: adminBroadcastNotifications/{broadcastId} created
========================================================= */

const {buildAdminBroadcast} = require("./domain/admin-broadcast");
const adminBroadcast = buildAdminBroadcast({db, auth: admin.auth(),
  sendUser: async ({userId, broadcastId, noticeId, title, body}) => {
    const user = await db.doc(`users/${userId}`).get();
    const tokens = await activeUserPushTokens(userId, user);
    if (!tokens.length) return {success: false, reason: "no_active_device"};
    const result = await sendMulticastInChunks(tokens, {
      notification: {title, body},
      data: {type: "adminMessage", broadcastId, notificationId: noticeId, eventId: noticeId,
        referenceType: "system", referenceId: broadcastId, userId},
      android: {priority: "high", collapseKey: broadcastId, notification: {tag: noticeId, sound: "default"}},
      apns: {headers: {"apns-collapse-id": broadcastId}},
    });
    return {success: result.successCount > 0, reason: result.successCount ? null : "push_rejected"};
  },
});
exports.adminBroadcastCommand = onCall({region: "us-central1"}, adminBroadcast.command);
exports.sendAdminBroadcast = onDocumentCreated(
  {document: "adminBroadcastNotifications/{broadcastId}", region: "us-central1", retry: true, timeoutSeconds: 540},
  async (event) => adminBroadcast.process(event.params.broadcastId),
);
exports.retryAdminBroadcast = onDocumentCreated(
  {document: "adminBroadcastJobs/{jobId}", region: "us-central1", retry: true, timeoutSeconds: 540},
  async (event) => adminBroadcast.process(event.data.data().broadcastId),
);
exports.recoverAdminBroadcasts = onSchedule({schedule: "every 1 minutes", timeZone: "UTC", region: "us-central1", timeoutSeconds: 540},
  async () => adminBroadcast.recover());
