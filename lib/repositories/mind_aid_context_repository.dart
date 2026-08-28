import '../core/utils/firestore_mapper.dart';
import '../database/firestore_collections.dart';
import '../features/mind_aid/domain/mind_aid_context.dart';
import '../models/mood_model.dart';
import '../models/report_model.dart';
import '../services/firebase/firestore_service.dart';

class MindAidContextRepository {
  MindAidContextRepository({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  Future<MindAidWellnessSnapshot?> fetchWellnessSnapshot(String userId) async {
    if (userId.trim().isEmpty || userId == 'guest') return null;

    try {
      final results = await Future.wait([
        _fetchRecentMoods(userId),
        _fetchLatestAssessment(userId),
        _fetchLatestReport(userId),
        _fetchUser(userId),
      ]);

      final moods = results[0] as List<MoodModel>;
      final assessment = results[1] as Map<String, dynamic>?;
      final report = results[2] as ReportModel?;
      final user = results[3] as Map<String, dynamic>?;

      return buildSnapshot(
        moods: moods,
        latestAssessment: assessment,
        latestReport: report,
        user: user,
      );
    } catch (_) {
      return null;
    }
  }

  static MindAidWellnessSnapshot? buildSnapshot({
    List<MoodModel> moods = const [],
    Map<String, dynamic>? latestAssessment,
    ReportModel? latestReport,
    Map<String, dynamic>? user,
  }) {
    final latestMood = moods.isEmpty ? null : moods.first;
    final recentMoodAverage = _averageMood(moods);
    final moodTrend = _moodTrend(moods);
    final assessmentScore = _assessmentScore(latestAssessment);
    final assessmentStatus = _assessmentStatus(latestAssessment, latestReport);
    final mentalStatusSignal = _firstNonEmpty([
      latestAssessment?['mentalStatusSignal'],
      latestReport?.mentalStatusSignal,
    ]);
    final topConcernAreas = _uniqueStrings([
      ..._stringList(latestAssessment?['mainConcernAreas']),
      ..._stringList(latestAssessment?['topConcernAreas']),
      ...(latestReport?.topConcernAreas ?? const []),
    ]).take(3).toList(growable: false);
    final recommendedActions = _uniqueStrings(
      latestReport?.recommendedNextActions ?? const [],
    ).take(3).toList(growable: false);

    final hasAnySignal =
        latestMood != null ||
        latestAssessment != null ||
        latestReport != null ||
        user != null;
    if (!hasAnySignal) return null;

    return MindAidWellnessSnapshot(
      latestMoodLevel: latestMood?.level,
      recentMoodAverage: recentMoodAverage,
      moodTrend: moodTrend,
      latestMoodLabel: _emptyToNull(latestMood?.label),
      hasMoodNote: (latestMood?.note ?? '').trim().isNotEmpty,
      assessmentStatus: assessmentStatus,
      assessmentScore: assessmentScore,
      mentalStatusSignal: mentalStatusSignal,
      topConcernAreas: topConcernAreas,
      reportSummary: _emptyToNull(latestReport?.description),
      recommendedActions: recommendedActions,
      currentStreak:
          _intValue(user?['dayStreak']) ?? latestReport?.currentStreak ?? 0,
      activeDayCount:
          latestReport?.activeDayCount ??
          _stringList(user?['activeDateKeys']).length,
      breathingSessionCount: latestReport?.breathingSessionCount ?? 0,
      mindfulBreathingMinutes: latestReport?.mindfulBreathingMinutes ?? 0,
      lastCheckInAt:
          latestMood?.createdAt ??
          dateTimeFromFirestore(user?['lastActiveAt']) ??
          latestReport?.generatedAt,
    );
  }

  Future<List<MoodModel>> _fetchRecentMoods(String userId) async {
    final docs = await _firestoreService.getDocuments(
      FirestoreCollections.moods,
      whereEquals: {'userId': userId},
      orderBy: 'createdAt',
      limit: 14,
    );
    return docs
        .map((doc) => MoodModel.fromJson(doc, id: doc['id']?.toString()))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> _fetchLatestAssessment(String userId) async {
    final docs = await _firestoreService.getDocuments(
      FirestoreCollections.assessments,
      whereEquals: {'userId': userId},
      orderBy: 'createdAt',
      limit: 50,
    );
    if (docs.isEmpty) return null;
    final verified = docs.where((doc) {
      final status = doc['verificationStatus']?.toString();
      return status == 'verified' || status == 'verified_legacy_recomputed';
    });
    return (verified.isNotEmpty ? verified : docs).first;
  }

  Future<ReportModel?> _fetchLatestReport(String userId) async {
    final docs = await _firestoreService.getDocuments(
      FirestoreCollections.reports,
      whereEquals: {'userId': userId},
      orderBy: 'generatedAt',
      limit: 1,
    );
    if (docs.isEmpty) return null;
    return ReportModel.fromJson(docs.first, id: docs.first['id']?.toString());
  }

  Future<Map<String, dynamic>?> _fetchUser(String userId) {
    return _firestoreService.getDocument(FirestoreCollections.users, userId);
  }

  static double? _averageMood(List<MoodModel> moods) {
    if (moods.isEmpty) return null;
    final sample = moods.take(7).toList(growable: false);
    final total = sample.fold<int>(0, (sum, mood) => sum + mood.level);
    return total / sample.length;
  }

  static MindAidMoodTrend? _moodTrend(List<MoodModel> moods) {
    if (moods.length < 4) return null;

    final recent = moods.take(3).map((mood) => mood.level).toList();
    final previous = moods.skip(3).take(3).map((mood) => mood.level).toList();
    if (previous.isEmpty) return null;

    final recentAverage =
        recent.reduce((left, right) => left + right) / recent.length;
    final previousAverage =
        previous.reduce((left, right) => left + right) / previous.length;
    final delta = recentAverage - previousAverage;

    if (delta >= 0.6) return MindAidMoodTrend.improving;
    if (delta <= -0.6) return MindAidMoodTrend.declining;
    return MindAidMoodTrend.steady;
  }

  static int? _assessmentScore(Map<String, dynamic>? assessment) {
    if (assessment == null) return null;
    final score =
        _intValue(assessment['overallScore']) ??
        _intValue(assessment['concernScore']);
    return score;
  }

  static String? _assessmentStatus(
    Map<String, dynamic>? assessment,
    ReportModel? report,
  ) {
    return _firstNonEmpty([
      assessment?['status'],
      assessment?['overallLevel'],
      report?.latestAssessmentStatus,
    ]);
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _uniqueStrings(Iterable<String> values) {
    final unique = <String>{};
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) unique.add(trimmed);
    }
    return unique.toList(growable: false);
  }

  static String? _firstNonEmpty(Iterable<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  static String? _emptyToNull(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static int? _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value == null) return null;
    return int.tryParse(value.toString());
  }
}
