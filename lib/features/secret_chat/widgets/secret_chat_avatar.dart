import 'package:flutter/material.dart';

import 'secret_chat_background.dart';

class SecretChatAvatar extends StatelessWidget {
  const SecretChatAvatar({
    super.key,
    required this.alias,
    this.photoUrl,
    this.radius = 22,
  });

  final String alias;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initial = alias.trim().isEmpty ? '?' : alias.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFFE3EF),
      foregroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
      onForegroundImageError: photoUrl == null ? null : (_, _) {},
      child: Text(
        initial,
        style: TextStyle(
          color: SecretChatPalette.text,
          fontSize: radius * .8,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
