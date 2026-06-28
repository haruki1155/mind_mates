import '../domain/mind_aid_context.dart';
import '../domain/mind_aid_dataset_models.dart';

class ScoreEngine {
  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static double scoreRecord(
    String normalizedInput,
    MindAidDatasetRecord record, {
    MindAidContext context = const MindAidContext(),
  }) {
    var score = 0.0;

    for (final keyword in record.keywords) {
      if (containsTerm(normalizedInput, normalize(keyword))) {
        score += 1;
      }
    }

    for (final phrase in record.phrases) {
      if (normalizedInput.contains(normalize(phrase))) {
        score += 2.5;
      }
    }

    if (record.severity == MindAidSeverity.crisis && score > 0) {
      score += 10;
    }

    if (context.moodLevel != null &&
        context.moodLevel! <= 2 &&
        record.category != 'school') {
      score += 0.25;
    }

    if (context.assessmentScore != null &&
        context.assessmentScore! >= 8 &&
        record.severity == MindAidSeverity.medium) {
      score += 0.25;
    }

    return score;
  }

  static List<String> matchedTerms(String normalizedInput, List<String> terms) {
    return terms
        .where((term) => containsTerm(normalizedInput, normalize(term)))
        .toList(growable: false);
  }

  static List<String> matchedPhrases(
    String normalizedInput,
    List<String> phrases,
  ) {
    return phrases
        .where((phrase) => normalizedInput.contains(normalize(phrase)))
        .toList(growable: false);
  }

  static bool containsTerm(String text, String term) {
    if (term.isEmpty) return false;
    if (term.contains(' ')) return text.contains(term);
    final escaped = RegExp.escape(term);
    return RegExp('(^|\\s)${escaped}s?(\\s|\$)').hasMatch(text);
  }
}
