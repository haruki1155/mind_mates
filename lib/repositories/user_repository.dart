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
}
