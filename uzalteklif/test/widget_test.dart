import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:uzalteklif/models/market_rate.dart';
import 'package:uzalteklif/models/product.dart';
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
    expect(find.text('Siemens'), findsAtLeastNWidgets(1));
    expect(find.text('Kontrolörler'), findsOneWidget);
    expect(find.text('DDC Kontrolörleri'), findsAtLeastNWidgets(1));
    expect(find.textContaining('urun listeleniyor'), findsOneWidget);
  });

  testWidgets('bulk price filters narrow the visible product list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomePage(
          productRepository: _FakeProductRepository([
            Product(
              id: '1',
              code: 'ABB-PLC-1',
              name: 'ABB PLC',
              category: 'PLC',
              brand: 'ABB',
              model: 'X1',
              unit: 'adet',
              currencyCode: 'TL',
              salePrice: 1000,
              stockQuantity: 1,
              minimumStock: 0,
              vatRate: 20,
              leadTime: '',
              description: '',
              technicalSummary: '',
              isActive: true,
              updatedAt: DateTime(2026, 9, 1, 12),
            ),
            Product(
              id: '2',
              code: 'ABB-HMI-1',
              name: 'ABB HMI',
              category: 'HMI',
              brand: 'ABB',
              model: 'X2',
              unit: 'adet',
              currencyCode: 'TL',
              salePrice: 900,
              stockQuantity: 1,
              minimumStock: 0,
              vatRate: 20,
              leadTime: '',
              description: '',
              technicalSummary: '',
              isActive: true,
              updatedAt: DateTime(2026, 9, 1, 12),
            ),
            Product(
              id: '3',
              code: 'SIE-PLC-1',
              name: 'Siemens PLC',
              category: 'PLC',
              brand: 'Siemens',
              model: 'X3',
              unit: 'adet',
              currencyCode: 'TL',
              salePrice: 1100,
              stockQuantity: 1,
              minimumStock: 0,
              vatRate: 20,
              leadTime: '',
              description: '',
              technicalSummary: '',
              isActive: true,
              updatedAt: DateTime(2026, 9, 1, 12),
            ),
          ]),
          marketRateService: _FakeMarketRateService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 urun listeleniyor'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bulk-price-brand-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ABB').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bulk-price-category-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLC').last);
    await tester.pumpAndSettle();

    expect(find.text('1 urun listeleniyor'), findsOneWidget);
    expect(find.text('ABB PLC'), findsAtLeastNWidgets(1));
    expect(find.text('ABB HMI'), findsNothing);
    expect(find.text('Siemens PLC'), findsNothing);
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

class _FakeProductRepository extends ProductRepository {
  _FakeProductRepository(this.products);

  final List<Product> products;

  @override
  Future<List<Product>> fetchProducts() async => products;
}
