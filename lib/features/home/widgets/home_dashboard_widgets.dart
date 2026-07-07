import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../models/home_dashboard_data.dart';

class HomePalette {
  const HomePalette._();

  static const background = Color(0xFFF7F1DF);
  static const sun = Color(0xFFFFC414);
  static const softGold = Color(0xFFFFD75C);
  static const gold = Color(0xFFE9B000);
  static const orange = Color(0xFFFFA000);
  static const mutedGold = Color(0xFFB8922F);
  static const text = Color(0xFF17120A);
  static const muted = Color(0xFF6C665B);
  static const blueText = Color(0xFF66736F);
}

class HomeTextStyles {
  const HomeTextStyles._();

  static const sectionTitle = TextStyle(
    color: Color(0xFF3B312B),
    fontSize: 17,
    fontWeight: FontWeight.w900,
  );

  static const cardTitle = TextStyle(
    color: HomePalette.text,
    fontSize: 13,
    height: 1.18,
    fontWeight: FontWeight.w900,
  );

  static const body = TextStyle(
    color: HomePalette.text,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const bodyMuted = TextStyle(
    color: HomePalette.blueText,
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w500,
  );

  static const caption = TextStyle(
    color: HomePalette.muted,
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  static const button = TextStyle(
    color: HomePalette.text,
    fontSize: 13,
    fontWeight: FontWeight.w900,
  );
}

class HomeDecor {
  const HomeDecor._();

  static BoxDecoration card({
    Color color = Colors.white,
    Color shadowColor = const Color(0x14000000),
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color,
      border: borderColor == null ? null : Border.all(color: borderColor),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: shadowColor,
          blurRadius: 14,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }
}

class HomeCalendarHeader extends StatelessWidget {
  const HomeCalendarHeader({
    super.key,
    required this.title,
    required this.days,
    required this.onProfileTap,
    required this.onCalendarTap,
  });

  final String title;
  final List<HomeDayData> days;
  final VoidCallback onProfileTap;
  final VoidCallback onCalendarTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
      decoration: const BoxDecoration(
        color: HomePalette.sun,
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
              HomeCircleIconButton(
                icon: Icons.person_outline,
                tooltip: 'Profile',
                onTap: onProfileTap,
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomePalette.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              HomeCircleIconButton(
                icon: Icons.calendar_today_outlined,
                tooltip: 'Calendar',
                onTap: onCalendarTap,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(days.length, (index) {
              return Expanded(
                child: Center(child: _DayChip(day: days[index])),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day});

  final HomeDayData day;

  @override
  Widget build(BuildContext context) {
    final isFuture = !day.isPast && !day.isToday;
    final backgroundColor = day.isToday
        ? HomePalette.gold
        : day.hasActivity && day.isPast
        ? const Color(0xFFFFE8A3)
        : isFuture
        ? const Color(0xFFF2EEE4)
        : Colors.white;
    final textColor = isFuture ? HomePalette.muted : HomePalette.text;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: day.hasActivity && day.isPast
            ? Border.all(color: HomePalette.gold, width: 1.5)
            : null,
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day.label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                day.date,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeAssessmentBanner extends StatelessWidget {
  const HomeAssessmentBanner({
    super.key,
    required this.data,
    required this.onStart,
    required this.onClose,
  });

  final HomeAssessmentPromptData data;
  final VoidCallback onStart;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: HomeDecor.card(
        color: const Color(0xFFE4EAFF),
        borderColor: const Color(0xFF5C7CFF),
        shadowColor: const Color(0x245C7CFF),
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
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HomeTextStyles.cardTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  data.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: HomeTextStyles.bodyMuted,
                ),
                const SizedBox(height: 10),
                HomePillButton(
                  label: data.actionLabel,
                  icon: Icons.arrow_forward,
                  onTap: onStart,
                ),
              ],
            ),
          ),
          HomePlainIconButton(
            icon: Icons.close,
            tooltip: 'Dismiss',
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class HomeWelcomeCard extends StatelessWidget {
  const HomeWelcomeCard({
    super.key,
    required this.user,
    required this.streak,
    required this.onNotificationTap,
    required this.onStreakTap,
    required this.onMoodTap,
    required this.actionLabel,
  });

  final HomeUserData user;
  final HomeStreakData? streak;
  final VoidCallback onNotificationTap;
  final VoidCallback onStreakTap;
  final VoidCallback onMoodTap;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final displayName = user.displayName.trim();
    final welcomeText = displayName.isEmpty
        ? 'Welcome back!'
        : 'Welcome back, $displayName!';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: HomeDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      welcomeText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomePalette.orange,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              HomeCircleIconButton(
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
              color: HomePalette.mutedGold,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _StreakCard(data: streak, onTap: onStreakTap),
          const SizedBox(height: 14),
          HomeWideButton(label: actionLabel, icon: Icons.add, onTap: onMoodTap),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.data, required this.onTap});

  final HomeStreakData? data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final streak = data;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [HomePalette.softGold, HomePalette.sun],
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
                    Text(
                      streak?.title ?? 'Your Streak',
                      style: HomeTextStyles.cardTitle,
                    ),
                    const SizedBox(height: 10),
                    if (streak == null)
                      const Row(
                        children: [
                          HomeDashboardAssetImage(
                            assetName: 'Breath.png',
                            width: 42,
                            height: 42,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Ready to sync',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: HomePalette.text,
                                fontSize: 24,
                                height: 1,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const HomeDashboardAssetImage(
                            assetName: 'Breath.png',
                            width: 42,
                            height: 42,
                          ),
                          Text(
                            '${streak.days}',
                            style: const TextStyle(
                              color: HomePalette.text,
                              fontSize: 36,
                              height: .9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 4),
                            child: Text('days', style: HomeTextStyles.body),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Text(
                      streak?.description ??
                          'Your streak will appear here after activity is synced.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: HomeTextStyles.body,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      streak == null
                          ? 'Backend-ready for account activity'
                          : '${streak.linkLabel} ->',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomePalette.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.workspace_premium_outlined,
                size: 46,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePaccServicesSection extends StatelessWidget {
  const HomePaccServicesSection({
    super.key,
    required this.services,
    required this.onOpen,
    required this.onViewAll,
  });

  final List<HomeServiceData> services;
  final ValueChanged<String> onOpen;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'PACC Services',
          actionLabel: 'Learn more',
          onAction: () => onOpen('PACC Services'),
        ),
        const SizedBox(height: 4),
        const Text(
          'Psychological Assessment & Counseling Center',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: HomeTextStyles.body,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 340 ? 1 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: services.length > 2 ? 2 : services.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 122,
              ),
              itemBuilder: (context, index) {
                final service = services[index];
                return _ServiceTile(
                  data: service,
                  onTap: () => onOpen(service.title),
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
        HomeOutlinedButton(
          label: 'View all ${services.length} PACC services',
          onTap: onViewAll,
        ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.data, required this.onTap});

  final HomeServiceData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
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
            children: [
              Icon(data.icon, color: Colors.white, size: 28),
              const Spacer(),
              Text(
                data.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HomePalette.text,
                  fontSize: 12,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HomePalette.text,
                  fontSize: 10,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeDailyInsightsSection extends StatelessWidget {
  const HomeDailyInsightsSection({
    super.key,
    required this.insights,
    required this.affirmation,
    required this.onOpen,
  });

  final List<HomeInsightData> insights;
  final HomeAffirmationData? affirmation;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My daily insights - Today',
          style: HomeTextStyles.sectionTitle,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 154,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: insights.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final insight = insights[index];
              if (insight.isAction) {
                return _InsightActionCard(
                  data: insight,
                  onTap: () => onOpen(insight.title),
                );
              }
              return _PhotoInsightCard(
                data: insight,
                onTap: () => onOpen(insight.title),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        _AffirmationCard(
          data: affirmation,
          onTap: () => onOpen(affirmation?.title ?? "Today's affirmation"),
        ),
      ],
    );
  }
}

class _InsightActionCard extends StatelessWidget {
  const _InsightActionCard({required this.data, required this.onTap});

  final HomeInsightData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 132,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: HomePalette.sun, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: HomePalette.sun,
                  shape: BoxShape.circle,
                ),
                child: Icon(data.icon, color: HomePalette.text, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                data.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: HomeTextStyles.cardTitle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoInsightCard extends StatelessWidget {
  const _PhotoInsightCard({required this.data, required this.onTap});

  final HomeInsightData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 184,
            child: Stack(
              fit: StackFit.expand,
              children: [
                HomeDashboardAssetImage(
                  assetName: data.imageName ?? '',
                  fit: BoxFit.cover,
                ),
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
                      Text(
                        data.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (data.subtitle != null)
                        Text(
                          data.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AffirmationCard extends StatelessWidget {
  const _AffirmationCard({required this.data, required this.onTap});

  final HomeAffirmationData? data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final affirmation = data;

    return Material(
      color: const Color(0xFFE6E7EC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFB9BED2)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.thumb_up_alt_outlined,
                    color: Color(0xFF1CA3C7),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Today's affirmation",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeTextStyles.cardTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                child: Center(
                  key: ValueKey(affirmation?.quote ?? 'pending-affirmation'),
                  child: Text(
                    affirmation?.quote ?? 'Daily affirmation will appear here.',
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: affirmation == null
                          ? HomePalette.muted
                          : HomePalette.text,
                      fontSize: 15,
                      height: 1.3,
                      fontStyle: affirmation == null
                          ? FontStyle.normal
                          : FontStyle.italic,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (affirmation?.author != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '- ${affirmation!.author}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HomeTextStyles.caption,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class HomeMentalHealthCheckCard extends StatelessWidget {
  const HomeMentalHealthCheckCard({
    super.key,
    required this.data,
    required this.onStart,
  });

  final HomeMentalHealthCheckData data;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Mental Health Check',
          actionLabel: 'Start ->',
          onAction: onStart,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: HomeDecor.card(
            borderColor: HomePalette.sun,
            shadowColor: const Color(0x33FFC107),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeDashboardAssetImage(
                assetName: 'How are you today.png',
                width: 42,
                height: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HomeTextStyles.cardTitle,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data.description,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: HomeTextStyles.body,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          size: 16,
                          color: HomePalette.muted,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            data.durationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: HomePalette.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.center,
                      child: HomePillButton(
                        label: data.actionLabel,
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

class HomeResourcesSection extends StatelessWidget {
  const HomeResourcesSection({
    super.key,
    required this.resources,
    required this.onOpen,
    required this.onSeeAll,
  });

  final List<HomeResourceData> resources;
  final ValueChanged<HomeResourceData> onOpen;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionHeader(
          title: 'Mental Health Resources',
          actionLabel: 'See All ->',
          onAction: onSeeAll,
        ),
        const SizedBox(height: 12),
        for (final item in resources) ...[
          _ResourceTile(data: item, onTap: () => onOpen(item)),
          if (item != resources.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({required this.data, required this.onTap});

  final HomeResourceData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: data.color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
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
                  color: Color(0x24FFFFFF),
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
                    Text(
                      data.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomePalette.text,
                        fontSize: 14,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomePalette.text,
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: HomePalette.text,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeToolkitSection extends StatelessWidget {
  const HomeToolkitSection({
    super.key,
    required this.items,
    required this.onOpen,
  });

  final List<HomeToolkitData> items;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your wellness toolkit', style: HomeTextStyles.sectionTitle),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 340 ? 1 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 138,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return _ToolkitTile(
                  data: item,
                  onTap: () => onOpen(item.title),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _ToolkitTile extends StatelessWidget {
  const _ToolkitTile({required this.data, required this.onTap});

  final HomeToolkitData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
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
            children: [
              HomeDashboardAssetImage(
                assetName: data.imageName,
                width: 44,
                height: 44,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              Text(
                data.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HomePalette.text,
                  fontSize: 12,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HomePalette.text,
                  fontSize: 10,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: HomeTextStyles.sectionTitle,
          ),
        ),
        if (actionLabel != null)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: HomePalette.orange,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onAction,
            child: Text(
              actionLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

class HomePillButton extends StatelessWidget {
  const HomePillButton({
    super.key,
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
      color: HomePalette.sun,
      borderRadius: BorderRadius.circular(22),
      elevation: 3,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
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

class HomeWideButton extends StatelessWidget {
  const HomeWideButton({
    super.key,
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
        color: HomePalette.sun,
        borderRadius: BorderRadius.circular(24),
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: HomePalette.text, size: 26),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HomeTextStyles.button,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeOutlinedButton extends StatelessWidget {
  const HomeOutlinedButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: HomePalette.text,
          side: const BorderSide(color: HomePalette.sun, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HomeTextStyles.button,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class HomeCircleIconButton extends StatelessWidget {
  const HomeCircleIconButton({
    super.key,
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
            child: Icon(icon, size: iconSize, color: HomePalette.text),
          ),
        ),
      ),
    );
  }
}

class HomePlainIconButton extends StatelessWidget {
  const HomePlainIconButton({
    super.key,
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
          child: Icon(icon, size: 16, color: HomePalette.text),
        ),
      ),
    );
  }
}

class HomeDashboardAssetImage extends StatelessWidget {
  const HomeDashboardAssetImage({
    super.key,
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

class HomeAnimatedSection extends StatelessWidget {
  const HomeAnimatedSection({
    super.key,
    required this.child,
    required this.delay,
  });

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }
}

class BlankHomeFeaturePage extends StatelessWidget {
  const BlankHomeFeaturePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomePalette.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: HomePalette.sun,
        foregroundColor: HomePalette.text,
        elevation: 0,
      ),
      body: const SizedBox.expand(),
    );
  }
}
