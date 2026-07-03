import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/features/secret_chat/domain/secret_chat_safety_validator.dart';

void main() {
  const validator = SecretChatSafetyValidator();

  test('allows mental health and wellbeing posts', () {
    final result = validator.validatePost(
      'I feel overwhelmed by school pressure, but breathing helps me rest.',
    );

    expect(result.isAllowed, isTrue);
    expect(result.labels, contains('stress'));
  });

  test('blocks off-topic posts', () {
    final result = validator.validatePost('Selling my old laptop this week.');

    expect(result.code, SecretChatValidationCode.offTopic);
  });

  test('blocks personal contact information', () {
    final result = validator.validatePost(
      'I feel anxious, please message me at test@example.com.',
    );

    expect(result.code, SecretChatValidationCode.containsPersonalInfo);
  });

  test('routes crisis language away from public posting', () {
    final result = validator.validatePost(
      'I feel suicidal and do not know what to do.',
    );

    expect(result.code, SecretChatValidationCode.crisisSupport);
  });
}
