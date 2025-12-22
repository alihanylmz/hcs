import 'package:flutter/material.dart';

/// Scrollable widget'ların (ListView/CustomScrollView) içine girmeden
/// sayfa içeriğini kurumsal "max width" ile ortalar.
class UiMaxWidth extends StatelessWidget {
  const UiMaxWidth({
    super.key,
    required this.child,
    this.maxWidth = 1100,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}


