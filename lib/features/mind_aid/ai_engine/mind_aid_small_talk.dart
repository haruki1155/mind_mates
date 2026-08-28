enum MindAidSmallTalkKind { greeting, thanks, goodbye, capabilities }

class MindAidSmallTalk {
  const MindAidSmallTalk._();

  static MindAidSmallTalkKind? classify(String normalizedInput) {
    final input = normalizedInput.trim();
    if (input.isEmpty) return null;

    if (_greetings.contains(input)) return MindAidSmallTalkKind.greeting;
    if (_thanks.contains(input)) return MindAidSmallTalkKind.thanks;
    if (_goodbyes.contains(input)) return MindAidSmallTalkKind.goodbye;
    if (_capabilities.contains(input)) return MindAidSmallTalkKind.capabilities;
    return null;
  }

  static bool isSmallTalk(String normalizedInput) =>
      classify(normalizedInput) != null;

  static String responseFor(MindAidSmallTalkKind kind) {
    switch (kind) {
      case MindAidSmallTalkKind.greeting:
        return 'Hi! I\'m MindAid. I can chat with you or help with stress, school, sleep, mood, and practical next steps. How are you doing today?';
      case MindAidSmallTalkKind.thanks:
        return 'You\'re welcome. I\'m here whenever you want to talk or work through something.';
      case MindAidSmallTalkKind.goodbye:
        return 'Take care. You can come back and talk with me anytime.';
      case MindAidSmallTalkKind.capabilities:
        return 'I can have a simple conversation, help you check in, and offer practical support for stress, school, sleep, mood, and coping. I\'m not a replacement for a counselor or emergency service. What would you like help with?';
    }
  }

  static const _greetings = {
    'hi',
    'hello',
    'hey',
    'hi there',
    'hello there',
    'hey there',
    'good morning',
    'good afternoon',
    'good evening',
    'kamusta',
    'kumusta',
    'hi mindaid',
    'hello mindaid',
  };

  static const _thanks = {
    'thanks',
    'thank you',
    'thank you mindaid',
    'salamat',
    'maraming salamat',
  };

  static const _goodbyes = {
    'bye',
    'goodbye',
    'see you',
    'see you later',
    'talk later',
  };

  static const _capabilities = {
    'what can you do',
    'how can you help',
    'can you help me',
    'what do you do',
    'who are you',
  };
}
