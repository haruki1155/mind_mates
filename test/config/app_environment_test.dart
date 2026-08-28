import 'package:flutter_test/flutter_test.dart';
import 'package:mind_mates/core/config/app_environment.dart';

void main() {
  test('development identity requires the development project and region', () {
    expect(
      () => AppEnvironmentConfig.validateFirebaseIdentity(
        environment: AppEnvironment.development,
        projectId: AppEnvironmentConfig.developmentProjectId,
        callableRegion: AppEnvironmentConfig.functionsRegion,
        releaseBuild: false,
      ),
      returnsNormally,
    );
  });

  test('release identity rejects development project configuration', () {
    expect(
      () => AppEnvironmentConfig.validateFirebaseIdentity(
        environment: AppEnvironment.production,
        projectId: AppEnvironmentConfig.developmentProjectId,
        callableRegion: AppEnvironmentConfig.functionsRegion,
        releaseBuild: true,
      ),
      throwsStateError,
    );
  });

  test('staging identity requires the staging project', () {
    expect(
      () => AppEnvironmentConfig.validateFirebaseIdentity(
        environment: AppEnvironment.staging,
        projectId: AppEnvironmentConfig.stagingProjectId,
        callableRegion: AppEnvironmentConfig.functionsRegion,
        releaseBuild: false,
      ),
      returnsNormally,
    );
  });

  test('production identity requires the production functions region', () {
    expect(
      () => AppEnvironmentConfig.validateFirebaseIdentity(
        environment: AppEnvironment.production,
        projectId: AppEnvironmentConfig.productionProjectId,
        callableRegion: 'asia-southeast1',
        releaseBuild: true,
      ),
      throwsStateError,
    );
  });
}
