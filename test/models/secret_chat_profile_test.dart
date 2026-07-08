import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/models/secret_chat_profile.dart';

void main() {
  test('normalizes aliases and creates case-insensitive reservation keys', () {
    expect(SecretChatProfile.normalizeAlias('  Calm   Owl  7 '), 'Calm Owl 7');
    expect(SecretChatProfile.aliasKeyFor('Calm Owl 7'), 'calm owl 7');
  });

  test('accepts only letters numbers and single normalized spaces', () {
    expect(SecretChatProfile.validateAlias('Mind Mate 22'), isNull);
    expect(SecretChatProfile.validateAlias('name_here'), isNotNull);
    expect(SecretChatProfile.validateAlias('name!'), isNotNull);
    expect(
      SecretChatProfile.validateAlias(List.filled(31, 'a').join()),
      isNotNull,
    );
    expect(SecretChatProfile.validateAlias(''), isNotNull);
  });
}
