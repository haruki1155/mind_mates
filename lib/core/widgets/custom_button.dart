import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';

class CustomButton extends StatelessWidget {
  const CustomButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: AppSizes.sm),
              Text(label),
            ],
          );

    return SizedBox(
      height: AppSizes.buttonHeight,
      child: FilledButton(onPressed: onPressed, child: child),
    );
  }
}
