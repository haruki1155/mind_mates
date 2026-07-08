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
      iconAsset: '📚.png',
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
          'Individual Inventory Services collect and organize data about students\' abilities, interests, and concerns. We maintain comprehensive profiles, track progress over time, and organize personal information to support tailored counseling interventions.',
      iconAsset: '📋.png',
      headerColor: Color(0xFFB9C1D3),
      features: [
        'Student profile management',
        'Personal information collection',
        'Interest and abilities assessment',
      ],
    ),
    _ServiceItemData(
      title: 'Counseling Services',
      subtitle: 'Professional mental health support and guidance',
      description:
          'Counseling Services provide professional support for personal and mental health concerns. Students and staff can book appointments with licensed counselors, receive one-on-one support, and access crisis intervention when needed. All sessions are confidential and conducted by trained professionals.',
      iconAsset: '👥.png',
      headerColor: Color(0xFFB9C1D3),
      showInquire: true,
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
          'Career Guidance and Placement Services help students make informed career choices and connect with opportunities. We provide career assessments, academic and career path guidance, employer connections, and professional development resources.',
      iconAsset: '🎯.png',
      headerColor: Color(0xFFD9AEAA),
      showInquire: true,
      features: [
        'Career interest assessments',
        'Academic and career path guidance',
        'Job placement and employer connections',
      ],
    ),
    _ServiceItemData(
      title: 'Referral Services',
      subtitle: 'Connect individuals with external specialists',
      description:
          'Referral Services connect individuals with external specialists and partner organizations when additional expertise is needed. This includes referrals to psychiatrists, specialized therapists, and medical professionals.',
      iconAsset: '🤝.png',
      headerColor: Color(0xFF83B797),
      features: [
        'Psychiatric referrals (medication management)',
        'Specialized therapy referrals',
        'Medical professional connections',
      ],
    ),
    _ServiceItemData(
      title: 'Follow-up Services',
      subtitle: 'Monitor student progress after interventions',
      description:
          'Follow-up Services monitor students’ progress after interventions, ensuring continued support and tracking improvements over time. This includes mood tracking, progress check-ins, reassessments, and adjustments to treatment plans as needed.',
      iconAsset: '🎯-1.png',
      headerColor: Color(0xFFD9AEAA),
      showInquire: true,
      features: [
        'Progress check-ins',
        'Reassessments and treatment adjustments',
        'Mood tracking and ongoing support',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ServicesColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _ServicesHeader(
                onBackTap: () => _goBack(context),
                onNotificationTap: () =>
                    _openBlankPage(context, 'Notifications'),
              ),
            ),
            const SliverToBoxAdapter(child: _ServicesIntroCard()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 42),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const _AnimatedServicesSection(
                    delay: 0,
                    child: Text('All Services', style: _ServicesText.heading),
                  ),
                  const SizedBox(height: 12),
                  for (var index = 0; index < _services.length; index++) ...[
                    _AnimatedServicesSection(
                      delay: 70 + (index * 45),
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

  static void _goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushNamedAndRemoveUntil(RouteNames.home, (route) => false);
  }

  static void _openPaccCounseling(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PaccCounselingScreen()));
  }
}

class _ServicesHeader extends StatelessWidget {
  const _ServicesHeader({
    required this.onBackTap,
    required this.onNotificationTap,
  });

  final VoidCallback onBackTap;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
          IconButton(
            tooltip: 'Back',
            onPressed: onBackTap,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          ),
          const _ServicesAssetImage(
            assetName: 'creativity_15557951 1.png',
            width: 32,
            height: 32,
          ),
          const SizedBox(width: 8),
          const _ServicesAssetImage(
            assetName: 'MindMate.png',
            width: 106,
            height: 26,
            fit: BoxFit.contain,
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotificationTap,
            icon: const _ServicesAssetImage(
              assetName: 'Notification.png',
              width: 24,
              height: 30,
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
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ServicesAssetImage(
            assetName: 'Love Circled.png',
            width: 41,
            height: 41,
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
                  _ServicesAssetImage(
                    assetName: service.iconAsset,
                    width: 30,
                    height: 30,
                  ),
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
            Container(
              width: double.infinity,
              color: _ServicesColors.cardBody,
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
                          const Text('✓ ', style: _ServicesText.body),
                          Expanded(
                            child: Text(feature, style: _ServicesText.body),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: service.showInquire
                        ? MainAxisAlignment.spaceBetween
                        : MainAxisAlignment.center,
                    children: [
                      _ServiceActionButton(
                        label: 'Learn More',
                        icon: Icons.info_outline,
                        isPrimary: false,
                        onTap: onLearnMore,
                      ),
                      if (service.showInquire)
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(top: 22, right: -28, child: _SupportBubble(size: 54)),
        const Positioned(
          bottom: -25,
          left: -30,
          child: _SupportBubble(size: 44),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PACC support services',
              style: _ServicesText.supportTitle,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _ServicesColors.sun, width: 1.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      _ServicesAssetImage(
                        assetName: 'Yellow Heart.png',
                        width: 42,
                        height: 32,
                      ),
                      SizedBox(width: 12),
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
        ),
      ],
    );
  }
}

class _SupportBubble extends StatelessWidget {
  const _SupportBubble({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFF4D8),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: _ServicesColors.sun, width: isPrimary ? 0 : 1),
      ),
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
    required this.iconAsset,
    required this.headerColor,
    required this.features,
    this.showInquire = false,
  });

  final String title;
  final String subtitle;
  final String description;
  final String iconAsset;
  final Color headerColor;
  final List<String> features;
  final bool showInquire;
}

class _ServicesColors {
  const _ServicesColors._();

  static const background = Colors.white;
  static const sun = Color(0xFFFFCD3A);
  static const cardBody = Color(0xFFE8E4E4);
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
