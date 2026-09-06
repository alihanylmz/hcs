import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_manage_cari_button.dart';

void main() {
  testWidgets('renders manage cari action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: QuoteEditorManageCariButton(onPressed: () {})),
      ),
    );
    expect(find.text('Carileri yonet'), findsOneWidget);
  });
}
