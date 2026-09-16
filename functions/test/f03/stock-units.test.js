"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {stockUnits, reserveUnits, consumeUnits} = require("../../src/domain/stock-units");

test("piece acceptance can reserve unopened packages without selling them", () => {
  const initial = {quantity: 486, pieceQuantity: 1, reservedPieceQuantity: 1, unitsPerPackage: 10};
  const reserved = {...initial, ...reserveUnits(initial, 0, 1)};
  assert.equal(reserved.quantity, 486);
  assert.equal(reserved.pieceQuantity, 1);
  assert.equal(reserved.reservedPieceQuantity, 2);
  assert.equal(stockUnits(reserved).availablePackages, 485);
  const sold = {...reserved, ...consumeUnits(reserved, 0, 1)};
  assert.equal(sold.quantity, 486);
  assert.equal(sold.pieceQuantity, 0);
  assert.equal(sold.reservedPieceQuantity, 1);
  const last = consumeUnits(sold, 0, 1);
  assert.equal(last.quantity, 485);
  assert.equal(last.pieceQuantity, 9);
});

test("piece and package demand compete for the same physical stock", () => {
  const initial = {quantity: 2, pieceQuantity: 0, unitsPerPackage: 10};
  const reserved = {...initial, ...reserveUnits(initial, 1, 1)};
  assert.equal(stockUnits(reserved).availablePackages, 0);
  assert.equal(stockUnits(reserved).availablePieces, 9);
  assert.throws(() => reserveUnits(reserved, 1, 0), /insufficient stock/);
  assert.throws(() => reserveUnits(initial, 2, 1), /insufficient stock/);
  const sold = consumeUnits(reserved, 1, 1);
  assert.deepEqual(sold, {quantity: 0, pieceQuantity: 9, reservedQuantity: 0, reservedPieceQuantity: 0});
});

test("piece sale never opens a package allocated to another order", () => {
  const initial = {quantity: 2, pieceQuantity: 0, unitsPerPackage: 10, reservedQuantity: 1};
  const reserved = {...initial, ...reserveUnits(initial, 0, 10)};
  assert.throws(() => reserveUnits(reserved, 0, 1), /insufficient stock/);
  assert.deepEqual(consumeUnits(reserved, 0, 10), {
    quantity: 1, pieceQuantity: 0, reservedQuantity: 1, reservedPieceQuantity: 0,
  });
});

test("malformed or oversubscribed inventory is rejected, not treated as available", () => {
  for (const quantity of [-1, 1.5, NaN, Infinity, "bad"]) {
    assert.throws(() => stockUnits({quantity}), /Invalid inventory/);
  }
  assert.throws(() => stockUnits({quantity: 1, reservedQuantity: 2}), /exceed/);
  assert.throws(() => stockUnits({quantity: 1, reservedPieceQuantity: 1}), /exceed/);
});

test("every accepted small mixed reservation conserves stock through consumption", () => {
  for (let packs = 0; packs < 4; packs++) {
    for (let loose = 0; loose < 4; loose++) {
      for (let requestedPacks = 0; requestedPacks <= packs; requestedPacks++) {
        for (let requestedPieces = 0; requestedPieces <= (packs - requestedPacks) * 3 + loose; requestedPieces++) {
          const initial = {quantity: packs, pieceQuantity: loose, unitsPerPackage: 3};
          const reserved = {...initial, ...reserveUnits(initial, requestedPacks, requestedPieces)};
          const final = consumeUnits(reserved, requestedPacks, requestedPieces);
          assert.equal(final.quantity * 3 + final.pieceQuantity,
            packs * 3 + loose - requestedPacks * 3 - requestedPieces);
          assert.equal(final.reservedQuantity + final.reservedPieceQuantity, 0);
        }
      }
    }
  }
});
