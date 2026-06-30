import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/report_provider.dart';

class MentalHealthReportScreen extends StatelessWidget {
  const MentalHealthReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final report = _reportProviderOrNull(context)?.latestReport;
    return _MentalHealthPlaceholderScreen(
      title: 'Full Report',
      icon: Icons.bar_chart_rounded,
      message: report == null
          ? 'Your mental health report will appear here once assessments, moods, sleep, and stress tracking are connected.'
          : report.hasEnoughData
          ? report.description
          : 'Your report space is ready. Keep using assessments and mood check-ins so MindMate can build a useful weekly view.',
      details: report?.recommendedNextActions ?? const [],
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

class _MentalHealthPlaceholderScreen extends StatelessWidget {
  const _MentalHealthPlaceholderScreen({
    required this.title,
    required this.icon,
    required this.message,
    this.details = const [],
  });

  final String title;
  final IconData icon;
  final String message;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF4E1),
      appBar: AppBar(
        title: Text(title),
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
                  Icon(icon, size: 42, color: const Color(0xFFFFCA24)),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF6E6658),
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    for (final detail in details.take(3))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 16,
                              color: Color(0xFFFFCA24),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                detail,
                                style: const TextStyle(
                                  color: Color(0xFF6E6658),
                                  fontSize: 12,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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
}
