import 'mind_aid_dataset_models.dart';

class MindAidEngineResult {
  const MindAidEngineResult({
    required this.intent,
    required this.category,
    required this.severity,
    required this.score,
    required this.response,
    required this.riskFlags,
    required this.copingSteps,
    required this.recommendations,
    required this.followUpQuestions,
    required this.requiresEscalation,
  });

  final String intent;
  final String category;
  final MindAidSeverity severity;
  final double score;
  final String response;
  final List<MindAidCopingExercise> copingSteps;
  final List<MindAidResource> recommendations;
  final List<String> riskFlags;
  final List<String> followUpQuestions;
  final bool requiresEscalation;

  bool get isFallback => intent == 'general_support';
}
