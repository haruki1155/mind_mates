import 'package:flutter/material.dart';

import '../features/authentication/screens/forgot_password_screen.dart';
import '../features/authentication/screens/login_screen.dart';
import '../features/authentication/screens/signup_screen.dart';
import '../features/counseling/screens/mind_aid_screen.dart';
import '../features/counseling/screens/services_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/splash/screens/splash_screen.dart';
import 'route_names.dart';

class AppPages {
  const AppPages._();

  static final Map<String, WidgetBuilder> routes = {
    RouteNames.splash: (_) => const SplashScreen(),
    RouteNames.onboarding: (_) => const OnboardingScreen(),
    RouteNames.login: (_) => const LoginScreen(),
    RouteNames.signup: (_) => const SignupScreen(),
    RouteNames.forgotPassword: (_) => const ForgotPasswordScreen(),
    RouteNames.home: (_) => const HomeScreen(),
    RouteNames.services: (_) => const ServicesScreen(),
    RouteNames.mindAid: (_) => const MindAidScreen(),
  };
}
