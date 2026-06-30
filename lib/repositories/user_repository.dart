import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/firestore_collections.dart';
import '../models/user_model.dart';
import '../services/firebase/firestore_service.dart';

class UserRepository {
  UserRepository({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  Future<UserModel?> fetchUserProfile(String uid) async {
    final data = await _firestoreService.getDocument(
      FirestoreCollections.users,
      uid,
    );
    if (data == null) return null;
    return UserModel.fromJson(data, id: uid);
  }

  Stream<UserModel?> watchUserProfile(String uid) {
    return _firestoreService
        .watchDocument(FirestoreCollections.users, uid)
        .map((data) => data == null ? null : UserModel.fromJson(data, id: uid));
  }

  Future<void> updateUserProfile(String uid, UserModel user) {
    return _firestoreService.updateDocument(
      FirestoreCollections.users,
      uid,
      user.toProfileUpdateJson(),
    );
  }

  Future<void> markUserActivity(String uid) {
    final now = DateTime.now();
    final todayKey =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final ref = _firestoreService.firestore
        .collection(FirestoreCollections.users)
        .doc(uid);

    return _firestoreService.firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      final lastCheckInDate = data?['lastCheckInDate']?.toString();
      final shouldIncrement = lastCheckInDate != todayKey;

      transaction.update(ref, {
        'lastActiveAt': FieldValue.serverTimestamp(),
        'lastCheckInDate': todayKey,
        'streakUpdatedAt': FieldValue.serverTimestamp(),
        if (shouldIncrement) 'dayStreak': FieldValue.increment(1),
      });
    });
  }
}
