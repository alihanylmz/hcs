import 'package:flutter/material.dart';
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

/// Ekrandaki metin alanlarinin iceriklerini gorunme sirasiyla verir.
List<String> _fieldTexts(WidgetTester tester) => tester
    .widgetList<EditableText>(find.byType(EditableText))
    .map((e) => e.controller.text)
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  Future<void> pumpWithTwoLines(WidgetTester tester) async {
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

  testWidgets('cogaltma kopyayi kaynagin hemen altina koyar', (tester) async {
    await pumpWithTwoLines(tester);

    final before = _fieldTexts(tester);
    expect(before.where((t) => t == '7'), hasLength(1));
    expect(before.where((t) => t == '9'), hasLength(1));

    // Ilk satiri cogalt.
    final duplicateButtons = find.byIcon(Icons.copy_all_outlined);
    expect(duplicateButtons, findsNWidgets(2), reason: 'her satirda bir buton');
    await tester.tap(duplicateButtons.first);
    await tester.pumpAndSettle();

    final after = _fieldTexts(tester);

    // Kopya olustu: miktar 7 artik iki kez var.
    expect(
      after.where((t) => t == '7'),
      hasLength(2),
      reason: 'kaynagin degerleri kopyalanmali',
    );

    // Kopya sona degil, kaynagin hemen altina girmeli: ekrandaki sirada
    // iki tane 7, ikinci satirin 9'undan once gelmeli.
    final firstNine = after.indexOf('9');
    final sevens = <int>[
      for (var i = 0; i < after.length; i++)
        if (after[i] == '7') i,
    ];
    expect(sevens, hasLength(2));
    expect(
      sevens.every((i) => i < firstNine),
      isTrue,
      reason: 'kopya kaynagin altina, ikinci kalemin ustune girmeli',
    );
  });

  testWidgets('cogaltma urun kodunu ve aciklamayi korur', (tester) async {
    await pumpWithTwoLines(tester);

    await tester.tap(find.byIcon(Icons.copy_all_outlined).first);
    await tester.pumpAndSettle();

    // Ilk urunun aciklamasi iki kez gorunmeli.
    final texts = _fieldTexts(tester);
    expect(
      texts.where((t) => t.contains('Birinci urun')),
      hasLength(2),
      reason: 'aciklama kopyaya tasinmali',
    );
  });
}
