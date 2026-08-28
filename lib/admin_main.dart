import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'features/admin/screens/admin_auth_gate.dart';
import 'features/admin/domain/admin_colors.dart';
import 'firebase_options_selector.dart';
import 'services/firebase/firebase_app_check_service.dart';
import 'app_bootstrap.dart';
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
  try {
    await FirebaseAppCheckService.activate();
  } catch (error) {
    debugPrint('Firebase App Check activation failed: $error');
  }

  runApp(
    selectMindMateRoot(
      isWeb: true,
      mobileApp: const MindMateAdminApp(),
      appCheckStatus: FirebaseAppCheckService.status,
    ),
  );
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
          seedColor: AdminColors.primary,
          primary: AdminColors.primary,
          surface: AdminColors.surface,
        ),
        scaffoldBackgroundColor: AdminColors.background,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AdminColors.textPrimary),
          bodyMedium: TextStyle(color: AdminColors.textPrimary),
          bodySmall: TextStyle(color: AdminColors.textMuted),
          titleLarge: TextStyle(color: AdminColors.textPrimary),
          titleMedium: TextStyle(color: AdminColors.textPrimary),
          headlineMedium: TextStyle(color: AdminColors.textPrimary),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AdminColors.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AdminColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AdminColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AdminColors.primaryPressed,
              width: 2,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AdminColors.primaryPressed,
          ),
        ),
        dividerTheme: const DividerThemeData(color: AdminColors.border),
        dataTableTheme: const DataTableThemeData(
          headingRowColor: WidgetStatePropertyAll(AdminColors.softSurface),
          headingTextStyle: TextStyle(
            color: AdminColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      home: const AdminAuthGate(),
    );
  }
}
