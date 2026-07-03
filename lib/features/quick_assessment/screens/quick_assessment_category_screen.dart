import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/assessment_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
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
            'Full Assessment Optional',
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
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: QuickAssessmentPalette.cream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: QuickAssessmentPalette.softBorder),
            ),
            child: Text(
              'You can answer the full ${role.label.toLowerCase()} assessment now for deeper insights, or skip it and take it later from your dashboard.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: QuickAssessmentPalette.mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.36,
              ),
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 46,
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
            height: 44,
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

    return '$prefix quick assessment is saved. Your ${role.label.toLowerCase()} answers will choose the right full assessment question set.';
  }

  Future<void> _openFullAssessment(BuildContext context) async {
    final userId = _currentUserId(context);
    if (userId == null || userId.isEmpty) {
      Navigator.of(context).pushNamed(RouteNames.studentAssessment);
      return;
    }

    final canStart = await context
        .read<AssessmentProvider>()
        .canStartFullAssessmentThisWeek(userId);
    if (!context.mounted) return;

    if (!canStart) {
      await _showWeeklyLimitDialog(context);
      return;
    }

    Navigator.of(context).pushNamed(RouteNames.studentAssessment);
  }

  String? _currentUserId(BuildContext context) {
    try {
      final authProvider = context.read<AuthProvider>();
      return authProvider.userId ?? authProvider.hydrateCurrentUser();
    } on ProviderNotFoundException {
      try {
        return context.read<UserProvider>().user?.id;
      } on ProviderNotFoundException {
        return null;
      }
    }
  }

  Future<void> _showWeeklyLimitDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: QuickAssessmentPalette.card,
        title: const Text('Assessment already completed'),
        content: const Text(
          'You can take the main assessment once per week. Your next assessment opens next Monday.',
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
}
