import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_total_card.dart';

void main() {
  testWidgets('renders total and rate text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuoteEditorTotalCard(
            totalText: '1.000 TL',
            rateText: 'Teklif TL olarak hazirlaniyor',
          ),
        ),
      ),
    );
    expect(find.text('Genel Toplam'), findsOneWidget);
    expect(find.text('1.000 TL'), findsOneWidget);
  });
}
