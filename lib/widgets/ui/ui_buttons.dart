import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class UiPrimaryButton extends StatelessWidget {
  const UiPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveOnPressed = isLoading ? null : onPressed;

    final child =
        isLoading
            ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.onPrimary,
                ),
              ),
            )
            : Text(label);

    final button =
        icon == null
            ? FilledButton(onPressed: effectiveOnPressed, child: child)
            : FilledButton.icon(
              onPressed: effectiveOnPressed,
              icon: Icon(icon, size: 18),
              label: child,
            );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class UiSecondaryButton extends StatelessWidget {
  const UiSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final button =
        icon == null
            ? OutlinedButton(onPressed: onPressed, child: Text(label))
            : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
            );

    final wrappedButton = Theme(
      data: theme.copyWith(
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurface,
            backgroundColor:
                isDark
                    ? AppColors.surfaceDarkMuted.withOpacity(0.56)
                    : AppColors.surfaceWhite,
            side: BorderSide(color: theme.dividerColor),
          ),
        ),
      ),
      child: button,
    );

    return expand
        ? SizedBox(width: double.infinity, child: wrappedButton)
        : wrappedButton;
  }
}

class UiGhostButton extends StatelessWidget {
  const UiGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.primary,
        backgroundColor:
            isDark
                ? theme.colorScheme.primary.withOpacity(0.10)
                : theme.colorScheme.primary.withOpacity(0.08),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class UiDestructiveButton extends StatelessWidget {
  const UiDestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.delete_outline, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.corporateRed,
        backgroundColor:
            isDark
                ? AppColors.corporateRed.withOpacity(0.12)
                : AppColors.corporateRed.withOpacity(0.06),
        side: BorderSide(color: AppColors.corporateRed.withOpacity(0.24)),
      ),
    );
  }
}
