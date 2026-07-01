import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/quick_assessment/models/quick_assessment_models.dart';
import 'package:mind_mates/features/student_assessment/data/student_assessment_questions.dart';
import 'package:mind_mates/features/student_assessment/models/student_assessment_models.dart';
import 'package:mind_mates/features/student_assessment/services/student_assessment_calculator.dart';
import 'package:mind_mates/providers/assessment_provider.dart';
import 'package:mind_mates/repositories/assessment_repository.dart';

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
  });
}
