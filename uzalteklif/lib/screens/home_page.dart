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
import '../widgets/product_preview_image.dart';
import '../widgets/workspace_background.dart';
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
  bool _isLoading = true;
  bool _isImportingCsv = false;
  bool _isRefreshingRates = false;
  bool _isApplyingPriceRule = false;
  String _searchQuery = '';
  String _codeFilter = '';
  String _nameFilter = '';
  String _brandModelFilter = '';
  String _currencyFilter = 'Tum Dovizler';
  bool? _lowStockFilter;
  double? _minTlFilter;
  double? _maxTlFilter;
  bool _showAdvancedSearch = false;
  String _selectedCategory = 'Tum Urunler';
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
    super.dispose();
  }

  List<String> get _categories {
    final categories =
        _products.map((product) => product.category).toSet().toList()..sort();
    return ['Tum Urunler', ...categories];
  }

  Map<String, double> get _rateLookup {
    return {'TL': 1, for (final rate in _rates) rate.code: rate.value};
  }

  List<Product> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    final codeQuery = _codeFilter.trim().toLowerCase();
    final nameQuery = _nameFilter.trim().toLowerCase();
    final brandModelQuery = _brandModelFilter.trim().toLowerCase();
    final rates = _rateLookup;

    return _products
        .where((product) {
          final matchesCategory =
              _selectedCategory == 'Tum Urunler' ||
              product.category == _selectedCategory;
          final haystack = [
            product.code,
            product.name,
            product.category,
            product.brand,
            product.model,
            product.description,
            product.technicalSummary,
          ].join(' ').toLowerCase();
          final matchesQuery = query.isEmpty || haystack.contains(query);
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

          return matchesCategory &&
              matchesQuery &&
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
    final isDesktopWide = MediaQuery.of(context).size.width >= 1180;

    return Scaffold(
      body: WorkspaceBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : isDesktopWide
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
        : GridView.builder(
            shrinkWrap: !expandList,
            physics: expandList
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 240,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              return _ProductCard(
                product: product,
                rateLookup: _rateLookup,
                onTap: () => _openProductDetail(product),
              );
            },
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 98,
                  height: 98,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withValues(alpha: 0.88),
                    border: Border.all(color: const Color(0xFFD8E0E8)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'lib/assest/logo/uzal.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'UZAL TEKNIK',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                      color: const Color(0xFF17304C),
                      fontSize:
                          (Theme.of(
                                context,
                              ).textTheme.headlineSmall?.fontSize ??
                              24) *
                          1.75,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _saveCsvTemplate,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('CSV Sablon'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _isImportingCsv ? null : _importProductsFromCsv,
                  icon: _isImportingCsv
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_rounded),
                  label: const Text('CSV Yukle'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _openNewProduct,
                  icon: const Icon(Icons.add_box_rounded),
                  label: const Text('Yeni Urun'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                labelText: 'Kod, urun adi, marka veya model ile ara',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: _showAdvancedSearch
                      ? 'Detayli aramayi gizle'
                      : 'Detayli aramayi ac',
                  onPressed: () {
                    setState(() => _showAdvancedSearch = !_showAdvancedSearch);
                  },
                  icon: Icon(
                    _showAdvancedSearch
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                ),
                isDense: true,
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories
                  .map(
                    (category) => ChoiceChip(
                      label: Text(category),
                      selected: category == _selectedCategory,
                      onSelected: (_) {
                        setState(() => _selectedCategory = category);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            if (expandList) Expanded(child: listContent) else listContent,
          ],
        ),
      ),
    );
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
      PriceAdjustmentScope.category => rule.category,
      PriceAdjustmentScope.brandAndCategory =>
        '${rule.brand} / ${rule.category}',
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
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
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

/// Stok sayfasindaki urun kartlari. Tiklandiginda [ProductDetailPage] acilir.
/// Eski list-row `_ProductTile`'dan farkli olarak kompakt grid icin dikey
/// yerlesim kullanir ve onTap destekler.
class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.rateLookup,
    required this.onTap,
  });

  final Product product;
  final Map<String, double> rateLookup;
  final VoidCallback onTap;

  Widget _buildThumbnail(Product product) {
    const ink = Color(0xFF17304C);
    final hasImage = product.imagePath.isNotEmpty;
    return Container(
      width: 62,
      height: 62,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: hasImage
          ? ProductPreviewImage(
              imagePath: product.imagePath,
              fit: BoxFit.cover,
              width: 62,
              height: 62,
              cacheSize: 200,
              errorIconSize: 24,
            )
          : const Icon(Icons.inventory_2_outlined, size: 26, color: ink),
    );
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17304C);
    const slate = Color(0xFF5B6F7F);
    final statusColor = product.isLowStock
        ? const Color(0xFF9D5C1D)
        : const Color(0xFF2C6957);
    final statusBg = product.isLowStock
        ? const Color(0xFFFFE7D1)
        : const Color(0xFFE5F1EC);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD7DEE6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildThumbnail(product),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                product.code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: ink,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.4,
                                    ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: statusBg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                product.isLowStock ? 'Kritik' : 'Normal',
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: ink,
                                height: 1.2,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${product.brand} - ${product.model}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: slate,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _CardChip(
                    icon: Icons.category_rounded,
                    label: product.category,
                  ),
                  _CardChip(
                    icon: Icons.inventory_2_outlined,
                    label: 'Stok ${product.formattedStock}',
                    warning: product.isLowStock,
                  ),
                  _CardChip(
                    icon: Icons.schedule_rounded,
                    label: product.leadTime.isEmpty ? '-' : product.leadTime,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.formattedSalePrice,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: ink,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        Text(
                          'TL ${product.formattedTlEquivalent(rateLookup)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: slate,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, size: 18, color: ink),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardChip extends StatelessWidget {
  const _CardChip({
    required this.icon,
    required this.label,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final bg = warning ? const Color(0xFFFFF4E0) : const Color(0xFFF1F4F8);
    final fg = warning ? const Color(0xFF9D5C1D) : const Color(0xFF17304C);
    final borderColor = warning
        ? const Color(0xFFE3B86C)
        : const Color(0xFFD7DEE6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
