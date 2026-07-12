import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'providers/assessment_provider.dart';
import 'providers/appointment_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/breathing_provider.dart';
import 'providers/insights_provider.dart';
import 'providers/mental_health_activity_provider.dart';
import 'providers/mind_aid_provider.dart';
import 'providers/journal_provider.dart';
import 'providers/mood_provider.dart';
import 'providers/report_provider.dart';
import 'providers/secret_chat_provider.dart';
import 'providers/user_provider.dart';
import 'repositories/assessment_repository.dart';
import 'repositories/appointment_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/breathing_repository.dart';
import 'repositories/insights_repository.dart';
import 'repositories/journal_repository.dart';
import 'repositories/mental_health_activity_repository.dart';
import 'repositories/mind_aid_repository_screen.dart';
import 'repositories/mood_repository.dart';
import 'repositories/report_repository.dart';
import 'repositories/secret_chat_repository.dart';
import 'repositories/user_repository.dart';
import 'services/auth/auth_service.dart';
import 'services/firebase/firebase_app_check_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthRepository(AuthService())),
        ),
        ChangeNotifierProvider(create: (_) => UserProvider(UserRepository())),
        ChangeNotifierProvider(create: (_) => MoodProvider(MoodRepository())),
        ChangeNotifierProvider(
          create: (_) => AppointmentProvider(AppointmentRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => JournalProvider(JournalRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => ReportProvider(ReportRepository()),
        ),
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
      ],
      child: const MindMateApp(),
    ),
  );
}
