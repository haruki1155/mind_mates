enum SecretChatValidationCode {
  allowed,
  offTopic,
  unsafe,
  tooShort,
  tooLong,
  containsPersonalInfo,
  crisisSupport,
}

class SecretChatValidationResult {
  const SecretChatValidationResult({
    required this.code,
    required this.message,
    this.labels = const [],
  });

  final SecretChatValidationCode code;
  final String message;
  final List<String> labels;

  bool get isAllowed => code == SecretChatValidationCode.allowed;
}

class SecretChatSafetyValidator {
  const SecretChatSafetyValidator();

  static const postMaxLength = 500;
  static const commentMaxLength = 400;

  SecretChatValidationResult validatePost(String text) {
    return _validate(text, minLength: 8, maxLength: postMaxLength);
  }

  SecretChatValidationResult validateComment(String text) {
    return _validate(text, minLength: 3, maxLength: commentMaxLength);
  }

  SecretChatValidationResult _validate(
    String text, {
    required int minLength,
    required int maxLength,
  }) {
    final normalized = text.trim().toLowerCase();
    if (normalized.length < minLength) {
      return const SecretChatValidationResult(
        code: SecretChatValidationCode.tooShort,
        message: 'Share a little more so others can understand your thought.',
      );
    }
    if (normalized.length > maxLength) {
      return SecretChatValidationResult(
        code: SecretChatValidationCode.tooLong,
        message: 'Please keep this under $maxLength characters.',
      );
    }
    if (_containsPersonalInfo(normalized)) {
      return const SecretChatValidationResult(
        code: SecretChatValidationCode.containsPersonalInfo,
        message:
            'For anonymity, please remove emails, phone numbers, links, handles, or IDs.',
      );
    }
    if (_containsCrisisLanguage(normalized)) {
      return const SecretChatValidationResult(
        code: SecretChatValidationCode.crisisSupport,
        labels: ['crisis_support'],
        message:
            'This sounds urgent. Please use MindAid or contact PACC/crisis support instead of posting publicly.',
      );
    }
    if (_containsUnsafeLanguage(normalized)) {
      return const SecretChatValidationResult(
        code: SecretChatValidationCode.unsafe,
        message:
            'Let us keep this space supportive. Please remove harmful, explicit, or attacking language.',
      );
    }
    if (!_isWellbeingRelated(normalized)) {
      return const SecretChatValidationResult(
        code: SecretChatValidationCode.offTopic,
        message:
            'Secret Chat is only for mental health, wellbeing, school stress, coping, gratitude, and support.',
      );
    }

    return SecretChatValidationResult(
      code: SecretChatValidationCode.allowed,
      labels: _labelsFor(normalized),
      message: 'Ready to share anonymously.',
    );
  }

  bool _containsPersonalInfo(String text) {
    final patterns = [
      RegExp(r'\b[\w\.\-]+@[\w\.\-]+\.\w{2,}\b'),
      RegExp(r'\b(?:\+?\d[\d\-\s()]{7,}\d)\b'),
      RegExp(r'\b(?:facebook|instagram|tiktok|telegram|discord)\b'),
      RegExp(r'@\w{3,}'),
      RegExp(r'\b(?:http|www\.)\S+'),
      RegExp(r'\b(?:student id|school id|id number)\b'),
    ];
    return patterns.any((pattern) => pattern.hasMatch(text));
  }

  bool _containsCrisisLanguage(String text) {
    const phrases = [
      'kill myself',
      'end my life',
      'suicide',
      'suicidal',
      'self harm',
      'self-harm',
      'hurt myself',
      'not want to live',
      'don\'t want to live',
    ];
    return phrases.any(text.contains);
  }

  bool _containsUnsafeLanguage(String text) {
    const phrases = [
      'porn',
      'sex',
      'nude',
      'buy now',
      'promo code',
      'free money',
      'hate you',
      'stupid idiot',
      'beat them',
      'hurt them',
      'weapon',
      'drugs for sale',
    ];
    return phrases.any(text.contains);
  }

  bool _isWellbeingRelated(String text) {
    const keywords = [
      'mental',
      'wellbeing',
      'wellness',
      'stress',
      'stressed',
      'anxiety',
      'anxious',
      'gratitude',
      'grateful',
      'pressure',
      'school',
      'class',
      'exam',
      'assignment',
      'study',
      'sleep',
      'rest',
      'tired',
      'burnout',
      'coping',
      'breathe',
      'breathing',
      'self care',
      'self-care',
      'support',
      'family',
      'friends',
      'lonely',
      'sad',
      'overwhelmed',
      'motivation',
      'focus',
      'therapy',
      'counseling',
      'healing',
      'emotion',
      'feel',
      'feeling',
      'mood',
      'worry',
      'worried',
    ];
    return keywords.any(text.contains);
  }

  List<String> _labelsFor(String text) {
    final labels = <String>[];
    void addIf(String label, List<String> words) {
      if (words.any(text.contains)) labels.add(label);
    }

    addIf('stress', ['stress', 'pressure', 'overwhelmed', 'burnout']);
    addIf('anxiety', ['anxiety', 'anxious', 'worry', 'worried']);
    addIf('gratitude', ['gratitude', 'grateful', 'thankful']);
    addIf('school_pressure', [
      'school',
      'class',
      'exam',
      'assignment',
      'study',
    ]);
    addIf('support', ['support', 'family', 'friends', 'lonely']);
    addIf('self_care', ['self care', 'self-care', 'rest', 'sleep', 'breathe']);
    return labels.isEmpty ? const ['wellbeing'] : labels.toSet().toList();
  }
}
