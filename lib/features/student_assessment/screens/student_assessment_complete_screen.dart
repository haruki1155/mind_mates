import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/assessment_provider.dart';
import '../../../core/config/support_contact_config.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/report_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../routes/route_names.dart';
import '../../../services/firebase/firebase_error_message.dart';
import '../../quick_assessment/widgets/quick_assessment_widgets.dart';
import '../models/student_assessment_models.dart';
import '../models/assessment_interpretation_models.dart';

class StudentAssessmentCompleteScreen extends StatefulWidget {
  const StudentAssessmentCompleteScreen({super.key});

  @override
  State<StudentAssessmentCompleteScreen> createState() =>
      _StudentAssessmentCompleteScreenState();
}

class _StudentAssessmentCompleteScreenState
    extends State<StudentAssessmentCompleteScreen> {
  bool _requestedSave = false;
  String? _saveError;

  @override
  Widget build(BuildContext context) {
    return Consumer<AssessmentProvider>(
      builder: (context, provider, _) {
        final result = provider.studentResult;
        if (result == null) {
          return Scaffold(
            backgroundColor: QuickAssessmentPalette.background,
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushReplacementNamed(RouteNames.studentAssessment),
                child: const Text('Start Assessment'),
              ),
            ),
          );
        }

        _saveResultIfNeeded(provider);

        if (!provider.hasVerifiedStudentResult) {
          return Scaffold(
            backgroundColor: QuickAssessmentPalette.background,
            body: SafeArea(
              child: _SubmissionState(
                error: _saveError,
                onRetry: _retrySubmission,
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: QuickAssessmentPalette.background,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Hero(result: result),
                      const SizedBox(height: 16),
                      _SummaryCards(result: result),
                      const SizedBox(height: 16),
                      _ResultActions(
                        onTalkPressed: () =>
                            Navigator.of(context).pushNamed(RouteNames.mindAid),
                        onSupportPressed: () => Navigator.of(
                          context,
                        ).pushNamed(RouteNames.services),
                        onContinuePressed: () {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            RouteNames.home,
                            (route) => false,
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      const _PaccCard(),
                      const SizedBox(height: 16),
                      _DetailedResults(result: result),
                      const SizedBox(height: 16),
                      _PilotFeedbackCard(
                        onSelected: provider.saveAssessmentClarityFeedback,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _saveResultIfNeeded(AssessmentProvider provider) {
    if (_requestedSave || provider.studentResult == null) return;
    _requestedSave = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final userId = await _currentUserId();
      if (!mounted) return;
      if (userId == null || userId.isEmpty) {
        setState(
          () => _saveError = 'Please sign in again to save this assessment.',
        );
        return;
      }

      Map<String, Object>? payload;
      try {
        payload = await provider.saveStudentAssessmentForUser(userId);
      } catch (error, stackTrace) {
        FirebaseErrorMessage.log(
          error,
          stackTrace,
          area: 'Student assessment sync failed.',
        );
        if (mounted) {
          setState(
            () => _saveError = FirebaseErrorMessage.describe(
              error,
              fallback:
                  'We could not verify your assessment yet. Check your connection and try again.',
            ),
          );
        }
        return;
      }
      if (payload == null) {
        if (mounted) {
          setState(() => _saveError = 'Sign in to save this assessment.');
        }
        return;
      }

      // Only the verified callable response controls submission state. These
      // refreshes are best-effort and cannot invalidate a persisted result.
      try {
        if (mounted) await context.read<UserProvider>().loadProfile(userId);
      } catch (error, stackTrace) {
        FirebaseErrorMessage.log(
          error,
          stackTrace,
          area: 'Full assessment profile refresh failed after verified save.',
        );
      }
      try {
        if (mounted) await _reportProviderOrNull()?.refreshWeeklyReport(userId);
      } catch (error, stackTrace) {
        FirebaseErrorMessage.log(
          error,
          stackTrace,
          area: 'Weekly report refresh failed after verified assessment save.',
        );
      }
    });
  }

  void _retrySubmission() {
    setState(() {
      _requestedSave = false;
      _saveError = null;
    });
  }

  ReportProvider? _reportProviderOrNull() {
    try {
      return context.read<ReportProvider>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<String?> _currentUserId() async {
    AuthProvider? authProvider;
    try {
      authProvider = context.read<AuthProvider>();
      final userId = await authProvider.resolveAuthenticatedUserId();
      if (userId != null && userId.isNotEmpty) return userId;
      if (!mounted) return null;
    } on ProviderNotFoundException {
      // Tests and preview surfaces may provide only UserProvider.
    }

    if (authProvider != null) return null;

    try {
      final userId = context.read<UserProvider>().user?.id;
      if (userId != null && userId.isNotEmpty) return userId;
    } on ProviderNotFoundException {
      // No profile provider means this surface cannot save a result.
    }

    return null;
  }
}

class _SubmissionState extends StatelessWidget {
  const _SubmissionState({required this.error, required this.onRetry});

  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = error != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed ? Icons.cloud_off_rounded : Icons.verified_user_outlined,
              size: 52,
              color: QuickAssessmentPalette.primary,
            ),
            const SizedBox(height: 16),
            Text(
              failed ? 'Assessment not submitted' : 'Preparing your results…',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              error ??
                  'Your summary will appear after your assessment is securely submitted.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 20),
            if (failed)
              Column(
                children: [
                  const Text(
                    'Your responses are still available for this retry.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Try Again'),
                  ),
                ],
              )
            else
              const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.result});

  final StudentAssessmentResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
      decoration: BoxDecoration(
        color: QuickAssessmentPalette.primary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: QuickAssessmentPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HeroBadge(),
          const SizedBox(height: 18),
          const Text(
            'Your Assessment Summary',
            style: TextStyle(
              color: _ResultPalette.text,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: QuickAssessmentPalette.card.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              result.interpretation.supportPriority.label,
              style: const TextStyle(
                color: _ResultPalette.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            result.interpretation.userSummary,
            style: const TextStyle(
              color: _ResultPalette.secondaryText,
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: QuickAssessmentPalette.shadow,
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.favorite_rounded,
        color: Color(0xFFFF5B69),
        size: 28,
      ),
    );
  }
}

class _ScoreGauge extends StatefulWidget {
  const _ScoreGauge({required this.score, required this.status});

  final double? score;
  final String status;

  @override
  State<_ScoreGauge> createState() => _ScoreGaugeState();
}

class _ScoreGaugeState extends State<_ScoreGauge> {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.score ?? 0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutQuart,
      builder: (context, animatedScore, _) {
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 268),
          child: Container(
            width: 252,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            decoration: BoxDecoration(
              color: QuickAssessmentPalette.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: QuickAssessmentPalette.softBorder),
              boxShadow: [
                BoxShadow(
                  color: QuickAssessmentPalette.shadow,
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Secondary overall concern index',
                  style: TextStyle(
                    color: _ResultPalette.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 128,
                  height: 128,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size.square(128),
                        painter: _ScoreRingPainter(
                          progress: animatedScore / 100,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.score == null
                                ? '—'
                                : animatedScore.round().toString(),
                            style: const TextStyle(
                              color: _ResultPalette.text,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              height: 0.95,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.score == null ? 'Not available' : '/ 100',
                            style: TextStyle(
                              color: _ResultPalette.mutedText,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: QuickAssessmentPalette.cream,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: QuickAssessmentPalette.primary.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Concern level',
                          style: TextStyle(
                            color: _ResultPalette.secondaryText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            widget.status,
                            maxLines: 1,
                            style: const TextStyle(
                              color: _ResultPalette.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.score == null
                      ? 'More answers are needed in one or more categories.'
                      : 'This summarizes category patterns; it is not a mental-health grade.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ResultPalette.mutedText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final clampedProgress = progress.clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..color = const Color(0xFFEDE9DD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = QuickAssessmentPalette.primary.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFD64D), QuickAssessmentPalette.primary],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    const startAngle = -1.5707963267948966;
    final sweepAngle = 6.283185307179586 * clampedProgress;

    canvas.drawCircle(center, radius, trackPaint);
    if (clampedProgress > 0) {
      canvas.drawArc(rect, startAngle, sweepAngle, false, glowPaint);
      canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Retained temporarily for compatibility with pending visual snapshots.
// ignore: unused_element
class _ResultBackground extends StatelessWidget {
  const _ResultBackground({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    const bubbles = [
      _ResultBubble(-18, 128, 23, QuickAssessmentPalette.grayBubble),
      _ResultBubble(138, 408, 34, QuickAssessmentPalette.softBubble),
      _ResultBubble(316, 708, 24, QuickAssessmentPalette.primary),
      _ResultBubble(16, 930, 34, QuickAssessmentPalette.softBubble),
      _ResultBubble(304, 1138, 42, QuickAssessmentPalette.primary),
      _ResultBubble(54, 1440, 28, QuickAssessmentPalette.grayBubble),
      _ResultBubble(318, 1660, 34, QuickAssessmentPalette.softBubble),
    ];

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return Stack(
              children: [
                const BubbleCluster(top: -34, left: -30),
                for (var index = 0; index < bubbles.length; index += 1)
                  Positioned(
                    left:
                        bubbles[index].left +
                        (index.isEven ? 1 : -1) * animation.value * 6,
                    top:
                        bubbles[index].top +
                        (index.isEven ? -1 : 1) * animation.value * 8,
                    child: Container(
                      width: bubbles[index].size,
                      height: bubbles[index].size,
                      decoration: BoxDecoration(
                        color: bubbles[index].color.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ResultBubble {
  const _ResultBubble(this.left, this.top, this.size, this.color);

  final double left;
  final double top;
  final double size;
  final Color color;
}

// ignore: unused_element
class _AnimatedResultSection extends StatelessWidget {
  const _AnimatedResultSection({required this.child, required this.delay});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + delay),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        final progress = ((value * (280 + delay) - delay) / 280).clamp(
          0.0,
          1.0,
        );

        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.result});

  final StudentAssessmentResult result;

  @override
  Widget build(BuildContext context) {
    final domains =
        result.interpretation.domainResults
            .where((domain) => domain.isScorable)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    final focusDomains = domains.take(2).toList(growable: false);
    final suggestedAction = result.interpretation.suggestedActions.firstOrNull;
    final nextStep = suggestedAction != null && suggestedAction.isNotEmpty
        ? suggestedAction
        : result.interpretation.priorityRationale.isNotEmpty
        ? result.interpretation.priorityRationale
        : result.interpretation.userSummary;

    return Column(
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Areas to pay attention to', style: _ResultText.title),
              const SizedBox(height: 14),
              if (focusDomains.isEmpty)
                const Text(
                  'There were not enough responses to identify focus areas.',
                  style: _ResultText.body,
                )
              else
                for (final entry in focusDomains.indexed) ...[
                  _DomainSummaryRow(number: entry.$1 + 1, domain: entry.$2),
                  if (entry.$1 != focusDomains.length - 1)
                    const Divider(height: 24),
                ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _InfoCard(title: 'Recommended next step', body: nextStep),
      ],
    );
  }
}

class _DomainSummaryRow extends StatelessWidget {
  const _DomainSummaryRow({required this.number, required this.domain});

  final int number;
  final AssessmentDomainResult domain;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MiniNumber(number: number),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(domain.domain, style: _ResultText.title),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    domain.band.label,
                    style: const TextStyle(
                      color: _ResultPalette.secondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(domain.interpretation, style: _ResultText.body),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _ResultText.title),
          const SizedBox(height: 11),
          Text(body, style: _ResultText.body),
        ],
      ),
    );
  }
}

class _PilotFeedbackCard extends StatefulWidget {
  const _PilotFeedbackCard({required this.onSelected});

  final Future<void> Function(String clarity) onSelected;

  @override
  State<_PilotFeedbackCard> createState() => _PilotFeedbackCardState();
}

class _PilotFeedbackCardState extends State<_PilotFeedbackCard> {
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Help improve this university pilot', style: _ResultText.title),
          const SizedBox(height: 8),
          Text(
            _submitted
                ? 'Thank you. Your anonymous clarity rating was recorded.'
                : 'Were your category results easy to understand? No written response or user ID is stored.',
            style: _ResultText.body,
          ),
          if (!_submitted) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _feedbackButton('Clear', 'clear'),
                _feedbackButton('Partly clear', 'partlyClear'),
                _feedbackButton('Unclear', 'unclear'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _feedbackButton(String label, String value) {
    return OutlinedButton(
      onPressed: () async {
        try {
          await widget.onSelected(value);
          if (mounted) setState(() => _submitted = true);
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to save feedback right now.')),
          );
        }
      },
      child: Text(label),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.result});

  final StudentAssessmentResult result;

  @override
  Widget build(BuildContext context) {
    final interpretation = result.interpretation;
    final insights = <String>[
      ...interpretation.rationale,
      ...interpretation.protectiveFactors.map(
        (factor) => 'Protective strength: $factor',
      ),
      ...interpretation.functionalImpactFlags.map(
        (flag) => 'Functional-impact observation: $flag',
      ),
      ...interpretation.suggestedActions,
    ];

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What your responses suggest', style: _ResultText.title),
          const SizedBox(height: 12),
          if (insights.isEmpty)
            const Text(
              'No specific concern pattern was identified from the responses provided.',
              style: _ResultText.body,
            ),
          for (var index = 0; index < insights.length; index += 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MiniNumber(number: index + 1),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(insights[index], style: _ResultText.body),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.result});

  final StudentAssessmentResult result;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Domain details', style: _ResultText.title),
          const SizedBox(height: 16),
          for (final entry in result.interpretation.domainResults.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ScoreBar(domain: entry.$2, staggerIndex: entry.$1),
            ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.domain, required this.staggerIndex});

  final AssessmentDomainResult domain;
  final int staggerIndex;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(milliseconds: 430 + (staggerIndex * 45));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: domain.isScorable ? domain.score / 100 : 0),
      duration: duration,
      curve: Curves.easeOutQuart,
      builder: (context, value, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    domain.domain,
                    style: const TextStyle(
                      color: _ResultPalette.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  domain.isScorable
                      ? '${(domain.score * value).round()}% · ${domain.band.label}'
                      : 'Insufficient responses',
                  style: const TextStyle(
                    color: _ResultPalette.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: domain.isScorable ? value : null,
                minHeight: 8,
                backgroundColor: Colors.white,
                valueColor: const AlwaysStoppedAnimation(
                  QuickAssessmentPalette.primary,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${domain.interpretation} ${domain.suggestedAction} '
              '${domain.answeredCount}/${domain.presentedCount} core questions answered.',
              style: const TextStyle(
                color: _ResultPalette.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        );
      },
    );
  }
}

// Kept as a private legacy layout while old golden snapshots are migrated.
// It is intentionally not mounted on the user-facing result screen.
// ignore: unused_element
class _CategoryScoreDots extends StatelessWidget {
  const _CategoryScoreDots({required this.result});

  final StudentAssessmentResult result;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      borderColor: const Color(0xFFE66767),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Domain interpretation', style: _ResultText.title),
          const SizedBox(height: 8),
          Text(result.interpretation.userSummary, style: _ResultText.body),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: result.subscaleScores.entries
                .map((entry) => _ScoreBox(label: entry.key, score: entry.value))
                .toList(),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Total responses: ${result.totalResponses}',
              style: const TextStyle(
                color: _ResultPalette.secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({required this.label, required this.score});

  final String label;
  final double score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 60
        ? const Color(0xFFFF3B30)
        : score >= 40
        ? const Color(0xFFFFB900)
        : const Color(0xFF75E000);

    return Container(
      width: 58,
      height: 66,
      decoration: BoxDecoration(
        color: QuickAssessmentPalette.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            score.round().toString(),
            style: const TextStyle(
              color: _ResultPalette.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            _shortLabel(label),
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              color: _ResultPalette.secondaryText,
              fontSize: 7.4,
              fontWeight: FontWeight.w700,
              height: 1.08,
            ),
          ),
        ],
      ),
    );
  }

  static String _shortLabel(String label) {
    switch (label) {
      case 'Academic Stress':
        return 'Academic\nStress';
      case 'Financial Well-Being':
        return 'Financial\nWell-being';
      case 'Social Adjustment':
        return 'Social\nAdjustment';
      case 'Workplace Stress':
        return 'Workplace\nStress';
      case 'Professional Support':
        return 'Prof.\nSupport';
      case 'Professional Well-Being':
        return 'Prof.\nWell-being';
      case 'Workplace Responsibilities':
        return 'Work\nDuties';
      case 'Workplace Support':
        return 'Work\nSupport';
      case 'Workplace Well-Being':
        return 'Work\nWell-being';
      case 'Sleep and Rest':
        return 'Sleep\nRest';
      case 'Emotional Well-Being':
        return 'Emotional\nWell-being';
      default:
        return label;
    }
  }
}

class _DetailedResults extends StatelessWidget {
  const _DetailedResults({required this.result});

  final StudentAssessmentResult result;

  @override
  Widget build(BuildContext context) {
    final quality = result.interpretation.responseQuality;
    return _Panel(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 12),
          title: const Text(
            'View detailed results',
            style: TextStyle(
              color: _ResultPalette.text,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: const Text(
            'Domains, strengths, response completeness, and methodology',
            style: TextStyle(
              color: _ResultPalette.mutedText,
              fontSize: 13,
              height: 1.3,
            ),
          ),
          children: [
            _CategoryBars(result: result),
            const SizedBox(height: 12),
            _InsightsCard(result: result),
            const SizedBox(height: 12),
            _InfoCard(
              title: 'Response completeness',
              body:
                  '${quality.confidence.label}. ${quality.answered} of ${quality.presented} presented questions were answered.',
            ),
            const SizedBox(height: 12),
            const _ReferencesCard(),
            const SizedBox(height: 12),
            _ImportantCard(disclaimer: result.disclaimer),
          ],
        ),
      ),
    );
  }
}

class _PaccCard extends StatelessWidget {
  const _PaccCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: QuickAssessmentPalette.primary,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: QuickAssessmentPalette.shadow,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.support_agent_rounded, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Support contact information',
                  style: TextStyle(
                    color: _ResultPalette.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  SupportContactConfig.safeFallback,
                  style: TextStyle(
                    color: _ResultPalette.secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferencesCard extends StatelessWidget {
  const _ReferencesCard();

  static const sections = {
    'Validation status': [
      'No documented validation source was found for the exact questions, weights, score ranges, completion rules, or follow-up combinations.',
      'The current values are internal experimental product rules retained for compatibility and require qualified professional review.',
      'General wellness publications must not be interpreted as validation of this scoring policy.',
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: QuickAssessmentPalette.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: QuickAssessmentPalette.softBorder),
        boxShadow: [
          BoxShadow(
            color: QuickAssessmentPalette.shadow.withValues(alpha: 0.11),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: QuickAssessmentPalette.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: const Text(
              'Method disclosure',
              style: TextStyle(
                color: _ResultPalette.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          for (final section in sections.entries)
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
                splashColor: QuickAssessmentPalette.primary.withValues(
                  alpha: 0.08,
                ),
              ),
              child: Material(
                color: QuickAssessmentPalette.card,
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 13),
                  childrenPadding: const EdgeInsets.fromLTRB(13, 0, 13, 12),
                  iconColor: _ResultPalette.text,
                  collapsedIconColor: _ResultPalette.secondaryText,
                  title: Text(section.key, style: _ResultText.title),
                  children: [
                    for (final item in section.value) ...[
                      _ReferenceItem(text: item),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReferenceItem extends StatelessWidget {
  const _ReferenceItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: QuickAssessmentPalette.softBorder),
      ),
      child: Text(text, style: _ResultText.body),
    );
  }
}

class _ImportantCard extends StatelessWidget {
  const _ImportantCard({required this.disclaimer});

  final String disclaimer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: QuickAssessmentPalette.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Important:', style: _ResultText.title),
          const SizedBox(height: 8),
          Text(disclaimer, style: _ResultText.body),
        ],
      ),
    );
  }
}

class _ResultActions extends StatelessWidget {
  const _ResultActions({
    required this.onTalkPressed,
    required this.onSupportPressed,
    required this.onContinuePressed,
  });

  final VoidCallback onTalkPressed;
  final VoidCallback onSupportPressed;
  final VoidCallback onContinuePressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: onTalkPressed,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
            label: const Text('Talk with MindAid about this'),
            style: ElevatedButton.styleFrom(
              backgroundColor: QuickAssessmentPalette.text,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 5,
              shadowColor: QuickAssessmentPalette.shadow,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onSupportPressed,
            icon: const Icon(Icons.support_agent_outlined, size: 19),
            label: const Text('Find Support'),
            style: OutlinedButton.styleFrom(
              foregroundColor: QuickAssessmentPalette.text,
              side: const BorderSide(color: QuickAssessmentPalette.softBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            onPressed: onContinuePressed,
            style: OutlinedButton.styleFrom(
              backgroundColor: QuickAssessmentPalette.primary,
              foregroundColor: QuickAssessmentPalette.text,
              side: BorderSide(
                color: QuickAssessmentPalette.text.withValues(alpha: 0.18),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            child: const Text('Continue to MindMate'),
          ),
        ),
      ],
    );
  }
}

class _MiniNumber extends StatelessWidget {
  const _MiniNumber({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: QuickAssessmentPalette.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          color: _ResultPalette.text,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.borderColor = QuickAssessmentPalette.softBorder,
  });

  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: QuickAssessmentPalette.card,
      shadowColor: QuickAssessmentPalette.shadow,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _ResultText {
  const _ResultText._();

  static const title = TextStyle(
    color: _ResultPalette.text,
    fontSize: 14,
    fontWeight: FontWeight.w900,
    height: 1.2,
  );
  static const body = TextStyle(
    color: _ResultPalette.secondaryText,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    height: 1.42,
  );
}

class _ResultPalette {
  const _ResultPalette._();

  static const text = QuickAssessmentPalette.text;
  static const secondaryText = QuickAssessmentPalette.secondaryText;
  static const mutedText = QuickAssessmentPalette.mutedText;
}
