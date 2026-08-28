import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/repositories/assessment_repository.dart';

void main() {
  test('full assessment request declares the agreement contract', () async {
    String? calledFunction;
    Map<String, Object>? payload;
    final client = FirebaseAssessmentSubmissionClient(
      currentUserId: () => 'user_1',
      requestPreflight: () async {},
      callableInvoker: (name, data) async {
        calledFunction = name;
        payload = data;
        return <String, Object>{'assessmentId': 'full_user_1_submission_123'};
      },
    );

    await client.submitFullAssessment(
      submissionId: 'submission_123',
      responseScaleVersion: 'agreement5_v2',
      questionSetVersion: 'experimental_role_based_v2_agreement',
      answers: const [
        {
          'questionId': 'academic_core_1',
          'answer': 'stronglyAgree',
          'isSkipped': false,
        },
      ],
    );

    expect(calledFunction, 'submitFullAssessment');
    expect(payload?['responseScaleVersion'], 'agreement5_v2');
    expect(
      payload?['questionSetVersion'],
      'experimental_role_based_v2_agreement',
    );
    expect(
      (payload?['answers'] as List).single,
      containsPair('answer', 'stronglyAgree'),
    );
    expect(payload.toString(), isNot(contains('always')));
  });

  test('prepares once and does not retry after unauthenticated', () async {
    var calls = 0;
    var refreshes = 0;
    final client = FirebaseAssessmentSubmissionClient(
      currentUserId: () => 'user_1',
      refreshAuthToken: () async => refreshes++,
      callableInvoker: (name, data) async {
        calls++;
        if (calls == 1) {
          throw FirebaseFunctionsException(
            code: 'unauthenticated',
            message: 'stale auth token',
          );
        }
        return {'assessmentId': 'quick_user_1'};
      },
    );

    await expectLater(
      client.submitQuickAssessment(
        submissionId: 'submission_123',
        role: 'student',
        name: 'Test User',
        responses: const [],
      ),
      throwsA(
        isA<FirebaseFunctionsException>().having(
          (error) => error.code,
          'code',
          'unauthenticated',
        ),
      ),
    );
    expect(calls, 1);
    expect(refreshes, 1);
  });

  test('does not retry permission errors', () async {
    var calls = 0;
    var refreshes = 0;
    final client = FirebaseAssessmentSubmissionClient(
      currentUserId: () => 'user_1',
      refreshAuthToken: () async => refreshes++,
      callableInvoker: (name, data) async {
        calls++;
        throw FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'denied',
        );
      },
    );

    await expectLater(
      client.submitQuickAssessment(
        submissionId: 'submission_123',
        role: 'student',
        name: 'Test User',
        responses: const [],
      ),
      throwsA(isA<FirebaseFunctionsException>()),
    );
    expect(calls, 1);
    expect(refreshes, 1);
  });

  test(
    'requires a live authenticated user before calling the backend',
    () async {
      var calls = 0;
      final client = FirebaseAssessmentSubmissionClient(
        currentUserId: () => null,
        callableInvoker: (name, data) async {
          calls++;
          return <String, Object>{};
        },
      );

      await expectLater(
        client.submitQuickAssessment(
          submissionId: 'submission_123',
          role: 'student',
          name: 'Test User',
          responses: const [],
        ),
        throwsA(
          isA<FirebaseFunctionsException>().having(
            (error) => error.code,
            'code',
            'unauthenticated',
          ),
        ),
      );
      expect(calls, 0);
    },
  );
}
