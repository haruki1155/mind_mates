import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

import 'core/config/app_environment.dart';
import 'firebase_options.dart';
import 'firebase_options_staging.dart';

class MindMatesFirebaseOptions {
  const MindMatesFirebaseOptions._();

  static FirebaseOptions get currentPlatform => AppEnvironmentConfig.isStaging
      ? StagingFirebaseOptions.currentPlatform
      : DefaultFirebaseOptions.currentPlatform;
}
