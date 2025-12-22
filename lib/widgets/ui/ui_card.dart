import 'package:flutter/material.dart';

class UiCard extends StatelessWidget {
  const UiCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(16);

    final content = Padding(
      padding: padding,
      child: child,
    );

    return Material(
      color: theme.cardColor,
      elevation: theme.brightness == Brightness.dark ? 0 : 2,
      shadowColor: Colors.black.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: theme.dividerColor.withOpacity(theme.brightness == Brightness.dark ? 0.18 : 0.08),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      ),
    );
  }
}


