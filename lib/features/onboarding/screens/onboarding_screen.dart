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
          'Monitor your emotional cycle with our 28-day Mind Rhythm Ring. Understand your patterns and gain insights into your mental wellbeing.',
      iconPath: 'assets/images/ONBOARDING_1/Target.png',
      iconWidth: 96,
    ),
    _OnboardingData(
      title: 'Express Your Thoughts',
      description:
          'Share your feelings privately in Secret Thoughts. Post, reflect, and comment on your journey in a safe, judgment-free space.',
      iconPath: 'assets/images/ONBOARDING_2/Thought Balloon.png',
      iconWidth: 102,
    ),
    _OnboardingData(
      title: 'Daily Mind Quests',
      description:
          'Complete personalized daily quests to build healthy habits. Earn rewards and watch your Mood Pet grow with you!',
      iconPath: 'assets/images/ONBOARDING_3/Creativity.png',
      iconWidth: 104,
    ),
    _OnboardingData(
      title: 'Express Your Thoughts',
      description:
          'Share your feelings privately in Secret Thoughts. Post, reflect, and comment on your journey in a safe, judgment-free space.',
      iconPath: 'assets/images/ONBOARDING_4/ONBOARDING 4/Sparkling.png',
      iconWidth: 104,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage == _pages.length - 1) {
      Navigator.of(context).pushReplacementNamed(RouteNames.login);
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      body: SafeArea(
        child: Stack(
          children: [
            const _BubbleCluster(
              top: -18,
              left: -16,
              mirror: false,
            ),
            const _BubbleCluster(
              top: 52,
              right: -9,
              mirror: true,
            ),
            PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, index) {
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double delta = 0;
                    if (_pageController.hasClients && _pageController.page != null) {
                      delta = (_pageController.page! - index).clamp(-1.0, 1.0);
                    }

                    return Opacity(
                      opacity: 1 - (delta.abs() * 0.18),
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
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PageIndicator(
                      count: _pages.length,
                      currentIndex: _currentPage,
                    ),
                    const SizedBox(height: 26),
                    _NextButton(onPressed: _next),
                  ],
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
    final contentWidth = size.width.clamp(0, 360).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: Column(
        children: [
          SizedBox(height: size.height * 0.24),
          _IllustrationBadge(data: data),
          SizedBox(height: size.height * 0.078),
          SizedBox(
            width: contentWidth,
            child: Text(
              data.title,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Color(0xFF050505),
                fontSize: 23,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: contentWidth - 32,
            child: Text(
              data.description,
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IllustrationBadge extends StatelessWidget {
  const _IllustrationBadge({required this.data});

  final _OnboardingData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 166,
      height: 166,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFBE0A),
            Color(0xFFFFD754),
          ],
        ),
      ),
      child: Center(
        child: Image.asset(
          data.iconPath,
          width: data.iconWidth,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.count,
    required this.currentIndex,
  });

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
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          width: isActive ? 30 : 8,
          height: 7,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFBE0A) : const Color(0xFF686868),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              if (isActive)
                BoxShadow(
                  color: const Color(0xFFFFBE0A).withAlpha(82),
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 216,
      height: 37,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(35),
              blurRadius: 8,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFFBE0A),
            foregroundColor: Colors.black,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Next'),
              SizedBox(width: 7),
              Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleCluster extends StatelessWidget {
  const _BubbleCluster({
    this.top,
    this.left,
    this.right,
    required this.mirror,
  });

  final double? top;
  final double? left;
  final double? right;
  final bool mirror;

  static const _yellow = Color(0xFFFFCF52);
  static const _gray = Color(0xFFD9D9D9);

  @override
  Widget build(BuildContext context) {
    final bubbles = [
      _BubbleSpec(18, 0, 31, _yellow),
      _BubbleSpec(43, 9, 28, _gray),
      _BubbleSpec(6, 36, 28, _yellow),
      _BubbleSpec(59, 48, 22, _gray),
      _BubbleSpec(28, 67, 16, _gray),
      _BubbleSpec(72, 82, 20, _yellow),
      _BubbleSpec(1, 91, 25, _yellow),
      _BubbleSpec(51, 111, 15, _gray),
      _BubbleSpec(75, 127, 17, _yellow),
    ];

    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Transform.scale(
        scaleX: mirror ? -1 : 1,
        scaleY: 1,
        child: SizedBox(
          width: 118,
          height: 158,
          child: Stack(
            clipBehavior: Clip.none,
            children: bubbles.map((bubble) => _Bubble(spec: bubble)).toList(),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.spec});

  final _BubbleSpec spec;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: spec.left,
      top: spec.top,
      child: Container(
        width: spec.size,
        height: spec.size,
        decoration: BoxDecoration(
          color: spec.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(spec.color == const Color(0xFFD9D9D9) ? 42 : 28),
              blurRadius: 7,
              offset: const Offset(3, 4),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleSpec {
  const _BubbleSpec(this.left, this.top, this.size, this.color);

  final double left;
  final double top;
  final double size;
  final Color color;
}

class _OnboardingData {
  const _OnboardingData({
    required this.title,
    required this.description,
    required this.iconPath,
    required this.iconWidth,
  });

  final String title;
  final String description;
  final String iconPath;
  final double iconWidth;
}
