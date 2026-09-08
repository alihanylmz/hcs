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

/// Kaydirilabilir listelerde hedef ekran disinda kalabiliyor; once gorunur
/// hale getirilmezse tap() sessizce iskaliyor.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _goToStep(WidgetTester tester, int step) async {
  await tester.tap(find.byKey(ValueKey('quote-step-$step')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  Future<void> pumpCatalog(WidgetTester tester) async {
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
            _product('p-3', 'CCC-3', 'Ucuncu urun'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _goToStep(tester, 1);
    // Katalogu ac.
    await tester.tap(find.byIcon(Icons.add_shopping_cart_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('hicbir sey secili degilken toplu islem cubugu cikmaz', (
    tester,
  ) async {
    await pumpCatalog(tester);
    expect(find.byKey(const ValueKey('catalog-selection-add')), findsNothing);
    expect(find.byKey(const ValueKey('catalog-selection-add')), findsNothing);
  });

  testWidgets('secilen urunlerin hepsi tek seferde eklenir', (tester) async {
    await pumpCatalog(tester);

    await _tapVisible(tester, find.byKey(const ValueKey('catalog-check-p-1')));
    await _tapVisible(tester, find.byKey(const ValueKey('catalog-check-p-3')));

    expect(find.textContaining('2 urun secildi'), findsOneWidget);

    await _tapVisible(tester, find.byKey(const ValueKey('catalog-selection-add')));

    // Iki kalem olusmali, isaretlenmeyen urun eklenmemeli.
    expect(find.byKey(const ValueKey('quote-line-p-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-line-p-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('quote-line-p-2')), findsNothing);

    // Ekleme sonrasi isaretler temizlenmeli, aksi halde ayni urunler
    // ikinci kez eklenmeye hazir kalir.
    expect(find.byKey(const ValueKey('catalog-selection-add')), findsNothing);
  });

  testWidgets('temizle isaretleri kaldirir, kalem eklemez', (tester) async {
    await pumpCatalog(tester);

    await _tapVisible(tester, find.byKey(const ValueKey('catalog-check-p-2')));
    expect(find.textContaining('1 urun secildi'), findsOneWidget);

    await _tapVisible(tester, find.byKey(const ValueKey('catalog-selection-clear')));

    expect(find.byKey(const ValueKey('catalog-selection-add')), findsNothing);
    expect(find.byKey(const ValueKey('quote-line-p-2')), findsNothing);
  });
}
