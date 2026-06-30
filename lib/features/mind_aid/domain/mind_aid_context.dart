class MindAidAssessmentContext {
  const MindAidAssessmentContext({
    required this.userType,
    required this.overallScore,
    required this.status,
    required this.mainConcernAreas,
    required this.subscaleScores,
    required this.summaryMessage,
    this.createdAt,
  });

  final String userType;
  final double overallScore;
  final String status;
  final List<String> mainConcernAreas;
  final Map<String, double> subscaleScores;
  final String summaryMessage;
  final DateTime? createdAt;

  bool get hasCategoryScores => subscaleScores.isNotEmpty;

  MapEntry<String, double>? get highestCategory {
    if (subscaleScores.isEmpty) return null;

    final entries = subscaleScores.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return entries.first;
  }

  List<MapEntry<String, double>> get topCategories {
    final entries = subscaleScores.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return entries.take(3).toList(growable: false);
  }
}

class MindAidContext {
  const MindAidContext({
    this.recentMessages = const [],
    this.moodLevel,
    this.assessmentScore,
    this.assessment,
    this.conversationSummary,
    this.preferredSupportStyle,
    this.journalText,
  });

  final List<String> recentMessages;
  final int? moodLevel;
  final int? assessmentScore;
  final MindAidAssessmentContext? assessment;
  final String? conversationSummary;
  final MindAidSupportStyle? preferredSupportStyle;
  final String? journalText;

  int? get effectiveAssessmentScore {
    final fullScore = assessment?.overallScore.round();
    return fullScore ?? assessmentScore;
  }

  bool get hasAssessment => assessment != null || assessmentScore != null;

  MindAidContext copyWith({
    List<String>? recentMessages,
    int? moodLevel,
    int? assessmentScore,
    MindAidAssessmentContext? assessment,
    String? conversationSummary,
    MindAidSupportStyle? preferredSupportStyle,
    String? journalText,
  }) {
    return MindAidContext(
      recentMessages: recentMessages ?? this.recentMessages,
      moodLevel: moodLevel ?? this.moodLevel,
      assessmentScore: assessmentScore ?? this.assessmentScore,
      assessment: assessment ?? this.assessment,
      conversationSummary: conversationSummary ?? this.conversationSummary,
      preferredSupportStyle:
          preferredSupportStyle ?? this.preferredSupportStyle,
      journalText: journalText ?? this.journalText,
    );
  }
}

enum MindAidSupportStyle {
  calming,
  practical,
  reflective,
  motivational;

  String get label {
    switch (this) {
      case MindAidSupportStyle.calming:
        return 'calming';
      case MindAidSupportStyle.practical:
        return 'practical';
      case MindAidSupportStyle.reflective:
        return 'reflective';
      case MindAidSupportStyle.motivational:
        return 'motivational';
    }
  }
}
