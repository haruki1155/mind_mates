class MindAidContext {
  const MindAidContext({
    this.recentMessages = const [],
    this.moodLevel,
    this.assessmentScore,
    this.journalText,
  });

  final List<String> recentMessages;
  final int? moodLevel;
  final int? assessmentScore;
  final String? journalText;
}
