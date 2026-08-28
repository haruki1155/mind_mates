/// Canonical client copy of the server-authoritative experimental policy.
///
/// No documented validation source was found for these values. They are
/// retained as internal product rules for backward compatibility and require
/// review by a qualified mental-health professional before any claim of
/// clinical or scientific validation.
class AssessmentPolicy {
  const AssessmentPolicy._();

  static const fullScoringPolicyVersion =
      'internal_wellness_policy_v2_agreement';
  static const quickScoringPolicyVersion = 'internal_wellness_policy_v1';
  static const fullQuestionSetVersion = 'experimental_role_based_v2_agreement';
  static const fullResponseScaleVersion = 'agreement5_v2';
  static const quickQuestionSetVersion = 'experimental_quick_v1';
  static const validationStatus = 'requires_professional_review';
  static const source = 'internally_defined_product_rule';

  static const minimumDomainAnswers = 3;
  static const minimumDomainCompletion = .70;
  static const highResponseConfidencePercent = 90.0;
  static const usableResponseConfidencePercent = 70.0;
  static const elevatedIndicatorScore = 75.0;
  static const protectiveIndicatorMaximum = 25.0;
  static const concernFocusScore = 40.0;
  static const mainConcernScore = 60.0;

  static const lowConcernMaximum = 20.0;
  static const watchfulMaximum = 40.0;
  static const moderateConcernMaximum = 60.0;
  static const elevatedConcernMaximum = 80.0;

  static const quickModerateMinimum = 30.0;
  static const quickHighMinimum = 55.0;
  static const quickVeryHighMinimum = 75.0;

  static const deeperStronglyAgreeCount = 1;
  static const deeperAgreeOrStronglyAgreeCount = 2;
  static const deeperAverageScore = 50.0;

  static const promptHighDomainCount = 1;
  static const promptElevatedDomainCount = 2;
  static const promptFunctionalImpactCount = 3;
  static const followUpElevatedDomainCount = 1;
  static const followUpModerateDomainCount = 2;
  static const followUpFunctionalImpactCount = 2;
  static const monitorModerateDomainCount = 1;
  static const monitorFunctionalImpactCount = 1;

  /// Explicit metadata replacing the former question-text search. These IDs
  /// preserve the existing priority behavior without making wording changes
  /// alter support guidance.
  static const functionalImpactQuestionIds = <String>{
    'academic_core_6',
    'academic_core_7',
    'academic_core_9',
    'academic_deeper_6',
    'academic_deeper_7',
    'financial_3',
    'sleep_1',
    'sleep_3',
    'sleep_4',
    'sleep_5',
    'sleep_6',
    'sleep_7',
    'sleep_8',
    'sleep_9',
    'sleep_10',
    'faculty_workplace_core_7',
    'faculty_workplace_core_9',
    'faculty_workplace_deeper_2',
    'faculty_workplace_deeper_5',
    'faculty_workplace_deeper_8',
    'faculty_workplace_deeper_9',
    'staff_responsibility_core_6',
    'staff_responsibility_core_9',
    'staff_responsibility_deeper_6',
    'staff_responsibility_deeper_7',
    'common_sleep_1',
    'common_sleep_3',
    'common_sleep_4',
    'common_sleep_5',
    'common_sleep_6',
    'common_sleep_7',
    'common_sleep_8',
    'common_sleep_9',
    'common_sleep_10',
  };

  static const domainWeights = <String, Map<String, double>>{
    'student': {
      'Academic Stress': .25,
      'Financial Well-Being': .15,
      'Social Adjustment': .10,
      'Sleep and Rest': .20,
      'Emotional Well-Being': .30,
    },
    'faculty': {
      'Workplace Stress': .30,
      'Professional Support': .15,
      'Professional Well-Being': .15,
      'Sleep and Rest': .15,
      'Emotional Well-Being': .25,
    },
    'staff': {
      'Workplace Responsibilities': .30,
      'Workplace Support': .15,
      'Workplace Well-Being': .15,
      'Sleep and Rest': .15,
      'Emotional Well-Being': .25,
    },
  };

  static double weight(String role, String domain) =>
      domainWeights[role]?[domain] ??
      (throw StateError('Missing assessment weight for $role/$domain.'));

  static const disclosure =
      'This wellness-awareness score is an estimate produced by an experimental internal framework. No documented validation source was found for its exact questions, weights, thresholds, or follow-up rules. It is not a diagnosis, does not replace a licensed professional, and does not automatically alert a counselor or emergency service.';
}
