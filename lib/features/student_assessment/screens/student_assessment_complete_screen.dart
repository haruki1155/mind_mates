import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/assessment_provider.dart';
import '../../../routes/route_names.dart';
import '../../quick_assessment/widgets/quick_assessment_widgets.dart';
import '../models/student_assessment_models.dart';

class StudentAssessmentCompleteScreen extends StatefulWidget {
  const StudentAssessmentCompleteScreen({super.key});

  @override
  State<StudentAssessmentCompleteScreen> createState() =>
      _StudentAssessmentCompleteScreenState();
}

class _StudentAssessmentCompleteScreenState
    extends State<StudentAssessmentCompleteScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _backgroundController;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

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

        return Scaffold(
          backgroundColor: QuickAssessmentPalette.background,
          body: SafeArea(
            child: Stack(
              children: [
                _ResultBackground(animation: _backgroundController),
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _Hero(result: result)),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 22),
                      sliver: SliverList.list(
                        children: [
                          _AnimatedResultSection(
                            delay: 0,
                            child: _SummaryCards(result: result),
                          ),
                          const SizedBox(height: 12),
                          _AnimatedResultSection(
                            delay: 50,
                            child: _CategoryBars(result: result),
                          ),
                          const SizedBox(height: 12),
                          _AnimatedResultSection(
                            delay: 90,
                            child: _CategoryScoreDots(result: result),
                          ),
                          const SizedBox(height: 12),
                          const _AnimatedResultSection(
                            delay: 130,
                            child: _PaccCard(),
                          ),
                          const SizedBox(height: 12),
                          const _AnimatedResultSection(
                            delay: 170,
                            child: _ReferencesCard(),
                          ),
                          const SizedBox(height: 12),
                          _AnimatedResultSection(
                            delay: 210,
                            child: _ImportantCard(
                              disclaimer: result.disclaimer,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _AnimatedResultSection(
                            delay: 250,
                            child: _ResultActions(
                              onTalkPressed: () {
                                Navigator.of(
                                  context,
                                ).pushNamed(RouteNames.mindAid);
                              },
                              onContinuePressed: () {
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  RouteNames.home,
                                  (route) => false,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.result});

  final StudentAssessmentResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 480,
      decoration: const BoxDecoration(color: QuickAssessmentPalette.primary),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 352,
            left: -80,
            right: -80,
            child: Container(
              height: 190,
              decoration: const BoxDecoration(
                color: QuickAssessmentPalette.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(160)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeroBadge(),
                const SizedBox(height: 14),
                const Text(
                  'Assessment Complete',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ResultPalette.text,
                    fontSize: 26,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Here are your personalized insights',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ResultPalette.secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                _ScoreGauge(score: result.overallScore, status: result.status),
              ],
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
      width: 52,
      height: 52,
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

  final double score;
  final String status;

  @override
  State<_ScoreGauge> createState() => _ScoreGaugeState();
}

class _ScoreGaugeState extends State<_ScoreGauge> {
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: widget.score),
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
                  'Overall Score',
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
                            animatedScore.round().toString(),
                            style: const TextStyle(
                              color: _ResultPalette.text,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              height: 0.95,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '/ 100',
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
                const Text(
                  'Higher score means higher concern level',
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
    return Column(
      children: [
        _InfoCard(title: 'Assessment Result', body: result.message),
        const SizedBox(height: 10),
        const _InfoCard(
          title: 'Interpretation',
          body:
              'Scores in this range indicate moderate levels of stress or difficulty. Without intervention, these may escalate and affect your overall functioning.',
        ),
        const SizedBox(height: 10),
        _InsightsCard(result: result),
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

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.result});

  final StudentAssessmentResult result;

  @override
  Widget build(BuildContext context) {
    final concerns = result.mainConcernAreas.isEmpty
        ? ['Sleep and Rest', 'Academic Stress', 'Emotional Well-Being']
        : result.mainConcernAreas;
    final insights = [
      '${concerns.first} is your most disrupted area - establish a consistent routine and consult a physician if symptoms persist.',
      'Sleep quality and emotional balance may need intentional attention.',
      'Building a stronger support network would be beneficial.',
      'Speaking with a PACC counselor is recommended for personalized support.',
    ];

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personalized Insights', style: _ResultText.title),
          const SizedBox(height: 12),
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
      backgroundColor: const Color(0xFFFFFAEC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Score by Category', style: _ResultText.title),
          const SizedBox(height: 16),
          for (final entry in result.subscaleScores.entries.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: _ScoreBar(
                label: entry.$2.key,
                score: entry.$2.value,
                staggerIndex: entry.$1,
              ),
            ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '* Higher bar = higher concern in that area',
              style: TextStyle(
                color: _ResultPalette.mutedText,
                fontSize: 11,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.label,
    required this.score,
    required this.staggerIndex,
  });

  final String label;
  final double score;
  final int staggerIndex;

  @override
  Widget build(BuildContext context) {
    final duration = Duration(milliseconds: 430 + (staggerIndex * 45));

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score / 100),
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
                    label,
                    style: const TextStyle(
                      color: _ResultPalette.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${(score * value).round()}%',
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
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white,
                valueColor: const AlwaysStoppedAnimation(
                  QuickAssessmentPalette.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

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
          Text('Score by Category', style: _ResultText.title),
          const SizedBox(height: 8),
          const Text(
            'Multiple dimensions show moderate concern. Taking proactive steps now - including counseling, self-care routines, and support-seeking - can significantly improve your well-being.',
            style: _ResultText.body,
          ),
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
                  'PAACC Counseling Office',
                  style: TextStyle(
                    color: _ResultPalette.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Urdaneta City University - 1st Floor, Lai Building\n+63 912 345 6789\npacc@ucu.edu.ph',
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
    'Academic Stress and Student Well-Being': [
      'World Health Organization. Mental health and COVID-19: Early evidence of the pandemic impact.',
      'American Psychological Association. Psychological assessment and evaluation.',
      'Tan, J., Cruz, M., & Reyes, P. Needs assessment of mental health challenges among university students in the Philippines.',
      'American School Counselor Association. ASCA National Model.',
    ],
    'Financial Stress': [
      'American Psychological Association. Stress in America Report.',
      'World Health Organization. Mental health and well-being.',
      'Department of Health Philippines. Philippine Mental Health Program.',
    ],
    'Sleep and Rest': [
      'World Health Organization. Mental health: Strengthening our response.',
      'National Sleep Foundation. Sleep Health Recommendations.',
      'American Psychological Association. Sleep and mental health.',
    ],
    'Emotional Well-Being': [
      'World Health Organization. Mental health: Strengthening our response.',
      'Philippine Mental Health Association. Mental Health Promotion and Wellness.',
      'Psychological Association of the Philippines. Mental health promotion and ethical psychological practice.',
    ],
    'Social Support and Help-Seeking': [
      'Philippine Mental Health Association. Mental health promotion and wellness.',
      'World Health Organization. Mental health and community support.',
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
              'References',
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
    required this.onContinuePressed,
  });

  final VoidCallback onTalkPressed;
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
          height: 46,
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
      width: 14,
      height: 14,
      decoration: const BoxDecoration(
        color: QuickAssessmentPalette.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: const TextStyle(
          color: _ResultPalette.text,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.backgroundColor = QuickAssessmentPalette.card,
    this.borderColor = QuickAssessmentPalette.softBorder,
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: QuickAssessmentPalette.shadow.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
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
