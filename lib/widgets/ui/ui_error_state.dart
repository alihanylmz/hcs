import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'ui_buttons.dart';
import 'ui_card.dart';

class UiErrorState extends StatelessWidget {
  const UiErrorState({
    super.key,
    this.title = 'Bir hata olustu',
    this.message,
    this.onRetry,
    this.retryLabel = 'Tekrar Dene',
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = theme.colorScheme.error;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: UiCard(
            tone: UiCardTone.danger,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(isDark ? 0.32 : 0.20),
                        color.withOpacity(isDark ? 0.16 : 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withOpacity(0.18)),
                  ),
                  child: Icon(Icons.error_outline, size: 34, color: color),
                ),
                const SizedBox(height: 22),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (message != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    message!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          isDark
                              ? AppColors.textOnDarkMuted
                              : AppColors.textLight,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 20),
                  UiPrimaryButton(
                    label: retryLabel,
                    icon: Icons.refresh,
                    onPressed: onRetry,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
