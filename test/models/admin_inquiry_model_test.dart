import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/models/admin_inquiry_model.dart';

void main() {
  test('parses inquiry status and preserves inquiry details', () {
    final inquiry = AdminInquiryModel.fromJson({
      'id': 'inquiry-1',
      'userId': 'user-1',
      'subject': 'Course selection',
      'message': 'I need guidance choosing classes.',
      'category': 'Academic',
      'email': 'student@example.edu',
      'name': 'Jamie Lee',
      'role': 'student',
      'status': 'in_progress',
      'createdAt': '2026-07-13T10:00:00.000',
    });

    expect(inquiry.status, InquiryStatus.inProgress);
    expect(inquiry.displayName, 'Jamie Lee');
    expect(inquiry.toJson()['status'], 'in_progress');
  });

  test('defaults an unknown inquiry status to pending', () {
    expect(InquiryStatus.fromValue('new'), InquiryStatus.pending);
    expect(InquiryStatus.resolved.label, 'Resolved');
  });
}
