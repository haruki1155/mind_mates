import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/insights/models/insights_models.dart';
import 'package:mind_mates/features/profile/screens/mental_health_insights_screen.dart';
import 'package:mind_mates/models/mood_model.dart';
import 'package:mind_mates/models/report_model.dart';
import 'package:mind_mates/providers/insights_provider.dart';
import 'package:mind_mates/providers/mood_provider.dart';
import 'package:mind_mates/providers/report_provider.dart';
import 'package:mind_mates/repositories/insights_repository.dart';
import 'package:mind_mates/repositories/mood_repository.dart';
import 'package:mind_mates/repositories/report_repository.dart';
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
    expect(find.text('Mood tracking'), findsOneWidget);
    expect(find.text('Stress relief'), findsOneWidget);
    expect(find.text('Better sleep'), findsOneWidget);
    expect(find.text('Manage anxiety'), findsOneWidget);
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
      home: const MentalHealthInsightsScreen(),
    ),
  );
}

class _EmptyInsightsRepository extends InsightsRepository {
  @override
  Future<InsightsDashboardData> fetchInsights() async {
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
