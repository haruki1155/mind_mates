import '../models/secret_chat_model.dart';

class SecretChatRepository {
  SecretChatRepository() {
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

  late List<SecretChatModel> _posts;
  late Map<String, List<SecretChatComment>> _comments;

  Future<List<SecretChatModel>> fetchPosts() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
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
      isMine: true,
    );
    _posts = [post, ..._posts];
    _comments[post.id] = [];
    return post;
  }

  Future<SecretChatModel> toggleLike(String postId) async {
    return _updatePost(postId, (post) {
      final nextLiked = !post.isLiked;
      return post.copyWith(
        isLiked: nextLiked,
        likeCount: post.likeCount + (nextLiked ? 1 : -1),
      );
    });
  }

  Future<SecretChatModel> toggleSave(String postId) async {
    return _updatePost(postId, (post) => post.copyWith(isSaved: !post.isSaved));
  }

  Future<List<SecretChatComment>> fetchComments(String postId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
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
    _comments[postId] = [comment, ...?_comments[postId]];
    await _updatePost(
      postId,
      (post) => post.copyWith(commentCount: post.commentCount + 1),
    );
    return comment;
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
