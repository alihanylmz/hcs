import 'dart:async';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/market_rate.dart';
import '../models/price_adjustment_rule.dart';
import '../models/product.dart';
import '../services/market_rate_service.dart';
import '../services/price_adjustment_rule_repository.dart';
import '../services/product_csv_service.dart';
import '../services/product_repository.dart';
import '../utils/product_category_labels.dart';
import '../widgets/workspace_background.dart';
import '../services/module_switcher.dart';
import 'product_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.productRepository,
    required this.marketRateService,
    PriceAdjustmentRuleRepository? priceAdjustmentRuleRepository,
  }) : priceAdjustmentRuleRepository =
           priceAdjustmentRuleRepository ??
           const PriceAdjustmentRuleRepository();

  final ProductRepository productRepository;
  final MarketRateService marketRateService;
  final PriceAdjustmentRuleRepository priceAdjustmentRuleRepository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Product> _products = const [];
  List<MarketRate> _rates = const [];
  List<PriceAdjustmentRule> _priceRules = const [];
  final _productCsvService = const ProductCsvService();
  final _bulkSearchController = TextEditingController();
  bool _isLoading = true;
  bool _isImportingCsv = false;
  bool _isRefreshingRates = false;
  bool _isApplyingPriceRule = false;
  bool _isApplyingBulkPriceUpdate = false;
  String _searchQuery = '';
  String _bulkBrandFilter = '';
  String _bulkCategoryFilter = '';
  String _codeFilter = '';
  String _nameFilter = '';
  String _brandModelFilter = '';
  String _currencyFilter = 'Tum Dovizler';
  bool? _lowStockFilter;
  double? _minTlFilter;
  double? _maxTlFilter;
  bool _showAdvancedSearch = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: AppConfig.ratesRefreshMinutes),
      (_) => _refreshRates(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _bulkSearchController.dispose();
    super.dispose();
  }

  Map<String, double> get _rateLookup {
    return {'TL': 1, for (final rate in _rates) rate.code: rate.value};
  }

  List<Product> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    final brandFilter = _bulkBrandFilter.trim().toLowerCase();
    final categoryFilter = _bulkCategoryFilter.trim().toLowerCase();
    final codeQuery = _codeFilter.trim().toLowerCase();
    final nameQuery = _nameFilter.trim().toLowerCase();
    final brandModelQuery = _brandModelFilter.trim().toLowerCase();
    final rates = _rateLookup;

    return _products
        .where((product) {
          final matchesQuery =
              query.isEmpty ||
              product.code.toLowerCase().contains(query) ||
              product.name.toLowerCase().contains(query);
          final matchesBrand =
              brandFilter.isEmpty ||
              product.brand.trim().toLowerCase() == brandFilter;
          final matchesCategory =
              categoryFilter.isEmpty ||
              product.category.trim().toLowerCase() == categoryFilter;
          final matchesCode =
              codeQuery.isEmpty ||
              product.code.toLowerCase().contains(codeQuery);
          final matchesName =
              nameQuery.isEmpty ||
              product.name.toLowerCase().contains(nameQuery);
          final brandModel = '${product.brand} ${product.model}'.toLowerCase();
          final matchesBrandModel =
              brandModelQuery.isEmpty || brandModel.contains(brandModelQuery);
          final matchesCurrency =
              _currencyFilter == 'Tum Dovizler' ||
              product.currencyLabel == _currencyFilter;
          final matchesStock =
              _lowStockFilter == null ||
              (_lowStockFilter! ? product.isLowStock : !product.isLowStock);

          final tlPrice = product.priceInTl(rates);
          final matchesMinTl = _minTlFilter == null || tlPrice >= _minTlFilter!;
          final matchesMaxTl = _maxTlFilter == null || tlPrice <= _maxTlFilter!;

          return matchesQuery &&
              matchesBrand &&
              matchesCategory &&
              matchesCode &&
              matchesName &&
              matchesBrandModel &&
              matchesCurrency &&
              matchesStock &&
              matchesMinTl &&
              matchesMaxTl;
        })
        .toList(growable: false);
  }

  List<String> get _availableBrands {
    final brands =
        _products
            .map((product) => product.brand.trim())
            .where((brand) => brand.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return brands;
  }

  List<String> get _availableCategories {
    final categories =
        _products
            .map((product) => product.category.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return categories;
  }

  bool get _hasActiveBulkFilter =>
      _bulkBrandFilter.trim().isNotEmpty ||
      _bulkCategoryFilter.trim().isNotEmpty ||
      _searchQuery.trim().isNotEmpty;

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    final products = await widget.productRepository.fetchProducts();
    final rates = await widget.marketRateService.fetchRates();
    final priceRules = await widget.priceAdjustmentRuleRepository.fetchRules();
    if (!mounted) {
      return;
    }

    setState(() {
      _products = products;
      _rates = rates;
      _priceRules = priceRules;
      _isLoading = false;
    });
  }

  Future<void> _openPriceRuleDialog({PriceAdjustmentRule? existing}) async {
    final rule = await showDialog<PriceAdjustmentRule>(
      context: context,
      builder: (ctx) =>
          _PriceRuleDialog(existing: existing, products: _products),
    );
    if (rule == null || !mounted) return;

    setState(() => _isApplyingPriceRule = true);
    try {
      await widget.priceAdjustmentRuleRepository.saveRule(rule);
      final affected = await widget.productRepository.applyPriceAdjustmentRule(
        rule,
      );
      final products = await widget.productRepository.fetchProducts();
      final rules = await widget.priceAdjustmentRuleRepository.fetchRules();
      if (!mounted) return;
      setState(() {
        _products = products;
        _priceRules = rules;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$affected urunun fiyatı ${rule.percentage.toStringAsFixed(2)}% oranında güncellendi.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fiyat politikası uygulanamadı: $error')),
      );
    } finally {
      if (mounted) setState(() => _isApplyingPriceRule = false);
    }
  }

  Future<void> _deletePriceRule(PriceAdjustmentRule rule) async {
    try {
      await widget.priceAdjustmentRuleRepository.deleteById(rule.id);
      final rules = await widget.priceAdjustmentRuleRepository.fetchRules();
      if (!mounted) return;
      setState(() => _priceRules = rules);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kural silinemedi: $error')));
    }
  }

  Future<void> _refreshRates({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _isRefreshingRates = true);
    }

    final rates = await widget.marketRateService.refreshRates();
    if (!mounted) {
      return;
    }

    setState(() {
      _rates = rates;
      _isRefreshingRates = false;
    });
  }

  Future<void> _openProductDetail(Product product) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(
          product: product,
          productRepository: widget.productRepository,
        ),
      ),
    );
    // Detay ekraninda kaydetme olmussa memory listesi zaten guncellendi;
    // ekranda tazelemek icin urunleri tekrar cekiyoruz.
    if (!mounted) return;
    final refreshed = await widget.productRepository.fetchProducts();
    if (!mounted) return;
    setState(() => _products = refreshed);
  }

  Future<void> _openNewProduct() async {
    final now = DateTime.now();
    final draft = Product(
      id: 'product-${now.microsecondsSinceEpoch}',
      code: '',
      name: '',
      category: 'Genel',
      brand: '',
      model: '',
      unit: 'adet',
      currencyCode: 'EURTRY',
      salePrice: 0,
      stockQuantity: 0,
      minimumStock: 0,
      vatRate: 20,
      leadTime: '',
      description: '',
      technicalSummary: '',
      isActive: true,
      updatedAt: now,
    );

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(
          product: draft,
          productRepository: widget.productRepository,
          startInEditMode: true,
        ),
      ),
    );
    if (!mounted) return;
    final refreshed = await widget.productRepository.fetchProducts();
    if (!mounted) return;
    setState(() => _products = refreshed);
  }

  void _clearBulkFilters() {
    setState(() {
      _bulkBrandFilter = '';
      _bulkCategoryFilter = '';
      _searchQuery = '';
      _bulkSearchController.clear();
    });
  }

  String _bulkFilterSummary() {
    final segments = <String>[];
    if (_bulkBrandFilter.trim().isNotEmpty) {
      segments.add('Marka: $_bulkBrandFilter');
    }
    if (_bulkCategoryFilter.trim().isNotEmpty) {
      segments.add(
        'Kategori: ${productCategoryTurkishLabel(_bulkCategoryFilter)}',
      );
    }
    if (_searchQuery.trim().isNotEmpty) {
      segments.add('Arama: ${_searchQuery.trim()}');
    }
    return segments.isEmpty ? 'Filtre yok' : segments.join(' | ');
  }

  Future<void> _openBulkPriceUpdateDialog() async {
    if (!_hasActiveBulkFilter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Toplu fiyat guncellemeden once en az bir filtre secin.',
          ),
        ),
      );
      return;
    }

    final filteredProducts = _filteredProducts;
    if (filteredProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Secili filtrelere uyan urun bulunamadi.'),
        ),
      );
      return;
    }

    final request = await showDialog<_BulkPriceUpdateRequest>(
      context: context,
      builder: (context) => _BulkPriceUpdateDialog(
        products: filteredProducts,
        brand: _bulkBrandFilter,
        category: _bulkCategoryFilter,
        query: _searchQuery,
        filterSummary: _bulkFilterSummary(),
      ),
    );
    if (request == null || !mounted) return;

    setState(() => _isApplyingBulkPriceUpdate = true);
    try {
      final affected = await widget.productRepository.applyBulkPriceChange(
        brand: request.brand,
        category: request.category,
        query: request.query,
        percentage: request.percentage,
      );
      final refreshed = await widget.productRepository.fetchProducts();
      if (!mounted) return;
      setState(() => _products = refreshed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$affected urunun fiyati ${request.percentage >= 0 ? 'artirildi' : 'azaltildi'}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Toplu fiyat guncellemesi basarisiz: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isApplyingBulkPriceUpdate = false);
      }
    }
  }

  Future<void> _saveCsvTemplate() async {
    try {
      final saved = await _productCsvService.saveTemplate();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'CSV sablon kaydedildi.' : 'CSV sablon kaydi iptal edildi.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV sablon kaydedilemedi: $error')),
      );
    }
  }

  Future<void> _importProductsFromCsv() async {
    if (_isImportingCsv) return;
    setState(() => _isImportingCsv = true);
    try {
      final result = await _productCsvService.pickAndParse(
        existingProducts: _products,
      );
      if (result == null) return;
      if (result.products.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.skippedRows > 0
                  ? 'CSV okundu ama aktarilacak gecerli urun bulunamadi.'
                  : 'CSV dosyasinda urun satiri bulunamadi.',
            ),
          ),
        );
        return;
      }

      final existingCodes = _products
          .map((product) => product.code.trim().toUpperCase())
          .toSet();
      final updateCount = result.products
          .where(
            (product) =>
                existingCodes.contains(product.code.trim().toUpperCase()),
          )
          .length;
      final activeCount = result.products
          .where((product) => product.isActive)
          .length;
      if (!mounted) return;
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Malzeme listesini yükle'),
              content: Text(
                '${result.products.length} ürün bulundu.\n'
                '${result.products.length - updateCount} yeni ürün eklenecek, '
                '$updateCount mevcut ürün güncellenecek.\n'
                '$activeCount aktif, '
                '${result.products.length - activeCount} pasif ürün var.'
                '${result.skippedRows > 0 ? '\n${result.skippedRows} geçersiz satır atlanacak.' : ''}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('İptal'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Yükle'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;

      await widget.productRepository.saveProducts(result.products);
      final refreshed = await widget.productRepository.fetchProducts();
      if (!mounted) return;
      setState(() => _products = refreshed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.products.length} urun CSV ile yuklendi.'
            '${result.skippedRows > 0 ? ' ${result.skippedRows} satir atlandi.' : ''}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV yuklenemedi: $error')));
    } finally {
      if (mounted) setState(() => _isImportingCsv = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final showMarketSidebar = viewport.width >= 1500;
    final compactLayout = viewport.width < 1500;

    return Scaffold(
      body: WorkspaceBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(compactLayout ? 12 : 20),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : showMarketSidebar
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 9,
                        child: _buildProductsArea(expandList: true),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 2,
                        child: _buildSidebar(expandContent: true),
                      ),
                    ],
                  )
                : ListView(
                    children: [
                      _buildProductsArea(expandList: false),
                      const SizedBox(height: 20),
                      _buildSidebar(expandContent: false),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductsArea({required bool expandList}) {
    final filteredProducts = _filteredProducts;

    final listContent = filteredProducts.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Arama sonucuna uygun urun bulunamadi.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          )
        : _ProductTable(products: filteredProducts, onTap: _openProductDetail);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProductToolbar(),
            const SizedBox(height: 16),
            _buildBulkFilterBar(),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  hintText:
                      '🔍 Ürün Kodu, Malzeme Adı, Marka veya Model Ara...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF2B82C9),
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          tooltip: 'Aramayı Temizle',
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: () {
                            _bulkSearchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                      IconButton(
                        tooltip: _showAdvancedSearch
                            ? 'Detaylı Aramayı Gizle'
                            : 'Detaylı Aramayı Aç',
                        onPressed: () {
                          setState(
                            () => _showAdvancedSearch = !_showAdvancedSearch,
                          );
                        },
                        icon: Icon(
                          _showAdvancedSearch
                              ? Icons.filter_list_off_rounded
                              : Icons.tune_rounded,
                          color: _showAdvancedSearch
                              ? const Color(0xFF2B82C9)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            if (_showAdvancedSearch) ...[
              const SizedBox(height: 10),
              _AdvancedSearchPanel(
                codeFilter: _codeFilter,
                nameFilter: _nameFilter,
                brandModelFilter: _brandModelFilter,
                currencyFilter: _currencyFilter,
                lowStockFilter: _lowStockFilter,
                minTlFilter: _minTlFilter,
                maxTlFilter: _maxTlFilter,
                onCodeChanged: (value) => setState(() => _codeFilter = value),
                onNameChanged: (value) => setState(() => _nameFilter = value),
                onBrandModelChanged: (value) =>
                    setState(() => _brandModelFilter = value),
                onCurrencyChanged: (value) =>
                    setState(() => _currencyFilter = value),
                onStockChanged: (value) =>
                    setState(() => _lowStockFilter = value),
                onMinTlChanged: (value) => setState(() {
                  _minTlFilter = double.tryParse(
                    value.trim().replaceAll(',', '.'),
                  );
                }),
                onMaxTlChanged: (value) => setState(() {
                  _maxTlFilter = double.tryParse(
                    value.trim().replaceAll(',', '.'),
                  );
                }),
                onReset: () {
                  setState(() {
                    _codeFilter = '';
                    _nameFilter = '';
                    _brandModelFilter = '';
                    _currencyFilter = 'Tum Dovizler';
                    _lowStockFilter = null;
                    _minTlFilter = null;
                    _maxTlFilter = null;
                  });
                },
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '${filteredProducts.length} urun listeleniyor',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF657888),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (expandList)
              Expanded(child: listContent)
            else
              SizedBox(height: _responsiveTableHeight(), child: listContent),
          ],
        ),
      ),
    );
  }

  Widget _buildProductToolbar() {
    final compact = MediaQuery.sizeOf(context).width < 1500;
    final logoSize = compact ? 52.0 : 64.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF17304C), Color(0xFF1E3E62), Color(0xFF2B82C9)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF17304C).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 980;

          final logoAndTitle = Row(
            children: [
              Container(
                width: logoSize,
                height: logoSize,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'lib/assest/logo/uzal.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'UZAL TEKNİK',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: Colors.white,
                            fontSize: compact ? 20 : 24,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'Katalog & Stok',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Endüstriyel Ürün Kataloğu ve Fiyat Takip Otomasyonu',
                      style: TextStyle(
                        fontSize: compact ? 11.5 : 13,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => ModuleSwitcher.switchToTask(context),
                icon: const Icon(Icons.build_circle_outlined, size: 18),
                label: const Text('🛠️ İş Takip & Atölye ➔'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF17304C),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _saveCsvTemplate,
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('CSV Şablon'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isImportingCsv ? null : _importProductsFromCsv,
                icon: _isImportingCsv
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_file_rounded, size: 16),
                label: const Text('CSV Yükle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _openNewProduct,
                icon: const Icon(Icons.add_box_rounded, size: 18),
                label: const Text('Yeni Ürün Ekle'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF29956F),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [logoAndTitle, const SizedBox(height: 14), actions],
            );
          }

          return Row(
            children: [
              Expanded(child: logoAndTitle),
              const SizedBox(width: 16),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildBulkFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF7FAFD),
        border: Border.all(color: const Color(0xFFD8E0E8)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              key: const ValueKey('bulk-price-brand-filter'),
              initialValue: _bulkBrandFilter,
              isDense: true,
              decoration: const InputDecoration(labelText: 'Marka'),
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('Tum Markalar'),
                ),
                ..._availableBrands.map(
                  (brand) => DropdownMenuItem(value: brand, child: Text(brand)),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _bulkBrandFilter = value ?? ''),
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              key: const ValueKey('bulk-price-category-filter'),
              initialValue: _bulkCategoryFilter,
              isDense: true,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('Tum Kategoriler'),
                ),
                ..._availableCategories.map(
                  (category) => DropdownMenuItem(
                    value: category,
                    child: Text(productCategoryTurkishLabel(category)),
                  ),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _bulkCategoryFilter = value ?? ''),
            ),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              key: const ValueKey('bulk-price-query-filter'),
              controller: _bulkSearchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                labelText: 'Urun Ara',
                hintText: 'Urun kodu veya adi',
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          OutlinedButton.icon(
            key: const ValueKey('bulk-price-clear-filters'),
            onPressed: _clearBulkFilters,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Filtreyi Temizle'),
          ),
          FilledButton.icon(
            key: const ValueKey('bulk-price-open-dialog'),
            onPressed: _isApplyingBulkPriceUpdate
                ? null
                : _openBulkPriceUpdateDialog,
            icon: _isApplyingBulkPriceUpdate
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.price_change_rounded),
            label: const Text('Toplu Fiyat Guncelle'),
          ),
        ],
      ),
    );
  }

  double _responsiveTableHeight() {
    final proposed = MediaQuery.sizeOf(context).height - 330;
    if (proposed < 420) return 420;
    if (proposed > 700) return 700;
    return proposed;
  }

  Widget _buildSidebar({required bool expandContent}) {
    final sidebarContent = Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Canlı Piyasa',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _refreshRates(),
                      icon: _isRefreshingRates
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final rate in _rates) ...[
                  _RateCard(rate: rate),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    if (!expandContent) {
      return sidebarContent;
    }

    return Column(
      children: [Expanded(child: SingleChildScrollView(child: sidebarContent))],
    );
  }

  // Fiyat politikası işlemi yönetim alanına taşındığı için stok ekranında
  // gösterilmiyor; mevcut akışı kırmamak için form kodu korunuyor.
  // ignore: unused_element
  Widget _buildPricePolicyCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Fiyat Politikaları',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _isApplyingPriceRule
                      ? null
                      : () => _openPriceRuleDialog(),
                  icon: _isApplyingPriceRule
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.percent_rounded),
                  label: const Text('Fiyat Politikası Uygula'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Marka veya kategori bazlı fiyat politikası uygulayın; eşleşen ürün kartlarının satış fiyatı topluca güncellenir.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF5B6F7F),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            if (_priceRules.isEmpty)
              Text(
                'Aktif fiyat kuralı yok.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5B6F7F),
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              for (final rule in _priceRules.take(6)) ...[
                _PriceRuleTile(
                  rule: rule,
                  onDelete: () => _deletePriceRule(rule),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildFieldRow(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFFF0E3D3),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF17304C),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _PriceRuleTile extends StatelessWidget {
  const _PriceRuleTile({required this.rule, required this.onDelete});

  final PriceAdjustmentRule rule;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final target = switch (rule.scope) {
      PriceAdjustmentScope.brand => rule.brand,
      PriceAdjustmentScope.category => productCategoryTurkishLabel(
        rule.category,
      ),
      PriceAdjustmentScope.brandAndCategory =>
        '${rule.brand} / ${productCategoryTurkishLabel(rule.category)}',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.name.isEmpty
                      ? '${rule.scope.label}: $target'
                      : rule.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF17304C),
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${rule.scope.label} - $target',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF5B6F7F),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${rule.percentage >= 0 ? '+' : ''}${rule.percentage.toStringAsFixed(2)}%',
            style: const TextStyle(
              color: Color(0xFF9D5C1D),
              fontWeight: FontWeight.w900,
            ),
          ),
          IconButton(
            tooltip: 'Kuralı sil',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _PriceRuleDialog extends StatefulWidget {
  const _PriceRuleDialog({required this.products, this.existing});

  final List<Product> products;
  final PriceAdjustmentRule? existing;

  @override
  State<_PriceRuleDialog> createState() => _PriceRuleDialogState();
}

class _PriceRuleDialogState extends State<_PriceRuleDialog> {
  late final TextEditingController _name;
  late final TextEditingController _percentage;
  late PriceAdjustmentScope _scope;
  String _brand = '';
  String _category = '';

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _scope = existing?.scope ?? PriceAdjustmentScope.brand;
    final brands = _brands;
    final categories = _categories;
    _brand = existing?.brand ?? (brands.isEmpty ? '' : brands.first);
    _category =
        existing?.category ?? (categories.isEmpty ? '' : categories.first);
    _name = TextEditingController(text: existing?.name ?? '');
    _percentage = TextEditingController(
      text: existing == null ? '10' : existing.percentage.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _percentage.dispose();
    super.dispose();
  }

  List<String> get _brands {
    final list =
        widget.products
            .map((p) => p.brand.trim())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return list;
  }

  List<String> get _categories {
    final list =
        widget.products
            .map((p) => p.category.trim())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return list;
  }

  int get _affectedCount {
    final rule = _buildRule(preview: true);
    return widget.products.where(rule.matches).length;
  }

  PriceAdjustmentRule _buildRule({required bool preview}) {
    return PriceAdjustmentRule(
      id:
          widget.existing?.id ??
          'rule-${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      scope: _scope,
      brand: _scope == PriceAdjustmentScope.category ? '' : _brand,
      category: _scope == PriceAdjustmentScope.brand ? '' : _category,
      percentage:
          double.tryParse(_percentage.text.trim().replaceAll(',', '.')) ?? 0,
      isActive: true,
      updatedAt: preview
          ? (widget.existing?.updatedAt ?? DateTime.now())
          : DateTime.now().toUtc(),
    );
  }

  void _submit() {
    final rule = _buildRule(preview: false);
    if (rule.percentage == 0 || _affectedCount == 0) return;
    Navigator.of(context).pop(rule);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Fiyat Politikası Uygula'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<PriceAdjustmentScope>(
                initialValue: _scope,
                decoration: const InputDecoration(labelText: 'Kapsam'),
                items: PriceAdjustmentScope.values
                    .map(
                      (scope) => DropdownMenuItem(
                        value: scope,
                        child: Text(scope.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _scope = value);
                },
              ),
              const SizedBox(height: 12),
              if (_scope != PriceAdjustmentScope.category)
                DropdownButtonFormField<String>(
                  initialValue: _brands.contains(_brand) ? _brand : null,
                  decoration: const InputDecoration(labelText: 'Marka'),
                  items: _brands
                      .map(
                        (brand) =>
                            DropdownMenuItem(value: brand, child: Text(brand)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _brand = value ?? ''),
                ),
              if (_scope != PriceAdjustmentScope.brand) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _categories.contains(_category)
                      ? _category
                      : null,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: _categories
                      .map(
                        (cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(productCategoryTurkishLabel(cat)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _category = value ?? ''),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _percentage,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Fiyat değişim oranı (%)',
                  hintText: 'Örn. 10 veya -5',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Kural adı',
                  hintText: 'Honeywell dönemsel fiyat politikası',
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Etkilenecek ürün: $_affectedCount',
                  style: const TextStyle(
                    color: Color(0xFF17304C),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgec'),
        ),
        FilledButton(
          onPressed: _affectedCount == 0 ? null : _submit,
          child: const Text('Uygula ve fiyatları güncelle'),
        ),
      ],
    );
  }
}

class _BulkPriceUpdateRequest {
  const _BulkPriceUpdateRequest({
    required this.brand,
    required this.category,
    required this.query,
    required this.percentage,
  });

  final String brand;
  final String category;
  final String query;
  final double percentage;
}

class _BulkPriceUpdateDialog extends StatefulWidget {
  const _BulkPriceUpdateDialog({
    required this.products,
    required this.brand,
    required this.category,
    required this.query,
    required this.filterSummary,
  });

  final List<Product> products;
  final String brand;
  final String category;
  final String query;
  final String filterSummary;

  @override
  State<_BulkPriceUpdateDialog> createState() => _BulkPriceUpdateDialogState();
}

class _BulkPriceUpdateDialogState extends State<_BulkPriceUpdateDialog> {
  late final TextEditingController _percentageController;
  bool _isDecrease = false;

  @override
  void initState() {
    super.initState();
    _percentageController = TextEditingController(text: '10');
  }

  @override
  void dispose() {
    _percentageController.dispose();
    super.dispose();
  }

  double get _percentageValue {
    final parsed = double.tryParse(
      _percentageController.text.trim().replaceAll(',', '.'),
    );
    if (parsed == null) {
      return 0;
    }
    return parsed.abs();
  }

  double get _signedPercentage =>
      _isDecrease ? -_percentageValue : _percentageValue;

  int get _matchedCount => widget.products.length;

  Product? get _previewProduct =>
      widget.products.isEmpty ? null : widget.products.first;

  String _formatPrice(double value, String currencyCode) {
    final product = _previewProduct;
    if (product == null) return value.toStringAsFixed(2);
    return product
        .copyWith(salePrice: value, currencyCode: currencyCode)
        .formattedSalePrice;
  }

  double _previewNewPrice(Product product) {
    final multiplier = 1 + (_signedPercentage / 100);
    final adjusted = product.salePrice * multiplier;
    return double.parse(adjusted.toStringAsFixed(2));
  }

  Future<void> _submit() async {
    if (_matchedCount == 0 || _percentageValue == 0) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Toplu fiyat guncellemesini onayla'),
            content: Text(
              '$_matchedCount urunun fiyati '
              '${_signedPercentage >= 0 ? '%' : '-%'}'
              '${_percentageValue.toStringAsFixed(2)} '
              '${_isDecrease ? 'azaltilacak' : 'artirilacak'}.\n\n'
              'Aktif filtreler: ${widget.filterSummary}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Iptal'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Onayla'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    Navigator.of(context).pop(
      _BulkPriceUpdateRequest(
        brand: widget.brand,
        category: widget.category,
        query: widget.query,
        percentage: _signedPercentage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewProduct = _previewProduct;
    final previewNewPrice = previewProduct == null
        ? 0.0
        : _previewNewPrice(previewProduct);

    return AlertDialog(
      title: const Text('Toplu Fiyat Guncelle'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(value: false, label: Text('Yuzde artir')),
                  ButtonSegment<bool>(value: true, label: Text('Yuzde azalt')),
                ],
                selected: {_isDecrease},
                onSelectionChanged: (selection) {
                  setState(() => _isDecrease = selection.first);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _percentageController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Oran (%)',
                  hintText: 'Orn. 10',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Text(
                'Eslesen urun sayisi: $_matchedCount',
                style: const TextStyle(
                  color: Color(0xFF17304C),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Aktif filtreler: ${widget.filterSummary}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF5B6F7F),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: const Color(0xFFD8E0E8)),
                ),
                child: previewProduct == null
                    ? const Text('Onizleme icin urun bulunamadi.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            previewProduct.code,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF17304C),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            previewProduct.name,
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Eski fiyat: ${_formatPrice(previewProduct.salePrice, previewProduct.currencyCode)}',
                          ),
                          Text(
                            'Degisim: ${_signedPercentage >= 0 ? '+' : '-'}%${_percentageValue.toStringAsFixed(2)}',
                          ),
                          Text(
                            'Yeni fiyat: ${_formatPrice(previewNewPrice, previewProduct.currencyCode)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgec'),
        ),
        FilledButton(
          onPressed: _matchedCount == 0 || _percentageValue == 0
              ? null
              : _submit,
          child: const Text('Devam Et'),
        ),
      ],
    );
  }
}

class _AdvancedSearchPanel extends StatelessWidget {
  const _AdvancedSearchPanel({
    required this.codeFilter,
    required this.nameFilter,
    required this.brandModelFilter,
    required this.currencyFilter,
    required this.lowStockFilter,
    required this.minTlFilter,
    required this.maxTlFilter,
    required this.onCodeChanged,
    required this.onNameChanged,
    required this.onBrandModelChanged,
    required this.onCurrencyChanged,
    required this.onStockChanged,
    required this.onMinTlChanged,
    required this.onMaxTlChanged,
    required this.onReset,
  });

  final String codeFilter;
  final String nameFilter;
  final String brandModelFilter;
  final String currencyFilter;
  final bool? lowStockFilter;
  final double? minTlFilter;
  final double? maxTlFilter;
  final ValueChanged<String> onCodeChanged;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onBrandModelChanged;
  final ValueChanged<String> onCurrencyChanged;
  final ValueChanged<bool?> onStockChanged;
  final ValueChanged<String> onMinTlChanged;
  final ValueChanged<String> onMaxTlChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF7FAFD),
        border: Border.all(color: const Color(0xFFD8E0E8)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              onChanged: onCodeChanged,
              decoration: const InputDecoration(
                labelText: 'Urun kodu',
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              onChanged: onNameChanged,
              decoration: const InputDecoration(
                labelText: 'Urun adi',
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              onChanged: onBrandModelChanged,
              decoration: const InputDecoration(
                labelText: 'Marka / model',
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              initialValue: currencyFilter,
              isDense: true,
              decoration: const InputDecoration(labelText: 'Doviz'),
              items: const [
                DropdownMenuItem(
                  value: 'Tum Dovizler',
                  child: Text('Tum Dovizler'),
                ),
                DropdownMenuItem(value: 'TL', child: Text('TL')),
                DropdownMenuItem(value: 'USD', child: Text('USD')),
                DropdownMenuItem(value: 'EUR', child: Text('EUR')),
              ],
              onChanged: (value) {
                if (value != null) {
                  onCurrencyChanged(value);
                }
              },
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<bool?>(
              initialValue: lowStockFilter,
              isDense: true,
              decoration: const InputDecoration(labelText: 'Stok durumu'),
              items: const [
                DropdownMenuItem<bool?>(
                  value: null,
                  child: Text('Tum stoklar'),
                ),
                DropdownMenuItem<bool?>(
                  value: true,
                  child: Text('Sadece kritik'),
                ),
                DropdownMenuItem<bool?>(
                  value: false,
                  child: Text('Sadece normal'),
                ),
              ],
              onChanged: onStockChanged,
            ),
          ),
          SizedBox(
            width: 160,
            child: TextField(
              onChanged: onMinTlChanged,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Min TL',
                isDense: true,
                hintText: minTlFilter?.toStringAsFixed(0),
              ),
            ),
          ),
          SizedBox(
            width: 160,
            child: TextField(
              onChanged: onMaxTlChanged,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Max TL',
                isDense: true,
                hintText: maxTlFilter?.toStringAsFixed(0),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Filtreleri sifirla'),
          ),
        ],
      ),
    );
  }
}

class _ProductTable extends StatefulWidget {
  const _ProductTable({required this.products, required this.onTap});

  final List<Product> products;
  final ValueChanged<Product> onTap;

  static const _tableWidth = 1390.0;

  @override
  State<_ProductTable> createState() => _ProductTableState();
}

class _ProductTableState extends State<_ProductTable> {
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  List<_ProductTableEntry> _buildEntries() {
    final entries = <_ProductTableEntry>[];
    var rowNumber = 0;
    final grouped = <String, List<Product>>{};
    for (final product in widget.products) {
      grouped
          .putIfAbsent(productMainCategoryTurkishLabel(product), () => [])
          .add(product);
    }
    final standardOrder = ProductMainCategory.values
        .map((category) => category.label)
        .toList(growable: false);
    final mainCategoryNames = grouped.keys.toList()
      ..sort((left, right) {
        final leftIndex = standardOrder.indexOf(left);
        final rightIndex = standardOrder.indexOf(right);
        if (leftIndex != -1 || rightIndex != -1) {
          if (leftIndex == -1) return 1;
          if (rightIndex == -1) return -1;
          return leftIndex.compareTo(rightIndex);
        }
        return left.toLowerCase().compareTo(right.toLowerCase());
      });
    for (final mainCategory in mainCategoryNames) {
      final mainProducts = grouped[mainCategory]!;
      if (mainProducts.isEmpty) continue;

      entries.add(
        _ProductTableEntry.mainCategory(mainCategory, mainProducts.length),
      );
      final subcategories = <String, List<Product>>{};
      for (final product in mainProducts) {
        final subcategory = productSubcategoryTurkishLabel(product);
        subcategories.putIfAbsent(subcategory, () => []).add(product);
      }
      final sortedSubcategoryNames = subcategories.keys.toList()..sort();
      for (final subcategory in sortedSubcategoryNames) {
        final products = subcategories[subcategory]!
          ..sort((left, right) {
            final byName = left.name.toLowerCase().compareTo(
              right.name.toLowerCase(),
            );
            return byName != 0 ? byName : left.code.compareTo(right.code);
          });
        entries.add(
          _ProductTableEntry.subcategory(subcategory, products.length),
        );
        for (final product in products) {
          rowNumber += 1;
          entries.add(_ProductTableEntry.product(product, rowNumber));
        }
      }
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > _ProductTable._tableWidth
            ? constraints.maxWidth
            : _ProductTable._tableWidth;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFCCD6E0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 8,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  height: constraints.maxHeight,
                  child: Column(
                    children: [
                      const _ProductTableHeader(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: entries.length,
                          padding: const EdgeInsets.only(bottom: 10),
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            return switch (entry.type) {
                              _ProductTableEntryType.mainCategory =>
                                _ProductCategoryBand(
                                  label: entry.label,
                                  count: entry.count,
                                  main: true,
                                ),
                              _ProductTableEntryType.subcategory =>
                                _ProductCategoryBand(
                                  label: entry.label,
                                  count: entry.count,
                                  main: false,
                                ),
                              _ProductTableEntryType.product =>
                                _ProductTableRow(
                                  index: entry.rowNumber - 1,
                                  product: entry.product!,
                                  onTap: () => widget.onTap(entry.product!),
                                ),
                            };
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _ProductTableEntryType { mainCategory, subcategory, product }

class _ProductTableEntry {
  const _ProductTableEntry._({
    required this.type,
    this.label = '',
    this.count = 0,
    this.product,
    this.rowNumber = 0,
  });

  factory _ProductTableEntry.mainCategory(String label, int count) =>
      _ProductTableEntry._(
        type: _ProductTableEntryType.mainCategory,
        label: label,
        count: count,
      );

  factory _ProductTableEntry.subcategory(String label, int count) =>
      _ProductTableEntry._(
        type: _ProductTableEntryType.subcategory,
        label: label,
        count: count,
      );

  factory _ProductTableEntry.product(Product product, int rowNumber) =>
      _ProductTableEntry._(
        type: _ProductTableEntryType.product,
        product: product,
        rowNumber: rowNumber,
      );

  final _ProductTableEntryType type;
  final String label;
  final int count;
  final Product? product;
  final int rowNumber;
}

class _ProductCategoryBand extends StatelessWidget {
  const _ProductCategoryBand({
    required this.label,
    required this.count,
    required this.main,
  });

  final String label;
  final int count;
  final bool main;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: main ? 44 : 36,
      padding: EdgeInsets.symmetric(horizontal: main ? 16 : 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: main
              ? [const Color(0xFF1E3E62), const Color(0xFF17304C)]
              : [const Color(0xFF475569), const Color(0xFF334155)],
        ),
      ),
      child: Row(
        children: [
          Icon(
            main
                ? Icons.folder_special_rounded
                : Icons.subdirectory_arrow_right_rounded,
            size: main ? 19 : 17,
            color: main ? const Color(0xFF60A5FA) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: main ? 13.5 : 12.5,
              fontWeight: main ? FontWeight.w900 : FontWeight.w800,
              letterSpacing: main ? 0.4 : 0.1,
            ),
          ),
          const SizedBox(width: 9),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Text(
              '$count ürün',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTableHeader extends StatelessWidget {
  const _ProductTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
      ),
      child: const Row(
        children: [
          _ProductTableCell(text: '#', width: 50, header: true),
          _ProductTableCell(text: 'ÜRÜN KODU', width: 155, header: true),
          _ProductTableCell(text: 'ÜRÜN ADI', width: 310, header: true),
          _ProductTableCell(text: 'KATEGORİ', width: 180, header: true),
          _ProductTableCell(text: 'MARKA', width: 135, header: true),
          _ProductTableCell(text: 'MODEL', width: 165, header: true),
          _ProductTableCell(text: 'DÖVİZ', width: 75, header: true),
          _ProductTableCell(text: 'BİRİM FİYAT', width: 130, header: true),
          _ProductTableCell(text: 'STOK', width: 105, header: true),
          _ProductTableCell(text: 'DURUM', width: 85, header: true),
        ],
      ),
    );
  }
}

class _ProductTableRow extends StatelessWidget {
  const _ProductTableRow({
    required this.index,
    required this.product,
    required this.onTap,
  });

  final int index;
  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = product.isActive ? 'Aktif' : 'Pasif';
    final statusColor = !product.isActive
        ? const Color(0xFFDC2626)
        : const Color(0xFF16A34A);

    return SizedBox(
      height: 48,
      child: Material(
        color: index.isEven ? Colors.white : const Color(0xFFF8FAFC),
        child: InkWell(
          onTap: onTap,
          hoverColor: const Color(0xFFE2E8F0),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
              ),
            ),
            child: Row(
              children: [
                _ProductTableCell(text: '${index + 1}', width: 50),
                _ProductTableCell(
                  text: product.code,
                  width: 155,
                  strong: true,
                  color: const Color(0xFF0F172A),
                ),
                _ProductTableCell(text: product.name, width: 310),
                _ProductTableCell(
                  text: productSubcategoryTurkishLabel(product),
                  width: 180,
                ),
                _ProductTableCell(text: product.brand, width: 135),
                _ProductTableCell(text: product.model, width: 165),
                _ProductTableCell(
                  text: product.currencyLabel,
                  width: 75,
                  strong: true,
                  color: const Color(0xFF2563EB),
                ),
                _ProductTableCell(
                  text: product.formattedSalePrice,
                  width: 130,
                  strong: true,
                  color: const Color(0xFF059669),
                ),
                _ProductTableCell(
                  text: product.formattedStock,
                  width: 105,
                  strong: product.isLowStock,
                  color: product.isLowStock ? const Color(0xFFD97706) : null,
                ),
                _ProductTableCell(
                  text: status,
                  width: 85,
                  strong: true,
                  color: statusColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductTableCell extends StatelessWidget {
  const _ProductTableCell({
    required this.text,
    required this.width,
    this.header = false,
    this.strong = false,
    this.color,
  });

  final String text;
  final double width;
  final bool header;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: header
                ? Colors.white.withValues(alpha: 0.18)
                : const Color(0xFFDCE3EA),
            width: 0.8,
          ),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color ?? (header ? Colors.white : const Color(0xFF17304C)),
          fontSize: header ? 11.5 : 12,
          fontWeight: header || strong ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({required this.rate});

  final MarketRate rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.82),
        border: Border.all(color: const Color(0xFFDCE3EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFF1E4D2),
            ),
            child: Icon(
              switch (rate.code) {
                'USDTRY' => Icons.attach_money_rounded,
                'EURTRY' => Icons.euro_rounded,
                _ => Icons.currency_exchange_rounded,
              },
              color: const Color(0xFF17304C),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rate.label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  rate.unitLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF667887),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (rate.isFallback)
                  Text(
                    'Yedek veri',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFB45309),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            rate.formattedValue,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
