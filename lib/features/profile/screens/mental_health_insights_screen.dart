import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/insights/models/insights_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/insights_provider.dart';
import '../../../providers/mood_provider.dart';
import '../../../providers/report_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../routes/route_names.dart';

class MentalHealthInsightsScreen extends StatefulWidget {
  const MentalHealthInsightsScreen({super.key});

  @override
  State<MentalHealthInsightsScreen> createState() =>
      _MentalHealthInsightsScreenState();
}

class _MentalHealthInsightsScreenState
    extends State<MentalHealthInsightsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _requestedInsights = false;
  String _searchQuery = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedInsights) return;
    _requestedInsights = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _readProviderOrNull<InsightsProvider>(
        context,
      )?.loadInsights(_currentUserId());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insightsProvider = _watchProviderOrNull<InsightsProvider>(context);
    final data = insightsProvider?.data;
    final visibleSections = _visibleSections(data);
    final hasSearchQuery = _searchQuery.trim().isNotEmpty;
    final moodProvider = _watchProviderOrNull<MoodProvider>(context);
    final moods = moodProvider?.moods ?? const [];
    final report = _watchProviderOrNull<ReportProvider>(context)?.latestReport;
    final metrics = InsightMetricsSummary.from(moods: moods, report: report);
    final hasCheckedInToday = moodProvider?.hasCheckedInToday == true;
    final featured = _featuredResource(data);

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
                  child: _Header(onNotificationTap: _openNotifications),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 20, 12, 42),
                  sliver: SliverList.list(
                    children: [
                      _HeroSearchCard(
                        controller: _searchController,
                        onChanged: _updateSearchQuery,
                      ),
                      const SizedBox(height: 22),
                      const _SectionHeading(
                        title: 'Explore by topic',
                        subtitle:
                            'Practical, easy-to-understand wellness resources',
                      ),
                      const SizedBox(height: 12),
                      _CategoryRow(
                        categories: data?.categories ?? const [],
                        onCategoryTap: (category) =>
                            _openCategory(category, data),
                      ),
                      if (!hasSearchQuery && featured != null) ...[
                        const SizedBox(height: 22),
                        const _SectionHeading(
                          title: 'Recommended starting point',
                          subtitle:
                              'A useful resource selected from your library',
                        ),
                        const SizedBox(height: 12),
                        _FeaturedResourceCard(
                          item: featured,
                          onTap: () => _openInsightArticle(featured),
                        ),
                      ],
                      const SizedBox(height: 22),
                      _WeeklyGlanceCard(
                        metrics: metrics,
                        onLogMoodTap: _openLogMood,
                        actionLabel: hasCheckedInToday
                            ? 'View today’s mood'
                            : 'Log mood →',
                      ),
                      const SizedBox(height: 24),
                      if (insightsProvider?.errorMessage != null &&
                          data != null) ...[
                        _InsightsErrorBanner(
                          onRetry: () => insightsProvider?.loadInsights(
                            _currentUserId(),
                            forceRefresh: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if ((insightsProvider?.isLoading ?? false) &&
                          data == null)
                        const _InsightSectionSkeleton()
                      else if (insightsProvider?.errorMessage != null &&
                          data == null)
                        _InsightsErrorState(
                          onRetry: () => insightsProvider?.loadInsights(
                            _currentUserId(),
                            forceRefresh: true,
                          ),
                        )
                      else if (data == null || data.resources.isEmpty)
                        const _EmptyInsightState()
                      else if (visibleSections.isEmpty && hasSearchQuery)
                        _NoInsightResultsState(query: _searchQuery)
                      else
                        for (final section in visibleSections) ...[
                          _InsightSectionView(
                            section: section,
                            onItemTap: _openInsightArticle,
                            onSeeAllTap: () => _openInsightSection(section),
                          ),
                          const SizedBox(height: 24),
                        ],
                      _PaaccSupportCard(onContactTap: _openServices),
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

  String _currentUserId() {
    final authProvider = _readProviderOrNull<AuthProvider>(context);
    final authUserId =
        authProvider?.userId ?? authProvider?.hydrateCurrentUser();
    if (authUserId != null && authUserId.isNotEmpty) return authUserId;

    final profileUserId = _readProviderOrNull<UserProvider>(context)?.user?.id;
    if (profileUserId != null && profileUserId.isNotEmpty) {
      return profileUserId;
    }

    return 'preview_user';
  }

  void _updateSearchQuery(String value) {
    setState(() => _searchQuery = value);
  }

  List<InsightSection> _visibleSections(InsightsDashboardData? data) {
    final query = _searchQuery.trim().toLowerCase();
    if (data == null) return const [];
    if (query.isEmpty) return data.sections;

    final matches = data.resources
        .where((item) => _matchesSearch(item, query))
        .toList(growable: false);
    if (matches.isEmpty) return const [];
    return [
      InsightSection(
        id: 'search_results',
        title: 'Search results',
        items: matches,
        showSeeAll: false,
      ),
    ];
  }

  bool _matchesSearch(InsightCardItem item, String query) {
    final values = [
      item.title,
      item.subtitle,
      item.category,
      item.categoryId,
      item.body ?? '',
      item.source ?? '',
      item.contentType ?? '',
      ...item.tags,
    ];

    return values.any((value) => value.toLowerCase().contains(query));
  }

  InsightCardItem? _featuredResource(InsightsDashboardData? data) {
    if (data == null) return null;
    for (final section in data.sections) {
      if (section.id != 'recommended') continue;
      final article = section.items.where((item) => !item.isVideoPlaceholder);
      if (article.isNotEmpty) return article.first;
    }
    final articles = data.resources.where((item) => !item.isVideoPlaceholder);
    return articles.isEmpty ? null : articles.first;
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InsightsNotificationsScreen()),
    );
  }

  void _openLogMood() {
    Navigator.of(context).pushNamed(RouteNames.logMood);
  }

  void _openServices() {
    Navigator.of(context).pushNamed(RouteNames.services);
  }

  void _openInsightArticle(InsightCardItem item) {
    if (item.isVideoPlaceholder) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Video coming soon')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InsightArticleDetailScreen(item: item)),
    );
  }

  void _openCategory(InsightCategory category, InsightsDashboardData? data) {
    if (data == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InsightCategoryResourceScreen(
          category: category,
          resources: data.resourcesForCategory(category.id),
        ),
      ),
    );
  }

  void _openInsightSection(InsightSection section) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InsightSectionDetailScreen(
          section: section,
          onItemTap: _openInsightArticle,
        ),
      ),
    );
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
  const _HeroSearchCard({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

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
          TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              color: Color(0xFF2D2618),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              hintText: 'Search insights...',
              hintStyle: const TextStyle(
                color: Color(0xFF8D7F5E),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 22,
                color: Color(0xFF2D6EA7),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 36,
                minHeight: 32,
              ),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _InsightsText.sectionTitle),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF6F654E),
            fontSize: 12,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.categories, required this.onCategoryTap});

  final List<InsightCategory> categories;
  final ValueChanged<InsightCategory> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final effectiveCategories = categories.isEmpty
        ? const [
            InsightCategory(
              id: 'stress_burnout',
              label: 'Stress relief',
              icon: 'stress',
            ),
            InsightCategory(
              id: 'anxiety',
              label: 'Manage anxiety',
              icon: 'anxiety',
            ),
            InsightCategory(
              id: 'emotional_wellbeing',
              label: 'Emotions',
              icon: 'mood',
            ),
            InsightCategory(
              id: 'sleep_mental_health',
              label: 'Better sleep',
              icon: 'sleep',
            ),
            InsightCategory(
              id: 'self_esteem_confidence',
              label: 'Confidence',
              icon: 'mood',
            ),
            InsightCategory(
              id: 'depression_support',
              label: 'Low mood',
              icon: 'mood',
            ),
          ]
        : categories;

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: effectiveCategories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final category = effectiveCategories[index];
          return SizedBox(
            width: 104,
            child: _CategoryTile(
              category: category,
              onTap: () => onCategoryTap(category),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final InsightCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8D89D)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF2BF),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _categoryIcon(category.icon),
                  size: 23,
                  color: const Color(0xFF715900),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                category.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
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
  const _WeeklyGlanceCard({
    required this.metrics,
    required this.onLogMoodTap,
    required this.actionLabel,
  });

  final InsightMetricsSummary metrics;
  final VoidCallback onLogMoodTap;
  final String actionLabel;

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
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
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
  const _InsightSectionView({
    required this.section,
    required this.onItemTap,
    required this.onSeeAllTap,
  });

  final InsightSection section;
  final ValueChanged<InsightCardItem> onItemTap;
  final VoidCallback onSeeAllTap;

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
              TextButton(
                onPressed: onSeeAllTap,
                style: TextButton.styleFrom(
                  foregroundColor: _InsightsPalette.gold,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(54, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'See all →',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
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
                      onTap: () => onItemTap(section.items[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class InsightCategoryResourceScreen extends StatelessWidget {
  const InsightCategoryResourceScreen({
    required this.category,
    required this.resources,
    super.key,
  });

  final InsightCategory category;
  final List<InsightCardItem> resources;

  @override
  Widget build(BuildContext context) {
    final articles = resources
        .where((item) => !item.isVideoPlaceholder)
        .toList(growable: false);
    final videos = resources
        .where((item) => item.isVideoPlaceholder)
        .toList(growable: false);
    final featured = articles.firstOrNull;

    return Scaffold(
      backgroundColor: _InsightsPalette.background,
      appBar: AppBar(
        title: Text(category.label),
        backgroundColor: _InsightsPalette.sun,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
        children: [
          _CategoryHero(category: category, articleCount: articles.length),
          if (featured != null) ...[
            const SizedBox(height: 22),
            const _SectionHeading(
              title: 'Featured resource',
              subtitle: 'A helpful place to begin',
            ),
            const SizedBox(height: 12),
            _FeaturedResourceCard(
              item: featured,
              onTap: () => _openArticle(context, featured),
            ),
          ],
          const SizedBox(height: 24),
          _SectionHeading(
            title: 'Articles and guides',
            subtitle:
                '${articles.length} resource${articles.length == 1 ? '' : 's'} available',
          ),
          const SizedBox(height: 12),
          if (articles.isEmpty)
            const _CategoryEmptyState()
          else
            for (final item in articles) ...[
              _SectionDetailCard(
                item: item,
                onTap: () => _openArticle(context, item),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 12),
          const _SectionHeading(
            title: 'Videos',
            subtitle: 'Guided learning resources are being prepared',
          ),
          const SizedBox(height: 12),
          for (final video in videos) _VideoComingSoonCard(item: video),
        ],
      ),
    );
  }

  void _openArticle(BuildContext context, InsightCardItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InsightArticleDetailScreen(item: item),
      ),
    );
  }
}

class _CategoryHero extends StatelessWidget {
  const _CategoryHero({required this.category, required this.articleCount});

  final InsightCategory category;
  final int articleCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD45B), Color(0xFFFFE9A2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(_iconForCategory(category.icon), size: 28),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.label, style: _InsightsText.sectionTitle),
                const SizedBox(height: 7),
                Text(
                  _categoryIntroduction(category.id),
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),
                const SizedBox(height: 10),
                Text(
                  '$articleCount educational resource${articleCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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

class _FeaturedResourceCard extends StatelessWidget {
  const _FeaturedResourceCard({required this.item, required this.onTap});

  final InsightCardItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: _InsightsDecor.card(radius: 20),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 25,
                backgroundColor: Color(0xFFFFF0B4),
                child: Icon(Icons.auto_stories_outlined, color: Colors.black87),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: _InsightsText.sectionTitle),
                    const SizedBox(height: 5),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoComingSoonCard extends StatelessWidget {
  const _VideoComingSoonCard({required this.item});

  final InsightCardItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: false,
      label: '${item.title}. Video coming soon.',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F0E5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDDD4BE)),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE4DDCD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.play_circle_outline, size: 31),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Video coming soon',
                    style: TextStyle(fontSize: 12, color: Color(0xFF716956)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.lock_clock_outlined, color: Color(0xFF8A816D)),
          ],
        ),
      ),
    );
  }
}

class _CategoryEmptyState extends StatelessWidget {
  const _CategoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _InsightsDecor.card(radius: 18),
      child: const Column(
        children: [
          Icon(Icons.menu_book_outlined, size: 32),
          SizedBox(height: 10),
          Text(
            'Resources are being prepared',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 5),
          Text(
            'Check back soon for articles and practical guides.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

IconData _iconForCategory(String key) => switch (key) {
  'stress' => Icons.self_improvement,
  'sleep' => Icons.bedtime_outlined,
  'anxiety' => Icons.cloud_outlined,
  _ => Icons.sentiment_satisfied_alt,
};

String _categoryIntroduction(String id) => switch (id) {
  'stress_burnout' =>
    'Understand everyday stress, recognize overload, and explore practical ways to recover.',
  'anxiety' =>
    'Learn how anxious feelings can appear and practice supportive ways to respond.',
  'emotional_wellbeing' =>
    'Build emotional awareness, name what you feel, and express emotions safely.',
  'sleep_mental_health' =>
    'Explore how sleep affects mood, concentration, energy, and recovery.',
  'self_esteem_confidence' =>
    'Strengthen self-respect, realistic confidence, and a healthy growth mindset.',
  'depression_support' =>
    'Understand low-mood experiences and learn when additional support may help.',
  _ =>
    'Explore practical information for supporting mental health and well-being.',
};

class InsightSectionDetailScreen extends StatelessWidget {
  const InsightSectionDetailScreen({
    super.key,
    required this.section,
    required this.onItemTap,
  });

  final InsightSection section;
  final ValueChanged<InsightCardItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _InsightsPalette.background,
      appBar: AppBar(
        title: Text(section.title),
        backgroundColor: _InsightsPalette.sun,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        itemCount: section.items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = section.items[index];
          return _SectionDetailCard(item: item, onTap: () => onItemTap(item));
        },
      ),
    );
  }
}

class _SectionDetailCard extends StatelessWidget {
  const _SectionDetailCard({required this.item, required this.onTap});

  final InsightCardItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: _InsightsDecor.card(radius: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _InsightsPalette.sun,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.insights, color: Colors.black87),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CategoryPill(label: item.category),
                    const SizedBox(height: 8),
                    Text(item.title, style: _InsightsText.sectionTitle),
                    const SizedBox(height: 5),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF5E533B),
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.item,
    required this.isPatternCard,
    required this.onTap,
  });

  final InsightCardItem item;
  final bool isPatternCard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 203,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: isPatternCard
                  ? const Color(0xFFFFDA66)
                  : const Color(0xFFFFD466),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _InsightsPalette.gold, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
                        if (item.isVideoPlaceholder) ...[
                          const SizedBox(height: 6),
                          const _CategoryPill(label: 'Video coming soon'),
                        ],
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
          ),
        ),
      ),
    );
  }
}

class InsightArticleDetailScreen extends StatelessWidget {
  const InsightArticleDetailScreen({super.key, required this.item});

  final InsightCardItem item;

  @override
  Widget build(BuildContext context) {
    final body = item.body?.trim().isNotEmpty == true
        ? item.body!.trim()
        : item.subtitle;
    final metadata = _metadataText(item);
    final isSupportContent =
        item.contentType == 'support' ||
        item.tags.any((tag) => tag.toLowerCase().contains('pacc'));

    return Scaffold(
      backgroundColor: _InsightsPalette.background,
      appBar: AppBar(
        title: const Text('Insight'),
        backgroundColor: _InsightsPalette.sun,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          if (item.imageAsset.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  item.imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const _ArticleImageFallback(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _InsightsDecor.card(radius: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: _CategoryPill(label: item.category),
                ),
                const SizedBox(height: 14),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 24,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    color: Color(0xFF514832),
                    fontSize: 14,
                    height: 1.42,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (metadata.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    metadata,
                    style: const TextStyle(
                      color: Color(0xFF8D7F5E),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF2F2A1D),
                    fontSize: 14,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.tags.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in item.tags) _ArticleTagChip(label: tag),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isSupportContent) ...[
            const SizedBox(height: 14),
            const _ArticleSupportPanel(),
          ],
        ],
      ),
    );
  }

  String _metadataText(InsightCardItem item) {
    final parts = <String>[];
    if (item.source?.trim().isNotEmpty == true) {
      parts.add(item.source!.trim());
    }

    final publishedAt = item.publishedAt;
    if (publishedAt != null) {
      parts.add(_formatDate(publishedAt));
    }

    return parts.join(' • ');
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _ArticleImageFallback extends StatelessWidget {
  const _ArticleImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _InsightsPalette.sun,
      alignment: Alignment.center,
      child: const Icon(Icons.insights, size: 44, color: Colors.black87),
    );
  }
}

class _ArticleTagChip extends StatelessWidget {
  const _ArticleTagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1BE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _InsightsPalette.gold.withValues(alpha: .45)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ArticleSupportPanel extends StatelessWidget {
  const _ArticleSupportPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _InsightsPalette.sun,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.favorite, size: 24, color: Colors.black87),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'If this feels familiar, PACC support is available. Reaching out early is a healthy support step.',
              style: TextStyle(
                color: Colors.black,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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
        children: [
          Icon(_pillIcon(label), size: 13, color: Colors.black87),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
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
      child: const Column(
        children: [
          Icon(Icons.auto_stories_outlined, size: 34),
          SizedBox(height: 10),
          Text(
            'No wellness resources are available yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6F654D),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsErrorState extends StatelessWidget {
  const _InsightsErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _InsightsDecor.card(radius: 18),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 34),
          const SizedBox(height: 10),
          const Text(
            'We couldn’t load wellness resources.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _InsightsErrorBanner extends StatelessWidget {
  const _InsightsErrorBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7C65B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'Showing saved resources. Refresh didn’t complete.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _NoInsightResultsState extends StatelessWidget {
  const _NoInsightResultsState({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _InsightsDecor.card(radius: 12),
      child: Text(
        'No insights found for "$query".',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF6F654D),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class InsightsNotificationsScreen extends StatelessWidget {
  const InsightsNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _InsightsPalette.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: _InsightsPalette.sun,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(22),
          decoration: _InsightsDecor.card(radius: 12),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none,
                color: _InsightsPalette.gold,
                size: 42,
              ),
              SizedBox(height: 12),
              Text(
                'No insight notifications yet',
                textAlign: TextAlign.center,
                style: _InsightsText.sectionTitle,
              ),
              SizedBox(height: 8),
              Text(
                'Updates about new recommendations and wellness content will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6F654D),
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
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
