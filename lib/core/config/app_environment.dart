import 'package:flutter/foundation.dart';

enum AppEnvironment { development, staging, production }

class AppEnvironmentConfig {
  const AppEnvironmentConfig._();

  static const _name = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static AppEnvironment get current {
    if (_name == 'development') return AppEnvironment.development;
    if (_name == 'staging') return AppEnvironment.staging;
    if (_name == 'production') return AppEnvironment.production;
    throw StateError('APP_ENV must be development, staging, or production.');
  }

  static bool get isDevelopment => current == AppEnvironment.development;
  static bool get isStaging => current == AppEnvironment.staging;
  static bool get isProduction => current == AppEnvironment.production;

  static const developmentProjectId = 'mindmate-dev-4e91c';
  static const stagingProjectId = 'mindmate-staging';
  static const productionProjectId = 'mind-mates-cd2cf';
  static const functionsRegion = 'us-central1';

  static void validate() {
    if (kReleaseMode && !isProduction) {
      throw StateError(
        'Release builds must use APP_ENV=production. '
        'Development Firebase configuration was rejected.',
      );
    }
  }

  static void validateFirebaseIdentity({
    required AppEnvironment environment,
    required String projectId,
    required String callableRegion,
    bool releaseBuild = kReleaseMode,
  }) {
    final expectedProject = switch (environment) {
      AppEnvironment.development => developmentProjectId,
      AppEnvironment.staging => stagingProjectId,
      AppEnvironment.production => productionProjectId,
    };
    if (projectId != expectedProject) {
      throw StateError(
        'Firebase project $projectId does not match ${environment.name} '
        'environment (expected $expectedProject).',
      );
    }
    if (callableRegion != functionsRegion) {
      throw StateError(
        'Callable region $callableRegion does not match the configured '
        'region $functionsRegion.',
      );
    }
    if (releaseBuild && environment != AppEnvironment.production) {
      throw StateError('Release builds must use the production environment.');
    }
  }
}
