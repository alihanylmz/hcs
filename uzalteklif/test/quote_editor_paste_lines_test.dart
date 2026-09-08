import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:uzalteklif/screens/quote_editor_page.dart';
import 'package:uzalteklif/services/quote_repository.dart';
import 'package:uzalteklif/theme/app_theme.dart';

Future<void> _goToStep(WidgetTester tester, int step) async {
  await tester.tap(find.byKey(ValueKey('quote-step-$step')));
  await tester.pumpAndSettle();
}

Future<void> _openPasteDialog(WidgetTester tester) async {
  final opener = find.byKey(const ValueKey('paste-lines-open'));
  await tester.ensureVisible(opener);
  await tester.pumpAndSettle();
  await tester.tap(opener);
  await tester.pumpAndSettle();
}

List<String> _fieldTexts(WidgetTester tester) => tester
    .widgetList<EditableText>(find.byType(EditableText))
    .map((e) => e.controller.text)
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  Future<void> pumpEditor(WidgetTester tester) async {
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
          availableProducts: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _goToStep(tester, 1);
  }

  testWidgets('yapistirilan satirlar onizlenir ve teklife eklenir', (
    tester,
  ) async {
    await pumpEditor(tester);
    await _openPasteDialog(tester);

    await tester.enterText(
      find.byKey(const ValueKey('paste-lines-input')),
      'Kablo kanali\t10\tmetre\t125,50\t5\n'
      'Pano montaji\t2\tadet\t1.500,00\t0',
    );
    await tester.pumpAndSettle();

    // Onizleme eklemeden once ne olusacagini gostermeli.
    expect(find.textContaining('2 satır eklenecek'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('paste-lines-confirm')));
    await tester.pumpAndSettle();

    final texts = _fieldTexts(tester);
    expect(texts, contains('Kablo kanali'));
    expect(texts, contains('Pano montaji'));
    // Turkce ondalik dogru okunmali: 1.500,00 -> 1500.00, 125,50 -> 125.50
    expect(texts, contains('1500.00'));
    expect(texts, contains('125.50'));
    expect(texts, contains('metre'));
  });

  testWidgets('bos metinle ekle butonu pasif', (tester) async {
    await pumpEditor(tester);
    await _openPasteDialog(tester);

    final confirm = tester.widget<FilledButton>(
      find.byKey(const ValueKey('paste-lines-confirm')),
    );
    expect(
      confirm.onPressed,
      isNull,
      reason: 'yapistirilacak satir yokken ekleme yapilamamali',
    );
  });

  testWidgets('baslik satiri otomatik isaretlenir ve eklenmez', (tester) async {
    await pumpEditor(tester);
    await _openPasteDialog(tester);

    await tester.enterText(
      find.byKey(const ValueKey('paste-lines-input')),
      'Aciklama\tMiktar\tBirim\nGercek kalem\t3\tadet',
    );
    await tester.pumpAndSettle();

    // Ikinci hucre sayi olmadigi icin ilk satir baslik sayilmali.
    final checkbox = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('paste-lines-skip-header')),
    );
    expect(checkbox.value, isTrue);
    expect(find.textContaining('1 satır eklenecek'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('paste-lines-confirm')));
    await tester.pumpAndSettle();

    final texts = _fieldTexts(tester);
    expect(texts, contains('Gercek kalem'));
    expect(
      texts.where((t) => t == 'Aciklama'),
      isEmpty,
      reason: 'baslik satiri kalem olarak eklenmemeli',
    );
  });
}
