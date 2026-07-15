import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/constants/app_colors.dart';
import 'features/admin/screens/admin_auth_gate.dart';
import 'firebase_options.dart';
import 'services/firebase/firebase_app_check_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await FirebaseAppCheckService.activate();
  } catch (error) {
    debugPrint('Firebase App Check activation failed: $error');
  }

  runApp(const MindMateAdminApp());
}

class MindMateAdminApp extends StatelessWidget {
  const MindMateAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MindMate Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
      ),
      home: const AdminAuthGate(),
    );
  }
}
