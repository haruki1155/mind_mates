import '../models/quick_assessment_models.dart';

class QuickAssessmentScoring {
  const QuickAssessmentScoring._();

  static const Map<String, String> concernAreasByQuestionId = {
    'calm_relaxed': 'Emotional calm',
    'overwhelmed': 'Stress load',
    'connected': 'Social connection',
    'little_interest': 'Motivation and interest',
    'stress_affecting_life': 'Daily coping',
  };

  static double concernScore({
    required QuickQuestionDirection direction,
    required int value,
  }) {
    if (direction == QuickQuestionDirection.protective) {
      return ((5 - value) / 4) * 100;
    }

    return ((value - 1) / 4) * 100;
  }

  static String progressLabelForStep(int step) {
    return '${step.clamp(1, 6)}/6';
  }

  static double averageConcernScore(List<QuickAssessmentResponse> responses) {
    if (responses.isEmpty) return 0;

    final total = responses.fold<double>(
      0,
      (sum, response) => sum + response.concernScore,
    );

    return double.parse((total / responses.length).toStringAsFixed(2));
  }

  static Map<String, double> areaScores(
    List<QuickAssessmentResponse> responses,
  ) {
    final scores = <String, double>{};

    for (final response in responses) {
      final area =
          concernAreasByQuestionId[response.questionId] ?? 'General well-being';
      scores[area] = response.concernScore;
    }

    return scores;
  }

  static QuickAssessmentLevel overallLevel(double concernScore) {
    if (concernScore >= 75) return QuickAssessmentLevel.veryHigh;
    if (concernScore >= 55) return QuickAssessmentLevel.high;
    if (concernScore >= 30) return QuickAssessmentLevel.moderate;
    return QuickAssessmentLevel.low;
  }

  static List<String> topConcernAreas(List<QuickAssessmentResponse> responses) {
    final sorted = areaScores(responses).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .where((entry) => entry.value >= 30)
        .take(3)
        .map((entry) => entry.key)
        .toList();
  }

  static String summaryForLevel(QuickAssessmentLevel level) {
    switch (level) {
      case QuickAssessmentLevel.low:
        return 'Responses suggest low current concern and generally stable day-to-day well-being.';
      case QuickAssessmentLevel.moderate:
        return 'Responses suggest some areas of strain that may benefit from regular check-ins and supportive habits.';
      case QuickAssessmentLevel.high:
        return 'Responses suggest elevated stress or reduced well-being that may benefit from a fuller assessment and support.';
      case QuickAssessmentLevel.veryHigh:
        return 'Responses suggest a very high level of concern and a strong need for timely support from a trusted person or counselor.';
    }
  }

  static String recommendedNextStepForLevel(QuickAssessmentLevel level) {
    switch (level) {
      case QuickAssessmentLevel.low:
        return 'Continue regular MindMate check-ins and wellness habits.';
      case QuickAssessmentLevel.moderate:
        return 'Complete the full role-based assessment for more personalized insight.';
      case QuickAssessmentLevel.high:
        return 'Complete the full assessment and consider contacting PACC counseling support.';
      case QuickAssessmentLevel.veryHigh:
        return 'Reach out to PACC counseling support or another trusted support person as soon as possible.';
    }
  }
}
