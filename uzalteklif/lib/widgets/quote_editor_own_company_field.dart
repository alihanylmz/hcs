import 'package:flutter/material.dart';

import '../models/own_company.dart';

class QuoteEditorOwnCompanyField extends StatelessWidget {
  const QuoteEditorOwnCompanyField({
    super.key,
    required this.companies,
    required this.selectedCompanyId,
    required this.enabled,
    required this.onChanged,
  });

  final List<OwnCompany> companies;
  final String selectedCompanyId;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = companies.any((company) => company.id == selectedCompanyId)
        ? selectedCompanyId
        : companies.first.id;
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Firma'),
      items: [
        for (final company in companies)
          DropdownMenuItem(value: company.id, child: Text(company.menuLabel)),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
