import '../models/student_assessment_models.dart';

enum AssessmentUserType { student, faculty, staff }

class StudentAssessmentCalculator {
  const StudentAssessmentCalculator._();

  static double riskScore({
    required LikertAnswer answer,
    required AssessmentDirection direction,
  }) {
    if (direction == AssessmentDirection.protective) {
      return ((5 - answer.value) / 4) * 100;
    }

    return ((answer.value - 1) / 4) * 100;
  }

  static bool shouldShowDeeperAcademicQuestions({
    required List<StudentAssessmentQuestion> questions,
    required List<StudentAssessmentAnswer> answers,
  }) {
    return shouldShowDeeperQuestions(
      questions: questions,
      answers: answers,
      coreSection: AssessmentSection.academicCore,
    );
  }

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
    var alwaysCount = 0;
    var oftenOrAlwaysCount = 0;
    final coreScores = <double>[];

    for (final answer in answers) {
      final question = coreQuestions
          .where((question) => question.id == answer.questionId)
          .firstOrNull;
      if (question == null) continue;

      if (answer.answer == LikertAnswer.always) alwaysCount += 1;
      if (answer.answer == LikertAnswer.often ||
          answer.answer == LikertAnswer.always) {
        oftenOrAlwaysCount += 1;
      }
      coreScores.add(
        riskScore(answer: answer.answer, direction: question.direction),
      );
    }

    return alwaysCount >= 1 ||
        oftenOrAlwaysCount >= 2 ||
        _average(coreScores) >= 50;
  }

  static StudentAssessmentResult calculate({
    required List<StudentAssessmentQuestion> questions,
    required List<StudentAssessmentAnswer> answers,
    AssessmentUserType userType = AssessmentUserType.student,
  }) {
    switch (userType) {
      case AssessmentUserType.student:
        return _calculateStudent(questions: questions, answers: answers);
      case AssessmentUserType.faculty:
        return _calculateFaculty(questions: questions, answers: answers);
      case AssessmentUserType.staff:
        return _calculateStaff(questions: questions, answers: answers);
    }
  }

  static StudentAssessmentResult _calculateStudent({
    required List<StudentAssessmentQuestion> questions,
    required List<StudentAssessmentAnswer> answers,
  }) {
    final academicCoreScore = _sectionAverage(
      questions: questions,
      answers: answers,
      section: AssessmentSection.academicCore,
    );
    final hasDeeperAcademicAnswers = answers.any((answer) {
      final question = questions
          .where((question) => question.id == answer.questionId)
          .firstOrNull;
      return question?.section == AssessmentSection.academicDeeper;
    });
    final academicDeeperScore = hasDeeperAcademicAnswers
        ? _sectionAverage(
            questions: questions,
            answers: answers,
            section: AssessmentSection.academicDeeper,
          )
        : 0.0;
    final academicStressScore = hasDeeperAcademicAnswers
        ? (academicCoreScore * 0.60) + (academicDeeperScore * 0.40)
        : academicCoreScore;
    final financialConcernScore = _sectionAverage(
      questions: questions,
      answers: answers,
      section: AssessmentSection.financialConcern,
    );
    final socialSupportRiskScore = _sectionAverage(
      questions: questions,
      answers: answers,
      section: AssessmentSection.socialAdjustment,
    );
    final sleepRiskScore = _sectionAverage(
      questions: questions,
      answers: answers,
      section: AssessmentSection.sleepRest,
    );
    final emotionalWellBeingRiskScore = _sectionAverage(
      questions: questions,
      answers: answers,
      section: AssessmentSection.emotionalWellBeing,
    );

    final overallScore =
        (academicStressScore * 0.25) +
        (financialConcernScore * 0.15) +
        (socialSupportRiskScore * 0.10) +
        (sleepRiskScore * 0.20) +
        (emotionalWellBeingRiskScore * 0.30);
    final status = _getStudentStatus(overallScore);
    final subscaleScores = {
      'Academic Stress': academicStressScore,
      'Financial Well-Being': financialConcernScore,
      'Social Adjustment': socialSupportRiskScore,
      'Sleep and Rest': sleepRiskScore,
      'Emotional Well-Being': emotionalWellBeingRiskScore,
    };

    return StudentAssessmentResult(
      userType: 'Student',
      overallScore: _round(overallScore),
      status: status,
      subscaleScores: subscaleScores.map(
        (key, value) => MapEntry(key, _round(value)),
      ),
      mainConcernAreas: getMainConcernAreas(subscaleScores),
      message: getMessage(status),
      disclaimer:
          'This assessment is not a diagnosis. It is a university-based wellness screening tool designed to help students reflect on their current well-being. If you are experiencing severe distress, feel unsafe, or need immediate help, please contact your university guidance office, a trusted person, or a qualified mental health professional.',
      totalResponses: answers.length,
    );
  }

  static StudentAssessmentResult _calculateFaculty({
    required List<StudentAssessmentQuestion> questions,
    required List<StudentAssessmentAnswer> answers,
  }) {
    final workplaceCoreScore = _sectionAverage(
      questions: questions,
      answers: answers,
      section: AssessmentSection.workplaceStressCore,
    );
    final hasDeeperAnswers = _hasSectionAnswer(
      questions: questions,
      answers: answers,
      section: AssessmentSection.workplaceStressDeeper,
    );
    final workplaceDeeperScore = hasDeeperAnswers
        ? _sectionAverage(
            questions: questions,
            answers: answers,
            section: AssessmentSection.workplaceStressDeeper,
          )
        : 0.0;
    final workplaceStressScore = hasDeeperAnswers
        ? (workplaceCoreScore * 0.60) + (workplaceDeeperScore * 0.40)
        : workplaceCoreScore;
    final professionalSupportRiskScore = _sectionAverage(
      questions: questions,
      answers: answers,
      section: AssessmentSection.professionalSupport,
    );
    final professionalWellBeingRiskScore = _sectionAverage(
      questions: questions,
      answers: answers,
      section: AssessmentSection.professionalWellBeing,
    );
    final sleepRiskScore = _sectionAverage(
      questions: questions,
      answers: answers,
      section: AssessmentSection.sleepRest,
    );
    final generalEmotionalRiskScore = _sectionAverage(
      questions: questions,
      answers: answers,
      section: AssessmentSection.emotionalWellBeing,
    );
    final overallScore =
        (workplaceStressScore * 0.30) +
        (professionalSupportRiskScore * 0.15) +
        (professionalWellBeingRiskScore * 0.15) +
        (sleepRiskScore * 0.15) +
        (generalEmotionalRiskScore * 0.25);
    final status = getStatus(overallScore);
    final subscaleScores = {
      'Workplace Stress': workplaceStressScore,
      'Professional Support': professionalSupportRiskScore,
      'Professional Well-Being': professionalWellBeingRiskScore,
      'Sleep and Rest': sleepRiskScore,
      'Emotional Well-Being': generalEmotionalRiskScore,
    };

    return StudentAssessmentResult(
      userType: 'Teaching Personnel',
      overallScore: _round(overallScore),
      status: status,
      subscaleScores: subscaleScores.map(
        (key, value) => MapEntry(key, _round(value)),
      ),
      mainConcernAreas: getMainConcernAreas(subscaleScores),
      message: getMessage(status),
      disclaimer: _workplaceDisclaimer,
      totalResponses: answers.length,
    );
  }

  static StudentAssessmentResult _calculateStaff({
    required List<StudentAssessmentQuestion> questions,
    required List<StudentAssessmentAnswer> answers,
  }) {
    final workplaceResponsibilityCoreScore = _sectionAverage(
      questions: questions,
      answers: answers,
      section: AssessmentSection.workplaceResponsibilityCore,
    );
    final hasDeeperAnswers = _hasSectionAnswer(
      questions: questions,
      answers: answers,
      section: AssessmentSection.workplaceResponsibilityDeeper,
    );
    final workplaceResponsibilityDeeperScore = hasDeeperAnswers
        ? _sectionAverage(
            questions: questions,
            answers: answers,
            section: AssessmentSection.workplaceResponsibilityDeeper,
          )
        : 0.0;
    final workplaceResponsibilityScore = hasDeeperAnswers
        ? (workplaceResponsibilityCoreScore * 0.60) +
              (workplaceResponsibilityDeeperScore * 0.40)
        : workplaceResponsibilityCoreScore;
    final workplaceSupportRiskScore = _sectionAverage(
      questions: questions,
      answers: answers,
      section: AssessmentSection.workplaceSupport,
    );
    final workplaceWellBeingRiskScore = _sectionAverage(
      questions: questions,
      answers: answers,
      section: AssessmentSection.workplaceWellBeing,
    );
    final sleepRiskScore = _sectionAverage(
      questions: questions,
      answers: answers,
      section: AssessmentSection.sleepRest,
    );
    final generalEmotionalRiskScore = _sectionAverage(
      questions: questions,
      answers: answers,
      section: AssessmentSection.emotionalWellBeing,
    );
    final overallScore =
        (workplaceResponsibilityScore * 0.30) +
        (workplaceSupportRiskScore * 0.15) +
        (workplaceWellBeingRiskScore * 0.15) +
        (sleepRiskScore * 0.15) +
        (generalEmotionalRiskScore * 0.25);
    final status = getStatus(overallScore);
    final subscaleScores = {
      'Workplace Responsibilities': workplaceResponsibilityScore,
      'Workplace Support': workplaceSupportRiskScore,
      'Workplace Well-Being': workplaceWellBeingRiskScore,
      'Sleep and Rest': sleepRiskScore,
      'Emotional Well-Being': generalEmotionalRiskScore,
    };

    return StudentAssessmentResult(
      userType: 'Non-Teaching Personnel',
      overallScore: _round(overallScore),
      status: status,
      subscaleScores: subscaleScores.map(
        (key, value) => MapEntry(key, _round(value)),
      ),
      mainConcernAreas: getMainConcernAreas(subscaleScores),
      message: getMessage(status),
      disclaimer: _workplaceDisclaimer,
      totalResponses: answers.length,
    );
  }

  static String getStatus(double score) {
    if (score <= 20) return 'Very Good Well-Being';
    if (score <= 40) return 'Generally Stable';
    if (score <= 60) return 'Moderate Concern';
    if (score <= 80) return 'High Concern';
    return 'Very High Concern';
  }

  static String _getStudentStatus(double score) {
    if (score <= 20) return 'Very Good Well-Being';
    if (score <= 40) return 'Generally Stable';
    if (score <= 60) return 'Moderate Well-Being';
    if (score <= 80) return 'High Concern';
    return 'Very High Concern';
  }

  static String getMessage(String status) {
    switch (status) {
      case 'Very Good Well-Being':
        return 'Your responses suggest that you are currently managing your academic, emotional, and personal well-being well. Continue maintaining healthy routines, social support, and balanced study habits.';
      case 'Generally Stable':
        return 'Your responses suggest that you may be experiencing some stress, but you appear to be generally coping. Continue monitoring your well-being and practice healthy academic, sleep, and emotional habits.';
      case 'Moderate Concern':
      case 'Moderate Well-Being':
        return 'Your responses suggest a noticeable level of workplace stress or emotional strain. This does not mean you have a mental health condition, but it may be helpful to monitor your well-being, improve rest habits, and consider speaking with a trusted supervisor, HR personnel, or university wellness support.';
      case 'High Concern':
        return 'Your responses suggest a high level of stress or reduced well-being. You may benefit from speaking with a university guidance counselor or a qualified mental health professional for support.';
      case 'Very High Concern':
        return 'Your responses suggest a very high level of concern. This result is not a diagnosis, but it is strongly recommended that you reach out to your university guidance office or a qualified mental health professional as soon as possible.';
      default:
        return 'Your result has been calculated.';
    }
  }

  static List<String> getMainConcernAreas(Map<String, double> scores) {
    return scores.entries
        .where((entry) => entry.value >= 60)
        .map((entry) => entry.key)
        .toList();
  }

  static double _average(List<double> scores) {
    if (scores.isEmpty) return 0;
    return scores.reduce((a, b) => a + b) / scores.length;
  }

  static double _sectionAverage({
    required List<StudentAssessmentQuestion> questions,
    required List<StudentAssessmentAnswer> answers,
    required AssessmentSection section,
  }) {
    final scores = <double>[];

    for (final question in questions.where(
      (question) => question.section == section,
    )) {
      final answer = answers
          .where((answer) => answer.questionId == question.id)
          .firstOrNull;
      if (answer == null) continue;

      scores.add(
        riskScore(answer: answer.answer, direction: question.direction),
      );
    }

    return _average(scores);
  }

  static bool _hasSectionAnswer({
    required List<StudentAssessmentQuestion> questions,
    required List<StudentAssessmentAnswer> answers,
    required AssessmentSection section,
  }) {
    return answers.any((answer) {
      final question = questions
          .where((question) => question.id == answer.questionId)
          .firstOrNull;
      return question?.section == section;
    });
  }

  static double _round(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  static const _workplaceDisclaimer =
      'This assessment is not a diagnosis. It is a university-based wellness screening tool designed to help users reflect on their current well-being. If you are experiencing severe distress, feel unsafe, or need immediate help, please contact your university support office, a trusted person, or a qualified mental health professional.';
}
