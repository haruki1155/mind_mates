import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/repositories/secret_chat_repository.dart';
import 'package:mind_mates/services/firebase/firestore_service.dart';

void main() {
  test(
    'recent posts query is owner-scoped, active, newest-first, and limited',
    () async {
      final firestore = _CapturingFirestoreService();
      final repository = _TestSecretChatRepository(firestore);

      final posts = await repository.fetchRecentPosts();

      expect(posts, isEmpty);
      expect(firestore.collection, 'secret_chats');
      expect(firestore.whereEquals, {
        'authorId': 'user_1',
        'moderationStatus': 'active',
      });
      expect(firestore.orderBy, 'createdAt');
      expect(firestore.descending, isTrue);
      expect(firestore.limit, 3);
    },
  );
}

class _TestSecretChatRepository extends SecretChatRepository {
  _TestSecretChatRepository(FirestoreService firestoreService)
    : super(firestoreService: firestoreService);

  @override
  String? get currentUserId => 'user_1';
}

class _CapturingFirestoreService extends FirestoreService {
  String? collection;
  Map<String, Object?>? whereEquals;
  String? orderBy;
  bool? descending;
  int? limit;

  @override
  Future<List<Map<String, dynamic>>> getDocuments(
    String collection, {
    Map<String, Object?> whereEquals = const {},
    String? orderBy,
    bool descending = true,
    int? limit,
  }) async {
    this.collection = collection;
    this.whereEquals = whereEquals;
    this.orderBy = orderBy;
    this.descending = descending;
    this.limit = limit;
    return const [];
  }
}
