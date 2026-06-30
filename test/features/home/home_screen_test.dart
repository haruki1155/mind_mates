import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/home/screens/home_screen.dart';
import 'package:mind_mates/models/mood_model.dart';
import 'package:mind_mates/models/report_model.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/providers/assessment_provider.dart';
import 'package:mind_mates/providers/mood_provider.dart';
import 'package:mind_mates/providers/report_provider.dart';
import 'package:mind_mates/providers/user_provider.dart';
import 'package:mind_mates/repositories/assessment_repository.dart';
import 'package:mind_mates/repositories/mood_repository.dart';
import 'package:mind_mates/repositories/report_repository.dart';
import 'package:mind_mates/repositories/user_repository.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('home dashboard overlays profile, streak, moods, and report', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final userProvider = UserProvider(_FakeUserRepository())
      ..setUser(
        const UserModel(
          id: 'user_1',
          email: 'leo@example.com',
          firstName: 'Leonardo',
          lastName: 'Molar',
          role: 'student',
          dayStreak: 5,
        ),
      );
    final moodProvider = MoodProvider(_FakeMoodRepository());
    await moodProvider.logMood(userId: 'user_1', level: 4, label: 'Good');
    final reportProvider = ReportProvider(
      _FakeReportRepository(
        latest: ReportModel(
          id: 'report_1',
          userId: 'user_1',
          title: 'Mental Health Summary',
          description: 'This week is ready for review',
          generatedAt: DateTime(2026, 6, 30),
        ),
      ),
    );
    await reportProvider.loadLatestReport('user_1');

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<MoodProvider>.value(value: moodProvider),
          ChangeNotifierProvider<ReportProvider>.value(value: reportProvider),
          ChangeNotifierProvider(
            create: (_) => AssessmentProvider(AssessmentRepository()),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Welcome back, Leonardo Molar!'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('This week is ready for review'), findsOneWidget);
  });
}

class _FakeUserRepository extends UserRepository {}

class _FakeMoodRepository extends MoodRepository {
  @override
  Future<String> createMood({
    required String userId,
    required int level,
    String? label,
    String? note,
  }) async {
    return 'mood_1';
  }

  @override
  Future<List<MoodModel>> fetchRecentMoods(String userId, {int limit = 14}) {
    return Future.value(const []);
  }
}

class _FakeReportRepository extends ReportRepository {
  _FakeReportRepository({this.latest});

  final ReportModel? latest;

  @override
  Future<ReportModel?> fetchLatestReport(String userId) async => latest;
}
