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
    final assessmentSummary = _assessmentSummary(assessments);
    final latestAssessment = assessmentSummary.preferredAssessment;
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
    final moodSummary = await _fetchMoodSummary(
      userId: userId,
      since: weekStart,
      before: weekEndExclusive,
    );
    final secretChatSummary = await _fetchSecretChatSummary(
      userId: userId,
      since: weekStart,
      before: weekEndExclusive,
    );
    final topConcernAreas = _topConcernAreas(latestAssessment);
    final latestAssessmentStatus = _assessmentStatus(latestAssessment);
    final latestAssessmentSource = _assessmentSource(latestAssessment);
    final mentalStatusSignal = _mentalStatusSignal(latestAssessment);
    final currentStreak = _intOrZero(userDoc?['dayStreak']);
    final totalEngagementCount =
        activeDateKeys.length +
        weeklyAssessments.length +
        moodSummary.count +
        mindAidMessageCount +
        breathingSummary.sessionCount +
        secretChatSummary.engagementCount;
    final mentalStatus = _mentalStatusFor(
      assessmentSummary: assessmentSummary,
      moodSummary: moodSummary,
      hasEnoughActivity: totalEngagementCount > 0,
    );
    final hasEnoughData =
        latestAssessment != null ||
        moodSummary.count > 0 ||
        mindAidMessageCount > 0 ||
        activeDateKeys.isNotEmpty ||
        breathingSummary.sessionCount > 0 ||
        secretChatSummary.engagementCount > 0 ||
        currentStreak > 0;

    final reportPayload = {
      'userId': userId,
      'title': 'Mental Health Summary',
      'description': _description(
        latestAssessmentStatus: latestAssessmentStatus,
        latestAssessmentSource: latestAssessmentSource,
        mentalStatusSignal: mentalStatusSignal,
        topConcernAreas: topConcernAreas,
        moodSummary: moodSummary,
        mindAidMessageCount: mindAidMessageCount,
        activeDayCount: activeDateKeys.length,
        currentStreak: currentStreak,
        breathingSessionCount: breathingSummary.sessionCount,
        mindfulBreathingMinutes: breathingSummary.minutes,
        secretChatSummary: secretChatSummary,
        mentalStatusLabel: mentalStatus.label,
      ),
      'generatedAt': FieldValue.serverTimestamp(),
      'weekStart': Timestamp.fromDate(weekStart),
      'weekEnd': Timestamp.fromDate(weekEnd),
      'moodCheckInCount': moodSummary.count,
      'averageMoodLevel': moodSummary.average,
      'latestMoodLevel': moodSummary.latestLevel,
      'positiveMoodCount': moodSummary.positiveCount,
      'assessmentCount': weeklyAssessments.length,
      'quickAssessmentScore': assessmentSummary.quickScore,
      'quickAssessmentStatus': assessmentSummary.quickStatus ?? '',
      'quickAssessmentSignal': assessmentSummary.quickSignal ?? '',
      'fullAssessmentScore': assessmentSummary.fullScore,
      'fullAssessmentStatus': assessmentSummary.fullStatus ?? '',
      'fullAssessmentTopConcernAreas': assessmentSummary.fullConcernAreas,
      'mindAidMessageCount': mindAidMessageCount,
      'activeDayCount': activeDateKeys.length,
      'currentStreak': currentStreak,
      'breathingSessionCount': breathingSummary.sessionCount,
      'mindfulBreathingMinutes': breathingSummary.minutes,
      'secretChatPostCount': secretChatSummary.postCount,
      'secretChatCommentCount': secretChatSummary.commentCount,
      'secretChatInteractionCount': secretChatSummary.interactionCount,
      'secretChatEngagementCount': secretChatSummary.engagementCount,
      'totalEngagementCount': totalEngagementCount,
      'mentalStatus': mentalStatus.status,
      'mentalStatusLabel': mentalStatus.label,
      'latestAssessmentStatus': latestAssessmentStatus ?? '',
      'latestAssessmentSource': latestAssessmentSource ?? '',
      'mentalStatusSignal': mentalStatusSignal ?? '',
      'topConcernAreas': topConcernAreas,
      'recommendedNextActions': _recommendedActions(
        latestAssessmentStatus: latestAssessmentStatus,
        mentalStatusSignal: mentalStatusSignal,
        topConcernAreas: topConcernAreas,
        moodSummary: moodSummary,
        mindAidMessageCount: mindAidMessageCount,
        activeDayCount: activeDateKeys.length,
        currentStreak: currentStreak,
        breathingSessionCount: breathingSummary.sessionCount,
        secretChatSummary: secretChatSummary,
        mentalStatus: mentalStatus.status,
      ),
      'hasEnoughData': hasEnoughData,
    };

    final reportId = await _firestoreService.createDocument(
      FirestoreCollections.reports,
      reportPayload,
    );
    await _syncAdminStatusSummary(
      userId: userId,
      userDoc: userDoc,
      latestAssessmentStatus: latestAssessmentStatus,
      quickAssessmentStatus: assessmentSummary.quickStatus,
      fullAssessmentStatus: assessmentSummary.fullStatus,
      mentalStatusSignal: mentalStatusSignal,
      topConcernAreas: topConcernAreas,
      moodSummary: moodSummary,
      activeDayCount: activeDateKeys.length,
      assessmentCount: weeklyAssessments.length,
      mindAidMessageCount: mindAidMessageCount,
      breathingSessionCount: breathingSummary.sessionCount,
      secretChatSummary: secretChatSummary,
      totalEngagementCount: totalEngagementCount,
      mentalStatus: mentalStatus,
      hasEnoughData: hasEnoughData,
    );
    return reportId;
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

  _AssessmentSummary _assessmentSummary(
    List<Map<String, dynamic>> assessments,
  ) {
    Map<String, dynamic>? latestQuick;
    Map<String, dynamic>? latestFull;

    for (final assessment in assessments) {
      final type = assessment['type']?.toString().trim().toLowerCase();
      if (type == 'quick') {
        latestQuick ??= assessment;
      } else {
        latestFull ??= assessment;
      }
      if (latestQuick != null && latestFull != null) break;
    }

    return _AssessmentSummary(latestQuick: latestQuick, latestFull: latestFull);
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

  Future<_MoodSummary> _fetchMoodSummary({
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
    final levels = snapshot.docs
        .map((doc) => _intOrZero(doc.data()['level']))
        .where((level) => level > 0)
        .toList(growable: false);
    final latest = [...snapshot.docs]
      ..sort((left, right) {
        final leftDate = _dateFrom(left.data()['createdAt']) ?? DateTime(0);
        final rightDate = _dateFrom(right.data()['createdAt']) ?? DateTime(0);
        return rightDate.compareTo(leftDate);
      });
    final total = levels.fold<int>(0, (total, level) => total + level);
    return _MoodSummary(
      count: levels.length,
      average: levels.isEmpty ? null : total / levels.length,
      latestLevel: latest.isEmpty
          ? null
          : _intOrZero(latest.first.data()['level']),
      positiveCount: levels.where((level) => level >= 4).length,
    );
  }

  Future<_SecretChatSummary> _fetchSecretChatSummary({
    required String userId,
    required DateTime since,
    required DateTime before,
  }) async {
    final postSnapshot = await _firestoreService.firestore
        .collection(FirestoreCollections.secretChats)
        .where('authorId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .where('createdAt', isLessThan: Timestamp.fromDate(before))
        .get();
    final commentSnapshot = await _firestoreService.firestore
        .collection(FirestoreCollections.secretChatComments)
        .where('authorId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .where('createdAt', isLessThan: Timestamp.fromDate(before))
        .get();
    final interactionSnapshot = await _firestoreService.firestore
        .collection(FirestoreCollections.secretChatInteractions)
        .where('userId', isEqualTo: userId)
        .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .where('updatedAt', isLessThan: Timestamp.fromDate(before))
        .get();

    final interactionCount = interactionSnapshot.docs.where((doc) {
      final data = doc.data();
      return data['liked'] == true || data['saved'] == true;
    }).length;

    return _SecretChatSummary(
      postCount: postSnapshot.docs.length,
      commentCount: commentSnapshot.docs.length,
      interactionCount: interactionCount,
    );
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
    required _MoodSummary moodSummary,
    required int mindAidMessageCount,
    required int activeDayCount,
    required int currentStreak,
    required int breathingSessionCount,
    required int mindfulBreathingMinutes,
    required _SecretChatSummary secretChatSummary,
    required String mentalStatusLabel,
  }) {
    final parts = <String>['Mental status: $mentalStatusLabel'];
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
    if (moodSummary.count > 0) {
      final average = moodSummary.average;
      parts.add(
        average == null
            ? '${moodSummary.count} mood check-in${moodSummary.count == 1 ? '' : 's'}'
            : '${moodSummary.count} mood check-in${moodSummary.count == 1 ? '' : 's'} averaging ${average.toStringAsFixed(1)}/5',
      );
    }
    if (mindAidMessageCount > 0) {
      parts.add(
        '$mindAidMessageCount MindAid check-in${mindAidMessageCount == 1 ? '' : 's'}',
      );
    }
    if (secretChatSummary.engagementCount > 0) {
      parts.add(
        '${secretChatSummary.engagementCount} Secret Chat engagement${secretChatSummary.engagementCount == 1 ? '' : 's'}',
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

    if (parts.length == 1) {
      return 'Your weekly summary will grow as you use assessments, MindAid, and daily check-ins.';
    }
    return '${parts.join(' with ')}.';
  }

  List<String> _recommendedActions({
    required String? latestAssessmentStatus,
    required String? mentalStatusSignal,
    required List<String> topConcernAreas,
    required _MoodSummary moodSummary,
    required int mindAidMessageCount,
    required int activeDayCount,
    required int currentStreak,
    required int breathingSessionCount,
    required _SecretChatSummary secretChatSummary,
    required String mentalStatus,
  }) {
    final actions = <String>[];
    if (mentalStatus == 'severe') {
      actions.add('Consider reaching out to PACC counseling support');
    }
    if (topConcernAreas.isNotEmpty) {
      actions.add('Review support strategies for ${topConcernAreas.first}');
    }
    if (moodSummary.count == 0) {
      actions.add('Log a mood check-in this week');
    } else if ((moodSummary.average ?? 5) <= 2.4) {
      actions.add('Choose one small support step for low mood days');
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
    if (secretChatSummary.engagementCount == 0) {
      actions.add('Use Secret Chat when peer support feels helpful');
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

  Future<void> _syncAdminStatusSummary({
    required String userId,
    required Map<String, dynamic>? userDoc,
    required String? latestAssessmentStatus,
    required String? quickAssessmentStatus,
    required String? fullAssessmentStatus,
    required String? mentalStatusSignal,
    required List<String> topConcernAreas,
    required _MoodSummary moodSummary,
    required int activeDayCount,
    required int assessmentCount,
    required int mindAidMessageCount,
    required int breathingSessionCount,
    required _SecretChatSummary secretChatSummary,
    required int totalEngagementCount,
    required _MentalStatusSummary mentalStatus,
    required bool hasEnoughData,
  }) {
    return _firestoreService
        .setDocument(FirestoreCollections.adminStatusSummaries, userId, {
          'userId': userId,
          'userLabel': _userLabel(userId, userDoc),
          'role': userDoc?['role']?.toString().trim() ?? '',
          'status': mentalStatus.status,
          'statusRank': _statusRank(mentalStatus.status),
          'mentalStatusLabel': mentalStatus.label,
          'latestAssessmentStatus': latestAssessmentStatus ?? '',
          'quickAssessmentStatus': quickAssessmentStatus ?? '',
          'fullAssessmentStatus': fullAssessmentStatus ?? '',
          'mentalStatusSignal': mentalStatusSignal ?? '',
          'topConcernAreas': topConcernAreas,
          'moodCheckInCount': moodSummary.count,
          'averageMoodLevel': moodSummary.average,
          'activeDayCount': activeDayCount,
          'assessmentCount': assessmentCount,
          'mindAidMessageCount': mindAidMessageCount,
          'breathingSessionCount': breathingSessionCount,
          'secretChatEngagementCount': secretChatSummary.engagementCount,
          'totalEngagementCount': totalEngagementCount,
          'updatedAt': FieldValue.serverTimestamp(),
        }, merge: true);
  }

  _MentalStatusSummary _mentalStatusFor({
    required _AssessmentSummary assessmentSummary,
    required _MoodSummary moodSummary,
    required bool hasEnoughActivity,
  }) {
    final fullStatus = (assessmentSummary.fullStatus ?? '').toLowerCase();
    final quickStatus = (assessmentSummary.quickStatus ?? '').toLowerCase();
    final quickSignal = (assessmentSummary.quickSignal ?? '').toLowerCase();
    final fullScore = assessmentSummary.fullScore;
    final quickScore = assessmentSummary.quickScore;
    final averageMood = moodSummary.average;

    final severe =
        fullStatus.contains('severe') ||
        fullStatus.contains('high') ||
        quickStatus.contains('very high') ||
        quickSignal == 'elevated' ||
        quickSignal == 'highsupport' ||
        (fullScore != null && fullScore >= 70) ||
        (quickScore != null && quickScore >= 75) ||
        (averageMood != null && averageMood <= 2.0);
    if (severe) {
      return const _MentalStatusSummary(
        status: 'severe',
        label: 'Needs support',
      );
    }

    final moderate =
        fullStatus.contains('moderate') ||
        quickStatus.contains('moderate') ||
        quickSignal == 'watchful' ||
        (quickScore != null && quickScore >= 50) ||
        (averageMood != null && averageMood <= 2.7) ||
        (!hasEnoughActivity &&
            (assessmentSummary.hasAssessment || moodSummary.count > 0));
    if (moderate) {
      return const _MentalStatusSummary(status: 'moderate', label: 'Watchful');
    }

    return const _MentalStatusSummary(status: 'normal', label: 'Stable');
  }

  int _statusRank(String status) {
    switch (status) {
      case 'severe':
        return 0;
      case 'moderate':
        return 1;
      default:
        return 2;
    }
  }

  String _userLabel(String userId, Map<String, dynamic>? userDoc) {
    final name = userDoc?['name']?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    final firstName = userDoc?['firstName']?.toString().trim();
    final lastName = userDoc?['lastName']?.toString().trim();
    final parts = [
      if (firstName != null && firstName.isNotEmpty) firstName,
      if (lastName != null && lastName.isNotEmpty) lastName,
    ];
    if (parts.isNotEmpty) return parts.join(' ');
    final email = userDoc?['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    if (userId.length <= 8) return 'User $userId';
    return 'User ${userId.substring(0, 8)}';
  }
}

class _BreathingSummary {
  const _BreathingSummary({required this.sessionCount, required this.minutes});

  final int sessionCount;
  final int minutes;
}

class _MoodSummary {
  const _MoodSummary({
    required this.count,
    required this.average,
    required this.latestLevel,
    required this.positiveCount,
  });

  final int count;
  final double? average;
  final int? latestLevel;
  final int positiveCount;
}

class _SecretChatSummary {
  const _SecretChatSummary({
    required this.postCount,
    required this.commentCount,
    required this.interactionCount,
  });

  final int postCount;
  final int commentCount;
  final int interactionCount;

  int get engagementCount => postCount + commentCount + interactionCount;
}

class _AssessmentSummary {
  const _AssessmentSummary({this.latestQuick, this.latestFull});

  final Map<String, dynamic>? latestQuick;
  final Map<String, dynamic>? latestFull;

  bool get hasAssessment => latestQuick != null || latestFull != null;

  Map<String, dynamic>? get preferredAssessment => latestFull ?? latestQuick;

  int? get quickScore => _score(latestQuick);
  int? get fullScore => _score(latestFull);

  String? get quickStatus =>
      _firstText(latestQuick?['overallLevel'], latestQuick?['status']);
  String? get fullStatus =>
      _firstText(latestFull?['status'], latestFull?['overallLevel']);
  String? get quickSignal => _firstText(latestQuick?['mentalStatusSignal']);

  List<String> get fullConcernAreas => _stringList(
    latestFull?['mainConcernAreas'] ?? latestFull?['topConcernAreas'],
  ).take(3).toList(growable: false);

  static int? _score(Map<String, dynamic>? assessment) {
    if (assessment == null) return null;
    final value = assessment['overallScore'] ?? assessment['concernScore'];
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _firstText(Object? first, [Object? second]) {
    for (final value in [first, second]) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

class _MentalStatusSummary {
  const _MentalStatusSummary({required this.status, required this.label});

  final String status;
  final String label;
}
