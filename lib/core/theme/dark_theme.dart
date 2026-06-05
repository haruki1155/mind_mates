import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class DarkTheme {
  const DarkTheme._();

  static ThemeData get theme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
      ),
      useMaterial3: true,
    );
  }
}
