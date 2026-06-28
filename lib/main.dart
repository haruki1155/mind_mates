import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/mind_aid_provider.dart';
import 'providers/secret_chat_provider.dart';
import 'repositories/mind_aid_repository_screen.dart';
import 'repositories/secret_chat_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => MindAidProvider(MindAidRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => SecretChatProvider(SecretChatRepository()),
        ),
      ],
      child: const MindMateApp(),
    ),
  );
}
