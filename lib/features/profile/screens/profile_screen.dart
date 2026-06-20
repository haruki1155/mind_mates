import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.data});

  final ProfileViewData? data;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientController;

  ProfileViewData? get _profileData => widget.data ?? _loadProfileData();

  static const List<ProfileActionItem> _actions = [
    ProfileActionItem(
      label: 'Secret Chats profile',
      icon: Icons.article_outlined,
    ),
    ProfileActionItem(
      label: 'Mood tracking settings',
      icon: Icons.monitor_heart_outlined,
    ),
    ProfileActionItem(
      label: 'Privacy settings',
      icon: Icons.privacy_tip_outlined,
    ),
    ProfileActionItem(label: 'Reminders', icon: Icons.notifications),
    ProfileActionItem(label: 'Help', icon: Icons.help_outline),
    ProfileActionItem(label: 'About MindMate', icon: Icons.info),
  ];

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _profileData;

    return Scaffold(
      backgroundColor: _ProfileColors.background,
      body: Stack(
        children: [
          _FloatingProfileBackground(animation: _ambientController),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _ProfileHeader(
                    onNotificationTap: () =>
                        _openPlaceholder(context, 'Notifications'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                  sliver: SliverList.list(
                    children: [
                      const _AnimatedProfileSection(
                        delay: 0,
                        child: Text('Your Profile', style: _ProfileText.title),
                      ),
                      const SizedBox(height: 10),
                      _AnimatedProfileSection(
                        delay: 60,
                        child: _ProfileSummaryCard(data: data),
                      ),
                      const SizedBox(height: 18),
                      _AnimatedProfileSection(
                        delay: 120,
                        child: _ActionListCard(
                          actions: _actions,
                          onActionTap: (action) =>
                              _openPlaceholder(context, action.label),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _AnimatedProfileSection(
                        delay: 180,
                        child: _MentalHealthSummaryCard(
                          data: data?.summary,
                          onReportTap: () =>
                              _openPlaceholder(context, 'Full Report'),
                          onInsightsTap: () =>
                              _openPlaceholder(context, 'Insights'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _AnimatedProfileSection(
                        delay: 240,
                        child: _AboutMindMateCard(),
                      ),
                      const SizedBox(height: 18),
                      const _AnimatedProfileSection(
                        delay: 300,
                        child: _DataProtectionCard(),
                      ),
                      const SizedBox(height: 26),
                      const _AnimatedProfileSection(
                        delay: 360,
                        child: _ProfileFooter(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ProfileViewData? _loadProfileData() {
    // Backend integration point: return fetched profile data here later.
    return null;
  }

  void _openPlaceholder(BuildContext context, String title) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => _BlankProfilePage(title: title)));
  }
}

class ProfileViewData {
  const ProfileViewData({
    this.displayName,
    this.role,
    this.avatarAssetName,
    this.metrics = const [],
    this.summary,
  });

  final String? displayName;
  final String? role;
  final String? avatarAssetName;
  final List<ProfileMetricData> metrics;
  final ProfileSummaryData? summary;
}

class ProfileMetricData {
  const ProfileMetricData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class ProfileSummaryData {
  const ProfileSummaryData({this.title, this.description});

  final String? title;
  final String? description;
}

class ProfileActionItem {
  const ProfileActionItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.onNotificationTap});

  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: _ProfileColors.sun,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const _ProfileAssetImage(
            assetName: 'logo.png 3.png',
            width: 34,
            height: 34,
          ),
          const SizedBox(width: 8),
          const _ProfileAssetImage(
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

class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.data});

  final ProfileViewData? data;

  @override
  Widget build(BuildContext context) {
    final displayName = data?.displayName;
    final role = data?.role;
    final hasProfile = displayName != null || role != null;
    final metrics = data?.metrics ?? const <ProfileMetricData>[];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: _ProfileDecor.card(
        color: _ProfileColors.sun,
        radius: 14,
        shadowColor: const Color(0x33A36B00),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _AvatarSlot(assetName: data?.avatarAssetName),
              const SizedBox(width: 12),
              Expanded(
                child: hasProfile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (displayName != null)
                            Text(displayName, style: _ProfileText.profileName),
                          if (role != null)
                            Text(role, style: _ProfileText.profileRole),
                        ],
                      )
                    : const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonLine(
                            widthFactor: .52,
                            height: 14,
                            color: Color(0x77FFFFFF),
                          ),
                          SizedBox(height: 8),
                          _SkeletonLine(
                            widthFactor: .34,
                            height: 10,
                            color: Color(0x77FFFFFF),
                          ),
                        ],
                      ),
              ),
              Tooltip(
                message: 'Open profile details',
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: _ProfileColors.sun,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: List.generate(3, (index) {
              final metric = index < metrics.length ? metrics[index] : null;
              return Expanded(child: _MetricSlot(metric: metric));
            }),
          ),
        ],
      ),
    );
  }
}

class _AvatarSlot extends StatelessWidget {
  const _AvatarSlot({required this.assetName});

  final String? assetName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: const BoxDecoration(
        color: Color(0xFFFFE587),
        shape: BoxShape.circle,
      ),
      child: assetName == null
          ? const Center(
              child: _SkeletonCircle(size: 38, color: Color(0x66FFFFFF)),
            )
          : ClipOval(
              child: _ProfileAssetImage(
                assetName: assetName!,
                fit: BoxFit.cover,
              ),
            ),
    );
  }
}

class _MetricSlot extends StatelessWidget {
  const _MetricSlot({required this.metric});

  final ProfileMetricData? metric;

  @override
  Widget build(BuildContext context) {
    final metric = this.metric;

    if (metric == null) {
      return const Column(
        children: [
          _SkeletonCircle(size: 24, color: Color(0x66FFFFFF)),
          SizedBox(height: 10),
          _SkeletonLine(widthFactor: .44, height: 15, color: Color(0x77FFFFFF)),
          SizedBox(height: 7),
          _SkeletonLine(widthFactor: .36, height: 8, color: Color(0x77FFFFFF)),
        ],
      );
    }

    return Column(
      children: [
        Icon(metric.icon, size: 28, color: Colors.black),
        const SizedBox(height: 8),
        Text(metric.value, style: _ProfileText.metricValue),
        Text(metric.label, style: _ProfileText.metricLabel),
      ],
    );
  }
}

class _ActionListCard extends StatelessWidget {
  const _ActionListCard({required this.actions, required this.onActionTap});

  final List<ProfileActionItem> actions;
  final ValueChanged<ProfileActionItem> onActionTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _ProfileDecor.card(radius: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            for (var index = 0; index < actions.length; index++)
              _ActionListTile(
                action: actions[index],
                showDivider: index != actions.length - 1,
                onTap: () => onActionTap(actions[index]),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionListTile extends StatelessWidget {
  const _ActionListTile({
    required this.action,
    required this.showDivider,
    required this.onTap,
  });

  final ProfileActionItem action;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    bottom: BorderSide(color: _ProfileColors.divider),
                  )
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(action.icon, size: 21, color: Colors.black),
              const SizedBox(width: 14),
              Expanded(child: Text(action.label, style: _ProfileText.action)),
              const Icon(Icons.chevron_right, size: 18, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }
}

class _MentalHealthSummaryCard extends StatelessWidget {
  const _MentalHealthSummaryCard({
    required this.data,
    required this.onReportTap,
    required this.onInsightsTap,
  });

  final ProfileSummaryData? data;
  final VoidCallback onReportTap;
  final VoidCallback onInsightsTap;

  @override
  Widget build(BuildContext context) {
    final title = data?.title;
    final description = data?.description;
    final hasText = title != null || description != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
      decoration: _ProfileDecor.card(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite, color: _ProfileColors.sun, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: hasText
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null)
                            Text(title, style: _ProfileText.cardTitle),
                          if (description != null) ...[
                            const SizedBox(height: 4),
                            Text(description, style: _ProfileText.body),
                          ],
                        ],
                      )
                    : const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonLine(widthFactor: .58, height: 13),
                          SizedBox(height: 8),
                          _SkeletonLine(widthFactor: .74, height: 9),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: _SkeletonAwareButton(
                  label: data == null ? null : 'Full Report',
                  icon: Icons.bar_chart,
                  color: _ProfileColors.sun,
                  onTap: onReportTap,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SkeletonAwareButton(
                  label: data == null ? null : 'View Insights',
                  icon: Icons.insights,
                  color: _ProfileColors.periwinkle,
                  onTap: onInsightsTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonAwareButton extends StatelessWidget {
  const _SkeletonAwareButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String? label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: label == null ? null : onTap,
        child: SizedBox(
          height: 36,
          child: Center(
            child: label == null
                ? const _SkeletonLine(widthFactor: .54, height: 10)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 16, color: Colors.black),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label!,
                          overflow: TextOverflow.ellipsis,
                          style: _ProfileText.button,
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

class _AboutMindMateCard extends StatelessWidget {
  const _AboutMindMateCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _ProfileDecor.card(radius: 14),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About MindMate', style: _ProfileText.cardTitle),
          SizedBox(height: 10),
          Text(
            'MindMate supports mental health awareness, reflection, and access to counseling resources.',
            style: _ProfileText.body,
          ),
          SizedBox(height: 10),
          Text(
            'This app does not replace professional care. For urgent concerns, contact PACC Counseling Services.',
            style: _ProfileText.body,
          ),
        ],
      ),
    );
  }
}

class _DataProtectionCard extends StatelessWidget {
  const _DataProtectionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: _ProfileDecor.card(radius: 14),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, size: 28, color: Colors.black),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your data is protected', style: _ProfileText.cardTitle),
                SizedBox(height: 7),
                Text(
                  'Profile details will stay private and only appear here when connected to secure backend data.',
                  style: _ProfileText.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileFooter extends StatelessWidget {
  const _ProfileFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: const [
            Text('Privacy Policy', style: _ProfileText.footerLink),
            Text('-', style: _ProfileText.footerLink),
            Text('Terms of Use', style: _ProfileText.footerLink),
            Text('-', style: _ProfileText.footerLink),
            Text('Accessibility Statement', style: _ProfileText.footerLink),
          ],
        ),
        const SizedBox(height: 28),
        const _ProfileAssetImage(
          assetName: 'logo.png 3.png',
          width: 48,
          height: 48,
        ),
        const SizedBox(height: 8),
        const Text('Mental Health Companion', style: _ProfileText.footer),
      ],
    );
  }
}

class _FloatingProfileBackground extends StatelessWidget {
  const _FloatingProfileBackground({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;
        return Stack(
          children: [
            _BackgroundCircle(top: 30 + (value * 10), left: 42, size: 40),
            _BackgroundCircle(top: 92, right: 10 + (value * 8), size: 38),
            _BackgroundCircle(top: 260 + (value * 12), left: 172, size: 42),
            _BackgroundCircle(bottom: 210, left: 0 + (value * 12), size: 36),
            _BackgroundCircle(bottom: 92 + (value * 9), right: 38, size: 40),
            _BackgroundCircle(bottom: 36, left: 82 + (value * 7), size: 38),
          ],
        );
      },
    );
  }
}

class _BackgroundCircle extends StatelessWidget {
  const _BackgroundCircle({
    this.top,
    this.right,
    this.bottom,
    this.left,
    required this.size,
  });

  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: _ProfileColors.circle,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _ProfileAssetImage extends StatelessWidget {
  const _ProfileAssetImage({
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
      '${AppAssets.profileImages}/$assetName',
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

class _AnimatedProfileSection extends StatelessWidget {
  const _AnimatedProfileSection({required this.child, required this.delay});

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
            offset: Offset(0, (1 - value) * 18),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.widthFactor,
    required this.height,
    this.color = const Color(0xFFEDE4CA),
  });

  final double widthFactor;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: _SkeletonBox(height: height, color: color),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({
    required this.size,
    this.color = const Color(0xFFEDE4CA),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _SkeletonBox(
      width: size,
      height: size,
      radius: size / 2,
      color: color,
    );
  }
}

class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({
    required this.height,
    this.width,
    this.radius = 8,
    this.color = const Color(0xFFEDE4CA),
  });

  final double? width;
  final double height;
  final double radius;
  final Color color;

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: .46,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

class _BlankProfilePage extends StatelessWidget {
  const _BlankProfilePage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ProfileColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _ProfileColors.sun,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: const SizedBox.expand(),
    );
  }
}

class _ProfileColors {
  const _ProfileColors._();

  static const background = Color(0xFFFAF4E1);
  static const sun = Color(0xFFFFCA24);
  static const circle = Color(0x66E5D28F);
  static const divider = Color(0xFFE1D9C7);
  static const text = Color(0xFF18130C);
  static const muted = Color(0xFF6E6658);
  static const periwinkle = Color(0xFFAFC2F7);
}

class _ProfileText {
  const _ProfileText._();

  static const title = TextStyle(
    color: Colors.black,
    fontSize: 20,
    fontWeight: FontWeight.w900,
  );

  static const profileName = TextStyle(
    color: Colors.black,
    fontSize: 15,
    fontWeight: FontWeight.w900,
  );

  static const profileRole = TextStyle(
    color: Colors.black,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  static const metricValue = TextStyle(
    color: Colors.black,
    fontSize: 22,
    height: 1,
    fontWeight: FontWeight.w900,
  );

  static const metricLabel = TextStyle(
    color: Colors.black,
    fontSize: 10,
    fontWeight: FontWeight.w800,
  );

  static const action = TextStyle(
    color: _ProfileColors.text,
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  static const cardTitle = TextStyle(
    color: Colors.black,
    fontSize: 13,
    fontWeight: FontWeight.w900,
  );

  static const body = TextStyle(
    color: _ProfileColors.muted,
    fontSize: 11,
    height: 1.38,
    fontWeight: FontWeight.w500,
  );

  static const button = TextStyle(
    color: Colors.black,
    fontSize: 11,
    fontWeight: FontWeight.w900,
  );

  static const footerLink = TextStyle(
    color: Colors.black,
    fontSize: 12,
    fontWeight: FontWeight.w900,
  );

  static const footer = TextStyle(
    color: Colors.black,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );
}

class _ProfileDecor {
  const _ProfileDecor._();

  static BoxDecoration card({
    Color color = Colors.white,
    Color shadowColor = const Color(0x1F000000),
    double radius = 12,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: shadowColor,
          blurRadius: 14,
          offset: const Offset(0, 7),
        ),
      ],
    );
  }
}
