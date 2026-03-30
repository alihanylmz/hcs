import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/user_profile.dart';
import '../services/pdf_export_service.dart';
import '../services/permission_service.dart';
import '../services/stock_service.dart';
import '../services/user_service.dart';
import '../widgets/app_drawer.dart';
import 'brand_models_settings_page.dart';
import 'pdf_viewer_page.dart';
import 'ticket_detail_page.dart';

class StockOverviewPage extends StatefulWidget {
  const StockOverviewPage({super.key});

  @override
  State<StockOverviewPage> createState() => _StockOverviewPageState();
}

class _StockOverviewPageState extends State<StockOverviewPage> {
  final StockService _stockService = StockService();
  final UserService _userService = UserService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> _allStocks = [];
  List<Map<String, dynamic>> _missingTickets = [];

  bool _isLoading = true;
  bool _missingLoading = true;
  String? _missingError;
  String _searchQuery = '';
  bool _isSelectionMode = false;
  Set<int> _selectedItems = {};
  Map<int, int> _orderQuantities = {};
  int _selectedCategoryIndex = 0;
  int _stockSectionIndex = 0;
  UserProfile? _userProfile;

  bool get _canViewStock =>
      PermissionService.hasPermission(_userProfile, AppPermission.viewStock);

  bool get _canManageStock =>
      PermissionService.hasPermission(_userProfile, AppPermission.manageStock);

  bool get _canDeleteStock =>
      PermissionService.hasPermission(_userProfile, AppPermission.deleteStock);

  bool get _canConfigureStockCatalog => PermissionService.hasPermission(
    _userProfile,
    AppPermission.configureStockCatalog,
  );

  final List<String> _uiCategories = [
    'Tümü',
    'Sürücü',
    'PLC',
    'HMI',
    'Şalt',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadStocks();
    _loadMissingTickets();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userService.getCurrentUserProfile();
    if (!mounted) return;
    setState(() => _userProfile = profile);
  }

  Future<void> _loadStocks() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final data = await _stockService.getStocks();
      if (!mounted) return;
      setState(() {
        _allStocks = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMissingTickets() async {
    if (mounted) {
      setState(() {
        _missingLoading = true;
        _missingError = null;
      });
    }

    try {
      final data = await _stockService.getTicketsWithMissingParts();
      if (!mounted) return;
      setState(() {
        _missingTickets = data;
        _missingLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _missingError = error.toString();
        _missingLoading = false;
      });
    }
  }

  String _normalizeTurkish(String text) {
    return text
        .replaceAll('I', 'ı')
        .replaceAll('İ', 'i')
        .replaceAll('Ş', 'ş')
        .replaceAll('Ğ', 'ğ')
        .replaceAll('Ü', 'ü')
        .replaceAll('Ö', 'ö')
        .replaceAll('Ç', 'ç')
        .toLowerCase()
        .trim();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _safeText(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _formatShortDate(dynamic value) {
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day.$month.${parsed.year} $hour:$minute';
  }

  int _resolvedCriticalLevel(Map<String, dynamic> item) {
    final critical = _asInt(item['critical_level']);
    return critical <= 0 ? 5 : critical;
  }

  bool _isLowStock(Map<String, dynamic> item) {
    final quantity = _asInt(item['quantity']);
    return quantity <= _resolvedCriticalLevel(item);
  }

  bool _needsReorder(Map<String, dynamic> item) {
    final quantity = _asInt(item['quantity']);
    return quantity < _resolvedCriticalLevel(item);
  }

  int _suggestedOrderQuantity(Map<String, dynamic> item) {
    final quantity = _asInt(item['quantity']);
    final critical = _resolvedCriticalLevel(item);
    return quantity >= critical ? 1 : critical - quantity;
  }

  List<Map<String, dynamic>> _getFilteredStocks() {
    final currentTab = _uiCategories[_selectedCategoryIndex];
    var list = List<Map<String, dynamic>>.from(_allStocks);

    if (currentTab != 'Tümü') {
      list =
          list.where((stock) {
            final category = (stock['category'] ?? 'Diğer').toString();
            if (currentTab == 'Diğer') {
              return !['Sürücü', 'PLC', 'HMI', 'Şalt'].contains(category);
            }
            return category == currentTab;
          }).toList();
    }

    final query = _normalizeTurkish(_searchQuery);
    if (query.isEmpty) return list;

    return list.where((stock) {
      final name = _normalizeTurkish(stock['name'] ?? '');
      final shelf = _normalizeTurkish(stock['shelf_location'] ?? '');
      final category = _normalizeTurkish(stock['category'] ?? '');
      return name.contains(query) ||
          shelf.contains(query) ||
          category.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _getCriticalStocks() {
    final items = _getFilteredStocks().where(_isLowStock).toList();
    items.sort((a, b) {
      final deficitA = _asInt(a['quantity']) - _resolvedCriticalLevel(a);
      final deficitB = _asInt(b['quantity']) - _resolvedCriticalLevel(b);
      return deficitA.compareTo(deficitB);
    });
    return items;
  }

  List<Map<String, dynamic>> _getFilteredMissingTickets() {
    final query = _normalizeTurkish(_searchQuery);
    if (query.isEmpty) return List<Map<String, dynamic>>.from(_missingTickets);

    return _missingTickets.where((ticket) {
      final customer = ticket['customers'] as Map<String, dynamic>? ?? {};
      final title = _normalizeTurkish(ticket['title'] ?? '');
      final jobCode = _normalizeTurkish(ticket['job_code'] ?? '');
      final missing = _normalizeTurkish(ticket['missing_parts'] ?? '');
      final customerName = _normalizeTurkish(customer['name'] ?? '');
      return title.contains(query) ||
          jobCode.contains(query) ||
          missing.contains(query) ||
          customerName.contains(query);
    }).toList();
  }

  Future<void> _showAddSelectionDialog() async {
    if (!_canManageStock) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hangi stok tipini eklemek istiyorsunuz?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTypeOption(
                  context,
                  icon: Icons.speed_rounded,
                  color: Colors.blue,
                  label: 'Sürücü',
                ),
                _buildTypeOption(
                  context,
                  icon: Icons.memory_rounded,
                  color: Colors.orange,
                  label: 'PLC',
                ),
                _buildTypeOption(
                  context,
                  icon: Icons.desktop_windows_rounded,
                  color: Colors.teal,
                  label: 'HMI',
                ),
                _buildTypeOption(
                  context,
                  icon: Icons.electric_bolt_rounded,
                  color: Colors.redAccent,
                  label: 'Şalt',
                ),
                _buildTypeOption(
                  context,
                  icon: Icons.category_rounded,
                  color: Colors.grey,
                  label: 'Diğer',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeOption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        foregroundColor: color,
        child: Icon(icon),
      ),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        Navigator.pop(context);
        _showSmartAddDialog(label);
      },
    );
  }

  Future<void> _showSmartAddDialog(
    String type, {
    Map<String, dynamic>? editItem,
  }) async {
    if (!_canManageStock) return;

    await showDialog<void>(
      context: context,
      builder: (_) {
        return StockFormDialog(
          type: type,
          editItem: editItem,
          onSave: (data, isEdit) async {
            try {
              if (isEdit) {
                await _stockService.updateStock(editItem!['id'] as int, data);
              } else {
                await _stockService.addStock(data);
              }

              if (!mounted) return;
              await _loadStocks();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Stok kaydi kaydedildi.'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (error) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Kayit hatasi: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        );
      },
    );
  }

  Future<void> _deleteStock(int id) async {
    if (!_canDeleteStock) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu islem icin yetkiniz yok.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Stok sil'),
          content: const Text(
            'Bu stok kaydini silmek istediginize emin misiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Iptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _stockService.deleteStock(id);
      if (!mounted) return;
      await _loadStocks();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stok kaydi silindi.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Silme hatasi: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handlePdfExport({
    required Future<Uint8List> Function() generator,
    required String baseName,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PdfViewerPage(
              title: baseName,
              pdfFileName: '$baseName.pdf',
              pdfGenerator: generator,
            ),
      ),
    );
  }

  Future<void> _handleItemSelection(Map<String, dynamic> item) async {
    final itemId = item['id'] as int;

    if (_selectedItems.contains(itemId)) {
      if (!mounted) return;
      setState(() {
        _selectedItems.remove(itemId);
        _orderQuantities.remove(itemId);
      });
      return;
    }

    final quantity = await _showQuantityDialog(item);
    if (!mounted || quantity == null || quantity <= 0) return;

    setState(() {
      _selectedItems.add(itemId);
      _orderQuantities[itemId] = quantity;
    });
  }

  Future<int?> _showQuantityDialog(Map<String, dynamic> item) async {
    return showDialog<int>(
      context: context,
      builder: (_) => StockOrderDialog(item: item),
    );
  }

  Future<void> _generateOrderListFromSelected() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lutfen en az bir urun secin.')),
      );
      return;
    }

    final selectedStocks =
        _allStocks.where((stock) => _selectedItems.contains(stock['id'])).map((
          stock,
        ) {
          final enriched = Map<String, dynamic>.from(stock);
          enriched['order_quantity'] = _orderQuantities[stock['id']] ?? 1;
          return enriched;
        }).toList();

    await _handlePdfExport(
      generator:
          () => PdfExportService.generateOrderListPdfBytesFromList(
            selectedStocks,
          ),
      baseName:
          'Siparis_Listesi_${DateTime.now().toIso8601String().substring(0, 10)}',
    );

    if (!mounted) return;
    setState(() {
      _isSelectionMode = false;
      _selectedItems.clear();
      _orderQuantities.clear();
    });
  }

  Future<void> _toggleSelectionMode() async {
    if (!mounted) return;
    setState(() {
      if (_isSelectionMode) {
        _isSelectionMode = false;
        _selectedItems.clear();
        _orderQuantities.clear();
      } else {
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _addItemToOrderList(Map<String, dynamic> item) async {
    if (!_isSelectionMode && mounted) {
      setState(() => _isSelectionMode = true);
    }
    await _handleItemSelection(item);
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadStocks(), _loadMissingTickets()]);
  }

  @override
  Widget build(BuildContext context) {
    if (_userProfile != null && !_canViewStock) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stok Durumu')),
        body: const Center(
          child: Text(
            'Bu sayfaya erisim yetkiniz yok.',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final filteredStocks = _getFilteredStocks();
    final criticalStocks = _getCriticalStocks();
    final filteredMissingTickets = _getFilteredMissingTickets();
    final totalItems = _allStocks.length;
    final totalUnits = _allStocks.fold<int>(
      0,
      (sum, item) => sum + _asInt(item['quantity']),
    );
    final criticalCount = _allStocks.where(_isLowStock).length;
    final reorderCount = _allStocks.where(_needsReorder).length;
    final missingCount = _missingTickets.length;
    final isCompact = MediaQuery.sizeOf(context).width < 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: AppDrawer(
        currentPage: AppDrawerPage.stock,
        userName: _userProfile?.displayName,
        userRole: _userProfile?.role,
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leadingWidth: 100,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            SvgPicture.asset('assets/images/log.svg', width: 32, height: 32),
          ],
        ),
        title: Text(
          'Stok Durumu',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
              tooltip: 'Siparis PDF olustur',
              onPressed:
                  _selectedItems.isEmpty
                      ? null
                      : _generateOrderListFromSelected,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _refreshAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryGrid(
                      theme: theme,
                      totalItems: totalItems,
                      totalUnits: totalUnits,
                      criticalCount: criticalCount,
                      reorderCount: reorderCount,
                      missingCount: missingCount,
                    ),
                    const SizedBox(height: 16),
                    _buildControlPanel(theme),
                    const SizedBox(height: 16),
                    _buildViewInfoBar(
                      theme: theme,
                      visibleCount:
                          _stockSectionIndex == 0
                              ? criticalStocks.length
                              : _stockSectionIndex == 1
                              ? filteredStocks.length
                              : filteredMissingTickets.length,
                    ),
                  ],
                ),
              ),
            ),
            ..._buildContentSlivers(
              theme: theme,
              criticalStocks: criticalStocks,
              filteredStocks: filteredStocks,
              filteredMissingTickets: filteredMissingTickets,
            ),
          ],
        ),
      ),
      floatingActionButton:
          isCompact && _canManageStock
              ? FloatingActionButton.extended(
                onPressed: _showAddSelectionDialog,
                backgroundColor: theme.colorScheme.primary,
                icon: Icon(
                  Icons.add_rounded,
                  color: theme.colorScheme.onPrimary,
                ),
                label: Text(
                  'Yeni Stok',
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                ),
              )
              : null,
    );
  }

  Widget _buildSummaryGrid({
    required ThemeData theme,
    required int totalItems,
    required int totalUnits,
    required int criticalCount,
    required int reorderCount,
    required int missingCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final cardWidth =
            maxWidth >= 1100
                ? (maxWidth - 36) / 4
                : maxWidth >= 700
                ? (maxWidth - 12) / 2
                : maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                theme,
                title: 'Toplam Kalem',
                value: '$totalItems',
                subtitle: '$totalUnits adet stokta',
                icon: Icons.inventory_2_outlined,
                accentColor: theme.colorScheme.primary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                theme,
                title: 'Kritik Urun',
                value: '$criticalCount',
                subtitle: 'Kritik seviyede veya altinda',
                icon: Icons.warning_amber_rounded,
                accentColor: theme.colorScheme.error,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                theme,
                title: 'Siparis Gereken',
                value: '$reorderCount',
                subtitle: 'Takviye oneriliyor',
                icon: Icons.shopping_cart_checkout_rounded,
                accentColor: theme.colorScheme.secondary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildSummaryCard(
                theme,
                title: 'Ise Bagli Eksik',
                value: '$missingCount',
                subtitle: 'Eksik malzeme bekleyen is',
                icon: Icons.build_circle_outlined,
                accentColor: theme.colorScheme.tertiary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlPanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stok merkezi',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kritik urunleri, tum stogu ve ise bagli eksikleri tek ekrandan yonetin.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedItems.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_selectedItems.length} urun secildi',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (_canManageStock)
                FilledButton.icon(
                  onPressed: _showAddSelectionDialog,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Yeni stok'),
                ),
              OutlinedButton.icon(
                onPressed: _toggleSelectionMode,
                icon: Icon(
                  _isSelectionMode
                      ? Icons.close_rounded
                      : Icons.playlist_add_check_rounded,
                ),
                label: Text(_isSelectionMode ? 'Secimi kapat' : 'Siparis modu'),
              ),
              FilledButton.tonalIcon(
                onPressed:
                    _selectedItems.isEmpty
                        ? null
                        : _generateOrderListFromSelected,
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Siparis PDF'),
              ),
              OutlinedButton.icon(
                onPressed:
                    () => _handlePdfExport(
                      generator: PdfExportService.generateStockReportPdfBytes,
                      baseName:
                          'Stok_Raporu_${DateTime.now().toIso8601String().substring(0, 10)}',
                    ),
                icon: const Icon(Icons.inventory_outlined),
                label: const Text('Stok raporu'),
              ),
              OutlinedButton.icon(
                onPressed:
                    () => _handlePdfExport(
                      generator:
                          PdfExportService.generateAnnualUsageReportPdfBytes,
                      baseName: 'Yillik_Kullanim_Raporu',
                    ),
                icon: const Icon(Icons.trending_up_rounded),
                label: const Text('Yillik kullanim'),
              ),
              if (_canConfigureStockCatalog)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BrandModelsSettingsPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings_applications_rounded),
                  label: const Text('Marka modelleri'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText:
                  _stockSectionIndex == 2
                      ? 'Is, musteri veya eksik parca ara...'
                      : 'Urun, kategori veya raf ara...',
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 18),
          _buildSectionSelector(theme),
          if (_stockSectionIndex != 2) ...[
            const SizedBox(height: 14),
            _buildCategorySelector(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildViewInfoBar({
    required ThemeData theme,
    required int visibleCount,
  }) {
    final sectionLabel =
        _stockSectionIndex == 0
            ? 'kritik urun'
            : _stockSectionIndex == 1
            ? 'stok kalemi'
            : 'eksik parca bagli is';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 8,
        children: [
          Text(
            '$visibleCount $sectionLabel goruntuleniyor',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            _stockSectionIndex == 2
                ? 'Is etkisini once gorebilirsiniz.'
                : 'Satirdan duzenle, siparise ekle veya sil.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContentSlivers({
    required ThemeData theme,
    required List<Map<String, dynamic>> criticalStocks,
    required List<Map<String, dynamic>> filteredStocks,
    required List<Map<String, dynamic>> filteredMissingTickets,
  }) {
    if (_stockSectionIndex == 2) {
      if (_missingLoading) {
        return const [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      }

      if (_missingError != null) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(
              theme,
              icon: Icons.error_outline_rounded,
              title: 'Eksik parca listesi yuklenemedi',
              subtitle: _missingError!,
            ),
          ),
        ];
      }

      if (filteredMissingTickets.isEmpty) {
        return [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(
              theme,
              icon: Icons.rule_folder_outlined,
              title: 'Eksik parca bagli is bulunamadi',
              subtitle:
                  _searchQuery.trim().isEmpty
                      ? 'Su anda eksik malzeme nedeniyle bekleyen is gorunmuyor.'
                      : 'Arama sonucuna uygun eksik malzemeli is bulunamadi.',
            ),
          ),
        ];
      }

      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _buildMissingTicketCard(filteredMissingTickets[index], theme),
              childCount: filteredMissingTickets.length,
            ),
          ),
        ),
      ];
    }

    if (_isLoading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    final visibleStocks =
        _stockSectionIndex == 0 ? criticalStocks : filteredStocks;

    if (visibleStocks.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(
            theme,
            icon: Icons.inventory_2_outlined,
            title:
                _stockSectionIndex == 0
                    ? 'Kritik stok bulunmuyor'
                    : 'Urun bulunamadi',
            subtitle:
                _stockSectionIndex == 0
                    ? 'Bu filtrede kritik seviyede urun yok.'
                    : 'Arama veya kategori filtresini degistirerek tekrar deneyin.',
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildStockCard(visibleStocks[index], theme),
            childCount: visibleStocks.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildSummaryCard(
    ThemeData theme, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withOpacity(0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSelector(ThemeData theme) {
    const labels = ['Kritik', 'Tum Stok', 'Ise Bagli Eksikler'];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children:
            labels.asMap().entries.map((entry) {
              final index = entry.key;
              final label = entry.value;
              final isSelected = _stockSectionIndex == index;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow:
                          isSelected
                              ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.18,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ]
                              : null,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => setState(() => _stockSectionIndex = index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color:
                                isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildCategorySelector(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          _uiCategories.asMap().entries.map((entry) {
            final index = entry.key;
            final label = entry.value;
            final isSelected = _selectedCategoryIndex == index;

            return ChoiceChip(
              selected: isSelected,
              label: Text(label),
              onSelected: (_) => setState(() => _selectedCategoryIndex = index),
              labelStyle: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color:
                    isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              selectedColor: theme.colorScheme.primary,
              backgroundColor: theme.cardColor,
              side: BorderSide(
                color:
                    isSelected
                        ? Colors.transparent
                        : theme.dividerColor.withOpacity(0.2),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            );
          }).toList(),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 56,
              color: theme.colorScheme.onSurface.withOpacity(0.35),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForCategory(String? category) {
    switch (category) {
      case 'Sürücü':
        return Icons.speed_rounded;
      case 'PLC':
        return Icons.memory_rounded;
      case 'HMI':
        return Icons.desktop_windows_rounded;
      case 'Şalt':
        return Icons.electric_bolt_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildStockCard(Map<String, dynamic> item, ThemeData theme) {
    final quantity = _asInt(item['quantity']);
    final criticalLevel = _resolvedCriticalLevel(item);
    final statusColor =
        quantity == 0
            ? theme.colorScheme.error
            : _isLowStock(item)
            ? theme.colorScheme.secondary
            : Colors.green.shade700;
    final statusLabel =
        quantity == 0
            ? 'Tukendi'
            : _isLowStock(item)
            ? 'Kritik'
            : 'Normal';
    final isSelected = _selectedItems.contains(item['id']);
    final unit = _safeText(item['unit'], fallback: 'adet');
    final category = _safeText(item['category'], fallback: 'Diger');
    final shelf = _safeText(item['shelf_location'], fallback: 'Raf yok');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              _isLowStock(item)
                  ? statusColor.withOpacity(0.28)
                  : theme.dividerColor.withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap:
            _isSelectionMode
                ? () => _handleItemSelection(item)
                : () => _showSmartAddDialog('Diğer', editItem: item),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 12, top: 8),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color:
                            isSelected
                                ? theme.colorScheme.primary
                                : theme.disabledColor,
                      ),
                    ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _getIconForCategory(item['category']?.toString()),
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _safeText(item['name']),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildMetaChip(
                              theme,
                              icon: Icons.grid_view_rounded,
                              label: category,
                            ),
                            _buildMetaChip(
                              theme,
                              icon: Icons.location_on_outlined,
                              label: shelf,
                            ),
                            _buildMetaChip(
                              theme,
                              icon: Icons.tag_rounded,
                              label: 'ID ${item['id']}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildStatusBadge(
                    theme,
                    label: statusLabel,
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildMetricTile(
                    theme,
                    label: 'Mevcut',
                    value: '$quantity $unit',
                    accentColor: statusColor,
                  ),
                  _buildMetricTile(
                    theme,
                    label: 'Kritik seviye',
                    value: '$criticalLevel $unit',
                    accentColor: theme.colorScheme.primary,
                  ),
                  _buildMetricTile(
                    theme,
                    label: 'Onerilen siparis',
                    value: '${_suggestedOrderQuantity(item)} $unit',
                    accentColor: theme.colorScheme.tertiary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_canManageStock)
                    OutlinedButton.icon(
                      onPressed:
                          () => _showSmartAddDialog('Diğer', editItem: item),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Duzenle'),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: () => _addItemToOrderList(item),
                    icon: Icon(
                      isSelected
                          ? Icons.playlist_remove_rounded
                          : Icons.playlist_add_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isSelected ? 'Siparisten cikar' : 'Siparise ekle',
                    ),
                  ),
                  if (_canDeleteStock)
                    OutlinedButton.icon(
                      onPressed: () => _deleteStock(_asInt(item['id'])),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Sil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    ThemeData theme, {
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    ThemeData theme, {
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildMissingTicketCard(Map<String, dynamic> ticket, ThemeData theme) {
    final customer = ticket['customers'] as Map<String, dynamic>? ?? {};
    final title = _safeText(ticket['title'], fallback: 'Adsiz is');
    final jobCode = _safeText(ticket['job_code'], fallback: 'Kod yok');
    final missing = _safeText(
      ticket['missing_parts'],
      fallback: 'Eksik parca bilgisi yok',
    );
    final customerName = _safeText(
      customer['name'],
      fallback: 'Musteri belirtilmemis',
    );
    final plannedDate = _formatShortDate(ticket['planned_date']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.error.withOpacity(0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          final id = ticket['id'].toString();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TicketDetailPage(ticketId: id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          customerName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(
                              0.74,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(
                    theme,
                    label: 'Malzeme eksik',
                    color: theme.colorScheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetaChip(
                    theme,
                    icon: Icons.badge_outlined,
                    label: jobCode,
                  ),
                  _buildMetaChip(
                    theme,
                    icon: Icons.schedule_outlined,
                    label: plannedDate,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Eksik parcalar',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      missing,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () {
                    final id = ticket['id'].toString();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TicketDetailPage(ticketId: id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Isi ac'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StockFormDialog extends StatefulWidget {
  final String type;
  final Map<String, dynamic>? editItem;
  final Future<void> Function(Map<String, dynamic> data, bool isEdit) onSave;

  const StockFormDialog({
    super.key,
    required this.type,
    this.editItem,
    required this.onSave,
  });

  @override
  State<StockFormDialog> createState() => _StockFormDialogState();
}

class _StockFormDialogState extends State<StockFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final StockService _stockService = StockService();

  late TextEditingController _qtyCtrl;
  late TextEditingController _shelfCtrl;
  late TextEditingController _criticalCtrl;
  late TextEditingController _manualNameCtrl;

  String? _selectedBrand;
  String? _selectedModel;
  double? _selectedHmiSize;
  double? _selectedKw;
  late String _selectedUnit;
  List<String> _availableModels = [];
  List<String> _availableBrands = [];
  bool _loadingBrands = false;

  @override
  void initState() {
    super.initState();
    final item = widget.editItem;
    _qtyCtrl = TextEditingController(
      text: item?['quantity']?.toString() ?? '0',
    );
    _shelfCtrl = TextEditingController(
      text: item?['shelf_location']?.toString() ?? '',
    );
    _criticalCtrl = TextEditingController(
      text: item?['critical_level']?.toString() ?? '5',
    );
    _manualNameCtrl = TextEditingController(
      text: item?['name']?.toString() ?? '',
    );
    _selectedUnit = item?['unit']?.toString() ?? 'adet';

    if ((widget.type == 'Sürücü' ||
            widget.type == 'PLC' ||
            widget.type == 'HMI') &&
        widget.editItem == null) {
      _loadBrands();
    }
  }

  Future<void> _loadBrands() async {
    setState(() => _loadingBrands = true);
    try {
      final brands = await _stockService.getBrandsByCategory(widget.type);
      if (!mounted) return;
      setState(() {
        _availableBrands = brands;
        _loadingBrands = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availableBrands = [];
        _loadingBrands = false;
      });
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _shelfCtrl.dispose();
    _criticalCtrl.dispose();
    _manualNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editItem != null;

    return AlertDialog(
      title: Text(isEdit ? 'Stok Duzenle' : '${widget.type} Ekle'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isEdit) ..._buildCreateFields(),
              if (isEdit)
                TextFormField(
                  controller: _manualNameCtrl,
                  decoration: const InputDecoration(labelText: 'Malzeme Adi'),
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Zorunlu'
                              : null,
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyCtrl,
                      decoration: const InputDecoration(labelText: 'Adet'),
                      keyboardType: TextInputType.number,
                      validator:
                          (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Zorunlu'
                                  : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _shelfCtrl,
                      decoration: const InputDecoration(labelText: 'Raf Yeri'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _criticalCtrl,
                decoration: const InputDecoration(labelText: 'Kritik Seviye'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Zorunlu';
                  final number = int.tryParse(value);
                  if (number == null || number < 0) {
                    return 'Gecerli bir sayi girin';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Iptal'),
        ),
        FilledButton(onPressed: _save, child: const Text('Kaydet')),
      ],
    );
  }

  List<Widget> _buildCreateFields() {
    if (widget.type == 'Sürücü') {
      return [
        if (_loadingBrands)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Marka'),
            items:
                (_availableBrands.isEmpty ? const ['Diğer'] : _availableBrands)
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
            onChanged: (value) async {
              setState(() {
                _selectedBrand = value;
                _selectedModel = null;
                _availableModels = [];
              });
              if (value != null && value != 'Diğer') {
                final models = await _stockService.getBrandModels(
                  value,
                  'Sürücü',
                );
                if (!mounted) return;
                setState(() => _availableModels = models);
              }
            },
            validator: (value) => value == null ? 'Seciniz' : null,
          ),
        if (_selectedBrand != null &&
            _selectedBrand != 'Diğer' &&
            _availableModels.isNotEmpty) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Model'),
            items:
                _availableModels
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _selectedModel = value),
            validator: (value) => value == null ? 'Seciniz' : null,
          ),
        ],
        const SizedBox(height: 10),
        DropdownButtonFormField<double>(
          decoration: const InputDecoration(labelText: 'Guc (kW)'),
          items:
              StockService.kwValues
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('${StockService.formatKw(value)} kW'),
                    ),
                  )
                  .toList(),
          onChanged: (value) => setState(() => _selectedKw = value),
          validator: (value) => value == null ? 'Seciniz' : null,
        ),
      ];
    }

    if (widget.type == 'PLC') {
      return [
        if (_loadingBrands)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Marka'),
            items:
                (_availableBrands.isEmpty
                        ? StockService.plcModels
                        : _availableBrands)
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
            onChanged: (value) async {
              setState(() {
                _selectedBrand = value;
                _selectedModel = null;
                _availableModels = [];
              });
              if (value != null && value != 'Diğer') {
                final models = await _stockService.getBrandModels(value, 'PLC');
                if (!mounted) return;
                setState(() => _availableModels = models);
              }
            },
            validator: (value) => value == null ? 'Seciniz' : null,
          ),
        if (_selectedBrand != null &&
            _selectedBrand != 'Diğer' &&
            _availableModels.isNotEmpty) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Model'),
            items:
                _availableModels
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _selectedModel = value),
            validator: (value) => value == null ? 'Seciniz' : null,
          ),
        ],
      ];
    }

    if (widget.type == 'HMI') {
      return [
        if (_loadingBrands)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Marka'),
            items:
                (_availableBrands.isEmpty
                        ? StockService.hmiBrands
                        : _availableBrands)
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
            onChanged: (value) async {
              setState(() {
                _selectedBrand = value;
                _selectedModel = null;
                _availableModels = [];
              });
              if (value != null && value != 'Diğer') {
                final models = await _stockService.getBrandModels(value, 'HMI');
                if (!mounted) return;
                setState(() => _availableModels = models);
              }
            },
            validator: (value) => value == null ? 'Seciniz' : null,
          ),
        if (_selectedBrand != null &&
            _selectedBrand != 'Diğer' &&
            _availableModels.isNotEmpty) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Model'),
            items:
                _availableModels
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _selectedModel = value),
            validator: (value) => value == null ? 'Seciniz' : null,
          ),
        ],
        const SizedBox(height: 10),
        DropdownButtonFormField<double>(
          decoration: const InputDecoration(labelText: 'Ekran Boyutu (inc)'),
          items:
              StockService.hmiSizes
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('${StockService.formatInch(value)} inc'),
                    ),
                  )
                  .toList(),
          onChanged: (value) => setState(() => _selectedHmiSize = value),
          validator: (value) => value == null ? 'Seciniz' : null,
        ),
      ];
    }

    return [
      TextFormField(
        controller: _manualNameCtrl,
        decoration: const InputDecoration(labelText: 'Malzeme Adi'),
        validator:
            (value) => value == null || value.trim().isEmpty ? 'Zorunlu' : null,
      ),
    ];
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isEdit = widget.editItem != null;
    String finalName;
    String category = widget.type;

    if (isEdit) {
      finalName = _manualNameCtrl.text.trim();
      category = widget.editItem!['category']?.toString() ?? 'Diğer';
    } else if (widget.type == 'Sürücü') {
      if (_selectedBrand == null || _selectedKw == null) {
        _showValidation('Lutfen tum alanlari doldurun.');
        return;
      }
      final kw = StockService.formatKw(_selectedKw!);
      finalName =
          _selectedModel != null && _selectedModel!.isNotEmpty
              ? '$_selectedBrand $_selectedModel $kw kW Sürücü'
              : '$_selectedBrand $kw kW Sürücü';
    } else if (widget.type == 'PLC') {
      if (_selectedBrand == null) {
        _showValidation('Lutfen marka secin.');
        return;
      }
      finalName =
          _selectedModel != null && _selectedModel!.isNotEmpty
              ? '$_selectedBrand $_selectedModel PLC'
              : '$_selectedBrand PLC';
    } else if (widget.type == 'HMI') {
      if (_selectedBrand == null || _selectedHmiSize == null) {
        _showValidation('Lutfen tum alanlari doldurun.');
        return;
      }
      final inch = StockService.formatInch(_selectedHmiSize!);
      finalName =
          _selectedModel != null && _selectedModel!.isNotEmpty
              ? '$_selectedBrand $_selectedModel $inch inç HMI'
              : '$_selectedBrand $inch inç HMI';
    } else {
      finalName = _manualNameCtrl.text.trim();
      if (finalName.isEmpty) {
        _showValidation('Malzeme adi zorunludur.');
        return;
      }
    }

    final quantity = int.tryParse(_qtyCtrl.text.trim());
    final critical = int.tryParse(_criticalCtrl.text.trim());

    if (quantity == null || quantity < 0) {
      _showValidation('Gecerli bir adet girin.');
      return;
    }

    if (critical == null || critical < 0) {
      _showValidation('Gecerli bir kritik seviye girin.');
      return;
    }

    final data = {
      'name': finalName,
      'category': category,
      'quantity': quantity,
      'unit': _selectedUnit,
      'shelf_location':
          _shelfCtrl.text.trim().isEmpty ? null : _shelfCtrl.text.trim(),
      'critical_level': critical,
    };

    await widget.onSave(data, isEdit);
    if (mounted) Navigator.pop(context);
  }

  void _showValidation(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class StockOrderDialog extends StatefulWidget {
  final Map<String, dynamic> item;

  const StockOrderDialog({super.key, required this.item});

  @override
  State<StockOrderDialog> createState() => _StockOrderDialogState();
}

class _StockOrderDialogState extends State<StockOrderDialog> {
  late TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    final currentQty = widget.item['quantity'] as int? ?? 0;
    final critical = widget.item['critical_level'] as int? ?? 5;
    final suggestedQty = critical > currentQty ? critical - currentQty : 1;
    _qtyController = TextEditingController(text: suggestedQty.toString());
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentQty = widget.item['quantity'] as int? ?? 0;
    final critical = widget.item['critical_level'] as int? ?? 5;

    return AlertDialog(
      title: const Text('Siparis Adedi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item['name']?.toString() ?? '-',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Mevcut: $currentQty ${widget.item['unit'] ?? 'adet'}'),
            Text('Kritik Seviye: $critical ${widget.item['unit'] ?? 'adet'}'),
            const SizedBox(height: 16),
            TextField(
              controller: _qtyController,
              decoration: const InputDecoration(
                labelText: 'Siparis Adedi',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Iptal'),
        ),
        FilledButton(
          onPressed: () {
            final qty = int.tryParse(_qtyController.text);
            if (qty != null && qty > 0) {
              Navigator.pop(context, qty);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gecerli bir adet girin.')),
              );
            }
          },
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}
