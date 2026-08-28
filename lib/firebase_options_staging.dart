import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Staging only has Android (tester builds) and Web (admin portal)
/// registrations. Deliberately reject every other platform so a staging
/// command can never use production Firebase options.
class StagingFirebaseOptions {
  const StagingFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError(
      'Staging Firebase is configured for Android testers and the Admin web '
      'portal only.',
    );
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyDQU_4AmHJVeZ7Yv6KspxJCZ8-AjTbEAWc',
    appId: '1:978195258114:android:36354078e3d99999f5801b',
    messagingSenderId: '978195258114',
    projectId: 'mindmate-staging',
    storageBucket: 'mindmate-staging.firebasestorage.app',
  );

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyCR2rylEQKFT5C0EzaF-daPlf5hkTr_w2w',
    appId: '1:978195258114:web:76a13336c1bc2088f5801b',
    messagingSenderId: '978195258114',
    projectId: 'mindmate-staging',
    authDomain: 'mindmate-staging.firebaseapp.com',
    storageBucket: 'mindmate-staging.firebasestorage.app',
    measurementId: 'G-FVXXSPVMH3',
  );
}
