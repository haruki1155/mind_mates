import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mind_mates/features/admin/domain/admin_management_models.dart';
import 'package:mind_mates/features/admin/screens/user_management_page.dart';
import 'package:mind_mates/features/admin/screens/admin_portal.dart';
import 'package:mind_mates/models/profile_roles.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/models/appointment_model.dart';
import 'package:mind_mates/models/admin_inquiry_model.dart';
import 'package:mind_mates/models/admin_activity_analytics_model.dart';
import 'package:mind_mates/models/admin_mind_aid_analytics_model.dart';
import 'package:mind_mates/repositories/admin_portal_repository.dart';

class _Repository extends AdminPortalRepository {
  bool deleteCalled = false;

  @override
  AccessRole get currentAccessRole => AccessRole.admin;
  @override
  bool get isSuperAdmin => true;

  @override
  Future<List<PublicAppUserRecord>> listPublicAppUsers() async => const [
    PublicAppUserRecord(
      publicUserId: 'USR-7K4P2Q',
      populationRole: PopulationRole.student,
      department: 'College of Computing',
      course: 'BS Information Technology',
      yearLevel: '3rd Year',
    ),
  ];

  @override
  Future<PublicAppUserPage> fetchPublicAppUsersPage({
    String? cursor,
    int pageSize = 25,
    String search = '',
    String role = '',
    String department = '',
    String course = '',
    String yearLevel = '',
  }) async =>
      PublicAppUserPage(users: await listPublicAppUsers(), totalAppUsers: 1);

  @override
  Future<PreviewInactiveAppUserDeletionResult>
  previewInactiveAppUserDeletion() async =>
      PreviewInactiveAppUserDeletionResult(
        cutoff: DateTime.utc(2026, 7, 9),
        inactiveDays: 7,
        eligibleCount: 1,
        skippedMissingActivity: 0,
        publicUserIds: const ['USR-7K4P2Q'],
      );

  @override
  Future<InactiveAppUserDeletionResult> deleteInactiveAppUsers() async {
    deleteCalled = true;
    return InactiveAppUserDeletionResult(
      runId: 'run-1',
      cutoff: DateTime.utc(2026, 7, 9),
      deletedCount: 1,
      failedCount: 0,
      skippedMissingActivity: 0,
      deletedDocumentCount: 12,
      deletedPublicUserIds: const ['USR-7K4P2Q'],
      failedPublicUserIds: const [],
    );
  }

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

class _PortalStaffRepository extends _Repository {
  @override
  AccessRole get currentAccessRole => AccessRole.portalStaff;
  @override
  bool get isSuperAdmin => false;
  @override
  User? get currentAuthUser => null;

  @override
  Stream<List<AppointmentModel>> watchAppointments() => Stream.value([
    AppointmentModel(
      id: 'appointment-1',
      userId: 'app-user-1',
      fullName: 'Scheduled app user',
      scheduledAt: DateTime(2026, 7, 21, 10),
      scheduledTime: '10:00 AM',
      location: 'PACC Office',
      status: 'pending',
      concern: 'Support request',
      contactNumber: 'hidden operational contact',
      email: 'appointment-contact@example.test',
      preferredContactMethod: 'Email',
      createdAt: DateTime(2026, 7, 17, 9),
    ),
  ]);

  @override
  Stream<List<UserModel>> watchUsers() =>
      throw StateError('Portal staff must not read private user profiles.');
}

class _PaginatedRepository extends _PortalStaffRepository {
  String lastSearch = '';

  @override
  Future<PublicAppUserPage> fetchPublicAppUsersPage({
    String? cursor,
    int pageSize = 25,
    String search = '',
    String role = '',
    String department = '',
    String course = '',
    String yearLevel = '',
  }) async {
    lastSearch = search;
    if (cursor == null) {
      return const PublicAppUserPage(
        users: [
          PublicAppUserRecord(
            publicUserId: 'USR-FIRST1',
            populationRole: PopulationRole.student,
          ),
        ],
        totalAppUsers: 2,
        nextCursor: 'USR-FIRST1',
      );
    }
    return const PublicAppUserPage(
      users: [
        PublicAppUserRecord(publicUserId: 'USR-SECOND2', populationRole: null),
      ],
      totalAppUsers: 2,
    );
  }
}

class _AppointmentActionsRepository extends _PortalStaffRepository {
  AppointmentModel _appointment(String id, String status) => AppointmentModel(
    id: id,
    userId: 'app-user-$id',
    fullName: 'App user $id',
    scheduledAt: DateTime(2026, 7, 21, 10),
    scheduledTime: '10:00 AM',
    location: 'PACC Office',
    status: status,
    concern: 'Support request',
    contactNumber: 'operational contact',
    email: 'appointment-contact@example.test',
    preferredContactMethod: 'Email',
    createdAt: DateTime(2026, 7, 17, 9),
  );

  @override
  Stream<List<AppointmentModel>> watchAppointments() => Stream.value([
    _appointment('pending', 'pending'),
    _appointment('confirmed', 'confirmed'),
    _appointment('ongoing', 'ongoing'),
    _appointment('proposal', 'reschedule_proposed'),
    _appointment('completed', 'completed'),
  ]);
}

class _CounselorRepository extends _PortalStaffRepository {
  @override
  AccessRole get currentAccessRole => AccessRole.counselor;

  @override
  Future<AdminDashboardSummary> getAppUserDashboardSummary() async =>
      const AdminDashboardSummary(
        totalAppUsers: 10,
        activeAppUsers: 4,
        populationCounts: {
          'student': 6,
          'teaching': 2,
          'nonTeaching': 2,
          'unknown': 0,
        },
        portalCounts: {'portalStaff': 3, 'counselor': 2, 'admin': 1},
        monthlyActiveUsers: {
          '2026-02': 1,
          '2026-03': 2,
          '2026-04': 3,
          '2026-05': 4,
          '2026-06': 5,
          '2026-07': 6,
        },
      );

  @override
  Stream<List<AdminInquiryModel>> watchInquiries() => Stream.value(const []);
  @override
  Stream<List<AdminAssessmentRecord>> watchAssessments() =>
      Stream.value(const []);
  @override
  Stream<List<AdminActivityAnalyticsModel>> watchActivityAnalytics() =>
      Stream.value(const []);
  @override
  Stream<List<AdminMindAidAnalyticsModel>> watchMindAidAnalytics() =>
      Stream.value(const []);
}

void main() {
  testWidgets('app users expose only anonymous academic fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: UserManagementPage(repository: _Repository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('USR-7K4P2Q'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('College of Computing'), findsOneWidget);
    expect(find.text('BS Information Technology'), findsOneWidget);
    expect(find.text('3rd Year'), findsOneWidget);
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
    expect(find.text('Delete inactive test users'), findsNothing);
  });

  testWidgets('approved portal staff can use only the anonymous directory', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: UserManagementPage(repository: _PortalStaffRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('USR-7K4P2Q'), findsOneWidget);
    expect(find.textContaining('Staff / Counselors'), findsNothing);
    expect(find.textContaining('Super-administrator access'), findsNothing);
  });

  testWidgets(
    'portal staff navigation exposes directory and appointments only',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: AdminPortalHome(repository: _PortalStaffRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('User Management'), findsWidgets);
      expect(find.text('Appointments'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Assessments'), findsNothing);
      expect(find.text('Inquiries'), findsNothing);

      await tester.tap(find.text('Appointments'));
      await tester.pumpAndSettle();
      expect(find.text('Active queue'), findsWidgets);
      expect(find.text('Pending'), findsWidgets);
      expect(find.textContaining('PACC Office'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
    },
  );

  testWidgets('appointment lifecycle actions are visible without a dropdown', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AdminPortalHome(repository: _AppointmentActionsRepository()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Appointments'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Start session'), findsOneWidget);
    expect(find.text('Complete session'), findsOneWidget);
    expect(find.text('Replace proposal'), findsOneWidget);
    expect(find.text('Withdraw proposal'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);

    await tester.tap(find.text('History / Archive'));
    await tester.pumpAndSettle();
    expect(find.text('Schedule follow-up'), findsOneWidget);
  });

  testWidgets('anonymous directory paginates and sends search to the server', (
    tester,
  ) async {
    final repository = _PaginatedRepository();
    await tester.pumpWidget(
      MaterialApp(home: UserManagementPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('USR-FIRST1'), findsOneWidget);
    await tester.ensureVisible(find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('USR-SECOND2'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'USR');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(repository.lastSearch, 'usr');
  });

  testWidgets('counselor dashboard shows app and portal counts separately', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: AdminPortalHome(repository: _CounselorRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total App Users'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Portal Staff'), findsOneWidget);
    expect(find.text('Counselors'), findsOneWidget);
    expect(find.text('Administrators'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
  });

  testWidgets(
    'debug cleanup requires typed confirmation and invokes deletion',
    (tester) async {
      final repository = _Repository();
      await tester.pumpWidget(
        MaterialApp(home: UserManagementPage(repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete inactive test users'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text('Permanently delete inactive test users?'),
        findsOneWidget,
      );
      expect(find.textContaining('USR-7K4P2Q'), findsWidgets);

      final deleteButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Delete permanently'),
      );
      expect(deleteButton.onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'DELETE');
      await tester.pump();
      await tester.tap(find.text('Delete permanently'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(repository.deleteCalled, isTrue);
      expect(find.text('Inactive-user cleanup finished'), findsOneWidget);
    },
  );

  testWidgets('debug cleanup is absent from the admin category', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: UserManagementPage(repository: _Repository())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Delete inactive test users'), findsNothing);
  });
}
