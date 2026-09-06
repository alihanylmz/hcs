import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_move_menu.dart';

void main() {
  testWidgets('renders move menu when targets exist', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorMoveMenu(
            targets: const [QuoteEditorMoveTarget(id: 'a', label: 'Kategori')],
            onSelected: (_) {},
            color: Colors.blue,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.drive_file_move_outline), findsOneWidget);
  });
}
