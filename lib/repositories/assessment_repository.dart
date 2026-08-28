import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../database/firestore_collections.dart';
import '../features/quick_assessment/models/quick_assessment_models.dart';
import '../features/student_assessment/models/student_assessment_models.dart';
import '../services/firebase/firestore_service.dart';
import '../services/firebase/firebase_app_check_service.dart';
import '../services/firebase/firebase_callable_router.dart';
import '../services/firebase/firebase_runtime_diagnostics.dart';

abstract class AssessmentSubmissionClient {
  Future<Map<String, Object>> submitQuickAssessment({
    required String submissionId,
    required String role,
    required String name,
    required List<Map<String, Object>> responses,
  });

  Future<Map<String, Object>> submitFullAssessment({
    required String submissionId,
    required String responseScaleVersion,
    required String questionSetVersion,
    required List<Map<String, Object>> answers,
  });
}

typedef AssessmentCallableInvoker =
    Future<Object?> Function(String functionName, Map<String, Object> data);
typedef AssessmentRequestPreflight = Future<void> Function();
typedef AssessmentStatusChecker = Future<bool> Function(String userId);

class FirebaseAssessmentSubmissionClient implements AssessmentSubmissionClient {
  FirebaseAssessmentSubmissionClient({
    this._functions,
    FirebaseAuth? firebaseAuth,
    String? Function()? currentUserId,
    Future<void> Function()? refreshAuthToken,
    AssessmentRequestPreflight? requestPreflight,
    this.callableInvoker,
  }) : _firebaseAuthOverride = firebaseAuth,
       _currentUserIdOverride = currentUserId,
       _hasCurrentUserIdOverride = currentUserId != null,
       _refreshAuthTokenOverride = refreshAuthToken,
       _requestPreflightOverride = requestPreflight;

  final FirebaseFunctions? _functions;
  final FirebaseAuth? _firebaseAuthOverride;
  final String? Function()? _currentUserIdOverride;
  final bool _hasCurrentUserIdOverride;
  final Future<void> Function()? _refreshAuthTokenOverride;
  final AssessmentRequestPreflight? _requestPreflightOverride;
  final AssessmentCallableInvoker? callableInvoker;

  FirebaseAuth get _firebaseAuth =>
      _firebaseAuthOverride ?? FirebaseAuth.instance;

  FirebaseFunctions get _instance =>
      _functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  Future<Map<String, Object>> submitQuickAssessment({
    required String submissionId,
    required String role,
    required String name,
    required List<Map<String, Object>> responses,
  }) async {
    _logAssessmentRequest(
      functionName: 'submitQuickAssessment',
      submissionId: submissionId,
      role: role,
      items: responses,
    );
    final data = {
      'submissionId': submissionId,
      'role': role,
      'name': name,
      'responses': responses,
    };
    final result = await _callPrepared('submitQuickAssessment', data);
    final mapped = _mapResult(result);
    developer.log(
      'Assessment callable returned a verified response.',
      name: 'AssessmentSubmission',
      error: <String, Object?>{
        'function': 'submitQuickAssessment',
        'submissionId': submissionId,
        'correlationId': mapped['correlationId']?.toString() ?? '',
      },
    );
    return mapped;
  }

  @override
  Future<Map<String, Object>> submitFullAssessment({
    required String submissionId,
    required String responseScaleVersion,
    required String questionSetVersion,
    required List<Map<String, Object>> answers,
  }) async {
    _logAssessmentRequest(
      functionName: 'submitFullAssessment',
      submissionId: submissionId,
      items: answers,
      responseScaleVersion: responseScaleVersion,
      questionSetVersion: questionSetVersion,
    );
    final result = await _callPrepared('submitFullAssessment', {
      'submissionId': submissionId,
      'responseScaleVersion': responseScaleVersion,
      'questionSetVersion': questionSetVersion,
      'answers': answers,
    });
    try {
      final mapped = _mapResult(result);
      developer.log(
        'Assessment callable returned a verified response.',
        name: 'AssessmentSubmission',
        error: <String, Object?>{
          'function': 'submitFullAssessment',
          'submissionId': submissionId,
          'correlationId': mapped['correlationId']?.toString() ?? '',
        },
      );
      return mapped;
    } catch (error, stackTrace) {
      developer.log(
        'Assessment callable returned an invalid response.',
        name: 'AssessmentSubmission',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  void _logAssessmentRequest({
    required String functionName,
    required String submissionId,
    required List<Map<String, Object>> items,
    String? role,
    String? responseScaleVersion,
    String? questionSetVersion,
  }) {
    final ids = items
        .map((answer) => answer['questionId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final metadata = <String, Object>{
      'function': functionName,
      'submissionId': submissionId,
      'answerCount': items.length,
      'firstQuestionId': ids.isEmpty ? '' : ids.first,
      'lastQuestionId': ids.isEmpty ? '' : ids.last,
    };
    if (role != null) metadata['role'] = role;
    if (responseScaleVersion != null) {
      metadata['responseScaleVersion'] = responseScaleVersion;
    }
    if (questionSetVersion != null) {
      metadata['questionSetVersion'] = questionSetVersion;
    }
    developer.log(
      'Submitting assessment request.',
      name: 'AssessmentSubmission',
      error: metadata,
    );
  }

  Future<dynamic> _callPrepared(
    String functionName,
    Map<String, Object> data,
  ) async {
    if (_currentUserId == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Sign in is required before submitting an assessment.',
      );
    }

    try {
      await _prepareRequest();
    } catch (error) {
      FirebaseRuntimeDiagnostics.log(
        event: '${functionName}_preflight_failed',
        error: error,
      );
      rethrow;
    }
    try {
      return await _invoke(functionName, data);
    } on FirebaseFunctionsException catch (error) {
      FirebaseRuntimeDiagnostics.log(
        event: '${functionName}_callable_failed',
        error: error,
      );
      // Do not relabel every unauthenticated response as App Check. The
      // callable can reject an expired/invalid Auth token as well. Local App
      // Check failures are surfaced by requireToken() before this boundary,
      // while the original Firebase code remains available for Auth errors.
      rethrow;
    }
  }

  Future<void> _prepareRequest() async {
    final override = _requestPreflightOverride;
    if (override != null) return override();
    final legacyOverride = _refreshAuthTokenOverride;
    if (legacyOverride != null) return legacyOverride();
    await _firebaseAuth.currentUser!.getIdToken(true);
    await FirebaseAppCheckService.refreshToken();
    await FirebaseAppCheckService.requireToken();
  }

  String? get _currentUserId => _hasCurrentUserIdOverride
      ? _currentUserIdOverride!.call()
      : _firebaseAuth.currentUser?.uid;

  Future<Object?> _invoke(String functionName, Map<String, Object> data) {
    final override = callableInvoker;
    if (override != null) return override(functionName, data);
    return _instance
        .routedCallable(functionName)
        .call<Object?>(data)
        .then((result) => result.data);
  }

  static Map<String, Object> _mapResult(Object? value) {
    if (value is! Map) {
      throw const FormatException(
        'Assessment submission returned invalid data.',
      );
    }
    return Map<String, Object>.from(value);
  }
}

class AssessmentRepository {
  AssessmentRepository({
    FirestoreService? firestoreService,
    AssessmentSubmissionClient? submissionClient,
    this._statusChecker,
  }) : _firestoreService = firestoreService ?? FirestoreService(),
       _submissionClient =
           submissionClient ?? FirebaseAssessmentSubmissionClient();

  static const fullAssessmentLimit = 2;
  static const fullAssessmentWindow = Duration(days: 7);
  static const fullAssessmentMinimumInterval = Duration(days: 2);

  final FirestoreService _firestoreService;
  final AssessmentSubmissionClient _submissionClient;
  final AssessmentStatusChecker? _statusChecker;

  Future<Map<String, Object>> saveQuickAssessment({
    required String userId,
    required QuickAssessmentResult result,
    String? submissionId,
  }) async {
    return _submissionClient.submitQuickAssessment(
      submissionId: submissionId ?? _submissionId(),
      role: result.role.populationRole.storedValue,
      name: result.name,
      responses: result.responses
          .map(
            (response) => <String, Object>{
              'questionId': response.questionId,
              'optionId': response.optionId,
              'value': response.value,
            },
          )
          .toList(growable: false),
    );
  }

  static String quickAssessmentDocumentId(String userId) => 'quick_$userId';

  Future<bool> ensureQuickAssessmentCompletion(String userId) async {
    final override = _statusChecker;
    if (override != null) return override(userId);
    final auth = FirebaseAuth.instance.currentUser;
    if (auth == null || auth.uid != userId) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'Sign in is required to check assessment status.',
      );
    }
    // Refreshing App Check immediately before every status request can make
    // the Android debug provider hit Firebase's token-attempt throttle. The
    // callable client attaches the cached App Check token automatically; a
    // non-forced read is enough to fail fast with a useful configuration
    // error while avoiding repeated token generation on login/retry.
    await auth.getIdToken(true);
    await FirebaseAppCheckService.requireToken();
    final result = await FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).routedCallable('getAssessmentStatus').call<Object?>();
    if (result.data is! Map) {
      throw const FormatException('Assessment status returned invalid data.');
    }
    return (result.data as Map)['completed'] == true;
  }

  Future<Map<String, Object>> saveStudentAssessment({
    required String userId,
    required StudentAssessmentResult result,
    List<StudentAssessmentAnswer> answers = const [],
    String? submissionId,
  }) async {
    return _submissionClient.submitFullAssessment(
      submissionId: submissionId ?? _submissionId(),
      responseScaleVersion: result.responseScaleVersion,
      questionSetVersion: result.interpretation.questionSetVersion,
      answers: answers
          .map(
            (answer) => <String, Object>{
              'questionId': answer.questionId,
              'answer': answer.answer.name,
              'isSkipped': answer.isSkipped,
            },
          )
          .toList(growable: false),
    );
  }

  Future<void> saveAssessmentClarityFeedback({
    required String clarity,
    required String algorithmVersion,
    required String questionSetVersion,
  }) async {
    await _firestoreService
        .createDocument(FirestoreCollections.assessmentFeedback, {
          'clarity': clarity,
          'algorithmVersion': algorithmVersion,
          'questionSetVersion': questionSetVersion,
          'createdAt': FieldValue.serverTimestamp(),
        });
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
    final docs = await _firestoreService.getDocuments(
      FirestoreCollections.assessments,
      whereEquals: {'userId': userId},
      orderBy: 'createdAt',
      descending: true,
    );

    final fullAssessmentDates = docs
        .where((doc) => doc['type'] != 'quick')
        .map((doc) => _dateFromValue(doc['createdAt']))
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

  static String _submissionId() =>
      'submission_${DateTime.now().microsecondsSinceEpoch}';
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
