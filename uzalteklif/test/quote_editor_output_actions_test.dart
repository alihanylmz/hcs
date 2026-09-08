import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_output_actions.dart';

void main() {
  testWidgets('shows save and export actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorOutputActions(
            isSubmitting: false,
            canCompleteQuote: true,
            isRevision: false,
            onSubmitForApproval: () {},
            onSave: () {},
            onExportPdf: () {},
            onExportExcel: () {},
            onExportMaterialRequestPdf: () {},
            onExportMaterialRequestExcel: () {},
          ),
        ),
      ),
    );

    expect(find.text('Teklifi Tamamla'), findsOneWidget);
    expect(find.text('Taslak Olarak Kaydet'), findsOneWidget);
    expect(find.text('PDF Cikart'), findsOneWidget);
    expect(find.text('Istek Excel'), findsOneWidget);
  });
}
