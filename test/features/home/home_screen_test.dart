import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/home/screens/home_screen.dart';
import 'package:mind_mates/models/mood_model.dart';
import 'package:mind_mates/models/report_model.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/providers/assessment_provider.dart';
import 'package:mind_mates/providers/breathing_provider.dart';
import 'package:mind_mates/providers/insights_provider.dart';
import 'package:mind_mates/providers/mood_provider.dart';
import 'package:mind_mates/providers/report_provider.dart';
import 'package:mind_mates/providers/user_provider.dart';
import 'package:mind_mates/repositories/assessment_repository.dart';
import 'package:mind_mates/repositories/breathing_repository.dart';
import 'package:mind_mates/repositories/insights_repository.dart';
import 'package:mind_mates/repositories/mood_repository.dart';
import 'package:mind_mates/repositories/report_repository.dart';
import 'package:mind_mates/repositories/user_repository.dart';
import 'package:mind_mates/routes/app_pages.dart';
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
            create: (_) => InsightsProvider(InsightsRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => AssessmentProvider(AssessmentRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => BreathingProvider(_FakeBreathingRepository()),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          routes: _testRoutes(),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Welcome back, Leonardo Molar!'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Day streak'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('This week is ready for review'), findsOneWidget);
  });

  testWidgets('home Insight destination opens the insights screen', (
    tester,
  ) async {
    final userProvider = UserProvider(_FakeUserRepository())
      ..setUser(const UserModel(id: 'user_1', email: 'leo@example.com'));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<MoodProvider>(
            create: (_) => MoodProvider(_FakeMoodRepository()),
          ),
          ChangeNotifierProvider<ReportProvider>(
            create: (_) => ReportProvider(_FakeReportRepository()),
          ),
          ChangeNotifierProvider<InsightsProvider>(
            create: (_) => InsightsProvider(InsightsRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => AssessmentProvider(AssessmentRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => BreathingProvider(_FakeBreathingRepository()),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          routes: _testRoutes(),
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.tap(find.text('Insight'));
    await tester.pumpAndSettle();

    expect(find.text('Search insights...'), findsOneWidget);
  });

  testWidgets('home Log your mood opens mood check-in screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final userProvider = UserProvider(_FakeUserRepository())
      ..setUser(const UserModel(id: 'user_1', email: 'leo@example.com'));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<MoodProvider>(
            create: (_) => MoodProvider(_FakeMoodRepository()),
          ),
          ChangeNotifierProvider<ReportProvider>(
            create: (_) => ReportProvider(_FakeReportRepository()),
          ),
          ChangeNotifierProvider<InsightsProvider>(
            create: (_) => InsightsProvider(InsightsRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => AssessmentProvider(AssessmentRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => BreathingProvider(_FakeBreathingRepository()),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          routes: _testRoutes(),
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.tap(find.text('Log your mood').first);
    await tester.pumpAndSettle();

    expect(find.text('How are you feeling?'), findsOneWidget);
    expect(find.text("What's on your mind today?"), findsOneWidget);
    expect(find.text('0/300 characters'), findsOneWidget);
  });

  testWidgets('home Mindful breathing insight opens breathing screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final userProvider = UserProvider(_FakeUserRepository())
      ..setUser(const UserModel(id: 'user_1', email: 'leo@example.com'));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<MoodProvider>(
            create: (_) => MoodProvider(_FakeMoodRepository()),
          ),
          ChangeNotifierProvider<ReportProvider>(
            create: (_) => ReportProvider(_FakeReportRepository()),
          ),
          ChangeNotifierProvider<InsightsProvider>(
            create: (_) => InsightsProvider(InsightsRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => AssessmentProvider(AssessmentRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => BreathingProvider(_FakeBreathingRepository()),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          routes: _testRoutes(),
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.tap(find.text('Mindful breathing'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Breathing'), findsOneWidget);
    expect(find.text('Breath to reduce'), findsOneWidget);
    expect(find.text('Anger'), findsOneWidget);
  });

  testWidgets('home blocks main assessment when completed this week', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final userProvider = UserProvider(_FakeUserRepository())
      ..setUser(
        const UserModel(
          id: 'user_1',
          email: 'leo@example.com',
          role: 'student',
        ),
      );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<UserProvider>.value(value: userProvider),
          ChangeNotifierProvider<MoodProvider>(
            create: (_) => MoodProvider(_FakeMoodRepository()),
          ),
          ChangeNotifierProvider<ReportProvider>(
            create: (_) => ReportProvider(_FakeReportRepository()),
          ),
          ChangeNotifierProvider<InsightsProvider>(
            create: (_) => InsightsProvider(InsightsRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => AssessmentProvider(
              _FakeAssessmentRepository(hasFullThisWeek: true),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => BreathingProvider(_FakeBreathingRepository()),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          routes: _testRoutes(),
          home: const HomeScreen(),
        ),
      ),
    );

    await tester.tap(find.text('Start Assessment'));
    await tester.pumpAndSettle();

    expect(find.text('Assessment already completed'), findsOneWidget);
    expect(find.text('Start Assessment?'), findsNothing);
  });
}

Map<String, WidgetBuilder> _testRoutes() {
  return Map<String, WidgetBuilder>.of(AppPages.routes)
    ..remove(Navigator.defaultRouteName);
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

class _FakeBreathingRepository extends BreathingRepository {}

class _FakeAssessmentRepository extends AssessmentRepository {
  _FakeAssessmentRepository({this.hasFullThisWeek = false});

  final bool hasFullThisWeek;

  @override
  Future<bool> hasFullAssessmentThisWeek(String userId, {DateTime? now}) async {
    return hasFullThisWeek;
  }
}
