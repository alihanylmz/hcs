import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_line_table_header.dart';

void main() {
  testWidgets('renders line table header on wide layout', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            child: QuoteEditorLineTableHeader(priceCurrencyLabel: 'TL'),
          ),
        ),
      ),
    );
    expect(find.byType(QuoteEditorLineTableHeader), findsOneWidget);
  });
}
