import 'package:flutter/material.dart';

class SecretChatPalette {
  const SecretChatPalette._();

  static const background = Color(0xFFFFF5D8);
  static const sun = Color(0xFFFFCC2E);
  static const gold = Color(0xFFF5BD20);
  static const text = Color(0xFF252017);
  static const muted = Color(0xFF766E5D);
  static const cardShadow = Color(0x30000000);
}

class SecretChatBackground extends StatelessWidget {
  const SecretChatBackground({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value;
        return Stack(
          children: [
            _Bubble(top: 126 + value * 14, right: 72, size: 42, opacity: .32),
            _Bubble(top: 340, left: -14 + value * 9, size: 52, opacity: .22),
            _Bubble(top: 470 + value * 10, right: -18, size: 40, opacity: .26),
            _Bubble(top: 700, left: 82 + value * 13, size: 34, opacity: .20),
            _Bubble(
              bottom: 240 + value * 16,
              right: 32,
              size: 44,
              opacity: .26,
            ),
            _Bubble(bottom: 126, left: 76 + value * 8, size: 38, opacity: .22),
            _Bubble(
              bottom: 34 + value * 10,
              right: 102,
              size: 42,
              opacity: .28,
            ),
          ],
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    this.top,
    this.right,
    this.bottom,
    this.left,
    required this.size,
    required this.opacity,
  });

  final double? top;
  final double? right;
  final double? bottom;
  final double? left;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: SecretChatPalette.sun.withAlpha((opacity * 255).round()),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
