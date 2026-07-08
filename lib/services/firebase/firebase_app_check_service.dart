import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class FirebaseAppCheckService {
  const FirebaseAppCheckService._();

  static const _webSiteKey = String.fromEnvironment('RECAPTCHA_V3_SITE_KEY');
  static const _debugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

  static Future<void> activate() async {
    if (kIsWeb) {
      if (_webSiteKey.isEmpty) {
        debugPrint(
          'Firebase App Check is not active on web: provide '
          '--dart-define=RECAPTCHA_V3_SITE_KEY=your-site-key.',
        );
        return;
      }
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(_webSiteKey),
      );
      return;
    }

    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? AndroidDebugProvider(
              debugToken: _debugToken.isEmpty ? null : _debugToken,
            )
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? AppleDebugProvider(
              debugToken: _debugToken.isEmpty ? null : _debugToken,
            )
          : const AppleDeviceCheckProvider(),
    );
  }

  static Future<String?> refreshToken() {
    return FirebaseAppCheck.instance.getToken(true);
  }
}
