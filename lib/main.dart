import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'app_bootstrap.dart';
import 'firebase_options_selector.dart';
import 'providers/assessment_provider.dart';
import 'providers/appointment_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/breathing_provider.dart';
import 'providers/insights_provider.dart';
import 'providers/mental_health_activity_provider.dart';
import 'providers/mind_aid_provider.dart';
import 'providers/mood_provider.dart';
import 'providers/report_provider.dart';
import 'providers/secret_chat_provider.dart';
import 'providers/sleep_provider.dart';
import 'providers/user_provider.dart';
import 'repositories/assessment_repository.dart';
import 'repositories/appointment_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/breathing_repository.dart';
import 'repositories/insights_repository.dart';
import 'repositories/mental_health_activity_repository.dart';
import 'repositories/mind_aid_repository_screen.dart';
import 'repositories/mood_repository.dart';
import 'repositories/report_repository.dart';
import 'repositories/secret_chat_repository.dart';
import 'repositories/sleep_repository.dart';
import 'repositories/user_repository.dart';
import 'services/auth/auth_service.dart';
import 'services/firebase/firebase_app_check_service.dart';
import 'services/firebase/firebase_callable_router.dart';
import 'core/config/app_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppEnvironmentConfig.validate();
  AppEnvironmentConfig.validateFirebaseIdentity(
    environment: AppEnvironmentConfig.current,
    projectId: MindMatesFirebaseOptions.currentPlatform.projectId,
    callableRegion: AppEnvironmentConfig.functionsRegion,
  );
  await Firebase.initializeApp(
    options: MindMatesFirebaseOptions.currentPlatform,
  );
  FirebaseCallableRouter.configure(
    FirebaseFunctions.instanceFor(region: 'us-central1'),
  );
  try {
    await FirebaseAppCheckService.activate();
  } catch (error) {
    debugPrint('Firebase App Check activation failed: $error');
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFFFFFFFF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final userProvider = UserProvider(UserRepository());
  final authProvider = AuthProvider(
    AuthRepository(AuthService()),
    onSessionCleared: userProvider.clear,
  )..monitorAuthState();
  final mobileApp = MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => authProvider),
      ChangeNotifierProvider(create: (_) => userProvider),
      ChangeNotifierProvider(create: (_) => MoodProvider(MoodRepository())),
      ChangeNotifierProvider(
        create: (_) => AppointmentProvider(AppointmentRepository()),
      ),

      ChangeNotifierProvider(create: (_) => ReportProvider(ReportRepository())),
      ChangeNotifierProvider(
        create: (_) =>
            MentalHealthActivityProvider(MentalHealthActivityRepository()),
      ),
      ChangeNotifierProvider(
        create: (_) => InsightsProvider(InsightsRepository()),
      ),
      ChangeNotifierProvider(
        create: (_) => MindAidProvider(MindAidRepository()),
      ),
      ChangeNotifierProvider(
        create: (_) => SecretChatProvider(SecretChatRepository()),
      ),
      ChangeNotifierProvider(
        create: (_) => AssessmentProvider(AssessmentRepository()),
      ),
      ChangeNotifierProvider(
        create: (_) => BreathingProvider(BreathingRepository()),
      ),
      ChangeNotifierProvider(create: (_) => SleepProvider(SleepRepository())),
    ],
    child: const MindMateApp(),
  );

  runApp(
    selectMindMateRoot(
      isWeb: kIsWeb,
      mobileApp: mobileApp,
      appCheckStatus: FirebaseAppCheckService.status,
    ),
  );
}
