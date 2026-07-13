import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/journal/screens/journal_screen.dart';
import 'package:mind_mates/models/journal_model.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/providers/journal_provider.dart';
import 'package:mind_mates/providers/user_provider.dart';
import 'package:mind_mates/repositories/journal_repository.dart';
import 'package:mind_mates/repositories/user_repository.dart';
import 'package:provider/provider.dart';

void main() {
  test('guided journal model round-trips and reads legacy fields', () {
    final entry = JournalModel(
      id: 'journal_1',
      userId: 'user_1',
      mode: JournalMode.understandFeelings,
      content: 'I felt pressure before an exam.',
      moodLevel: 2,
      moodLabel: 'Stressed',
      feelingAfter: JournalFeelingAfter.same,
      category: 'Academics',
      tags: const ['exams', 'pressure'],
      promptIds: const ['feel_trigger_01'],
      responses: const [
        JournalPromptResponse(
          promptId: 'feel_trigger_01',
          response: 'An exam is coming up.',
        ),
      ],
      createdAt: DateTime(2026, 7, 1),
    );

    final decoded = JournalModel.fromJson(entry.toJson(), id: entry.id);
    expect(decoded.mode, JournalMode.understandFeelings);
    expect(decoded.moodLabel, 'Stressed');
    expect(decoded.responses.single.response, 'An exam is coming up.');
    expect(decoded.feelingAfter, JournalFeelingAfter.same);

    final legacy = JournalModel.fromJson({
      'content': 'Legacy reflection',
      'moodLevel': 4,
      'createdAt': DateTime(2025, 1, 1),
    });
    expect(legacy.mode, JournalMode.freeWrite);
    expect(legacy.content, 'Legacy reflection');
    expect(legacy.moodLevel, 4);
  });

  testWidgets('journal home exposes all six low-pressure modes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_journalApp(_FakeJournalRepository()));
    await tester.pumpAndSettle();

    expect(find.text('My Journal'), findsOneWidget);
    for (final mode in JournalMode.values) {
      expect(find.text(mode.label), findsOneWidget);
    }
    expect(find.text('Private to you'), findsOneWidget);
    expect(find.textContaining('not a diagnosis'), findsOneWidget);
  });

  testWidgets('free writing saves privately and appears in history', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeJournalRepository();
    final journalProvider = JournalProvider(repository);
    await tester.pumpWidget(_journalApp(repository, provider: journalProvider));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Write Freely'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      'Today felt manageable and I asked for help.',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save privately'));
    await tester.tap(find.text('Save privately'));
    await tester.pumpAndSettle();

    expect(repository.created, hasLength(1));
    expect(
      repository.created.single.content,
      contains('Today felt manageable'),
    );
    expect(
      journalProvider.journals.single.content,
      contains('Today felt manageable'),
    );
  });

  testWidgets('guided mode shows one prompt at a time without a skip button', (
    tester,
  ) async {
    await tester.pumpWidget(_journalApp(_FakeJournalRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Understand My Feelings'));
    await tester.pumpAndSettle();
    expect(
      find.text('What happened before you started feeling this way?'),
      findsOneWidget,
    );
    expect(
      find.text('What part of this situation feels hardest right now?'),
      findsNothing,
    );

    expect(find.text('Skip'), findsNothing);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      find.text('What part of this situation feels hardest right now?'),
      findsOneWidget,
    );
  });
}

Widget _journalApp(
  _FakeJournalRepository repository, {
  JournalProvider? provider,
}) {
  final users = UserProvider(_FakeUserRepository())
    ..setUser(const UserModel(id: 'user_1', email: 'user@example.com'));
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: users),
      ChangeNotifierProvider.value(
        value: provider ?? JournalProvider(repository),
      ),
    ],
    child: const MaterialApp(home: JournalScreen()),
  );
}

class _FakeJournalRepository extends JournalRepository {
  final List<JournalModel> created = [];

  @override
  Future<List<JournalModel>> fetchRecentJournals(
    String userId, {
    int limit = 20,
  }) async => [...created];

  @override
  Future<String> createEntry(JournalModel entry) async {
    created.add(entry.copyWith(id: 'journal_${created.length + 1}'));
    return created.last.id;
  }

  @override
  Future<void> updateEntry(JournalModel entry) async {}

  @override
  Future<void> deleteJournal(String journalId) async {
    created.removeWhere((entry) => entry.id == journalId);
  }
}

class _FakeUserRepository extends UserRepository {}
