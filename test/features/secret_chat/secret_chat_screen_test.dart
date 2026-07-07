import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/secret_chat/screens/secret_chat_screen.dart';
import 'package:mind_mates/models/secret_chat_model.dart';
import 'package:mind_mates/providers/secret_chat_provider.dart';

void main() {
  testWidgets('empty Secret Chat shows real empty state', (tester) async {
    await tester.pumpWidget(_app(posts: const []));

    expect(find.text('No thoughts found'), findsOneWidget);
    expect(
      find.text('No anonymous threads yet. Start a wellbeing conversation.'),
      findsOneWidget,
    );
  });

  testWidgets('compose shows validation message for blocked content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(posts: const []));

    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pump();
    await tester.enterText(
      find.byType(TextField).last,
      'Selling my old laptop this week',
    );
    await tester.pump();

    expect(find.textContaining('Secret Chat is only for'), findsOneWidget);
  });

  testWidgets('tapping comments opens full thread screen', (tester) async {
    await tester.pumpWidget(_app(posts: [_post()]));

    await tester.tap(find.byIcon(Icons.mode_comment_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Anonymous Thread'), findsOneWidget);
    expect(find.text('You are not alone in this.'), findsOneWidget);
  });

  testWidgets('thread shows friendly message when reply cannot be saved', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        posts: [_post()],
        onAddComment: ({required postId, required message}) async {
          throw const SecretChatActionException(
            'This thread is no longer available for replies.',
          );
        },
      ),
    );

    await tester.tap(find.byIcon(Icons.mode_comment_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(
      find.byType(TextField).last,
      'I feel this too. Support helps.',
    );
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(
      find.text('This thread is no longer available for replies.'),
      findsWidgets,
    );
  });

  testWidgets('thread shows success message when reply is saved', (
    tester,
  ) async {
    await tester.pumpWidget(_app(posts: [_post()]));

    await tester.tap(find.byIcon(Icons.mode_comment_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(
      find.byType(TextField).last,
      'I feel this too. Support helps.',
    );
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(find.text('Reply posted anonymously.'), findsWidgets);
  });
}

Widget _app({
  required List<SecretChatModel> posts,
  AddSecretComment? onAddComment,
}) {
  return MaterialApp(
    home: SecretChatScreen(
      posts: posts,
      categories: const [
        SecretChatCategory(label: 'Mental Health', color: Color(0xFFFFC414)),
        SecretChatCategory(label: 'Anxiety', color: Color(0xFFFF7BA5)),
        SecretChatCategory(label: 'Stress', color: Color(0xFFFF9D76)),
      ],
      selectedFilter: SecretChatFilter.popular,
      savedCount: 0,
      searchQuery: '',
      isLoading: false,
      errorMessage: null,
      canCreate: true,
      onFilterChanged: (_) {},
      onSearchChanged: (_) {},
      onCreatePost: ({required message, required category}) async {},
      onToggleLike: (_) {},
      onToggleSave: (_) {},
      onFetchComments: (_) async => [
        SecretChatComment(
          id: 'comment_1',
          postId: 'post_1',
          message: 'You are not alone in this.',
          createdAt: DateTime(2026, 7, 3),
        ),
      ],
      onAddComment:
          onAddComment ?? ({required postId, required message}) async {},
      onRetry: () {},
      onBack: () {},
    ),
  );
}

SecretChatModel _post() {
  return SecretChatModel(
    id: 'post_1',
    message: 'I feel anxious about school pressure.',
    createdAt: DateTime(2026, 7, 3),
    category: 'Anxiety',
    likeCount: 1,
    commentCount: 1,
  );
}
