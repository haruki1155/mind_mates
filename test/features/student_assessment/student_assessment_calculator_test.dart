import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/student_assessment/screens/student_assessment_complete_screen.dart';
import 'package:mind_mates/features/student_assessment/screens/student_assessment_screen.dart';
import 'package:mind_mates/features/quick_assessment/models/quick_assessment_models.dart';
import 'package:mind_mates/features/quick_assessment/widgets/quick_assessment_widgets.dart';
import 'package:mind_mates/features/student_assessment/data/student_assessment_questions.dart';
import 'package:mind_mates/features/student_assessment/models/student_assessment_models.dart';
import 'package:mind_mates/features/student_assessment/services/student_assessment_calculator.dart';
import 'package:mind_mates/models/report_model.dart';
import 'package:mind_mates/models/user_model.dart';
import 'package:mind_mates/providers/assessment_provider.dart';
import 'package:mind_mates/providers/report_provider.dart';
import 'package:mind_mates/providers/user_provider.dart';
import 'package:mind_mates/repositories/assessment_repository.dart';
import 'package:mind_mates/repositories/report_repository.dart';
import 'package:mind_mates/repositories/user_repository.dart';
import 'package:provider/provider.dart';

void main() {
  group('StudentAssessmentCalculator', () {
    test('scores risk and protective answers correctly', () {
      expect(
        StudentAssessmentCalculator.riskScore(
          answer: LikertAnswer.always,
          direction: AssessmentDirection.risk,
        ),
        100,
      );
      expect(
        StudentAssessmentCalculator.riskScore(
          answer: LikertAnswer.always,
          direction: AssessmentDirection.protective,
        ),
        0,
      );
    });

    test('triggers deeper academic questions for elevated core answers', () {
      final answers = [
        const StudentAssessmentAnswer(
          questionId: 'academic_core_1',
          answer: LikertAnswer.always,
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
      expect(result.status, 'Moderate Well-Being');
      expect(result.totalResponses, questions.length);
      expect(result.subscaleScores['Sleep and Rest'], 50);
    });

    test(
      'does not trigger faculty deeper questions from protective answers',
      () {
        const answers = [
          StudentAssessmentAnswer(
            questionId: 'faculty_workplace_core_1',
            answer: LikertAnswer.always,
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
    });

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

    test(
      'blocks full assessment when one exists in the current week',
      () async {
        final provider = AssessmentProvider(
          _FakeAssessmentRepository(hasFullThisWeek: true),
        );

        final canStart = await provider.canStartFullAssessmentThisWeek(
          'user_1',
          now: DateTime(2026, 7, 3),
        );

        expect(canStart, isFalse);
      },
    );
  });

  group('StudentAssessmentScreen UI', () {
    testWidgets('neutral option is not preselected', (tester) async {
      final provider = AssessmentProvider(AssessmentRepository())
        ..startStudentAssessment();

      await tester.pumpWidget(
        ChangeNotifierProvider<AssessmentProvider>.value(
          value: provider,
          child: const MaterialApp(home: StudentAssessmentScreen()),
        ),
      );
      await tester.pump();

      final neutralMaterial = tester.widget<Material>(
        find
            .ancestor(of: find.text('Neutral'), matching: find.byType(Material))
            .first,
      );

      expect(neutralMaterial.color, QuickAssessmentPalette.card);
    });
  });

  group('StudentAssessmentCompleteScreen', () {
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
    });
  });
}

void _completeAssessment(AssessmentProvider provider) {
  var guard = 0;
  while (provider.studentResult == null && guard < 100) {
    provider.answerCurrentStudentQuestion(LikertAnswer.sometimes);
    guard += 1;
  }
}

class _FakeAssessmentRepository extends AssessmentRepository {
  _FakeAssessmentRepository({this.hasFullThisWeek = false});

  final bool hasFullThisWeek;
  String? savedFullAssessmentUserId;

  @override
  Future<bool> hasFullAssessmentThisWeek(String userId, {DateTime? now}) async {
    return hasFullThisWeek;
  }

  @override
  Future<Map<String, Object>> saveStudentAssessment({
    required String userId,
    required StudentAssessmentResult result,
    List<StudentAssessmentAnswer> answers = const [],
  }) async {
    savedFullAssessmentUserId = userId;
    return {
      'userId': userId,
      'type': result.userType.toLowerCase(),
      ...result.toJson(),
    };
  }
}

class _FakeUserRepository extends UserRepository {
  @override
  Future<UserModel?> recordActivity(
    String uid,
    UserActivityType type, {
    DateTime? occurredAt,
  }) async {
    return UserModel(
      id: uid,
      email: 'leo@example.com',
      dayStreak: 1,
      activeDateKeys: const ['2026-07-03'],
    );
  }
}

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
