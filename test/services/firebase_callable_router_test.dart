import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/services/firebase/firebase_callable_router.dart';

void main() {
  test('uses the development alias for App-Check-sensitive auth calls', () {
    const productionName = 'getAssessmentStatus';
    expect(
      FirebaseCallableRouter.name(productionName),
      'getAssessmentStatusDev',
    );
  });

  test('routes every audited callable consistently', () {
    const operations = [
      'provisionAppUserProfile',
      'getAssessmentStatus',
      'submitQuickAssessment',
      'submitFullAssessment',
      'sendMindAidMessage',
      'requestPasswordRecovery',
      'createAppointmentRequest',
      'saveSecretChatProfile',
      'getAdminServiceMonitoring',
    ];
    for (final operation in operations) {
      expect(FirebaseCallableRouter.name(operation), '${operation}Dev');
    }
  });
}
