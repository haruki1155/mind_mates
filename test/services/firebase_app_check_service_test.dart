import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/services/firebase/firebase_app_check_service.dart';
import 'package:mind_mates/services/firebase/firebase_runtime_diagnostics.dart';

void main() {
  test('web App Check requires a non-empty Enterprise site key', () {
    expect(
      FirebaseAppCheckService.statusForWebSiteKey(''),
      FirebaseAppCheckStatus.missingWebConfiguration,
    );
    expect(
      FirebaseAppCheckService.statusForWebSiteKey('  '),
      FirebaseAppCheckStatus.missingWebConfiguration,
    );
    expect(
      FirebaseAppCheckService.statusForWebSiteKey('site-key'),
      FirebaseAppCheckStatus.active,
    );
  });

  test(
    'web configuration error tells developers how to configure App Check',
    () {
      expect(
        FirebaseAppCheckService.webConfigurationMessage,
        contains('RECAPTCHA_ENTERPRISE_SITE_KEY'),
      );
    },
  );

  test('safe diagnostics extract only code and correlation ID', () {
    final error = FirebaseFunctionsException(
      code: 'failed-precondition',
      message: 'private message must not be copied into metadata',
      details: const {'correlationId': 'correlation-123'},
    );

    expect(
      FirebaseRuntimeDiagnostics.firebaseErrorCode(error),
      'failed-precondition',
    );
    expect(
      FirebaseRuntimeDiagnostics.correlationIdFrom(error),
      'correlation-123',
    );
  });
}
