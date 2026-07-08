import '../core/utils/firestore_mapper.dart';

class SecretChatProfile {
  const SecretChatProfile({
    required this.userId,
    required this.alias,
    required this.aliasKey,
    this.photoUrl,
    this.photoPath,
    this.updatedAt,
  });

  final String userId;
  final String alias;
  final String aliasKey;
  final String? photoUrl;
  final String? photoPath;
  final DateTime? updatedAt;

  static String normalizeAlias(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String aliasKeyFor(String value) =>
      normalizeAlias(value).toLowerCase();

  static String? validateAlias(String? value) {
    final normalized = normalizeAlias(value ?? '');
    if (normalized.isEmpty || normalized.length > 30) {
      return 'Use a name between 1 and 30 characters.';
    }
    if (!RegExp(r'^[A-Za-z0-9]+(?: [A-Za-z0-9]+)*$').hasMatch(normalized)) {
      return 'Use letters, numbers, and single spaces only.';
    }
    return null;
  }

  factory SecretChatProfile.fromJson(Map<String, dynamic> json) {
    return SecretChatProfile(
      userId: (json['userId'] ?? json['id'] ?? '').toString(),
      alias: (json['alias'] ?? 'Anonymous').toString(),
      aliasKey: (json['aliasKey'] ?? '').toString(),
      photoUrl: _optionalString(json['photoUrl']),
      photoPath: _optionalString(json['photoPath']),
      updatedAt: dateTimeFromFirestore(json['updatedAt']),
    );
  }

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class SecretChatProfileStats {
  const SecretChatProfileStats({
    required this.reads,
    required this.reactions,
    required this.comments,
  });

  final int reads;
  final int reactions;
  final int comments;

  static const empty = SecretChatProfileStats(
    reads: 0,
    reactions: 0,
    comments: 0,
  );
}

class SecretChatAliasTakenException implements Exception {
  const SecretChatAliasTakenException();

  @override
  String toString() => 'That Secret Chat name is already taken.';
}
