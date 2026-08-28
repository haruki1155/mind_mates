import 'package:flutter/material.dart';

import '../domain/admin_colors.dart';
import '../domain/service_monitoring_models.dart';
import '../../../repositories/admin_portal_repository.dart';

class ServiceMonitoringPage extends StatefulWidget {
  const ServiceMonitoringPage({super.key, required this.repository});
  final AdminPortalRepository repository;

  @override
  State<ServiceMonitoringPage> createState() => _ServiceMonitoringPageState();
}

class _ServiceMonitoringPageState extends State<ServiceMonitoringPage> {
  int _days = 7;
  String _filter = 'all';
  late Future<AdminServiceMonitoringResponse> _future = _load();

  Future<AdminServiceMonitoringResponse> _load() =>
      widget.repository.getAdminServiceMonitoring(days: _days);

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Monitoring',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          'Aggregate usage and operational health for MindMates services.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AdminColors.textMuted),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 days')),
                ButtonSegment(value: 30, label: Text('30 days')),
                ButtonSegment(value: 90, label: Text('90 days')),
              ],
              selected: {_days},
              onSelectionChanged: (value) => setState(() {
                _days = value.first;
                _future = _load();
              }),
            ),
            SizedBox(
              width: 230,
              child: DropdownButtonFormField<String>(
                initialValue: _filter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Service',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('All services'),
                  ),
                  ...adminServiceCatalog.map(
                    (service) => DropdownMenuItem(
                      value: service.serviceKey,
                      child: Text(service.displayLabel),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _filter = value ?? 'all'),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FutureBuilder<AdminServiceMonitoringResponse>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return _StatePanel(
                icon: Icons.cloud_off_outlined,
                title: 'Monitoring is unavailable',
                message:
                    'Check the connection or your portal permissions, then retry.',
                action: OutlinedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              );
            }
            final services =
                snapshot.data?.services
                    .where(
                      (service) =>
                          _filter == 'all' || service.serviceKey == _filter,
                    )
                    .toList() ??
                const [];
            if (services.isEmpty) {
              return const _StatePanel(
                icon: Icons.insights_outlined,
                title: 'No monitoring data',
                message:
                    'Service aggregates will appear after app-user activity is recorded.',
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1200
                    ? 3
                    : constraints.maxWidth >= 760
                    ? 2
                    : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: services.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 250,
                  ),
                  itemBuilder: (_, index) =>
                      _ServiceCard(summary: services[index]),
                );
              },
            );
          },
        ),
      ],
    ),
  );
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.summary});
  final AdminServiceMonitoringSummary summary;

  @override
  Widget build(BuildContext context) {
    final catalog = adminServiceCatalog.firstWhere(
      (item) => item.serviceKey == summary.serviceKey,
      orElse: () => const AdminServiceCatalogEntry(
        serviceKey: 'unknown',
        displayLabel: 'Service',
        icon: Icons.extension_outlined,
      ),
    );
    final healthColor = switch (summary.healthState) {
      ServiceHealthState.healthy => AdminColors.success,
      ServiceHealthState.degraded => AdminColors.highlight,
      ServiceHealthState.stale => AdminColors.warning,
      ServiceHealthState.unavailable => AdminColors.textMuted,
    };
    final trend = summary.dailyTrend
        .map((point) => point.count)
        .fold<int>(0, (total, value) => total + value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(catalog.icon, color: AdminColors.primaryPressed),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary.displayLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                _HealthBadge(state: summary.healthState, color: healthColor),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Activities',
                    value: '${summary.activityCount}',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: 'Active users',
                    value: '${summary.activeUserCount}',
                  ),
                ),
                Expanded(
                  child: _Metric(label: '7d trend', value: '$trend'),
                ),
              ],
            ),
            if (summary.serviceKey == 'mindaid' &&
                summary.turnCount != null) ...[
              const SizedBox(height: 12),
              Text(
                'MindAid: ${summary.turnCount} turns · ${summary.fallbackCount ?? 0} fallbacks',
                style: TextStyle(color: AdminColors.textMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              summary.telemetryFreshness == null
                  ? 'Telemetry: not available yet'
                  : 'Telemetry updated ${_relative(summary.telemetryFreshness!)}',
              style: TextStyle(color: AdminColors.textMuted, fontSize: 12),
            ),
            if (summary.errorCount > 0 || summary.averageLatencyMs > 0)
              Text(
                '${summary.errorCount} errors · ${summary.averageLatencyMs} ms avg latency',
                style: TextStyle(color: AdminColors.textMuted, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  String _relative(DateTime time) {
    final difference = DateTime.now().difference(time.toLocal());
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      ),
      Text(label, style: TextStyle(fontSize: 11, color: AdminColors.textMuted)),
    ],
  );
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.state, required this.color});
  final ServiceHealthState state;
  final Color color;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Text(
        state.name,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _StatePanel extends StatelessWidget {
  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Row(
        children: [
          Icon(icon, color: AdminColors.primaryPressed, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: AdminColors.textMuted)),
                if (action != null) ...[const SizedBox(height: 14), action!],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
