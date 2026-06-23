import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

enum UiCardTone { base, muted, accent, success, danger }

class UiCard extends StatelessWidget {
  const UiCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.tone = UiCardTone.base,
    this.radius = 8,
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
        isDark ? const Color(0xFF10243B) : AppColors.surfaceAccent,
      UiCardTone.success =>
        isDark ? const Color(0xFF082D24) : const Color(0xFFF0FDF4),
      UiCardTone.danger =>
        isDark ? const Color(0xFF33161C) : const Color(0xFFFEF2F2),
    };

    final border = switch (tone) {
      UiCardTone.base => isDark ? AppColors.borderDark : AppColors.borderSubtle,
      UiCardTone.muted =>
        isDark ? const Color(0xFF243657) : const Color(0xFFDCE7F7),
      UiCardTone.accent =>
        isDark
            ? AppColors.corporateBlue.withValues(alpha: 0.34)
            : AppColors.corporateBlue.withValues(alpha: 0.18),
      UiCardTone.success =>
        isDark
            ? AppColors.statusDone.withValues(alpha: 0.34)
            : AppColors.statusDone.withValues(alpha: 0.20),
      UiCardTone.danger =>
        isDark
            ? AppColors.corporateRed.withValues(alpha: 0.34)
            : AppColors.corporateRed.withValues(alpha: 0.20),
    };

    final shadowColor = switch (tone) {
      UiCardTone.base => Colors.black,
      UiCardTone.muted => AppColors.corporateNavy,
      UiCardTone.accent => AppColors.corporateBlue,
      UiCardTone.success => AppColors.statusDone,
      UiCardTone.danger => AppColors.corporateRed,
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
              color: shadowColor.withValues(alpha: isDark ? 0.12 : 0.035),
              blurRadius: isDark ? 14 : 10,
              offset: const Offset(0, 4),
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
