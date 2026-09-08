import 'package:flutter/material.dart';

class QuoteEditorLineRemoveButton extends StatelessWidget {
  const QuoteEditorLineRemoveButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.delete_outline_rounded),
    );
  }
}
