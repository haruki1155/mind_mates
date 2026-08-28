import '../models/assessment_interpretation_models.dart';
import '../models/student_assessment_models.dart';
import '../config/assessment_policy.dart';

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
    final confidence =
        completion >= AssessmentPolicy.highResponseConfidencePercent
        ? AssessmentResponseConfidence.high
        : completion >= AssessmentPolicy.usableResponseConfidencePercent
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
      if (risk >= AssessmentPolicy.elevatedIndicatorScore) {
        elevatedByDomain.putIfAbsent(domain, () => []).add(question.text);
        if (question.isFunctionalImpactItem) {
          functionalFlags.add(question.text);
        }
      }
      if (question.direction == AssessmentDirection.protective &&
          risk <= AssessmentPolicy.protectiveIndicatorMaximum) {
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
      final band = isScorable
          ? bandFor(score)
          : AssessmentConcernBand.insufficient;
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
    final priorityRationale = _priorityRationale(
      priority: priority,
      domains: domainResults,
      functionalImpactCount: functionalFlags.length,
    );
    final priorityReasonCodes = _priorityReasonCodes(
      priority: priority,
      domains: domainResults,
      functionalImpactCount: functionalFlags.length,
    );
    final rationale = _rationale(priority, domainResults, functionalFlags);
    final actions = _actions(priority, domainResults);
    final focus = domainResults
        .where(
          (domain) =>
              domain.isScorable &&
              domain.score > AssessmentPolicy.concernFocusScore,
        )
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
      priorityRationale: priorityRationale,
      priorityReasonCodes: priorityReasonCodes,
      userSummary: _userSummary(priority, focusText),
      counselorSummary:
          '$userType screening: ${priority.label}. $focusText '
          'Response confidence: ${quality.confidence.label.toLowerCase()} '
          '(${quality.completionPercent.toStringAsFixed(0)}% completed).',
      suggestedActions: actions,
    );
  }

  static AssessmentConcernBand bandFor(double score) {
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
    final above80 = domains
        .where(
          (domain) => domain.score > AssessmentPolicy.elevatedConcernMaximum,
        )
        .length;
    final above60 = domains
        .where(
          (domain) => domain.score > AssessmentPolicy.moderateConcernMaximum,
        )
        .length;
    final above40 = domains
        .where((domain) => domain.score > AssessmentPolicy.watchfulMaximum)
        .length;
    if (above80 >= AssessmentPolicy.promptHighDomainCount ||
        above60 >= AssessmentPolicy.promptElevatedDomainCount ||
        functionalImpactCount >= AssessmentPolicy.promptFunctionalImpactCount) {
      return AssessmentSupportPriority.promptFollowUp;
    }
    if (above60 >= AssessmentPolicy.followUpElevatedDomainCount ||
        above40 >= AssessmentPolicy.followUpModerateDomainCount ||
        functionalImpactCount >=
            AssessmentPolicy.followUpFunctionalImpactCount) {
      return AssessmentSupportPriority.followUpSuggested;
    }
    if (above40 >= AssessmentPolicy.monitorModerateDomainCount ||
        functionalImpactCount >=
            AssessmentPolicy.monitorFunctionalImpactCount) {
      return AssessmentSupportPriority.monitor;
    }
    return AssessmentSupportPriority.routine;
  }

  static String _priorityRationale({
    required AssessmentSupportPriority priority,
    required List<AssessmentDomainResult> domains,
    required int functionalImpactCount,
  }) {
    if (priority == AssessmentSupportPriority.insufficientResponses) {
      final impact = functionalImpactCount == 0
          ? ''
          : ' $functionalImpactCount explicit follow-up or impact indicator${functionalImpactCount == 1 ? '' : 's'} were also recorded separately from scoring.';
      return 'Priority is limited because one or more core domains do not meet the completion rule.$impact';
    }
    final reasons = <String>[];
    final elevated = domains
        .where(
          (domain) =>
              domain.isScorable &&
              domain.score > AssessmentPolicy.moderateConcernMaximum,
        )
        .length;
    final high = domains
        .where(
          (domain) =>
              domain.isScorable &&
              domain.score > AssessmentPolicy.elevatedConcernMaximum,
        )
        .length;
    if (high > 0) {
      reasons.add(
        '$high domain score${high == 1 ? '' : 's'} above the elevated boundary',
      );
    }
    if (elevated > 0) {
      reasons.add(
        '$elevated domain score${elevated == 1 ? '' : 's'} above the moderate boundary',
      );
    }
    if (functionalImpactCount > 0) {
      reasons.add(
        '$functionalImpactCount explicit follow-up or impact indicator${functionalImpactCount == 1 ? '' : 's'}',
      );
    }
    if (reasons.isEmpty) {
      return 'Priority is based on the scored core domains and did not identify an elevated rule trigger.';
    }
    return 'Priority is separate from the concern score and reflects ${reasons.join(', ')}.';
  }

  static List<String> _priorityReasonCodes({
    required AssessmentSupportPriority priority,
    required List<AssessmentDomainResult> domains,
    required int functionalImpactCount,
  }) {
    final codes = <String>[];
    if (priority == AssessmentSupportPriority.insufficientResponses) {
      codes.add('insufficient_core_coverage');
    }
    final high = domains
        .where(
          (domain) =>
              domain.isScorable &&
              domain.score > AssessmentPolicy.elevatedConcernMaximum,
        )
        .length;
    final elevated = domains
        .where(
          (domain) =>
              domain.isScorable &&
              domain.score > AssessmentPolicy.moderateConcernMaximum,
        )
        .length;
    final moderate = domains
        .where(
          (domain) =>
              domain.isScorable &&
              domain.score > AssessmentPolicy.watchfulMaximum,
        )
        .length;
    if (high > 0) codes.add('domain_above_80_count_$high');
    if (elevated > 0) codes.add('domain_above_60_count_$elevated');
    if (moderate > 0) codes.add('domain_above_40_count_$moderate');
    if (functionalImpactCount > 0) {
      codes.add('functional_impact_count_$functionalImpactCount');
    }
    if (codes.isEmpty) codes.add('no_elevated_priority_trigger');
    return codes;
  }

  static List<String> _rationale(
    AssessmentSupportPriority priority,
    List<AssessmentDomainResult> domains,
    List<String> functionalFlags,
  ) {
    final reasons = <String>[];
    for (final domain
        in domains
            .where(
              (domain) =>
                  domain.isScorable &&
                  domain.score > AssessmentPolicy.concernFocusScore,
            )
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
      reasons.insert(
        0,
        'Some categories do not have enough answered questions for a dependable overall interpretation',
      );
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
        'Your responses produce several elevated estimates under the internal framework. This does not confirm a condition; consider direct support from a trusted person or qualified professional.',
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
    if (top != null) {
      final topDomain = scorable.first;
      actions.add(topDomain.suggestedAction);
    }
    if (domains.any((domain) => domain.elevatedIndicators.isNotEmpty)) {
      actions.add(
        'Review the day-to-day impact indicators separately from the domain score and choose one practical support step.',
      );
    }
    if (priority == AssessmentSupportPriority.followUpSuggested ||
        priority == AssessmentSupportPriority.promptFollowUp) {
      actions.add(
        'Consider using a locally verified counseling or qualified professional support option.',
      );
    }
    actions.add('Continue mood check-ins to observe changes over time.');
    return actions;
  }

  static String _domainInterpretation(
    String domain,
    AssessmentConcernBand band,
  ) {
    return switch (band) {
      AssessmentConcernBand.insufficient =>
        '$domain needs more answered questions before a dependable result can be shown.',
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
      AssessmentConcernBand.insufficient =>
        'Answer more $domain questions when comfortable, or discuss this area directly with a counselor.',
      AssessmentConcernBand.low =>
        'Continue the habits and support that are working in this area.',
      AssessmentConcernBand.watchful => 'Monitor this area and $support.',
      AssessmentConcernBand.moderate => 'Consider taking time to $support.',
      AssessmentConcernBand.elevated || AssessmentConcernBand.high =>
        'Consider discussing this area with university wellness support and $support.',
    };
  }

  static double _riskScore(LikertAnswer answer, AssessmentDirection direction) {
    return direction == AssessmentDirection.protective
        ? ((5 - answer.value) / 4) * 100
        : ((answer.value - 1) / 4) * 100;
  }

  static double _round(double value) => double.parse(value.toStringAsFixed(2));
}
