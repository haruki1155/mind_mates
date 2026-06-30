import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'providers/assessment_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/mind_aid_provider.dart';
import 'providers/secret_chat_provider.dart';
import 'providers/user_provider.dart';
import 'repositories/assessment_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/mind_aid_repository_screen.dart';
import 'repositories/secret_chat_repository.dart';
import 'repositories/user_repository.dart';
import 'services/auth/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthRepository(AuthService())),
        ),
        ChangeNotifierProvider(create: (_) => UserProvider(UserRepository())),
        ChangeNotifierProvider(
          create: (_) => MindAidProvider(MindAidRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => SecretChatProvider(SecretChatRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => AssessmentProvider(AssessmentRepository()),
        ),
      ],
      child: const MindMateApp(),
    ),
  );
}
