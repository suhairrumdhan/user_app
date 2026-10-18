"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { after, before, test } = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  where,
  writeBatch,
} = require("firebase/firestore");
const { getBytes, ref, uploadString } = require("firebase/storage");
const {
  assertIsolatedEnvironment,
  buildEmulatorEnvironment,
} = require("../helpers/environment");
const {
  FIXED_NOW,
  VALID_EXPIRY,
  resetFixtureData,
  snapshotFixtureData,
} = require("../helpers/fixtures");

Object.assign(process.env, buildEmulatorEnvironment(process.env));
const environment = assertIsolatedEnvironment();
const repositoryRoot = path.resolve(__dirname, "..", "..", "..");
let testEnvironment;

before(async () => {
  testEnvironment = await initializeTestEnvironment({
    projectId: environment.projectId,
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: fs.readFileSync(path.join(repositoryRoot, "firestore.rules"), "utf8"),
    },
    storage: {
      host: "127.0.0.1",
      port: 9199,
      rules: fs.readFileSync(path.join(repositoryRoot, "storage.rules"), "utf8"),
    },
  });
});

after(async () => {
  if (testEnvironment) await testEnvironment.cleanup();
});

test("fixture reset is idempotent and recreates identical values", async () => {
  await resetFixtureData(testEnvironment);
  const first = await snapshotFixtureData(testEnvironment);
  await resetFixtureData(testEnvironment);
  const second = await snapshotFixtureData(testEnvironment);
  assert.deepEqual(second, first);
});

test("Firestore rejects cross-user and unauthorized admin access", async () => {
  await resetFixtureData(testEnvironment);
  const userOne = testEnvironment.authenticatedContext("user-one").firestore();
  const userTwo = testEnvironment.authenticatedContext("user-two").firestore();
  const deniedAdmin = testEnvironment
    .authenticatedContext("admin-denied")
    .firestore();
  const allowedAdmin = testEnvironment
    .authenticatedContext("admin-allowed")
    .firestore();

  await assertSucceeds(getDoc(doc(userOne, "users/user-one")));
  await assertFails(getDoc(doc(userOne, "users/user-two")));
  await assertFails(setDoc(doc(userTwo, "users/user-one"), { name: "tampered" }));
  await assertFails(getDoc(doc(deniedAdmin, "users/user-one")));
  await assertFails(getDoc(doc(allowedAdmin, "users/user-one")));
});

test("insurance rules enforce one deterministic policy document per beneficiary", async () => {
  await resetFixtureData(testEnvironment);
  const user = testEnvironment.authenticatedContext("user-one").firestore();
  const valid = {
    schemaVersion: 2,
    beneficiaryId: "beneficiary-one",
    beneficiaryType: "family",
    beneficiaryName: "Beneficiary One",
    companyCode: "C1",
    companyName: "Company One",
    policyNumber: "POLICY-ONE",
    cardNumber: "POLICY-ONE",
    coveredMemberIds: ["beneficiary-one"],
    startDate: FIXED_NOW,
    endDate: VALID_EXPIRY,
  };

  await assertSucceeds(setDoc(
    doc(user, "users/user-one/insurances/beneficiary-one"),
    valid,
  ));
  await assertFails(setDoc(
    doc(user, "users/user-one/insurances/another-document"),
    {...valid, policyNumber: "SECOND"},
  ));
  await assertFails(setDoc(
    doc(user, "users/user-one/insurances/beneficiary-two"),
    {...valid, beneficiaryId: "beneficiary-two", coveredMemberIds: ["beneficiary-one", "beneficiary-two"]},
  ));
});

test("order state is server-only and admins receive summaries only", async () => {
  await resetFixtureData(testEnvironment);
  const owner = testEnvironment.authenticatedContext("user-one").firestore();
  const other = testEnvironment.authenticatedContext("user-two").firestore();
  const adminDb = testEnvironment.authenticatedContext("admin-allowed").firestore();
  const orderRef = doc(owner, "orders/order-one");

  await assertSucceeds(getDoc(orderRef));
  await assertFails(getDoc(doc(other, "orders/order-one")));
  await assertFails(setDoc(orderRef, {status: "completed"}, {merge: true}));
  await assertSucceeds(setDoc(orderRef, {
    userNote: "fixture note",
    updatedAt: FIXED_NOW,
  }, {merge: true}));
  await assertFails(getDoc(doc(adminDb, "orders/order-one")));
  await assertSucceeds(getDoc(doc(adminDb, "adminOrderSummaries/order-one")));
});

test("signed-in users can read public pharmacy hours but cannot change them", async () => {
  await resetFixtureData(testEnvironment);
  const userDb = testEnvironment.authenticatedContext("user-one").firestore();
  const hoursRef = doc(
    userDb,
    "pharmacies/pharmacy-one/settings/businessHours",
  );
  await assertSucceeds(getDoc(hoursRef));
  await assertFails(setDoc(hoursRef, {workingHours: {}}, {merge: true}));
});

test("only the owning pharmacy can maintain its own medicine index", async () => {
  await resetFixtureData(testEnvironment);
  const owner = testEnvironment.authenticatedContext("pharmacy-one", {email_verified: true}).firestore();
  const other = testEnvironment.authenticatedContext("pharmacy-two", {email_verified: true}).firestore();
  const user = testEnvironment.authenticatedContext("user-one").firestore();
  const path = "medicine_search_index/pharmacy-one_batch-valid";
  const projection = {pharmacyId: "pharmacy-one", medicineId: "batch-valid", available: true};
  await assertSucceeds(setDoc(doc(owner, path), projection));
  await assertSucceeds(getDoc(doc(user, path)));
  for (const db of [other, user]) {
    await assertFails(setDoc(doc(db, path), {available: false}, {merge: true}));
    await assertFails(deleteDoc(doc(db, path)));
  }
  await assertSucceeds(setDoc(doc(owner, path), {available: false}, {merge: true}));
  await assertFails(setDoc(doc(owner, path), {pharmacyId: "pharmacy-two"}, {merge: true}));
  await assertSucceeds(deleteDoc(doc(owner, path)));
  await assertFails(setDoc(doc(other, path), projection));
  await assertFails(setDoc(doc(user, path), projection));
});

test("index creation requires an existing medicine and the exact owner-derived document id", async () => {
  await resetFixtureData(testEnvironment);
  const owner = testEnvironment.authenticatedContext("pharmacy-one", {email_verified: true}).firestore();
  await assertFails(setDoc(doc(owner, "medicine_search_index/pharmacy-one_missing"), {
    pharmacyId: "pharmacy-one", medicineId: "missing", available: true,
  }));
  await assertFails(setDoc(doc(owner, "medicine_search_index/forged-id"), {
    pharmacyId: "pharmacy-one", medicineId: "batch-valid", available: true,
  }));
});

test("pharmacy can stop receiving orders but cannot grant itself approval or unblock itself", async () => {
  await resetFixtureData(testEnvironment);
  const owner = testEnvironment.authenticatedContext("pharmacy-one", {email_verified: true}).firestore();
  const admin = testEnvironment.authenticatedContext("admin-allowed").firestore();
  const path = "pharmacies/pharmacy-one";
  await assertSucceeds(setDoc(doc(owner, path), {isOnline: false}, {merge: true}));
  await assertFails(setDoc(doc(admin, path), {isBlocked: true}, {merge: true}));
  for (const patch of [{isBlocked: false}, {status: "pending"}, {isActive: false},
    {approvedBy: "self"}, {approvedDate: FIXED_NOW}, {sourceRequestId: "fake"}]) {
    await assertFails(setDoc(doc(owner, path), patch, {merge: true}));
  }
  await assertSucceeds(setDoc(doc(owner, path), {isOnline: true, phone: "fixture"}, {merge: true}));
  await assertFails(setDoc(doc(admin, path), {isBlocked: false}, {merge: true}));
});

test("employee account profiles credentials and sessions are server-only", async () => {
  await resetFixtureData(testEnvironment);
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "pharmacies/pharmacy-one/employeeCredentials/employee-manager"), {
      passwordHash: "server-only",
      salt: "server-only",
      credentialVersion: 1,
    });
    await setDoc(doc(db, "pharmacies/pharmacy-one/employeeUsernames/server-only"), {
      employeeId: "employee-manager",
    });
    await setDoc(doc(db, "pharmacies/pharmacy-one/employeeSessions/server-only"), {
      employeeId: "employee-manager",
    });
  });
  const owner = testEnvironment.authenticatedContext("pharmacy-one", {email_verified: true}).firestore();
  const employee = doc(owner, "pharmacies/pharmacy-one/employees/employee-manager");
  await assertSucceeds(getDoc(employee));
  await assertFails(setDoc(employee, {name: "Updated Manager"}, {merge: true}));
  for (const mutation of [
    {username: "forged"},
    {usernameKey: "forged"},
    {password: "plaintext"},
    {passwordHash: "forged"},
    {credentialVersion: 99},
  ]) {
    await assertFails(setDoc(employee, mutation, {merge: true}));
  }
  await assertFails(setDoc(
    doc(owner, "pharmacies/pharmacy-one/employees/forged"),
    {id: "forged", name: "Forged"},
  ));
  for (const path of [
    "pharmacies/pharmacy-one/employeeCredentials/employee-manager",
    "pharmacies/pharmacy-one/employeeUsernames/server-only",
    "pharmacies/pharmacy-one/employeeSessions/server-only",
  ]) {
    await assertFails(getDoc(doc(owner, path)));
    await assertFails(setDoc(doc(owner, path), {forged: true}, {merge: true}));
  }
});

test("canonical order invoices and ledger cannot be forged edited or deleted by a pharmacy", async () => {
  await resetFixtureData(testEnvironment);
  const pharmacy = testEnvironment.authenticatedContext("pharmacy-one", {email_verified: true}).firestore();
  const root = "pharmacies/pharmacy-one";
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `${root}/sales/order-fixture`), {
      source: "order", orderId: "order-one", sourceOrderId: "order-one", total: 10,
    });
    await setDoc(doc(context.firestore(), `${root}/financial_transactions/order-customer-order-one`), {
      referenceCollection: "sales", referenceId: "order-fixture", amount: 10, metadata: {source: "order"},
    });
  });
  const invoice = doc(pharmacy, `${root}/sales/order-fixture`);
  const ledger = doc(pharmacy, `${root}/financial_transactions/order-customer-order-one`);
  await assertSucceeds(getDoc(invoice));
  await assertFails(setDoc(invoice, {total: 1}, {merge: true}));
  await assertFails(setDoc(invoice, {source: "pos", orderId: null, sourceOrderId: null}));
  await assertFails(deleteDoc(invoice));
  await assertFails(setDoc(doc(pharmacy, `${root}/sales/forged-order`), {source: "order", orderId: "order-one"}));
  await assertFails(setDoc(doc(pharmacy, `${root}/sales/order-reserved-id`), {source: "pos"}));
  await assertFails(setDoc(doc(pharmacy, `${root}/sales/fake-pos-refund`), {source: "pos", refSaleId: "order-fixture"}));
  await assertFails(setDoc(ledger, {amount: 100}, {merge: true}));
  await assertFails(deleteDoc(ledger));
  await assertFails(setDoc(doc(pharmacy, `${root}/financial_transactions/forged`), {
    referenceCollection: "sales", referenceId: "order-fixture", amount: 100,
  }));
});

test("POS invoice and financial entry are server-only even in a client batch", async () => {
  await resetFixtureData(testEnvironment);
  const pharmacy = testEnvironment.authenticatedContext("pharmacy-one", {email_verified: true}).firestore();
  const root = "pharmacies/pharmacy-one";
  const batch = writeBatch(pharmacy);
  batch.set(doc(pharmacy, `${root}/sales/pos-fixture`), {
    source: "pos", orderId: null, sourceOrderId: null, total: 10,
  });
  batch.set(doc(pharmacy, `${root}/financial_transactions/pos-fixture-sale`), {
    referenceCollection: "sales", referenceId: "pos-fixture", amount: 10, metadata: null,
  });
  await assertFails(batch.commit());
  await assertFails(setDoc(doc(pharmacy, `${root}/sales/pos-fixture`), {notes: "printed"}, {merge: true}));
  await assertFails(setDoc(doc(pharmacy, `${root}/sales/pos-fixture`), {source: "order"}, {merge: true}));
});

test("users and pharmacies cannot change server-owned order incidents or quarantine", async () => {
  await resetFixtureData(testEnvironment);
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users/user-one/orderIncidents/order-one"), {occurrenceCount: 1});
    await setDoc(doc(context.firestore(), "pharmacies/pharmacy-one/quarantinedReturns/return-one"), {quantity: 1});
  });
  const user = testEnvironment.authenticatedContext("user-one").firestore();
  const pharmacy = testEnvironment.authenticatedContext("pharmacy-one", {email_verified: true}).firestore();
  const incident = doc(user, "users/user-one/orderIncidents/order-one");
  await assertSucceeds(getDoc(incident));
  await assertFails(setDoc(incident, {occurrenceCount: 0}));
  await assertFails(deleteDoc(incident));
  const quarantine = doc(pharmacy, "pharmacies/pharmacy-one/quarantinedReturns/return-one");
  await assertSucceeds(getDoc(quarantine));
  await assertFails(setDoc(quarantine, {quantity: 0}));
  await assertFails(deleteDoc(quarantine));
});

test("only the order user and pharmacy can access its chat", async () => {
  await resetFixtureData(testEnvironment);
  const userDb = testEnvironment.authenticatedContext("user-one").firestore();
  const pharmacyDb = testEnvironment
    .authenticatedContext("pharmacy-one", {email_verified: true})
    .firestore();
  const outsiderDb = testEnvironment.authenticatedContext("user-two").firestore();

  await assertSucceeds(getDocs(query(
    collection(userDb, "chats"),
    where("userId", "==", "user-one"),
  )));
  await assertSucceeds(getDocs(query(
    collection(pharmacyDb, "chats"),
    where("pharmacyId", "==", "pharmacy-one"),
  )));
  await assertFails(getDoc(doc(outsiderDb, "chats/order_order-one")));

  await assertSucceeds(setDoc(
    doc(pharmacyDb, "chats/order_order-one"),
    {pharmacyUnreadCount: 0, updatedAt: FIXED_NOW},
    {merge: true},
  ));
  await assertSucceeds(setDoc(
    doc(pharmacyDb, "chats/order_order-one/messages/message-two"),
    {
      senderId: "pharmacy-one",
      senderName: "Fixture Pharmacy",
      senderType: "pharmacy",
      type: "text",
      text: "Fixture reply",
      status: "sent",
      isRead: false,
      timestamp: FIXED_NOW,
    },
  ));
  await assertFails(setDoc(
    doc(outsiderDb, "chats/order_order-one/messages/message-three"),
    {
      senderId: "user-two",
      senderType: "user",
      type: "text",
      text: "tampered",
      status: "sent",
      isRead: false,
      timestamp: FIXED_NOW,
    },
  ));
});

test("an order participant can atomically create a missing deterministic chat", async () => {
  await resetFixtureData(testEnvironment);
  const orderId = "order-chat-create";
  const chatId = `order_${orderId}`;
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `orders/${orderId}`), {
      schemaVersion: 3,
      orderId,
      orderNumber: "260115-1001",
      user: {userId: "user-one", name: "Test User One"},
      pharmacy: {
        pharmacyId: "pharmacy-one",
        pharmacyName: "F02 Pharmacy One",
      },
      status: "underReview",
      statusLabel: "قيد المراجعة",
      medicines: [{matchedMedicineId: "batch-valid", quantity: 1}],
      statusHistory: [],
      createdAt: FIXED_NOW,
      updatedAt: FIXED_NOW,
    });
  });

  const userDb = testEnvironment.authenticatedContext("user-one").firestore();
  await assertSucceeds(runTransaction(userDb, async (transaction) => {
    const orderRef = doc(userDb, `orders/${orderId}`);
    const chatRef = doc(userDb, `chats/${chatId}`);
    const messageRef = doc(
      userDb,
      `chats/${chatId}/messages/conversation_created`,
    );
    const order = await transaction.get(orderRef);
    const chat = await transaction.get(chatRef);
    assert.equal(order.exists(), true);
    assert.equal(chat.exists(), false);
    transaction.set(chatRef, {
      chatId,
      orderId,
      userId: "user-one",
      userName: "Test User One",
      pharmacyId: "pharmacy-one",
      pharmacyName: "F02 Pharmacy One",
      lastMessage: "تم إنشاء المحادثة",
      lastMessageType: "system",
      lastMessageTime: serverTimestamp(),
      userUnreadCount: 0,
      pharmacyUnreadCount: 0,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
    transaction.set(messageRef, {
      senderId: "system",
      senderName: "النظام",
      senderType: "system",
      type: "system",
      text: "تم إنشاء المحادثة",
      status: "read",
      isRead: true,
      timestamp: serverTimestamp(),
    });
    transaction.update(orderRef, {
      chatId,
      updatedAt: serverTimestamp(),
    });
  }));

  const pharmacyDb = testEnvironment
    .authenticatedContext("pharmacy-one", {email_verified: true})
    .firestore();
  const outsiderDb = testEnvironment.authenticatedContext("user-two").firestore();
  const anonymousDb = testEnvironment.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(userDb, `chats/${chatId}`)));
  await assertSucceeds(getDocs(query(
    collection(userDb, "chats"),
    where("userId", "==", "user-one"),
    orderBy("lastMessageTime", "desc"),
  )));
  await assertSucceeds(getDocs(query(
    collection(pharmacyDb, "chats"),
    where("pharmacyId", "==", "pharmacy-one"),
    orderBy("lastMessageTime", "desc"),
  )));
  await assertFails(setDoc(doc(userDb, "chats/order_duplicate"), {
    chatId: "order_duplicate",
    orderId,
    userId: "user-one",
    userName: "Test User One",
    pharmacyId: "pharmacy-one",
    pharmacyName: "F02 Pharmacy One",
    lastMessage: "duplicate",
    lastMessageType: "system",
    lastMessageTime: FIXED_NOW,
    userUnreadCount: 0,
    pharmacyUnreadCount: 0,
    createdAt: FIXED_NOW,
    updatedAt: FIXED_NOW,
  }));
  await assertFails(getDoc(doc(outsiderDb, `chats/${chatId}`)));
  await assertFails(getDoc(doc(anonymousDb, "chats/order_missing")));
});

test("completed cancelled rejected and not-collected orders close chat writes", async () => {
  for (const status of ["completed", "cancelled", "rejected", "notCollected"]) {
    await resetFixtureData(testEnvironment);
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "orders/order-one"), {status}, {merge: true});
    });
    const user = testEnvironment.authenticatedContext("user-one").firestore();
    await assertFails(setDoc(
      doc(user, `chats/order_order-one/messages/closed-${status}`),
      {
        senderId: "user-one",
        senderName: "User One",
        senderType: "user",
        type: "text",
        text: "must be rejected",
        status: "sent",
        isRead: false,
        timestamp: FIXED_NOW,
      },
    ));
  }
});

test("Storage accepts an owner's file and rejects another user", async () => {
  await resetFixtureData(testEnvironment);
  const ownerStorage = testEnvironment
    .authenticatedContext("user-one")
    .storage();
  const otherStorage = testEnvironment
    .authenticatedContext("user-two")
    .storage();
  const objectPath = "users/user-one/prescriptions/f02-prescription.pdf";
  await assertSucceeds(uploadString(
    ref(ownerStorage, objectPath),
    "F02 fixture document",
    "raw",
    { contentType: "application/pdf" },
  ));
  await assertSucceeds(getBytes(ref(ownerStorage, objectPath)));
  await assertFails(getBytes(ref(otherStorage, objectPath)));
});
