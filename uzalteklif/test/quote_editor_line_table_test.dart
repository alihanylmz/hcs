import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_line_table.dart';

void main() {
  testWidgets('renders header and rows with spacing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuoteEditorLineTable(
            header: Text('Baslik'),
            rows: [Text('Satir 1'), Text('Satir 2')],
          ),
        ),
      ),
    );
    expect(find.text('Baslik'), findsOneWidget);
    expect(find.text('Satir 1'), findsOneWidget);
    expect(find.text('Satir 2'), findsOneWidget);
  });
}
