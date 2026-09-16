"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {initializeApp, deleteApp} = require("firebase/app");
const {getAuth, signInWithCustomToken} = require("firebase/auth");
const {
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
} = require("firebase/firestore");
const {
  initializeLiveSuite,
  testOrder,
  writeEvidence,
} = require("./helpers/live-firebase");

const SUITE_NAME = "f03-live-chat-notifications";

async function clientFor(context, identity) {
  const app = initializeApp({
    apiKey: context.apiKey,
    projectId: "pharma-apps",
  }, `${identity}-${context.runId}`);
  const auth = getAuth(app);
  const token = await context.auth.createCustomToken(context.identities[identity].uid);
  await signInWithCustomToken(auth, token);
  return {app, db: getFirestore(app)};
}

async function waitForDocument(reference, predicate = () => true, timeoutMs = 90000) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const snapshot = await reference.get();
    if (snapshot.exists && predicate(snapshot.data() || {})) return snapshot.data();
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  assert.fail(`Timed out waiting for ${reference.path}`);
}

test("F03 chat and notification chain on the live Firebase project", {
  timeout: 300000,
}, async (t) => {
  const context = await initializeLiveSuite(SUITE_NAME, {
    isolatedIdentities: true,
  });
  const userClient = await clientFor(context, "user");
  const pharmacyClient = await clientFor(context, "pharmacy");
  const orderId = `chat-order-${context.runId}`;
  const medicineId = `chat-medicine-${context.runId}`;
  const chatId = `order_${orderId}`;

  await context.db.doc(`users/${context.userUid}`).set({
    userId: context.userUid,
    name: "Live Chat User",
    isActive: true,
    liveTest: true,
  });
  await context.db.doc(`pharmacies/${context.pharmacyUid}`).set({
    pharmacyId: context.pharmacyUid,
    name: "Live Chat Pharmacy",
    pharmacyName: "Live Chat Pharmacy",
    status: "approved",
    isActive: true,
    isOnline: true,
    liveTest: true,
  });
  await context.db.doc(
    `pharmacies/${context.pharmacyUid}/medicines/${medicineId}`,
  ).set({
    id: medicineId,
    name: "Live Chat Medicine",
    quantity: 2,
    reservedQuantity: 0,
    isActive: true,
    expiryDate: context.admin.firestore.Timestamp.fromDate(
      new Date("2099-01-01T00:00:00Z"),
    ),
  });
  await writeEvidence(context, "running", {orderId, chatId});

  try {
    await context.db.doc(`orders/${orderId}`).set(testOrder(
      context,
      orderId,
      [{matchedMedicineId: medicineId, quantity: 1}],
    ));

    await t.test("new order creates the deterministic pharmacy notification", async () => {
      const notification = await waitForDocument(context.db.doc(
        `pharmacies/${context.pharmacyUid}/notifications/new_order_${orderId}`,
      ));
      assert.equal(notification.orderId, orderId);
      assert.equal(notification.type, "newOrder");
    });

    await t.test("order command creates a visible user notification once", async () => {
      await context.call("pharmacy", "confirmFullOrder", orderId);
      const notificationRef = context.db.doc(
        `users/${context.userUid}/notifications/` +
          `order_${orderId}_confirmedReserved_1`,
      );
      await waitForDocument(notificationRef,
        (data) => data.pushDelivery?.state === "skipped");
      const duplicates = await context.db.collection(`users/${context.userUid}/notifications`)
        .get();
      assert.equal(duplicates.docs.filter((entry) => entry.data().extraData?.status ===
        "confirmedReserved" && entry.data().orderId === orderId).length, 1);
    });

    await t.test("user creates exactly one order chat and both indexed lists can read it", async () => {
      const userDb = userClient.db;
      await runTransaction(userDb, async (transaction) => {
        const orderRef = doc(userDb, `orders/${orderId}`);
        const chatRef = doc(userDb, `chats/${chatId}`);
        const order = await transaction.get(orderRef);
        const chat = await transaction.get(chatRef);
        assert.equal(order.exists(), true);
        if (!chat.exists()) {
          transaction.set(chatRef, {
            chatId,
            orderId,
            userId: context.userUid,
            userName: "Live Chat User",
            pharmacyId: context.pharmacyUid,
            pharmacyName: "Live Chat Pharmacy",
            lastMessage: "تم إنشاء المحادثة",
            lastMessageType: "system",
            lastMessageTime: serverTimestamp(),
            userUnreadCount: 0,
            pharmacyUnreadCount: 0,
            createdAt: serverTimestamp(),
            updatedAt: serverTimestamp(),
          });
          transaction.set(doc(userDb, `chats/${chatId}/messages/conversation_created`), {
            senderId: "system",
            senderName: "النظام",
            senderType: "system",
            type: "system",
            text: "تم إنشاء المحادثة",
            status: "read",
            isRead: true,
            timestamp: serverTimestamp(),
          });
        }
        transaction.update(orderRef, {chatId, updatedAt: serverTimestamp()});
      });
      const userChats = await getDocs(query(
        collection(userDb, "chats"),
        where("userId", "==", context.userUid),
        orderBy("lastMessageTime", "desc"),
      ));
      const pharmacyChats = await getDocs(query(
        collection(pharmacyClient.db, "chats"),
        where("pharmacyId", "==", context.pharmacyUid),
        orderBy("lastMessageTime", "desc"),
      ));
      assert.equal(userChats.docs.filter((entry) => entry.id === chatId).length, 1);
      assert.equal(pharmacyChats.docs.filter((entry) => entry.id === chatId).length, 1);
    });

    await t.test("pharmacy message creates one user notification", async () => {
      const chat = await getDoc(doc(pharmacyClient.db, `chats/${chatId}`));
      assert.equal(chat.exists(), true, "the order chat must exist before messaging");
      const message = await addDoc(
        collection(pharmacyClient.db, `chats/${chatId}/messages`),
        {
          senderId: context.pharmacyUid,
          senderName: "Live Chat Pharmacy",
          senderType: "pharmacy",
          type: "text",
          text: "رسالة اختبار فعلية",
          status: "sent",
          isRead: false,
          timestamp: serverTimestamp(),
        },
      );
      await updateDoc(doc(pharmacyClient.db, `chats/${chatId}`), {
        lastMessage: "رسالة اختبار فعلية",
        lastMessageType: "text",
        lastMessageTime: serverTimestamp(),
        userUnreadCount: 1,
        pharmacyUnreadCount: 0,
        updatedAt: serverTimestamp(),
      });
      const notification = await waitForDocument(context.db.doc(
        `users/${context.userUid}/notifications/chat_${message.id}`,
      ), (data) => data.pushDelivery?.state === "skipped");
      assert.equal(notification.chatId, chatId);
      assert.equal(notification.type, "pharmacyMessage");
    });

    await t.test("terminal order rules reject new chat messages", async () => {
      const chat = await getDoc(doc(userClient.db, `chats/${chatId}`));
      assert.equal(chat.exists(), true, "the order chat must exist before closing it");
      await context.db.doc(`orders/${orderId}`).update({status: "completed"});
      await assert.rejects(
        setDoc(doc(userClient.db, `chats/${chatId}/messages/after-close`), {
          senderId: context.userUid,
          senderName: "Live Chat User",
          senderType: "user",
          type: "text",
          text: "must fail",
          status: "sent",
          isRead: false,
          timestamp: serverTimestamp(),
        }),
        (error) => String(error.code).includes("permission-denied"),
      );
    });

    await writeEvidence(context, "passed", {orderId, chatId});
  } catch (error) {
    await writeEvidence(context, "failed", {
      orderId,
      chatId,
      errorCode: error.code || "unknown",
      errorMessage: String(error.message || error).slice(0, 500),
    });
    throw error;
  } finally {
    await deleteApp(userClient.app);
    await deleteApp(pharmacyClient.app);
    await context.app.delete();
  }
});
