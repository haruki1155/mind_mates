import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/counseling/screens/services_screen.dart';
import 'package:mind_mates/features/insights/models/insights_models.dart';
import 'package:mind_mates/features/mood/screens/log_mood_screen.dart';
import 'package:mind_mates/features/profile/screens/mental_health_insights_screen.dart';
import 'package:mind_mates/models/mood_model.dart';
import 'package:mind_mates/models/report_model.dart';
import 'package:mind_mates/providers/insights_provider.dart';
import 'package:mind_mates/providers/mood_provider.dart';
import 'package:mind_mates/providers/report_provider.dart';
import 'package:mind_mates/repositories/insights_repository.dart';
import 'package:mind_mates/repositories/mood_repository.dart';
import 'package:mind_mates/repositories/report_repository.dart';
import 'package:mind_mates/routes/route_names.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('renders insights screen with backend-ready weekly metrics', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final moodProvider = MoodProvider(
      _FakeMoodRepository([
        MoodModel(id: 'mood_1', userId: 'user_1', level: 5, createdAt: now),
        MoodModel(id: 'mood_2', userId: 'user_1', level: 2, createdAt: now),
      ]),
    );
    await moodProvider.loadRecentMoods('user_1');

    final reportProvider = ReportProvider(
      _FakeReportRepository(
        ReportModel(
          id: 'report_1',
          userId: 'user_1',
          generatedAt: now,
          assessmentCount: 1,
        ),
      ),
    );
    await reportProvider.loadLatestReport('user_1');

    await tester.pumpWidget(
      _insightsApp(
        insightsProvider: InsightsProvider(InsightsRepository()),
        moodProvider: moodProvider,
        reportProvider: reportProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Search insights...'), findsOneWidget);
    expect(find.text('Stress relief'), findsAtLeastNWidgets(1));
    expect(find.text('Manage anxiety'), findsOneWidget);
    expect(find.text('Emotions'), findsOneWidget);
    expect(find.text('Better sleep'), findsOneWidget);
    expect(find.text('This week at a glance'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Your mental health patterns'), findsOneWidget);
    expect(find.text('Mental Wellbeing 101'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('PAACC support services'), findsOneWidget);
  });

  testWidgets('shows polished empty state when insight sections are absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      _insightsApp(
        insightsProvider: InsightsProvider(_EmptyInsightsRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Insight content is ready to be wired to backend data.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a seeded insight opens article detail page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _insightsApp(insightsProvider: InsightsProvider(InsightsRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('What is stress?'));
    await tester.pumpAndSettle();

    expect(find.text('Insight'), findsOneWidget);
    expect(find.text('What is stress?'), findsOneWidget);
    expect(
      find.textContaining('Stress is the body natural response to challenges'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Mental Health Insights Categories.docx'),
      findsOneWidget,
    );
    expect(find.text('stress'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Your mental wellness hub'), findsOneWidget);
  });

  testWidgets('article detail falls back when optional fields are missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const InsightArticleDetailScreen(
          item: InsightCardItem(
            id: 'minimal',
            title: 'Minimal insight',
            subtitle: 'Subtitle becomes the body.',
            category: 'General',
            imageAsset: '',
          ),
        ),
      ),
    );

    expect(find.text('Minimal insight'), findsOneWidget);
    expect(find.text('Subtitle becomes the body.'), findsNWidgets(2));
    expect(find.text('General'), findsOneWidget);
    expect(find.textContaining('PACC support is available'), findsNothing);
  });

  testWidgets('insights controls navigate to existing screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _insightsApp(insightsProvider: InsightsProvider(InsightsRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log mood ->'));
    await tester.pumpAndSettle();
    expect(find.byType(LogMoodScreen), findsOneWidget);
    expect(find.text('Log your mood'), findsOneWidget);

    Navigator.of(tester.element(find.byType(LogMoodScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('No insight notifications yet'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -950));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contact counselor'));
    await tester.pumpAndSettle();
    expect(find.byType(ServicesScreen), findsOneWidget);
    expect(find.text('All Services'), findsOneWidget);
  });

  testWidgets('search filters insights and shows empty state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _insightsApp(insightsProvider: InsightsProvider(InsightsRepository())),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'academic stress');
    await tester.pumpAndSettle();

    expect(find.text('Academic stress: how to manage it'), findsOneWidget);
    expect(find.text('What is stress?'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzzz no results');
    await tester.pumpAndSettle();

    expect(
      find.text('No insights found for "zzzz no results".'),
      findsOneWidget,
    );
  });

  testWidgets('see all opens section detail and cards open articles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _insightsApp(insightsProvider: InsightsProvider(InsightsRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('See all ->').at(1));
    await tester.pumpAndSettle();

    expect(find.text('Mental Wellbeing 101'), findsOneWidget);
    expect(find.text('What is stress?'), findsOneWidget);

    await tester.tap(find.text('What is stress?'));
    await tester.pumpAndSettle();

    expect(find.text('Insight'), findsOneWidget);
    expect(
      find.textContaining('Stress is the body natural response to challenges'),
      findsOneWidget,
    );
  });
}

Widget _insightsApp({
  required InsightsProvider insightsProvider,
  MoodProvider? moodProvider,
  ReportProvider? reportProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<InsightsProvider>.value(value: insightsProvider),
      if (moodProvider != null)
        ChangeNotifierProvider<MoodProvider>.value(value: moodProvider),
      if (reportProvider != null)
        ChangeNotifierProvider<ReportProvider>.value(value: reportProvider),
    ],
    child: MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      routes: {
        RouteNames.logMood: (_) => const LogMoodScreen(),
        RouteNames.services: (_) => const ServicesScreen(),
      },
      home: const MentalHealthInsightsScreen(),
    ),
  );
}

class _EmptyInsightsRepository extends InsightsRepository {
  @override
  Future<InsightsDashboardData> fetchInsights(String userId) async {
    return const InsightsDashboardData(categories: [], sections: []);
  }
}

class _FakeMoodRepository extends MoodRepository {
  _FakeMoodRepository(this.moods);

  final List<MoodModel> moods;

  @override
  Future<List<MoodModel>> fetchRecentMoods(String userId, {int limit = 14}) {
    return Future.value(moods);
  }
}

class _FakeReportRepository extends ReportRepository {
  _FakeReportRepository(this.latest);

  final ReportModel? latest;

  @override
  Future<ReportModel?> fetchLatestReport(String userId) async => latest;
}
