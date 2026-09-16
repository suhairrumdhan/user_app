"use strict";

const admin = require("firebase-admin");
const { doc, getDoc, setDoc } = require("firebase/firestore");
const { assertIsolatedEnvironment } = require("./environment");

const FIXED_NOW = new Date("2026-01-15T09:00:00.000Z");
const VALID_EXPIRY = new Date("2027-01-15T00:00:00.000Z");
const EXPIRED_EXPIRY = new Date("2025-01-15T00:00:00.000Z");
const TEST_PASSWORD = "F02-Test-Only-123!";

const AUTH_FIXTURES = Object.freeze([
  { uid: "user-one", email: "user-one@f02.test", displayName: "User One" },
  { uid: "user-two", email: "user-two@f02.test", displayName: "User Two" },
  { uid: "pharmacy-one", email: "pharmacy-one@f02.test", displayName: "Pharmacy One" },
  { uid: "pharmacy-two", email: "pharmacy-two@f02.test", displayName: "Pharmacy Two" },
  { uid: "admin-allowed", email: "admin-allowed@f02.test", displayName: "Allowed Admin" },
  { uid: "admin-denied", email: "admin-denied@f02.test", displayName: "Denied Admin" },
]);

function buildFixtureDocuments() {
  return [
    ["users/user-one", {
      userId: "user-one",
      name: "Test User One",
      email: "user-one@f02.test",
      isActive: true,
      healthConditions: ["fixture-private-condition"],
      createdAt: FIXED_NOW,
    }],
    ["users/user-two", {
      userId: "user-two",
      name: "Test User Two",
      email: "user-two@f02.test",
      isActive: true,
      healthConditions: ["fixture-private-condition-two"],
      createdAt: FIXED_NOW,
    }],
    ["users/user-one/familyMembers/beneficiary-one", {
      id: "beneficiary-one",
      userId: "user-one",
      name: "Beneficiary One",
      relation: "child",
      allergies: ["fixture-allergy-one"],
      createdAt: FIXED_NOW,
    }],
    ["users/user-two/familyMembers/beneficiary-two", {
      id: "beneficiary-two",
      userId: "user-two",
      name: "Beneficiary Two",
      relation: "parent",
      allergies: ["fixture-allergy-two"],
      createdAt: FIXED_NOW,
    }],
    ["pharmacies/pharmacy-one", {
      id: "pharmacy-one",
      pharmacyId: "pharmacy-one",
      name: "F02 Pharmacy One",
      status: "approved",
      isActive: true,
      createdAt: FIXED_NOW,
    }],
    ["pharmacies/pharmacy-two", {
      id: "pharmacy-two",
      pharmacyId: "pharmacy-two",
      name: "F02 Pharmacy Two",
      status: "approved",
      isActive: true,
      createdAt: FIXED_NOW,
    }],
    ["pharmacies/pharmacy-one/settings/businessHours", {
      timezone: "Africa/Tripoli",
      workingHours: {monday: {open: "08:00", close: "22:00"}},
      updatedAt: FIXED_NOW,
    }],
    ["pharmacies/pharmacy-one/employees/employee-manager", {
      id: "employee-manager",
      name: "Fixture Manager",
      roleId: "admin",
      roleDisplay: "Administrator",
      isActive: true,
      permissionOverrides: {
        "orders.update": true,
        "orders.update_status": true,
        "inventory.update": true,
      },
      createdAt: FIXED_NOW,
    }],
    ["pharmacies/pharmacy-one/employees/employee-viewer", {
      id: "employee-viewer",
      name: "Fixture Viewer",
      roleId: "cashier",
      roleDisplay: "Cashier",
      isActive: true,
      permissionOverrides: { "orders.update": false, "inventory.update": false },
      createdAt: FIXED_NOW,
    }],
    ["adminEmployees/admin-allowed", {
      uid: "admin-allowed",
      name: "Allowed Admin",
      role: "super_admin",
      isActive: true,
      permissions: { "notifications.send": true, "employees.create": true },
      createdAt: FIXED_NOW,
    }],
    ["adminEmployees/admin-denied", {
      uid: "admin-denied",
      name: "Denied Admin",
      role: "viewer",
      isActive: true,
      permissions: { "notifications.send": false, "employees.create": false },
      createdAt: FIXED_NOW,
    }],
    ["pharmacies/pharmacy-one/medicines/batch-valid", {
      id: "batch-valid",
      name: "F02 Valid Medicine Batch",
      scientificName: "Fixture Valid",
      batchNumber: "F02-VALID-001",
      quantity: 10,
      reservedQuantity: 0,
      expiryDate: VALID_EXPIRY,
      isActive: true,
      lastUpdated: FIXED_NOW,
    }],
    ["pharmacies/pharmacy-one/medicines/batch-expired", {
      id: "batch-expired",
      name: "F02 Expired Medicine Batch",
      scientificName: "Fixture Expired",
      batchNumber: "F02-EXPIRED-001",
      quantity: 10,
      reservedQuantity: 0,
      expiryDate: EXPIRED_EXPIRY,
      isActive: true,
      lastUpdated: FIXED_NOW,
    }],
    ["orders/order-one", {
      schemaVersion: 3,
      orderId: "order-one",
      orderNumber: "260115-1000",
      user: {userId: "user-one", name: "Test User One"},
      pharmacy: {pharmacyId: "pharmacy-one", pharmacyName: "F02 Pharmacy One"},
      status: "underReview",
      statusLabel: "قيد المراجعة",
      medicines: [{matchedMedicineId: "batch-valid", quantity: 1}],
      statusHistory: [],
      createdAt: FIXED_NOW,
      updatedAt: FIXED_NOW,
    }],
    ["chats/order_order-one", {
      chatId: "order_order-one",
      orderId: "order-one",
      userId: "user-one",
      userName: "Test User One",
      pharmacyId: "pharmacy-one",
      pharmacyName: "F02 Pharmacy One",
      lastMessage: "Fixture message",
      lastMessageType: "text",
      lastMessageTime: FIXED_NOW,
      userUnreadCount: 0,
      pharmacyUnreadCount: 1,
      createdAt: FIXED_NOW,
      updatedAt: FIXED_NOW,
    }],
    ["chats/order_order-one/messages/message-one", {
      senderId: "user-one",
      senderName: "Test User One",
      senderType: "user",
      type: "text",
      text: "Fixture message",
      status: "sent",
      isRead: false,
      timestamp: FIXED_NOW,
    }],
    ["adminOrderSummaries/order-one", {
      schemaVersion: 3,
      orderId: "order-one",
      orderNumber: "260115-1000",
      pharmacyId: "pharmacy-one",
      pharmacyName: "F02 Pharmacy One",
      status: "underReview",
      statusLabel: "قيد المراجعة",
      totalItemsCount: 1,
      createdAt: FIXED_NOW,
      updatedAt: FIXED_NOW,
    }],
  ];
}

function getAdminAuth(projectId) {
  const appName = `f02-${projectId}`;
  let app = admin.apps.find((candidate) => candidate.name === appName);
  if (!app) {
    app = admin.initializeApp({ projectId }, appName);
  }
  return app.auth();
}

async function upsertAuthFixtures(projectId) {
  const auth = getAdminAuth(projectId);
  for (const fixture of AUTH_FIXTURES) {
    const record = { ...fixture, password: TEST_PASSWORD, emailVerified: true };
    try {
      await auth.getUser(fixture.uid);
      await auth.updateUser(fixture.uid, record);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
      await auth.createUser(record);
    }
  }
}

async function clearAuthEmulator(environment) {
  const url = `http://${environment.authHost}/emulator/v1/projects/` +
    `${environment.projectId}/accounts`;
  const response = await fetch(url, { method: "DELETE" });
  if (!response.ok) {
    throw new Error(`Auth emulator reset failed: ${response.status}`);
  }
}

async function seedFixtureData(testEnvironment) {
  const environment = assertIsolatedEnvironment();
  await upsertAuthFixtures(environment.projectId);
  const fixtures = buildFixtureDocuments();
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    for (const [path, data] of fixtures) {
      await setDoc(doc(firestore, path), data);
    }
  });
  return fixtures.map(([path]) => path);
}

async function resetFixtureData(testEnvironment) {
  const environment = assertIsolatedEnvironment();
  await testEnvironment.clearFirestore();
  if (typeof testEnvironment.clearStorage === "function") {
    await testEnvironment.clearStorage();
  }
  await clearAuthEmulator(environment);
  return seedFixtureData(testEnvironment);
}

function normalizeValue(value) {
  if (value && typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }
  if (value instanceof Date) return value.toISOString();
  if (Array.isArray(value)) return value.map(normalizeValue);
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).sort().map(([key, item]) => [key, normalizeValue(item)]),
    );
  }
  return value;
}

async function snapshotFixtureData(testEnvironment) {
  const fixtures = buildFixtureDocuments();
  return testEnvironment.withSecurityRulesDisabled(async (context) => {
    const firestore = context.firestore();
    const snapshot = {};
    for (const [path] of fixtures) {
      const result = await getDoc(doc(firestore, path));
      snapshot[path] = normalizeValue(result.data());
    }
    return snapshot;
  });
}

module.exports = {
  AUTH_FIXTURES,
  EXPIRED_EXPIRY,
  FIXED_NOW,
  VALID_EXPIRY,
  buildFixtureDocuments,
  resetFixtureData,
  seedFixtureData,
  snapshotFixtureData,
};
