import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/android_firebase_identity.dart';
import '../../core/config/app_environment.dart';
import 'firebase_runtime_diagnostics.dart';

enum FirebaseAppCheckStatus {
  notStarted,
  active,
  disabledForDevelopment,
  missingWebConfiguration,
  activationFailed,
}

class FirebaseAppCheckService {
  const FirebaseAppCheckService._();

  static const _webSiteKey = String.fromEnvironment(
    'RECAPTCHA_ENTERPRISE_SITE_KEY',
    defaultValue: '6LcaIIctAAAAALvJeMnoXQN41JiPoxRuAhDeUltT',
  );
  // App Check is not needed to exercise Firestore during local native
  // development. The debug provider requires a per-installation token, which
  // needlessly blocks database testing. Keep an opt-in for testing callable
  // functions that explicitly enforce App Check.
  static const _enableDebugAppCheck = bool.fromEnvironment(
    'ENABLE_DEBUG_APP_CHECK',
    defaultValue: false,
  );
  static bool get _skipNativeAppCheckForDevelopment =>
      AppEnvironmentConfig.isDevelopment &&
      kDebugMode &&
      !kIsWeb &&
      !_enableDebugAppCheck;
  static FirebaseAppCheckStatus _status = FirebaseAppCheckStatus.notStarted;

  static FirebaseAppCheckStatus get status => _status;
  static bool get isWebConfigurationMissing =>
      kIsWeb && _status == FirebaseAppCheckStatus.missingWebConfiguration;
  static bool get isWebUnavailable =>
      kIsWeb &&
      (_status == FirebaseAppCheckStatus.missingWebConfiguration ||
          _status == FirebaseAppCheckStatus.activationFailed);
  static String get webConfigurationMessage =>
      'Web Firebase App Check is not configured. Run with '
      '--dart-define=RECAPTCHA_ENTERPRISE_SITE_KEY=<registered-site-key>.';

  static FirebaseAppCheckStatus statusForWebSiteKey(String siteKey) =>
      siteKey.trim().isEmpty
      ? FirebaseAppCheckStatus.missingWebConfiguration
      : FirebaseAppCheckStatus.active;

  static Future<void> activate() async {
    if (kIsWeb) {
      if (statusForWebSiteKey(_webSiteKey) ==
          FirebaseAppCheckStatus.missingWebConfiguration) {
        _status = statusForWebSiteKey(_webSiteKey);
        debugPrint(webConfigurationMessage);
        return;
      }
      try {
        await FirebaseAppCheck.instance.activate(
          providerWeb: ReCaptchaEnterpriseProvider(_webSiteKey),
        );
        _status = FirebaseAppCheckStatus.active;
      } catch (_) {
        _status = FirebaseAppCheckStatus.activationFailed;
        rethrow;
      }
      return;
    }

    if (_skipNativeAppCheckForDevelopment) {
      _status = FirebaseAppCheckStatus.disabledForDevelopment;
      FirebaseRuntimeDiagnostics.log(
        event: 'app_check_disabled_for_native_development',
      );
      return;
    }

    if (kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
      debugPrint(
        'Firebase App Check debug mode is active. Copy the Android debug token '
        'from Logcat and register it in Firebase Console for '
        '${AndroidFirebaseIdentity.packageName}.',
      );
    }

    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
      _status = FirebaseAppCheckStatus.active;
      FirebaseRuntimeDiagnostics.log(event: 'app_check_activated');
    } catch (error) {
      _status = FirebaseAppCheckStatus.activationFailed;
      FirebaseRuntimeDiagnostics.log(
        event: 'app_check_activation_failed',
        error: error,
      );
      rethrow;
    }
  }

  static Future<String?> refreshToken() {
    if (_skipNativeAppCheckForDevelopment) return Future<String?>.value(null);
    return FirebaseAppCheck.instance.getToken(true);
  }

  static Future<String> requireToken() async {
    if (_skipNativeAppCheckForDevelopment) {
      // This guard is intentionally development-only. Firebase Auth remains
      // required by Firestore Rules, and production callable/App Check
      // enforcement is unchanged.
      return 'development-app-check-bypass';
    }
    if (isWebUnavailable) throw StateError(webConfigurationMessage);
    if (_status != FirebaseAppCheckStatus.active) {
      throw StateError('Firebase App Check is not active on this device.');
    }
    final token = await FirebaseAppCheck.instance.getToken(false);
    if (token == null || token.trim().isEmpty) {
      throw StateError('Firebase App Check could not verify this app.');
    }
    return token;
  }
}
