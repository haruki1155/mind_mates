import '../models/student_assessment_models.dart';
import '../config/assessment_policy.dart';
import 'assessment_interpretation_engine.dart';

enum AssessmentUserType { student, faculty, staff }

class StudentAssessmentCalculator {
  const StudentAssessmentCalculator._();

  static const double minimumDomainCompletion =
      AssessmentPolicy.minimumDomainCompletion;
  static const int minimumDomainAnswers = AssessmentPolicy.minimumDomainAnswers;

  static double riskScore({
    required LikertAnswer answer,
    required AssessmentDirection direction,
  }) {
    return direction == AssessmentDirection.protective
        ? ((5 - answer.value) / 4) * 100
        : ((answer.value - 1) / 4) * 100;
  }

  static bool shouldShowDeeperAcademicQuestions({
    required List<StudentAssessmentQuestion> questions,
    required List<StudentAssessmentAnswer> answers,
  }) => shouldShowDeeperQuestions(
    questions: questions,
    answers: answers,
    coreSection: AssessmentSection.academicCore,
  );

  static bool shouldShowDeeperQuestions({
    required List<StudentAssessmentQuestion> questions,
    required List<StudentAssessmentAnswer> answers,
    required AssessmentSection coreSection,
  }) {
    final coreQuestions = questions
        .where(
          (question) =>
              question.section == coreSection &&
              question.direction == AssessmentDirection.risk,
        )
        .toList();
    var stronglyAgreeCount = 0;
    var agreeOrStronglyAgreeCount = 0;
    final coreScores = <double>[];

    // A corrected answer may be represented more than once by callers that
    // append to an answer log. Score the latest answer once per question so
    // duplicates cannot inflate the deeper-question trigger.
    final answerById = {
      for (final answer in answers) answer.questionId: answer,
    };
    for (final answer in answerById.values.where(
      (answer) => !answer.isSkipped,
    )) {
      final question = coreQuestions
          .where((question) => question.id == answer.questionId)
          .firstOrNull;
      if (question == null) continue;
      if (answer.answer == LikertAnswer.stronglyAgree) stronglyAgreeCount++;
      if (answer.answer == LikertAnswer.agree ||
          answer.answer == LikertAnswer.stronglyAgree) {
        agreeOrStronglyAgreeCount++;
      }
      coreScores.add(
        riskScore(answer: answer.answer, direction: question.direction),
      );
    }

    return stronglyAgreeCount >= AssessmentPolicy.deeperStronglyAgreeCount ||
        agreeOrStronglyAgreeCount >=
            AssessmentPolicy.deeperAgreeOrStronglyAgreeCount ||
        _average(coreScores) >= AssessmentPolicy.deeperAverageScore;
  }

  static StudentAssessmentResult calculate({
    required List<StudentAssessmentQuestion> questions,
    required List<StudentAssessmentAnswer> answers,
    AssessmentUserType userType = AssessmentUserType.student,
  }) {
    final config = _RoleConfig.forType(userType);
    final domainScores = <String, double>{};
    final scorableDomains = <String, bool>{};
    final weights = <String, double>{};

    for (final domain in config.domains) {
      final score = _scoreDomain(
        questions: questions,
        answers: answers,
        sections: domain.scoredSections,
      );
      scorableDomains[domain.label] = score.isScorable;
      weights[domain.label] = domain.weight;
      if (score.isScorable) domainScores[domain.label] = _round(score.score!);
    }

    final allRequiredScorable = config.domains.every(
      (domain) => scorableDomains[domain.label] == true,
    );
    final overallScore = allRequiredScorable
        ? _round(
            config.domains.fold<double>(
              0,
              (total, domain) =>
                  total + domainScores[domain.label]! * domain.weight,
            ),
          )
        : null;
    final status = overallScore == null
        ? 'Insufficient Responses'
        : getStatus(overallScore);
    final interpretation = AssessmentInterpretationEngine.build(
      questions: questions,
      answers: answers,
      domainScores: domainScores,
      domainSections: {
        for (final domain in config.domains) domain.label: domain.allSections,
      },
      userType: config.userLabel,
    );

    return StudentAssessmentResult(
      userType: config.userLabel,
      overallScore: overallScore,
      status: status,
      subscaleScores: domainScores,
      mainConcernAreas: getMainConcernAreas(domainScores, weights: weights),
      message: overallScore == null
          ? 'Some wellness categories did not have enough responses for a dependable summary. Review the category results that are available.'
          : getMessage(status),
      disclaimer: _pilotDisclaimer,
      totalResponses: answers.where((answer) => !answer.isSkipped).length,
      interpretation: interpretation,
    );
  }

  static String getStatus(double score) {
    if (score <= AssessmentPolicy.lowConcernMaximum) return 'Low Concern';
    if (score <= AssessmentPolicy.watchfulMaximum) return 'Watchful';
    if (score <= AssessmentPolicy.moderateConcernMaximum) {
      return 'Moderate Concern';
    }
    if (score <= AssessmentPolicy.elevatedConcernMaximum) {
      return 'Elevated Concern';
    }
    return 'High Concern';
  }

  static String getMessage(String status) => switch (status) {
    'Low Concern' =>
      'Your answered categories currently show a relatively low concern pattern. Continue the routines and support that are working for you.',
    'Watchful' =>
      'Your responses suggest some areas worth watching. Small supportive habits and regular check-ins may help you notice changes.',
    'Moderate Concern' =>
      'Your responses show noticeable strain in one or more wellness areas. Review the category details and consider talking with someone you trust.',
    'Elevated Concern' =>
      'Your responses show elevated strain. A conversation with university wellness support or a qualified professional may be helpful.',
    'High Concern' =>
      'Your responses show a high concern pattern. Timely support from the university guidance office or a qualified professional is recommended.',
    _ => 'Your category results are ready to review.',
  };

  static List<String> getMainConcernAreas(
    Map<String, double> scores, {
    Map<String, double> weights = const {},
  }) {
    final ranked =
        scores.entries
            .where((entry) => entry.value > AssessmentPolicy.mainConcernScore)
            .toList()
          ..sort((left, right) {
            final scoreOrder = right.value.compareTo(left.value);
            if (scoreOrder != 0) return scoreOrder;
            final weightOrder = (weights[right.key] ?? 0).compareTo(
              weights[left.key] ?? 0,
            );
            if (weightOrder != 0) return weightOrder;
            return left.key.compareTo(right.key);
          });
    return ranked.map((entry) => entry.key).toList(growable: false);
  }

  static _DomainScore _scoreDomain({
    required List<StudentAssessmentQuestion> questions,
    required List<StudentAssessmentAnswer> answers,
    required Set<AssessmentSection> sections,
  }) {
    final presented = questions
        .where((question) => sections.contains(question.section))
        .toList();
    final answerById = {
      for (final answer in answers) answer.questionId: answer,
    };
    final scored = <double>[];
    for (final question in presented) {
      final answer = answerById[question.id];
      if (answer == null || answer.isSkipped) continue;
      scored.add(
        riskScore(answer: answer.answer, direction: question.direction),
      );
    }
    final completion = presented.isEmpty
        ? 0.0
        : scored.length / presented.length;
    final isScorable =
        scored.length >= minimumDomainAnswers &&
        completion >= minimumDomainCompletion;
    return _DomainScore(
      score: isScorable ? _average(scored) : null,
      isScorable: isScorable,
    );
  }

  static double _average(List<double> scores) =>
      scores.isEmpty ? 0 : scores.reduce((a, b) => a + b) / scores.length;

  static double _round(double value) => double.parse(value.toStringAsFixed(2));

  static const _pilotDisclaimer = AssessmentPolicy.disclosure;
}

class _DomainScore {
  const _DomainScore({required this.score, required this.isScorable});
  final double? score;
  final bool isScorable;
}

class _DomainConfig {
  const _DomainConfig({
    required this.label,
    required this.scoredSections,
    required this.allSections,
    required this.weight,
  });
  final String label;
  final Set<AssessmentSection> scoredSections;
  final Set<AssessmentSection> allSections;
  final double weight;
}

class _RoleConfig {
  const _RoleConfig(this.userLabel, this.domains);
  final String userLabel;
  final List<_DomainConfig> domains;

  static _RoleConfig forType(AssessmentUserType type) => switch (type) {
    AssessmentUserType.student => _RoleConfig('Student', [
      _DomainConfig(
        label: 'Academic Stress',
        scoredSections: {AssessmentSection.academicCore},
        allSections: {
          AssessmentSection.academicCore,
          AssessmentSection.academicDeeper,
        },
        weight: AssessmentPolicy.weight('student', 'Academic Stress'),
      ),
      _DomainConfig(
        label: 'Financial Well-Being',
        scoredSections: {AssessmentSection.financialConcern},
        allSections: {AssessmentSection.financialConcern},
        weight: AssessmentPolicy.weight('student', 'Financial Well-Being'),
      ),
      _DomainConfig(
        label: 'Social Adjustment',
        scoredSections: {AssessmentSection.socialAdjustment},
        allSections: {AssessmentSection.socialAdjustment},
        weight: AssessmentPolicy.weight('student', 'Social Adjustment'),
      ),
      _DomainConfig(
        label: 'Sleep and Rest',
        scoredSections: {AssessmentSection.sleepRest},
        allSections: {AssessmentSection.sleepRest},
        weight: AssessmentPolicy.weight('student', 'Sleep and Rest'),
      ),
      _DomainConfig(
        label: 'Emotional Well-Being',
        scoredSections: {AssessmentSection.emotionalWellBeing},
        allSections: {AssessmentSection.emotionalWellBeing},
        weight: AssessmentPolicy.weight('student', 'Emotional Well-Being'),
      ),
    ]),
    AssessmentUserType.faculty => _RoleConfig('Teaching Personnel', [
      _DomainConfig(
        label: 'Workplace Stress',
        scoredSections: {AssessmentSection.workplaceStressCore},
        allSections: {
          AssessmentSection.workplaceStressCore,
          AssessmentSection.workplaceStressDeeper,
        },
        weight: AssessmentPolicy.weight('faculty', 'Workplace Stress'),
      ),
      _DomainConfig(
        label: 'Professional Support',
        scoredSections: {AssessmentSection.professionalSupport},
        allSections: {AssessmentSection.professionalSupport},
        weight: AssessmentPolicy.weight('faculty', 'Professional Support'),
      ),
      _DomainConfig(
        label: 'Professional Well-Being',
        scoredSections: {AssessmentSection.professionalWellBeing},
        allSections: {AssessmentSection.professionalWellBeing},
        weight: AssessmentPolicy.weight('faculty', 'Professional Well-Being'),
      ),
      _DomainConfig(
        label: 'Sleep and Rest',
        scoredSections: {AssessmentSection.sleepRest},
        allSections: {AssessmentSection.sleepRest},
        weight: AssessmentPolicy.weight('faculty', 'Sleep and Rest'),
      ),
      _DomainConfig(
        label: 'Emotional Well-Being',
        scoredSections: {AssessmentSection.emotionalWellBeing},
        allSections: {AssessmentSection.emotionalWellBeing},
        weight: AssessmentPolicy.weight('faculty', 'Emotional Well-Being'),
      ),
    ]),
    AssessmentUserType.staff => _RoleConfig('Non-Teaching Personnel', [
      _DomainConfig(
        label: 'Workplace Responsibilities',
        scoredSections: {AssessmentSection.workplaceResponsibilityCore},
        allSections: {
          AssessmentSection.workplaceResponsibilityCore,
          AssessmentSection.workplaceResponsibilityDeeper,
        },
        weight: AssessmentPolicy.weight('staff', 'Workplace Responsibilities'),
      ),
      _DomainConfig(
        label: 'Workplace Support',
        scoredSections: {AssessmentSection.workplaceSupport},
        allSections: {AssessmentSection.workplaceSupport},
        weight: AssessmentPolicy.weight('staff', 'Workplace Support'),
      ),
      _DomainConfig(
        label: 'Workplace Well-Being',
        scoredSections: {AssessmentSection.workplaceWellBeing},
        allSections: {AssessmentSection.workplaceWellBeing},
        weight: AssessmentPolicy.weight('staff', 'Workplace Well-Being'),
      ),
      _DomainConfig(
        label: 'Sleep and Rest',
        scoredSections: {AssessmentSection.sleepRest},
        allSections: {AssessmentSection.sleepRest},
        weight: AssessmentPolicy.weight('staff', 'Sleep and Rest'),
      ),
      _DomainConfig(
        label: 'Emotional Well-Being',
        scoredSections: {AssessmentSection.emotionalWellBeing},
        allSections: {AssessmentSection.emotionalWellBeing},
        weight: AssessmentPolicy.weight('staff', 'Emotional Well-Being'),
      ),
    ]),
  };
}
