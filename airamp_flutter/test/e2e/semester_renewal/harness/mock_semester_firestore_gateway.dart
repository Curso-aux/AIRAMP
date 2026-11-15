// Robust In-Memory Firestore Gateway for Standalone CI E2E Testing
// Emulates Cloud Firestore collections, subcollections, documents, and chunked batch writes.
// Strictly enforces Firestore's 500-operation limit per WriteBatch.

import 'dart:convert';

enum BatchOpType { set, update, delete }

class FirestoreBatchOperation {
  final BatchOpType type;
  final String collection;
  final String id;
  final Map<String, dynamic>? data;

  FirestoreBatchOperation.set(this.collection, this.id, Map<String, dynamic> this.data)
      : type = BatchOpType.set;

  FirestoreBatchOperation.update(this.collection, this.id, Map<String, dynamic> this.data)
      : type = BatchOpType.update;

  FirestoreBatchOperation.delete(this.collection, this.id)
      : type = BatchOpType.delete,
        data = null;
}

abstract class ISemesterFirestoreGateway {
  Future<List<Map<String, dynamic>>> getCollection(String path);
  Future<Map<String, dynamic>?> getDocument(String collection, String id);
  Future<void> setDocument(String collection, String id, Map<String, dynamic> data);
  Future<void> updateDocument(String collection, String id, Map<String, dynamic> partialData);
  Future<void> deleteDocument(String collection, String id);
  Future<void> commitBatch(List<FirestoreBatchOperation> operations);
  Future<int> countCollection(String path);
  Future<void> clearAll();
}

class MockSemesterFirestoreGateway implements ISemesterFirestoreGateway {
  // collectionPath -> (docId -> docData)
  final Map<String, Map<String, Map<String, dynamic>>> _store = {};

  int totalBatchesCommitted = 0;
  int maxBatchSizeSeen = 0;
  final List<int> batchSizesHistory = [];

  Map<String, dynamic> _deepClone(Map<String, dynamic> original) {
    return jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> getCollection(String path) async {
    final col = _store[path];
    if (col == null) return [];
    return col.values.map((doc) => _deepClone(doc)).toList();
  }

  @override
  Future<Map<String, dynamic>?> getDocument(String collection, String id) async {
    final doc = _store[collection]?[id];
    if (doc == null) return null;
    return _deepClone(doc);
  }

  @override
  Future<void> setDocument(String collection, String id, Map<String, dynamic> data) async {
    _store.putIfAbsent(collection, () => {})[id] = _deepClone(data);
  }

  @override
  Future<void> updateDocument(String collection, String id, Map<String, dynamic> partialData) async {
    final existing = _store[collection]?[id];
    if (existing == null) {
      throw StateError('Cannot update non-existent document $collection/$id');
    }
    existing.addAll(_deepClone(partialData));
  }

  @override
  Future<void> deleteDocument(String collection, String id) async {
    _store[collection]?.remove(id);
  }

  @override
  Future<void> commitBatch(List<FirestoreBatchOperation> operations) async {
    // Firestore Hard Batch Limit Guard
    if (operations.length > 500) {
      throw StateError(
        'Firestore batch limit exceeded: max 500 operations per WriteBatch, '
        'attempted ${operations.length} operations',
      );
    }

    totalBatchesCommitted++;
    batchSizesHistory.add(operations.length);
    if (operations.length > maxBatchSizeSeen) {
      maxBatchSizeSeen = operations.length;
    }

    // Atomic execution simulation
    final backup = <String, Map<String, Map<String, dynamic>>>{};
    for (final colEntry in _store.entries) {
      backup[colEntry.key] = {};
      for (final docEntry in colEntry.value.entries) {
        backup[colEntry.key]![docEntry.key] = _deepClone(docEntry.value);
      }
    }

    try {
      for (final op in operations) {
        switch (op.type) {
          case BatchOpType.set:
            _store.putIfAbsent(op.collection, () => {})[op.id] = _deepClone(op.data!);
            break;
          case BatchOpType.update:
            final doc = _store[op.collection]?[op.id];
            if (doc != null) {
              doc.addAll(_deepClone(op.data!));
            }
            break;
          case BatchOpType.delete:
            _store[op.collection]?.remove(op.id);
            break;
        }
      }
    } catch (e) {
      // Rollback on any failure
      _store.clear();
      _store.addAll(backup);
      rethrow;
    }
  }

  @override
  Future<int> countCollection(String path) async {
    return _store[path]?.length ?? 0;
  }

  @override
  Future<void> clearAll() async {
    _store.clear();
    totalBatchesCommitted = 0;
    maxBatchSizeSeen = 0;
    batchSizesHistory.clear();
  }
}
