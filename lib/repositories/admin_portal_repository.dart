import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

import '../database/firestore_collections.dart';
import '../models/admin_inquiry_model.dart';
import '../models/admin_activity_analytics_model.dart';
import '../models/admin_mind_aid_analytics_model.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../models/profile_roles.dart';
import '../features/admin/domain/admin_auth_failure.dart';
import '../features/admin/domain/admin_management_models.dart';
import '../features/admin/domain/admin_session_policy.dart';
import '../features/admin/domain/service_monitoring_models.dart';
import '../services/firebase/firebase_app_check_service.dart';
import '../services/firebase/firebase_callable_router.dart';
import '../services/firebase/firebase_runtime_diagnostics.dart';
import '../services/firebase/firestore_service.dart';

class AdminAssessmentRecord {
  const AdminAssessmentRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.createdAt,
    this.score,
    this.status,
    this.role,
  });

  final String id;
  final String userId;
  final String type;
  final DateTime createdAt;
  final num? score;
  final String? status;
  final String? role;

  factory AdminAssessmentRecord.fromJson(Map<String, dynamic> data) =>
      AdminAssessmentRecord(
        id: data['id']?.toString() ?? '',
        userId: data['userId']?.toString() ?? '',
        type: data['type']?.toString() ?? 'Assessment',
        createdAt: _date(data['createdAt']),
        score: _number(
          data['overallScore'] ?? data['concernScore'] ?? data['score'],
        ),
        status: _text(data['status'] ?? data['overallLevel']),
        role: _text(data['populationRole'] ?? data['role']),
      );

  static DateTime _date(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse('$value') ?? DateTime.now();
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static num? _number(Object? value) {
    if (value is num) return value;
    return num.tryParse('$value');
  }
}

class CounselorSleepSummaryRecord {
  const CounselorSleepSummaryRecord({
    required this.id,
    required this.loggedDays,
    required this.windowDays,
    required this.averageSleepMinutes,
    required this.averageQuality,
    required this.averageSleepiness,
    required this.expiresAt,
    required this.guidanceShown,
  });

  final String id;
  final int loggedDays;
  final int windowDays;
  final double? averageSleepMinutes;
  final double? averageQuality;
  final double? averageSleepiness;
  final DateTime expiresAt;
  final Map<String, dynamic> guidanceShown;

  factory CounselorSleepSummaryRecord.fromJson(
    Map<String, dynamic> data,
  ) => CounselorSleepSummaryRecord(
    id: data['id']?.toString() ?? '',
    loggedDays: AdminAssessmentRecord._number(data['loggedDays'])?.toInt() ?? 0,
    windowDays: AdminAssessmentRecord._number(data['windowDays'])?.toInt() ?? 0,
    averageSleepMinutes: AdminAssessmentRecord._number(
      data['averageEstimatedSleepMinutes'],
    )?.toDouble(),
    averageQuality: AdminAssessmentRecord._number(
      data['averageQuality'],
    )?.toDouble(),
    averageSleepiness: AdminAssessmentRecord._number(
      data['averageSleepiness'],
    )?.toDouble(),
    expiresAt: AdminAssessmentRecord._date(data['expiresAt']),
    guidanceShown: Map<String, dynamic>.from(
      data['guidanceShown'] as Map? ?? const {},
    ),
  );
}

class AdminPortalRepository {
  AdminPortalRepository({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;
  AccessRole _currentAccessRole = AccessRole.appUser;
  AccessRole get currentAccessRole => _currentAccessRole;
  bool _isSuperAdmin = false;
  bool get isSuperAdmin => _isSuperAdmin;
  bool _mustChangePassword = false;
  bool get mustChangePassword => _mustChangePassword;

  Stream<List<CounselorSleepSummaryRecord>> watchCounselorSleepSummaries(
    String counselorId,
  ) => _firestoreService
      .watchDocuments(
        FirestoreCollections.sleepSharedSummaries,
        whereEquals: {'counselorId': counselorId},
        orderBy: 'expiresAt',
      )
      .map(
        (docs) => docs
            .map(CounselorSleepSummaryRecord.fromJson)
            .where((summary) => summary.expiresAt.isAfter(DateTime.now()))
            .toList(growable: false),
      );

  Future<void> setCounselorSleepAssignment({
    required String studentId,
    required String counselorId,
    required bool active,
  }) async {
    await FirebaseAppCheckService.requireToken();
    await FirebaseFunctions.instance
        .routedCallable('setCounselorAssignment')
        .call({
          'studentId': studentId,
          'counselorId': counselorId,
          'active': active,
        });
  }

  Future<void> signInStaff({
    required String schoolId,
    required String password,
  }) async {
    UserCredential credential;
    try {
      credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: schoolId.trim(),
        password: password,
      );
    } catch (error, stackTrace) {
      _logAuthenticationFailure(error, stackTrace, 'admin_auth_credentials');
      throw AdminAuthenticationException.fromFirebase(
        error,
        stage: AdminAuthenticationStage.credentials,
        fallback: 'Unable to sign in to the Admin portal.',
      );
    }
    final user = credential.user;
    if (user == null) {
      throw const AdminAuthenticationException(
        stage: AdminAuthenticationStage.credentials,
        code: 'missing-user',
        userMessage: 'Unable to identify the administrator account.',
      );
    }
    await _establishStaffSession(user);
  }

  Future<void> _establishStaffSession(User user) async {
    try {
      await user.getIdToken(true);
      await FirebaseAppCheckService.refreshToken();
      await FirebaseAppCheckService.requireToken();
    } catch (error, stackTrace) {
      await _rejectSession();
      _logAuthenticationFailure(error, stackTrace, 'admin_auth_app_check');
      throw AdminAuthenticationException.fromFirebase(
        error,
        stage: AdminAuthenticationStage.appCheck,
        fallback:
            'This Admin web session could not be verified by Firebase App Check.',
      );
    }

    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser ?? user;
    Map<String, dynamic>? profile;
    try {
      profile = await _firestoreService.getDocument(
        FirestoreCollections.users,
        refreshedUser.uid,
      );
    } catch (error, stackTrace) {
      await _rejectSession();
      _logAuthenticationFailure(error, stackTrace, 'admin_auth_profile');
      throw AdminAuthenticationException.fromFirebase(
        error,
        stage: AdminAuthenticationStage.profile,
        fallback: 'Unable to load the portal account profile.',
      );
    }
    if (profile == null) {
      await _rejectSession();
      throw const AdminAuthenticationException(
        stage: AdminAuthenticationStage.profile,
        code: 'profile-not-found',
        userMessage:
            'Authentication succeeded, but the portal account profile is missing.',
      );
    }
    final role = AccessRole.parse(
      profile['accessRole'],
      legacyRole: profile['role'],
    );
    final status = StaffAccountStatus.parse(profile['staffAccountStatus']);
    _mustChangePassword = profile['mustChangePassword'] == true;
    final decision = evaluateAdminSession(
      accessRole: role,
      staffAccountStatus: status,
      emailVerified: refreshedUser.emailVerified,
    );
    switch (decision) {
      case AdminSessionDecision.pending:
        await _rejectSession();
        throw const AdminAuthenticationException(
          stage: AdminAuthenticationStage.authorization,
          code: 'staff-pending',
          userMessage: 'This staff account is awaiting administrator approval.',
        );
      case AdminSessionDecision.rejected:
        await _rejectSession();
        throw const AdminAuthenticationException(
          stage: AdminAuthenticationStage.authorization,
          code: 'staff-rejected',
          userMessage: 'This staff registration was rejected.',
        );
      case AdminSessionDecision.disabled:
        await _rejectSession();
        throw const AdminAuthenticationException(
          stage: AdminAuthenticationStage.authorization,
          code: 'staff-disabled',
          userMessage: 'This staff account is disabled.',
        );
      case AdminSessionDecision.denied:
        await _rejectSession();
        throw const AdminAuthenticationException(
          stage: AdminAuthenticationStage.authorization,
          code: 'staff-access-required',
          userMessage: 'This account does not have portal access.',
        );
      case AdminSessionDecision.requireSuperAdminEmailVerification:
        try {
          await refreshedUser.sendEmailVerification();
        } catch (_) {
          // Keep delivery-provider details off the authentication surface.
        }
        await _rejectSession();
        throw const AdminAuthenticationException(
          stage: AdminAuthenticationStage.emailVerification,
          code: 'email-not-verified',
          userMessage:
              'Verify the super-administrator email address using the message Firebase sent, then sign in again.',
        );
      case AdminSessionDecision.allowSuperAdmin:
        try {
          await _confirmSuperAdmin();
          _isSuperAdmin = true;
        } catch (error, stackTrace) {
          await _rejectSession();
          _logAuthenticationFailure(
            error,
            stackTrace,
            'admin_auth_super_admin_confirmation',
          );
          if (error is AdminAuthenticationException) rethrow;
          throw AdminAuthenticationException.fromFirebase(
            error,
            stage: AdminAuthenticationStage.superAdminConfirmation,
            fallback: 'Unable to confirm super-administrator access.',
          );
        }
        break;
      case AdminSessionDecision.allowPortalStaff:
      case AdminSessionDecision.allowCounselor:
        _isSuperAdmin = false;
        break;
    }
    _currentAccessRole = role;
  }

  User? get currentAuthUser => FirebaseAuth.instance.currentUser;
  Stream<User?> get authStateChanges =>
      FirebaseAuth.instance.authStateChanges();

  Future<bool> restoreSession() async {
    final user = currentAuthUser;
    if (user == null) return false;
    try {
      await _establishStaffSession(user);
      return true;
    } catch (error, stackTrace) {
      _logAuthenticationFailure(error, stackTrace, 'admin_session_restore');
      return false;
    }
  }

  Future<void> registerStaff({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String employeeId,
    required String position,
    required String department,
    String departmentId = '',
    String collegeId = '',
    String courseId = '',
  }) async {
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
    try {
      await FirebaseFunctions.instance
          .routedCallable('registerStaffAccount')
          .call({
            'firstName': firstName.trim(),
            'lastName': lastName.trim(),
            'employeeId': employeeId.trim(),
            'position': position.trim(),
            'department': department.trim(),
            'departmentId': departmentId,
            'collegeId': collegeId,
            'courseId': courseId,
          });
    } catch (_) {
      await credential.user?.delete();
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) =>
      FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  Future<void> signOut() async {
    _currentAccessRole = AccessRole.appUser;
    _isSuperAdmin = false;
    _mustChangePassword = false;
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _confirmSuperAdmin() async {
    final result = await FirebaseFunctions.instance
        .routedCallable('confirmSuperAdmin')
        .call<Map<String, dynamic>>();
    if (result.data['isSuperAdmin'] != true) {
      throw AdminAuthenticationException(
        stage: AdminAuthenticationStage.superAdminConfirmation,
        code: 'super-admin-not-confirmed',
        userMessage: 'This account is not the configured super-administrator.',
        correlationId: result.data['correlationId']?.toString(),
      );
    }
  }

  Future<void> _rejectSession() async {
    _currentAccessRole = AccessRole.appUser;
    _isSuperAdmin = false;
    _mustChangePassword = false;
    await FirebaseAuth.instance.signOut();
  }

  void _logAuthenticationFailure(
    Object error,
    StackTrace stackTrace,
    String event,
  ) {
    FirebaseRuntimeDiagnostics.log(event: event, error: error);
  }

  Future<void> completeMandatoryPasswordChange(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Administrator session is missing.');
    await user.updatePassword(password);
    await FirebaseFunctions.instance
        .routedCallable('completeAdminPasswordChange')
        .call();
    _mustChangePassword = false;
    await user.getIdToken(true);
  }

  Stream<List<College>> watchColleges() => _firestoreService
      .watchDocuments(FirestoreCollections.colleges)
      .map(
        (v) =>
            v.map(College.fromJson).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );
  Stream<List<Department>> watchDepartments() => _firestoreService
      .watchDocuments(FirestoreCollections.departments)
      .map(
        (v) =>
            v.map(Department.fromJson).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );
  Stream<List<Course>> watchCourses() => _firestoreService
      .watchDocuments(FirestoreCollections.courses)
      .map(
        (v) =>
            v.map(Course.fromJson).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );

  Stream<List<AdminAuditEvent>> watchAdminAudit(String userId) =>
      _firestoreService
          .watchDocuments(
            FirestoreCollections.adminAuditLogs,
            whereEquals: {'targetUserId': userId},
          )
          .map(
            (items) => items.map(AdminAuditEvent.fromJson).toList()
              ..sort(
                (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
                  a.createdAt ?? DateTime(1970),
                ),
              ),
          );

  Future<List<PublicAppUserRecord>> listPublicAppUsers() async {
    return (await fetchPublicAppUsersPage()).users;
  }

  Future<PublicAppUserPage> fetchPublicAppUsersPage({
    String? cursor,
    int pageSize = 25,
    String search = '',
    String role = '',
    String department = '',
    String course = '',
    String yearLevel = '',
  }) async {
    await FirebaseAppCheckService.requireToken();
    final result = await FirebaseFunctions.instance
        .routedCallable('listPublicAppUsers')
        .call<Map<String, dynamic>>({
          'pageSize': pageSize,
          'cursor': cursor ?? '',
          'search': search,
          'role': role,
          'department': department,
          'course': course,
          'yearLevel': yearLevel,
        });
    final raw = result.data['users'];
    final users =
        (raw is List ? raw : const [])
            .whereType<Map>()
            .map(
              (item) =>
                  PublicAppUserRecord.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
          ..sort((a, b) => a.publicUserId.compareTo(b.publicUserId));
    return PublicAppUserPage(
      users: users,
      totalAppUsers:
          (result.data['totalAppUsers'] as num?)?.toInt() ?? users.length,
      nextCursor: result.data['nextCursor']?.toString(),
    );
  }

  Future<AdminDashboardSummary> getAppUserDashboardSummary() async {
    await FirebaseAppCheckService.requireToken();
    final result = await FirebaseFunctions.instance
        .routedCallable('getAppUserDashboardSummary')
        .call<Map<String, dynamic>>();
    return AdminDashboardSummary.fromJson(result.data);
  }

  Future<AdminServiceMonitoringResponse> getAdminServiceMonitoring({
    int days = 7,
    String? serviceKey,
  }) async {
    if (![7, 30, 90].contains(days)) {
      throw ArgumentError('Monitoring range must be 7, 30, or 90 days.');
    }
    await FirebaseAppCheckService.requireToken();
    final result = await FirebaseFunctions.instance
        .routedCallable('getAdminServiceMonitoring')
        .call<Map<String, dynamic>>({
          'days': days,
          if (serviceKey != null && serviceKey.trim().isNotEmpty)
            'serviceKey': serviceKey.trim(),
        });
    return AdminServiceMonitoringResponse.fromJson(result.data);
  }

  Future<int> backfillPublicAppUserIds() async {
    final result = await FirebaseFunctions.instance
        .routedCallable('backfillPublicAppUserIds')
        .call<Map<String, dynamic>>();
    return (result.data['processed'] as num?)?.toInt() ?? 0;
  }

  Future<PreviewInactiveAppUserDeletionResult>
  previewInactiveAppUserDeletion() async {
    final result = await FirebaseFunctions.instance
        .routedCallable('previewInactiveAppUserDeletion')
        .call<Map<String, dynamic>>();
    return PreviewInactiveAppUserDeletionResult.fromJson(result.data);
  }

  Future<InactiveAppUserDeletionResult> deleteInactiveAppUsers() async {
    final result = await FirebaseFunctions.instance
        .routedCallable('deleteInactiveAppUsers')
        .call<Map<String, dynamic>>({'confirmation': 'DELETE'});
    return InactiveAppUserDeletionResult.fromJson(result.data);
  }

  Stream<List<UserModel>> watchUsers() => _firestoreService
      .watchDocuments(FirestoreCollections.users)
      .map(
        (items) =>
            items
                .map(
                  (item) =>
                      UserModel.fromJson(item, id: item['id']?.toString()),
                )
                .toList()
              ..sort((a, b) => a.displayName.compareTo(b.displayName)),
      );

  Stream<List<AppointmentModel>> watchAppointments() => _firestoreService
      .watchDocuments(FirestoreCollections.appointments)
      .map(
        (items) =>
            items
                .map(
                  (item) => AppointmentModel.fromJson(
                    item,
                    id: item['id']?.toString(),
                  ),
                )
                .toList()
              ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt)),
      );

  Stream<List<AppointmentHistoryEvent>> watchAppointmentHistory(
    String appointmentId,
  ) => _firestoreService.firestore
      .collection(FirestoreCollections.appointments)
      .doc(appointmentId)
      .collection('history')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs
                .map(
                  (document) => AppointmentHistoryEvent.fromJson(
                    document.data(),
                    id: document.id,
                  ),
                )
                .toList()
              ..sort(
                (a, b) => (b.createdAt ?? DateTime(1970)).compareTo(
                  a.createdAt ?? DateTime(1970),
                ),
              ),
      );

  Stream<List<AdminAssessmentRecord>> watchAssessments() => _firestoreService
      .watchDocuments(FirestoreCollections.assessments)
      .map(
        (items) =>
            items.map(AdminAssessmentRecord.fromJson).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  Stream<List<AdminInquiryModel>> watchInquiries() => _firestoreService
      .watchDocuments(FirestoreCollections.inquiries)
      .map(
        (items) =>
            items
                .map(
                  (item) => AdminInquiryModel.fromJson(
                    item,
                    id: item['id']?.toString(),
                  ),
                )
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  Stream<List<AdminActivityAnalyticsModel>> watchActivityAnalytics() =>
      _firestoreService
          .watchDocuments(FirestoreCollections.analyticsDaily)
          .map(
            (items) =>
                items.map(AdminActivityAnalyticsModel.fromJson).toList()
                  ..sort((a, b) => b.dateKey.compareTo(a.dateKey)),
          );

  Stream<List<AdminMindAidAnalyticsModel>> watchMindAidAnalytics() =>
      _firestoreService
          .watchDocuments(FirestoreCollections.mindAidAnalyticsDaily)
          .map(
            (items) =>
                items.map(AdminMindAidAnalyticsModel.fromJson).toList()
                  ..sort((a, b) => b.dateKey.compareTo(a.dateKey)),
          );

  Future<void> reviewAppointment({
    required String appointmentId,
    required String action,
    required String reply,
    DateTime? proposedScheduledAt,
    String? proposedScheduledTime,
    String? operationId,
  }) async {
    await FirebaseAppCheckService.requireToken();
    final data = <String, dynamic>{
      'appointmentId': appointmentId,
      'action': action,
      'reply': reply,
      'operationId': operationId ?? newOperationId(),
      if (proposedScheduledAt != null)
        'proposedScheduledAt': proposedScheduledAt.millisecondsSinceEpoch,
    };
    if (proposedScheduledTime != null) {
      data['proposedScheduledTime'] = proposedScheduledTime;
    }
    await FirebaseFunctions.instance
        .routedCallable('reviewAppointment')
        .call(data);
  }

  Future<String> scheduleAppointmentFollowUp({
    required String sourceAppointmentId,
    required DateTime scheduledAt,
    required String scheduledTime,
    required String location,
    required String reply,
  }) async {
    await FirebaseAppCheckService.requireToken();
    final result = await FirebaseFunctions.instance
        .routedCallable('scheduleAppointmentFollowUp')
        .call<Map<String, dynamic>>({
          'sourceAppointmentId': sourceAppointmentId,
          'scheduledAt': scheduledAt.millisecondsSinceEpoch,
          'scheduledTime': scheduledTime.trim(),
          'location': location.trim(),
          'reply': reply.trim(),
        });
    return '${result.data['appointmentId'] ?? ''}';
  }

  static String newOperationId() {
    final random = Random.secure();
    final suffix = List.generate(
      12,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    return 'op_${DateTime.now().microsecondsSinceEpoch}_$suffix';
  }

  Future<void> assignAccessRole({
    required String userId,
    required AccessRole accessRole,
    required String reason,
  }) async {
    await FirebaseFunctions.instance.routedCallable('assignAccessRole').call({
      'userId': userId,
      'accessRole': accessRole.storedValue,
      'reason': reason.trim(),
    });
  }

  Future<void> reviewStaffRegistration({
    required String userId,
    required bool approve,
    required AccessRole accessRole,
    required String reason,
  }) => FirebaseFunctions.instance
      .routedCallable('reviewStaffRegistration')
      .call({
        'userId': userId,
        'approve': approve,
        'accessRole': accessRole.storedValue,
        'reason': reason.trim(),
      });

  Future<void> setStaffAccountEnabled({
    required String userId,
    required bool enabled,
    required String reason,
  }) => FirebaseFunctions.instance
      .routedCallable('setStaffAccountEnabled')
      .call({'userId': userId, 'enabled': enabled, 'reason': reason.trim()});

  Future<void> saveOrganizationRecord({
    required String kind,
    String? id,
    required String name,
    required String code,
    required bool active,
    String collegeId = '',
  }) =>
      FirebaseFunctions.instance.routedCallable('saveOrganizationRecord').call({
        'kind': kind,
        'id': ?id,
        'name': name,
        'code': code,
        'active': active,
        'collegeId': collegeId,
      });

  Future<void> updateStaffOrganization({
    required String userId,
    required String departmentId,
    required String collegeId,
    required String courseId,
    required String reason,
  }) => FirebaseFunctions.instance
      .routedCallable('updateStaffOrganization')
      .call({
        'userId': userId,
        'departmentId': departmentId,
        'collegeId': collegeId,
        'courseId': courseId,
        'reason': reason,
      });

  Future<void> updateInquiryStatus(String id, InquiryStatus status) =>
      _firestoreService.updateDocument(FirestoreCollections.inquiries, id, {
        'status': status.storedValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> updateOwnProfile(String userId, Map<String, dynamic> values) =>
      _firestoreService.updateDocument(
        FirestoreCollections.users,
        userId,
        values,
      );
}
