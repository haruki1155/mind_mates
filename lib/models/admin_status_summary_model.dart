import '../core/utils/firestore_mapper.dart';

enum AdminUserStatus {
  severe,
  moderate,
  normal;

  String get label {
    switch (this) {
      case AdminUserStatus.severe:
        return 'Severe';
      case AdminUserStatus.moderate:
        return 'Moderate';
      case AdminUserStatus.normal:
        return 'Normal';
    }
  }

  int get rank {
    switch (this) {
      case AdminUserStatus.severe:
        return 0;
      case AdminUserStatus.moderate:
        return 1;
      case AdminUserStatus.normal:
        return 2;
    }
  }

  static AdminUserStatus fromString(Object? value) {
    final text = value?.toString().trim().toLowerCase();
    return AdminUserStatus.values.firstWhere(
      (status) => status.name == text,
      orElse: () => AdminUserStatus.normal,
    );
  }
}

class AdminStatusSummaryModel {
  const AdminStatusSummaryModel({
    required this.userId,
    required this.userLabel,
    required this.status,
    required this.updatedAt,
    this.role,
    this.latestAssessmentStatus,
    this.mentalStatusSignal,
    this.activeDayCount = 0,
    this.assessmentCount = 0,
    this.mindAidMessageCount = 0,
    this.breathingSessionCount = 0,
  });

  final String userId;
  final String userLabel;
  final AdminUserStatus status;
  final DateTime updatedAt;
  final String? role;
  final String? latestAssessmentStatus;
  final String? mentalStatusSignal;
  final int activeDayCount;
  final int assessmentCount;
  final int mindAidMessageCount;
  final int breathingSessionCount;

  int get totalActivityCount =>
      activeDayCount +
      assessmentCount +
      mindAidMessageCount +
      breathingSessionCount;

  factory AdminStatusSummaryModel.fromJson(
    Map<String, dynamic> json, {
    String? id,
  }) {
    final userId = (json['userId'] ?? id ?? '').toString();
    return AdminStatusSummaryModel(
      userId: userId,
      userLabel: _stringOrFallback(
        json['userLabel'],
        _fallbackUserLabel(userId),
      ),
      status: AdminUserStatus.fromString(json['status']),
      updatedAt: dateTimeFromFirestoreOrNow(json['updatedAt']),
      role: _stringOrNull(json['role']),
      latestAssessmentStatus: _stringOrNull(json['latestAssessmentStatus']),
      mentalStatusSignal: _stringOrNull(json['mentalStatusSignal']),
      activeDayCount: intFromFirestore(json['activeDayCount']),
      assessmentCount: intFromFirestore(json['assessmentCount']),
      mindAidMessageCount: intFromFirestore(json['mindAidMessageCount']),
      breathingSessionCount: intFromFirestore(json['breathingSessionCount']),
    );
  }

  static String _fallbackUserLabel(String userId) {
    if (userId.trim().isEmpty) return 'Unknown user';
    if (userId.length <= 8) return 'User $userId';
    return 'User ${userId.substring(0, 8)}';
  }

  static String _stringOrFallback(Object? value, String fallback) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
