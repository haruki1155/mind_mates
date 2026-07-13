import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../routes/route_names.dart';
import '../domain/mind_aid_integration_models.dart';

class MindAidNavigation {
  const MindAidNavigation._();

  static final navigatorKey = GlobalKey<NavigatorState>();
  static final observer = MindAidRouteObserver();
}

class MindAidRouteObserver extends NavigatorObserver {
  final ValueNotifier<String?> currentRoute = ValueNotifier(RouteNames.splash);

  void _set(Route<dynamic>? route) {
    currentRoute.value = route?.settings.name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _set(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _set(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _set(newRoute);
  }
}

class MindAidLauncherOverlay extends StatelessWidget {
  const MindAidLauncherOverlay({required this.child, super.key});

  final Widget child;

  static const _excludedRoutes = {
    RouteNames.splash,
    RouteNames.onboarding,
    RouteNames.login,
    RouteNames.signup,
    RouteNames.forgotPassword,
    RouteNames.mindAid,
    RouteNames.adminStatus,
  };

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().userId;
    return ValueListenableBuilder<String?>(
      valueListenable: MindAidNavigation.observer.currentRoute,
      builder: (context, route, _) {
        final show =
            route != null &&
            userId?.trim().isNotEmpty == true &&
            !_excludedRoutes.contains(route);
        return Stack(
          children: [
            child,
            if (show)
              Positioned(
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 18,
                child: SafeArea(
                  child: FloatingActionButton.small(
                    heroTag: 'global_mind_aid_launcher',
                    tooltip: 'Talk to MindAid',
                    backgroundColor: const Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    onPressed: () => _openMindAid(route),
                    child: const Icon(Icons.psychology_alt_rounded),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _openMindAid(String? route) {
    final context = _launchContext(route);
    MindAidNavigation.navigatorKey.currentState?.pushNamed(
      RouteNames.mindAid,
      arguments: context,
    );
  }

  MindAidLaunchContext _launchContext(String? route) {
    switch (route) {
      case RouteNames.logMood:
        return const MindAidLaunchContext(
          source: 'mood',
          openingPrompt: 'Help me understand how I have been feeling.',
        );
      case RouteNames.journal:
        return const MindAidLaunchContext(
          source: 'journal',
          openingPrompt: 'Help me reflect without sharing my journal text.',
        );
      case RouteNames.studentAssessment:
      case RouteNames.studentAssessmentComplete:
        return const MindAidLaunchContext(
          source: 'assessment',
          openingPrompt: 'What does my assessment suggest?',
        );
      case RouteNames.mentalHealthReport:
      case RouteNames.mentalHealthInsights:
      case RouteNames.insights:
        return const MindAidLaunchContext(
          source: 'insights',
          openingPrompt: 'Help me understand my wellness patterns.',
        );
      case RouteNames.mindfulBreathing:
        return const MindAidLaunchContext(
          source: 'breathing',
          openingPrompt: 'Help me choose a calming exercise.',
        );
      case RouteNames.services:
        return const MindAidLaunchContext(
          source: 'counseling',
          openingPrompt: 'Help me decide what support service fits my concern.',
          appointmentConcern: 'I would like counseling support.',
        );
      case RouteNames.appointmentCalendar:
        return const MindAidLaunchContext(
          source: 'appointments',
          openingPrompt: 'Help me prepare for a counseling appointment.',
        );
      default:
        return const MindAidLaunchContext(
          source: 'home',
          openingPrompt: 'How can MindAid support me today?',
        );
    }
  }
}
