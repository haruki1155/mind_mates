import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/admin/screens/admin_status_dashboard_screen.dart';
import 'package:mind_mates/models/admin_status_summary_model.dart';
import 'package:mind_mates/repositories/admin_status_repository.dart';

void main() {
  testWidgets('admin status dashboard shows user status categories', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminStatusDashboardScreen(
          repository: _FakeAdminStatusRepository([
            AdminStatusSummaryModel(
              userId: 'user_1',
              userLabel: 'Leo Molar',
              status: AdminUserStatus.severe,
              role: 'student',
              latestAssessmentStatus: 'High Concern',
              activeDayCount: 2,
              assessmentCount: 1,
              mindAidMessageCount: 4,
              breathingSessionCount: 1,
              updatedAt: DateTime(2026, 7, 3),
            ),
            AdminStatusSummaryModel(
              userId: 'user_2',
              userLabel: 'Mia Reyes',
              status: AdminUserStatus.normal,
              role: 'faculty',
              latestAssessmentStatus: 'Stable',
              activeDayCount: 3,
              updatedAt: DateTime(2026, 7, 3),
            ),
          ]),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Admin User Status'), findsOneWidget);
    expect(find.text('Leo Molar'), findsOneWidget);
    expect(find.text('Mia Reyes'), findsOneWidget);
    expect(find.text('Severe'), findsWidgets);
    expect(find.text('Normal'), findsWidgets);
  });
}

class _FakeAdminStatusRepository extends AdminStatusRepository {
  _FakeAdminStatusRepository(this.statuses);

  final List<AdminStatusSummaryModel> statuses;

  @override
  Stream<List<AdminStatusSummaryModel>> watchUserStatuses({int limit = 200}) {
    return Stream.value(statuses);
  }
}
