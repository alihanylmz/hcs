import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class UiPage extends StatelessWidget {
  const UiPage({
    super.key,
    required this.child,
    this.maxWidth = 1420,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    this.center = false,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final resolvedPadding =
        screenWidth < 720
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
            : screenWidth < 1200
            ? const EdgeInsets.symmetric(horizontal: 20, vertical: 20)
            : padding;

    final body = Padding(
      padding: resolvedPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );

    return Align(
      alignment: center ? Alignment.center : Alignment.topCenter,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: body,
      ),
    );
  }
}

class UiSection extends StatelessWidget {
  const UiSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
    this.padding = const EdgeInsets.symmetric(vertical: 10),
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final String? subtitle;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          subtitle!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            letterSpacing: 1.1,
                            color:
                                isDark
                                    ? AppColors.textOnDarkMuted
                                    : AppColors.textLight,
                          ),
                        ),
                      ),
                    Text(
                      title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
