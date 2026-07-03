import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/firestore_collections.dart';
import '../models/report_model.dart';
import '../services/firebase/firestore_service.dart';

class ReportRepository {
  ReportRepository({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  Future<ReportModel?> fetchLatestReport(String userId) async {
    final docs = await _firestoreService.getDocuments(
      FirestoreCollections.reports,
      whereEquals: {'userId': userId},
      orderBy: 'generatedAt',
      limit: 1,
    );
    if (docs.isEmpty) return null;
    return ReportModel.fromJson(docs.first, id: docs.first['id']?.toString());
  }

  Stream<List<ReportModel>> watchReports(String userId, {int limit = 12}) {
    return _firestoreService
        .watchDocuments(
          FirestoreCollections.reports,
          whereEquals: {'userId': userId},
          orderBy: 'generatedAt',
          limit: limit,
        )
        .map(
          (docs) => docs
              .map(
                (doc) => ReportModel.fromJson(doc, id: doc['id']?.toString()),
              )
              .toList(growable: false),
        );
  }

  Future<String> createPlaceholderWeeklyReport(String userId) {
    return generateWeeklyReport(userId);
  }

  Future<String> generateWeeklyReport(String userId, {DateTime? now}) async {
    final generatedAt = now ?? DateTime.now();
    final weekStart = _weekStartFor(generatedAt);
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekEndExclusive = weekStart.add(const Duration(days: 7));

    final userDoc = await _firestoreService.getDocument(
      FirestoreCollections.users,
      userId,
    );
    final assessments = await _fetchAssessments(userId);
    final weeklyAssessments = assessments
        .where((assessment) {
          final createdAt = _dateFrom(assessment['createdAt']);
          return createdAt != null &&
              !createdAt.isBefore(weekStart) &&
              createdAt.isBefore(weekEndExclusive);
        })
        .toList(growable: false);
    final latestAssessment = _latestAssessmentForSummary(assessments);
    final mindAidMessageCount = await _countMindAidMessages(
      userId: userId,
      since: weekStart,
      before: weekEndExclusive,
    );
    final activeDateKeys = await _fetchActiveDateKeys(
      userId: userId,
      since: weekStart,
      before: weekEndExclusive,
    );
    final breathingSummary = await _fetchBreathingSummary(
      userId: userId,
      since: weekStart,
      before: weekEndExclusive,
    );
    final positiveMoodCount = await _countPositiveMoods(
      userId: userId,
      since: weekStart,
      before: weekEndExclusive,
    );
    final topConcernAreas = _topConcernAreas(latestAssessment);
    final latestAssessmentStatus = _assessmentStatus(latestAssessment);
    final latestAssessmentSource = _assessmentSource(latestAssessment);
    final mentalStatusSignal = _mentalStatusSignal(latestAssessment);
    final currentStreak = _intOrZero(userDoc?['dayStreak']);
    final hasEnoughData =
        latestAssessment != null ||
        mindAidMessageCount > 0 ||
        activeDateKeys.isNotEmpty ||
        breathingSummary.sessionCount > 0 ||
        currentStreak > 0;

    return _firestoreService.createDocument(FirestoreCollections.reports, {
      'userId': userId,
      'title': 'Mental Health Summary',
      'description': _description(
        latestAssessmentStatus: latestAssessmentStatus,
        latestAssessmentSource: latestAssessmentSource,
        mentalStatusSignal: mentalStatusSignal,
        topConcernAreas: topConcernAreas,
        mindAidMessageCount: mindAidMessageCount,
        activeDayCount: activeDateKeys.length,
        currentStreak: currentStreak,
        breathingSessionCount: breathingSummary.sessionCount,
        mindfulBreathingMinutes: breathingSummary.minutes,
      ),
      'generatedAt': FieldValue.serverTimestamp(),
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekEnd),
      'positiveMoodCount': positiveMoodCount,
      'assessmentCount': weeklyAssessments.length,
      'mindAidMessageCount': mindAidMessageCount,
      'activeDayCount': activeDateKeys.length,
      'currentStreak': currentStreak,
      'breathingSessionCount': breathingSummary.sessionCount,
      'mindfulBreathingMinutes': breathingSummary.minutes,
      'latestAssessmentStatus': latestAssessmentStatus ?? '',
      'latestAssessmentSource': latestAssessmentSource ?? '',
      'mentalStatusSignal': mentalStatusSignal ?? '',
      'topConcernAreas': topConcernAreas,
      'recommendedNextActions': _recommendedActions(
        latestAssessmentStatus: latestAssessmentStatus,
        mentalStatusSignal: mentalStatusSignal,
        topConcernAreas: topConcernAreas,
        mindAidMessageCount: mindAidMessageCount,
        activeDayCount: activeDateKeys.length,
        currentStreak: currentStreak,
        breathingSessionCount: breathingSummary.sessionCount,
      ),
      'hasEnoughData': hasEnoughData,
    });
  }

  DateTime _weekStartFor(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return local.subtract(Duration(days: local.weekday - 1));
  }

  Future<List<Map<String, dynamic>>> _fetchAssessments(String userId) {
    return _firestoreService.getDocuments(
      FirestoreCollections.assessments,
      whereEquals: {'userId': userId},
      orderBy: 'createdAt',
      limit: 50,
    );
  }

  Map<String, dynamic>? _latestAssessmentForSummary(
    List<Map<String, dynamic>> assessments,
  ) {
    if (assessments.isEmpty) return null;
    final full = assessments.where((assessment) {
      return assessment['type']?.toString() != 'quick';
    });
    return full.isNotEmpty ? full.first : assessments.first;
  }

  Future<int> _countMindAidMessages({
    required String userId,
    required DateTime since,
    required DateTime before,
  }) async {
    final snapshot = await _firestoreService.firestore
        .collection(FirestoreCollections.mindAidMessages)
        .where('userId', isEqualTo: userId)
        .where('sender', isEqualTo: 'user')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .where('createdAt', isLessThan: Timestamp.fromDate(before))
        .get();
    return snapshot.docs.length;
  }

  Future<Set<String>> _fetchActiveDateKeys({
    required String userId,
    required DateTime since,
    required DateTime before,
  }) async {
    final snapshot = await _firestoreService.firestore
        .collection(FirestoreCollections.userActivities)
        .where('userId', isEqualTo: userId)
        .where('occurredAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .where('occurredAt', isLessThan: Timestamp.fromDate(before))
        .get();
    return snapshot.docs
        .map((doc) => doc.data()['dateKey']?.toString() ?? '')
        .where((key) => key.trim().isNotEmpty)
        .toSet();
  }

  Future<int> _countPositiveMoods({
    required String userId,
    required DateTime since,
    required DateTime before,
  }) async {
    final snapshot = await _firestoreService.firestore
        .collection(FirestoreCollections.moods)
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .where('createdAt', isLessThan: Timestamp.fromDate(before))
        .get();
    return snapshot.docs
        .where((doc) => _intOrZero(doc.data()['level']) >= 4)
        .length;
  }

  Future<_BreathingSummary> _fetchBreathingSummary({
    required String userId,
    required DateTime since,
    required DateTime before,
  }) async {
    final snapshot = await _firestoreService.firestore
        .collection(FirestoreCollections.breathingSessions)
        .where('userId', isEqualTo: userId)
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .where('completedAt', isLessThan: Timestamp.fromDate(before))
        .get();

    final completedDocs = snapshot.docs.where(
      (doc) => doc.data()['completed'] == true,
    );
    final seconds = completedDocs.fold<int>(
      0,
      (total, doc) => total + _intOrZero(doc.data()['completedSeconds']),
    );

    return _BreathingSummary(
      sessionCount: completedDocs.length,
      minutes: (seconds / 60).round(),
    );
  }

  List<String> _topConcernAreas(Map<String, dynamic>? assessment) {
    final raw =
        assessment?['mainConcernAreas'] ?? assessment?['topConcernAreas'];
    if (raw is! List) return const [];
    return raw
        .map((area) => area.toString().trim())
        .where((area) => area.isNotEmpty)
        .take(3)
        .toList(growable: false);
  }

  String? _assessmentStatus(Map<String, dynamic>? assessment) {
    final status = assessment?['status'] ?? assessment?['overallLevel'];
    final text = status?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  String? _assessmentSource(Map<String, dynamic>? assessment) {
    if (assessment == null) return null;
    final signalSource = assessment['signalSource']?.toString().trim();
    if (signalSource != null && signalSource.isNotEmpty) return signalSource;
    final type = assessment['type']?.toString().trim();
    if (type == null || type.isEmpty) return null;
    return type == 'quick' ? 'quickAssessment' : 'fullAssessment';
  }

  String? _mentalStatusSignal(Map<String, dynamic>? assessment) {
    final signal = assessment?['mentalStatusSignal']?.toString().trim();
    if (signal == null || signal.isEmpty) return null;
    return signal;
  }

  String _description({
    required String? latestAssessmentStatus,
    required String? latestAssessmentSource,
    required String? mentalStatusSignal,
    required List<String> topConcernAreas,
    required int mindAidMessageCount,
    required int activeDayCount,
    required int currentStreak,
    required int breathingSessionCount,
    required int mindfulBreathingMinutes,
  }) {
    final parts = <String>[];
    if (latestAssessmentStatus != null) {
      if (latestAssessmentSource == 'quickAssessment') {
        parts.add(
          'Your quick assessment suggests a ${latestAssessmentStatus.toLowerCase()} support need',
        );
      } else {
        parts.add(
          'Latest full assessment shows $latestAssessmentStatus concern',
        );
      }
    }
    if (mentalStatusSignal != null && mentalStatusSignal.isNotEmpty) {
      parts.add('wellness signal: $mentalStatusSignal');
    }
    if (topConcernAreas.isNotEmpty) {
      parts.add('main focus: ${topConcernAreas.join(', ')}');
    }
    if (mindAidMessageCount > 0) {
      parts.add(
        '$mindAidMessageCount MindAid check-in${mindAidMessageCount == 1 ? '' : 's'}',
      );
    }
    if (breathingSessionCount > 0) {
      parts.add(
        '$breathingSessionCount breathing session${breathingSessionCount == 1 ? '' : 's'} adding $mindfulBreathingMinutes mindful minute${mindfulBreathingMinutes == 1 ? '' : 's'}',
      );
    }
    if (currentStreak > 0) {
      parts.add('$currentStreak-day streak');
    } else if (activeDayCount > 0) {
      parts.add(
        '$activeDayCount active day${activeDayCount == 1 ? '' : 's'} this week',
      );
    }

    if (parts.isEmpty) {
      return 'Your weekly summary will grow as you use assessments, MindAid, and daily check-ins.';
    }
    return '${parts.join(' with ')}.';
  }

  List<String> _recommendedActions({
    required String? latestAssessmentStatus,
    required String? mentalStatusSignal,
    required List<String> topConcernAreas,
    required int mindAidMessageCount,
    required int activeDayCount,
    required int currentStreak,
    required int breathingSessionCount,
  }) {
    final actions = <String>[];
    if (topConcernAreas.isNotEmpty) {
      actions.add('Review support strategies for ${topConcernAreas.first}');
    }
    if (mindAidMessageCount == 0) {
      actions.add('Use MindAid when you want guided support');
    }
    if (currentStreak == 0 || activeDayCount < 3) {
      actions.add('Build consistency with a short daily check-in');
    }
    if (breathingSessionCount == 0 ||
        topConcernAreas.any(_breathingRelevantConcern)) {
      actions.add('Try a short mindful breathing session');
    }
    if ((latestAssessmentStatus ?? '').toLowerCase().contains('high')) {
      actions.add('Consider reaching out to PACC counseling support');
    }
    if (mentalStatusSignal == 'watchful' || mentalStatusSignal == 'elevated') {
      actions.add('Consider a full assessment for deeper insight');
    }
    actions.add('Continue daily check-ins');

    return actions.toSet().take(3).toList(growable: false);
  }

  DateTime? _dateFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  int _intOrZero(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _breathingRelevantConcern(String concern) {
    final text = concern.toLowerCase();
    return text.contains('stress') ||
        text.contains('anxiety') ||
        text.contains('sleep') ||
        text.contains('overwhelm');
  }
}

class _BreathingSummary {
  const _BreathingSummary({required this.sessionCount, required this.minutes});

  final int sessionCount;
  final int minutes;
}
