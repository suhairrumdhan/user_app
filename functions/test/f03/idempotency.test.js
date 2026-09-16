"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  executeIdempotentTransaction,
  payloadHash,
} = require("../../src/common/idempotency");

function fakeDb() {
  const documents = new Map();
  const ref = (path) => ({path});
  return {
    documents,
    collection: (name) => ({doc: (id) => ref(`${name}/${id}`)}),
    runTransaction: async (worker) => worker({
      get: async (documentRef) => ({
        exists: documents.has(documentRef.path),
        data: () => documents.get(documentRef.path),
      }),
      create: (documentRef, value) => {
        if (documents.has(documentRef.path)) throw new Error("already exists");
        documents.set(documentRef.path, value);
      },
    }),
  };
}

test("same operation and payload returns the exact committed result once", async () => {
  const db = fakeDb();
  let executions = 0;
  const options = {
    db,
    actorId: "user-one",
    operationId: "order:create:fixed-001",
    payload: {b: 2, a: 1},
    schemaVersion: 3,
    command: "createOrder",
    committedAt: "fixed-time",
    execute: async () => {
      executions += 1;
      return {orderId: "order-one", status: "underReview"};
    },
  };
  const first = await executeIdempotentTransaction(options);
  const retry = await executeIdempotentTransaction(options);
  assert.deepEqual(retry, first);
  assert.equal(executions, 1);
});

test("same operation with a different payload is rejected", async () => {
  const db = fakeDb();
  const base = {
    db,
    actorId: "user-one",
    operationId: "order:create:fixed-002",
    schemaVersion: 3,
    command: "createOrder",
    committedAt: "fixed-time",
    execute: async () => ({orderId: "order-two"}),
  };
  await executeIdempotentTransaction({...base, payload: {quantity: 1}});
  await assert.rejects(
    executeIdempotentTransaction({...base, payload: {quantity: 2}}),
    {code: "idempotency-conflict"},
  );
});

test("payload hash is independent from object key order", () => {
  assert.equal(payloadHash({a: 1, b: 2}), payloadHash({b: 2, a: 1}));
});
