import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/core/config/support_contact_config.dart';
import 'package:mind_mates/features/student_assessment/config/assessment_policy.dart';

void main() {
  test('unverified and incomplete contacts are suppressed', () {
    final unverified = SupportContact.fromJson({
      'value': '+00 000 000 0000',
      'type': 'crisis',
      'displayName': 'Placeholder service',
      'availability': '24/7',
      'verificationStatus': 'unverified',
      'enabled': true,
    });

    expect(
      SupportContactConfig(contacts: [unverified]).displayableContacts,
      isEmpty,
    );
    expect(SupportContactConfig.safeFallback, contains('locally verified'));
    expect(SupportContactConfig.safeFallback, isNot(contains('24/7')));
  });

  test('fully verified enabled contact is displayable', () {
    final verified = SupportContact.fromJson({
      'value': 'verified-value',
      'type': 'counseling',
      'displayName': 'Approved counseling service',
      'availability': 'Approved office hours',
      'verificationStatus': 'verified',
      'verifiedAt': '2026-07-01T00:00:00Z',
      'approvingAuthority': 'Authorized institutional office',
      'enabled': true,
    });

    expect(verified.isDisplayable, isTrue);
  });

  test('experimental policy metadata and every domain weight are explicit', () {
    expect(AssessmentPolicy.fullScoringPolicyVersion, contains('internal'));
    expect(AssessmentPolicy.validationStatus, 'requires_professional_review');
    for (final role in AssessmentPolicy.domainWeights.entries) {
      expect(role.value.values.reduce((a, b) => a + b), closeTo(1, .0001));
      expect(role.value.values, everyElement(greaterThan(0)));
    }
  });
}
