"use strict";

function cloneValue(value) {
  if (Array.isArray(value)) return value.map(cloneValue);
  if (!value || typeof value !== "object") return value;
  if (Object.getPrototypeOf(value) !== Object.prototype) return value;
  return Object.fromEntries(
    Object.entries(value).map(([key, item]) => [key, cloneValue(item)]),
  );
}

class FakeDocumentReference {
  constructor(database, path) {
    this.database = database;
    this.path = path;
    this.id = path.split("/").at(-1);
  }

  collection(name) {
    return new FakeCollectionReference(this.database, `${this.path}/${name}`);
  }

  async get() {
    return snapshot(this.database.documents, this);
  }
}

class FakeCollectionReference {
  constructor(database, path) {
    this.database = database;
    this.path = path;
    this.filters = [];
  }

  where(field, operator, value) {
    if (operator !== "==") throw new Error("Unsupported fake query operator");
    const query = new FakeCollectionReference(this.database, this.path);
    query.filters = [...this.filters, {field, value}];
    return query;
  }

  limit(value) {
    const query = new FakeCollectionReference(this.database, this.path);
    query.filters = [...this.filters];
    query.maximum = value;
    return query;
  }

  async get() {
    const prefix = `${this.path}/`;
    let docs = [...this.database.documents.keys()].filter((path) =>
      path.startsWith(prefix) && !path.slice(prefix.length).includes("/") &&
      this.filters.every(({field, value}) => this.database.documents.get(path)[field] === value));
    if (Number.isInteger(this.maximum)) docs = docs.slice(0, this.maximum);
    const snapshots = docs.map((path) => ({id: path.slice(prefix.length),
      exists: true, data: () => cloneValue(this.database.documents.get(path))}));
    return {docs: snapshots, empty: snapshots.length === 0, size: snapshots.length};
  }

  doc(id) {
    const documentId = id || `auto-${this.database.nextAutoId++}`;
    return new FakeDocumentReference(
      this.database,
      `${this.path}/${documentId}`,
    );
  }
}

function snapshot(documents, reference) {
  const exists = documents.has(reference.path);
  return {
    exists,
    data: () => exists ? cloneValue(documents.get(reference.path)) : undefined,
  };
}

function applyUpdate(previous, value) {
  const next = {...previous};
  for (const [key, item] of Object.entries(value)) {
    if (item?.constructor?.name === "DeleteTransform") delete next[key];
    else next[key] = cloneValue(item);
  }
  return next;
}

class FakeFirestore {
  constructor(seed = {}) {
    this.documents = new Map(
      Object.entries(seed).map(([path, value]) => [path, cloneValue(value)]),
    );
    this.nextAutoId = 1;
  }

  collection(name) {
    return new FakeCollectionReference(this, name);
  }

  read(path) {
    return cloneValue(this.documents.get(path));
  }

  write(path, value) {
    this.documents.set(path, cloneValue(value));
  }

  delete(path) {
    this.documents.delete(path);
  }

  paths(prefix) {
    return [...this.documents.keys()].filter((path) => path.startsWith(prefix));
  }

  async runTransaction(worker) {
    const working = new Map(
      [...this.documents.entries()]
        .map(([path, value]) => [path, cloneValue(value)]),
    );
    let hasWritten = false;
    const transaction = {
      get: async (reference) => {
        if (hasWritten) throw new Error("Firestore transactions require all reads before writes.");
        if (reference instanceof FakeCollectionReference) {
          const prefix = `${reference.path}/`;
          let paths = [...working.keys()].filter((path) => path.startsWith(prefix) &&
            !path.slice(prefix.length).includes("/") && reference.filters.every(({field, value}) =>
            working.get(path)[field] === value));
          if (Number.isInteger(reference.maximum)) paths = paths.slice(0, reference.maximum);
          const docs = paths.map((path) => ({
            id: path.slice(prefix.length),
            exists: true,
            data: () => cloneValue(working.get(path)),
          }));
          return {docs, empty: docs.length === 0, size: docs.length};
        }
        return snapshot(working, reference);
      },
      create: (reference, value) => {
        hasWritten = true;
        if (working.has(reference.path)) {
          throw new Error(`Document already exists: ${reference.path}`);
        }
        working.set(reference.path, cloneValue(value));
      },
      delete: (reference) => {
        hasWritten = true;
        working.delete(reference.path);
      },
      set: (reference, value, options = {}) => {
        hasWritten = true;
        const previous = working.get(reference.path) || {};
        const next = options.merge ? applyUpdate(previous, value) : value;
        working.set(reference.path, cloneValue(next));
      },
      update: (reference, value) => {
        hasWritten = true;
        if (!working.has(reference.path)) {
          throw new Error(`Document does not exist: ${reference.path}`);
        }
        working.set(reference.path, applyUpdate(working.get(reference.path), value));
      },
    };
    const result = await worker(transaction);
    this.documents = working;
    return result;
  }
}

module.exports = {FakeFirestore};
