import 'package:flutter/material.dart';

class QuoteEditorLineUnitField extends StatelessWidget {
  const QuoteEditorLineUnitField({
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
      decoration: InputDecoration(
        labelText: desktop ? null : 'Birim',
        isDense: true,
        filled: desktop ? false : null,
        border: desktop ? InputBorder.none : null,
        contentPadding: desktop
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 10)
            : null,
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }
}
