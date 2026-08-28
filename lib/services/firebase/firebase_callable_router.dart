import 'package:cloud_functions/cloud_functions.dart';

import '../../core/config/app_environment.dart';

class FirebaseCallableRouter {
  const FirebaseCallableRouter._();

  static const _useFunctionsEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: false,
  );

  // Development callable wrappers intentionally disable App Check so a debug
  // APK can use the development Firebase project without a registered
  // production attestation. Production always uses the protected callable.
  static const _developmentAliases = <String>{
    'provisionAppUserProfile',
    'getAssessmentStatus',
    'submitQuickAssessment',
    'submitFullAssessment',
    'sendMindAidMessage',
    'requestPasswordRecovery',
    'confirmPasswordRecovery',
    'requestRecoveryEmailVerification',
    'confirmRecoveryEmailVerification',
    'createAppointmentRequest',
    'reviewAppointment',
    'respondToAppointmentReschedule',
    'scheduleAppointmentFollowUp',
    'startBreathingSession',
    'completeBreathingSession',
    'setSleepCloudConsent',
    'saveSleepEntry',
    'deleteSleepEntry',
    'deleteAllSleepEntries',
    'revokeSleepCloud',
    'createSleepShare',
    'revokeSleepShare',
    'saveSecretChatProfile',
    'finalizeSecretChatProfilePhoto',
    'removeSecretChatProfilePhoto',
    'deleteSecretChatPost',
    'rebuildMySecretChatStats',
    'registerStaffAccount',
    'reviewStaffRegistration',
    'setStaffAccountEnabled',
    'getAdminServiceMonitoring',
    'listPublicAppUsers',
    'getAppUserDashboardSummary',
    'backfillPublicAppUserIds',
    'previewInactiveAppUserDeletion',
    'deleteInactiveAppUsers',
    'confirmSuperAdmin',
    'completeAdminPasswordChange',
    'assignAccessRole',
    'saveOrganizationRecord',
    'updateStaffOrganization',
  };

  static String name(String productionName) {
    if (AppEnvironmentConfig.isDevelopment &&
        _developmentAliases.contains(productionName)) {
      return '${productionName}Dev';
    }
    return productionName;
  }

  static void configure(FirebaseFunctions functions) {
    if (AppEnvironmentConfig.isDevelopment && _useFunctionsEmulator) {
      functions.useFunctionsEmulator('127.0.0.1', 5001);
    }
  }

  static HttpsCallable callable(
    FirebaseFunctions functions,
    String productionName,
  ) => functions.httpsCallable(name(productionName));
}

extension FirebaseFunctionsRouting on FirebaseFunctions {
  HttpsCallable routedCallable(String productionName) =>
      httpsCallable(FirebaseCallableRouter.name(productionName));
}
