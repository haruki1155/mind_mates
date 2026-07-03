import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/admin_status_summary_model.dart';
import '../../../repositories/admin_status_repository.dart';

class AdminStatusDashboardScreen extends StatelessWidget {
  const AdminStatusDashboardScreen({super.key, this.repository});

  final AdminStatusRepository? repository;

  AdminStatusRepository get _effectiveRepository =>
      repository ?? AdminStatusRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin User Status'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<List<AdminStatusSummaryModel>>(
        stream: _effectiveRepository.watchUserStatuses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MessagePanel(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load statuses',
              message: 'Check the admin status Firestore rules and try again.',
            );
          }

          final statuses = snapshot.data ?? const <AdminStatusSummaryModel>[];
          if (statuses.isEmpty) {
            return const _MessagePanel(
              icon: Icons.monitor_heart_outlined,
              title: 'No statuses yet',
              message:
                  'User statuses will appear here after app activity generates mental health summaries.',
            );
          }

          return _DashboardContent(statuses: statuses);
        },
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.statuses});

  final List<AdminStatusSummaryModel> statuses;

  @override
  Widget build(BuildContext context) {
    final severeCount = _count(AdminUserStatus.severe);
    final moderateCount = _count(AdminUserStatus.moderate);
    final normalCount = _count(AdminUserStatus.normal);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatusSummaryTile(
                        label: 'Severe',
                        count: severeCount,
                        color: const Color(0xFFB3261E),
                      ),
                      _StatusSummaryTile(
                        label: 'Moderate',
                        count: moderateCount,
                        color: const Color(0xFFB06A00),
                      ),
                      _StatusSummaryTile(
                        label: 'Normal',
                        count: normalCount,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _StatusTable(statuses: statuses),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _count(AdminUserStatus status) {
    return statuses.where((item) => item.status == status).length;
  }
}

class _StatusSummaryTile extends StatelessWidget {
  const _StatusSummaryTile({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusTable extends StatelessWidget {
  const _StatusTable({required this.statuses});

  final List<AdminStatusSummaryModel> statuses;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E8E5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F6F4)),
            columnSpacing: 28,
            columns: const [
              DataColumn(label: Text('User')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Activity')),
              DataColumn(label: Text('Assessment')),
              DataColumn(label: Text('Updated')),
            ],
            rows: [
              for (final item in statuses)
                DataRow(
                  cells: [
                    DataCell(Text(item.userLabel)),
                    DataCell(_StatusBadge(status: item.status)),
                    DataCell(Text(item.role ?? '-')),
                    DataCell(Text('${item.totalActivityCount}')),
                    DataCell(Text(item.latestAssessmentStatus ?? '-')),
                    DataCell(Text(_formatDate(item.updatedAt))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final AdminUserStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AdminUserStatus.severe => const Color(0xFFB3261E),
      AdminUserStatus.moderate => const Color(0xFFB06A00),
      AdminUserStatus.normal => AppColors.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 38),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
