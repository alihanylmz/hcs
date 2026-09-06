import 'package:flutter/material.dart';

class QuoteEditorCustomerContactFields extends StatelessWidget {
  const QuoteEditorCustomerContactFields({
    super.key,
    required this.companyController,
    required this.nameController,
    required this.titleController,
    required this.phoneController,
    required this.emailController,
    required this.onCompanyChanged,
  });

  final TextEditingController companyController;
  final TextEditingController nameController;
  final TextEditingController titleController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final ValueChanged<String> onCompanyChanged;

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Zorunlu alan' : null;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: companyController,
          decoration: const InputDecoration(labelText: 'Firma Adi'),
          validator: _required,
          onChanged: onCompanyChanged,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Yetkili Ad Soyad'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Unvan'),
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
