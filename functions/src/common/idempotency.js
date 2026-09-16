"use strict";

const crypto = require("node:crypto");

const OPERATION_SCHEMA_VERSION = 1;

class IdempotencyConflictError extends Error {
  constructor(operationId) {
    super(`operationId ${operationId} was already used with a different payload.`);
    this.name = "IdempotencyConflictError";
    this.code = "idempotency-conflict";
    this.operationId = operationId;
  }
}

function normalizeJson(value) {
  if (value === undefined) return null;
  if (value === null || typeof value !== "object") return value;
  if (Array.isArray(value)) return value.map(normalizeJson);
  return Object.fromEntries(
    Object.keys(value)
      .sort()
      .map((key) => [key, normalizeJson(value[key])]),
  );
}

function stableStringify(value) {
  return JSON.stringify(normalizeJson(value));
}

function payloadHash(payload) {
  return crypto.createHash("sha256").update(stableStringify(payload)).digest("hex");
}

function validateOperationId(value) {
  const operationId = String(value ?? "").trim();
  if (!/^[A-Za-z0-9][A-Za-z0-9._:-]{7,127}$/.test(operationId)) {
    throw new Error("operationId must contain 8-128 safe characters.");
  }
  return operationId;
}

function operationDocumentId(actorId, operationId) {
  return crypto
    .createHash("sha256")
    .update(`${actorId}:${validateOperationId(operationId)}`)
    .digest("hex");
}

async function executeIdempotentTransaction(options) {
  const operationId = validateOperationId(options.operationId);
  const hash = payloadHash(options.payload);
  if (options.declaredPayloadHash && options.declaredPayloadHash !== hash) {
    throw new IdempotencyConflictError(operationId);
  }
  const operationRef = options.db
    .collection("orderOperations")
    .doc(operationDocumentId(options.actorId, operationId));

  return options.db.runTransaction(async (transaction) => {
    const existing = await transaction.get(operationRef);
    if (existing.exists) {
      const saved = existing.data() || {};
      if (saved.payloadHash !== hash) {
        throw new IdempotencyConflictError(operationId);
      }
      if (!saved.result) {
        throw new Error(`Operation ${operationId} has no committed result.`);
      }
      return saved.result;
    }

    const domainResult = await options.execute({
      transaction,
      operationRef,
      operationId,
      payloadHash: hash,
    });
    const result = Object.freeze({
      schemaVersion: options.schemaVersion,
      operationId,
      payloadHash: hash,
      result: domainResult,
    });
    transaction.create(operationRef, {
      schemaVersion: OPERATION_SCHEMA_VERSION,
      commandSchemaVersion: options.schemaVersion,
      operationId,
      payloadHash: hash,
      actorId: options.actorId,
      command: options.command,
      result,
      committedAt: options.committedAt,
    });
    return result;
  });
}

module.exports = {
  IdempotencyConflictError,
  OPERATION_SCHEMA_VERSION,
  executeIdempotentTransaction,
  normalizeJson,
  operationDocumentId,
  payloadHash,
  stableStringify,
  validateOperationId,
};
