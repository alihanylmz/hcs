import 'package:flutter/material.dart';

class QuoteEditorLineDiscountField extends StatelessWidget {
  const QuoteEditorLineDiscountField({
    super.key,
    required this.controller,
    required this.validator,
    required this.onChanged,
    required this.locked,
    this.desktop = false,
  });

  final TextEditingController controller;
  final String? Function(String?) validator;
  final ValueChanged<String> onChanged;
  final bool locked;
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: !locked,
      textAlign: desktop ? TextAlign.end : TextAlign.start,
      decoration: InputDecoration(
        labelText: desktop ? null : (locked ? 'Toplu iskonto' : 'Iskonto %'),
        hintText: desktop && locked ? 'Toplu' : null,
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
