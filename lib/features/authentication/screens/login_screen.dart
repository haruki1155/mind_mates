import 'package:flutter/material.dart';

import '../../../routes/route_names.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // Builds the full login page with decorative background and form content.
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _LoginColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            _BubbleCluster(top: -27, left: -14, mirror: false),
            _BubbleCluster(top: -16, right: -12, mirror: true),
            _LoginBody(),
          ],
        ),
      ),
    );
  }
}

class _LoginBody extends StatefulWidget {
  const _LoginBody();

  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  final _identificationController = TextEditingController();
  final _passwordController = TextEditingController();

  // Releases text controllers owned by the visible login form.
  @override
  void dispose() {
    _identificationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Temporarily opens the dashboard while authentication is being built.
  void _handleSignIn() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pushReplacementNamed(RouteNames.home);
  }

  // Opens the existing forgot password route without validating inputs.
  void _openForgotPassword() {
    Navigator.of(context).pushNamed(RouteNames.forgotPassword);
  }

  // Lays out the logo, notice card, and form card responsively.
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(6, screenHeight < 720 ? 28 : 60, 6, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Column(
            children: [
              const _LogoHeader(),
              const SizedBox(height: 21),
              const _NoticePanel(),
              const SizedBox(height: 8),
              _LoginFormCard(
                identificationController: _identificationController,
                passwordController: _passwordController,
                onForgotPassword: _openForgotPassword,
                onSignIn: _handleSignIn,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoHeader extends StatelessWidget {
  const _LogoHeader();

  static const _logoPath = 'assets/images/Login/logo.png';

  // Displays the MindMate logo image from the Login asset folder.
  @override
  Widget build(BuildContext context) {
    return Image.asset(_logoPath, width: 150, height: 150, fit: BoxFit.contain);
  }
}

class _NoticePanel extends StatelessWidget {
  const _NoticePanel();

  // Shows the unofficial-use reminder card below the logo.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: _LoginColors.notice,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '-- Unofficial --\nRefer to the instructions of UCU-MiS+ FB Page\n+ PACC before using.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _LoginColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.33,
        ),
      ),
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.identificationController,
    required this.passwordController,
    required this.onForgotPassword,
    required this.onSignIn,
  });

  final TextEditingController identificationController;
  final TextEditingController passwordController;
  final VoidCallback onForgotPassword;
  final VoidCallback onSignIn;

  // Groups all future-login inputs and actions inside one reusable card.
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 346,
      padding: const EdgeInsets.fromLTRB(24, 28, 16, 40),
      decoration: BoxDecoration(
        color: _LoginColors.card,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LoginField(
            controller: identificationController,
            label: 'Identification Number',
            assetIconPath: 'assets/images/Login/mail.png',
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 11),
          _LoginField(
            controller: passwordController,
            label: 'Password',
            icon: Icons.lock_outline,
            obscureText: true,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: _LoginColors.text,
                minimumSize: const Size(0, 24),
                padding: const EdgeInsets.only(right: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: const Text('Forgot Password?'),
            ),
          ),
          const SizedBox(height: 13),
          _SignInButton(onPressed: onSignIn),
        ],
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.label,
    this.assetIconPath,
    this.icon,
    this.keyboardType,
    this.obscureText = false,
  }) : assert(assetIconPath != null || icon != null);

  final TextEditingController controller;
  final String label;
  final String? assetIconPath;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscureText;

  // Builds a labeled input with an asset icon and no validation attached.
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 11, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: _LoginColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(
          height: 29,
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: const TextStyle(fontSize: 13, height: 1),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              prefixIcon: _LoginFieldIcon(
                assetIconPath: assetIconPath,
                icon: icon,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 38,
                minHeight: 29,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: _LoginColors.button,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginFieldIcon extends StatelessWidget {
  const _LoginFieldIcon({this.assetIconPath, this.icon});

  final String? assetIconPath;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 9, 6),
      child: assetIconPath == null
          ? Icon(icon, size: 18, color: _LoginColors.text)
          : Image.asset(
              assetIconPath!,
              width: 18,
              height: 18,
              fit: BoxFit.contain,
            ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.onPressed});

  final VoidCallback onPressed;

  // Renders the sign-in call to action without performing authentication.
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 29,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _LoginColors.button,
          foregroundColor: _LoginColors.text,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 13),
            SizedBox(width: 10),
            Text('Sign in'),
          ],
        ),
      ),
    );
  }
}

class _BubbleCluster extends StatelessWidget {
  const _BubbleCluster({this.top, this.left, this.right, required this.mirror});

  final double? top;
  final double? left;
  final double? right;
  final bool mirror;

  // Positions the decorative bubble cluster around the page corners.
  @override
  Widget build(BuildContext context) {
    const bubbles = [
      _BubbleSpec(23, 0, 30, _LoginColors.bubbleYellow),
      _BubbleSpec(52, 29, 29, _LoginColors.bubbleGray),
      _BubbleSpec(9, 30, 23, _LoginColors.bubbleYellow),
      _BubbleSpec(66, 38, 24, _LoginColors.bubbleYellow),
      _BubbleSpec(35, 52, 20, _LoginColors.bubbleGray),
      _BubbleSpec(0, 62, 26, _LoginColors.bubbleGray),
      _BubbleSpec(53, 73, 24, _LoginColors.bubbleYellow),
      _BubbleSpec(82, 80, 14, _LoginColors.bubbleYellow),
      _BubbleSpec(28, 98, 17, _LoginColors.bubbleGray),
      _BubbleSpec(51, 127, 20, _LoginColors.bubbleYellow),
    ];

    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Transform.scale(
        scaleX: mirror ? -1 : 1,
        child: SizedBox(
          width: 118,
          height: 153,
          child: Stack(
            clipBehavior: Clip.none,
            children: [for (final bubble in bubbles) _Bubble(spec: bubble)],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.spec});

  final _BubbleSpec spec;

  // Draws one shadowed circular bubble.
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
              color: Colors.black.withAlpha(40),
              blurRadius: 7,
              offset: const Offset(4, 5),
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

class _LoginColors {
  const _LoginColors._();

  static const background = Color(0xFFFEFEFE);
  static const card = Color(0xFFFFE9AC);
  static const notice = Color(0xFFFFE292);
  static const button = Color(0xFFFFBE0A);
  static const text = Color(0xFF050505);
  static const bubbleYellow = Color(0xFFFFCF52);
  static const bubbleGray = Color(0xFFD9D9D9);
}
