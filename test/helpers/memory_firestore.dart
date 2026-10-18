// Firestore SDK interfaces are implemented only by this isolated test double.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';

/// A small optimistic transaction test double, not a Firebase/rules emulator.
/// No reads/writes leave memory. Tests exercise the production callback and
/// can force a conflicting external write, an aborted commit or a lost reply.
class MemoryFirestore implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{};
  final versions = <String, int>{};
  void Function()? beforeCommit;
  bool rejectCommit = false;
  bool loseReply = false;
  int commits = 0;

  void seed(String path, Map<String, dynamic> value) {
    documents[path] = Map.from(value);
    versions[path] = (versions[path] ?? 0) + 1;
  }

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final tx = _Transaction(this);
      final result = await handler(tx);
      final hook = beforeCommit;
      beforeCommit = null;
      hook?.call();
      if (tx.reads.entries.any((e) => (versions[e.key] ?? 0) != e.value)) {
        continue;
      }
      if (rejectCommit) throw StateError('Injected rejected commit');
      for (final write in tx.writes.entries) {
        seed(write.key, write.value);
      }
      for (final path in tx.deletes) {
        documents.remove(path);
        versions[path] = (versions[path] ?? 0) + 1;
      }
      if (tx.writes.isNotEmpty) commits++;
      if (loseReply) {
        loseReply = false;
        throw StateError('Injected lost reply');
      }
      return result;
    }
    throw StateError('Transaction attempts exhausted');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.db, this.path);
  final MemoryFirestore db;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    if (path == null) throw StateError('Tests require deterministic IDs');
    return _Reference(db, '${this.path}/$path');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reference implements DocumentReference<Map<String, dynamic>> {
  _Reference(this.db, this.path);
  final MemoryFirestore db;
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Collection(db, '$path/$collectionPath');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot<T> implements DocumentSnapshot<T> {
  _Snapshot(this.reference, this.value);
  @override
  final DocumentReference<T> reference;
  final T? value;
  @override
  bool get exists => value != null;
  @override
  String get id => reference.id;
  @override
  T? data() => value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Transaction implements Transaction {
  _Transaction(this.db);
  final MemoryFirestore db;
  final reads = <String, int>{};
  final writes = <String, Map<String, dynamic>>{};
  final deletes = <String>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> ref,
  ) async {
    if (writes.isNotEmpty) throw StateError('Read after write');
    reads[ref.path] = db.versions[ref.path] ?? 0;
    final value = db.documents[ref.path];
    return _Snapshot<T>(
      ref,
      value == null ? null : Map<String, dynamic>.from(value) as T,
    );
  }

  @override
  Transaction delete(DocumentReference ref) {
    deletes.add(ref.path);
    return this;
  }

  @override
  Transaction set<T>(DocumentReference<T> ref, T data, [SetOptions? options]) {
    if (options != null) throw StateError('Merge options not implemented');
    writes[ref.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }

  @override
  Transaction update(DocumentReference ref, Map<Object, Object?> data) {
    final previous = writes[ref.path] ?? db.documents[ref.path];
    if (previous == null) throw StateError('Update of missing document');
    writes[ref.path] = {...previous, ...Map<String, dynamic>.from(data)};
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
