import 'package:flutter/material.dart';

import '../features/admin/screens/admin_status_dashboard_screen.dart';
import '../features/authentication/screens/account_gate_screen.dart';
import '../features/authentication/screens/forgot_password_screen.dart';
import '../features/authentication/screens/login_screen.dart';
import '../features/authentication/screens/signup_screen.dart';
import '../features/breathing/screens/mindful_breathing_screen.dart';
import '../features/counseling/screens/services_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/profile/screens/mental_health_insights_screen.dart';
import '../features/profile/screens/mental_health_report_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/quick_assessment/screens/quick_assessment_category_screen.dart';
import '../features/quick_assessment/screens/quick_assessment_name_screen.dart';
import '../features/quick_assessment/screens/quick_assessment_question_screen.dart';
import '../features/quick_assessment/screens/quick_assessment_role_screen.dart';
import '../features/secret_chat/pages/secret_chat_page.dart';
import '../features/splash/screens/splash_screen.dart';
import '../features/student_assessment/screens/student_assessment_complete_screen.dart';
import '../features/student_assessment/screens/student_assessment_screen.dart';
import '../features/page/mind_aid_page.dart';
import 'route_names.dart';

class AppPages {
  const AppPages._();

  static final Map<String, WidgetBuilder> routes = {
    RouteNames.splash: (_) => const SplashScreen(),
    RouteNames.onboarding: (_) => const OnboardingScreen(),
    RouteNames.accountGate: (_) => const AccountGateScreen(),
    RouteNames.login: (_) => const LoginScreen(),
    RouteNames.signup: (_) => const SignupScreen(),
    RouteNames.forgotPassword: (_) => const ForgotPasswordScreen(),
    RouteNames.quickAssessmentRole: (_) => const QuickAssessmentRoleScreen(),
    RouteNames.quickAssessmentName: (_) => const QuickAssessmentNameScreen(),
    RouteNames.quickAssessmentQuestions: (_) =>
        const QuickAssessmentQuestionScreen(),
    RouteNames.quickAssessmentCategory: (_) =>
        const QuickAssessmentCategoryScreen(),
    RouteNames.studentAssessment: (_) => const StudentAssessmentScreen(),
    RouteNames.studentAssessmentComplete: (_) =>
        const StudentAssessmentCompleteScreen(),
    RouteNames.home: (_) => const HomeScreen(),
    RouteNames.services: (_) => const ServicesScreen(),
    RouteNames.mindAid: (_) => const MindAidPage(),
    RouteNames.secretChat: (_) => const SecretChatPage(),
    RouteNames.insights: (_) => const MentalHealthInsightsScreen(),
    RouteNames.profile: (_) => const ProfileScreen(),
    RouteNames.mentalHealthReport: (_) => const MentalHealthReportScreen(),
    RouteNames.mentalHealthInsights: (_) => const MentalHealthInsightsScreen(),
    RouteNames.mindfulBreathing: (_) => const MindfulBreathingScreen(),
    RouteNames.adminStatus: (_) => const AdminStatusDashboardScreen(),
  };
}
