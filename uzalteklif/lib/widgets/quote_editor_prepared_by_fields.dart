import 'package:flutter/material.dart';

class QuoteEditorPreparedByFields extends StatelessWidget {
  const QuoteEditorPreparedByFields({
    super.key,
    required this.nameController,
    required this.titleController,
    required this.phoneController,
    required this.emailController,
  });

  final TextEditingController nameController;
  final TextEditingController titleController;
  final TextEditingController phoneController;
  final TextEditingController emailController;

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Zorunlu alan' : null;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Ad Soyad'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Unvan'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: phoneController,
          decoration: const InputDecoration(labelText: 'Telefon'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'E-posta'),
        ),
      ],
    );
  }
}
