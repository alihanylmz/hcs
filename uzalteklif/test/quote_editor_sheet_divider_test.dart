import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_sheet_divider.dart';

void main() {
  testWidgets('renders the sheet divider', (tester) async {
    await tester.pumpWidget(const QuoteEditorSheetDivider());
    expect(find.byType(QuoteEditorSheetDivider), findsOneWidget);
  });
}
