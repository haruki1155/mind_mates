import 'package:cloud_firestore/cloud_firestore.dart';

import '../database/firestore_collections.dart';
import '../features/quick_assessment/models/quick_assessment_models.dart';
import '../features/student_assessment/models/student_assessment_models.dart';
import '../services/firebase/firestore_service.dart';

class AssessmentRepository {
  AssessmentRepository({FirestoreService? firestoreService})
    : _firestoreService = firestoreService ?? FirestoreService();

  static const fullAssessmentLimit = 2;
  static const fullAssessmentWindow = Duration(days: 7);
  static const fullAssessmentMinimumInterval = Duration(days: 2);

  final FirestoreService _firestoreService;

  Future<Map<String, Object>> saveQuickAssessment({
    required String userId,
    required QuickAssessmentResult result,
  }) async {
    final payload = <String, Object>{
      'userId': userId,
      'type': 'quick',
      ...result.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestoreService.createDocument(
      FirestoreCollections.assessments,
      Map<String, dynamic>.from(payload),
    );

    return payload;
  }

  Future<Map<String, Object>> saveStudentAssessment({
    required String userId,
    required StudentAssessmentResult result,
    List<StudentAssessmentAnswer> answers = const [],
  }) async {
    final payload = <String, Object>{
      'userId': userId,
      'type': result.userType.toLowerCase(),
      'role': result.userType.toLowerCase(),
      ...result.toJson(),
      'responses': answers.map((answer) => answer.toJson()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestoreService.createDocument(
      FirestoreCollections.assessments,
      Map<String, dynamic>.from(payload),
    );

    return payload;
  }

  Future<Map<String, dynamic>?> fetchLatestAssessment(String userId) async {
    final docs = await _firestoreService.getDocuments(
      FirestoreCollections.assessments,
      whereEquals: {'userId': userId},
      orderBy: 'createdAt',
      limit: 1,
    );
    if (docs.isEmpty) return null;
    return docs.first;
  }

  Future<int> countAssessmentsSince({
    required String userId,
    required DateTime since,
  }) async {
    final snapshot = await _firestoreService.firestore
        .collection(FirestoreCollections.assessments)
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();
    return snapshot.docs.length;
  }

  Future<FullAssessmentEligibility> fullAssessmentEligibility(
    String userId, {
    DateTime? now,
  }) async {
    final checkedAt = now ?? DateTime.now();
    final windowStart = checkedAt.subtract(fullAssessmentWindow);
    final snapshot = await _firestoreService.firestore
        .collection(FirestoreCollections.assessments)
        .where('userId', isEqualTo: userId)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(windowStart))
        .get();

    final fullAssessmentDates = snapshot.docs
        .where((doc) => doc.data()['type'] != 'quick')
        .map((doc) => _dateFromValue(doc.data()['createdAt']))
        .whereType<DateTime>()
        .toList();

    return FullAssessmentEligibility.fromCompletedDates(
      completedAt: fullAssessmentDates,
      now: checkedAt,
    );
  }

  DateTime? _dateFromValue(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}

enum FullAssessmentBlockReason { minimumInterval, rollingLimit }

class FullAssessmentEligibility {
  const FullAssessmentEligibility({
    required this.canStart,
    this.nextEligibleAt,
    this.reason,
  });

  factory FullAssessmentEligibility.fromCompletedDates({
    required List<DateTime> completedAt,
    required DateTime now,
  }) {
    final windowStart = now.subtract(AssessmentRepository.fullAssessmentWindow);
    final fullAssessmentDates =
        completedAt.where((date) => date.isAfter(windowStart)).toList()..sort();

    if (fullAssessmentDates.isEmpty) {
      return const FullAssessmentEligibility(canStart: true);
    }

    final latestEligibleAt = fullAssessmentDates.last.add(
      AssessmentRepository.fullAssessmentMinimumInterval,
    );
    DateTime? nextEligibleAt;
    var reason = FullAssessmentBlockReason.minimumInterval;

    if (now.isBefore(latestEligibleAt)) {
      nextEligibleAt = latestEligibleAt;
    }

    if (fullAssessmentDates.length >=
        AssessmentRepository.fullAssessmentLimit) {
      final rollingEligibleAt = fullAssessmentDates.first.add(
        AssessmentRepository.fullAssessmentWindow,
      );
      if (nextEligibleAt == null || rollingEligibleAt.isAfter(nextEligibleAt)) {
        nextEligibleAt = rollingEligibleAt;
        reason = FullAssessmentBlockReason.rollingLimit;
      }
    }

    if (nextEligibleAt == null || !now.isBefore(nextEligibleAt)) {
      return const FullAssessmentEligibility(canStart: true);
    }

    return FullAssessmentEligibility(
      canStart: false,
      nextEligibleAt: nextEligibleAt,
      reason: reason,
    );
  }

  final bool canStart;
  final DateTime? nextEligibleAt;
  final FullAssessmentBlockReason? reason;
}
