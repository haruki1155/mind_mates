import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/mental_health_activity_summary.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/mental_health_activity_provider.dart';
import '../../../providers/user_provider.dart';

class MentalHealthReportScreen extends StatefulWidget {
  const MentalHealthReportScreen({super.key});

  @override
  State<MentalHealthReportScreen> createState() =>
      _MentalHealthReportScreenState();
}

class _MentalHealthReportScreenState extends State<MentalHealthReportScreen> {
  String? _loadedUserId;
  bool _isRefreshing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = _currentUserId(hydrate: true);
    if (userId == null || userId.isEmpty || _loadedUserId == userId) return;

    _loadedUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadSummary(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final summaryProvider = _summaryProviderOrNull(context);
    final summary = summaryProvider?.summary;
    final userId = _currentUserId();
    final hasUser = userId != null && userId.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF4E1),
      appBar: AppBar(
        title: const Text('Mental Health Summary'),
        backgroundColor: const Color(0xFFFFCA24),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: !hasUser
          ? const _EmptySummary(
              message: 'Please sign in to view your mental health summary.',
            )
          : RefreshIndicator(
              onRefresh: () => _loadSummary(userId),
              child: _SummaryBody(
                summary: summary,
                isLoading: summaryProvider?.isLoading ?? false,
                errorMessage: summaryProvider?.errorMessage,
              ),
            ),
    );
  }

  Future<void> _loadSummary(String userId) async {
    if (_isRefreshing) return;
    final summaryProvider = _readSummaryProviderOrNull(context);
    if (summaryProvider == null) return;
    _isRefreshing = true;
    try {
      await summaryProvider.loadDailySummary(userId);
    } finally {
      _isRefreshing = false;
    }
  }

  MentalHealthActivityProvider? _summaryProviderOrNull(BuildContext context) {
    try {
      return context.watch<MentalHealthActivityProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  MentalHealthActivityProvider? _readSummaryProviderOrNull(
    BuildContext context,
  ) {
    try {
      return context.read<MentalHealthActivityProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  String? _currentUserId({bool hydrate = false}) {
    final authProvider = _readProviderOrNull<AuthProvider>();
    final authUserId =
        authProvider?.userId ??
        (hydrate ? authProvider?.hydrateCurrentUser() : null);
    if (authUserId != null && authUserId.isNotEmpty) return authUserId;

    final profileUserId = _readProviderOrNull<UserProvider>()?.user?.id;
    if (profileUserId != null && profileUserId.isNotEmpty) return profileUserId;

    return null;
  }

  T? _readProviderOrNull<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.summary,
    required this.isLoading,
    required this.errorMessage,
  });

  final MentalHealthActivitySummary? summary;
  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (isLoading && summary == null) {
      return const _ScrollableStatus(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null && summary == null) {
      return _ScrollableStatus(
        child: _Panel(
          child: Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: _SummaryText.body,
          ),
        ),
      );
    }

    final loadedSummary =
        summary ?? MentalHealthActivitySummary.empty(date: DateTime.now());
    return _SummaryContent(summary: loadedSummary);
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.summary});

  final MentalHealthActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        _StatusPanel(summary: summary),
        const SizedBox(height: 14),
        _UsageGrid(summary: summary),
        const SizedBox(height: 14),
        _RecentActivityPanel(summary: summary),
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.summary});

  final MentalHealthActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Today's activity",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800).withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  summary.hasActivity ? 'Live' : 'No activity yet',
                  style: const TextStyle(
                    color: Color(0xFF6B5D00),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(summary.dateLabel, style: _SummaryText.muted),
          const SizedBox(height: 10),
          Text(
            summary.hasActivity
                ? 'Your day-to-day activity is shown here as it is recorded. Weekly reports can still run in the background for admin monitoring and insights.'
                : 'No activity yet today. Start with a mood check-in, breathing session, MindAid, or Secret Chat support.',
            style: _SummaryText.body,
          ),
        ],
      ),
    );
  }
}

class _UsageGrid extends StatelessWidget {
  const _UsageGrid({required this.summary});

  final MentalHealthActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      _UsageItem(
        icon: Icons.mood_rounded,
        label: 'Mood',
        value: '${summary.moodCheckIns}',
        detail: 'Avg ${summary.averageMoodLabel}/5',
      ),
      _UsageItem(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'MindAid',
        value: '${summary.mindAidMessages}',
        detail: 'messages',
      ),
      _UsageItem(
        icon: Icons.air_rounded,
        label: 'Breathing',
        value: '${summary.breathingSessions}',
        detail: '${summary.breathingMinutes} min',
      ),
      _UsageItem(
        icon: Icons.local_fire_department_rounded,
        label: 'Activity',
        value: '${summary.activeDayCount}',
        detail: '${summary.currentStreak}-day streak',
      ),
      _UsageItem(
        icon: Icons.forum_outlined,
        label: 'Secret Chat',
        value: '${summary.secretChatEngagementCount}',
        detail:
            '${summary.secretChatPosts} posts, ${summary.secretChatComments} comments',
      ),
      _UsageItem(
        icon: Icons.monitor_heart_outlined,
        label: 'Engagement',
        value: '${summary.totalActions}',
        detail: "today's actions",
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth >= 560
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _UsageCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _RecentActivityPanel extends StatelessWidget {
  const _RecentActivityPanel({required this.summary});

  final MentalHealthActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final activities = summary.recentActivities;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Activity', style: _SummaryText.sectionTitle),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            const Text('No activity yet today.', style: _SummaryText.body)
          else
            for (final activity in activities) ...[
              _RecentActivityRow(activity: activity),
              if (activity != activities.last) const Divider(height: 18),
            ],
        ],
      ),
    );
  }
}

class _RecentActivityRow extends StatelessWidget {
  const _RecentActivityRow({required this.activity});

  final MentalHealthActivityItem activity;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_iconForType(activity.type), color: const Color(0xFFFFB800)),
        const SizedBox(width: 10),
        Expanded(child: Text(activity.label, style: _SummaryText.cardTitle)),
        Text(activity.timeLabel, style: _SummaryText.muted),
      ],
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'moodCheckIn':
        return Icons.mood_rounded;
      case 'mindAidMessage':
        return Icons.chat_bubble_outline_rounded;
      case 'breathingSession':
        return Icons.air_rounded;
      case 'secretChatPost':
      case 'secretChatComment':
      case 'secretChatInteraction':
        return Icons.forum_outlined;
      case 'quickAssessment':
      case 'fullAssessment':
        return Icons.assignment_turned_in_outlined;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }
}

class _UsageItem {
  const _UsageItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.item});

  final _UsageItem item;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Icon(item.icon, color: const Color(0xFFFFB800), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: _SummaryText.cardTitle),
                const SizedBox(height: 3),
                Text(item.detail, style: _SummaryText.muted),
              ],
            ),
          ),
          Text(item.value, style: _SummaryText.score),
        ],
      ),
    );
  }
}

class _EmptySummary extends StatelessWidget {
  const _EmptySummary({
    this.message =
        'Your daily mental health activity will appear here once moods, MindAid, breathing, and Secret Chat usage are connected.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return _ScrollableStatus(
      child: _Panel(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: _SummaryText.body,
        ),
      ),
    );
  }
}

class _ScrollableStatus extends StatelessWidget {
  const _ScrollableStatus({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * .58,
          child: Center(child: child),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1F000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SummaryText {
  const _SummaryText._();

  static const sectionTitle = TextStyle(
    color: Colors.black,
    fontSize: 15,
    fontWeight: FontWeight.w900,
  );

  static const cardTitle = TextStyle(
    color: Colors.black,
    fontSize: 13,
    fontWeight: FontWeight.w900,
  );

  static const score = TextStyle(
    color: Colors.black,
    fontSize: 18,
    fontWeight: FontWeight.w900,
  );

  static const body = TextStyle(
    color: Color(0xFF5F584A),
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );

  static const muted = TextStyle(
    color: Color(0xFF837B70),
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );
}
