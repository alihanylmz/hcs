import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/own_company.dart';
import 'package:uzalteklif/widgets/quote_editor_own_company_field.dart';

void main() {
  testWidgets('renders own company selector', (tester) async {
    final company = OwnCompany(
      id: 'own-1',
      name: 'Firma',
      shortName: '',
      tagline: '',
      phone: '',
      email: '',
      website: '',
      address: '',
      taxOffice: '',
      taxNumber: '',
      mersis: '',
      bankName: '',
      bankBranch: '',
      bankAccountName: '',
      bankIban: '',
      bankSwift: '',
      defaultVatRate: 20,
      isDefault: true,
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorOwnCompanyField(
            companies: [company],
            selectedCompanyId: 'own-1',
            enabled: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Firma'), findsNWidgets(2));
  });
}
