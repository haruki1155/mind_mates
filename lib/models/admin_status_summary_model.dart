import '../core/utils/firestore_mapper.dart';

enum AdminUserStatus {
  severe,
  moderate,
  normal;

  String get label {
    switch (this) {
      case AdminUserStatus.severe:
        return 'Prompt follow-up';
      case AdminUserStatus.moderate:
        return 'Review suggested';
      case AdminUserStatus.normal:
        return 'Routine monitoring';
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
    this.mentalStatusLabel,
    this.role,
    this.latestAssessmentStatus,
    this.quickAssessmentStatus,
    this.fullAssessmentStatus,
    this.mentalStatusSignal,
    this.moodCheckInCount = 0,
    this.averageMoodLevel,
    this.activeDayCount = 0,
    this.assessmentCount = 0,
    this.mindAidMessageCount = 0,
    this.breathingSessionCount = 0,
    this.secretChatEngagementCount = 0,
    this.totalEngagementCount = 0,
  });

  final String userId;
  final String userLabel;
  final AdminUserStatus status;
  final DateTime updatedAt;
  final String? mentalStatusLabel;
  final String? role;
  final String? latestAssessmentStatus;
  final String? quickAssessmentStatus;
  final String? fullAssessmentStatus;
  final String? mentalStatusSignal;
  final int moodCheckInCount;
  final double? averageMoodLevel;
  final int activeDayCount;
  final int assessmentCount;
  final int mindAidMessageCount;
  final int breathingSessionCount;
  final int secretChatEngagementCount;
  final int totalEngagementCount;

  int get totalActivityCount => totalEngagementCount == 0
      ? activeDayCount +
            assessmentCount +
            mindAidMessageCount +
            breathingSessionCount +
            moodCheckInCount +
            secretChatEngagementCount
      : totalEngagementCount;

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
      mentalStatusLabel: _stringOrNull(json['mentalStatusLabel']),
      role: _stringOrNull(json['role']),
      latestAssessmentStatus: _stringOrNull(json['latestAssessmentStatus']),
      quickAssessmentStatus: _stringOrNull(json['quickAssessmentStatus']),
      fullAssessmentStatus: _stringOrNull(json['fullAssessmentStatus']),
      mentalStatusSignal: _stringOrNull(json['mentalStatusSignal']),
      moodCheckInCount: intFromFirestore(json['moodCheckInCount']),
      averageMoodLevel: _doubleOrNull(json['averageMoodLevel']),
      activeDayCount: intFromFirestore(json['activeDayCount']),
      assessmentCount: intFromFirestore(json['assessmentCount']),
      mindAidMessageCount: intFromFirestore(json['mindAidMessageCount']),
      breathingSessionCount: intFromFirestore(json['breathingSessionCount']),
      secretChatEngagementCount: intFromFirestore(
        json['secretChatEngagementCount'],
      ),
      totalEngagementCount: intFromFirestore(json['totalEngagementCount']),
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

  static double? _doubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
