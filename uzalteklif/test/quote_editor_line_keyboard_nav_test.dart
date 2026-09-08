import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:uzalteklif/models/product.dart';
import 'package:uzalteklif/screens/quote_editor_page.dart';
import 'package:uzalteklif/services/quote_repository.dart';
import 'package:uzalteklif/theme/app_theme.dart';

Product _product(String id, String code, String name) => Product(
  id: id,
  code: code,
  name: name,
  category: 'Sensor',
  brand: 'B',
  model: 'M',
  unit: 'adet',
  currencyCode: 'TL',
  salePrice: 100,
  stockQuantity: 5,
  minimumStock: 1,
  vatRate: 20,
  leadTime: '',
  description: '',
  technicalSummary: '',
  isActive: true,
  updatedAt: DateTime(2026, 9, 8),
);

Future<void> _goToStep(WidgetTester tester, int step) async {
  await tester.tap(find.byKey(ValueKey('quote-step-$step')));
  await tester.pumpAndSettle();
}

/// Su an odakli olan metin alaninin icerigi. Odakli alan yoksa null.
String? _focusedText(WidgetTester tester) {
  for (final e in tester.widgetList<EditableText>(find.byType(EditableText))) {
    if (e.focusNode.hasFocus) return e.controller.text;
  }
  return null;
}

/// Icerigi [text] olan metin alanini bulur.
Finder _fieldWithText(String text) => find.byWidgetPredicate(
  (w) => w is EditableText && w.controller.text == text,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  Future<void> pumpEditorWithTwoLines(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: QuoteEditorPage(
          quoteRepository: QuoteRepository(),
          initialRates: const [],
          availableProducts: [
            _product('p-1', 'AAA-1', 'Birinci urun'),
            _product('p-2', 'BBB-2', 'Ikinci urun'),
          ],
          // Miktarlar bilerek farkli: odagin hangi satira gectigini
          // icerikten ayirt edebilmek icin.
          initialProductLines: const [
            QuoteInitialProductLine(productId: 'p-1', quantity: 7),
            QuoteInitialProductLine(productId: 'p-2', quantity: 9),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _goToStep(tester, 1);
  }

  testWidgets('Enter ayni sutunda bir alt satira gecer', (tester) async {
    await pumpEditorWithTwoLines(tester);

    // Ilk satirin miktar alanina odaklan.
    await tester.tap(_fieldWithText('7').first);
    await tester.pumpAndSettle();
    expect(_focusedText(tester), '7');

    // Enter: ayni sutun (miktar), bir alt satir.
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    expect(
      _focusedText(tester),
      '9',
      reason: 'Enter miktar sutununda ikinci satira gecmeliydi',
    );
  });

  testWidgets('son satirda Enter odagi listenin basina sarmaz', (tester) async {
    await pumpEditorWithTwoLines(tester);

    // Son satirin miktar alanina odaklan.
    await tester.tap(_fieldWithText('9').first);
    await tester.pumpAndSettle();
    expect(_focusedText(tester), '9');

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();

    // Basa sarmak yanlislikla ustteki veriyi ezmeye davet ettigi icin
    // odak oldugu yerde kalir.
    expect(
      _focusedText(tester),
      isNot('7'),
      reason: 'Son satirdan sonra odak ilk satira sarmamali',
    );
  });

}
