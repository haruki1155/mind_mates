import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/secret_chat/screens/secret_chat_profile_screen.dart';
import 'package:mind_mates/models/secret_chat_model.dart';
import 'package:mind_mates/models/secret_chat_profile.dart';
import 'package:mind_mates/providers/secret_chat_provider.dart';
import 'package:mind_mates/repositories/secret_chat_repository.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('keeps profile and statistics visible when recent posts fail', (
    tester,
  ) async {
    final repository = _ProfileRepository(
      profile: _profile('Calm Owl'),
      failRecentPosts: true,
      stats: const SecretChatProfileStats(reads: 7, reactions: 2, comments: 1),
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Recent posts could not be refreshed.'),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Calm Owl'), findsWidgets);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Recent posts could not be refreshed.'), findsOneWidget);
    expect(find.text('Post statistics could not be refreshed.'), findsNothing);
    expect(
      find.text('Secret Chat is unavailable right now. Please try again.'),
      findsNothing,
    );
  });

  testWidgets('keeps recent posts visible when statistics fail', (
    tester,
  ) async {
    final repository = _ProfileRepository(
      profile: _profile('Calm Owl'),
      failStats: true,
      recentPosts: [_recentPost()],
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Post statistics could not be refreshed.'),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.text('Post statistics could not be refreshed.'),
      findsOneWidget,
    );
    expect(find.text('I feel supported after sharing today.'), findsOneWidget);
    expect(find.text('Recent posts could not be refreshed.'), findsNothing);
  });

  testWidgets('recent-post retry removes its targeted warning', (tester) async {
    final repository = _ProfileRepository(
      profile: _profile('Calm Owl'),
      failRecentPosts: true,
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Recent posts could not be refreshed.'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    repository.failRecentPosts = false;
    repository.recentPosts = [_recentPost()];
    await tester.tap(find.widgetWithText(TextButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Recent posts could not be refreshed.'), findsNothing);
    expect(find.text('I feel supported after sharing today.'), findsOneWidget);
  });

  testWidgets('zero counters with a post are described as no engagement', (
    tester,
  ) async {
    final repository = _ProfileRepository(
      profile: _profile('Calm Owl'),
      recentPosts: [_recentPost()],
    );

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('No engagement yet'),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('No engagement yet'), findsOneWidget);
    expect(find.text('No recent posts yet'), findsNothing);
    expect(find.text('No post activity yet'), findsNothing);
  });

  testWidgets('empty recent-post result is not presented as broken activity', (
    tester,
  ) async {
    final repository = _ProfileRepository(profile: _profile('Calm Owl'));

    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('No recent posts yet'),
      250,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('No recent posts yet'), findsOneWidget);
    expect(find.text('No engagement yet'), findsNothing);
    expect(find.text('No post activity yet'), findsNothing);
  });

  testWidgets('shows a server-confirmed alias after save and reload', (
    tester,
  ) async {
    final repository = _ProfileRepository(profile: _profile('Calm Owl'));
    final provider = SecretChatProvider(repository);
    await tester.pumpWidget(_app(repository, provider: provider));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Choose a pseudonym'),
      'Quiet Fox',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save profile'));
    await tester.pumpAndSettle();
    expect(repository.profile?.alias, 'Quiet Fox');

    await provider.loadProfile();
    await tester.pumpAndSettle();
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, 'Quiet Fox');
    expect(find.text('Quiet Fox'), findsWidgets);
  });
}

Widget _app(_ProfileRepository repository, {SecretChatProvider? provider}) {
  return ChangeNotifierProvider.value(
    value: provider ?? SecretChatProvider(repository),
    child: const MaterialApp(home: SecretChatProfileScreen()),
  );
}

SecretChatProfile _profile(String alias) => SecretChatProfile(
  userId: 'user_1',
  alias: alias,
  aliasKey: SecretChatProfile.aliasKeyFor(alias),
);

SecretChatModel _recentPost() => SecretChatModel(
  id: 'recent_1',
  message: 'I feel supported after sharing today.',
  createdAt: DateTime(2026, 7, 4),
  category: 'Support',
  likeCount: 1,
  commentCount: 2,
  authorId: 'user_1',
  isMine: true,
);

class _ProfileRepository extends SecretChatRepository {
  _ProfileRepository({
    required this.profile,
    this.failStats = false,
    this.failRecentPosts = false,
    this.stats = SecretChatProfileStats.empty,
    List<SecretChatModel>? recentPosts,
  }) : recentPosts = recentPosts ?? [];

  SecretChatProfile? profile;
  bool failStats;
  bool failRecentPosts;
  final SecretChatProfileStats stats;
  List<SecretChatModel> recentPosts;

  @override
  String? get currentUserId => 'user_1';

  @override
  bool get hasSignedInUser => true;

  @override
  Future<SecretChatProfile?> fetchCurrentProfile({
    bool forceServer = false,
  }) async {
    return profile;
  }

  @override
  Future<SecretChatProfileStats> fetchProfileStats() async {
    if (failStats) throw StateError('statistics unavailable');
    return stats;
  }

  @override
  Future<List<SecretChatModel>> fetchRecentPosts({int limit = 3}) async {
    if (failRecentPosts) throw StateError('recent posts unavailable');
    return recentPosts.take(limit).toList(growable: false);
  }

  @override
  Future<SecretChatProfile> saveProfile({required String alias}) async {
    profile = _profile(SecretChatProfile.normalizeAlias(alias));
    return profile!;
  }
}
