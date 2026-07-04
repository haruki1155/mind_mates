import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../database/firestore_collections.dart';
import '../features/secret_chat/domain/secret_chat_safety_validator.dart';
import '../models/secret_chat_model.dart';
import '../services/firebase/firestore_service.dart';
import 'user_repository.dart';

class SecretChatAuthException implements Exception {
  const SecretChatAuthException();

  @override
  String toString() => 'Please sign in to use Secret Chat.';
}

class SecretChatRepository {
  SecretChatRepository({
    FirestoreService? firestoreService,
    UserRepository? userRepository,
    this.firebaseAuth,
  }) : _firestoreService = firestoreService ?? FirestoreService(),
       _userRepository = userRepository ?? UserRepository();

  final FirestoreService _firestoreService;
  final UserRepository _userRepository;
  final FirebaseAuth? firebaseAuth;

  FirebaseAuth get _auth => firebaseAuth ?? FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;
  bool get hasSignedInUser => currentUserId != null;

  String _requireUserId() {
    final uid = currentUserId;
    if (uid == null || uid.trim().isEmpty) {
      throw const SecretChatAuthException();
    }
    return uid;
  }

  Future<List<SecretChatModel>> fetchPosts() async {
    final uid = _requireUserId();
    final docs = await _firestoreService.getDocuments(
      FirestoreCollections.secretChats,
      whereEquals: {'moderationStatus': 'active'},
      orderBy: 'createdAt',
      limit: 50,
    );
    final interactions = await _fetchInteractions(uid);
    return docs
        .map((doc) {
          final id = doc['id']?.toString() ?? '';
          final interaction = interactions[id];
          return SecretChatModel.fromJson(
            doc,
            id: id,
            currentUserId: uid,
            isLiked: interaction?['liked'] == true,
            isSaved: interaction?['saved'] == true,
          );
        })
        .toList(growable: false);
  }

  Future<SecretChatModel> createPost({
    required String message,
    required String category,
    List<String> safetyLabels = const [],
  }) async {
    final uid = _requireUserId();
    final createdAt = DateTime.now();
    final id = await _firestoreService
        .createDocument(FirestoreCollections.secretChats, {
          'authorId': uid,
          'message': message.trim(),
          'category': category,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'likeCount': 0,
          'commentCount': 0,
          'moderationStatus': 'active',
          'safetyLabels': safetyLabels,
          'isAnonymous': true,
        });
    await _tryRecordActivity(uid, UserActivityType.secretChatPost);
    return SecretChatModel(
      id: id,
      message: message.trim(),
      category: category,
      createdAt: createdAt,
      likeCount: 0,
      commentCount: 0,
      authorId: uid,
      safetyLabels: safetyLabels,
      isAnonymous: true,
      isMine: true,
    );
  }

  Future<SecretChatModel> toggleLike(SecretChatModel post) async {
    final uid = _requireUserId();
    final nextLiked = !post.isLiked;
    final interactionId = _interactionId(uid, post.id);
    final postRef = _firestoreService.firestore
        .collection(FirestoreCollections.secretChats)
        .doc(post.id);
    final interactionRef = _firestoreService.firestore
        .collection(FirestoreCollections.secretChatInteractions)
        .doc(interactionId);

    await _firestoreService.firestore.runTransaction((transaction) async {
      final interactionSnapshot = await transaction.get(interactionRef);
      final wasLiked = interactionSnapshot.data()?['liked'] == true;
      if (wasLiked == nextLiked) return;

      transaction.set(interactionRef, {
        'userId': uid,
        'postId': post.id,
        'liked': nextLiked,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.update(postRef, {
        'likeCount': FieldValue.increment(nextLiked ? 1 : -1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    await _tryRecordActivity(uid, UserActivityType.secretChatInteraction);

    return post.copyWith(
      isLiked: nextLiked,
      likeCount: (post.likeCount + (nextLiked ? 1 : -1)).clamp(0, 1 << 31),
    );
  }

  Future<SecretChatModel> toggleSave(SecretChatModel post) async {
    final uid = _requireUserId();
    final nextSaved = !post.isSaved;
    await _firestoreService.setDocument(
      FirestoreCollections.secretChatInteractions,
      _interactionId(uid, post.id),
      {
        'userId': uid,
        'postId': post.id,
        'saved': nextSaved,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      merge: true,
    );
    await _tryRecordActivity(uid, UserActivityType.secretChatInteraction);
    return post.copyWith(isSaved: nextSaved);
  }

  Future<List<SecretChatComment>> fetchComments(String postId) async {
    _requireUserId();
    final docs = await _firestoreService.getDocuments(
      FirestoreCollections.secretChatComments,
      whereEquals: {'postId': postId, 'moderationStatus': 'active'},
      orderBy: 'createdAt',
      descending: false,
    );
    return docs
        .map(
          (doc) => SecretChatComment.fromJson(doc, id: doc['id']?.toString()),
        )
        .toList(growable: false);
  }

  Future<SecretChatComment> addComment({
    required String postId,
    required String message,
    List<String> safetyLabels = const [],
  }) async {
    final uid = _requireUserId();
    final createdAt = DateTime.now();
    final postRef = _firestoreService.firestore
        .collection(FirestoreCollections.secretChats)
        .doc(postId);
    final commentRef = _firestoreService.firestore
        .collection(FirestoreCollections.secretChatComments)
        .doc();

    await _firestoreService.firestore.runTransaction((transaction) async {
      transaction.set(commentRef, {
        'postId': postId,
        'authorId': uid,
        'message': message.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'moderationStatus': 'active',
        'safetyLabels': safetyLabels,
        'isAnonymous': true,
      });
      transaction.update(postRef, {
        'commentCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    await _tryRecordActivity(uid, UserActivityType.secretChatComment);

    return SecretChatComment(
      id: commentRef.id,
      postId: postId,
      authorId: uid,
      message: message.trim(),
      createdAt: createdAt,
      moderationStatus: 'active',
      safetyLabels: safetyLabels,
      isAnonymous: true,
    );
  }

  Future<Map<String, Map<String, dynamic>>> _fetchInteractions(
    String uid,
  ) async {
    final docs = await _firestoreService.getDocuments(
      FirestoreCollections.secretChatInteractions,
      whereEquals: {'userId': uid},
      limit: 200,
    );
    return {
      for (final doc in docs)
        if ((doc['postId']?.toString() ?? '').isNotEmpty)
          doc['postId'].toString(): doc,
    };
  }

  String _interactionId(String uid, String postId) => '${uid}_$postId';

  Future<void> _tryRecordActivity(String userId, UserActivityType type) async {
    try {
      await _userRepository.recordActivity(userId, type);
    } catch (_) {
      // Secret Chat should remain usable even if activity sync is unavailable.
    }
  }
}

extension SecretChatValidationCodeLabel on SecretChatValidationCode {
  String get storedValue => name;
}
