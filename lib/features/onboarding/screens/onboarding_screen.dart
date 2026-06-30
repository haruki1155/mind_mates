import 'package:flutter/material.dart';

import '../../../routes/route_names.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingData(
      title: 'Track Your Mind Rhythm',
      description:
          'Notice emotional patterns over time and understand what your day is trying to tell you.',
      iconPath: 'assets/images/ONBOARDING_1/Target.png',
      accentColor: Color(0xFFFFC944),
    ),
    _OnboardingData(
      title: 'Share What Feels Heavy',
      description:
          'Write private reflections or anonymous thoughts in a space built for honesty and care.',
      iconPath: 'assets/images/ONBOARDING_2/Thought Balloon.png',
      accentColor: Color(0xFFBFE3D6),
    ),
    _OnboardingData(
      title: 'Build Gentle Habits',
      description:
          'Try small daily quests that make emotional check-ins feel possible, not overwhelming.',
      iconPath: 'assets/images/ONBOARDING_3/Creativity.png',
      accentColor: Color(0xFFFFDFA0),
    ),
    _OnboardingData(
      title: 'Find Support Sooner',
      description:
          'Reach campus resources, counseling help, and calming tools when you need someone beside you.',
      iconPath: 'assets/images/ONBOARDING_4/ONBOARDING 4/Sparkling.png',
      accentColor: Color(0xFFD9D2F2),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      Navigator.of(
        context,
      ).pushReplacementNamed(RouteNames.quickAssessmentRole);
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: _OnboardingColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const _SoftCircle(top: -72, left: -80, size: 190),
            const _SoftCircle(top: 32, right: -76, size: 148, muted: true),
            PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double delta = 0;
                    if (_pageController.hasClients &&
                        _pageController.page != null) {
                      delta = (_pageController.page! - index).clamp(-1.0, 1.0);
                    }

                    return Opacity(
                      opacity: 1 - (delta.abs() * 0.12),
                      child: Transform.translate(
                        offset: Offset(delta * -18, 0),
                        child: child,
                      ),
                    );
                  },
                  child: _OnboardingPage(data: _pages[index]),
                );
              },
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(28, 0, 28, 22 + bottomPadding),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PageIndicator(
                        count: _pages.length,
                        currentIndex: _currentPage,
                      ),
                      const SizedBox(height: 22),
                      _NextButton(
                        label: _currentPage == _pages.length - 1
                            ? 'Start checking in'
                            : 'Next',
                        onPressed: _next,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingData data;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compactHeight = size.height < 700;
    final illustrationSize = compactHeight ? 158.0 : 188.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 128),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _IllustrationBadge(data: data, size: illustrationSize),
              SizedBox(height: compactHeight ? 34 : 48),
              Text(
                data.title,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: _OnboardingColors.text,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                data.description,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: _OnboardingColors.mutedText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.48,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IllustrationBadge extends StatelessWidget {
  const _IllustrationBadge({required this.data, required this.size});

  final _OnboardingData data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: data.accentColor,
          boxShadow: [
            BoxShadow(
              color: data.accentColor.withAlpha(84),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Image.asset(data.iconPath, fit: BoxFit.contain),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.currentIndex});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? _OnboardingColors.primary
                : _OnboardingColors.indicatorMuted,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _OnboardingColors.primary,
          foregroundColor: _OnboardingColors.text,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({
    this.top,
    this.left,
    this.right,
    required this.size,
    this.muted = false,
  });

  final double? top;
  final double? left;
  final double? right;
  final double size;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              (muted ? _OnboardingColors.softGreen : _OnboardingColors.primary)
                  .withAlpha(50),
        ),
      ),
    );
  }
}

class _OnboardingData {
  const _OnboardingData({
    required this.title,
    required this.description,
    required this.iconPath,
    required this.accentColor,
  });

  final String title;
  final String description;
  final String iconPath;
  final Color accentColor;
}

class _OnboardingColors {
  const _OnboardingColors._();

  static const background = Color(0xFFFFFCF4);
  static const primary = Color(0xFFFFC944);
  static const softGreen = Color(0xFFBFE3D6);
  static const text = Color(0xFF17201D);
  static const mutedText = Color(0xFF66736F);
  static const indicatorMuted = Color(0xFFE2DDD1);
}
