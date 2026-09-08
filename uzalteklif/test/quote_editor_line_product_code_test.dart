import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_line_product_code.dart';

void main() {
  testWidgets('renders product code or fallback dash', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              QuoteEditorLineProductCode(code: 'PRD-1'),
              QuoteEditorLineProductCode(code: ''),
            ],
          ),
        ),
      ),
    );
    expect(find.text('PRD-1'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });
}
