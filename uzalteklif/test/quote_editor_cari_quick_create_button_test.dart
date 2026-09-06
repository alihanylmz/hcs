import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_cari_quick_create_button.dart';

void main() {
  testWidgets('renders quick cari create action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorCariQuickCreateButton(onPressed: () {}),
        ),
      ),
    );
    expect(find.text('Hizli cari ekle'), findsOneWidget);
  });
}
