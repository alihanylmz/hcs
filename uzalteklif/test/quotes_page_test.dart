import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:uzalteklif/models/market_rate.dart';
import 'package:uzalteklif/models/product.dart';
import 'package:uzalteklif/models/quote.dart';
import 'package:uzalteklif/screens/quotes_page.dart';
import 'package:uzalteklif/services/cari_repository.dart';
import 'package:uzalteklif/services/market_rate_service.dart';
import 'package:uzalteklif/services/own_company_repository.dart';
import 'package:uzalteklif/services/price_adjustment_rule_repository.dart';
import 'package:uzalteklif/services/product_repository.dart';
import 'package:uzalteklif/services/quote_repository.dart';
import 'package:uzalteklif/services/user_profile_repository.dart';
import 'package:uzalteklif/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('quotes page provides list and sales board views', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: QuotesPage(
          quoteRepository: _FakeQuoteRepository(),
          productRepository: _FakeProductRepository(),
          marketRateService: _FakeMarketRateService(),
          ownCompanyRepository: const OwnCompanyRepository(),
          priceAdjustmentRuleRepository: const PriceAdjustmentRuleRepository(),
          userProfileRepository: UserProfileRepository(),
          cariRepository: CariRepository(),
          isManager: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tüm cariler'), findsOneWidget);
    expect(find.text('Tüm kullanıcılar'), findsOneWidget);
    expect(find.text('Teklif kodu veya konu ara'), findsOneWidget);
    expect(find.text('Liste (0)'), findsOneWidget);
    expect(find.text('Pano'), findsOneWidget);

    await tester.tap(find.text('Pano'));
    await tester.pumpAndSettle();

    expect(find.text('Taslak'), findsOneWidget);
    expect(find.text('Gönderime Hazır'), findsOneWidget);
    expect(find.text('Müşteriye Gönderildi'), findsOneWidget);
  });
}

class _FakeQuoteRepository extends QuoteRepository {
  @override
  Future<List<Quote>> fetchQuotes() async => const [];
}

class _FakeProductRepository extends ProductRepository {
  @override
  Future<List<Product>> fetchProducts() async => const [];
}

class _FakeMarketRateService extends MarketRateService {
  @override
  Future<List<MarketRate>> fetchRates() async => const [];
}
