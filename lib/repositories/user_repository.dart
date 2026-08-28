import 'package:cloud_functions/cloud_functions.dart';

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
    final authenticatedUserId = _firestoreService.authenticatedUserId;
    if (authenticatedUserId == null || authenticatedUserId != uid) {
      throw StateError(
        'A live authenticated user is required to update this profile.',
      );
    }
    return _firestoreService.updateDocument(
      FirestoreCollections.users,
      uid,
      user.toProfileUpdateJson(),
    );
  }

  Future<UserModel?> recordAppOpen(String uid) {
    return FirebaseFunctions.instanceFor(region: 'us-central1')
        .httpsCallable('recordAppOpen')
        .call<Object?>()
        .then((_) => fetchUserProfile(uid));
  }
}
