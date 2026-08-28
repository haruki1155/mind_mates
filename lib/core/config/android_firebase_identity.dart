import 'app_environment.dart';

class AndroidFirebaseIdentity {
  const AndroidFirebaseIdentity._();

  static String get packageName => switch (AppEnvironmentConfig.current) {
    AppEnvironment.development => 'com.example.mind_mates.dev',
    AppEnvironment.staging => 'com.example.mind_mates.staging',
    AppEnvironment.production => 'com.example.mind_mates',
  };

  static String get firebaseAppId => switch (AppEnvironmentConfig.current) {
    AppEnvironment.staging => '1:978195258114:android:36354078e3d99999f5801b',
    // These variants require their own generated Firebase configuration before
    // they can be distributed. Avoid claiming the stale app IDs were valid.
    AppEnvironment.development || AppEnvironment.production => '',
  };

  static String get firebaseProjectId => switch (AppEnvironmentConfig.current) {
    AppEnvironment.development => AppEnvironmentConfig.developmentProjectId,
    AppEnvironment.staging => AppEnvironmentConfig.stagingProjectId,
    AppEnvironment.production => AppEnvironmentConfig.productionProjectId,
  };
}
