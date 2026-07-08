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

  test('allows ordinary contextual comments without wellbeing keywords', () {
    expect(validator.validateComment('Same here!').isAllowed, isTrue);
    expect(
      validator.validateComment('I disagree, but I hear you.').isAllowed,
      isTrue,
    );
    expect(validator.validateComment('You got this').isAllowed, isTrue);
  });

  test('comments still block personal information and unsafe language', () {
    expect(
      validator.validateComment('Message me at person@example.com').code,
      SecretChatValidationCode.containsPersonalInfo,
    );
    expect(
      validator.validateComment('I will hurt you').code,
      SecretChatValidationCode.unsafe,
    );
    expect(
      validator.validateComment('I want to kill myself').code,
      SecretChatValidationCode.crisisSupport,
    );
  });

  test('boundary-aware filters avoid harmless substring false positives', () {
    expect(
      validator.validateComment('My class is in Essex.').isAllowed,
      isTrue,
    );
    expect(
      validator.validateComment('I study weaponry in history.').isAllowed,
      isTrue,
    );
  });

  test('comment length stays between 3 and 400 characters', () {
    expect(
      validator.validateComment('ok').code,
      SecretChatValidationCode.tooShort,
    );
    expect(
      validator.validateComment(List.filled(401, 'a').join()).code,
      SecretChatValidationCode.tooLong,
    );
  });
}
