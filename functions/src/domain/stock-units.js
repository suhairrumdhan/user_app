"use strict";

const {OrderContractError} = require("./order-contract");

function count(value, field) {
  const number = Number(value ?? 0);
  if (!Number.isSafeInteger(number) || number < 0) {
    throw new OrderContractError("failed-precondition", `Invalid inventory ${field}.`);
  }
  return number;
}

// Piece reservations may be backed by unopened, unreserved packages. Reserving
// never changes physical stock; packages are opened only when stock is sold.
function stockUnits(data) {
  const quantity = count(data.quantity, "quantity");
  const pieceQuantity = count(data.pieceQuantity, "pieceQuantity");
  const reservedQuantity = count(data.reservedQuantity, "reservedQuantity");
  const reservedPieceQuantity = count(data.reservedPieceQuantity, "reservedPieceQuantity");
  const units = count(data.unitsPerPackage, "unitsPerPackage");
  const packagesBackingPieces = reservedPieceQuantity > pieceQuantity ?
    (units > 0 ? Math.ceil((reservedPieceQuantity - pieceQuantity) / units) : Infinity) : 0;
  const availablePackages = quantity - reservedQuantity - packagesBackingPieces;
  const availablePieces = (quantity - reservedQuantity) * units +
    pieceQuantity - reservedPieceQuantity;
  if (availablePackages < 0 || availablePieces < 0 ||
      !Number.isSafeInteger(availablePieces)) {
    throw new OrderContractError("failed-precondition", "Inventory reservations exceed physical stock.");
  }
  return {quantity, pieceQuantity, reservedQuantity, reservedPieceQuantity,
    units, availablePackages, availablePieces};
}

function reserveUnits(data, packages, pieces) {
  const stock = stockUnits(data);
  count(packages, "requested packages");
  count(pieces, "requested pieces");
  if (packages > stock.availablePackages || pieces > stock.availablePieces - packages * stock.units) {
    throw new OrderContractError("failed-precondition", "Medicine has insufficient stock.");
  }
  return {
    reservedQuantity: stock.reservedQuantity + packages,
    reservedPieceQuantity: stock.reservedPieceQuantity + pieces,
  };
}

function consumeUnits(data, packages, pieces) {
  const stock = stockUnits(data);
  count(packages, "consumed packages");
  count(pieces, "consumed pieces");
  if (stock.reservedQuantity < packages || stock.reservedPieceQuantity < pieces) {
    throw new OrderContractError("failed-precondition", "Reserved stock is no longer valid.");
  }
  const openedPackages = Math.max(0, pieces - stock.pieceQuantity) > 0 ?
    Math.ceil((pieces - stock.pieceQuantity) / stock.units) : 0;
  const update = {
    quantity: stock.quantity - packages - openedPackages,
    pieceQuantity: stock.pieceQuantity + openedPackages * stock.units - pieces,
    reservedQuantity: stock.reservedQuantity - packages,
    reservedPieceQuantity: stock.reservedPieceQuantity - pieces,
  };
  stockUnits({...data, ...update});
  return update;
}

module.exports = {stockUnits, reserveUnits, consumeUnits};
