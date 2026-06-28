import '../domain/mind_aid_dataset_models.dart';

class MindAidTriageResult {
  const MindAidTriageResult({
    required this.severity,
    required this.requiresEscalation,
    required this.riskFlags,
  });

  final MindAidSeverity severity;
  final bool requiresEscalation;
  final List<String> riskFlags;
}

class TriageEngine {
  static MindAidTriageResult classify(MindAidDatasetRecord record) {
    return MindAidTriageResult(
      severity: record.severity,
      requiresEscalation: record.requiresEscalation,
      riskFlags: record.riskFlags,
    );
  }
}
