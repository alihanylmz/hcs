import 'package:flutter/material.dart';

class UiBadge extends StatelessWidget {
  const UiBadge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.minSize = 20,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  });

  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final double minSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = backgroundColor ?? theme.colorScheme.error;
    final fg = textColor ?? theme.colorScheme.onError;

    return Container(
      padding: padding,
      constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.10) : bg.withOpacity(0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: bg.withOpacity(isDark ? 0.26 : 0.22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          text,
          style: TextStyle(
            color: fg,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
