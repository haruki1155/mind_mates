import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/onboarding/screens/onboarding_screen.dart';
import 'features/splash/screens/splash_screen.dart';
import 'providers/mind_aid_provider.dart';
import 'providers/secret_chat_provider.dart';
import 'repositories/mind_aid_repository_screen.dart';
import 'repositories/secret_chat_repository.dart';
import 'routes/route_generator.dart';

Widget previewAppWrapper(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => MindAidProvider(MindAidRepository()),
      ),
      ChangeNotifierProvider(
        create: (_) => SecretChatProvider(SecretChatRepository()),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      onGenerateRoute: RouteGenerator.generateRoute,
      home: child,
    ),
  );
}

@Preview(
  group: 'Screens',
  name: 'Splash',
  size: Size(390, 844),
  wrapper: previewAppWrapper,
)
Widget splashScreenPreview() {
  return const SplashScreen();
}

@Preview(
  group: 'Screens',
  name: 'Onboarding',
  size: Size(390, 844),
  wrapper: previewAppWrapper,
)
Widget onboardingScreenPreview() {
  return const OnboardingScreen();
}
