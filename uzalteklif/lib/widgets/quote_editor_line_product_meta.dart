import 'package:flutter/material.dart';

class QuoteEditorLineProductMeta extends StatelessWidget {
  const QuoteEditorLineProductMeta({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: const Color(0xFF5B6F7F),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
