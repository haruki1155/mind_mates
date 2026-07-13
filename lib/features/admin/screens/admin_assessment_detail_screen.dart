import 'package:flutter/material.dart';

import '../../../repositories/admin_status_repository.dart';

class AdminAssessmentDetailScreen extends StatelessWidget {
  const AdminAssessmentDetailScreen({
    required this.userId,
    required this.userLabel,
    required this.repository,
    super.key,
  });

  final String userId;
  final String userLabel;
  final AdminStatusRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$userLabel assessments')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: repository.fetchUserAssessments(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load assessments.'));
          }
          final assessments = snapshot.data ?? const [];
          if (assessments.isEmpty) {
            return const Center(child: Text('No assessments available.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: assessments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _AssessmentCard(
              assessment: assessments[index],
              previous: index + 1 < assessments.length
                  ? assessments[index + 1]
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.assessment, this.previous});

  final Map<String, dynamic> assessment;
  final Map<String, dynamic>? previous;

  @override
  Widget build(BuildContext context) {
    final interpretation = _map(assessment['interpretation']);
    if (interpretation == null) {
      return Card(
        child: ListTile(
          title: const Text('Legacy assessment'),
          subtitle: Text(
            '${assessment['status'] ?? assessment['overallLevel'] ?? 'Result available'} — '
            'not recalculated with the current algorithm.',
          ),
        ),
      );
    }
    final quality = _map(interpretation['responseQuality']);
    final domains = _maps(interpretation['domainResults']);
    final compatible =
        previous != null &&
        previous!['algorithmVersion'] == assessment['algorithmVersion'] &&
        previous!['questionSetVersion'] == assessment['questionSetVersion'];
    final previousDomains = compatible
        ? _maps(_map(previous!['interpretation'])?['domainResults'])
        : const <Map<String, dynamic>>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              interpretation['supportPriorityLabel']?.toString() ??
                  interpretation['supportPriority']?.toString() ??
                  'Assessment interpretation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(interpretation['counselorSummary']?.toString() ?? ''),
            const SizedBox(height: 12),
            Text(
              'Response confidence: '
              '${quality?['confidenceLabel'] ?? 'Unavailable'}',
            ),
            const SizedBox(height: 12),
            const Text('Reasons for classification'),
            ..._strings(interpretation['rationale']).map(Text.new),
            const SizedBox(height: 12),
            const Text('Wellness domain profile'),
            ...domains.map(
              (domain) => Text(
                '${domain['domain']}: ${domain['score']}/100 '
                '(${domain['band']})',
              ),
            ),
            _ListSection(
              title: 'Protective factors',
              values: _strings(interpretation['protectiveFactors']),
            ),
            _ListSection(
              title: 'Functional-impact indicators',
              values: _strings(interpretation['functionalImpactFlags']),
            ),
            _ListSection(
              title: 'Suggested follow-up',
              values: _strings(interpretation['suggestedActions']),
            ),
            const SizedBox(height: 12),
            if (compatible)
              _TrendSection(current: domains, previous: previousDomains)
            else
              const Text(
                'Trend unavailable: no preceding version-compatible assessment.',
              ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Authorized raw-response drill-down'),
              children: [
                SelectableText(
                  (assessment['responses'] ?? assessment['answers'] ?? const [])
                      .toString(),
                ),
              ],
            ),
            const Text(
              'This custom wellness screening supports review and does not provide a diagnosis.',
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({required this.current, required this.previous});

  final List<Map<String, dynamic>> current;
  final List<Map<String, dynamic>> previous;

  @override
  Widget build(BuildContext context) {
    final previousScores = {
      for (final domain in previous)
        domain['domain']?.toString() ?? '': _number(domain['score']),
    };
    final comparable = current.where(
      (domain) => previousScores.containsKey(domain['domain']?.toString()),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Compatible assessment trend'),
          for (final domain in comparable)
            Text(
              '${domain['domain']}: '
              '${(_number(domain['score']) - previousScores[domain['domain']]!).toStringAsFixed(1)} points',
            ),
        ],
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({required this.title, required this.values});

  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(title), ...values.map(Text.new)],
      ),
    );
  }
}

Map<String, dynamic>? _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.map(_map).whereType<Map<String, dynamic>>().toList()
    : const [];

List<String> _strings(Object? value) => value is List
    ? value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList()
    : const [];

double _number(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
