import 'package:flutter/material.dart';

/// Kalem satirini oldugu gibi kopyalayan buton.
///
/// Benzer kalemler (ayni urunun farkli kapasitesi, ayni hizmetin farkli
/// katti) arka arkaya girilirken alanlari tek tek doldurmak yerine kopyalayip
/// tek alani degistirmek cok daha hizli.
class QuoteEditorLineDuplicateButton extends StatelessWidget {
  const QuoteEditorLineDuplicateButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: 'Satiri cogalt',
      icon: const Icon(Icons.copy_all_outlined),
    );
  }
}
