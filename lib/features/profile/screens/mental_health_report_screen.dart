import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/mental_health_activity_summary.dart';
import '../../../models/report_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/mental_health_activity_provider.dart';
import '../../../providers/report_provider.dart';
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
    final reportProvider = _reportProviderOrNull(context);
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
              onRefresh: () => _loadSummary(userId, refresh: true),
              child: _SummaryBody(
                summary: summary,
                isLoading: summaryProvider?.isLoading ?? false,
                errorMessage: summaryProvider?.errorMessage,
                report: reportProvider?.latestReport,
                isReportLoading: reportProvider?.isLoading ?? false,
                reportErrorMessage: reportProvider?.errorMessage,
              ),
            ),
    );
  }

  Future<void> _loadSummary(String userId, {bool refresh = false}) async {
    if (_isRefreshing) return;
    final summaryProvider = _readSummaryProviderOrNull(context);
    final reportProvider = _readReportProviderOrNull(context);
    if (summaryProvider == null && reportProvider == null) return;
    _isRefreshing = true;
    try {
      await Future.wait([
        if (summaryProvider != null) summaryProvider.loadDailySummary(userId),
        if (reportProvider != null)
          refresh
              ? reportProvider.refreshWeeklyReport(userId)
              : _loadWeeklyReport(reportProvider, userId),
      ]);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _loadWeeklyReport(ReportProvider provider, String userId) async {
    await provider.loadLatestReport(userId);
    if (provider.latestReport == null) {
      await provider.ensureWeeklyPlaceholder(userId);
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

  ReportProvider? _reportProviderOrNull(BuildContext context) {
    try {
      return context.watch<ReportProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  ReportProvider? _readReportProviderOrNull(BuildContext context) {
    try {
      return context.read<ReportProvider>();
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
    required this.report,
    required this.isReportLoading,
    required this.reportErrorMessage,
  });

  final MentalHealthActivitySummary? summary;
  final bool isLoading;
  final String? errorMessage;
  final ReportModel? report;
  final bool isReportLoading;
  final String? reportErrorMessage;

  @override
  Widget build(BuildContext context) {
    if (summary == null && report == null && (isLoading || isReportLoading)) {
      return const _ScrollableStatus(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final loadedSummary =
        summary ?? MentalHealthActivitySummary.empty(date: DateTime.now());
    return _SummaryContent(
      summary: loadedSummary,
      dailyErrorMessage: errorMessage,
      isDailyLoading: isLoading,
      report: report,
      reportErrorMessage: reportErrorMessage,
      isReportLoading: isReportLoading,
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({
    required this.summary,
    required this.dailyErrorMessage,
    required this.isDailyLoading,
    required this.report,
    required this.reportErrorMessage,
    required this.isReportLoading,
  });

  final MentalHealthActivitySummary summary;
  final String? dailyErrorMessage;
  final bool isDailyLoading;
  final ReportModel? report;
  final String? reportErrorMessage;
  final bool isReportLoading;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        _WeeklyReportSection(
          report: report,
          isLoading: isReportLoading,
          errorMessage: reportErrorMessage,
        ),
        const SizedBox(height: 20),
        if (isDailyLoading && !summary.hasActivity)
          const _Panel(child: LinearProgressIndicator())
        else if (dailyErrorMessage != null && !summary.hasActivity)
          _Panel(
            child: Text(
              dailyErrorMessage!,
              textAlign: TextAlign.center,
              style: _SummaryText.body,
            ),
          )
        else
          _StatusPanel(summary: summary),
        const SizedBox(height: 14),
        _UsageGrid(summary: summary),
        const SizedBox(height: 14),
        _RecentActivityPanel(summary: summary),
      ],
    );
  }
}

class _WeeklyReportSection extends StatelessWidget {
  const _WeeklyReportSection({
    required this.report,
    required this.isLoading,
    required this.errorMessage,
  });

  final ReportModel? report;
  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (isLoading && report == null) {
      return const _Panel(
        child: Column(
          children: [
            LinearProgressIndicator(),
            SizedBox(height: 12),
            Text('Preparing your weekly summary…', style: _SummaryText.body),
          ],
        ),
      );
    }
    if (errorMessage != null && report == null) {
      return _Panel(
        child: Text(
          errorMessage!,
          textAlign: TextAlign.center,
          style: _SummaryText.body,
        ),
      );
    }
    final value = report;
    if (value == null) {
      return const _Panel(
        child: Column(
          children: [
            Icon(Icons.insights_outlined, size: 34, color: Color(0xFFFFB800)),
            SizedBox(height: 10),
            Text(
              'Your weekly summary is being prepared.',
              style: _SummaryText.sectionTitle,
            ),
            SizedBox(height: 6),
            Text(
              'Keep checking in and using MindMate to build a more useful picture of your week.',
              textAlign: TextAlign.center,
              style: _SummaryText.body,
            ),
          ],
        ),
      );
    }

    final statusColor = _statusColor(value.mentalStatus);
    final statusBackground = statusColor.withValues(alpha: .12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, statusBackground],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor.withValues(alpha: .45)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: statusBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.health_and_safety_outlined,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value.title, style: _SummaryText.heroTitle),
                        if (value.weekDateRangeLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            value.weekDateRangeLabel,
                            style: _SummaryText.muted,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      value.mentalStatusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(value.description, style: _SummaryText.heroBody),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.update_rounded,
                    size: 16,
                    color: Color(0xFF837B70),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Generated ${_formatGeneratedAt(value.generatedAt)}',
                      style: _SummaryText.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _WeeklyMetrics(report: value),
        if (value.latestAssessmentStatus != null ||
            value.quickAssessmentScore != null ||
            value.fullAssessmentScore != null) ...[
          const SizedBox(height: 14),
          _AssessmentPanel(report: value),
        ],
        if (value.topConcernAreas.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ConcernPanel(concerns: value.topConcernAreas),
        ],
        if (value.recommendedNextActions.isNotEmpty) ...[
          const SizedBox(height: 14),
          _RecommendationsPanel(actions: value.recommendedNextActions),
        ],
        const SizedBox(height: 14),
        const _WellnessNote(),
      ],
    );
  }

  static Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'severe':
      case 'high':
        return const Color(0xFFB3261E);
      case 'moderate':
      case 'needs_support':
        return const Color(0xFF9A6700);
      default:
        return const Color(0xFF2E7D57);
    }
  }
}

class _WeeklyMetrics extends StatelessWidget {
  const _WeeklyMetrics({required this.report});

  final ReportModel report;

  @override
  Widget build(BuildContext context) {
    final items = [
      _UsageItem(
        icon: Icons.mood_outlined,
        label: 'Weekly mood',
        value: report.averageMoodLabel,
        detail: '${report.moodCheckInCount} check-ins',
      ),
      _UsageItem(
        icon: Icons.assignment_turned_in_outlined,
        label: 'Assessments',
        value: '${report.assessmentCount}',
        detail: report.latestAssessmentStatus ?? 'No recent result',
      ),
      _UsageItem(
        icon: Icons.air_rounded,
        label: 'Mindful breathing',
        value: '${report.mindfulBreathingMinutes} min',
        detail: '${report.breathingSessionCount} sessions',
      ),
      _UsageItem(
        icon: Icons.calendar_month_outlined,
        label: 'Active days',
        value: '${report.activeDayCount}',
        detail: '${report.currentStreak}-day streak',
      ),
      _UsageItem(
        icon: Icons.favorite_border_rounded,
        label: 'Engagement',
        value: '${report.totalEngagementCount}',
        detail: 'support activities',
      ),
      _UsageItem(
        icon: Icons.forum_outlined,
        label: 'Secret Chat',
        value: '${report.secretChatEngagementCount}',
        detail: 'private engagement count',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 350;
        final width = twoColumns
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

class _AssessmentPanel extends StatelessWidget {
  const _AssessmentPanel({required this.report});
  final ReportModel report;

  @override
  Widget build(BuildContext context) {
    final score = report.fullAssessmentScore ?? report.quickAssessmentScore;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Latest assessment', style: _SummaryText.sectionTitle),
          const SizedBox(height: 10),
          Text(
            report.latestAssessmentStatus ??
                report.fullAssessmentStatus ??
                report.quickAssessmentStatus ??
                'Assessment recorded',
            style: _SummaryText.cardTitle,
          ),
          if (score != null) ...[
            const SizedBox(height: 5),
            Text('Recorded score: $score', style: _SummaryText.body),
          ],
          if (report.mentalStatusSignal != null) ...[
            const SizedBox(height: 8),
            Text(report.mentalStatusSignal!, style: _SummaryText.body),
          ],
        ],
      ),
    );
  }
}

class _ConcernPanel extends StatelessWidget {
  const _ConcernPanel({required this.concerns});
  final List<String> concerns;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Areas to keep an eye on',
            style: _SummaryText.sectionTitle,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final concern in concerns)
                Chip(
                  avatar: const Icon(Icons.visibility_outlined, size: 16),
                  label: Text(concern),
                  backgroundColor: const Color(0xFFFFF4CC),
                  side: const BorderSide(color: Color(0xFFFFD45A)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecommendationsPanel extends StatelessWidget {
  const _RecommendationsPanel({required this.actions});
  final List<String> actions;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended next steps',
            style: _SummaryText.sectionTitle,
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < actions.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFCA24),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(actions[index], style: _SummaryText.body)),
              ],
            ),
            if (index != actions.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _WellnessNote extends StatelessWidget {
  const _WellnessNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD45A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF8A6500)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'This summary supports self-reflection and is not a diagnosis. Contact a qualified professional when you need clinical guidance or urgent support.',
              style: _SummaryText.body,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatGeneratedAt(DateTime value) {
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
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '${months[value.month - 1]} ${value.day}, ${value.year} at $hour:$minute $period';
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

  static const heroTitle = TextStyle(
    color: Colors.black,
    fontSize: 21,
    height: 1.15,
    fontWeight: FontWeight.w900,
  );

  static const heroBody = TextStyle(
    color: Color(0xFF3F392F),
    fontSize: 14,
    height: 1.45,
    fontWeight: FontWeight.w600,
  );

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
