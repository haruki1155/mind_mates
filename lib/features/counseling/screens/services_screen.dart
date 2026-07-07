import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../routes/route_names.dart';
import 'pacc_counseling_screen.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  static const List<_ServiceItemData> _services = [
    _ServiceItemData(
      title: 'Information Services',
      subtitle: 'Educational content, resources, and mental health guidance',
      description:
          'Information Services provide students and staff with educational, occupational, and personal guidance. This includes mental health awareness materials, self-help resources, wellness tips, and access to evidence-based information about mental health conditions and treatments.',
      icon: Icons.menu_book_rounded,
      headerColor: Color(0xFFFFCE3C),
      features: [
        'Mental health awareness materials',
        'Educational articles and resources',
        'Self-help guides and coping strategies',
      ],
    ),
    _ServiceItemData(
      title: 'Individual Inventory Services',
      subtitle: 'Collect and organize student data, abilities, and concerns',
      description:
          'Individual Inventory Services help collect and organize data regarding students abilities, interests, and concerns. This includes maintaining comprehensive profiles, tracking progress over time, and organizing personal information to support effective counseling interventions.',
      icon: Icons.assignment_outlined,
      headerColor: Color(0xFFB8BECD),
      features: [
        'Student profiles and background data',
        'Progress monitoring records',
        'Organized support information',
      ],
    ),
    _ServiceItemData(
      title: 'Counseling Services',
      subtitle: 'Professional mental health support and guidance',
      description:
          'Counseling Services provide professional support for personal and mental health concerns. Students and staff can book appointments with licensed counselors, receive one-on-one support, and access crisis intervention when needed.',
      icon: Icons.groups_2_outlined,
      headerColor: Color(0xFFB8BECD),
      features: [
        'One-on-one counseling sessions',
        'Crisis intervention support',
        'Appointment booking system',
      ],
    ),
    _ServiceItemData(
      title: 'Career Guidance and Placement Services',
      subtitle: 'Assist students in making informed career decisions',
      description:
          'Career Guidance and Placement Services assist students in making informed career decisions and connecting them with opportunities. This includes career assessments, guidance on academic paths, job placement support, and professional development resources.',
      icon: Icons.track_changes_outlined,
      headerColor: Color(0xFFDAB3AE),
      features: [
        'Career interest assessments',
        'Academic path guidance',
        'Job placement assistance',
      ],
    ),
    _ServiceItemData(
      title: 'Referral Services',
      subtitle: 'Connect individuals with external specialists',
      description:
          'Referral Services connect individuals with external specialists or agencies when necessary. This includes referrals to psychiatrists for medication management, specialized therapists, medical professionals, and community mental health resources when cases require expertise beyond PACC capabilities.',
      icon: Icons.handshake_outlined,
      headerColor: Color(0xFF86B995),
      features: [
        'Psychiatric referrals',
        'Specialized therapy referrals',
        'Medical professional connections',
      ],
    ),
    _ServiceItemData(
      title: 'Follow-up Services',
      subtitle: 'Monitor student progress after interventions',
      description:
          'Follow-up Services monitor students progress after interventions, ensuring continued support and tracking improvements over time. This includes mood tracking, progress check-ins, reassessments, and adjustments to treatment plans as needed.',
      icon: Icons.track_changes_outlined,
      headerColor: Color(0xFFDAB3AE),
      features: [
        'Progress check-ins',
        'Academic path guidance',
        'Job placement assistance',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ServicesColors.background,
      bottomNavigationBar: const _ServicesBottomNav(),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _ServicesHeader(
                onNotificationTap: () =>
                    _openBlankPage(context, 'Notifications'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 34),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _AnimatedServicesSection(
                    delay: 0,
                    child: const _ServicesIntroCard(),
                  ),
                  const SizedBox(height: 20),
                  const _AnimatedServicesSection(
                    delay: 70,
                    child: Text('All Services', style: _ServicesText.heading),
                  ),
                  const SizedBox(height: 12),
                  for (var index = 0; index < _services.length; index++) ...[
                    _AnimatedServicesSection(
                      delay: 110 + (index * 45),
                      child: _ServiceCard(
                        service: _services[index],
                        onLearnMore: () => _openBlankPage(
                          context,
                          '${_services[index].title} Details',
                        ),
                        onInquire: () => _openBlankPage(
                          context,
                          'Inquire - ${_services[index].title}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  _AnimatedServicesSection(
                    delay: 420,
                    child: _SupportServicesCard(
                      onContact: () => _openPaccCounseling(context),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _openBlankPage(BuildContext context, String title) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _BlankServicesPage(title: title)));
  }

  static void _openPaccCounseling(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PaccCounselingScreen()));
  }
}

class _ServicesHeader extends StatelessWidget {
  const _ServicesHeader({required this.onNotificationTap});

  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: _ServicesColors.sun,
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const _ServicesAssetImage(
            assetName: 'logo.png 3.png',
            width: 34,
            height: 34,
          ),
          const SizedBox(width: 8),
          const _ServicesAssetImage(
            assetName: 'MindMate.png',
            height: 30,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          Tooltip(
            message: 'Notifications',
            child: IconButton(
              onPressed: onNotificationTap,
              icon: const Icon(Icons.notifications, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicesIntroCard extends StatelessWidget {
  const _ServicesIntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
      decoration: _ServicesDecor.card(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _ServicesColors.goldLine, width: 2),
            ),
            child: const Icon(
              Icons.favorite_border,
              color: _ServicesColors.goldLine,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PACC Services', style: _ServicesText.introTitle),
                SizedBox(height: 4),
                Text(
                  'Psychological Assessment & Counseling Center',
                  style: _ServicesText.introSubtitle,
                ),
                SizedBox(height: 14),
                Text(
                  'Comprehensive mental health support services for the UCU community',
                  style: _ServicesText.introBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.onLearnMore,
    required this.onInquire,
  });

  final _ServiceItemData service;
  final VoidCallback onLearnMore;
  final VoidCallback onInquire;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _ServicesDecor.card(radius: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
              color: service.headerColor,
              child: Row(
                children: [
                  Icon(service.icon, size: 30, color: Colors.black87),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(service.title, style: _ServicesText.cardTitle),
                        const SizedBox(height: 2),
                        Text(
                          service.subtitle,
                          style: _ServicesText.cardSubtitle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.description, style: _ServicesText.body),
                  const SizedBox(height: 8),
                  const Text('Key Features', style: _ServicesText.keyTitle),
                  const SizedBox(height: 4),
                  for (final feature in service.features)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('- ', style: _ServicesText.body),
                          Expanded(
                            child: Text(feature, style: _ServicesText.body),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _ServiceActionButton(
                        label: 'Learn More',
                        icon: Icons.info_outline,
                        isPrimary: false,
                        onTap: onLearnMore,
                      ),
                      const Spacer(),
                      _ServiceActionButton(
                        label: 'Inquire',
                        icon: Icons.chevron_right,
                        isPrimary: true,
                        onTap: onInquire,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportServicesCard extends StatelessWidget {
  const _SupportServicesCard({required this.onContact});

  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PAACC support services', style: _ServicesText.supportTitle),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _ServicesColors.sun, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  _ServicesAssetImage(
                    assetName: 'Yellow Heart.png',
                    width: 42,
                    height: 42,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Need Immediate Help?',
                      style: _ServicesText.helpTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'PACC counselors are available to support you. Contact us for appointments or urgent assistance.',
                style: _ServicesText.helpBody,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _RoundedYellowButton(
                  label: 'Contact counselor',
                  onTap: onContact,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServicesBottomNav extends StatelessWidget {
  const _ServicesBottomNav();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 66,
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 12,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomNavItem(
              icon: Icons.calendar_today,
              label: 'Today',
              onTap: () => Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(RouteNames.home, (route) => false),
            ),
            _BottomNavItem(
              icon: Icons.forum_outlined,
              label: 'Secret chat',
              onTap: () =>
                  Navigator.of(context).pushNamed(RouteNames.secretChat),
            ),
            _BottomNavItem(
              icon: Icons.show_chart,
              label: 'Insight',
              isActive: true,
              onTap: () => ServicesScreen._openBlankPage(context, 'Insights'),
            ),
            _BottomNavItem(
              icon: Icons.chat_bubble_outline,
              label: 'Messages',
              onTap: () => Navigator.of(context).pushNamed(RouteNames.mindAid),
            ),
            _BottomNavItem(
              icon: Icons.person,
              label: 'Profile',
              onTap: () => Navigator.of(context).pushNamed(RouteNames.profile),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: isActive ? 34 : 26,
              height: isActive ? 34 : 26,
              decoration: BoxDecoration(
                color: isActive ? _ServicesColors.sun : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: Colors.black87),
            ),
            const SizedBox(height: 3),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: _ServicesText.navLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceActionButton extends StatelessWidget {
  const _ServiceActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? _ServicesColors.sun : const Color(0xFFE1E1E1),
      borderRadius: BorderRadius.circular(10),
      elevation: 4,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 112,
          height: 31,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isPrimary) Icon(icon, size: 12, color: Colors.black87),
              if (!isPrimary) const SizedBox(width: 5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, style: _ServicesText.button),
                ),
              ),
              if (isPrimary) const SizedBox(width: 8),
              if (isPrimary) Icon(icon, size: 18, color: Colors.black87),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundedYellowButton extends StatelessWidget {
  const _RoundedYellowButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ServicesColors.sun,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: const Color(0x33000000),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: _ServicesText.contactButton,
          ),
        ),
      ),
    );
  }
}

class _ServicesAssetImage extends StatelessWidget {
  const _ServicesAssetImage({
    required this.assetName,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String assetName;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      '${AppAssets.servicesImages}/$assetName',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) {
        return SizedBox(
          width: width,
          height: height,
          child: const Icon(Icons.image_not_supported_outlined),
        );
      },
    );
  }
}

class _AnimatedServicesSection extends StatelessWidget {
  const _AnimatedServicesSection({required this.child, required this.delay});

  final Widget child;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }
}

class _BlankServicesPage extends StatelessWidget {
  const _BlankServicesPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ServicesColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _ServicesColors.sun,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: const SizedBox.expand(),
    );
  }
}

class _ServiceItemData {
  const _ServiceItemData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.headerColor,
    required this.features,
  });

  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color headerColor;
  final List<String> features;
}

class _ServicesColors {
  const _ServicesColors._();

  static const background = Color(0xFFFAF5E8);
  static const sun = Color(0xFFFFCD3A);
  static const goldLine = Color(0xFFC79A2C);
  static const text = Color(0xFF17120D);
}

class _ServicesText {
  const _ServicesText._();

  static const heading = TextStyle(
    color: _ServicesColors.sun,
    fontSize: 20,
    fontWeight: FontWeight.w900,
  );

  static const introTitle = TextStyle(
    color: _ServicesColors.sun,
    fontSize: 20,
    fontWeight: FontWeight.w900,
  );

  static const introSubtitle = TextStyle(
    color: _ServicesColors.sun,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  static const introBody = TextStyle(
    color: _ServicesColors.sun,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
  );

  static const cardTitle = TextStyle(
    color: Colors.black,
    fontSize: 13,
    fontWeight: FontWeight.w900,
  );

  static const cardSubtitle = TextStyle(
    color: Colors.black,
    fontSize: 9,
    height: 1.15,
    fontWeight: FontWeight.w700,
  );

  static const body = TextStyle(
    color: _ServicesColors.text,
    fontSize: 12,
    height: 1.28,
    fontWeight: FontWeight.w500,
  );

  static const keyTitle = TextStyle(
    color: _ServicesColors.text,
    fontSize: 12,
    fontWeight: FontWeight.w900,
  );

  static const button = TextStyle(
    color: Colors.black,
    fontSize: 10,
    fontWeight: FontWeight.w900,
  );

  static const supportTitle = TextStyle(
    color: Colors.black,
    fontSize: 16,
    fontWeight: FontWeight.w900,
  );

  static const helpTitle = TextStyle(
    color: Colors.black,
    fontSize: 16,
    fontWeight: FontWeight.w900,
  );

  static const helpBody = TextStyle(
    color: Colors.black,
    fontSize: 16,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const contactButton = TextStyle(
    color: Colors.white,
    fontSize: 12,
    fontWeight: FontWeight.w900,
  );

  static const navLabel = TextStyle(
    color: Colors.black,
    fontSize: 10,
    fontWeight: FontWeight.w800,
  );
}

class _ServicesDecor {
  const _ServicesDecor._();

  static BoxDecoration card({double radius = 10}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 10,
          offset: Offset(0, 5),
        ),
      ],
    );
  }
}
