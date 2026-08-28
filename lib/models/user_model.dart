import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/quick_assessment/models/quick_assessment_models.dart';
import 'profile_roles.dart';
import '../features/admin/domain/admin_management_models.dart';

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.firstName,
    this.middleName,
    this.lastName,
    this.schoolId,
    this.employeeId,
    this.department,
    this.departmentId,
    this.collegeId,
    this.courseId,
    this.course,
    this.yearLevel,
    this.sector,
    this.position,
    this.role,
    this.populationRole,
    this.declaredRole,
    this.accessRole = AccessRole.appUser,
    this.staffAccountStatus,
    this.mustChangePassword = false,
    this.passwordChangedAt,
    this.verifiedAt,
    this.verifiedBy,
    this.profileVersion = 2,
    this.createdAt,
    this.dayStreak = 0,
    this.longestStreak = 0,
    this.lastActivityDateKey,
    this.lastActiveAt,
    this.lastQualifyingActivityDateKey,
    this.lastQualifyingActivityAt,
    this.activeDateKeys = const [],
    this.avatarAssetName,
    this.quickAssessmentCompleted = false,
    this.quickAssessmentCompletedAt,
  });

  final String id;
  final String email;
  final String? name;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? schoolId;
  final String? employeeId;
  final String? department;
  final String? departmentId;
  final String? collegeId;
  final String? courseId;
  final String? course;
  final String? yearLevel;
  final String? sector;
  final String? position;

  /// Legacy compatibility field. New authorization must never use this value.
  final String? role;
  final PopulationRole? populationRole;
  final PopulationRole? declaredRole;
  final AccessRole accessRole;
  final StaffAccountStatus? staffAccountStatus;
  final bool mustChangePassword;
  final DateTime? passwordChangedAt;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final int profileVersion;
  final DateTime? createdAt;
  final int dayStreak;
  final int longestStreak;
  final String? lastActivityDateKey;
  final DateTime? lastActiveAt;
  final String? lastQualifyingActivityDateKey;
  final DateTime? lastQualifyingActivityAt;
  final List<String> activeDateKeys;
  final String? avatarAssetName;
  final bool quickAssessmentCompleted;
  final DateTime? quickAssessmentCompletedAt;

  String get displayName {
    final parts =
        [
              firstName,
              if ((middleName ?? '').trim().isNotEmpty) middleName,
              lastName,
            ]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();

    if (parts.isNotEmpty) return parts.join(' ');
    if ((name ?? '').trim().isNotEmpty) return name!.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return 'MindMate User';
  }

  String get roleLabel {
    return effectivePopulationRole?.label ??
        switch (accessRole) {
          AccessRole.appUser => 'User',
          AccessRole.portalStaff => 'Portal Staff',
          AccessRole.counselor => 'Counselor',
          AccessRole.admin => 'Admin',
        };
  }

  PopulationRole? get effectivePopulationRole =>
      populationRole ?? declaredRole ?? PopulationRole.parse(role);
  AssessmentRole? get assessmentRole =>
      AssessmentRole.fromPopulationRole(effectivePopulationRole);
  bool get isProfileComplete {
    final base =
        displayName.trim().isNotEmpty && effectivePopulationRole != null;
    return switch (effectivePopulationRole) {
      PopulationRole.student =>
        base &&
            _present(schoolId) &&
            _present(department) &&
            _present(course) &&
            _present(yearLevel),
      PopulationRole.teaching =>
        base &&
            _present(employeeId) &&
            _present(department) &&
            _present(position),
      PopulationRole.nonTeaching =>
        base && _present(employeeId) && _present(sector) && _present(position),
      null => false,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? firstName,
    String? middleName,
    String? lastName,
    String? schoolId,
    String? employeeId,
    String? department,
    String? departmentId,
    String? collegeId,
    String? courseId,
    String? course,
    String? yearLevel,
    String? sector,
    String? position,
    String? role,
    PopulationRole? populationRole,
    PopulationRole? declaredRole,
    AccessRole? accessRole,
    StaffAccountStatus? staffAccountStatus,
    bool? mustChangePassword,
    DateTime? passwordChangedAt,
    DateTime? verifiedAt,
    String? verifiedBy,
    int? profileVersion,
    DateTime? createdAt,
    int? dayStreak,
    int? longestStreak,
    String? lastActivityDateKey,
    DateTime? lastActiveAt,
    String? lastQualifyingActivityDateKey,
    DateTime? lastQualifyingActivityAt,
    List<String>? activeDateKeys,
    String? avatarAssetName,
    bool? quickAssessmentCompleted,
    DateTime? quickAssessmentCompletedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      schoolId: schoolId ?? this.schoolId,
      employeeId: employeeId ?? this.employeeId,
      department: department ?? this.department,
      departmentId: departmentId ?? this.departmentId,
      collegeId: collegeId ?? this.collegeId,
      courseId: courseId ?? this.courseId,
      course: course ?? this.course,
      yearLevel: yearLevel ?? this.yearLevel,
      sector: sector ?? this.sector,
      position: position ?? this.position,
      role: role ?? this.role,
      populationRole: populationRole ?? this.populationRole,
      declaredRole: declaredRole ?? this.declaredRole,
      accessRole: accessRole ?? this.accessRole,
      staffAccountStatus: staffAccountStatus ?? this.staffAccountStatus,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      passwordChangedAt: passwordChangedAt ?? this.passwordChangedAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      profileVersion: profileVersion ?? this.profileVersion,
      createdAt: createdAt ?? this.createdAt,
      dayStreak: dayStreak ?? this.dayStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActivityDateKey: lastActivityDateKey ?? this.lastActivityDateKey,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      lastQualifyingActivityDateKey:
          lastQualifyingActivityDateKey ?? this.lastQualifyingActivityDateKey,
      lastQualifyingActivityAt:
          lastQualifyingActivityAt ?? this.lastQualifyingActivityAt,
      activeDateKeys: activeDateKeys ?? this.activeDateKeys,
      avatarAssetName: avatarAssetName ?? this.avatarAssetName,
      quickAssessmentCompleted:
          quickAssessmentCompleted ?? this.quickAssessmentCompleted,
      quickAssessmentCompletedAt:
          quickAssessmentCompletedAt ?? this.quickAssessmentCompletedAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json, {String? id}) {
    final legacyRole = _stringOrNull(json['role']);
    final canonicalRole = PopulationRole.parse(json['populationRole']);
    final declaredRole = PopulationRole.parse(json['declaredRole']);
    final legacyPopulation = PopulationRole.parse(legacyRole);
    return UserModel(
      id: (json['id'] ?? id ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: _stringOrNull(json['name']),
      firstName: _stringOrNull(json['firstName']),
      middleName: _stringOrNull(json['middleName']),
      lastName: _stringOrNull(json['lastName']),
      schoolId: _stringOrNull(json['schoolId']),
      employeeId: _stringOrNull(json['employeeId']),
      department: _stringOrNull(json['department']),
      departmentId: _stringOrNull(json['departmentId']),
      collegeId: _stringOrNull(json['collegeId']),
      courseId: _stringOrNull(json['courseId']),
      course: _stringOrNull(json['course']),
      yearLevel: _stringOrNull(json['yearLevel']),
      sector: _stringOrNull(json['sector']),
      position: _stringOrNull(json['position']),
      role: legacyRole,
      populationRole: canonicalRole ?? legacyPopulation,
      declaredRole: declaredRole ?? canonicalRole ?? legacyPopulation,
      accessRole: AccessRole.parse(json['accessRole'], legacyRole: legacyRole),
      staffAccountStatus: StaffAccountStatus.parse(json['staffAccountStatus']),
      mustChangePassword: json['mustChangePassword'] == true,
      passwordChangedAt: _dateOrNull(json['passwordChangedAt']),
      verifiedAt: _dateOrNull(json['verifiedAt']),
      verifiedBy: _stringOrNull(json['verifiedBy']),
      profileVersion: _intOrDefault(json['profileVersion'], 1),
      createdAt: _dateOrNull(json['createdAt']),
      dayStreak: _intOrZero(json['dayStreak']),
      longestStreak: _intOrZero(json['longestStreak']),
      lastActivityDateKey: _stringOrNull(json['lastActivityDateKey']),
      lastActiveAt: _dateOrNull(json['lastActiveAt']),
      lastQualifyingActivityDateKey: _stringOrNull(
        json['lastQualifyingActivityDateKey'],
      ),
      lastQualifyingActivityAt: _dateOrNull(json['lastQualifyingActivityAt']),
      activeDateKeys: _stringList(json['activeDateKeys']),
      avatarAssetName: _stringOrNull(json['avatarAssetName']),
      quickAssessmentCompleted: json['quickAssessmentCompleted'] == true,
      quickAssessmentCompletedAt: _dateOrNull(
        json['quickAssessmentCompletedAt'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': displayName,
      'firstName': firstName ?? '',
      'middleName': middleName ?? '',
      'lastName': lastName ?? '',
      'schoolId': schoolId ?? '',
      'employeeId': employeeId ?? '',
      'department': department ?? '',
      'departmentId': departmentId ?? '',
      'collegeId': collegeId ?? '',
      'courseId': courseId ?? '',
      'course': course ?? '',
      'yearLevel': yearLevel ?? '',
      'sector': sector ?? '',
      'position': position ?? '',
      'role': role ?? '',
      'populationRole': populationRole?.storedValue ?? '',
      'declaredRole': declaredRole?.storedValue ?? '',
      'accessRole': accessRole.storedValue,
      if (staffAccountStatus != null)
        'staffAccountStatus': staffAccountStatus!.name,
      'mustChangePassword': mustChangePassword,
      'passwordChangedAt': passwordChangedAt?.toIso8601String(),
      if (staffAccountStatus != null || accessRole != AccessRole.appUser) ...{
        'verifiedAt': verifiedAt?.toIso8601String(),
        'verifiedBy': verifiedBy ?? '',
      },
      'profileVersion': profileVersion,
      'createdAt': createdAt?.toIso8601String(),
      'dayStreak': dayStreak,
      'longestStreak': longestStreak,
      'lastActivityDateKey': lastActivityDateKey ?? '',
      'lastActiveAt': lastActiveAt?.toIso8601String(),
      'lastQualifyingActivityDateKey': lastQualifyingActivityDateKey ?? '',
      'lastQualifyingActivityAt': lastQualifyingActivityAt?.toIso8601String(),
      'activeDateKeys': activeDateKeys,
      'avatarAssetName': avatarAssetName ?? '',
      'quickAssessmentCompleted': quickAssessmentCompleted,
      'quickAssessmentCompletedAt': quickAssessmentCompletedAt
          ?.toIso8601String(),
    };
  }

  Map<String, dynamic> toProfileUpdateJson() {
    return {
      'firstName': firstName?.trim() ?? '',
      'middleName': middleName?.trim() ?? '',
      'lastName': lastName?.trim() ?? '',
      'avatarAssetName': avatarAssetName?.trim() ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) return null;
    final text = value.toString();
    return text.trim().isEmpty ? null : text;
  }

  static DateTime? _dateOrNull(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value.toString());
  }

  static int _intOrZero(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  static int _intOrDefault(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static bool _present(String? value) => value?.trim().isNotEmpty == true;

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
  }
}
