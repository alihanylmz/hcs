import 'package:flutter/material.dart';

class QuoteEditorLineRemoveButton extends StatelessWidget {
  const QuoteEditorLineRemoveButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // Buton bilerek klavye gezinme sirasinda birakildi. Tab ile satir sonunda
    // buraya ugramak kucuk bir zahmet, ama onu sirandan cikarmak klavyeyle
    // calisan kullanicinin satiri hic silememesi demek olurdu. Hizli giris
    // yolu Enter: ayni sutunda bir alt satira gecer, silme butonuna ugramaz.
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.delete_outline_rounded),
    );
  }
}
