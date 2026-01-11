import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class DailyBackground extends StatelessWidget {
  final Widget child;
  const DailyBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Very light, performance-friendly gradient derived from AppColors.
    final topTint = Color.alphaBlend(AppColors.primary.withOpacity(0.04), AppColors.background);
    final bottomTint = Color.alphaBlend(AppColors.accent.withOpacity(0.03), AppColors.background);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [topTint, AppColors.background, bottomTint],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: child,
    );
  }
}


