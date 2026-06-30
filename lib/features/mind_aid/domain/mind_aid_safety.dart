enum MindAidSafetyLevel {
  safeSupport,
  needsClarification,
  highDistress,
  crisisOrImmediateRisk;

  bool get blocksCloud =>
      this == MindAidSafetyLevel.highDistress ||
      this == MindAidSafetyLevel.crisisOrImmediateRisk;
}

class MindAidSafetyResult {
  const MindAidSafetyResult({required this.level, this.reason = ''});

  final MindAidSafetyLevel level;
  final String reason;
}
