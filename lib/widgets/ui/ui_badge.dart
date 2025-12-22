import 'package:flutter/material.dart';

class UiBadge extends StatelessWidget {
  const UiBadge({
    super.key,
    required this.text,
    this.backgroundColor,
    this.textColor,
    this.minSize = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
  });

  final String text;
  final Color? backgroundColor;
  final Color? textColor;
  final double minSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.error;
    final fg = textColor ?? theme.colorScheme.onError;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      constraints: BoxConstraints(
        minWidth: minSize,
        minHeight: minSize,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}


