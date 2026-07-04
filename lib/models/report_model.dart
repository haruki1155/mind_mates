import '../core/utils/firestore_mapper.dart';

class ReportModel {
  const ReportModel({
    required this.id,
    required this.generatedAt,
    this.userId,
    this.title = 'Mental Health Summary',
    this.description = "This week's positive moods",
    this.weekStart,
    this.weekEnd,
    this.moodCheckInCount = 0,
    this.averageMoodLevel,
    this.latestMoodLevel,
    this.positiveMoodCount = 0,
    this.assessmentCount = 0,
    this.quickAssessmentScore,
    this.quickAssessmentStatus,
    this.quickAssessmentSignal,
    this.fullAssessmentScore,
    this.fullAssessmentStatus,
    this.fullAssessmentTopConcernAreas = const [],
    this.mindAidMessageCount = 0,
    this.activeDayCount = 0,
    this.currentStreak = 0,
    this.breathingSessionCount = 0,
    this.mindfulBreathingMinutes = 0,
    this.secretChatPostCount = 0,
    this.secretChatCommentCount = 0,
    this.secretChatInteractionCount = 0,
    this.secretChatEngagementCount = 0,
    this.totalEngagementCount = 0,
    this.mentalStatus = 'normal',
    this.mentalStatusLabel = 'Normal',
    this.latestAssessmentStatus,
    this.latestAssessmentSource,
    this.mentalStatusSignal,
    this.topConcernAreas = const [],
    this.recommendedNextActions = const [],
    this.hasEnoughData = false,
  });

  final String id;
  final DateTime generatedAt;
  final String? userId;
  final String title;
  final String description;
  final DateTime? weekStart;
  final DateTime? weekEnd;
  final int moodCheckInCount;
  final double? averageMoodLevel;
  final int? latestMoodLevel;
  final int positiveMoodCount;
  final int assessmentCount;
  final int? quickAssessmentScore;
  final String? quickAssessmentStatus;
  final String? quickAssessmentSignal;
  final int? fullAssessmentScore;
  final String? fullAssessmentStatus;
  final List<String> fullAssessmentTopConcernAreas;
  final int mindAidMessageCount;
  final int activeDayCount;
  final int currentStreak;
  final int breathingSessionCount;
  final int mindfulBreathingMinutes;
  final int secretChatPostCount;
  final int secretChatCommentCount;
  final int secretChatInteractionCount;
  final int secretChatEngagementCount;
  final int totalEngagementCount;
  final String mentalStatus;
  final String mentalStatusLabel;
  final String? latestAssessmentStatus;
  final String? latestAssessmentSource;
  final String? mentalStatusSignal;
  final List<String> topConcernAreas;
  final List<String> recommendedNextActions;
  final bool hasEnoughData;

  factory ReportModel.fromJson(Map<String, dynamic> json, {String? id}) {
    return ReportModel(
      id: (json['id'] ?? id ?? '').toString(),
      userId: json['userId']?.toString(),
      title: (json['title'] ?? 'Mental Health Summary').toString(),
      description: (json['description'] ?? "This week's positive moods")
          .toString(),
      generatedAt: dateTimeFromFirestoreOrNow(json['generatedAt']),
      weekStart: dateTimeFromFirestore(json['weekStart']),
      weekEnd: dateTimeFromFirestore(json['weekEnd']),
      moodCheckInCount: intFromFirestore(json['moodCheckInCount']),
      averageMoodLevel: _doubleOrNull(json['averageMoodLevel']),
      latestMoodLevel: _intOrNull(json['latestMoodLevel']),
      positiveMoodCount: intFromFirestore(json['positiveMoodCount']),
      assessmentCount: intFromFirestore(json['assessmentCount']),
      quickAssessmentScore: _intOrNull(json['quickAssessmentScore']),
      quickAssessmentStatus: _stringOrNull(json['quickAssessmentStatus']),
      quickAssessmentSignal: _stringOrNull(json['quickAssessmentSignal']),
      fullAssessmentScore: _intOrNull(json['fullAssessmentScore']),
      fullAssessmentStatus: _stringOrNull(json['fullAssessmentStatus']),
      fullAssessmentTopConcernAreas:
          (json['fullAssessmentTopConcernAreas'] as List<dynamic>? ?? const [])
              .map((area) => area.toString())
              .toList(growable: false),
      mindAidMessageCount: intFromFirestore(json['mindAidMessageCount']),
      activeDayCount: intFromFirestore(json['activeDayCount']),
      currentStreak: intFromFirestore(json['currentStreak']),
      breathingSessionCount: intFromFirestore(json['breathingSessionCount']),
      mindfulBreathingMinutes: intFromFirestore(
        json['mindfulBreathingMinutes'],
      ),
      secretChatPostCount: intFromFirestore(json['secretChatPostCount']),
      secretChatCommentCount: intFromFirestore(json['secretChatCommentCount']),
      secretChatInteractionCount: intFromFirestore(
        json['secretChatInteractionCount'],
      ),
      secretChatEngagementCount: intFromFirestore(
        json['secretChatEngagementCount'],
      ),
      totalEngagementCount: intFromFirestore(json['totalEngagementCount']),
      mentalStatus: (json['mentalStatus'] ?? 'normal').toString(),
      mentalStatusLabel: (json['mentalStatusLabel'] ?? 'Normal').toString(),
      latestAssessmentStatus: _stringOrNull(json['latestAssessmentStatus']),
      latestAssessmentSource: _stringOrNull(json['latestAssessmentSource']),
      mentalStatusSignal: _stringOrNull(json['mentalStatusSignal']),
      topConcernAreas: (json['topConcernAreas'] as List<dynamic>? ?? const [])
          .map((area) => area.toString())
          .toList(growable: false),
      recommendedNextActions:
          (json['recommendedNextActions'] as List<dynamic>? ?? const [])
              .map((action) => action.toString())
              .toList(growable: false),
      hasEnoughData: boolFromFirestore(json['hasEnoughData']),
    );
  }

  Map<String, dynamic> toJson({String? userId}) {
    return {
      'userId': userId ?? this.userId,
      'title': title,
      'description': description,
      'generatedAt': generatedAt,
      'weekStart': weekStart,
      'weekEnd': weekEnd,
      'moodCheckInCount': moodCheckInCount,
      'averageMoodLevel': averageMoodLevel,
      'latestMoodLevel': latestMoodLevel,
      'positiveMoodCount': positiveMoodCount,
      'assessmentCount': assessmentCount,
      'quickAssessmentScore': quickAssessmentScore,
      'quickAssessmentStatus': quickAssessmentStatus,
      'quickAssessmentSignal': quickAssessmentSignal,
      'fullAssessmentScore': fullAssessmentScore,
      'fullAssessmentStatus': fullAssessmentStatus,
      'fullAssessmentTopConcernAreas': fullAssessmentTopConcernAreas,
      'mindAidMessageCount': mindAidMessageCount,
      'activeDayCount': activeDayCount,
      'currentStreak': currentStreak,
      'breathingSessionCount': breathingSessionCount,
      'mindfulBreathingMinutes': mindfulBreathingMinutes,
      'secretChatPostCount': secretChatPostCount,
      'secretChatCommentCount': secretChatCommentCount,
      'secretChatInteractionCount': secretChatInteractionCount,
      'secretChatEngagementCount': secretChatEngagementCount,
      'totalEngagementCount': totalEngagementCount,
      'mentalStatus': mentalStatus,
      'mentalStatusLabel': mentalStatusLabel,
      'latestAssessmentStatus': latestAssessmentStatus,
      'latestAssessmentSource': latestAssessmentSource,
      'mentalStatusSignal': mentalStatusSignal,
      'topConcernAreas': topConcernAreas,
      'recommendedNextActions': recommendedNextActions,
      'hasEnoughData': hasEnoughData,
    };
  }

  String get averageMoodLabel {
    final average = averageMoodLevel;
    if (average == null) return '-';
    return average.toStringAsFixed(1);
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  static double? _doubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
