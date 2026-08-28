import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_operation.dart';

class FirestoreSetOperation {
  const FirestoreSetOperation({
    required this.collection,
    required this.documentId,
    required this.data,
    this.merge = false,
  });

  final String collection;
  final String documentId;
  final Map<String, dynamic> data;
  final bool merge;
}

class FirestoreService {
  FirestoreService({
    FirebaseFirestore? firestore,
    FirebaseOperationRunner? operationRunner,
  }) : _operationRunner = operationRunner ?? FirebaseOperationRunner() {
    _firestore = firestore;
  }

  FirebaseFirestore? _firestore;
  final FirebaseOperationRunner _operationRunner;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  String? get authenticatedUserId => _operationRunner.currentUserId;

  Future<String> createDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    final document = await _operationRunner.run(
      area: 'Creating $collection document',
      operation: () => firestore.collection(collection).add(data),
    );
    return document.id;
  }

  Future<void> setDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data, {
    bool merge = false,
  }) {
    return _operationRunner.run(
      area: 'Saving $collection/$documentId',
      operation: () => firestore
          .collection(collection)
          .doc(documentId)
          .set(data, SetOptions(merge: merge)),
    );
  }

  Future<void> setDocumentsAtomically(
    List<FirestoreSetOperation> operations,
  ) async {
    final batch = firestore.batch();
    for (final operation in operations) {
      final reference = firestore
          .collection(operation.collection)
          .doc(operation.documentId);
      batch.set(reference, operation.data, SetOptions(merge: operation.merge));
    }
    await _operationRunner.run(
      area: 'Saving Firestore batch',
      operation: batch.commit,
    );
  }

  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String documentId,
    {bool requiresAuthentication = true}
  ) async {
    final snapshot = await _operationRunner.run(
      area: 'Reading $collection/$documentId',
      operation: () => firestore.collection(collection).doc(documentId).get(),
      requiresAuthentication: requiresAuthentication,
    );
    return snapshot.data();
  }

  Future<List<Map<String, dynamic>>> getDocuments(
    String collection, {
    Map<String, Object?> whereEquals = const {},
    String? orderBy,
    bool descending = true,
    int? limit,
    bool requiresAuthentication = true,
  }) async {
    Query<Map<String, dynamic>> query = firestore.collection(collection);

    for (final entry in whereEquals.entries) {
      query = query.where(entry.key, isEqualTo: entry.value);
    }

    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await _operationRunner.run(
      area: 'Listing $collection documents',
      operation: query.get,
      requiresAuthentication: requiresAuthentication,
    );
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList(growable: false);
  }

  Stream<List<Map<String, dynamic>>> watchDocuments(
    String collection, {
    Map<String, Object?> whereEquals = const {},
    String? orderBy,
    bool descending = true,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = firestore.collection(collection);

    for (final entry in whereEquals.entries) {
      query = query.where(entry.key, isEqualTo: entry.value);
    }

    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList(growable: false),
    );
  }

  Stream<Map<String, dynamic>?> watchDocument(
    String collection,
    String documentId,
  ) {
    return firestore
        .collection(collection)
        .doc(documentId)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  Future<void> updateDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) {
    return _operationRunner.run(
      area: 'Updating $collection/$documentId',
      operation: () =>
          firestore.collection(collection).doc(documentId).update(data),
    );
  }

  Future<void> deleteDocument(String collection, String documentId) {
    return _operationRunner.run(
      area: 'Deleting $collection/$documentId',
      operation: () =>
          firestore.collection(collection).doc(documentId).delete(),
    );
  }

  Future<T> runTransaction<T>({
    required String area,
    required TransactionHandler<T> handler,
  }) {
    return _operationRunner.run(
      area: area,
      operation: () => firestore.runTransaction(handler),
    );
  }

  Future<T> runAuthenticated<T>({
    required String area,
    required FirebaseOperation<T> operation,
  }) {
    return _operationRunner.run(area: area, operation: operation);
  }
}
