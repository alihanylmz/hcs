import 'package:flutter/material.dart';

class QuoteEditorLineProductCode extends StatelessWidget {
  const QuoteEditorLineProductCode({super.key, required this.code, this.style});

  final String code;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      code.isEmpty ? '—' : code,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
