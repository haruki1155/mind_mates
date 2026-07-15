import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/admin/domain/admin_management_models.dart';
import 'package:mind_mates/features/admin/screens/user_management_page.dart';
import 'package:mind_mates/models/profile_roles.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/repositories/admin_portal_repository.dart';

class _Repository extends AdminPortalRepository {
  @override
  AccessRole get currentAccessRole => AccessRole.admin;
  @override
  bool get isSuperAdmin => true;

  @override
  Future<List<PublicAppUserRecord>> listPublicAppUsers() async => const [
    PublicAppUserRecord(
      publicUserId: 'USR-7K4P2Q',
      populationRole: PopulationRole.student,
    ),
  ];

  @override
  Stream<List<UserModel>> watchUsers() => Stream.value(const [
    UserModel(
      id: 'private-app-uid',
      email: 'private@student.example',
      firstName: 'Private',
      lastName: 'Student',
      populationRole: PopulationRole.student,
    ),
    UserModel(
      id: 'staff-uid',
      email: 'staff@example.com',
      firstName: 'Portal',
      lastName: 'Staff',
      employeeId: 'EMP-1',
      position: 'Counselor',
      department: 'Guidance/PACC',
      accessRole: AccessRole.portalStaff,
      staffAccountStatus: StaffAccountStatus.pending,
    ),
    UserModel(
      id: 'admin-uid',
      email: 'admin@example.com',
      firstName: 'System',
      lastName: 'Admin',
      accessRole: AccessRole.admin,
    ),
  ]);

  @override
  Stream<List<College>> watchColleges() => Stream.value(const []);
  @override
  Stream<List<Department>> watchDepartments() => Stream.value(const []);
  @override
  Stream<List<Course>> watchCourses() => Stream.value(const []);
}

void main() {
  testWidgets('app users expose only public ID and population category', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: UserManagementPage(repository: _Repository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('USR-7K4P2Q'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Private Student'), findsNothing);
    expect(find.text('private@student.example'), findsNothing);
    expect(find.text('Review'), findsNothing);
    expect(find.text('Verify'), findsNothing);
    expect(find.text('Reject'), findsNothing);
  });

  testWidgets('pending staff show visible contextual action buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: UserManagementPage(repository: _Repository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Staff / Counselors (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Portal Staff'), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });
}
