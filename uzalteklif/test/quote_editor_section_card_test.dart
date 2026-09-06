import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_section_card.dart';

void main() {
  testWidgets('renders title, subtitle and child content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuoteEditorSectionCard(
            title: 'Baslik',
            subtitle: 'Aciklama',
            child: Text('Icerik'),
          ),
        ),
      ),
    );

    expect(find.text('Baslik'), findsOneWidget);
    expect(find.text('Aciklama'), findsOneWidget);
    expect(find.text('Icerik'), findsOneWidget);
  });
}
