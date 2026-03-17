import 'package:flutter/material.dart';

class UiMaxWidth extends StatelessWidget {
  const UiMaxWidth({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final resolvedPadding =
        screenWidth < 720
            ? const EdgeInsets.symmetric(horizontal: 16)
            : padding;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: resolvedPadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
