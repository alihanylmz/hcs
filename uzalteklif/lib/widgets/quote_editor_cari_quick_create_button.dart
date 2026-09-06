import 'package:flutter/material.dart';

class QuoteEditorCariQuickCreateButton extends StatelessWidget {
  const QuoteEditorCariQuickCreateButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add_business_rounded, size: 18),
      label: const Text('Hizli cari ekle'),
    );
  }
}
