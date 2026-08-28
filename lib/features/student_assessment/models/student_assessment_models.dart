import 'assessment_interpretation_models.dart';
import '../config/assessment_policy.dart';

enum LikertAnswer {
  stronglyDisagree,
  disagree,
  neutral,
  agree,
  stronglyAgree;

  /// Compatibility aliases for pre-agreement-scale callers. Serialized
  /// responses always use the agreement semantic names above.
  @Deprecated('Use stronglyDisagree')
  static const never = stronglyDisagree;
  @Deprecated('Use disagree')
  static const rarely = disagree;
  @Deprecated('Use neutral')
  static const sometimes = neutral;
  @Deprecated('Use agree')
  static const often = agree;
  @Deprecated('Use stronglyAgree')
  static const always = stronglyAgree;

  int get value => index + 1;

  String get label {
    switch (this) {
      case LikertAnswer.stronglyDisagree:
        return 'Strongly Disagree';
      case LikertAnswer.disagree:
        return 'Disagree';
      case LikertAnswer.neutral:
        return 'Neutral';
      case LikertAnswer.agree:
        return 'Agree';
      case LikertAnswer.stronglyAgree:
        return 'Strongly Agree';
    }
  }
}

enum AssessmentSection {
  academicCore,
  academicDeeper,
  financialConcern,
  socialAdjustment,
  workplaceStressCore,
  workplaceStressDeeper,
  professionalSupport,
  professionalWellBeing,
  workplaceResponsibilityCore,
  workplaceResponsibilityDeeper,
  workplaceSupport,
  workplaceWellBeing,
  sleepRest,
  emotionalWellBeing;

  String get label {
    switch (this) {
      case AssessmentSection.academicCore:
      case AssessmentSection.academicDeeper:
        return 'Academic Stress';
      case AssessmentSection.financialConcern:
        return 'Financial Well-Being';
      case AssessmentSection.socialAdjustment:
        return 'Social Adjustment';
      case AssessmentSection.workplaceStressCore:
      case AssessmentSection.workplaceStressDeeper:
        return 'Workplace Stress';
      case AssessmentSection.professionalSupport:
        return 'Professional Support';
      case AssessmentSection.professionalWellBeing:
        return 'Professional Well-Being';
      case AssessmentSection.workplaceResponsibilityCore:
      case AssessmentSection.workplaceResponsibilityDeeper:
        return 'Workplace Responsibilities';
      case AssessmentSection.workplaceSupport:
        return 'Workplace Support';
      case AssessmentSection.workplaceWellBeing:
        return 'Workplace Well-Being';
      case AssessmentSection.sleepRest:
        return 'Sleep and Rest';
      case AssessmentSection.emotionalWellBeing:
        return 'Emotional Well-Being';
    }
  }
}

enum AssessmentDirection { risk, protective }

class StudentAssessmentQuestion {
  const StudentAssessmentQuestion({
    required this.id,
    required this.text,
    required this.section,
    required this.direction,
    this.isConditional = false,
  });

  final String id;
  final String text;
  final AssessmentSection section;
  final AssessmentDirection direction;
  final bool isConditional;

  bool get isFunctionalImpactItem =>
      AssessmentPolicy.functionalImpactQuestionIds.contains(id);

  bool get affectsDomainScore => !isConditional;

  bool get affectsSupportPriority => isFunctionalImpactItem;

  String? get functionalImpactCategory =>
      isFunctionalImpactItem ? section.label : null;

  int get priorityContribution => isFunctionalImpactItem ? 1 : 0;
}

class StudentAssessmentAnswer {
  const StudentAssessmentAnswer({
    required this.questionId,
    required this.answer,
    this.isSkipped = false,
  });

  final String questionId;
  final LikertAnswer answer;
  final bool isSkipped;

  Map<String, Object> toJson() {
    return {
      'questionId': questionId,
      'answer': answer.name,
      'value': answer.value,
      'isSkipped': isSkipped,
    };
  }
}

class StudentAssessmentResult {
  const StudentAssessmentResult({
    required this.userType,
    required this.overallScore,
    required this.status,
    required this.subscaleScores,
    required this.mainConcernAreas,
    required this.message,
    required this.disclaimer,
    required this.totalResponses,
    required this.interpretation,
    this.responseScaleVersion = AssessmentPolicy.fullResponseScaleVersion,
  });

  final String userType;
  final double? overallScore;
  final String status;
  final Map<String, double> subscaleScores;
  final List<String> mainConcernAreas;
  final String message;
  final String disclaimer;
  final int totalResponses;
  final AssessmentInterpretation interpretation;
  final String responseScaleVersion;

  factory StudentAssessmentResult.fromJson(Map<String, dynamic> json) {
    final rawScores = json['subscaleScores'];
    final scores = <String, double>{};
    if (rawScores is Map) {
      for (final entry in rawScores.entries) {
        final value = entry.value;
        if (value is num) scores[entry.key.toString()] = value.toDouble();
      }
    }
    final rawInterpretation = json['interpretation'];
    return StudentAssessmentResult(
      userType: json['userType']?.toString() ?? 'Student',
      overallScore: _nullableDouble(json['overallScore']),
      status: json['status']?.toString() ?? 'Insufficient Responses',
      subscaleScores: scores,
      mainConcernAreas: _stringList(json['mainConcernAreas']),
      message: json['message']?.toString() ?? '',
      disclaimer: json['disclaimer']?.toString() ?? '',
      totalResponses: _int(json['totalResponses']),
      responseScaleVersion:
          json['responseScaleVersion']?.toString() ??
          AssessmentPolicy.fullResponseScaleVersion,
      interpretation: AssessmentInterpretation.fromJson(
        rawInterpretation is Map
            ? Map<String, dynamic>.from(rawInterpretation)
            : json,
      ),
    );
  }

  Map<String, Object> toJson() {
    return {
      'userType': userType,
      'overallScore': ?overallScore,
      'status': status,
      'subscaleScores': subscaleScores,
      'mainConcernAreas': mainConcernAreas,
      'message': message,
      'disclaimer': disclaimer,
      'totalResponses': totalResponses,
      'algorithmVersion': interpretation.algorithmVersion,
      'questionSetVersion': interpretation.questionSetVersion,
      'responseScaleVersion': responseScaleVersion,
      'supportPriority': interpretation.supportPriority.name,
      'interpretation': interpretation.toJson(),
    };
  }
}

double? _nullableDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString());
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}
