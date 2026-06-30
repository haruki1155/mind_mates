import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore}) {
    _firestore = firestore;
  }

  FirebaseFirestore? _firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  Future<String> createDocument(
    String collection,
    Map<String, dynamic> data,
  ) async {
    final document = await firestore.collection(collection).add(data);
    return document.id;
  }

  Future<void> setDocument(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) {
    return firestore.collection(collection).doc(documentId).set(data);
  }

  Future<Map<String, dynamic>?> getDocument(
    String collection,
    String documentId,
  ) async {
    final snapshot = await firestore
        .collection(collection)
        .doc(documentId)
        .get();
    return snapshot.data();
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
    return firestore.collection(collection).doc(documentId).update(data);
  }
}
