import 'package:flutter/material.dart';

/// Admin-only design tokens. Keep these separate from AppColors because the
/// mobile application has its own visual language.
abstract final class AdminColors {
  static const primary = Color(0xFFF59E0B);
  static const primaryPressed = Color(0xFFD97706);
  static const secondary = Color(0xFFFBBF24);
  static const highlight = Color(0xFFF97316);
  static const background = Color(0xFFFFF7E6);
  static const softSurface = Color(0xFFFEF3C7);
  static const surface = Color(0xFFFFFCF7);
  static const textPrimary = Color(0xFF29231D);
  static const textMuted = Color(0xFF78716C);
  static const border = Color(0xFFE7DCCB);

  static const success = Color(0xFF247A45);
  static const warning = Color(0xFFB45309);
  static const error = Color(0xFFB42318);
  static const info = Color(0xFF6D5A9E);
}
