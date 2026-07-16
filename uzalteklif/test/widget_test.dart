import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:uzalteklif/models/market_rate.dart';
import 'package:uzalteklif/screens/home_page.dart';
import 'package:uzalteklif/services/market_rate_service.dart';
import 'package:uzalteklif/services/product_repository.dart';
import 'package:uzalteklif/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('home screen renders offer flow', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(
          productRepository: ProductRepository(),
          marketRateService: _FakeMarketRateService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UZAL TEKNIK'), findsOneWidget);
    expect(find.textContaining('Siemens - QAE2120.010'), findsAtLeastNWidgets(1));
    expect(find.textContaining('urun listeleniyor'), findsOneWidget);
  });
}

class _FakeMarketRateService extends MarketRateService {
  @override
  Future<List<MarketRate>> fetchRates() async {
    final now = DateTime(2026, 4, 20, 12);
    return [
      MarketRate(
        code: 'USDTRY',
        label: 'Dolar',
        unitLabel: '1 USD',
        value: 38.2,
        updatedAt: now,
      ),
      MarketRate(
        code: 'EURTRY',
        label: 'Euro',
        unitLabel: '1 EUR',
        value: 41.7,
        updatedAt: now,
      ),
    ];
  }
}
