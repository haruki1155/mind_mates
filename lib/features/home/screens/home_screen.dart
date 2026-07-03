import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/assessment_provider.dart';
import '../../../providers/mood_provider.dart';
import '../../../providers/report_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../routes/route_names.dart';
import '../../quick_assessment/models/quick_assessment_models.dart';
import '../models/home_dashboard_data.dart';
import '../widgets/home_dashboard_widgets.dart';

enum _HomeNavDestination { today, secretChat, insight, messages, profile }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.data});

  final HomeDashboardData? data;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double _navVisibilityThreshold = 24;

  final ScrollController _scrollController = ScrollController();

  bool _showBottomNav = true;
  _HomeNavDestination _activeDestination = _HomeNavDestination.today;
  String? _loadedBackendUserId;

  HomeDashboardData get _data => widget.data ?? HomeDashboardData.mock();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<UserProvider>().user;
    final userId = user?.id;
    if (userId == null || userId.isEmpty || _loadedBackendUserId == userId) {
      return;
    }

    _loadedBackendUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _readProviderOrNull<MoodProvider>(context)?.loadRecentMoods(userId);
      final reportProvider = _readProviderOrNull<ReportProvider>(context);
      if (reportProvider == null) return;
      reportProvider.loadLatestReport(userId).then((_) {
        if (!mounted) return;
        reportProvider.ensureWeeklyPlaceholder(userId);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _dashboardDataFromProviders(context);
    final assessmentProvider = context.watch<AssessmentProvider>();
    final user = _userFor(data, assessmentProvider);

    return Scaffold(
      backgroundColor: HomePalette.background,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: HomeCalendarHeader(
                    title: data.headerTitle,
                    days: data.days,
                    onProfileTap: _openProfile,
                    onCalendarTap: () => _openPlaceholder('Calendar'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                  sliver: SliverList.list(
                    children: [
                      HomeAnimatedSection(
                        delay: 0,
                        child: HomeAssessmentBanner(
                          data: data.assessment,
                          onStart: _openStudentAssessment,
                          onClose: () {},
                        ),
                      ),
                      const SizedBox(height: 16),
                      HomeAnimatedSection(
                        delay: 70,
                        child: HomeWelcomeCard(
                          user: user,
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
                          onStart: () =>
                              _openPlaceholder('Mental Health Check'),
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _HomeBottomNav(
              isVisible: _showBottomNav,
              activeDestination: _activeDestination,
              onDestinationSelected: _handleNavDestination,
            ),
          ),
        ],
      ),
    );
  }

  HomeDashboardData _dashboardDataFromProviders(BuildContext context) {
    final base = _data;
    final user = context.watch<UserProvider>().user;
    final latestReport = _watchProviderOrNull<ReportProvider>(
      context,
    )?.latestReport;
    final moods =
        _watchProviderOrNull<MoodProvider>(context)?.moods ?? const [];

    final backendActivityDates =
        user?.activeDateKeys
            .map(_dateFromActivityKey)
            .whereType<DateTime>()
            .toList(growable: false) ??
        const <DateTime>[];
    final activityDates = backendActivityDates.isNotEmpty
        ? backendActivityDates
        : moods.map((mood) => mood.createdAt).toList();
    final displayName = user?.displayName.trim();
    final role = user?.roleLabel;

    return base.copyWith(
      user: HomeUserData(
        displayName: (displayName == null || displayName.isEmpty)
            ? base.user.displayName
            : displayName,
        role: role ?? base.user.role,
      ),
      streak: user == null
          ? base.streak
          : HomeStreakData(
              title: 'Day streak',
              days: user.dayStreak,
              description: user.dayStreak == 0
                  ? 'Start with one check-in today'
                  : 'Keep your wellness rhythm going',
              linkLabel: 'View',
              lastActiveAt: user.lastActiveAt,
            ),
      days: activityDates.isEmpty
          ? base.days
          : HomeDashboardData.weekAround(
              DateTime.now(),
              activityDates: activityDates,
            ),
      mentalHealthCheck: latestReport == null
          ? base.mentalHealthCheck
          : HomeMentalHealthCheckData(
              title: latestReport.title,
              description: latestReport.description,
              durationLabel: latestReport.hasEnoughData
                  ? 'Updated this week'
                  : 'Ready for your data',
              actionLabel: 'View Summary',
            ),
    );
  }

  DateTime? _dateFromActivityKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  T? _readProviderOrNull<T>(BuildContext context) {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  T? _watchProviderOrNull<T>(BuildContext context) {
    try {
      return context.watch<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  HomeUserData _userFor(
    HomeDashboardData data,
    AssessmentProvider assessmentProvider,
  ) {
    final assessmentName = assessmentProvider.name.trim();
    final assessmentRole = assessmentProvider.selectedRole;

    return HomeUserData(
      displayName: assessmentName.isNotEmpty
          ? assessmentName
          : data.user.displayName.trim(),
      role: assessmentRole?.label ?? data.user.role,
    );
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final isAtTop = _scrollController.offset <= _navVisibilityThreshold;
    if (isAtTop == _showBottomNav &&
        (!isAtTop || _activeDestination == _HomeNavDestination.today)) {
      return;
    }

    setState(() {
      _showBottomNav = isAtTop;
      if (isAtTop) {
        _activeDestination = _HomeNavDestination.today;
      }
    });
  }

  void _handleNavDestination(_HomeNavDestination destination) {
    switch (destination) {
      case _HomeNavDestination.today:
        _scrollToTop();
      case _HomeNavDestination.secretChat:
        Navigator.of(context).pushNamed(RouteNames.secretChat);
      case _HomeNavDestination.insight:
        Navigator.of(context).pushNamed(RouteNames.mentalHealthInsights);
      case _HomeNavDestination.messages:
        Navigator.of(context).pushNamed(RouteNames.mindAid);
      case _HomeNavDestination.profile:
        _openProfile();
    }
  }

  void _scrollToTop() {
    setState(() {
      _activeDestination = _HomeNavDestination.today;
      _showBottomNav = true;
    });

    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _openProfile() {
    Navigator.of(context).pushNamed(RouteNames.profile);
  }

  void _openServices() {
    Navigator.of(context).pushNamed(RouteNames.services);
  }

  Future<void> _openStudentAssessment() async {
    final shouldStart = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: HomePalette.sun, width: 1.2),
          ),
          title: const Text(
            'Start Assessment?',
            style: TextStyle(
              color: HomePalette.text,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'This will open your role-based assessment questions. You can skip questions while answering.',
            style: TextStyle(
              color: HomePalette.blueText,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: HomePalette.orange,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: HomePalette.sun,
                foregroundColor: HomePalette.text,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: const Text('Start'),
            ),
          ],
        );
      },
    );

    if (shouldStart != true || !mounted) return;

    final assessmentProvider = context.read<AssessmentProvider>();
    final savedRole = context.read<UserProvider>().user?.role;
    final role =
        assessmentProvider.selectedRole ??
        AssessmentRole.fromStoredValue(savedRole) ??
        AssessmentRole.student;

    if (assessmentProvider.selectedRole != role) {
      assessmentProvider.selectRole(role);
    }

    Navigator.of(context).pushNamed(RouteNames.studentAssessment);
  }

  void _openResource(HomeResourceData resource) {
    if (resource.title == 'Talk to AI companion') {
      Navigator.of(context).pushNamed(RouteNames.mindAid);
      return;
    }

    if (resource.title == 'View your insights') {
      Navigator.of(context).pushNamed(RouteNames.mentalHealthInsights);
      return;
    }

    _openPlaceholder(resource.title);
  }

  void _openPlaceholder(String title) {
    if (title == 'Mindful breathing') {
      Navigator.of(context).pushNamed(RouteNames.mindfulBreathing);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BlankHomeFeaturePage(title: title)),
    );
  }
}

class _HomeBottomNav extends StatelessWidget {
  const _HomeBottomNav({
    this.isVisible = true,
    required this.activeDestination,
    required this.onDestinationSelected,
  });

  final bool? isVisible;
  final _HomeNavDestination? activeDestination;
  final ValueChanged<_HomeNavDestination>? onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final visible = isVisible ?? true;
    final active = activeDestination ?? _HomeNavDestination.today;

    return SafeArea(
      top: false,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: IgnorePointer(
            ignoring: !visible,
            child: Container(
              height: 70,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 14,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _HomeBottomNavItem(
                    icon: Icons.calendar_today,
                    label: 'Today',
                    isActive: active == _HomeNavDestination.today,
                    onTap: () =>
                        onDestinationSelected?.call(_HomeNavDestination.today),
                  ),
                  _HomeBottomNavItem(
                    icon: Icons.forum_outlined,
                    label: 'Secret chat',
                    isActive: active == _HomeNavDestination.secretChat,
                    onTap: () => onDestinationSelected?.call(
                      _HomeNavDestination.secretChat,
                    ),
                  ),
                  _HomeBottomNavItem(
                    icon: Icons.show_chart,
                    label: 'Insight',
                    isActive: active == _HomeNavDestination.insight,
                    onTap: () => onDestinationSelected?.call(
                      _HomeNavDestination.insight,
                    ),
                  ),
                  _HomeBottomNavItem(
                    icon: Icons.chat_bubble_outline,
                    label: 'Messages',
                    isActive: active == _HomeNavDestination.messages,
                    onTap: () => onDestinationSelected?.call(
                      _HomeNavDestination.messages,
                    ),
                  ),
                  _HomeBottomNavItem(
                    icon: Icons.person,
                    label: 'Profile',
                    isActive: active == _HomeNavDestination.profile,
                    onTap: () => onDestinationSelected?.call(
                      _HomeNavDestination.profile,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBottomNavItem extends StatelessWidget {
  const _HomeBottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              width: isActive ? 34 : 28,
              height: isActive ? 34 : 28,
              decoration: BoxDecoration(
                color: isActive ? HomePalette.sun : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 20, color: HomePalette.text),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: HomePalette.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
