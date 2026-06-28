import '../domain/mind_aid_context.dart';
import '../domain/mind_aid_chat_models.dart';
import '../domain/mind_aid_dataset_models.dart';
import 'score_engine.dart';

class IntentEngine {
  static const minimumConfidence = 1.0;

  static MindAidIntentMatch? detectBestMatch(
    String normalizedInput,
    MindAidDatasetBundle dataset, {
    MindAidContext context = const MindAidContext(),
  }) {
    MindAidIntentMatch? bestMatch;

    for (final record in dataset.allRecords) {
      final score = ScoreEngine.scoreRecord(
        normalizedInput,
        record,
        context: context,
      );

      if (score < minimumConfidence) continue;
      if (bestMatch == null || score > bestMatch.score) {
        bestMatch = MindAidIntentMatch(
          record: record,
          score: score,
          matchedKeywords: ScoreEngine.matchedTerms(
            normalizedInput,
            record.keywords,
          ),
          matchedPhrases: ScoreEngine.matchedPhrases(
            normalizedInput,
            record.phrases,
          ),
          confidence: (score / 6).clamp(0.05, 1).toDouble(),
        );
      }
    }

    return bestMatch;
  }
}
