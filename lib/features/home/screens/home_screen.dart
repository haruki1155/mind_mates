import 'package:flutter/material.dart';

import '../../../routes/route_names.dart';
import '../models/home_dashboard_data.dart';
import '../widgets/home_dashboard_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.data});

  final HomeDashboardData? data;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedDayIndex = 1;

  HomeDashboardData get _data => widget.data ?? HomeDashboardData.mock();

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      backgroundColor: HomePalette.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: HomeCalendarHeader(
                title: data.headerTitle,
                days: data.days,
                selectedDayIndex: _selectedDayIndex.clamp(
                  0,
                  data.days.length - 1,
                ),
                onDaySelected: (index) {
                  setState(() => _selectedDayIndex = index);
                },
                onProfileTap: _openProfile,
                onCalendarTap: () => _openPlaceholder('Calendar'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList.list(
                children: [
                  HomeAnimatedSection(
                    delay: 0,
                    child: HomeAssessmentBanner(
                      data: data.assessment,
                      onStart: () => _openPlaceholder('Stress Assessment'),
                      onClose: () {},
                    ),
                  ),
                  const SizedBox(height: 16),
                  HomeAnimatedSection(
                    delay: 70,
                    child: HomeWelcomeCard(
                      user: data.user,
                      streak: data.streak,
                      onNotificationTap: () =>
                          _openPlaceholder('Notifications'),
                      onStreakTap: () => _openPlaceholder('Streak Details'),
                      onMoodTap: () => _openPlaceholder('Log Mood'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  HomeAnimatedSection(
                    delay: 120,
                    child: HomePaccServicesSection(
                      services: data.services,
                      onOpen: _openPlaceholder,
                      onViewAll: _openServices,
                    ),
                  ),
                  const SizedBox(height: 24),
                  HomeAnimatedSection(
                    delay: 170,
                    child: HomeDailyInsightsSection(
                      insights: data.insights,
                      affirmation: data.affirmation,
                      onOpen: _openPlaceholder,
                    ),
                  ),
                  const SizedBox(height: 24),
                  HomeAnimatedSection(
                    delay: 220,
                    child: HomeMentalHealthCheckCard(
                      data: data.mentalHealthCheck,
                      onStart: () => _openPlaceholder('Mental Health Check'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  HomeAnimatedSection(
                    delay: 270,
                    child: HomeResourcesSection(
                      resources: data.resources,
                      onOpen: _openResource,
                      onSeeAll: () => _openPlaceholder('All Resources'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  HomeAnimatedSection(
                    delay: 320,
                    child: HomeToolkitSection(
                      items: data.toolkitItems,
                      onOpen: _openPlaceholder,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openProfile() {
    Navigator.of(context).pushNamed(RouteNames.profile);
  }

  void _openServices() {
    Navigator.of(context).pushNamed(RouteNames.services);
  }

  void _openResource(HomeResourceData resource) {
    if (resource.title == 'Talk to AI companion') {
      Navigator.of(context).pushNamed(RouteNames.mindAid);
      return;
    }

    _openPlaceholder(resource.title);
  }

  void _openPlaceholder(String title) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BlankHomeFeaturePage(title: title)),
    );
  }
}
