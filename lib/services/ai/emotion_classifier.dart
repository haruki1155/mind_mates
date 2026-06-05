class EmotionClassifier {
  String classify(double score) {
    if (score > 0.25) return 'positive';
    if (score < -0.25) return 'negative';
    return 'neutral';
  }
}
