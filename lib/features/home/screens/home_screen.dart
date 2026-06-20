import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routes/route_names.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedDayIndex = 1;

  static const List<_DashboardDay> _weekDays = [
    _DashboardDay(label: 'S', date: '19'),
    _DashboardDay(label: 'M', date: '20'),
    _DashboardDay(label: 'T', date: '21'),
    _DashboardDay(label: 'W', date: '22'),
    _DashboardDay(label: 'Th', date: '23'),
    _DashboardDay(label: 'F', date: '24'),
    _DashboardDay(label: 'Sat', date: '25'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HomeColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _CalendarHeader(
                selectedDayIndex: _selectedDayIndex,
                weekDays: _weekDays,
                onDaySelected: (index) {
                  setState(() => _selectedDayIndex = index);
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList.list(
                children: [
                  _AnimatedDashboardSection(
                    delay: 0,
                    child: _AssessmentBanner(
                      onStart: () =>
                          _openBlankPage(context, 'Stress Assessment'),
                      onClose: () {},
                    ),
                  ),
                  const SizedBox(height: 16),
                  _AnimatedDashboardSection(
                    delay: 80,
                    child: _WelcomeCard(
                      onNotificationTap: () =>
                          _openBlankPage(context, 'Notifications'),
                      onStreakTap: () =>
                          _openBlankPage(context, 'Streak Details'),
                      onMoodTap: () => _openBlankPage(context, 'Log Mood'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _AnimatedDashboardSection(
                    delay: 140,
                    child: _PaccServicesSection(
                      onOpen: (title) => _openBlankPage(context, title),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _AnimatedDashboardSection(
                    delay: 200,
                    child: _DailyInsightsSection(
                      onOpen: (title) => _openBlankPage(context, title),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _AnimatedDashboardSection(
                    delay: 260,
                    child: _MentalHealthCheckCard(
                      onStart: () =>
                          _openBlankPage(context, 'Mental Health Check'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _AnimatedDashboardSection(
                    delay: 320,
                    child: _ResourcesSection(
                      onOpen: (title) => _openBlankPage(context, title),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _AnimatedDashboardSection(
                    delay: 380,
                    child: _ToolkitSection(
                      onOpen: (title) => _openBlankPage(context, title),
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

  void _openBlankPage(BuildContext context, String title) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _BlankFeaturePage(title: title)));
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.selectedDayIndex,
    required this.weekDays,
    required this.onDaySelected,
  });

  final int selectedDayIndex;
  final List<_DashboardDay> weekDays;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: _HomeColors.sun,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _CircleIconButton(
                icon: Icons.person_outline,
                tooltip: 'Profile',
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.profile),
              ),
              const Expanded(
                child: Text(
                  'April 20',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _CircleIconButton(
                icon: Icons.calendar_today_outlined,
                tooltip: 'Calendar',
                onTap: () => _pushFromHeader(context, 'Calendar'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(weekDays.length, (index) {
              final day = weekDays[index];
              return _DaySelector(
                day: day,
                isSelected: selectedDayIndex == index,
                onTap: () => onDaySelected(index),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _pushFromHeader(BuildContext context, String title) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _BlankFeaturePage(title: title)));
  }
}

class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.day,
    required this.isSelected,
    required this.onTap,
  });

  final _DashboardDay day;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? _HomeColors.gold : Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              day.label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              day.date,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssessmentBanner extends StatelessWidget {
  const _AssessmentBanner({required this.onStart, required this.onClose});

  final VoidCallback onStart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE4EAFF),
        border: Border.all(color: const Color(0xFF5C7CFF)),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x245C7CFF),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(
              Icons.error_outline,
              color: Color(0xFF6D7484),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Time for Your Stress Assessment',
                  style: _HomeText.titleSmall,
                ),
                const SizedBox(height: 3),
                const Text(
                  'Take your first stress assessment to establish a baseline.',
                  style: _HomeText.bodySmall,
                ),
                const SizedBox(height: 10),
                _PrimaryPillButton(
                  label: 'Start Assessment',
                  icon: Icons.arrow_forward,
                  onTap: onStart,
                ),
              ],
            ),
          ),
          _PlainIconButton(
            icon: Icons.close,
            tooltip: 'Dismiss',
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.onNotificationTap,
    required this.onStreakTap,
    required this.onMoodTap,
  });

  final VoidCallback onNotificationTap;
  final VoidCallback onStreakTap;
  final VoidCallback onMoodTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _HomeDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, Leo!',
                      style: TextStyle(
                        color: _HomeColors.orange,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Student - Urdaneta City University',
                      style: _HomeText.caption,
                    ),
                  ],
                ),
              ),
              _CircleIconButton(
                icon: Icons.notifications_none,
                tooltip: 'Notifications',
                onTap: onNotificationTap,
                size: 36,
                iconSize: 20,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'How are you feeling today?',
            style: TextStyle(
              color: _HomeColors.mutedGold,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _StreakCard(onTap: onStreakTap),
          const SizedBox(height: 14),
          _WideActionButton(
            label: 'Log your mood',
            icon: Icons.add,
            onTap: onMoodTap,
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_HomeColors.softGold, _HomeColors.sun],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Streak', style: _HomeText.titleSmall),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      _DashboardAssetImage(
                        assetName: 'Breath.png',
                        width: 42,
                        height: 42,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '20',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 36,
                          height: .9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(width: 5),
                      Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text('days', style: _HomeText.bodySmallDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "You're doing great! Keep logging daily.",
                    style: _HomeText.bodySmallDark,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Learn about building consistency ->',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.workspace_premium_outlined,
              size: 50,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaccServicesSection extends StatelessWidget {
  const _PaccServicesSection({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final services = <_ServiceTileData>[
      const _ServiceTileData(
        title: 'Testing Services',
        subtitle: 'Psychological assessment',
        icon: Icons.psychology_alt_outlined,
        colors: [Color(0xFFB8C8FF), Color(0xFF94A6DB)],
      ),
      const _ServiceTileData(
        title: 'Counseling Services',
        subtitle: 'Appoint Now',
        icon: Icons.groups_2_outlined,
        colors: [Color(0xFFF2A5D9), Color(0xFF7B3E78)],
      ),
      const _ServiceTileData(
        title: 'Individual Inventory',
        subtitle: 'Your profile & data',
        icon: Icons.assignment_outlined,
        colors: [Color(0xFFFF9987), Color(0xFFFF624C)],
      ),
      const _ServiceTileData(
        title: 'Information Services',
        subtitle: 'Mental health resources',
        icon: Icons.menu_book_outlined,
        colors: [Color(0xFF72E4B8), Color(0xFF008A61)],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'PACC Services',
          actionLabel: 'Learn more',
          onAction: () => onOpen('PACC Services'),
        ),
        const SizedBox(height: 4),
        const Text(
          'Psychological Assessment & Counseling Center',
          style: _HomeText.body,
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: services.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
          ),
          itemBuilder: (context, index) {
            final service = services[index];
            return _ServiceTile(
              data: service,
              onTap: () => onOpen(service.title),
            );
          },
        ),
        const SizedBox(height: 16),
        _OutlinedWideButton(
          label: 'View all 7 PACC services',
          onTap: () => Navigator.of(context).pushNamed(RouteNames.services),
        ),
      ],
    );
  }
}

class _DailyInsightsSection extends StatelessWidget {
  const _DailyInsightsSection({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('My daily insights - Today', style: _HomeText.sectionTitle),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _InsightActionCard(
                title: 'Log your mood',
                icon: Icons.add,
                onTap: () => onOpen('Log Mood'),
              ),
              const SizedBox(width: 12),
              _PhotoInsightCard(
                title: 'Time for a wellness check?',
                subtitle: 'Check your mood',
                imageName: 'Rectangle 254.png',
                onTap: () => onOpen('Wellness Check'),
              ),
              const SizedBox(width: 12),
              _PhotoInsightCard(
                title: 'Mindful breathing',
                subtitle: '5 min session',
                imageName: 'Rectangle 255.png',
                onTap: () => onOpen('Mindful Breathing'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _AffirmationCard(onTap: () => onOpen('Today Affirmation')),
      ],
    );
  }
}

class _MentalHealthCheckCard extends StatelessWidget {
  const _MentalHealthCheckCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Mental Health Check',
          actionLabel: 'Start ->',
          onAction: onStart,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _HomeColors.sun),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33FFC107),
                blurRadius: 14,
                offset: Offset(-6, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DashboardAssetImage(
                assetName: 'How are you today.png',
                width: 42,
                height: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'How are you today',
                      style: _HomeText.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Take our comprehensive mental health check to get personalized insights and recommendations.',
                      style: _HomeText.body,
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 16,
                          color: _HomeColors.textMuted,
                        ),
                        SizedBox(width: 6),
                        Text('Takes ~5 minutes', style: _HomeText.captionDark),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.center,
                      child: _PrimaryPillButton(
                        label: 'Take Assessment',
                        onTap: onStart,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResourcesSection extends StatelessWidget {
  const _ResourcesSection({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final items = <_ResourceItemData>[
      const _ResourceItemData(
        title: 'Talk to AI companion',
        subtitle: 'Get instant support anytime',
        icon: Icons.support_agent_outlined,
        color: Color(0xFFD9AF6A),
      ),
      const _ResourceItemData(
        title: 'View your insights',
        subtitle: 'Understand your emotional patterns',
        icon: Icons.insights_outlined,
        color: Color(0xFFD7AFC1),
        borderColor: Color(0xFFFF2FA2),
      ),
      const _ResourceItemData(
        title: 'Mental Wellbeing 101',
        subtitle: 'Essential mental health knowledge',
        icon: Icons.school_outlined,
        color: Color(0xFFFF9C97),
        borderColor: Color(0xFFFF4C4C),
      ),
      const _ResourceItemData(
        title: 'Latest News & Research',
        subtitle: 'Updates and mental health insights',
        icon: Icons.science_outlined,
        color: Color(0xFFD0C6C8),
      ),
      const _ResourceItemData(
        title: 'Recommended for You',
        subtitle: 'Personalized mental health resources',
        icon: Icons.thumb_up_alt_outlined,
        color: Color(0xFFB4C6FF),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Mental Health Resources',
          actionLabel: 'See All ->',
          onAction: () => onOpen('All Resources'),
        ),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ResourceTile(data: item, onTap: () => onOpen(item.title)),
          ),
        ),
      ],
    );
  }
}

class _ToolkitSection extends StatelessWidget {
  const _ToolkitSection({required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final tools = <_ToolkitItemData>[
      const _ToolkitItemData(
        title: 'Breathing exercise',
        subtitle: '5 min guided session',
        imageName: 'Breathing exercise 5 min guided session.png',
        colors: [Color(0xFF6483F4), Color(0xFF5570C8)],
      ),
      const _ToolkitItemData(
        title: 'Facial Recognition',
        subtitle: 'Capturing your emotion',
        imageName: 'Facial Recognition.png',
        colors: [Color(0xFFFFB2D7), Color(0xFF8A3E82)],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your wellness toolkit', style: _HomeText.sectionTitle),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tools.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
          ),
          itemBuilder: (context, index) {
            final tool = tools[index];
            return _ToolkitTile(data: tool, onTap: () => onOpen(tool.title));
          },
        ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.data, required this.onTap});

  final _ServiceTileData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: data.colors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(data.icon, color: Colors.white, size: 30),
            const SizedBox(height: 8),
            Text(data.title, style: _HomeText.tileTitle),
            Text(data.subtitle, style: _HomeText.tileSubtitle),
          ],
        ),
      ),
    );
  }
}

class _InsightActionCard extends StatelessWidget {
  const _InsightActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _HomeColors.sun, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: _HomeColors.sun,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.black, size: 34),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: _HomeText.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoInsightCard extends StatelessWidget {
  const _PhotoInsightCard({
    required this.title,
    required this.subtitle,
    required this.imageName,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String imageName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 180,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _DashboardAssetImage(assetName: imageName, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xB3000000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _HomeText.photoTitle),
                    Text(subtitle, style: _HomeText.photoSubtitle),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AffirmationCard extends StatelessWidget {
  const _AffirmationCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFE6E7EC),
          border: Border.all(color: const Color(0xFFB9BED2)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.thumb_up_alt_outlined, color: Color(0xFF1CA3C7)),
                SizedBox(width: 8),
                Text("Today's affirmation", style: _HomeText.titleSmall),
              ],
            ),
            SizedBox(height: 20),
            Center(
              child: Text(
                '"My mental health is a priority"...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({required this.data, required this.onTap});

  final _ResourceItemData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: data.color,
          border: Border.all(
            color: data.borderColor ?? const Color(0x33000000),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0x22FFFFFF),
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(data.title, style: _HomeText.resourceTitle),
                  const SizedBox(height: 2),
                  Text(data.subtitle, style: _HomeText.resourceSubtitle),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black, size: 28),
          ],
        ),
      ),
    );
  }
}

class _ToolkitTile extends StatelessWidget {
  const _ToolkitTile({required this.data, required this.onTap});

  final _ToolkitItemData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: data.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _DashboardAssetImage(
              assetName: data.imageName,
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8),
            Text(data.title, style: _HomeText.tileTitle),
            Text(data.subtitle, style: _HomeText.tileSubtitle),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: _HomeText.sectionTitle)),
        if (actionLabel != null)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _HomeColors.orange,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

class _PrimaryPillButton extends StatelessWidget {
  const _PrimaryPillButton({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _HomeColors.sun,
      borderRadius: BorderRadius.circular(22),
      elevation: 4,
      shadowColor: const Color(0x3D000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(icon, color: Colors.white, size: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WideActionButton extends StatelessWidget {
  const _WideActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: _HomeColors.sun,
        borderRadius: BorderRadius.circular(24),
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.black, size: 28),
                const SizedBox(width: 8),
                Text(label, style: _HomeText.buttonDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedWideButton extends StatelessWidget {
  const _OutlinedWideButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: _HomeColors.sun, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: _HomeText.buttonDark),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 44,
    this.iconSize = 22,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: const Color(0x33000000),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: iconSize, color: Colors.black),
          ),
        ),
      ),
    );
  }
}

class _PlainIconButton extends StatelessWidget {
  const _PlainIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: Colors.black),
        ),
      ),
    );
  }
}

class _DashboardAssetImage extends StatelessWidget {
  const _DashboardAssetImage({
    required this.assetName,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String assetName;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '${AppAssets.dashboardImages}/$assetName',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) {
        return SizedBox(
          width: width,
          height: height,
          child: const Icon(Icons.image_not_supported_outlined),
        );
      },
    );
  }
}

class _AnimatedDashboardSection extends StatelessWidget {
  const _AnimatedDashboardSection({required this.child, required this.delay});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        final offset = (1 - value) * 18;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, offset),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }
}

class _BlankFeaturePage extends StatelessWidget {
  const _BlankFeaturePage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _HomeColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _HomeColors.sun,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: const SizedBox.expand(),
    );
  }
}

class _DashboardDay {
  const _DashboardDay({required this.label, required this.date});

  final String label;
  final String date;
}

class _ServiceTileData {
  const _ServiceTileData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
}

class _ResourceItemData {
  const _ResourceItemData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.borderColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color? borderColor;
}

class _ToolkitItemData {
  const _ToolkitItemData({
    required this.title,
    required this.subtitle,
    required this.imageName,
    required this.colors,
  });

  final String title;
  final String subtitle;
  final String imageName;
  final List<Color> colors;
}

class _HomeColors {
  const _HomeColors._();

  static const background = Color(0xFFF7F1DF);
  static const sun = Color(0xFFFFC414);
  static const softGold = Color(0xFFFFD75C);
  static const gold = Color(0xFFE9B000);
  static const orange = Color(0xFFFFA000);
  static const mutedGold = Color(0xFFB8922F);
  static const textMuted = Color(0xFF6C665B);
}

class _HomeText {
  const _HomeText._();

  static const sectionTitle = TextStyle(
    color: Color(0xFF3B312B),
    fontSize: 17,
    fontWeight: FontWeight.w900,
  );

  static const titleSmall = TextStyle(
    color: Colors.black,
    fontSize: 13,
    fontWeight: FontWeight.w900,
  );

  static const body = TextStyle(
    color: Colors.black,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const bodySmall = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w500,
  );

  static const bodySmallDark = TextStyle(
    color: Colors.black,
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w500,
  );

  static const caption = TextStyle(
    color: _HomeColors.textMuted,
    fontSize: 10,
    fontWeight: FontWeight.w700,
  );

  static const captionDark = TextStyle(
    color: Colors.black,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  static const buttonDark = TextStyle(
    color: Colors.black,
    fontSize: 13,
    fontWeight: FontWeight.w900,
  );

  static const tileTitle = TextStyle(
    color: Colors.black,
    fontSize: 12,
    fontWeight: FontWeight.w900,
  );

  static const tileSubtitle = TextStyle(
    color: Colors.black,
    fontSize: 10,
    height: 1.15,
    fontWeight: FontWeight.w500,
  );

  static const photoTitle = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w900,
  );

  static const photoSubtitle = TextStyle(
    color: Colors.white,
    fontSize: 10,
    fontWeight: FontWeight.w500,
  );

  static const resourceTitle = TextStyle(
    color: Colors.black,
    fontSize: 14,
    fontWeight: FontWeight.w900,
  );

  static const resourceSubtitle = TextStyle(
    color: Colors.black,
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w500,
  );
}

class _HomeDecor {
  const _HomeDecor._();

  static BoxDecoration card() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 12,
          offset: Offset(0, 6),
        ),
      ],
    );
  }
}
