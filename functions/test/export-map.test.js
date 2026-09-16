"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const deployed = require("../src");

const expected = {
  processOrderDeadlines: {type: "schedule", schedule: "every 5 minutes"},
  refreshMedicineSearchAvailability: {type: "schedule", schedule: "every 15 minutes"},
  onPharmacySearchProfileWritten: {
    type: "google.cloud.firestore.document.v1.written",
    document: "pharmacies/{pharmacyId}",
    retry: true,
  },
  onMedicineStockWritten: {
    type: "google.cloud.firestore.document.v1.written",
    document: "pharmacies/{pharmacyId}/medicines/{medicineId}",
    retry: true,
  },
  executeOrderCommand: { type: "callable" },
  loginEmployee: {type: "callable"},
  managePharmacyEmployeeAccount: {type: "callable"},
  managePharmacyEmployeeCredential: {type: "callable"},
  migrateLegacyEmployeeCredential: {type: "callable"},
  createPharmacyEmployeeSession: {type: "callable"},
  revokePharmacyEmployeeSession: {type: "callable"},
  syncUserPushToken: {type: "callable"},
  createAdminEmployee: { type: "callable" },
  onNotificationCreated: {
    type: "google.cloud.firestore.document.v1.created",
    document: "users/{userId}/notifications/{notificationId}",
    retry: true,
  },
  onChatMessageCreated: {
    type: "google.cloud.firestore.document.v1.created",
    document: "chats/{chatId}/messages/{messageId}",
    retry: true,
  },
  onOrderCreated: {
    type: "google.cloud.firestore.document.v1.created",
    document: "orders/{orderId}",
    retry: true,
  },
  onOrderUpdated: {
    type: "google.cloud.firestore.document.v1.updated",
    document: "orders/{orderId}",
    retry: true,
  },
  sendAdminBroadcast: {
    type: "google.cloud.firestore.document.v1.created",
    document: "adminBroadcastNotifications/{broadcastId}",
  },
};

test("exports exactly the reviewed Cloud Functions contract", () => {
  assert.deepEqual(Object.keys(deployed).sort(), Object.keys(expected).sort());

  const eventKeys = new Set();
  for (const [name, contract] of Object.entries(expected)) {
    const endpoint = deployed[name].__endpoint;
    assert.ok(endpoint, `${name} must expose deployment metadata`);

    if (contract.type === "schedule") {
      assert.equal(endpoint.scheduleTrigger.schedule, contract.schedule);
      assert.equal(endpoint.scheduleTrigger.timeZone, "UTC");
      continue;
    }

    if (contract.type === "callable") {
      assert.ok(endpoint.callableTrigger, `${name} must remain callable`);
      continue;
    }

    assert.equal(endpoint.eventTrigger.eventType, contract.type);
    assert.equal(
      endpoint.eventTrigger.eventFilterPathPatterns.document,
      contract.document,
    );
    assert.equal(endpoint.eventTrigger.retry, contract.retry === true);

    const eventKey = `${contract.type}:${contract.document}`;
    assert.equal(eventKeys.has(eventKey), false, `duplicate trigger ${eventKey}`);
    eventKeys.add(eventKey);
  }
});

test("root entry point re-exports the canonical source", () => {
  assert.equal(require(".."), deployed);
});

test("firebase config owns functions, rules, indexes, and storage", () => {
  const configPath = path.join(__dirname, "..", "..", "firebase.json");
  const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const functionsConfig = Array.isArray(config.functions) ?
    config.functions[0] : config.functions;

  assert.equal(functionsConfig.source, "functions");
  assert.equal(functionsConfig.codebase, "default");
  assert.equal(functionsConfig.runtime, "nodejs24");
  assert.equal(config.firestore.rules, "firestore.rules");
  assert.equal(config.firestore.indexes, "firestore.indexes.json");
  assert.equal(config.storage.rules, "storage.rules");
  const indexes = JSON.parse(fs.readFileSync(
    path.join(__dirname, "..", "..", config.firestore.indexes),
    "utf8",
  ));
  const indexKeys = new Set(indexes.indexes.map((index) =>
    `${index.collectionGroup}:` + index.fields.map((field) =>
      `${field.fieldPath}:${field.order}`).join(",")));
  for (const required of [
    "orders:user.userId:ASCENDING,createdAt:DESCENDING",
    "orders:pharmacy.pharmacyId:ASCENDING,createdAt:DESCENDING",
    "chats:userId:ASCENDING,lastMessageTime:DESCENDING",
    "chats:pharmacyId:ASCENDING,lastMessageTime:DESCENDING",
    "notifications:isDeleted:ASCENDING,type:ASCENDING,createdAt:DESCENDING",
    "sales:employeeId:ASCENDING,isDeleted:ASCENDING,saleDate:DESCENDING",
    "sales:isDeleted:ASCENDING,status:ASCENDING,saleDate:DESCENDING",
    "sales:isDeleted:ASCENDING,saleDate:DESCENDING",
  ]) {
    assert.equal(indexKeys.has(required), true, `missing client query index ${required}`);
  }
  assert.equal(config.emulators.auth.host, "127.0.0.1");
  assert.equal(config.emulators.auth.port, 9099);
  assert.equal(config.emulators.firestore.port, 8080);
  assert.equal(config.emulators.functions.port, 5001);
  assert.equal(config.emulators.storage.port, 9199);
  assert.equal(config.emulators.singleProjectMode, true);
});
