import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/profile_roles.dart';

enum StaffAccountStatus {
  pending,
  approved,
  rejected,
  disabled;

  String get label => switch (this) {
    pending => 'Pending',
    approved => 'Approved',
    rejected => 'Rejected',
    disabled => 'Disabled',
  };

  static StaffAccountStatus? parse(Object? value) =>
      switch (value?.toString()) {
        'pending' => pending,
        'approved' => approved,
        'rejected' => rejected,
        'disabled' => disabled,
        _ => null,
      };
}

class StaffRegistration {
  const StaffRegistration({
    required this.userId,
    required this.email,
    required this.employeeId,
    required this.status,
  });
  final String userId;
  final String email;
  final String employeeId;
  final StaffAccountStatus status;
}

class PublicAppUserRecord {
  const PublicAppUserRecord({
    required this.publicUserId,
    required this.populationRole,
    this.department = '',
    this.course = '',
    this.yearLevel = '',
  });

  final String publicUserId;
  final PopulationRole? populationRole;
  String get populationRoleLabel => populationRole?.label ?? 'Unknown';
  final String department;
  final String course;
  final String yearLevel;

  factory PublicAppUserRecord.fromJson(Map<String, dynamic> json) =>
      PublicAppUserRecord(
        publicUserId: '${json['publicUserId'] ?? ''}',
        populationRole: PopulationRole.parse(json['populationRole']),
        department: '${json['department'] ?? ''}'.trim(),
        course: '${json['course'] ?? ''}'.trim(),
        yearLevel: '${json['yearLevel'] ?? ''}'.trim(),
      );
}

class PublicAppUserPage {
  const PublicAppUserPage({
    required this.users,
    required this.totalAppUsers,
    this.nextCursor,
  });
  final List<PublicAppUserRecord> users;
  final int totalAppUsers;
  final String? nextCursor;
}

class AdminDashboardSummary {
  const AdminDashboardSummary({
    required this.totalAppUsers,
    required this.activeAppUsers,
    required this.populationCounts,
    required this.portalCounts,
    required this.monthlyActiveUsers,
  });
  final int totalAppUsers;
  final int activeAppUsers;
  final Map<String, int> populationCounts;
  final Map<String, int> portalCounts;
  final Map<String, int> monthlyActiveUsers;

  factory AdminDashboardSummary.fromJson(Map<String, dynamic> json) {
    Map<String, int> counts(Object? value) => value is Map
        ? value.map((key, value) => MapEntry('$key', (value as num?)?.toInt() ?? 0))
        : const {};
    return AdminDashboardSummary(
      totalAppUsers: (json['totalAppUsers'] as num?)?.toInt() ?? 0,
      activeAppUsers: (json['activeAppUsers'] as num?)?.toInt() ?? 0,
      populationCounts: counts(json['populationCounts']),
      portalCounts: counts(json['portalCounts']),
      monthlyActiveUsers: counts(json['monthlyActiveUsers']),
    );
  }
}

class PreviewInactiveAppUserDeletionResult {
  const PreviewInactiveAppUserDeletionResult({
    required this.cutoff,
    required this.inactiveDays,
    required this.eligibleCount,
    required this.skippedMissingActivity,
    required this.publicUserIds,
  });

  final DateTime cutoff;
  final int inactiveDays;
  final int eligibleCount;
  final int skippedMissingActivity;
  final List<String> publicUserIds;

  factory PreviewInactiveAppUserDeletionResult.fromJson(
    Map<String, dynamic> json,
  ) => PreviewInactiveAppUserDeletionResult(
    cutoff: DateTime.parse('${json['cutoff']}'),
    inactiveDays: (json['inactiveDays'] as num?)?.toInt() ?? 7,
    eligibleCount: (json['eligibleCount'] as num?)?.toInt() ?? 0,
    skippedMissingActivity:
        (json['skippedMissingActivity'] as num?)?.toInt() ?? 0,
    publicUserIds: (json['publicUserIds'] as List? ?? const [])
        .map((value) => '$value')
        .toList(growable: false),
  );
}

class InactiveAppUserDeletionResult {
  const InactiveAppUserDeletionResult({
    required this.runId,
    required this.cutoff,
    required this.deletedCount,
    required this.failedCount,
    required this.skippedMissingActivity,
    required this.deletedDocumentCount,
    required this.deletedPublicUserIds,
    required this.failedPublicUserIds,
  });

  final String runId;
  final DateTime cutoff;
  final int deletedCount;
  final int failedCount;
  final int skippedMissingActivity;
  final int deletedDocumentCount;
  final List<String> deletedPublicUserIds;
  final List<String> failedPublicUserIds;

  factory InactiveAppUserDeletionResult.fromJson(
    Map<String, dynamic> json,
  ) => InactiveAppUserDeletionResult(
    runId: '${json['runId'] ?? ''}',
    cutoff: DateTime.parse('${json['cutoff']}'),
    deletedCount: (json['deletedCount'] as num?)?.toInt() ?? 0,
    failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
    skippedMissingActivity:
        (json['skippedMissingActivity'] as num?)?.toInt() ?? 0,
    deletedDocumentCount: (json['deletedDocumentCount'] as num?)?.toInt() ?? 0,
    deletedPublicUserIds: (json['deletedPublicUserIds'] as List? ?? const [])
        .map((value) => '$value')
        .toList(growable: false),
    failedPublicUserIds: (json['failedPublicUserIds'] as List? ?? const [])
        .map((value) => '$value')
        .toList(growable: false),
  );
}

class OrganizationRecord {
  const OrganizationRecord({
    required this.id,
    required this.name,
    required this.code,
    required this.active,
  });
  final String id;
  final String name;
  final String code;
  final bool active;
}

class College extends OrganizationRecord {
  const College({
    required super.id,
    required super.name,
    required super.code,
    required super.active,
  });
  factory College.fromJson(Map<String, dynamic> json) => College(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    code: '${json['code'] ?? ''}',
    active: json['active'] == true,
  );
}

class Department extends OrganizationRecord {
  const Department({
    required super.id,
    required super.name,
    required super.code,
    required super.active,
  });
  factory Department.fromJson(Map<String, dynamic> json) => Department(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    code: '${json['code'] ?? ''}',
    active: json['active'] == true,
  );
}

class Course extends OrganizationRecord {
  const Course({
    required super.id,
    required super.name,
    required super.code,
    required super.active,
    required this.collegeId,
  });
  final String collegeId;
  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    code: '${json['code'] ?? ''}',
    active: json['active'] == true,
    collegeId: '${json['collegeId'] ?? ''}',
  );
}

class AdminAuditEvent {
  const AdminAuditEvent({
    required this.id,
    required this.action,
    required this.actorId,
    required this.targetUserId,
    required this.reason,
    this.createdAt,
  });
  final String id;
  final String action;
  final String actorId;
  final String targetUserId;
  final String reason;
  final DateTime? createdAt;
  factory AdminAuditEvent.fromJson(Map<String, dynamic> json) =>
      AdminAuditEvent(
        id: '${json['id'] ?? ''}',
        action: '${json['action'] ?? ''}',
        actorId: '${json['actorId'] ?? ''}',
        targetUserId: '${json['targetUserId'] ?? ''}',
        reason: '${json['reason'] ?? ''}',
        createdAt: json['createdAt'] is Timestamp
            ? (json['createdAt'] as Timestamp).toDate()
            : null,
      );
}
