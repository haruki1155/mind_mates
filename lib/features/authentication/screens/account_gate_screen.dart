import 'package:flutter/material.dart';

import '../../../routes/route_names.dart';

class AccountGateScreen extends StatelessWidget {
  const AccountGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AccountGateColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const _SoftCircle(top: -82, left: -74, size: 196),
            const _SoftCircle(top: 46, right: -86, size: 166, muted: true),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: const _AccountGateContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountGateContent extends StatelessWidget {
  const _AccountGateContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: Container(
            width: 132,
            height: 132,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _AccountGateColors.shadow.withAlpha(22),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/Login/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 26),
        const Text(
          'Welcome to MindMate',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _AccountGateColors.text,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Do you already have an account?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _AccountGateColors.mutedText,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.38,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pushNamed(RouteNames.login),
            icon: const Icon(Icons.lock_rounded, size: 19),
            label: const Text('I already have an account'),
            style: FilledButton.styleFrom(
              backgroundColor: _AccountGateColors.primary,
              foregroundColor: _AccountGateColors.text,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed(RouteNames.quickAssessmentRole);
            },
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            label: const Text('I am new here'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _AccountGateColors.text,
              side: const BorderSide(color: _AccountGateColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
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
              (muted
                      ? _AccountGateColors.softGreen
                      : _AccountGateColors.primary)
                  .withAlpha(48),
        ),
      ),
    );
  }
}

class _AccountGateColors {
  const _AccountGateColors._();

  static const background = Color(0xFFFFFCF4);
  static const primary = Color(0xFFFFC944);
  static const softGreen = Color(0xFFBFE3D6);
  static const border = Color(0xFFE7DDC9);
  static const text = Color(0xFF17201D);
  static const mutedText = Color(0xFF66736F);
  static const shadow = Color(0xFF4B3A12);
}
