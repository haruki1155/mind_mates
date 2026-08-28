import '../models/quick_assessment_models.dart';
import '../../student_assessment/models/assessment_interpretation_models.dart';
import '../../student_assessment/config/assessment_policy.dart';

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
    int minValue = 1,
    int maxValue = 5,
  }) {
    final range = maxValue - minValue;
    if (range <= 0) return 0;
    if (direction == QuickQuestionDirection.protective) {
      return ((maxValue - value) / range) * 100;
    }

    return ((value - minValue) / range) * 100;
  }

  static String progressLabelForStep(int step, {int total = 5}) {
    return '${step.clamp(1, total)}/$total';
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
    if (concernScore >= AssessmentPolicy.quickVeryHighMinimum) {
      return QuickAssessmentLevel.veryHigh;
    }
    if (concernScore >= AssessmentPolicy.quickHighMinimum) {
      return QuickAssessmentLevel.high;
    }
    if (concernScore >= AssessmentPolicy.quickModerateMinimum) {
      return QuickAssessmentLevel.moderate;
    }
    return QuickAssessmentLevel.low;
  }

  static QuickAssessmentSignal signalForLevel(QuickAssessmentLevel level) {
    switch (level) {
      case QuickAssessmentLevel.low:
        return QuickAssessmentSignal.stable;
      case QuickAssessmentLevel.moderate:
        return QuickAssessmentSignal.watchful;
      case QuickAssessmentLevel.high:
        return QuickAssessmentSignal.elevated;
      case QuickAssessmentLevel.veryHigh:
        return QuickAssessmentSignal.highSupport;
    }
  }

  static List<String> topConcernAreas(List<QuickAssessmentResponse> responses) {
    final sorted = areaScores(responses).entries.toList()
      ..sort((a, b) {
        final scoreOrder = b.value.compareTo(a.value);
        return scoreOrder == 0 ? a.key.compareTo(b.key) : scoreOrder;
      });

    return sorted
        .where((entry) => entry.value >= AssessmentPolicy.quickModerateMinimum)
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
        return 'Responses produce a very high estimate under the experimental internal framework. This does not confirm a mental-health condition; consider direct support if you are concerned.';
    }
  }

  static String recommendedNextStepForLevel(QuickAssessmentLevel level) {
    switch (level) {
      case QuickAssessmentLevel.low:
        return 'Continue regular MindMate check-ins and wellness habits.';
      case QuickAssessmentLevel.moderate:
        return 'Complete the full role-based assessment for more personalized insight.';
      case QuickAssessmentLevel.high:
        return 'Complete the full assessment and consider using a locally verified counseling or professional support option.';
      case QuickAssessmentLevel.veryHigh:
        return 'Consider reaching out directly to a trusted person or locally verified qualified support service.';
    }
  }

  static AssessmentInterpretation interpretationFor(
    List<QuickAssessmentResponse> responses,
  ) {
    final domains = areaScores(responses).entries.map((entry) {
      final band = _band(entry.value);
      return AssessmentDomainResult(
        domain: entry.key,
        score: entry.value,
        band: band,
        answeredCount: 1,
        skippedCount: 0,
        presentedCount: 1,
        completionPercent: 100,
        isScorable: true,
        interpretation:
            '${entry.key} is currently in the ${band.label.toLowerCase()} screening range.',
        suggestedAction: recommendedNextStepForLevel(
          overallLevel(averageConcernScore(responses)),
        ),
      );
    }).toList()..sort((a, b) => b.score.compareTo(a.score));
    final level = overallLevel(averageConcernScore(responses));
    final priority = switch (level) {
      QuickAssessmentLevel.low => AssessmentSupportPriority.routine,
      QuickAssessmentLevel.moderate => AssessmentSupportPriority.monitor,
      QuickAssessmentLevel.high => AssessmentSupportPriority.followUpSuggested,
      QuickAssessmentLevel.veryHigh => AssessmentSupportPriority.promptFollowUp,
    };
    final top = domains
        .where(
          (domain) => domain.score >= AssessmentPolicy.quickModerateMinimum,
        )
        .take(3)
        .toList();
    final focus = top.isEmpty
        ? 'No quick-screen area showed a moderate concern signal.'
        : 'Higher signals appeared in ${top.map((domain) => domain.domain).join(', ')}.';
    return AssessmentInterpretation(
      supportPriority: priority,
      responseQuality: AssessmentResponseQuality(
        presented: responses.length,
        answered: responses.length,
        skipped: 0,
        completionPercent: 100,
        confidence: AssessmentResponseConfidence.high,
      ),
      domainResults: domains,
      rationale: [focus],
      priorityRationale:
          'Priority is based on the quick-screen classification and ranked quick-screen areas; it is separate from the full-assessment concern score.',
      priorityReasonCodes: [
        'quick_classification_${level.name}',
        if (top.isNotEmpty) 'ranked_quick_concern_areas',
      ],
      userSummary: '${summaryForLevel(level)} $focus This is not a diagnosis.',
      counselorSummary:
          'Quick wellness screen: ${priority.label}. $focus Complete the full role-based assessment for domain-level interpretation.',
      suggestedActions: [recommendedNextStepForLevel(level)],
      algorithmVersion: AssessmentPolicy.quickScoringPolicyVersion,
      questionSetVersion: AssessmentPolicy.quickQuestionSetVersion,
    );
  }

  static AssessmentConcernBand _band(double score) {
    if (score <= AssessmentPolicy.lowConcernMaximum) {
      return AssessmentConcernBand.low;
    }
    if (score <= AssessmentPolicy.watchfulMaximum) {
      return AssessmentConcernBand.watchful;
    }
    if (score <= AssessmentPolicy.moderateConcernMaximum) {
      return AssessmentConcernBand.moderate;
    }
    if (score <= AssessmentPolicy.elevatedConcernMaximum) {
      return AssessmentConcernBand.elevated;
    }
    return AssessmentConcernBand.high;
  }
}
