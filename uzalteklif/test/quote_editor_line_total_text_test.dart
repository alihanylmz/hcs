import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_line_total_text.dart';

void main() {
  testWidgets('renders line total with optional prefix', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuoteEditorLineTotalText(
            prefix: 'Satır toplamı: ',
            text: '1.250,00 TL',
          ),
        ),
      ),
    );
    expect(find.text('Satır toplamı: 1.250,00 TL'), findsOneWidget);
  });
}
