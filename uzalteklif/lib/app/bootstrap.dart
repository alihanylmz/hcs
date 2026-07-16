import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../services/admin_repository.dart';
import '../services/cari_repository.dart';
import '../services/market_rate_service.dart';
import '../services/own_company_repository.dart';
import '../services/price_adjustment_rule_repository.dart';
import '../services/product_repository.dart';
import '../services/quote_repository.dart';
import '../services/theme_preference_service.dart';
import '../services/user_profile_repository.dart';

class AppBootstrap {
  const AppBootstrap({
    required this.productRepository,
    required this.adminRepository,
    required this.quoteRepository,
    required this.marketRateService,
    required this.ownCompanyRepository,
    required this.priceAdjustmentRuleRepository,
    required this.userProfileRepository,
    required this.cariRepository,
    required this.themePreferenceService,
    required this.supabaseActive,
  });

  final ProductRepository productRepository;
  final AdminRepository adminRepository;
  final QuoteRepository quoteRepository;
  final MarketRateService marketRateService;
  final OwnCompanyRepository ownCompanyRepository;
  final PriceAdjustmentRuleRepository priceAdjustmentRuleRepository;
  final UserProfileRepository userProfileRepository;
  final CariRepository cariRepository;
  final ThemePreferenceService themePreferenceService;
  final bool supabaseActive;

  static Future<AppBootstrap> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    SupabaseClient? client;

    if (AppConfig.hasSupabase) {
      try {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
        );
        client = Supabase.instance.client;
      } catch (_) {}
    }

    final themePreferenceService = await ThemePreferenceService.create();

    return AppBootstrap(
      productRepository: ProductRepository(client: client),
      adminRepository: AdminRepository(client: client),
      quoteRepository: QuoteRepository(client: client),
      marketRateService: MarketRateService(client: client),
      ownCompanyRepository: OwnCompanyRepository(client: client),
      priceAdjustmentRuleRepository: PriceAdjustmentRuleRepository(
        client: client,
      ),
      userProfileRepository: UserProfileRepository(client: client),
      cariRepository: CariRepository(client: client),
      themePreferenceService: themePreferenceService,
      supabaseActive: client != null,
    );
  }
}
