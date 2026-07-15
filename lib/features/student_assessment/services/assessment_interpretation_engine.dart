import '../models/assessment_interpretation_models.dart';
import '../models/student_assessment_models.dart';

class AssessmentInterpretationEngine {
  const AssessmentInterpretationEngine._();

  static AssessmentInterpretation build({
    required List<StudentAssessmentQuestion> questions,
    required List<StudentAssessmentAnswer> answers,
    required Map<String, double> domainScores,
    required Map<String, Set<AssessmentSection>> domainSections,
    required String userType,
  }) {
    final answerById = {
      for (final answer in answers) answer.questionId: answer,
    };
    final answered = answers.where((answer) => !answer.isSkipped).length;
    final skipped = answers.where((answer) => answer.isSkipped).length;
    final presented = questions.length;
    final completion = presented == 0 ? 0.0 : (answered / presented) * 100;
    final confidence = completion >= 90
        ? AssessmentResponseConfidence.high
        : completion >= 70
        ? AssessmentResponseConfidence.usableWithCaution
        : AssessmentResponseConfidence.limited;
    final quality = AssessmentResponseQuality(
      presented: presented,
      answered: answered,
      skipped: skipped,
      completionPercent: _round(completion),
      confidence: confidence,
    );

    final protectiveFactors = <String>[];
    final functionalFlags = <String>[];
    final elevatedByDomain = <String, List<String>>{};
    final protectiveByDomain = <String, List<String>>{};

    for (final question in questions) {
      final answer = answerById[question.id];
      if (answer == null || answer.isSkipped) continue;
      final risk = _riskScore(answer.answer, question.direction);
      final domain = question.section.label;
      if (risk >= 75) {
        elevatedByDomain.putIfAbsent(domain, () => []).add(question.text);
        if (_isFunctionalImpact(question.text)) {
          functionalFlags.add(question.text);
        }
      }
      if (question.direction == AssessmentDirection.protective && risk <= 25) {
        protectiveFactors.add(question.text);
        protectiveByDomain.putIfAbsent(domain, () => []).add(question.text);
      }
    }

    final domainResults = <AssessmentDomainResult>[];
    for (final entry in domainSections.entries) {
      final domainQuestions = questions
          .where((question) => entry.value.contains(question.section))
          .toList();
      final scoredQuestions = domainQuestions
          .where((question) => !question.isConditional)
          .toList();
      final domainAnswers = scoredQuestions
          .map((question) => answerById[question.id])
          .whereType<StudentAssessmentAnswer>()
          .toList();
      final domainAnswered = domainAnswers
          .where((answer) => !answer.isSkipped)
          .length;
      final domainSkipped = domainAnswers
          .where((answer) => answer.isSkipped)
          .length;
      final domainCompletion = scoredQuestions.isEmpty
          ? 0.0
          : (domainAnswered / scoredQuestions.length) * 100;
      final isScorable = domainScores.containsKey(entry.key);
      final score = domainScores[entry.key] ?? 0;
      final band = bandFor(score);
      domainResults.add(
        AssessmentDomainResult(
          domain: entry.key,
          score: _round(score),
          band: band,
          answeredCount: domainAnswered,
          skippedCount: domainSkipped,
          presentedCount: scoredQuestions.length,
          completionPercent: _round(domainCompletion),
          isScorable: isScorable,
          elevatedIndicators: elevatedByDomain[entry.key] ?? const [],
          protectiveIndicators: protectiveByDomain[entry.key] ?? const [],
          interpretation: isScorable
              ? _domainInterpretation(entry.key, band)
              : '${entry.key} needs more answered questions before a dependable category result can be shown.',
          suggestedAction: isScorable
              ? _domainAction(entry.key, band)
              : 'Answer more ${entry.key.toLowerCase()} questions when you feel comfortable, or discuss this area directly with a counselor.',
        ),
      );
    }
    domainResults.sort((a, b) {
      if (a.isScorable != b.isScorable) return a.isScorable ? -1 : 1;
      return b.score.compareTo(a.score);
    });

    final priority = _priority(
      quality: quality,
      domains: domainResults,
      functionalImpactCount: functionalFlags.length,
    );
    final rationale = _rationale(priority, domainResults, functionalFlags);
    final actions = _actions(priority, domainResults);
    final focus = domainResults
        .where((domain) => domain.isScorable && domain.score > 40)
        .take(3);
    final focusText = focus.isEmpty
        ? 'No wellness domain showed a moderate or higher concern pattern.'
        : 'The main areas to review are ${focus.map((item) => item.domain).join(', ')}.';

    return AssessmentInterpretation(
      supportPriority: priority,
      responseQuality: quality,
      domainResults: domainResults,
      protectiveFactors: protectiveFactors.take(5).toList(),
      functionalImpactFlags: functionalFlags.take(5).toList(),
      rationale: rationale,
      userSummary: _userSummary(priority, focusText),
      counselorSummary:
          '$userType screening: ${priority.label}. $focusText '
          'Response confidence: ${quality.confidence.label.toLowerCase()} '
          '(${quality.completionPercent.toStringAsFixed(0)}% completed).',
      suggestedActions: actions,
    );
  }

  static AssessmentConcernBand bandFor(double score) {
    if (score <= 20) return AssessmentConcernBand.low;
    if (score <= 40) return AssessmentConcernBand.watchful;
    if (score <= 60) return AssessmentConcernBand.moderate;
    if (score <= 80) return AssessmentConcernBand.elevated;
    return AssessmentConcernBand.high;
  }

  static AssessmentSupportPriority _priority({
    required AssessmentResponseQuality quality,
    required List<AssessmentDomainResult> domains,
    required int functionalImpactCount,
  }) {
    if (quality.confidence == AssessmentResponseConfidence.limited) {
      return AssessmentSupportPriority.insufficientResponses;
    }
    if (domains.any((domain) => !domain.isScorable)) {
      return AssessmentSupportPriority.insufficientResponses;
    }
    final above80 = domains.where((domain) => domain.score > 80).length;
    final above60 = domains.where((domain) => domain.score > 60).length;
    final above40 = domains.where((domain) => domain.score > 40).length;
    if (above80 >= 1 || above60 >= 2 || functionalImpactCount >= 3) {
      return AssessmentSupportPriority.promptFollowUp;
    }
    if (above60 >= 1 || above40 >= 2 || functionalImpactCount >= 2) {
      return AssessmentSupportPriority.followUpSuggested;
    }
    if (above40 >= 1 || functionalImpactCount >= 1) {
      return AssessmentSupportPriority.monitor;
    }
    return AssessmentSupportPriority.routine;
  }

  static List<String> _rationale(
    AssessmentSupportPriority priority,
    List<AssessmentDomainResult> domains,
    List<String> functionalFlags,
  ) {
    final reasons = <String>[];
    for (final domain
        in domains
            .where((domain) => domain.isScorable && domain.score > 40)
            .take(3)) {
      reasons.add(
        '${domain.domain}: ${domain.score.toStringAsFixed(0)}/100 (${domain.band.label.toLowerCase()})',
      );
    }
    if (functionalFlags.isNotEmpty) {
      reasons.add(
        '${functionalFlags.length} response${functionalFlags.length == 1 ? '' : 's'} indicated possible day-to-day impact',
      );
    }
    if (reasons.isEmpty) {
      reasons.add(
        'Responses did not show a moderate or higher concern pattern',
      );
    }
    if (priority == AssessmentSupportPriority.insufficientResponses) {
      reasons.insert(0, 'Too many presented questions were skipped');
    }
    return reasons;
  }

  static String _userSummary(
    AssessmentSupportPriority priority,
    String focusText,
  ) {
    final opening = switch (priority) {
      AssessmentSupportPriority.routine =>
        'Your responses suggest generally manageable current well-being.',
      AssessmentSupportPriority.monitor =>
        'Your responses suggest an area that may benefit from monitoring and supportive habits.',
      AssessmentSupportPriority.followUpSuggested =>
        'Your responses suggest notable strain that may benefit from a conversation with a counselor or trusted support person.',
      AssessmentSupportPriority.promptFollowUp =>
        'Your responses suggest several elevated concerns. Timely support from PACC or another qualified professional is recommended.',
      AssessmentSupportPriority.insufficientResponses =>
        'There were not enough answered questions for a dependable interpretation.',
    };
    return '$opening $focusText This screening result is not a diagnosis.';
  }

  static List<String> _actions(
    AssessmentSupportPriority priority,
    List<AssessmentDomainResult> domains,
  ) {
    final actions = <String>[];
    if (priority == AssessmentSupportPriority.insufficientResponses) {
      return const [
        'Review skipped items and complete the assessment when comfortable.',
        'Speak directly with a counselor if you would prefer a conversation.',
      ];
    }
    final scorable = domains.where((domain) => domain.isScorable);
    final top = scorable.isEmpty ? null : scorable.first.domain;
    if (top != null) actions.add('Review practical support options for $top.');
    if (priority == AssessmentSupportPriority.followUpSuggested ||
        priority == AssessmentSupportPriority.promptFollowUp) {
      actions.add('Consider scheduling a confidential PACC consultation.');
    }
    actions.add('Continue mood check-ins to observe changes over time.');
    return actions;
  }

  static String _domainInterpretation(
    String domain,
    AssessmentConcernBand band,
  ) {
    return switch (band) {
      AssessmentConcernBand.low =>
        '$domain responses currently show a relatively low concern pattern.',
      AssessmentConcernBand.watchful =>
        '$domain may benefit from routine monitoring and supportive habits.',
      AssessmentConcernBand.moderate =>
        '$domain shows a noticeable concern pattern worth reviewing.',
      AssessmentConcernBand.elevated =>
        '$domain shows elevated strain that may benefit from follow-up.',
      AssessmentConcernBand.high =>
        '$domain shows a high concern pattern and deserves timely attention.',
    };
  }

  static String _domainAction(String domain, AssessmentConcernBand band) {
    final support = switch (domain) {
      'Academic Stress' =>
        'review workload, deadlines, and academic support options',
      'Financial Well-Being' =>
        'review available financial-aid or student-support resources',
      'Social Adjustment' =>
        'identify one trusted person or university group you can connect with',
      'Sleep and Rest' =>
        'choose one realistic sleep or rest routine to try this week',
      'Emotional Well-Being' =>
        'continue check-ins and consider a supportive conversation',
      'Workplace Stress' || 'Workplace Responsibilities' =>
        'review workload priorities and available workplace support',
      'Professional Support' || 'Workplace Support' =>
        'identify a trusted colleague, supervisor, or university support contact',
      'Professional Well-Being' || 'Workplace Well-Being' =>
        'choose one recovery or support step that feels manageable',
      _ => 'review a practical support option for this area',
    };
    return switch (band) {
      AssessmentConcernBand.low =>
        'Continue the habits and support that are working in this area.',
      AssessmentConcernBand.watchful => 'Monitor this area and $support.',
      AssessmentConcernBand.moderate => 'Consider taking time to $support.',
      AssessmentConcernBand.elevated || AssessmentConcernBand.high =>
        'Consider discussing this area with university wellness support and $support.',
    };
  }

  static bool _isFunctionalImpact(String text) {
    final normalized = text.toLowerCase();
    return const [
      'concentrat',
      'sleep',
      'motivation',
      'social life',
      'skip meals',
      'family time',
      'personal life',
      'relationships',
      'health',
      'daily life',
    ].any(normalized.contains);
  }

  static double _riskScore(LikertAnswer answer, AssessmentDirection direction) {
    return direction == AssessmentDirection.protective
        ? ((5 - answer.value) / 4) * 100
        : ((answer.value - 1) / 4) * 100;
  }

  static double _round(double value) => double.parse(value.toStringAsFixed(2));
}
