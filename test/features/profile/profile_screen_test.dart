import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/profile/screens/mental_health_report_screen.dart';
import 'package:mind_mates/features/profile/screens/profile_screen.dart';
import 'package:mind_mates/models/report_model.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/providers/report_provider.dart';
import 'package:mind_mates/providers/user_provider.dart';
import 'package:mind_mates/repositories/report_repository.dart';
import 'package:mind_mates/repositories/user_repository.dart';
import 'package:mind_mates/routes/app_pages.dart';
import 'package:mind_mates/routes/route_names.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('profile hero shows user info and day streak', (tester) async {
    final repository = _FakeUserRepository();
    final provider = UserProvider(repository)
      ..setUser(
        UserModel.fromJson({
          'id': 'user_1',
          'email': 'leo@example.com',
          'firstName': 'Leonardo',
          'lastName': 'Molar',
          'role': 'student',
          'dayStreak': 20,
          'createdAt': '2026-06-30T00:00:00.000',
        }),
      );

    await tester.pumpWidget(
      _profileApp(provider, data: _dataFrom(provider.user!)),
    );

    expect(find.text('Leonardo Molar'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Member since Jun 30, 2026'), findsNothing);
    expect(find.text('leo@example.com'), findsNothing);
    expect(find.byType(FractionallySizedBox), findsNothing);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('--/10'), findsNWidgets(2));
  });

  testWidgets('mental health summary buttons and routes are ready', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = UserProvider(_FakeUserRepository())
      ..setUser(const UserModel(id: 'user_1', email: 'leo@example.com'));

    await tester.pumpWidget(
      _profileApp(provider, data: _dataFrom(provider.user!)),
    );

    expect(find.text('Full Report'), findsOneWidget);
    expect(find.text('View Insights'), findsOneWidget);
    expect(AppPages.routes[RouteNames.mentalHealthReport], isNotNull);
    expect(AppPages.routes[RouteNames.mentalHealthInsights], isNotNull);
  });

  testWidgets('mental health summary uses generated report text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final userProvider = UserProvider(_FakeUserRepository())
      ..setUser(const UserModel(id: 'user_1', email: 'leo@example.com'));
    final reportProvider = ReportProvider(
      _FakeReportRepository(
        ReportModel(
          id: 'report_1',
          userId: 'user_1',
          title: 'Mental Health Summary',
          description:
              'Latest assessment shows moderate concern with a 4-day streak.',
          generatedAt: DateTime(2026, 7, 3),
          hasEnoughData: true,
        ),
      ),
    );
    await reportProvider.loadLatestReport('user_1');

    await tester.pumpWidget(
      _profileApp(userProvider, reportProvider: reportProvider),
    );
    await tester.pump();

    expect(
      find.text(
        'Latest assessment shows moderate concern with a 4-day streak.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('mental health report shows assessment and usage summary', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final reportProvider = ReportProvider(
      _FakeReportRepository(
        ReportModel(
          id: 'report_1',
          userId: 'user_1',
          title: 'Mental Health Summary',
          description:
              'Mental status: Watchful with 6 Secret Chat engagements.',
          generatedAt: DateTime(2026, 7, 3),
          mentalStatus: 'moderate',
          mentalStatusLabel: 'Watchful',
          fullAssessmentScore: 72,
          fullAssessmentStatus: 'High Concern',
          fullAssessmentTopConcernAreas: const ['Sleep and Rest'],
          quickAssessmentScore: 61,
          quickAssessmentStatus: 'moderate',
          quickAssessmentSignal: 'watchful',
          moodCheckInCount: 4,
          averageMoodLevel: 3.2,
          mindAidMessageCount: 5,
          breathingSessionCount: 2,
          mindfulBreathingMinutes: 8,
          activeDayCount: 3,
          currentStreak: 4,
          secretChatPostCount: 1,
          secretChatCommentCount: 2,
          secretChatInteractionCount: 3,
          secretChatEngagementCount: 6,
          totalEngagementCount: 22,
          recommendedNextActions: const ['Review support strategies'],
          hasEnoughData: true,
        ),
      ),
    );
    await reportProvider.loadLatestReport('user_1');

    await tester.pumpWidget(
      ChangeNotifierProvider<ReportProvider>.value(
        value: reportProvider,
        child: const MaterialApp(home: MentalHealthReportScreen()),
      ),
    );

    expect(find.text('Watchful'), findsOneWidget);
    expect(find.text('Assessment Results'), findsOneWidget);
    expect(find.text('High Concern'), findsOneWidget);
    expect(find.text('72/100'), findsOneWidget);
    expect(find.text('moderate'), findsOneWidget);
    expect(find.text('61/100'), findsOneWidget);
    expect(find.text('Secret Chat'), findsOneWidget);
    expect(find.text('1 posts, 2 comments'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
    expect(find.text('Review support strategies'), findsOneWidget);
  });
}

Widget _profileApp(
  UserProvider provider, {
  ProfileViewData? data,
  ReportProvider? reportProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: provider),
      if (reportProvider != null)
        ChangeNotifierProvider<ReportProvider>.value(value: reportProvider),
    ],
    child: MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: ProfileScreen(data: data),
    ),
  );
}

ProfileViewData _dataFrom(UserModel user) {
  return ProfileViewData(
    displayName: user.displayName,
    role: user.roleLabel,
    email: user.email,
    memberSince: 'Member since Jun 30, 2026',
    metrics: [
      ProfileMetricData(
        label: 'Day Streak',
        value: '${user.dayStreak}',
        icon: Icons.local_fire_department,
      ),
      const ProfileMetricData(
        label: 'Sleep',
        value: '--/10',
        icon: Icons.sentiment_satisfied_alt,
      ),
      const ProfileMetricData(
        label: 'Stress',
        value: '--/10',
        icon: Icons.bar_chart,
      ),
    ],
    summary: const ProfileSummaryData(
      title: 'Mental Health Summary',
      description: "This week's positive moods",
    ),
  );
}

class _FakeUserRepository extends UserRepository {
  UserModel? updatedUser;

  @override
  Future<void> updateUserProfile(String uid, UserModel user) async {
    updatedUser = user;
  }
}

class _FakeReportRepository extends ReportRepository {
  _FakeReportRepository(this.report);

  final ReportModel report;

  @override
  Future<ReportModel?> fetchLatestReport(String userId) async => report;
}
