import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/cari_account.dart';
import 'package:uzalteklif/widgets/quote_editor_cari_dropdown.dart';

void main() {
  testWidgets('renders manual and saved cari options', (tester) async {
    final cari = CariAccount(
      id: 'cari-1',
      companyName: 'Ornek Firma',
      contactName: 'Ali',
      contactTitle: '',
      phone: '',
      email: '',
      address: '',
      taxOffice: '',
      taxNumber: '',
      notes: '',
      updatedAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorCariDropdown(
            cariler: [cari],
            selectedValue: 'cari-1',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Kayitli cari'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ornek Firma'), findsOneWidget);
  });
}
