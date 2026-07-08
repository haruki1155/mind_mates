import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/models/secret_chat_model.dart';
import 'package:mind_mates/providers/secret_chat_provider.dart';
import 'package:mind_mates/repositories/secret_chat_repository.dart';

void main() {
  test('blocked post does not call repository write', () async {
    final repository = _FakeSecretChatRepository();
    final provider = SecretChatProvider(repository);

    await expectLater(
      provider.createPost(
        message: 'Selling shoes today',
        categories: ['Support'],
      ),
      throwsA(isA<SecretChatValidationException>()),
    );

    expect(repository.createdMessages, isEmpty);
    expect(provider.errorMessage, contains('mental health'));
  });

  test('allowed post is added to Mine', () async {
    final repository = _FakeSecretChatRepository();
    final provider = SecretChatProvider(repository);

    await provider.createPost(
      message: 'I feel stressed about exams and need support.',
      categories: ['Stress'],
    );

    expect(provider.posts, hasLength(1));
    expect(provider.selectedFilter, SecretChatFilter.mine);
    expect(provider.visiblePosts.single.isMine, isTrue);
    expect(repository.createdMessages.single, contains('stressed'));
  });

  test('post appears optimistically while Firestore is pending', () async {
    final gate = Completer<void>();
    final repository = _FakeSecretChatRepository(createGate: gate);
    final provider = SecretChatProvider(repository);

    final completion = provider.createPost(
      message: 'I feel stressed about exams and need support.',
      categories: ['Stress', 'Support'],
    );

    expect(provider.posts.single.isPending, isTrue);
    expect(provider.posts.single.categoryList, ['Stress', 'Support']);
    gate.complete();
    await completion;
    expect(provider.posts.single.isPending, isFalse);
  });

  test('rejects missing duplicate or more than three categories', () async {
    final provider = SecretChatProvider(_FakeSecretChatRepository());
    const message = 'I feel stressed about exams and need support.';

    await expectLater(
      provider.createPost(message: message, categories: []),
      throwsArgumentError,
    );
    await expectLater(
      provider.createPost(message: message, categories: ['Stress', 'Stress']),
      throwsArgumentError,
    );
    await expectLater(
      provider.createPost(
        message: message,
        categories: ['Stress', 'Support', 'Anxiety', 'Gratitude'],
      ),
      throwsArgumentError,
    );
  });

  test('allowed comment increments local count', () async {
    final repository = _FakeSecretChatRepository();
    final provider = SecretChatProvider(repository);
    await provider.loadPosts();

    await provider.addComment(
      postId: 'post_1',
      message: 'I feel this too. Rest and support matter.',
    );

    expect(provider.posts.single.commentCount, 1);
    expect(repository.comments.single.message, contains('support'));
  });

  test('ordinary comment without wellness keywords is accepted', () async {
    final repository = _FakeSecretChatRepository();
    final provider = SecretChatProvider(repository);
    await provider.loadPosts();

    await provider.addComment(postId: 'post_1', message: 'Same here!');

    expect(repository.comments.single.message, 'Same here!');
  });

  test('unavailable thread exposes friendly comment error', () async {
    final repository = _FakeSecretChatRepository(
      commentError: const SecretChatThreadUnavailableException(),
    );
    final provider = SecretChatProvider(repository);
    await provider.loadPosts();

    await expectLater(
      provider.addComment(
        postId: 'post_1',
        message: 'I feel this too. Support helps a lot.',
      ),
      throwsA(isA<SecretChatActionException>()),
    );

    expect(provider.posts.single.commentCount, 0);
    expect(repository.comments, isEmpty);
    expect(
      provider.errorMessage,
      'This thread is no longer available for replies.',
    );
  });
}

class _FakeSecretChatRepository extends SecretChatRepository {
  _FakeSecretChatRepository({this.commentError, this.createGate});

  final Object? commentError;
  final Completer<void>? createGate;
  final createdMessages = <String>[];
  final comments = <SecretChatComment>[];

  @override
  bool get hasSignedInUser => true;

  @override
  String newPostId() => 'post_created';

  @override
  Future<List<SecretChatModel>> fetchPosts() async {
    return [
      SecretChatModel(
        id: 'post_1',
        message: 'I feel anxious about school.',
        createdAt: DateTime(2026, 7, 3),
        category: 'Anxiety',
        likeCount: 0,
        commentCount: 0,
        authorId: 'user_1',
        isMine: true,
      ),
    ];
  }

  @override
  Future<SecretChatModel> createPost({
    required String message,
    required List<String> categories,
    String? postId,
    List<String> safetyLabels = const [],
  }) async {
    await createGate?.future;
    createdMessages.add(message);
    return SecretChatModel(
      id: 'post_created',
      message: message,
      createdAt: DateTime(2026, 7, 3),
      category: categories.first,
      categories: categories,
      likeCount: 0,
      commentCount: 0,
      authorId: 'user_1',
      safetyLabels: safetyLabels,
      isMine: true,
    );
  }

  @override
  Future<SecretChatComment> addComment({
    required String postId,
    required String message,
    String? commentId,
    List<String> safetyLabels = const [],
  }) async {
    final error = commentError;
    if (error != null) throw error;

    final comment = SecretChatComment(
      id: 'comment_1',
      postId: postId,
      message: message,
      createdAt: DateTime(2026, 7, 3),
      authorId: 'user_1',
      safetyLabels: safetyLabels,
    );
    comments.add(comment);
    return comment;
  }
}
