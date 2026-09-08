import 'package:flutter/material.dart';

class QuoteEditorLineQuantityField extends StatelessWidget {
  const QuoteEditorLineQuantityField({
    super.key,
    required this.controller,
    required this.validator,
    required this.onChanged,
    this.desktop = false,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final ValueChanged<String> onChanged;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
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
