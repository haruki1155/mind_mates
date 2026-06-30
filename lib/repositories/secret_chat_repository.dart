import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../database/firestore_collections.dart';
import '../models/secret_chat_model.dart';
import '../services/firebase/firestore_service.dart';

class SecretChatRepository {
  SecretChatRepository({
    FirestoreService? firestoreService,
    FirebaseAuth? firebaseAuth,
  }) : _firestoreService = firestoreService ?? FirestoreService(),
       _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance {
    _posts = List<SecretChatModel>.from(_mockPosts);
    _comments = {
      for (final post in _posts)
        post.id: [
          SecretChatComment(
            id: '${post.id}_c1',
            postId: post.id,
            message: 'Thank you for sharing this here.',
            createdAt: DateTime(2026, 4, 23, 11, 15),
          ),
          SecretChatComment(
            id: '${post.id}_c2',
            postId: post.id,
            message: 'You are not alone in feeling this.',
            createdAt: DateTime(2026, 4, 23, 11, 18),
          ),
        ],
    };
  }

  final FirestoreService _firestoreService;
  final FirebaseAuth _firebaseAuth;
  late List<SecretChatModel> _posts;
  late Map<String, List<SecretChatComment>> _comments;

  String get _currentUserId => _firebaseAuth.currentUser?.uid ?? 'guest';

  Future<List<SecretChatModel>> fetchPosts() async {
    try {
      final docs = await _firestoreService.getDocuments(
        FirestoreCollections.secretChats,
        whereEquals: {'moderationStatus': 'active'},
        orderBy: 'createdAt',
        limit: 50,
      );
      final posts = docs
          .map(
            (doc) => SecretChatModel.fromJson(
              doc,
              id: doc['id']?.toString(),
              currentUserId: _currentUserId,
            ),
          )
          .toList(growable: false);
      _posts = posts.isEmpty ? _posts : posts;
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    return List<SecretChatModel>.from(_posts);
  }

  Future<SecretChatModel> createPost({
    required String message,
    required String category,
  }) async {
    final post = SecretChatModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      message: message,
      category: category,
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      authorId: _currentUserId,
      isMine: true,
    );
    try {
      final id = await _firestoreService
          .createDocument(FirestoreCollections.secretChats, {
            'authorId': _currentUserId,
            'message': message.trim(),
            'category': category,
            'createdAt': FieldValue.serverTimestamp(),
            'likeCount': 0,
            'commentCount': 0,
            'moderationStatus': 'active',
          });
      final saved = post.copyWith(id: id);
      _posts = [saved, ..._posts];
      _comments[saved.id] = [];
      return saved;
    } catch (_) {
      // Keep the current local behavior when Firestore is not available yet.
    }
    _posts = [post, ..._posts];
    _comments[post.id] = [];
    return post;
  }

  Future<SecretChatModel> toggleLike(String postId) async {
    final updated = await _updatePost(postId, (post) {
      final nextLiked = !post.isLiked;
      return post.copyWith(
        isLiked: nextLiked,
        likeCount: post.likeCount + (nextLiked ? 1 : -1),
      );
    });
    await _syncInteraction(
      postId: postId,
      field: 'liked',
      value: updated.isLiked,
    );
    return updated;
  }

  Future<SecretChatModel> toggleSave(String postId) async {
    final updated = await _updatePost(
      postId,
      (post) => post.copyWith(isSaved: !post.isSaved),
    );
    await _syncInteraction(
      postId: postId,
      field: 'saved',
      value: updated.isSaved,
    );
    return updated;
  }

  Future<List<SecretChatComment>> fetchComments(String postId) async {
    try {
      final docs = await _firestoreService.getDocuments(
        FirestoreCollections.secretChatComments,
        whereEquals: {'postId': postId},
        orderBy: 'createdAt',
        descending: false,
      );
      _comments[postId] = docs
          .map(
            (doc) => SecretChatComment.fromJson(doc, id: doc['id']?.toString()),
          )
          .toList(growable: false);
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return List<SecretChatComment>.from(_comments[postId] ?? const []);
  }

  Future<SecretChatComment> addComment({
    required String postId,
    required String message,
  }) async {
    final comment = SecretChatComment(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      postId: postId,
      message: message,
      createdAt: DateTime.now(),
    );
    try {
      final id = await _firestoreService
          .createDocument(FirestoreCollections.secretChatComments, {
            'postId': postId,
            'authorId': _currentUserId,
            'message': message.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });
      await _firestoreService.updateDocument(
        FirestoreCollections.secretChats,
        postId,
        {'commentCount': FieldValue.increment(1)},
      );
      final saved = SecretChatComment(
        id: id,
        postId: postId,
        message: message,
        createdAt: DateTime.now(),
      );
      _comments[postId] = [saved, ...?_comments[postId]];
      await _updatePost(
        postId,
        (post) => post.copyWith(commentCount: post.commentCount + 1),
      );
      return saved;
    } catch (_) {
      // Fall back to local comments while backend rules are settling.
    }
    _comments[postId] = [comment, ...?_comments[postId]];
    await _updatePost(
      postId,
      (post) => post.copyWith(commentCount: post.commentCount + 1),
    );
    return comment;
  }

  Future<void> _syncInteraction({
    required String postId,
    required String field,
    required bool value,
  }) async {
    try {
      final interactionId = '${_currentUserId}_$postId';
      await _firestoreService.setDocument(
        FirestoreCollections.secretChatInteractions,
        interactionId,
        {
          'userId': _currentUserId,
          'postId': postId,
          field: value,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        merge: true,
      );
      if (field == 'liked') {
        await _firestoreService.updateDocument(
          FirestoreCollections.secretChats,
          postId,
          {'likeCount': FieldValue.increment(value ? 1 : -1)},
        );
      }
    } catch (_) {}
  }

  Future<SecretChatModel> _updatePost(
    String postId,
    SecretChatModel Function(SecretChatModel post) update,
  ) async {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index == -1) {
      throw StateError('Post not found');
    }
    final updated = update(_posts[index]);
    _posts[index] = updated;
    return updated;
  }

  static final _mockPosts = <SecretChatModel>[
    SecretChatModel(
      id: 'post_1',
      message:
          'The constant comparison on social media is draining. Everyone seems to have it all figured out except me.',
      createdAt: DateTime(2026, 4, 23, 9, 10),
      category: 'Mental Health',
      likeCount: 70,
      commentCount: 34,
      isLiked: true,
    ),
    SecretChatModel(
      id: 'post_2',
      message:
          "Just wanted to say that I'm grateful for this app. Having a private space to express myself without judgment means everything.",
      createdAt: DateTime(2026, 4, 23, 9, 35),
      category: 'Gratitude',
      likeCount: 100,
      commentCount: 55,
      isLiked: true,
      isSaved: true,
    ),
    SecretChatModel(
      id: 'post_3',
      message:
          "My parents don't understand why I'm stressed. They think college should be 'the best years of my life' but they don't see the pressure.",
      createdAt: DateTime(2026, 4, 23, 10, 5),
      category: 'Mental Health',
      likeCount: 98,
      commentCount: 34,
    ),
    SecretChatModel(
      id: 'post_4',
      message:
          "Some days I wake up and the anxiety is already there, before I even start my day. Breathing exercises help, but it's exhausting.",
      createdAt: DateTime(2026, 4, 23, 10, 25),
      category: 'Anxiety',
      likeCount: 56,
      commentCount: 31,
    ),
    SecretChatModel(
      id: 'post_5',
      message:
          "I completed my project presentation today! It wasn't perfect but I did it and I'm proud of myself.",
      createdAt: DateTime(2026, 4, 23, 11),
      category: 'Mental Health',
      likeCount: 34,
      commentCount: 52,
      isMine: true,
    ),
    SecretChatModel(
      id: 'post_6',
      message:
          'Feeling disconnected from friends lately. I miss the times when we could just hang out without worrying about assignments.',
      createdAt: DateTime(2026, 4, 23, 11, 15),
      category: 'Mental Health',
      likeCount: 34,
      commentCount: 52,
    ),
    SecretChatModel(
      id: 'post_7',
      message:
          "Today I realized that it's okay to not be productive all the time. Rest is productive too.",
      createdAt: DateTime(2026, 4, 23, 12, 20),
      category: 'Mental Health',
      likeCount: 70,
      commentCount: 34,
      isLiked: true,
    ),
    SecretChatModel(
      id: 'post_8',
      message:
          'Had a really good conversation with my family today. It reminded me that even when things are tough, I have support.',
      createdAt: DateTime(2026, 4, 23, 13, 5),
      category: 'Gratitude',
      likeCount: 70,
      commentCount: 34,
      isLiked: true,
    ),
    SecretChatModel(
      id: 'post_9',
      message:
          "Finals week is approaching and the pressure is overwhelming. I keep telling myself one step at a time, but it's hard.",
      createdAt: DateTime(2026, 4, 23, 13, 40),
      category: 'Mental Health',
      likeCount: 34,
      commentCount: 52,
    ),
    SecretChatModel(
      id: 'post_10',
      message:
          "Sometimes I feel like I'm the only one struggling with balancing studies and mental health. It's comforting to know I have this space to share.",
      createdAt: DateTime(2026, 4, 23, 14, 5),
      category: 'Anxiety',
      likeCount: 34,
      commentCount: 52,
    ),
  ];
}
