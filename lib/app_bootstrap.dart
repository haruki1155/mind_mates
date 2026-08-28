import 'package:flutter/material.dart';

import 'services/firebase/firebase_app_check_service.dart';

Widget selectMindMateRoot({
  required bool isWeb,
  required Widget mobileApp,
  FirebaseAppCheckStatus? appCheckStatus,
}) {
  final status = appCheckStatus;
  if (isWeb &&
      (status == FirebaseAppCheckStatus.missingWebConfiguration ||
          status == FirebaseAppCheckStatus.activationFailed)) {
    return const FirebaseAppCheckConfigurationApp();
  }
  return mobileApp;
}

class FirebaseAppCheckConfigurationApp extends StatelessWidget {
  const FirebaseAppCheckConfigurationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_outlined, size: 52),
                  SizedBox(height: 16),
                  Text(
                    'MindMate web verification is not configured',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Start or build the app with a registered reCAPTCHA Enterprise site key using '
                    '--dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=<registered-site-key>.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
