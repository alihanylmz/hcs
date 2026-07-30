import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uzalteklif/models/own_company.dart';
import 'package:uzalteklif/screens/company_settings_page.dart';
import 'package:uzalteklif/services/own_company_repository.dart';
import 'package:uzalteklif/theme/app_theme.dart';

void main() {
  testWidgets('company settings updates the PDF company record', (
    WidgetTester tester,
  ) async {
    final repository = _FakeOwnCompanyRepository(
      OwnCompany(
        id: 'company-1',
        name: 'Eski Firma',
        shortName: 'Eski',
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
        updatedAt: DateTime(2026, 7, 30),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CompanySettingsPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eski Firma'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Yeni Firma AŞ');
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await tester.pumpAndSettle();

    expect(repository.saved?.name, 'Yeni Firma AŞ');
    expect(repository.saved?.isDefault, isTrue);
  });
}

class _FakeOwnCompanyRepository extends OwnCompanyRepository {
  _FakeOwnCompanyRepository(this.company);

  final OwnCompany company;
  OwnCompany? saved;

  @override
  Future<List<OwnCompany>> fetchAll() async => [company];

  @override
  Future<void> save(OwnCompany company) async {
    saved = company;
  }
}
