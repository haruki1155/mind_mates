import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../database/firestore_collections.dart';
import '../models/admin_inquiry_model.dart';
import '../models/admin_activity_analytics_model.dart';
import '../models/admin_mind_aid_analytics_model.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../models/profile_roles.dart';
import '../features/admin/domain/admin_management_models.dart';
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
        score: data['score'] is num
            ? data['score'] as num
            : num.tryParse('${data['score']}'),
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
}

class AdminRoleCorrectionRequest {
  const AdminRoleCorrectionRequest({
    required this.id,
    required this.userId,
    required this.currentRole,
    required this.requestedRole,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String currentRole;
  final String requestedRole;
  final String reason;
  final String status;
  final DateTime createdAt;

  factory AdminRoleCorrectionRequest.fromJson(Map<String, dynamic> data) =>
      AdminRoleCorrectionRequest(
        id: data['id']?.toString() ?? '',
        userId: data['userId']?.toString() ?? '',
        currentRole: data['currentRole']?.toString() ?? '',
        requestedRole: data['requestedRole']?.toString() ?? '',
        reason: data['reason']?.toString() ?? '',
        status: data['status']?.toString() ?? 'pending',
        createdAt: AdminAssessmentRecord._date(data['createdAt']),
      );
}

class AdminPortalRepository {
  AdminPortalRepository({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;
  AccessRole _currentAccessRole = AccessRole.appUser;
  AccessRole get currentAccessRole => _currentAccessRole;

  Future<void> signInStaff({
    required String schoolId,
    required String password,
  }) async {
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: schoolId.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw StateError('Unable to identify staff account.');
    final profile = await _firestoreService.getDocument(
      FirestoreCollections.users,
      user.uid,
    );
    final role = AccessRole.parse(
      profile?['accessRole'],
      legacyRole: profile?['role'],
    );
    final status = StaffAccountStatus.parse(profile?['staffAccountStatus']);
    if (status == StaffAccountStatus.pending) {
      throw StateError(
        'Your staff registration is awaiting administrator approval.',
      );
    }
    if (status == StaffAccountStatus.rejected) {
      await FirebaseAuth.instance.signOut();
      throw StateError(
        'Your staff registration was rejected. Contact the administrator.',
      );
    }
    if (status == StaffAccountStatus.disabled) {
      await FirebaseAuth.instance.signOut();
      throw StateError('This staff account is disabled.');
    }
    if (!role.canUsePortal) {
      await FirebaseAuth.instance.signOut();
      throw StateError('This account does not have staff access.');
    }
    _currentAccessRole = role;
  }

  User? get currentAuthUser => FirebaseAuth.instance.currentUser;
  Stream<User?> get authStateChanges =>
      FirebaseAuth.instance.authStateChanges();

  Future<bool> restoreSession() async {
    final user = currentAuthUser;
    if (user == null) return false;
    final profile = await _firestoreService.getDocument(
      FirestoreCollections.users,
      user.uid,
    );
    final status = StaffAccountStatus.parse(profile?['staffAccountStatus']);
    final role = AccessRole.parse(
      profile?['accessRole'],
      legacyRole: profile?['role'],
    );
    if (status == StaffAccountStatus.approved ||
        (status == null && role.canUsePortal)) {
      _currentAccessRole = role;
      return role.canUsePortal;
    }
    return false;
  }

  Future<void> registerStaff({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String employeeId,
    required String position,
    required String departmentId,
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
          .httpsCallable('registerStaffAccount')
          .call({
            'firstName': firstName.trim(),
            'lastName': lastName.trim(),
            'employeeId': employeeId.trim(),
            'position': position.trim(),
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
  Future<void> signOut() => FirebaseAuth.instance.signOut();

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

  Stream<List<AdminRoleCorrectionRequest>> watchRoleCorrectionRequests() =>
      _firestoreService
          .watchDocuments(FirestoreCollections.roleCorrectionRequests)
          .map(
            (items) =>
                items
                    .map(AdminRoleCorrectionRequest.fromJson)
                    .where((item) => item.status == 'pending')
                    .toList()
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
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
  }) async {
    final data = <String, dynamic>{
      'appointmentId': appointmentId,
      'action': action,
      'reply': reply,
      if (proposedScheduledAt != null)
        'proposedScheduledAt': proposedScheduledAt.millisecondsSinceEpoch,
    };
    if (proposedScheduledTime != null) {
      data['proposedScheduledTime'] = proposedScheduledTime;
    }
    await FirebaseFunctions.instance
        .httpsCallable('reviewAppointment')
        .call(data);
  }

  Future<void> reviewProfileVerification({
    required String userId,
    required VerificationStatus decision,
    required String reason,
  }) async {
    await FirebaseFunctions.instance
        .httpsCallable('reviewProfileVerification')
        .call({
          'userId': userId,
          'decision': decision.storedValue,
          'reason': reason.trim(),
        });
  }

  Future<void> assignAccessRole({
    required String userId,
    required AccessRole accessRole,
    required String reason,
  }) async {
    await FirebaseFunctions.instance.httpsCallable('assignAccessRole').call({
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
  }) =>
      FirebaseFunctions.instance.httpsCallable('reviewStaffRegistration').call({
        'userId': userId,
        'approve': approve,
        'accessRole': accessRole.storedValue,
        'reason': reason.trim(),
      });

  Future<void> setStaffAccountEnabled({
    required String userId,
    required bool enabled,
    required String reason,
  }) => FirebaseFunctions.instance.httpsCallable('setStaffAccountEnabled').call(
    {'userId': userId, 'enabled': enabled, 'reason': reason.trim()},
  );

  Future<void> saveOrganizationRecord({
    required String kind,
    String? id,
    required String name,
    required String code,
    required bool active,
    String collegeId = '',
  }) =>
      FirebaseFunctions.instance.httpsCallable('saveOrganizationRecord').call({
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
  }) =>
      FirebaseFunctions.instance.httpsCallable('updateStaffOrganization').call({
        'userId': userId,
        'departmentId': departmentId,
        'collegeId': collegeId,
        'courseId': courseId,
        'reason': reason,
      });

  Future<void> reviewRoleCorrection({
    required String requestId,
    required bool approve,
    required String reason,
  }) async {
    await FirebaseFunctions.instance.httpsCallable('reviewRoleCorrection').call(
      {'requestId': requestId, 'approve': approve, 'reason': reason.trim()},
    );
  }

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
