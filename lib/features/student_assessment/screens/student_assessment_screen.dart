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

class _StudentAssessmentScreenState extends State<StudentAssessmentScreen> {
  bool _showSectionIntro = false;
  bool _showReview = false;
  bool _editingFromReview = false;
  bool _movingBack = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AssessmentProvider>();
    _showReview = provider.studentResult != null;
    if (!provider.hasStudentAssessmentStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<AssessmentProvider>().startStudentAssessment();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AssessmentProvider>(
      builder: (context, provider, _) {
        final question = provider.currentStudentQuestion;
        if (question == null) {
          return const Scaffold(
            backgroundColor: QuickAssessmentPalette.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBack(provider);
          },
          child: Scaffold(
            backgroundColor: QuickAssessmentPalette.background,
            appBar: _AssessmentAppBar(
              title: provider.activeAssessmentTitle,
              onBack: () => _handleBack(provider),
              onExit: _requestExit,
              onReview: _editingFromReview
                  ? () => _returnToReview(provider)
                  : null,
            ),
            body: _showReview
                ? _AssessmentReview(
                    provider: provider,
                    onEditSection: (label) => _editSection(provider, label),
                    onSubmit: () => Navigator.of(context).pushReplacementNamed(
                      RouteNames.studentAssessmentComplete,
                    ),
                  )
                : _showSectionIntro
                ? _SectionIntro(
                    section: question.section.label,
                    progressLabel: provider.studentSectionProgressLabel,
                    onContinue: () => setState(() => _showSectionIntro = false),
                  )
                : _QuestionExperience(
                    question: question,
                    answer: provider.currentStudentAnswer,
                    sectionProgress: provider.studentCategoryProgress,
                    sectionProgressLabel: provider.studentCategoryProgressLabel,
                    sectionNumberLabel: provider.studentSectionProgressLabel,
                    movingBack: _movingBack,
                    onSelect: provider.selectCurrentStudentAnswer,
                    onContinue: () => _continue(provider),
                  ),
          ),
        );
      },
    );
  }

  void _continue(AssessmentProvider provider) {
    final previousSection = provider.currentStudentQuestion?.section.label;
    final completed = provider.submitCurrentStudentAnswer();
    if (completed) {
      setState(() {
        _showReview = true;
        _editingFromReview = false;
      });
      return;
    }

    final nextSection = provider.currentStudentQuestion?.section.label;
    final changedSection =
        previousSection != null && nextSection != previousSection;
    if (_editingFromReview && changedSection) {
      _returnToReview(provider);
      return;
    }

    setState(() {
      _movingBack = false;
      _showSectionIntro = changedSection;
    });
  }

  void _handleBack(AssessmentProvider provider) {
    if (_showReview) {
      setState(() {
        _showReview = false;
        _editingFromReview = true;
      });
      return;
    }
    if (_showSectionIntro) {
      setState(() => _showSectionIntro = false);
      provider.goBackStudentQuestion();
      return;
    }
    if (provider.canGoBackStudentQuestion) {
      setState(() => _movingBack = true);
      provider.goBackStudentQuestion();
      return;
    }
    _requestExit();
  }

  void _editSection(AssessmentProvider provider, String section) {
    final index = provider.studentQuestions.indexWhere(
      (question) => question.section.label == section,
    );
    if (index < 0) return;
    provider.goToStudentQuestion(index);
    setState(() {
      _showReview = false;
      _showSectionIntro = false;
      _editingFromReview = true;
      _movingBack = false;
    });
  }

  void _returnToReview(AssessmentProvider provider) {
    provider.prepareStudentResultForReview();
    setState(() {
      _showReview = true;
      _showSectionIntro = false;
      _editingFromReview = false;
    });
  }

  Future<void> _requestExit() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: QuickAssessmentPalette.card,
        title: const Text('Save and exit?'),
        content: const Text(
          'Your answers will stay available when you return during this app session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep answering'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: QuickAssessmentPalette.primary,
              foregroundColor: QuickAssessmentPalette.text,
            ),
            child: const Text('Save & Exit'),
          ),
        ],
      ),
    );
    if (shouldExit != true || !mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
  }
}

class _AssessmentAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AssessmentAppBar({
    required this.title,
    required this.onBack,
    required this.onExit,
    this.onReview,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onExit;
  final VoidCallback? onReview;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: QuickAssessmentPalette.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 64,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      centerTitle: true,
      actions: [
        if (onReview != null)
          TextButton(onPressed: onReview, child: const Text('Review'))
        else
          TextButton(onPressed: onExit, child: const Text('Save & Exit')),
        const SizedBox(width: 8),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: QuickAssessmentPalette.softBorder),
      ),
    );
  }
}

class _QuestionExperience extends StatelessWidget {
  const _QuestionExperience({
    required this.question,
    required this.answer,
    required this.sectionProgress,
    required this.sectionProgressLabel,
    required this.sectionNumberLabel,
    required this.movingBack,
    required this.onSelect,
    required this.onContinue,
  });

  final StudentAssessmentQuestion question;
  final LikertAnswer? answer;
  final double sectionProgress;
  final String sectionProgressLabel;
  final String sectionNumberLabel;
  final bool movingBack;
  final ValueChanged<LikertAnswer> onSelect;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      children: [
        _ProgressHeader(
          section: question.section.label,
          sectionNumberLabel: sectionNumberLabel,
          questionLabel: sectionProgressLabel,
          progress: sectionProgress,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) {
              if (reduceMotion) {
                return FadeTransition(opacity: animation, child: child);
              }
              final offset = movingBack ? -0.025 : 0.025;
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset(offset, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: SingleChildScrollView(
              key: ValueKey(question.id),
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          question.text,
                          style: const TextStyle(
                            color: QuickAssessmentPalette.text,
                            fontSize: 26,
                            height: 1.32,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (question.isConditional) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Follow-up question',
                          style: TextStyle(
                            color: QuickAssessmentPalette.mutedText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 36),
                      for (final option in LikertAnswer.values) ...[
                        _AssessmentOption(
                          answer: option,
                          selected: answer == option,
                          onTap: () => onSelect(option),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        _StickyNavigation(
          enabled: answer != null,
          label: 'Continue',
          onPressed: onContinue,
        ),
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.section,
    required this.sectionNumberLabel,
    required this.questionLabel,
    required this.progress,
  });

  final String section;
  final String sectionNumberLabel;
  final String questionLabel;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$section, $sectionNumberLabel, $questionLabel',
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
        color: QuickAssessmentPalette.card,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        section,
                        style: const TextStyle(
                          color: QuickAssessmentPalette.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      sectionNumberLabel,
                      style: const TextStyle(
                        color: QuickAssessmentPalette.mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0, 1),
                          minHeight: 5,
                          backgroundColor: QuickAssessmentPalette.cream,
                          valueColor: const AlwaysStoppedAnimation(
                            QuickAssessmentPalette.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      questionLabel.replaceFirst(' in this category', ''),
                      style: const TextStyle(
                        color: QuickAssessmentPalette.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssessmentOption extends StatelessWidget {
  const _AssessmentOption({
    required this.answer,
    required this.selected,
    required this.onTap,
  });

  final LikertAnswer answer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: '${answer.value}, ${answer.label}',
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? QuickAssessmentPalette.selectedFill
                  : QuickAssessmentPalette.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? QuickAssessmentPalette.border
                    : QuickAssessmentPalette.softBorder,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? QuickAssessmentPalette.primary
                        : QuickAssessmentPalette.card,
                    border: Border.all(
                      color: selected
                          ? QuickAssessmentPalette.border
                          : QuickAssessmentPalette.mutedText,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: QuickAssessmentPalette.text,
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    answer.label,
                    style: const TextStyle(
                      color: QuickAssessmentPalette.text,
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
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

class _StickyNavigation extends StatelessWidget {
  const _StickyNavigation({
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: QuickAssessmentPalette.card,
        border: Border(
          top: BorderSide(color: QuickAssessmentPalette.softBorder),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: enabled ? onPressed : null,
              style: FilledButton.styleFrom(
                backgroundColor: QuickAssessmentPalette.primary,
                foregroundColor: QuickAssessmentPalette.text,
                disabledBackgroundColor: QuickAssessmentPalette.cream,
                disabledForegroundColor: QuickAssessmentPalette.subtleText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({
    required this.section,
    required this.progressLabel,
    required this.onContinue,
  });

  final String section;
  final String progressLabel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      progressLabel,
                      style: const TextStyle(
                        color: QuickAssessmentPalette.mutedText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      section,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: QuickAssessmentPalette.text,
                        fontSize: 30,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Next section',
                      style: TextStyle(
                        color: QuickAssessmentPalette.secondaryText,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _StickyNavigation(
          enabled: true,
          label: 'Continue',
          onPressed: onContinue,
        ),
      ],
    );
  }
}

class _AssessmentReview extends StatelessWidget {
  const _AssessmentReview({
    required this.provider,
    required this.onEditSection,
    required this.onSubmit,
  });

  final AssessmentProvider provider;
  final ValueChanged<String> onEditSection;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Review your responses',
                      style: TextStyle(
                        color: QuickAssessmentPalette.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Each section is complete. Open a section if you want to review or change an answer before submitting.',
                      style: TextStyle(
                        color: QuickAssessmentPalette.secondaryText,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 28),
                    for (final section in provider.studentSectionLabels) ...[
                      _ReviewSectionTile(
                        label: section,
                        count: provider.studentQuestions
                            .where(
                              (question) => question.section.label == section,
                            )
                            .length,
                        onTap: () => onEditSection(section),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        _StickyNavigation(
          enabled: provider.studentResult != null,
          label: 'Submit Assessment',
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

class _ReviewSectionTile extends StatelessWidget {
  const _ReviewSectionTile({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: QuickAssessmentPalette.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: QuickAssessmentPalette.softBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: QuickAssessmentPalette.border,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: QuickAssessmentPalette.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count questions · Complete',
                      style: const TextStyle(
                        color: QuickAssessmentPalette.mutedText,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
