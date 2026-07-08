import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/models/secret_chat_model.dart';

void main() {
  test('SecretChatModel parses safety fields with defaults', () {
    final post = SecretChatModel.fromJson({
      'id': 'post_1',
      'authorId': 'user_1',
      'message': 'I feel stressed about exams.',
      'category': 'Stress',
      'likeCount': 2,
      'commentCount': 1,
      'safetyLabels': ['stress'],
      'isAnonymous': true,
    }, currentUserId: 'user_1');

    expect(post.isMine, isTrue);
    expect(post.moderationStatus, 'active');
    expect(post.safetyLabels, ['stress']);
    expect(post.isAnonymous, isTrue);
  });

  test('SecretChatComment parses safety fields with defaults', () {
    final comment = SecretChatComment.fromJson({
      'id': 'comment_1',
      'postId': 'post_1',
      'authorId': 'user_2',
      'message': 'You are not alone.',
    });

    expect(comment.moderationStatus, 'active');
    expect(comment.safetyLabels, isEmpty);
    expect(comment.isAnonymous, isTrue);
  });

  test('legacy category becomes a one-item category list', () {
    final post = SecretChatModel.fromJson({
      'id': 'legacy',
      'message': 'Legacy post',
      'category': 'Stress',
    });

    expect(post.categoryList, ['Stress']);
    expect(post.primaryCategory, 'Stress');
  });

  test('new category list preserves selection order', () {
    final post = SecretChatModel.fromJson({
      'id': 'new',
      'message': 'New post',
      'category': 'Support',
      'categories': ['Support', 'Anxiety', 'School Pressure'],
    });

    expect(post.categoryList, ['Support', 'Anxiety', 'School Pressure']);
    expect(post.primaryCategory, 'Support');
  });
}
