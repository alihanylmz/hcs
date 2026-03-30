import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

enum UiCardTone { base, muted, accent, success, danger }

class UiCard extends StatelessWidget {
  const UiCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.tone = UiCardTone.base,
    this.radius = 24,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final UiCardTone tone;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderRadius = BorderRadius.circular(radius);

    final surface = switch (tone) {
      UiCardTone.base => theme.cardColor,
      UiCardTone.muted =>
        isDark ? AppColors.surfaceDarkMuted : AppColors.surfaceSoft,
      UiCardTone.accent =>
        isDark ? const Color(0xFF183149) : AppColors.surfaceAccent,
      UiCardTone.success =>
        isDark ? const Color(0xFF14362E) : const Color(0xFFF1FBF6),
      UiCardTone.danger =>
        isDark ? const Color(0xFF3A2024) : const Color(0xFFFFF4F3),
    };

    final border = switch (tone) {
      UiCardTone.base => isDark ? AppColors.borderDark : AppColors.borderSubtle,
      UiCardTone.muted =>
        isDark ? AppColors.borderDark : AppColors.borderSubtle,
      UiCardTone.accent =>
        isDark
            ? AppColors.corporateBlue.withOpacity(0.26)
            : AppColors.corporateBlue.withOpacity(0.14),
      UiCardTone.success =>
        isDark
            ? AppColors.statusDone.withOpacity(0.32)
            : AppColors.statusDone.withOpacity(0.18),
      UiCardTone.danger =>
        isDark
            ? AppColors.corporateRed.withOpacity(0.36)
            : AppColors.corporateRed.withOpacity(0.18),
    };

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: borderRadius,
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.10 : 0.035),
              blurRadius: isDark ? 10 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
