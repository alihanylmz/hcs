import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_offer_fields.dart';

void main() {
  testWidgets('renders offer title preview and notes counter', (tester) async {
    final title = TextEditingController(text: 'Bakim');
    final notes = TextEditingController(text: 'Not');
    addTearDown(title.dispose);
    addTearDown(notes.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorOfferFields(
            titleController: title,
            noteController: notes,
            composedTitle: 'Firma - Bakim - KOD',
            onTitleChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Konu'), findsOneWidget);
    expect(find.text('Kayit adi: Firma - Bakim - KOD'), findsOneWidget);
    expect(find.textContaining('3 karakter'), findsOneWidget);
  });
}
