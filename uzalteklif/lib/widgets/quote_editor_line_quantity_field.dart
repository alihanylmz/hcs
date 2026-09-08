import 'package:flutter/material.dart';

class QuoteEditorLineQuantityField extends StatelessWidget {
  const QuoteEditorLineQuantityField({
    super.key,
    required this.controller,
    required this.validator,
    required this.onChanged,
    this.focusNode,
    this.onSubmitted,
    this.desktop = false,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final ValueChanged<String> onChanged;
  /// Enter ile ayni sutunda bir alt satira gecmek icin gerekli.
  final FocusNode? focusNode;

  /// Enter'a basildiginda cagrilir; null ise varsayilan davranis.
  final VoidCallback? onSubmitted;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      textAlign: desktop ? TextAlign.end : TextAlign.start,
      decoration: InputDecoration(
        labelText: desktop ? null : 'Miktar',
        isDense: true,
        filled: desktop ? false : null,
        border: desktop ? InputBorder.none : null,
        contentPadding: desktop
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 10)
            : null,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: validator,
      onChanged: onChanged,
    );
  }
}
