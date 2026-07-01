import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/insights/models/insights_models.dart';
import '../../../providers/insights_provider.dart';
import '../../../providers/mood_provider.dart';
import '../../../providers/report_provider.dart';

class MentalHealthInsightsScreen extends StatefulWidget {
  const MentalHealthInsightsScreen({super.key});

  @override
  State<MentalHealthInsightsScreen> createState() =>
      _MentalHealthInsightsScreenState();
}

class _MentalHealthInsightsScreenState
    extends State<MentalHealthInsightsScreen> {
  bool _requestedInsights = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedInsights) return;
    _requestedInsights = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _readProviderOrNull<InsightsProvider>(context)?.loadInsights();
    });
  }

  @override
  Widget build(BuildContext context) {
    final insightsProvider = _watchProviderOrNull<InsightsProvider>(context);
    final data = insightsProvider?.data;
    final moods =
        _watchProviderOrNull<MoodProvider>(context)?.moods ?? const [];
    final report = _watchProviderOrNull<ReportProvider>(context)?.latestReport;
    final metrics = InsightMetricsSummary.from(moods: moods, report: report);

    return Scaffold(
      backgroundColor: _InsightsPalette.background,
      body: Stack(
        children: [
          const _InsightsBackground(),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _Header(
                    onNotificationTap: () =>
                        _showSnack(context, 'Notifications are coming soon.'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 42),
                  sliver: SliverList.list(
                    children: [
                      const _HeroSearchCard(),
                      const SizedBox(height: 26),
                      _CategoryRow(categories: data?.categories ?? const []),
                      const SizedBox(height: 22),
                      _WeeklyGlanceCard(
                        metrics: metrics,
                        onLogMoodTap: () =>
                            _showSnack(context, 'Mood tracker is next.'),
                      ),
                      const SizedBox(height: 24),
                      if (insightsProvider?.isLoading ?? false)
                        const _InsightSectionSkeleton()
                      else if (data == null || data.sections.isEmpty)
                        const _EmptyInsightState()
                      else
                        for (final section in data.sections) ...[
                          _InsightSectionView(section: section),
                          const SizedBox(height: 24),
                        ],
                      _PaaccSupportCard(
                        onContactTap: () =>
                            _showSnack(context, 'Counselor contact is next.'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onNotificationTap});

  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.fromLTRB(20, 0, 18, 0),
      decoration: const BoxDecoration(
        color: _InsightsPalette.sun,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/INSIGHTS/logo.png 3.png',
            width: 31,
            height: 31,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.psychology_alt, size: 30),
          ),
          const SizedBox(width: 6),
          Image.asset(
            'assets/images/INSIGHTS/MindMate.png',
            height: 26,
            errorBuilder: (context, error, stackTrace) => const Text(
              'MindMate',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    blurRadius: 4,
                    offset: Offset(1, 2),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotificationTap,
            icon: Image.asset(
              'assets/images/INSIGHTS/Notification.png',
              width: 24,
              height: 24,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.notifications, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSearchCard extends StatelessWidget {
  const _HeroSearchCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: BoxDecoration(
        color: _InsightsPalette.sun,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: Color(0xFFFF6F8F), size: 28),
              const SizedBox(width: 9),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insights',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Your mental wellness hub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Image.asset(
                'assets/images/INSIGHTS/Pulse.png',
                width: 32,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.monitor_heart, color: Colors.black),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x28000000),
                  blurRadius: 7,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.search, size: 22, color: Color(0xFF2D6EA7)),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Search insights...',
                    style: TextStyle(
                      color: Color(0xFF8D7F5E),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.categories});

  final List<InsightCategory> categories;

  @override
  Widget build(BuildContext context) {
    final effectiveCategories = categories.isEmpty
        ? const [
            InsightCategory(
              id: 'mood_tracking',
              label: 'Mood tracking',
              icon: 'mood',
            ),
            InsightCategory(
              id: 'stress_relief',
              label: 'Stress relief',
              icon: 'stress',
            ),
            InsightCategory(
              id: 'better_sleep',
              label: 'Better sleep',
              icon: 'sleep',
              isSelected: true,
            ),
            InsightCategory(
              id: 'manage_anxiety',
              label: 'Manage anxiety',
              icon: 'anxiety',
            ),
          ]
        : categories;

    return SizedBox(
      height: 92,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final category in effectiveCategories.take(4))
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _CategoryTile(category: category),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final InsightCategory category;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      decoration: BoxDecoration(
        color: category.isSelected
            ? _InsightsPalette.gold
            : _InsightsPalette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _InsightsPalette.gold, width: 1.1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_categoryIcon(category.icon), size: 27, color: Colors.black87),
          const SizedBox(height: 6),
          Text(
            category.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(String key) {
    switch (key) {
      case 'stress':
        return Icons.self_improvement;
      case 'sleep':
        return Icons.bedtime;
      case 'anxiety':
        return Icons.cloud_outlined;
      case 'mood':
      default:
        return Icons.sentiment_satisfied_alt;
    }
  }
}

class _WeeklyGlanceCard extends StatelessWidget {
  const _WeeklyGlanceCard({required this.metrics, required this.onLogMoodTap});

  final InsightMetricsSummary metrics;
  final VoidCallback onLogMoodTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      InsightMetric(
        label: 'Check-ins',
        value: '${metrics.checkIns}',
        icon: 'fire',
      ),
      InsightMetric(
        label: 'Good days',
        value: '${metrics.goodDays}',
        icon: 'mood',
      ),
      InsightMetric(
        label: 'Total logs',
        value: '${metrics.totalLogs}',
        icon: 'chart',
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 17),
      decoration: _InsightsDecor.card(),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'This week at a glance',
                  style: _InsightsText.sectionTitle,
                ),
              ),
              TextButton(
                onPressed: onLogMoodTap,
                style: TextButton.styleFrom(
                  foregroundColor: _InsightsPalette.gold,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(72, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Log mood ->',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 21),
          Row(
            children: [
              for (final item in items)
                Expanded(child: _MetricColumn(metric: item)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({required this.metric});

  final InsightMetric metric;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(_metricIcon(metric.icon), size: 28, color: _InsightsPalette.gold),
        const SizedBox(height: 8),
        Text(metric.value, style: _InsightsText.metricValue),
        Text(
          metric.label,
          textAlign: TextAlign.center,
          style: _InsightsText.metricLabel,
        ),
      ],
    );
  }

  IconData _metricIcon(String key) {
    switch (key) {
      case 'fire':
        return Icons.local_fire_department;
      case 'chart':
        return Icons.bar_chart;
      case 'mood':
      default:
        return Icons.sentiment_satisfied_alt;
    }
  }
}

class _InsightSectionView extends StatelessWidget {
  const _InsightSectionView({required this.section});

  final InsightSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(section.title, style: _InsightsText.sectionTitle),
            ),
            if (section.showSeeAll)
              const Text(
                'See all ->',
                style: TextStyle(
                  color: _InsightsPalette.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: section.id == 'patterns' ? 138 : 126,
          child: section.items.isEmpty
              ? const _InlineEmptyState()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: section.items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    return _InsightCard(
                      item: section.items[index],
                      isPatternCard: section.id == 'patterns',
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.item, required this.isPatternCard});

  final InsightCardItem item;
  final bool isPatternCard;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 203,
      child: Container(
        decoration: BoxDecoration(
          color: isPatternCard
              ? const Color(0xFFFFDA66)
              : const Color(0xFFFFD466),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _InsightsPalette.gold, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (!isPatternCard && item.imageAsset.isNotEmpty)
              Image.asset(
                item.imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            if (!isPatternCard)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x22FFFFFF), Color(0xAA000000)],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryPill(label: item.category),
                  const Spacer(),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPatternCard ? Colors.black : Colors.white,
                      fontSize: 13,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPatternCard
                          ? const Color(0xFF2B2619)
                          : Colors.white,
                      fontSize: 10,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
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
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_pillIcon(label), size: 13, color: Colors.black87),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  IconData _pillIcon(String label) {
    switch (label.toLowerCase()) {
      case 'your data':
        return Icons.bar_chart;
      case 'trending':
        return Icons.trending_up;
      case 'academic':
        return Icons.school;
      case 'self-care':
        return Icons.edit;
      case 'social':
        return Icons.groups_2;
      case 'sleep':
        return Icons.bedtime;
      case 'wellbeing':
        return Icons.favorite_border;
      case 'mindfulness':
        return Icons.self_improvement;
      default:
        return Icons.auto_awesome;
    }
  }
}

class _PaaccSupportCard extends StatelessWidget {
  const _PaaccSupportCard({required this.onContactTap});

  final VoidCallback onContactTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PAACC support services', style: _InsightsText.sectionTitle),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _InsightsPalette.gold),
          ),
          child: Column(
            children: [
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.favorite, color: _InsightsPalette.gold, size: 31),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Need to talk to someone?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  "PAACC counseling services are available 24/7 for students and faculty. You're never alone.",
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 190,
                height: 38,
                child: ElevatedButton(
                  onPressed: onContactTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _InsightsPalette.gold,
                    foregroundColor: Colors.white,
                    elevation: 5,
                    shadowColor: const Color(0x66000000),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Contact counselor',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: _InsightsDecor.card(radius: 12),
      child: const Center(
        child: Text(
          'Insights will appear here when content is connected.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF6F654D),
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyInsightState extends StatelessWidget {
  const _EmptyInsightState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _InsightsDecor.card(radius: 12),
      child: const Text(
        'Insight content is ready to be wired to backend data.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF6F654D),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InsightSectionSkeleton extends StatelessWidget {
  const _InsightSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 180, height: 16, color: const Color(0x22B88B00)),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 203,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0x22B88B00),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0x18B88B00),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _InsightsBackground extends StatelessWidget {
  const _InsightsBackground();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        _Circle(top: 90, right: 0, size: 44),
        _Circle(top: 205, left: -10, size: 44),
        _Circle(top: 575, right: 58, size: 44),
        _Circle(top: 810, left: -8, size: 36),
        _Circle(bottom: 88, left: 66, size: 38),
        _Circle(bottom: 26, right: 162, size: 40),
      ],
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
  });

  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0x55F4D772),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _InsightsPalette {
  const _InsightsPalette._();

  static const background = Color(0xFFFFF7DE);
  static const sun = Color(0xFFFFCA24);
  static const gold = Color(0xFFF4B600);
}

class _InsightsText {
  const _InsightsText._();

  static const sectionTitle = TextStyle(
    color: Colors.black,
    fontSize: 14,
    fontWeight: FontWeight.w900,
  );

  static const metricValue = TextStyle(
    fontSize: 16,
    height: 1,
    fontWeight: FontWeight.w900,
  );

  static const metricLabel = TextStyle(
    fontSize: 10,
    height: 1.1,
    fontWeight: FontWeight.w900,
  );
}

class _InsightsDecor {
  const _InsightsDecor._();

  static BoxDecoration card({double radius = 14}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    );
  }
}
