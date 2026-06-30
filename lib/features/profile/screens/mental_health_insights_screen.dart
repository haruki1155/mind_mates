import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/report_provider.dart';

class MentalHealthInsightsScreen extends StatelessWidget {
  const MentalHealthInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final report = _reportProviderOrNull(context)?.latestReport;
    final concernAreas = report?.topConcernAreas ?? const <String>[];

    return Scaffold(
      backgroundColor: const Color(0xFFFAF4E1),
      appBar: AppBar(
        title: const Text('View Insights'),
        backgroundColor: const Color(0xFFFFCA24),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 14,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.insights_rounded,
                    size: 42,
                    color: Color(0xFF9FB5F2),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Mental Health Insights',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    concernAreas.isEmpty
                        ? 'Personalized insights will appear here when enough mood, assessment, sleep, and stress data is available.'
                        : 'Current focus areas from your recent records.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF6E6658),
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (concernAreas.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    for (final area in concernAreas.take(4))
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          area,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  ReportProvider? _reportProviderOrNull(BuildContext context) {
    try {
      return context.watch<ReportProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}
