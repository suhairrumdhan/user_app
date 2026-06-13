const { onCall, HttpsError } = require("firebase-functions/v2/https");
const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");

const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

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
  return admin.firestore.FieldValue.serverTimestamp();
}

function getDateKey() {
  const nowDate = new Date();
  const year = nowDate.getFullYear().toString().slice(-2);
  const month = String(nowDate.getMonth() + 1).padStart(2, "0");
  const day = String(nowDate.getDate()).padStart(2, "0");

  return `${year}${month}${day}`;
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
  switch (status) {
    case "pending":
      return "معلقة";
    case "reviewing":
      return "قيد المراجعة";
    case "confirmed":
      return "تم التأكيد";
    case "partiallyConfirmed":
      return "متوفر جزئيًا";
    case "rejected":
      return "مرفوض";
    case "ready":
      return "جاهز";
    case "completed":
      return "مكتمل";
    case "cancelled":
      return "ملغي";
    default:
      return "تحديث جديد";
  }
}

function orderNotificationTitle(status) {
  switch (status) {
    case "reviewing":
      return "طلبك قيد المراجعة";
    case "confirmed":
      return "تم تأكيد الطلب";
    case "partiallyConfirmed":
      return "الطلب متوفر جزئيًا";
    case "rejected":
      return "تم رفض الطلب";
    case "ready":
      return "طلبك جاهز";
    case "completed":
      return "تم إكمال الطلب";
    case "cancelled":
      return "تم إلغاء الطلب";
    default:
      return "تحديث على الطلب";
  }
}

async function commitInChunks(operations, chunkSize = 450) {
  for (let i = 0; i < operations.length; i += chunkSize) {
    const batch = db.batch();
    const chunk = operations.slice(i, i + chunkSize);

    chunk.forEach((op) => {
      batch.set(op.ref, op.data, { merge: true });
    });

    await batch.commit();
  }
}

/* =========================================================
   1) Reserve Order Number
   Used by Flutter: httpsCallable("reserveOrderNumber")
========================================================= */

exports.reserveOrderNumber = onCall(async (request) => {
  try {
    const payload = request.data || {};

    const pharmacyId = text(payload.pharmacyId);
    const userId = text(payload.userId);

    if (!pharmacyId || !userId) {
      throw new HttpsError(
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
          dateKey,
          updatedAt: now(),
        });
      } else {
        const last = counterSnap.data().lastSequence || 1000;
        newSequence = last + 1;

        tx.update(counterRef, {
          lastSequence: newSequence,
          updatedAt: now(),
        });
      }
    });

    const orderNumber = `${dateKey}-${newSequence}`;

    return {
      success: true,
      orderNumber,
      orderDateKey: dateKey,
      dailySequence: newSequence,
    };
  } catch (error) {
    console.error("reserveOrderNumber failed:", error);

    if (error instanceof HttpsError) {
      throw error;
    }

    throw new HttpsError(
      "internal",
      error.message || "Failed to reserve order number",
    );
  }
});

/* =========================================================
   2) Push Notification for User
   Trigger: users/{userId}/notifications/{notificationId}
========================================================= */

exports.onNotificationCreated = onDocumentCreated(
  "users/{userId}/notifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const notification = snapshot.data() || {};
    const userId = event.params.userId;

    try {
      const userDoc = await db.collection("users").doc(userId).get();
      const userData = userDoc.data() || {};

      const singleToken = text(userData.fcmToken);

      const tokens = [];

      if (singleToken) {
        tokens.push(singleToken);
      }

      const tokensSnap = await db
        .collection("users")
        .doc(userId)
        .collection("fcmTokens")
        .get();

      tokensSnap.docs.forEach((doc) => {
        const token = text(doc.data().token || doc.id);
        if (token && !tokens.includes(token)) {
          tokens.push(token);
        }
      });

      if (tokens.length === 0) {
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
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
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
        const batch = db.batch();

        invalidTokens.forEach((token) => {
          const ref = db
            .collection("users")
            .doc(userId)
            .collection("fcmTokens")
            .doc(token);

          batch.delete(ref);
        });

        await batch.commit();
        console.log("Deleted invalid tokens:", invalidTokens.length);
      }
    } catch (error) {
      console.error("❌ Push failed:", error);
    }
  },
);

/* =========================================================
   3) Chat Notifications
   pharmacy -> user notification + push
   user -> pharmacy internal notification
========================================================= */

exports.onChatMessageCreated = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
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
   4) New Order -> Pharmacy Internal Notification
   Trigger: orders/{orderId} created
========================================================= */

exports.onOrderCreated = onDocumentCreated(
  "orders/{orderId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const order = snap.data() || {};
    const orderId = event.params.orderId;

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
          status: text(order.status, "pending"),
          statusLabel: text(order.statusLabel, "معلقة"),
        },
      }, { merge: true });

    console.log("✅ Pharmacy new order notification created:", pharmacyId);
  },
);

/* =========================================================
   5) Order Status Update -> User Notification + Push
   Trigger: orders/{orderId} updated
========================================================= */

exports.onOrderUpdated = onDocumentUpdated(
  "orders/{orderId}",
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    const orderId = event.params.orderId;

    const oldStatus = text(before.status);
    const newStatus = text(after.status);

    if (!newStatus || oldStatus === newStatus) {
      return;
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

    const statusLabel = text(after.statusLabel, orderStatusLabel(newStatus));
    const title = orderNotificationTitle(newStatus);
    const message = `${statusLabel} طلب ${beneficiaryName} من ${pharmacyName}.`;

    const historyLength = Array.isArray(after.statusHistory)
      ? after.statusHistory.length
      : Date.now();

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
          orderStatusLabel: statusLabel,
          status: newStatus,
          statusLabel,
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
   6) Admin Broadcast
   Trigger: adminBroadcastNotifications/{broadcastId} created
========================================================= */

exports.onAdminBroadcastCreated = onDocumentCreated(
  "adminBroadcastNotifications/{broadcastId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const broadcast = snap.data() || {};
    const broadcastId = event.params.broadcastId;

    const title = text(broadcast.title, "رسالة من الإدارة");
    const message = text(broadcast.body || broadcast.message);
    const target = text(broadcast.target, "users");
    const targetRoute = broadcast.targetRoute || null;
    const targetIds = Array.isArray(broadcast.targetIds)
      ? broadcast.targetIds.map((id) => text(id)).filter((id) => id)
      : [];

    if (!message) {
      console.log("Skipped empty broadcast:", broadcastId);
      return;
    }

    const operations = [];

    async function addUsersNotifications(userIds = null) {
      if (userIds && userIds.length > 0) {
        userIds.forEach((uid) => {
          const ref = db
            .collection("users")
            .doc(uid)
            .collection("notifications")
            .doc(`admin_${broadcastId}`);

          operations.push({
            ref,
            data: {
              userId: uid,
              type: "adminMessage",
              title,
              message,
              body: message,

              referenceType: "system",
              referenceId: broadcastId,
              actionRoute: targetRoute,
              actionId: broadcastId,

              orderId: null,
              chatId: null,
              pharmacyId: null,
              pharmacyName: null,
              prescriptionId: null,

              beneficiaryId: null,
              beneficiaryName: null,
              beneficiaryType: null,

              iconName: "admin_broadcast",
              imageUrl: null,

              isActionable: targetRoute !== null,
              isDeleted: false,
              isRead: false,
              priority: text(broadcast.priority, "normal"),

              createdAt: now(),
              readAt: null,
              expiresAt: null,

              extraData: {
                source: "admin_panel_web",
                broadcastId,
                sentBy: broadcast.sentBy || null,
              },
            },
          });
        });

        return;
      }

      const usersSnap = await db.collection("users").get();

      usersSnap.docs.forEach((doc) => {
        const uid = doc.id;

        const ref = db
          .collection("users")
          .doc(uid)
          .collection("notifications")
          .doc(`admin_${broadcastId}`);

        operations.push({
          ref,
          data: {
            userId: uid,
            type: "adminMessage",
            title,
            message,
            body: message,

            referenceType: "system",
            referenceId: broadcastId,
            actionRoute: targetRoute,
            actionId: broadcastId,

            orderId: null,
            chatId: null,
            pharmacyId: null,
            pharmacyName: null,
            prescriptionId: null,

            beneficiaryId: null,
            beneficiaryName: null,
            beneficiaryType: null,

            iconName: "admin_broadcast",
            imageUrl: null,

            isActionable: targetRoute !== null,
            isDeleted: false,
            isRead: false,
            priority: text(broadcast.priority, "normal"),

            createdAt: now(),
            readAt: null,
            expiresAt: null,

            extraData: {
              source: "admin_panel_web",
              broadcastId,
              sentBy: broadcast.sentBy || null,
            },
          },
        });
      });
    }

    async function addPharmaciesNotifications(pharmacyIds = null) {
      if (pharmacyIds && pharmacyIds.length > 0) {
        pharmacyIds.forEach((pharmacyId) => {
          const ref = db
            .collection("pharmacies")
            .doc(pharmacyId)
            .collection("notifications")
            .doc(`admin_${broadcastId}`);

          operations.push({
            ref,
            data: {
              pharmacyId,
              type: "adminBroadcast",
              title,
              message,
              body: message,

              referenceType: "system",
              referenceId: broadcastId,
              actionRoute: targetRoute,
              actionId: broadcastId,

              iconName: "admin_broadcast",
              imageUrl: null,

              isActionable: targetRoute !== null,
              isDeleted: false,
              isRead: false,
              priority: text(broadcast.priority, "normal"),

              createdAt: now(),
              readAt: null,
              expiresAt: null,

              extraData: {
                source: "admin_panel_web",
                broadcastId,
                sentBy: broadcast.sentBy || null,
              },
            },
          });
        });

        return;
      }

      const pharmaciesSnap = await db.collection("pharmacies").get();

      pharmaciesSnap.docs.forEach((doc) => {
        const pharmacyId = doc.id;

        const ref = db
          .collection("pharmacies")
          .doc(pharmacyId)
          .collection("notifications")
          .doc(`admin_${broadcastId}`);

        operations.push({
          ref,
          data: {
            pharmacyId,
            type: "adminBroadcast",
            title,
            message,
            body: message,

            referenceType: "system",
            referenceId: broadcastId,
            actionRoute: targetRoute,
            actionId: broadcastId,

            iconName: "admin_broadcast",
            imageUrl: null,

            isActionable: targetRoute !== null,
            isDeleted: false,
            isRead: false,
            priority: text(broadcast.priority, "normal"),

            createdAt: now(),
            readAt: null,
            expiresAt: null,

            extraData: {
              source: "admin_panel_web",
              broadcastId,
              sentBy: broadcast.sentBy || null,
            },
          },
        });
      });
    }

    if (target === "users") {
      await addUsersNotifications();
    } else if (target === "pharmacies") {
      await addPharmaciesNotifications();
    } else if (target === "all") {
      await addUsersNotifications();
      await addPharmaciesNotifications();
    } else if (target === "selected_users") {
      await addUsersNotifications(targetIds);
    } else if (target === "selected_pharmacies") {
      await addPharmaciesNotifications(targetIds);
    } else {
      console.log("Unknown broadcast target:", target);
      return;
    }

    await commitInChunks(operations);

    await db
      .collection("adminBroadcastNotifications")
      .doc(broadcastId)
      .set({
        status: "sent",
        sentAt: now(),
        deliveredCount: operations.length,
      }, { merge: true });

    console.log("✅ Admin broadcast distributed:", broadcastId, operations.length);
  },
);