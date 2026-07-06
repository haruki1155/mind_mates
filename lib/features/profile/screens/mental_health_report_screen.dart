import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/report_model.dart';
import '../../../providers/auth_provider.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = _currentUserId(hydrate: true);
    if (userId == null || userId.isEmpty || _loadedUserId == userId) return;

    _loadedUserId = userId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshReport(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = _reportProviderOrNull(context);
    final report = reportProvider?.latestReport;
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
          ? const _EmptyReport(
              message: 'Please sign in to view your mental health summary.',
            )
          : RefreshIndicator(
              onRefresh: () => _refreshReport(userId),
              child: _ReportBody(
                report: report,
                isLoading: reportProvider?.isLoading ?? false,
                errorMessage: reportProvider?.errorMessage,
              ),
            ),
    );
  }

  Future<void> _refreshReport(String userId) async {
    final reportProvider = _readReportProviderOrNull(context);
    if (reportProvider == null) return;
    await reportProvider.refreshWeeklyReport(userId);
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

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.report,
    required this.isLoading,
    required this.errorMessage,
  });

  final ReportModel? report;
  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final loadedReport = report;
    if (isLoading && report == null) {
      return const _ScrollableStatus(
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null && report == null) {
      return _ScrollableStatus(
        child: _Panel(
          child: Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: _ReportText.body,
          ),
        ),
      );
    }

    if (loadedReport == null) {
      return const _EmptyReport();
    }

    return _ReportContent(report: loadedReport);
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.report});

  final ReportModel report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        _StatusPanel(report: report),
        const SizedBox(height: 14),
        _AssessmentPanel(report: report),
        const SizedBox(height: 14),
        _UsageGrid(report: report),
        if (report.recommendedNextActions.isNotEmpty) ...[
          const SizedBox(height: 14),
          _ActionsPanel(actions: report.recommendedNextActions),
        ],
      ],
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.report});

  final ReportModel report;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (report.mentalStatus) {
      'severe' => const Color(0xFFB3261E),
      'moderate' => const Color(0xFFB06A00),
      _ => const Color(0xFF2E7D32),
    };

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  report.title,
                  style: const TextStyle(
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
                  color: statusColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  report.mentalStatusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(report.description, style: _ReportText.body),
        ],
      ),
    );
  }
}

class _AssessmentPanel extends StatelessWidget {
  const _AssessmentPanel({required this.report});

  final ReportModel report;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Assessment Results', style: _ReportText.sectionTitle),
          const SizedBox(height: 12),
          _AssessmentRow(
            title: 'Full Assessment',
            status: report.fullAssessmentStatus,
            score: report.fullAssessmentScore,
            detail: report.fullAssessmentTopConcernAreas.isEmpty
                ? 'No full assessment result this week'
                : 'Focus: ${report.fullAssessmentTopConcernAreas.join(', ')}',
          ),
          const Divider(height: 22),
          _AssessmentRow(
            title: 'Quick Assessment',
            status: report.quickAssessmentStatus,
            score: report.quickAssessmentScore,
            detail: report.quickAssessmentSignal == null
                ? 'No quick assessment result this week'
                : 'Signal: ${report.quickAssessmentSignal}',
          ),
        ],
      ),
    );
  }
}

class _AssessmentRow extends StatelessWidget {
  const _AssessmentRow({
    required this.title,
    required this.status,
    required this.score,
    required this.detail,
  });

  final String title;
  final String? status;
  final int? score;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: _ReportText.cardTitle),
              const SizedBox(height: 4),
              Text(status ?? 'Not available', style: _ReportText.body),
              const SizedBox(height: 4),
              Text(detail, style: _ReportText.muted),
            ],
          ),
        ),
        if (score != null)
          Text('$score/100', style: _ReportText.score)
        else
          const Text('--', style: _ReportText.score),
      ],
    );
  }
}

class _UsageGrid extends StatelessWidget {
  const _UsageGrid({required this.report});

  final ReportModel report;

  @override
  Widget build(BuildContext context) {
    final items = [
      _UsageItem(
        icon: Icons.mood_rounded,
        label: 'Mood',
        value: '${report.moodCheckInCount}',
        detail: 'Avg ${report.averageMoodLabel}/5',
      ),
      _UsageItem(
        icon: Icons.chat_bubble_outline_rounded,
        label: 'MindAid',
        value: '${report.mindAidMessageCount}',
        detail: 'messages',
      ),
      _UsageItem(
        icon: Icons.air_rounded,
        label: 'Breathing',
        value: '${report.breathingSessionCount}',
        detail: '${report.mindfulBreathingMinutes} min',
      ),
      _UsageItem(
        icon: Icons.local_fire_department_rounded,
        label: 'Activity',
        value: '${report.activeDayCount}',
        detail: '${report.currentStreak}-day streak',
      ),
      _UsageItem(
        icon: Icons.forum_outlined,
        label: 'Secret Chat',
        value: '${report.secretChatEngagementCount}',
        detail:
            '${report.secretChatPostCount} posts, ${report.secretChatCommentCount} comments',
      ),
      _UsageItem(
        icon: Icons.monitor_heart_outlined,
        label: 'Engagement',
        value: '${report.totalEngagementCount}',
        detail: 'weekly actions',
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
                Text(item.label, style: _ReportText.cardTitle),
                const SizedBox(height: 3),
                Text(item.detail, style: _ReportText.muted),
              ],
            ),
          ),
          Text(item.value, style: _ReportText.score),
        ],
      ),
    );
  }
}

class _ActionsPanel extends StatelessWidget {
  const _ActionsPanel({required this.actions});

  final List<String> actions;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended Next Actions',
            style: _ReportText.sectionTitle,
          ),
          const SizedBox(height: 10),
          for (final action in actions.take(4))
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 17,
                    color: Color(0xFFFFB800),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(action, style: _ReportText.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport({
    this.message =
        'Your mental health summary will appear here once assessments, moods, MindAid, breathing, and Secret Chat usage are connected.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return _ScrollableStatus(
      child: _Panel(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: _ReportText.body,
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

class _ReportText {
  const _ReportText._();

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
