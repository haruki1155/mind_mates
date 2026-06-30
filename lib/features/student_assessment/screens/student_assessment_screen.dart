import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/assessment_provider.dart';
import '../../../routes/route_names.dart';
import '../../quick_assessment/widgets/quick_assessment_widgets.dart';
import '../models/student_assessment_models.dart';

class StudentAssessmentScreen extends StatefulWidget {
  const StudentAssessmentScreen({super.key});

  @override
  State<StudentAssessmentScreen> createState() =>
      _StudentAssessmentScreenState();
}

class _StudentAssessmentScreenState extends State<StudentAssessmentScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _backgroundController;

  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AssessmentProvider>().startStudentAssessment();
    });
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
        final question = provider.currentStudentQuestion;
        if (question == null) {
          return const Scaffold(
            backgroundColor: _StudentPalette.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: _StudentPalette.background,
          body: SafeArea(
            child: Stack(
              children: [
                _FloatingBubbles(animation: _backgroundController),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AssessmentHeader(
                      progress: provider.studentProgress,
                      title: provider.activeAssessmentTitle,
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOutQuart,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final curved = CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutQuart,
                            reverseCurve: Curves.easeInCubic,
                          );
                          final slide = Tween<Offset>(
                            begin: const Offset(0.04, 0.01),
                            end: Offset.zero,
                          ).animate(curved);

                          return FadeTransition(
                            opacity: curved,
                            child: SlideTransition(
                              position: slide,
                              child: ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.985,
                                  end: 1,
                                ).animate(curved),
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: _QuestionBody(
                          key: ValueKey(question.id),
                          question: question,
                          onAnswer: (answer) {
                            final wasLast = provider.isLastStudentQuestion;
                            provider.answerCurrentStudentQuestion(answer);
                            if (wasLast && context.mounted) {
                              Navigator.of(context).pushReplacementNamed(
                                RouteNames.studentAssessmentComplete,
                              );
                            }
                          },
                          onSkip: () {
                            final wasLast = provider.isLastStudentQuestion;
                            provider.skipCurrentStudentQuestion();
                            if (wasLast && context.mounted) {
                              Navigator.of(context).pushReplacementNamed(
                                RouteNames.studentAssessmentComplete,
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    const _SecureFooter(),
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

class _AssessmentHeader extends StatelessWidget {
  const _AssessmentHeader({required this.progress, required this.title});

  final double progress;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(19, 34, 19, 12),
      decoration: BoxDecoration(
        color: _StudentPalette.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
        boxShadow: [
          BoxShadow(
            color: QuickAssessmentPalette.shadow,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _StudentPalette.text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Answer honestly for the best insights',
                      style: TextStyle(
                        color: _StudentPalette.secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _StudentPalette.border,
                          width: 0.8,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: progress.clamp(0, 1),
                              ),
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: value,
                                  heightFactor: 1,
                                  child: child,
                                );
                              },
                              child: Container(color: _StudentPalette.text),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: (progress * 100).round()),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Text(
                    '$value%',
                    style: const TextStyle(
                      color: _StudentPalette.text,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionBody extends StatelessWidget {
  const _QuestionBody({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.onSkip,
  });

  final StudentAssessmentQuestion question;
  final ValueChanged<LikertAnswer> onAnswer;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(21, 18, 21, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _SectionPill(label: question.section.label),
              const Spacer(),
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: _StudentPalette.secondaryText,
                  minimumSize: const Size(0, 28),
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Skip'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            question.text,
            style: const TextStyle(
              color: _StudentPalette.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 52),
          for (final answer in LikertAnswer.values) ...[
            _LikertOption(answer: answer, onTap: () => onAnswer(answer)),
            const SizedBox(height: 13),
          ],
          const SizedBox(height: 30),
          const Text(
            'Tap your answer to continue to the next question',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _StudentPalette.mutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionPill extends StatelessWidget {
  const _SectionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
      decoration: BoxDecoration(
        color: _StudentPalette.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _StudentPalette.primary, width: 2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _StudentPalette.text,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LikertOption extends StatefulWidget {
  const _LikertOption({required this.answer, required this.onTap});

  final LikertAnswer answer;
  final VoidCallback onTap;

  @override
  State<_LikertOption> createState() => _LikertOptionState();
}

class _LikertOptionState extends State<_LikertOption> {
  bool _pressed = false;

  void _handleTap() {
    if (_pressed) return;

    setState(() => _pressed = true);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final isNeutral = widget.answer == LikertAnswer.sometimes;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOutCubic,
      child: Material(
        color: isNeutral
            ? QuickAssessmentPalette.selectedFill
            : _StudentPalette.card,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(10),
          splashColor: _StudentPalette.primary.withValues(alpha: 0.18),
          highlightColor: _StudentPalette.primary.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 44,
            padding: const EdgeInsets.fromLTRB(13, 0, 18, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _pressed
                    ? _StudentPalette.border
                    : _StudentPalette.softBorder,
                width: _pressed ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: QuickAssessmentPalette.shadow.withValues(
                    alpha: _pressed ? 0.11 : 0.07,
                  ),
                  blurRadius: _pressed ? 14 : 8,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                _NumberBadge(answer: widget.answer),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    widget.answer.label,
                    style: const TextStyle(
                      color: _StudentPalette.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.answer});

  final LikertAnswer answer;

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFFF1010),
      const Color(0xFFFF7A00),
      const Color(0xFFFFC400),
      const Color(0xFFA6FF00),
      const Color(0xFF00D326),
    ];

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: colors[answer.index],
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '${answer.value}',
        style: const TextStyle(
          color: _StudentPalette.text,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SecureFooter extends StatelessWidget {
  const _SecureFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: _StudentPalette.card,
        border: Border.all(color: _StudentPalette.softBorder),
        boxShadow: [
          BoxShadow(
            color: QuickAssessmentPalette.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'Your responses are confidential and secure',
        style: TextStyle(
          color: _StudentPalette.secondaryText,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FloatingBubbles extends StatelessWidget {
  const _FloatingBubbles({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    const bubbles = [
      _Bubble(8, 120, 39, Color(0xFFD2C7A4)),
      _Bubble(80, 132, 40, Color(0xFFFFE28D)),
      _Bubble(154, 175, 37, Color(0xFFFFE28D)),
      _Bubble(242, 180, 39, Color(0xFFFFF9F0)),
      _Bubble(335, 110, 42, Color(0xFFFFE28D)),
      _Bubble(312, 488, 40, Color(0xFFD2C7A4)),
      _Bubble(198, 555, 38, Color(0xFFFFE28D)),
      _Bubble(52, 600, 39, Color(0xFFFFE28D)),
      _Bubble(252, 650, 37, Color(0xFFFFF9F0)),
    ];

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return Stack(
              children: [
                for (var index = 0; index < bubbles.length; index += 1)
                  Positioned(
                    left:
                        bubbles[index].left +
                        (index.isEven ? 1 : -1) * animation.value * 5,
                    top:
                        bubbles[index].top +
                        (index.isEven ? -1 : 1) * animation.value * 4,
                    child: Container(
                      width: bubbles[index].size,
                      height: bubbles[index].size,
                      decoration: BoxDecoration(
                        color: bubbles[index].color.withValues(alpha: 0.38),
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

class _Bubble {
  const _Bubble(this.left, this.top, this.size, this.color);

  final double left;
  final double top;
  final double size;
  final Color color;
}

class _StudentPalette {
  const _StudentPalette._();

  static const background = QuickAssessmentPalette.background;
  static const primary = QuickAssessmentPalette.primary;
  static const card = QuickAssessmentPalette.card;
  static const border = QuickAssessmentPalette.border;
  static const softBorder = QuickAssessmentPalette.softBorder;
  static const text = QuickAssessmentPalette.text;
  static const secondaryText = QuickAssessmentPalette.secondaryText;
  static const mutedText = QuickAssessmentPalette.mutedText;
}
