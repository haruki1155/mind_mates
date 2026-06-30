import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/profile/screens/profile_screen.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/providers/user_provider.dart';
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
}

Widget _profileApp(UserProvider provider, {ProfileViewData? data}) {
  return ChangeNotifierProvider<UserProvider>.value(
    value: provider,
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
