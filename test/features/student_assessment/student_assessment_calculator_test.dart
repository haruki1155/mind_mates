import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/student_assessment/screens/student_assessment_complete_screen.dart';
import 'package:mind_mates/features/student_assessment/screens/student_assessment_screen.dart';
import 'package:mind_mates/features/quick_assessment/models/quick_assessment_models.dart';
import 'package:mind_mates/features/student_assessment/data/student_assessment_questions.dart';
import 'package:mind_mates/features/student_assessment/models/student_assessment_models.dart';
import 'package:mind_mates/features/student_assessment/services/student_assessment_calculator.dart';
import 'package:mind_mates/models/report_model.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/providers/assessment_provider.dart';
import 'package:mind_mates/providers/auth_provider.dart';
import 'package:mind_mates/providers/report_provider.dart';
import 'package:mind_mates/providers/user_provider.dart';
import 'package:mind_mates/repositories/assessment_repository.dart';
import 'package:mind_mates/repositories/auth_repository.dart';
import 'package:mind_mates/repositories/report_repository.dart';
import 'package:mind_mates/repositories/user_repository.dart';
import 'package:mind_mates/services/firebase/firestore_service.dart';
import 'package:mind_mates/services/auth/auth_service.dart';
import 'package:provider/provider.dart';

void main() {
  test(
    'Flutter question catalogs match the shared agreement-scale role contract',
    () {
      final contract =
          jsonDecode(
                File(
                  'contracts/assessment_question_ids.v2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final roles = contract['roles'] as Map<String, dynamic>;

      expect(contract['version'], 'experimental_role_based_v2_agreement');
      expect(
        StudentAssessmentQuestions.questions.map((question) => question.id),
        _contractIds(roles['student'] as List<dynamic>),
      );
      expect(
        StudentAssessmentQuestions.facultyQuestions.map(
          (question) => question.id,
        ),
        _contractIds(roles['teaching'] as List<dynamic>),
      );
      expect(
        StudentAssessmentQuestions.staffQuestions.map(
          (question) => question.id,
        ),
        _contractIds(roles['nonTeaching'] as List<dynamic>),
      );
    },
  );

  group('StudentAssessmentCalculator', () {
    test('serializes the approved agreement response semantics', () {
      const answer = StudentAssessmentAnswer(
        questionId: 'academic_core_1',
        answer: LikertAnswer.stronglyAgree,
      );

      expect(LikertAnswer.stronglyAgree.label, 'Strongly Agree');
      expect(answer.toJson()['answer'], 'stronglyAgree');
      expect(answer.toJson()['value'], 5);
    });

    test('scores risk and protective answers correctly', () {
      expect(
        StudentAssessmentCalculator.riskScore(
          answer: LikertAnswer.stronglyAgree,
          direction: AssessmentDirection.risk,
        ),
        100,
      );
      expect(
        StudentAssessmentCalculator.riskScore(
          answer: LikertAnswer.stronglyAgree,
          direction: AssessmentDirection.protective,
        ),
        0,
      );
    });

    test('triggers deeper academic questions for elevated core answers', () {
      final answers = [
        const StudentAssessmentAnswer(
          questionId: 'academic_core_1',
          answer: LikertAnswer.stronglyAgree,
        ),
      ];

      expect(
        StudentAssessmentCalculator.shouldShowDeeperAcademicQuestions(
          questions: StudentAssessmentQuestions.questions,
          answers: answers,
        ),
        isTrue,
      );
    });

    test('does not count duplicate answer records twice', () {
      final questions = [
        for (var index = 0; index < 3; index++)
          StudentAssessmentQuestion(
            id: 'core_$index',
            text: 'Question $index',
            section: AssessmentSection.academicCore,
            direction: AssessmentDirection.risk,
          ),
      ];
      final answers = [
        for (final question in questions)
          StudentAssessmentAnswer(
            questionId: question.id,
            answer: LikertAnswer.never,
          ),
        const StudentAssessmentAnswer(
          questionId: 'core_0',
          answer: LikertAnswer.often,
        ),
      ];

      expect(
        StudentAssessmentCalculator.shouldShowDeeperQuestions(
          questions: questions,
          answers: answers,
          coreSection: AssessmentSection.academicCore,
        ),
        isFalse,
      );
    });

    test('ignores answers for unknown question IDs', () {
      final questions = [
        for (var index = 0; index < 3; index++)
          StudentAssessmentQuestion(
            id: 'known_$index',
            text: 'Question $index',
            section: AssessmentSection.academicCore,
            direction: AssessmentDirection.risk,
          ),
      ];
      final answers = [
        for (final question in questions)
          StudentAssessmentAnswer(
            questionId: question.id,
            answer: LikertAnswer.never,
          ),
        const StudentAssessmentAnswer(
          questionId: 'unknown',
          answer: LikertAnswer.always,
        ),
      ];

      expect(
        StudentAssessmentCalculator.shouldShowDeeperQuestions(
          questions: questions,
          answers: answers,
          coreSection: AssessmentSection.academicCore,
        ),
        isFalse,
      );
    });

    test('calculates weighted student result', () {
      final questions = StudentAssessmentQuestions.questions
          .where((question) => !question.isConditional)
          .toList();
      final answers = [
        for (final question in questions)
          StudentAssessmentAnswer(
            questionId: question.id,
            answer: LikertAnswer.sometimes,
          ),
      ];

      final result = StudentAssessmentCalculator.calculate(
        questions: questions,
        answers: answers,
      );

      expect(result.overallScore, 50);
      expect(result.status, 'Moderate Concern');
      expect(result.totalResponses, questions.length);
      expect(result.subscaleScores['Sleep and Rest'], 50);
      expect(
        result.interpretation.algorithmVersion,
        'internal_wellness_policy_v2_agreement',
      );
      expect(result.interpretation.responseQuality.completionPercent, 100);
    });

    test('excludes skipped responses and reports insufficient coverage', () {
      final questions = StudentAssessmentQuestions.questions
          .where((question) => !question.isConditional)
          .take(10)
          .toList();
      final answers = [
        for (var index = 0; index < questions.length; index++)
          StudentAssessmentAnswer(
            questionId: questions[index].id,
            answer: LikertAnswer.sometimes,
            isSkipped: index >= 5,
          ),
      ];

      final result = StudentAssessmentCalculator.calculate(
        questions: questions,
        answers: answers,
      );

      expect(result.totalResponses, 5);
      expect(result.interpretation.responseQuality.skipped, 5);
      expect(result.interpretation.responseQuality.completionPercent, 50);
      expect(
        result.interpretation.supportPriority.name,
        'insufficientResponses',
      );
    });

    test('protective answers are reversed and retained as strengths', () {
      final question = StudentAssessmentQuestions.questions.firstWhere(
        (item) => item.direction == AssessmentDirection.protective,
      );
      final result = StudentAssessmentCalculator.calculate(
        questions: [question],
        answers: [
          StudentAssessmentAnswer(
            questionId: question.id,
            answer: LikertAnswer.stronglyAgree,
          ),
        ],
      );

      expect(result.interpretation.protectiveFactors, contains(question.text));
    });

    test('does not report missing categories as zero concern', () {
      final questions = StudentAssessmentQuestions.questions
          .where(
            (question) => question.section == AssessmentSection.academicCore,
          )
          .toList();
      final answers = [
        for (final question in questions)
          StudentAssessmentAnswer(
            questionId: question.id,
            answer: LikertAnswer.never,
          ),
      ];

      final result = StudentAssessmentCalculator.calculate(
        questions: StudentAssessmentQuestions.questions
            .where((question) => !question.isConditional)
            .toList(),
        answers: answers,
      );

      expect(result.overallScore, isNull);
      expect(result.subscaleScores.containsKey('Sleep and Rest'), isFalse);
      expect(
        result.interpretation.domainResults
            .firstWhere((domain) => domain.domain == 'Sleep and Rest')
            .isScorable,
        isFalse,
      );
    });

    test(
      'conditional follow-up answers do not change the core domain score',
      () {
        final core = StudentAssessmentQuestions.questions
            .where(
              (question) => question.section == AssessmentSection.academicCore,
            )
            .toList();
        final deeper = StudentAssessmentQuestions.questions
            .where(
              (question) =>
                  question.section == AssessmentSection.academicDeeper,
            )
            .toList();
        final coreAnswers = [
          for (final question in core)
            StudentAssessmentAnswer(
              questionId: question.id,
              answer: LikertAnswer.often,
            ),
        ];
        final withoutFollowUps = StudentAssessmentCalculator.calculate(
          questions: [...core],
          answers: coreAnswers,
        );
        final withFollowUps = StudentAssessmentCalculator.calculate(
          questions: [...core, ...deeper],
          answers: [
            ...coreAnswers,
            for (final question in deeper)
              StudentAssessmentAnswer(
                questionId: question.id,
                answer: LikertAnswer.never,
              ),
          ],
        );

        expect(
          withFollowUps.subscaleScores['Academic Stress'],
          withoutFollowUps.subscaleScores['Academic Stress'],
        );
        expect(
          withFollowUps.interpretation.priorityRationale,
          contains('explicit follow-up or impact indicator'),
        );
      },
    );

    test('ranks main concern areas deterministically', () {
      expect(
        StudentAssessmentCalculator.getMainConcernAreas({
          'Sleep and Rest': 82,
          'Academic Stress': 91,
          'Social Connection': 91,
        }),
        ['Academic Stress', 'Social Connection', 'Sleep and Rest'],
      );
      expect(
        StudentAssessmentCalculator.getMainConcernAreas(
          {'Lower Weight': 81, 'Higher Weight': 81},
          weights: {'Lower Weight': 0.2, 'Higher Weight': 0.8},
        ),
        ['Higher Weight', 'Lower Weight'],
      );
    });

    test('uses consistent concern-band boundaries', () {
      expect(StudentAssessmentCalculator.getStatus(0), 'Low Concern');
      expect(StudentAssessmentCalculator.getStatus(20), 'Low Concern');
      expect(StudentAssessmentCalculator.getStatus(20.01), 'Watchful');
      expect(StudentAssessmentCalculator.getStatus(40), 'Watchful');
      expect(StudentAssessmentCalculator.getStatus(60), 'Moderate Concern');
      expect(StudentAssessmentCalculator.getStatus(80), 'Elevated Concern');
      expect(StudentAssessmentCalculator.getStatus(80.01), 'High Concern');
      expect(StudentAssessmentCalculator.getStatus(100), 'High Concern');
    });

    test(
      'serializes nullable results and answer metadata without losing values',
      () {
        const answer = StudentAssessmentAnswer(
          questionId: 'q1',
          answer: LikertAnswer.agree,
          isSkipped: true,
        );
        expect(answer.toJson(), {
          'questionId': 'q1',
          'answer': 'agree',
          'value': 4,
          'isSkipped': true,
        });

        final result = StudentAssessmentCalculator.calculate(
          questions: const [],
          answers: const [],
        );
        final json = result.toJson();
        expect(json['overallScore'], isNull);
        expect(json['status'], 'Insufficient Responses');
        expect(json['totalResponses'], 0);
        expect(json['interpretation'], isA<Map<String, Object>>());
      },
    );

    test(
      'does not trigger faculty deeper questions from protective answers',
      () {
        const answers = [
          StudentAssessmentAnswer(
            questionId: 'faculty_workplace_core_1',
            answer: LikertAnswer.stronglyAgree,
          ),
        ];

        expect(
          StudentAssessmentCalculator.shouldShowDeeperQuestions(
            questions: StudentAssessmentQuestions.facultyQuestions,
            answers: answers,
            coreSection: AssessmentSection.workplaceStressCore,
          ),
          isFalse,
        );
      },
    );

    test('calculates weighted faculty result', () {
      final questions = StudentAssessmentQuestions.facultyQuestions
          .where((question) => !question.isConditional)
          .toList();
      final answers = [
        for (final question in questions)
          StudentAssessmentAnswer(
            questionId: question.id,
            answer: LikertAnswer.sometimes,
          ),
      ];

      final result = StudentAssessmentCalculator.calculate(
        questions: questions,
        answers: answers,
        userType: AssessmentUserType.faculty,
      );

      expect(result.userType, 'Teaching Personnel');
      expect(result.overallScore, 50);
      expect(result.status, 'Moderate Concern');
      expect(result.subscaleScores['Workplace Stress'], 50);
      expect(result.subscaleScores['Professional Support'], 50);
    });

    test('calculates weighted staff result', () {
      final questions = StudentAssessmentQuestions.staffQuestions
          .where((question) => !question.isConditional)
          .toList();
      final answers = [
        for (final question in questions)
          StudentAssessmentAnswer(
            questionId: question.id,
            answer: LikertAnswer.sometimes,
          ),
      ];

      final result = StudentAssessmentCalculator.calculate(
        questions: questions,
        answers: answers,
        userType: AssessmentUserType.staff,
      );

      expect(result.userType, 'Non-Teaching Personnel');
      expect(result.overallScore, 50);
      expect(result.status, 'Moderate Concern');
      expect(result.subscaleScores['Workplace Responsibilities'], 50);
      expect(result.subscaleScores['Workplace Support'], 50);
    });
  });

  group('AssessmentProvider student assessment flow', () {
    test('inserts deeper academic questions after trigger point', () {
      final provider = AssessmentProvider(AssessmentRepository());
      provider.startStudentAssessment();

      for (var index = 0; index < 10; index += 1) {
        provider.answerCurrentStudentQuestion(LikertAnswer.always);
      }

      expect(
        provider.studentQuestions.any((question) => question.isConditional),
        isTrue,
      );
      expect(
        provider.currentStudentQuestion?.section,
        AssessmentSection.academicDeeper,
      );
      expect(provider.studentSectionCount, 5);
      expect(provider.studentSectionProgressLabel, 'Section 1 of 5');
      expect(provider.studentCategoryProgressLabel, 'Follow-up 1 of 10');
    });

    test('goes back and allows a previous answer to be changed', () {
      final provider = AssessmentProvider(AssessmentRepository())
        ..startStudentAssessment();

      provider.answerCurrentStudentQuestion(LikertAnswer.always);
      expect(provider.studentQuestionIndex, 1);

      provider.goBackStudentQuestion();
      expect(provider.studentQuestionIndex, 0);
      expect(provider.currentStudentAnswer, LikertAnswer.always);

      provider.answerCurrentStudentQuestion(LikertAnswer.rarely);
      expect(provider.studentQuestionIndex, 1);
      expect(
        provider.studentAnswers
            .singleWhere((answer) => answer.questionId == 'academic_core_1')
            .answer,
        LikertAnswer.rarely,
      );
    });

    test(
      'removes conditional questions when the trigger answer is corrected',
      () {
        final provider = AssessmentProvider(AssessmentRepository())
          ..startStudentAssessment();

        for (var index = 0; index < 10; index++) {
          provider.answerCurrentStudentQuestion(
            index == 9 ? LikertAnswer.always : LikertAnswer.never,
          );
        }
        expect(provider.currentStudentQuestion?.isConditional, isTrue);

        provider.goBackStudentQuestion();
        provider.answerCurrentStudentQuestion(LikertAnswer.never);

        expect(
          provider.studentQuestions.any((question) => question.isConditional),
          isFalse,
        );
        expect(
          provider.currentStudentQuestion?.section,
          AssessmentSection.financialConcern,
        );
      },
    );

    test('starts faculty questions from selected role', () {
      final provider = AssessmentProvider(AssessmentRepository());
      provider.selectRole(AssessmentRole.faculty);
      provider.startStudentAssessment();

      expect(provider.activeAssessmentTitle, 'Teaching Assessment');
      expect(
        provider.currentStudentQuestion?.section,
        AssessmentSection.workplaceStressCore,
      );
    });

    test('starts staff questions from selected role', () {
      final provider = AssessmentProvider(AssessmentRepository());
      provider.selectRole(AssessmentRole.staff);
      provider.startStudentAssessment();

      expect(provider.activeAssessmentTitle, 'Non-Teaching Assessment');
      expect(
        provider.currentStudentQuestion?.section,
        AssessmentSection.workplaceResponsibilityCore,
      );
    });

    test('allows full assessment when none were completed recently', () {
      final eligibility = FullAssessmentEligibility.fromCompletedDates(
        completedAt: const [],
        now: DateTime(2026, 7, 3, 9),
      );

      expect(eligibility.canStart, isTrue);
    });

    test('blocks full assessment until 2 days after latest completion', () {
      final eligibility = FullAssessmentEligibility.fromCompletedDates(
        completedAt: [DateTime(2026, 7, 2, 9)],
        now: DateTime(2026, 7, 3, 9),
      );

      expect(eligibility.canStart, isFalse);
      expect(eligibility.nextEligibleAt, DateTime(2026, 7, 4, 9));
      expect(eligibility.reason, FullAssessmentBlockReason.minimumInterval);
    });

    test('allows full assessment 2 days after one completion', () {
      final eligibility = FullAssessmentEligibility.fromCompletedDates(
        completedAt: [DateTime(2026, 7, 1, 9)],
        now: DateTime(2026, 7, 3, 9),
      );

      expect(eligibility.canStart, isTrue);
    });

    test('blocks after 2 full assessments in a rolling 7-day period', () {
      final eligibility = FullAssessmentEligibility.fromCompletedDates(
        completedAt: [DateTime(2026, 6, 29, 9), DateTime(2026, 7, 1, 9)],
        now: DateTime(2026, 7, 3, 9),
      );

      expect(eligibility.canStart, isFalse);
      expect(eligibility.nextEligibleAt, DateTime(2026, 7, 6, 9));
      expect(eligibility.reason, FullAssessmentBlockReason.rollingLimit);
    });

    test(
      'uses the later interval date when it is after the rolling window',
      () {
        final eligibility = FullAssessmentEligibility.fromCompletedDates(
          completedAt: [DateTime(2026, 6, 27, 9), DateTime(2026, 7, 3, 8)],
          now: DateTime(2026, 7, 3, 9),
        );

        expect(eligibility.canStart, isFalse);
        expect(eligibility.nextEligibleAt, DateTime(2026, 7, 5, 8));
        expect(eligibility.reason, FullAssessmentBlockReason.minimumInterval);
      },
    );
  });

  group('AssessmentRepository full assessment eligibility', () {
    test(
      'uses indexed user and descending createdAt query and ignores quick records',
      () async {
        final firestore = _EligibilityFirestoreService(
          docs: [
            {
              'type': 'quick',
              'createdAt': DateTime(2026, 7, 3, 9).toIso8601String(),
            },
            {
              'type': 'student',
              'createdAt': DateTime(2026, 7, 2, 9).toIso8601String(),
            },
          ],
        );
        final repository = AssessmentRepository(firestoreService: firestore);

        final eligibility = await repository.fullAssessmentEligibility(
          'user_1',
          now: DateTime(2026, 7, 3, 9),
        );

        expect(firestore.collection, 'assessments');
        expect(firestore.whereEquals, {'userId': 'user_1'});
        expect(firestore.orderBy, 'createdAt');
        expect(firestore.descending, isTrue);
        expect(eligibility.canStart, isFalse);
        expect(eligibility.nextEligibleAt, DateTime(2026, 7, 4, 9));
        expect(eligibility.reason, FullAssessmentBlockReason.minimumInterval);
      },
    );
  });

  group('StudentAssessmentScreen UI', () {
    testWidgets(
      'selection waits for Continue and persists when navigating back',
      (tester) async {
        final provider = AssessmentProvider(AssessmentRepository())
          ..startStudentAssessment();

        await tester.pumpWidget(
          ChangeNotifierProvider<AssessmentProvider>.value(
            value: provider,
            child: const MaterialApp(home: StudentAssessmentScreen()),
          ),
        );
        await tester.pump();

        FilledButton continueButton() => tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Continue'),
        );

        expect(provider.currentStudentAnswer, isNull);
        expect(continueButton().onPressed, isNull);

        await tester.tap(find.text('Neutral'));
        await tester.pump();

        expect(provider.studentQuestionIndex, 0);
        expect(provider.currentStudentAnswer, LikertAnswer.neutral);
        expect(continueButton().onPressed, isNotNull);

        await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
        await tester.pumpAndSettle();

        expect(provider.studentQuestionIndex, 1);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();

        expect(provider.studentQuestionIndex, 0);
        expect(provider.currentStudentAnswer, LikertAnswer.neutral);
        expect(continueButton().onPressed, isNotNull);
        expect(find.text('Skip'), findsNothing);
      },
    );

    testWidgets('core controls support large text and reduced motion', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final provider = AssessmentProvider(AssessmentRepository())
        ..startStudentAssessment();

      await tester.pumpWidget(
        ChangeNotifierProvider<AssessmentProvider>.value(
          value: provider,
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(430, 900),
                textScaler: TextScaler.linear(1.8),
                disableAnimations: true,
              ),
              child: StudentAssessmentScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Strongly Disagree'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('StudentAssessmentCompleteScreen', () {
    test('full-assessment retry reuses the original submission ID', () async {
      final repository = _FakeAssessmentRepository(failuresBeforeSuccess: 1);
      final provider = AssessmentProvider(repository)..startStudentAssessment();
      _completeAssessment(provider);

      await expectLater(
        provider.saveStudentAssessmentForUser('user_1'),
        throwsA(isA<StateError>()),
      );
      expect(provider.hasVerifiedStudentResult, isFalse);

      final payload = await provider.saveStudentAssessmentForUser('user_1');

      expect(payload, isNotNull);
      expect(provider.hasVerifiedStudentResult, isTrue);
      expect(repository.submissionIds, hasLength(2));
      expect(repository.submissionIds.toSet(), hasLength(1));
    });

    testWidgets('saving full assessment refreshes weekly report', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final assessmentRepository = _FakeAssessmentRepository();
      final assessmentProvider = AssessmentProvider(assessmentRepository)
        ..startStudentAssessment();
      _completeAssessment(assessmentProvider);
      final userProvider = UserProvider(_FakeUserRepository())
        ..setUser(const UserModel(id: 'user_1', email: 'leo@example.com'));
      final reportRepository = _FakeReportRepository();
      final reportProvider = ReportProvider(reportRepository);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AssessmentProvider>.value(
              value: assessmentProvider,
            ),
            ChangeNotifierProvider<AuthProvider>(
              create: (_) =>
                  AuthProvider(_FakeAuthRepository(currentUserId: 'user_1')),
            ),
            ChangeNotifierProvider<UserProvider>.value(value: userProvider),
            ChangeNotifierProvider<ReportProvider>.value(value: reportProvider),
          ],
          child: const MaterialApp(home: StudentAssessmentCompleteScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(assessmentRepository.savedFullAssessmentUserId, 'user_1');
      expect(reportRepository.generatedForUserId, 'user_1');
      expect(
        reportProvider.latestReport?.latestAssessmentSource,
        'fullAssessment',
      );
      expect(
        find.text(
          assessmentProvider.studentResult!.interpretation.counselorSummary,
        ),
        findsNothing,
      );
    });
  });
}

List<String> _contractIds(List<dynamic> groups) {
  return groups
      .expand((rawGroup) {
        final group = rawGroup as Map<String, dynamic>;
        final prefix = group['prefix'] as String;
        final count = group['count'] as int;
        return List.generate(count, (index) => '$prefix${index + 1}');
      })
      .toList(growable: false);
}

void _completeAssessment(AssessmentProvider provider) {
  var guard = 0;
  while (provider.studentResult == null && guard < 100) {
    provider.answerCurrentStudentQuestion(LikertAnswer.sometimes);
    guard += 1;
  }
}

class _FakeAssessmentRepository extends AssessmentRepository {
  _FakeAssessmentRepository({this.failuresBeforeSuccess = 0});

  String? savedFullAssessmentUserId;
  int failuresBeforeSuccess;
  final submissionIds = <String>[];

  @override
  Future<Map<String, Object>> saveStudentAssessment({
    required String userId,
    required StudentAssessmentResult result,
    List<StudentAssessmentAnswer> answers = const [],
    String? submissionId,
  }) async {
    savedFullAssessmentUserId = userId;
    submissionIds.add(submissionId!);
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess -= 1;
      throw StateError('temporary submission failure');
    }
    return {
      'userId': userId,
      'type': result.userType.toLowerCase(),
      ...result.toJson(),
    };
  }
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({this.currentUserId}) : super(AuthService());

  @override
  String? currentUserId;
}

class _EligibilityFirestoreService extends FirestoreService {
  _EligibilityFirestoreService({required this.docs});

  final List<Map<String, dynamic>> docs;
  String? collection;
  Map<String, Object?>? whereEquals;
  String? orderBy;
  bool? descending;

  @override
  Future<List<Map<String, dynamic>>> getDocuments(
    String collection, {
    Map<String, Object?> whereEquals = const {},
    String? orderBy,
    bool descending = true,
    int? limit,
    bool requiresAuthentication = true,
  }) async {
    this.collection = collection;
    this.whereEquals = whereEquals;
    this.orderBy = orderBy;
    this.descending = descending;
    return docs;
  }
}

class _FakeUserRepository extends UserRepository {}

class _FakeReportRepository extends ReportRepository {
  String? generatedForUserId;
  ReportModel? latest;

  @override
  Future<String> generateWeeklyReport(String userId, {DateTime? now}) async {
    generatedForUserId = userId;
    latest = ReportModel(
      id: 'report_1',
      userId: userId,
      generatedAt: DateTime(2026, 7, 3),
      description: 'Latest full assessment shows Moderate Concern concern.',
      hasEnoughData: true,
      latestAssessmentSource: 'fullAssessment',
    );
    return 'report_1';
  }

  @override
  Future<ReportModel?> fetchLatestReport(String userId) async => latest;
}
