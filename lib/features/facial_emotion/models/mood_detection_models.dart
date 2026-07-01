enum CameraMood {
  joy,
  sadness,
  trust,
  disgust,
  fear,
  anger,
  surprise,
  anticipation;

  String get key => name;

  String get label {
    switch (this) {
      case CameraMood.joy:
        return 'Joy';
      case CameraMood.sadness:
        return 'Sadness';
      case CameraMood.trust:
        return 'Trust';
      case CameraMood.disgust:
        return 'Disgust';
      case CameraMood.fear:
        return 'Fear';
      case CameraMood.anger:
        return 'Anger';
      case CameraMood.surprise:
        return 'Surprise';
      case CameraMood.anticipation:
        return 'Anticipation';
    }
  }

  String get emoji {
    switch (this) {
      case CameraMood.joy:
        return '😊';
      case CameraMood.sadness:
        return '😔';
      case CameraMood.trust:
        return '🤝';
      case CameraMood.disgust:
        return '😣';
      case CameraMood.fear:
        return '😟';
      case CameraMood.anger:
        return '😠';
      case CameraMood.surprise:
        return '😮';
      case CameraMood.anticipation:
        return '✨';
    }
  }

  int get level {
    switch (this) {
      case CameraMood.joy:
      case CameraMood.trust:
        return 5;
      case CameraMood.anticipation:
        return 4;
      case CameraMood.surprise:
        return 3;
      case CameraMood.sadness:
      case CameraMood.fear:
        return 2;
      case CameraMood.disgust:
      case CameraMood.anger:
        return 1;
    }
  }

  String get supportMessage {
    switch (this) {
      case CameraMood.joy:
        return 'You seem bright right now. Save this check-in to remember what supported this moment.';
      case CameraMood.sadness:
        return 'This check-in noticed a softer mood. A small pause or message to someone you trust may help.';
      case CameraMood.trust:
        return 'You seem grounded and open. This can be a good time to reflect on what feels supportive.';
      case CameraMood.disgust:
        return 'This estimate suggests discomfort. Try naming what feels off before deciding your next step.';
      case CameraMood.fear:
        return 'This estimate suggests tension or worry. Slow breathing can help your body settle first.';
      case CameraMood.anger:
        return 'This check-in noticed intensity. Give yourself room before responding to anything stressful.';
      case CameraMood.surprise:
        return 'This estimate suggests alertness. Take a moment to notice what changed around you.';
      case CameraMood.anticipation:
        return 'This check-in noticed expectation or readiness. Capture what you are preparing for.';
    }
  }

  static CameraMood fromKey(String? key) {
    return CameraMood.values.firstWhere(
      (mood) => mood.key == key,
      orElse: () => CameraMood.joy,
    );
  }
}

class MoodDetectionResult {
  const MoodDetectionResult({
    required this.mood,
    required this.confidence,
    this.secondaryMoods = const [],
    this.source = 'camera_fallback',
  });

  final CameraMood mood;
  final double confidence;
  final List<CameraMood> secondaryMoods;
  final String source;

  int get confidencePercent => (confidence.clamp(0, 1) * 100).round();
}
