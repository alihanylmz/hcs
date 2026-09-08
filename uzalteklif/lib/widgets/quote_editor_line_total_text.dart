import 'package:flutter/material.dart';

class QuoteEditorLineTotalText extends StatelessWidget {
  const QuoteEditorLineTotalText({
    super.key,
    required this.text,
    this.prefix,
    this.textAlign = TextAlign.left,
  });
  final String text;
  final String? prefix;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) => Text(
    prefix == null ? text : '$prefix$text',
    textAlign: textAlign,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: const Color(0xFF17304C),
      fontWeight: FontWeight.w800,
    ),
  );
}
