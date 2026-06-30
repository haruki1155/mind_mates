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
    this.positiveMoodCount = 0,
    this.assessmentCount = 0,
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
  final int positiveMoodCount;
  final int assessmentCount;
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
      positiveMoodCount: intFromFirestore(json['positiveMoodCount']),
      assessmentCount: intFromFirestore(json['assessmentCount']),
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
      'positiveMoodCount': positiveMoodCount,
      'assessmentCount': assessmentCount,
      'topConcernAreas': topConcernAreas,
      'recommendedNextActions': recommendedNextActions,
      'hasEnoughData': hasEnoughData,
    };
  }
}
