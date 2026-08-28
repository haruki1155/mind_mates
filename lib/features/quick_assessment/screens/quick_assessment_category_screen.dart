import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/assessment_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../repositories/assessment_repository.dart';
import '../../../routes/route_names.dart';
import '../models/quick_assessment_models.dart';
import '../widgets/quick_assessment_widgets.dart';

class QuickAssessmentCategoryScreen extends StatelessWidget {
  const QuickAssessmentCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AssessmentProvider>(
      builder: (context, provider, _) {
        final role = provider.selectedRole ?? AssessmentRole.student;

        return QuickAssessmentScaffold(
          topClusters: const [
            BubbleCluster(top: 28, left: -26),
            BubbleCluster(top: 28, right: -28, mirrored: true),
          ],
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomInset = MediaQuery.paddingOf(context).bottom;

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(28, 68, 28, 32 + bottomInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 100 - bottomInset,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 390),
                      child: _DecisionContent(provider: provider, role: role),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  static String iconFor(AssessmentRole role) {
    switch (role) {
      case AssessmentRole.student:
        return 'ST';
      case AssessmentRole.faculty:
        return 'FC';
      case AssessmentRole.staff:
        return 'SF';
    }
  }
}

class _AssessmentFacts extends StatelessWidget {
  const _AssessmentFacts();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QuickAssessmentPalette.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: QuickAssessmentPalette.softBorder),
      ),
      child: const Column(
        children: [
          _FactRow(
            icon: Icons.format_list_numbered_rounded,
            text: '40 core questions',
          ),
          SizedBox(height: 10),
          _FactRow(
            icon: Icons.call_split_rounded,
            text: 'Some follow-up questions may appear',
          ),
          SizedBox(height: 10),
          _FactRow(
            icon: Icons.calendar_today_outlined,
            text: 'Think about the past two weeks',
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: QuickAssessmentPalette.secondaryText),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: QuickAssessmentPalette.secondaryText,
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AgreementScale extends StatelessWidget {
  const _AgreementScale();

  static const labels = [
    'Strongly Disagree',
    'Disagree',
    'Neutral',
    'Agree',
    'Strongly Agree',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Response scale',
          style: TextStyle(
            color: QuickAssessmentPalette.text,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final entry in labels.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: QuickAssessmentPalette.optionFill,
                    border: Border.all(
                      color: QuickAssessmentPalette.softBorder,
                    ),
                  ),
                  child: Text(
                    '${entry.$1 + 1}',
                    style: const TextStyle(
                      color: QuickAssessmentPalette.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  entry.$2,
                  style: const TextStyle(
                    color: QuickAssessmentPalette.secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DecisionContent extends StatelessWidget {
  const _DecisionContent({required this.provider, required this.role});

  final AssessmentProvider provider;
  final AssessmentRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: QuickAssessmentPalette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: QuickAssessmentPalette.softBorder),
        boxShadow: [
          BoxShadow(
            color: QuickAssessmentPalette.shadow.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QuickPlaceholderIcon(
            icon: QuickAssessmentCategoryScreen.iconFor(role),
            size: 20,
          ),
          const SizedBox(height: 20),
          const Text(
            'Full Wellness Assessment',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: QuickAssessmentPalette.text,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _messageFor(provider, role),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: QuickAssessmentPalette.secondaryText,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              height: 1.42,
            ),
          ),
          if (provider.hasVerifiedQuickResult && provider.quickResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Your quick check-in is complete: '
                '${provider.quickResult!.overallLevel.label}. '
                'This is an awareness signal, not a diagnosis.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: QuickAssessmentPalette.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.36,
                ),
              ),
            ),
          const SizedBox(height: 18),
          const _AssessmentFacts(),
          const SizedBox(height: 18),
          const _AgreementScale(),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _openFullAssessment(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: QuickAssessmentPalette.primary,
                foregroundColor: QuickAssessmentPalette.text,
                elevation: 4,
                shadowColor: QuickAssessmentPalette.shadow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text('Take ${role.label} Assessment'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
              },
              style: TextButton.styleFrom(
                foregroundColor: QuickAssessmentPalette.secondaryText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: const Text('Not Now'),
            ),
          ),
        ],
      ),
    );
  }

  static String _messageFor(AssessmentProvider provider, AssessmentRole role) {
    final name = provider.name.trim();
    final prefix = name.isEmpty ? 'Your' : '$name, your';

    return '$prefix quick assessment is saved. Continue for a more detailed ${role.label.toLowerCase()} assessment, or return later.';
  }

  Future<void> _openFullAssessment(BuildContext context) async {
    final userId = await _currentUserId(context);
    if (!context.mounted) return;
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in before starting the full assessment.'),
        ),
      );
      return;
    }

    FullAssessmentEligibility eligibility;
    try {
      eligibility = await context
          .read<AssessmentProvider>()
          .fullAssessmentEligibility(userId);
    } catch (error, stackTrace) {
      debugPrint(
        'Full assessment eligibility check failed: $error\n$stackTrace',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to verify assessment eligibility. Please retry before continuing.',
            ),
          ),
        );
      return;
    }
    if (!context.mounted) return;

    if (!eligibility.canStart) {
      await _showAssessmentLimitDialog(context, eligibility);
      return;
    }

    Navigator.of(context).pushNamed(RouteNames.studentAssessment);
  }

  Future<String?> _currentUserId(BuildContext context) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final liveUserId = await authProvider.resolveAuthenticatedUserId();
      if (liveUserId != null && liveUserId.isNotEmpty) return liveUserId;
    } on ProviderNotFoundException {
      // Standalone previews do not provide a live authentication session.
    }
    return null;
  }

  Future<void> _showAssessmentLimitDialog(
    BuildContext context,
    FullAssessmentEligibility eligibility,
  ) {
    final nextEligibleAt = eligibility.nextEligibleAt;
    final nextEligibleText = nextEligibleAt == null
        ? 'Please try again later.'
        : 'Try again on ${_formatEligibilityDate(nextEligibleAt)}.';

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: QuickAssessmentPalette.card,
        title: const Text('Assessment limit reached'),
        content: Text(
          'You can take the full assessment up to 2 times in 7 days, with 2 days between attempts. $nextEligibleText',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  String _formatEligibilityDate(DateTime date) {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${weekdays[local.weekday - 1]}, ${months[local.month - 1]} ${local.day}, ${local.year} at $hour:$minute $period';
  }
}
