import 'package:flutter/material.dart';

class QuoteEditorManageCariButton extends StatelessWidget {
  const QuoteEditorManageCariButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.open_in_new_rounded, size: 18),
      label: const Text('Carileri yonet'),
    );
  }
}
