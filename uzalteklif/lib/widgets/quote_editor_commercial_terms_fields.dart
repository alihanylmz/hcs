import 'package:flutter/material.dart';

/// Commercial terms inputs used by the quote editor.
class QuoteEditorCommercialTermsFields extends StatelessWidget {
  const QuoteEditorCommercialTermsFields({
    super.key,
    required this.validityController,
    required this.deliveryTermsController,
    required this.paymentTermsController,
  });

  final TextEditingController validityController;
  final TextEditingController deliveryTermsController;
  final TextEditingController paymentTermsController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: validityController,
          decoration: const InputDecoration(labelText: 'Teklif Gecerliligi'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: deliveryTermsController,
          decoration: const InputDecoration(labelText: 'Teslim Kosulu'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: paymentTermsController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Odeme Kosulu'),
        ),
      ],
    );
  }
}
