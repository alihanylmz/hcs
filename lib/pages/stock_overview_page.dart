import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/user_profile.dart';
import '../services/permission_service.dart';
import '../services/stock_pdf_service.dart';
import '../services/stock_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_drawer.dart';
import 'pdf_viewer_page.dart';
import 'ticket_detail_page.dart';

class StockOverviewPage extends StatefulWidget {
  const StockOverviewPage({super.key});

  @override
  State<StockOverviewPage> createState() => _StockOverviewPageState();
}

class _StockOverviewPageState extends State<StockOverviewPage>
    with SingleTickerProviderStateMixin {
  final StockService _stockService = StockService();
  final UserService _userService = UserService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> _allStocks = [];
  List<Map<String, dynamic>> _missingTickets = [];
  List<Map<String, dynamic>> _stockMovements = [];
  List<Map<String, dynamic>> _personnelLoans = [];
  List<Map<String, dynamic>> _defectiveProducts = [];
  List<Map<String, dynamic>> _activeTickets = [];

  bool _isLoading = true;
  bool _onlyTracked = true; // Varsayılan: Sadece depoda bulunan / takibi olan stoklar

  String _searchQuery = '';
  String _selectedCategory = 'Tümü';
  int _activeTab = 0; // 0: Depodaki Stoklar, 1: Kritik Stoklar, 2: Tüm Katalog, 3: Zimmetler, 4: Hareketler, 5: Eksik İşler, 6: Arızalı Ürünler

  // SAYFALAMA (PAGINATION) STATE
  int _currentPage = 0;
  int _pageSize = 50;

  bool _isSelectionMode = false;
  final Set<String> _selectedProductIds = {};

  UserProfile? _userProfile;

  bool get _canViewStock =>
      PermissionService.hasPermission(_userProfile, AppPermission.viewStock);

  bool get _canManageStock =>
      PermissionService.hasPermission(_userProfile, AppPermission.manageStock);

  bool get _canUseScanner =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await _loadUserProfile();
    await Future.wait([
      _loadStocks(),
      _loadMissingTickets(),
      _loadStockMovements(),
      _loadPersonnelLoans(),
      _loadDefectiveProducts(),
      _loadActiveTickets(),
    ]);
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userService.getCurrentUserProfile();
    if (mounted) {
      setState(() => _userProfile = profile);
    }
  }

  Future<void> _loadStocks() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final fetchOnlyTracked = _activeTab != 2 && _onlyTracked;
      final data = await _stockService.getStocks(onlyTracked: fetchOnlyTracked);
      if (mounted) {
        setState(() {
          _allStocks = data;
          _isLoading = false;
          _currentPage = 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMissingTickets() async {
    try {
      final data = await _stockService.getTicketsWithMissingParts();
      if (mounted) setState(() => _missingTickets = data);
    } catch (_) {}
  }

  Future<void> _loadStockMovements() async {
    try {
      final data = await _stockService.getStockMovements();
      if (mounted) setState(() => _stockMovements = data);
    } catch (_) {}
  }

  Future<void> _loadPersonnelLoans() async {
    try {
      final data = await _stockService.getOpenPersonnelLoans();
      if (mounted) setState(() => _personnelLoans = data);
    } catch (_) {}
  }

  Future<void> _loadDefectiveProducts() async {
    try {
      final data = await _stockService.getDefectiveProducts();
      if (mounted) setState(() => _defectiveProducts = data);
    } catch (_) {}
  }

  Future<void> _loadActiveTickets() async {
    try {
      final data = await _stockService.getActiveTicketsList();
      if (mounted) setState(() => _activeTickets = data);
    } catch (_) {}
  }

  // --- FİLTRELEME & YARDIMCI METODLAR ---

  int _asInt(dynamic val) {
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val?.toString() ?? '') ?? 0;
  }

  bool _isLowStock(Map<String, dynamic> item) {
    final qty = _asInt(item['quantity']);
    final min = _asInt(item['critical_level']);
    return qty <= min;
  }

  List<Map<String, dynamic>> _getFilteredStocks() {
    final query = _searchQuery.trim().toLowerCase();
    return _allStocks.where((item) {
      if (_selectedCategory != 'Tümü' &&
          item['category'] != _selectedCategory) {
        return false;
      }
      if (query.isEmpty) return true;
      final code = (item['code'] ?? '').toString().toLowerCase();
      final name = (item['name'] ?? '').toString().toLowerCase();
      final displayName = (item['displayName'] ?? '').toString().toLowerCase();
      final displaySubtitle = (item['displaySubtitle'] ?? '').toString().toLowerCase();
      final brand = (item['brand'] ?? '').toString().toLowerCase();
      final model = (item['model'] ?? '').toString().toLowerCase();
      final barcode = (item['barcode'] ?? '').toString().toLowerCase();
      final shelf = (item['shelf_location'] ?? '').toString().toLowerCase();
      return code.contains(query) ||
          name.contains(query) ||
          displayName.contains(query) ||
          displaySubtitle.contains(query) ||
          brand.contains(query) ||
          model.contains(query) ||
          barcode.contains(query) ||
          shelf.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> _getCriticalStocks() {
    return _getFilteredStocks().where(_isLowStock).toList();
  }

  String _formatDate(dynamic value) {
    if (value == null) return '-';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    final local = parsed.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$min';
  }

  void _showResetCatalogTrackingConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cleaning_services, color: AppColors.brass),
            SizedBox(width: 8),
            Text('Sanal Katalog Stoklarını Temizle'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Veritabanındaki sanal katalog stok takipleri temizlenecektir.\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '• GÜVENLİ İŞLEM: Fiyat teklifleri kataloğunuzdaki 2.000+ ürün ASLA SİLİNMEZ.\n'
              '• Sadece stok sayfasındaki sanal gösterimler temizlenir.\n'
              '• Fiziksel depodaki ürünlerinizi "Stoğa Al" butonu ile ekleyebilirsiniz.',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, color: Colors.white),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.brass),
            label: const Text('Depo Listesini Temizle'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _stockService.resetCatalogStockTracking();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sanal katalog stokları temizlendi. Ürün kataloğunuz aynen korunuyor.'),
                  backgroundColor: AppColors.mint,
                ),
              );
              _loadStocks();
            },
          ),
        ],
      ),
    );
  }

  void _showStopTrackingConfirmDialog(Map<String, dynamic> stock) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stok Takibini Durdur (Depodan Çıkar)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ürün: ${stock['displayName'] ?? stock['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.surfaceAccent, borderRadius: BorderRadius.circular(6)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.ink, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bu işlem ürünü Fiyat Teklifleri Kataloğundan SİLMES. Ürün teklif verirken hazır bulunur, sadece depodaki stok listesinden çıkarılır.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.corporateRed, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              await _stockService.stopStockTracking(stock['id'].toString());
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ürün stok takibinden çıkarıldı. Katalogda korunuyor.'), backgroundColor: AppColors.brass),
              );
              _loadStocks();
            },
            child: const Text('Depodan Çıkar'),
          ),
        ],
      ),
    );
  }

  // --- STOK KAYIT / DÜZENLEME MODALI ---

  void _showAddOrTrackStockModal([Map<String, dynamic>? editItem]) {
    if (!_canManageStock) return;

    if (editItem != null) {
      _showEditStockDialog(editItem);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => const _StockAddOrTrackDialog(),
    ).then((updated) {
      if (updated == true) _loadStocks();
    });
  }

  void _showEditStockDialog(Map<String, dynamic> stock) {
    final nameCtrl = TextEditingController(text: stock['displayName'] ?? stock['name'] ?? '');
    final brandCtrl = TextEditingController(text: stock['brand'] ?? '');
    final modelCtrl = TextEditingController(text: stock['model'] ?? '');
    final unitCtrl = TextEditingController(text: stock['unit'] ?? 'Adet');
    final qtyCtrl = TextEditingController(text: (stock['quantity'] ?? 0).toString());
    final minCtrl = TextEditingController(text: (stock['critical_level'] ?? 0).toString());
    final barcodeCtrl = TextEditingController(text: stock['barcode'] ?? '');
    final shelfCtrl = TextEditingController(text: stock['shelf_location'] ?? '');
    String category = stock['category'] ?? StockService.categories.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stok Ürününü Düzenle'),
        content: SingleChildScrollView(
          child: Container(
            width: 450,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ürün Adı (Anlaşılır Başlık) *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: StockService.categories.contains(category)
                            ? category
                            : StockService.categories.first,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          border: OutlineInputBorder(),
                        ),
                        items: StockService.categories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) => category = val!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: unitCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Birim (Adet/m/kg)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: brandCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Marka',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: modelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Model',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Stok Miktarı',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: minCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Kritik Seviye',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: barcodeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Barkod / Karekod',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: shelfCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Raf / Kasa No',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final payload = {
                'name': nameCtrl.text.trim(),
                'category': category,
                'unit': unitCtrl.text.trim(),
                'brand': brandCtrl.text.trim(),
                'model': modelCtrl.text.trim(),
                'quantity': int.tryParse(qtyCtrl.text.trim()) ?? 0,
                'critical_level': int.tryParse(minCtrl.text.trim()) ?? 0,
                'barcode': barcodeCtrl.text.trim(),
                'shelf_location': shelfCtrl.text.trim(),
              };
              Navigator.pop(ctx);
              await _stockService.updateStock(stock['id'], payload);
              _loadStocks();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showStartTrackingForCatalogItem(Map<String, dynamic> catalogItem) {
    if (!_canManageStock) return;
    final qtyCtrl = TextEditingController(text: '1');
    final minCtrl = TextEditingController(text: '5');
    final shelfCtrl = TextEditingController(text: catalogItem['shelf_location'] ?? '');
    final barcodeCtrl = TextEditingController(text: catalogItem['barcode'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.add_shopping_cart, color: AppColors.ink),
            const SizedBox(width: 8),
            Expanded(child: Text('Stoğa Al: ${catalogItem['displayName'] ?? catalogItem['name']}')),
          ],
        ),
        content: Container(
          width: 420,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ürün Kodu: ${catalogItem['code'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Kategori: ${catalogItem['category'] ?? '-'} | Marka: ${catalogItem['brand'] ?? '-'}'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'İlk Stok Miktarı *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kritik Seviye',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: shelfCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Raf / Kasa No',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: barcodeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Barkod',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white),
            onPressed: () async {
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
              final min = int.tryParse(minCtrl.text.trim()) ?? 0;
              Navigator.pop(ctx);
              try {
                await _stockService.startStockTracking(
                  productId: catalogItem['id'].toString(),
                  initialQuantity: qty,
                  minimumStock: min,
                  shelfLocation: shelfCtrl.text.trim(),
                  barcode: barcodeCtrl.text.trim(),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ürün stok takibine alındı ve depoya eklendi.'),
                    backgroundColor: AppColors.mint,
                  ),
                );
                _loadStocks();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.corporateRed),
                );
              }
            },
            child: const Text('Stoğa Ekle ve Takip Başlat'),
          ),
        ],
      ),
    );
  }

  void _showStockMovementModal(Map<String, dynamic> stock, String movementType) {
    if (!_canManageStock) return;
    final qtyCtrl = TextEditingController(text: '1');
    final reasonCtrl = TextEditingController();
    final destCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final isIn = movementType == 'in';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isIn ? Icons.arrow_circle_down_rounded : Icons.arrow_circle_up_rounded,
              color: isIn ? AppColors.mint : AppColors.brass,
            ),
            const SizedBox(width: 8),
            Text(isIn ? 'Stok Girişi Yap (IN)' : 'Stok Çıkışı Yap (OUT)'),
          ],
        ),
        content: Container(
          width: 400,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ürün: ${stock['displayName'] ?? stock['name']} (${stock['code']})', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Mevcut Stok: ${stock['quantity']} ${stock['unit'] ?? 'Adet'}'),
              const SizedBox(height: 16),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Miktar *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: InputDecoration(
                  labelText: isIn ? 'Geliş Nedeni / Fatura No' : 'Çıkış Nedeni',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: destCtrl,
                decoration: InputDecoration(
                  labelText: isIn ? 'Tedarikçi Firma' : 'Teslim Edilen Yer / Müşteri',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Açıklama / Not', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isIn ? AppColors.mint : AppColors.brass,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
              if (qty <= 0) return;
              Navigator.pop(ctx);
              try {
                await _stockService.registerStockMovement(
                  productId: stock['id'],
                  movementType: movementType,
                  quantity: qty,
                  reason: reasonCtrl.text.trim(),
                  destination: destCtrl.text.trim(),
                  note: noteCtrl.text.trim(),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isIn ? 'Stok girişi kaydedildi.' : 'Stok çıkışı kaydedildi.'),
                    backgroundColor: AppColors.mint,
                  ),
                );
                _loadStocks();
                _loadStockMovements();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.corporateRed),
                );
              }
            },
            child: const Text('İşlemi Kaydet'),
          ),
        ],
      ),
    );
  }

  // --- PERSONELE ZİMMET VERME MODALI ---

  void _showPersonnelLoanModal([Map<String, dynamic>? preselectedStock, String? preselectedPersonnelId]) async {
    if (!_canManageStock) return;
    final personnelList = await _stockService.listStockPersonnel();
    if (!mounted) return;

    if (personnelList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zimmet verilebilecek yetkili personel bulunamadı.')),
      );
      return;
    }

    String? selectedPersonnelId = preselectedPersonnelId ?? personnelList.first['id']?.toString();
    Map<String, dynamic>? selectedStock = preselectedStock;
    String? selectedJobCode;
    final qtyCtrl = TextEditingController(text: '1');
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.badge_outlined, color: AppColors.ink),
                SizedBox(width: 8),
                Text('Personele Zimmet Ver'),
              ],
            ),
            content: SingleChildScrollView(
              child: Container(
                width: 480,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedStock != null) ...[
                      Text('Ürün: ${selectedStock!['displayName'] ?? selectedStock!['name']} (${selectedStock!['code']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Mevcut Depo Stok: ${selectedStock!['quantity']} ${selectedStock!['unit'] ?? 'Adet'}', style: const TextStyle(color: AppColors.ink)),
                    ] else ...[
                      DropdownButtonFormField<String>(
                        value: selectedStock?['id']?.toString(),
                        decoration: const InputDecoration(labelText: 'Zimmet Edilecek Depo Ürünü *', border: OutlineInputBorder()),
                        items: _allStocks.where((s) => (s['quantity'] as num? ?? 0) > 0).map((s) {
                          return DropdownMenuItem<String>(
                            value: s['id'].toString(),
                            child: Text('${s['displayName'] ?? s['name']} (${s['quantity']} ${s['unit'] ?? 'Adet'})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          final found = _allStocks.firstWhere((s) => s['id'].toString() == val, orElse: () => {});
                          setModalState(() => selectedStock = found);
                        },
                      ),
                    ],
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: selectedPersonnelId,
                      decoration: const InputDecoration(labelText: 'Teknik Personel *', border: OutlineInputBorder()),
                      items: personnelList
                          .map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['full_name'] ?? p['email'] ?? p['id'])))
                          .toList(),
                      onChanged: (val) => setModalState(() => selectedPersonnelId = val),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: selectedJobCode,
                      decoration: const InputDecoration(labelText: 'İlişkili İş Kodu / Proje (İsteğe Bağlı)', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('Seçilmedi (İş Kodsuz)')),
                        ..._activeTickets.map((t) {
                          final code = t['job_code'] ?? t['id'];
                          final cust = t['customers'] is Map ? (t['customers']['name'] ?? '') : '';
                          return DropdownMenuItem<String>(
                            value: code.toString(),
                            child: Text('$code - $cust (${t['title'] ?? ''})', overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (val) => setModalState(() => selectedJobCode = val),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Zimmet Edilecek Miktar *', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(labelText: 'Zimmet Açıklaması / Not', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white),
                onPressed: () async {
                  if (selectedPersonnelId == null || selectedStock == null) return;
                  final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                  if (qty <= 0) return;
                  Navigator.pop(ctx);
                  try {
                    await _stockService.registerPersonnelLoan(
                      productId: selectedStock!['id'].toString(),
                      personnelId: selectedPersonnelId!,
                      quantity: qty,
                      jobCode: selectedJobCode,
                      note: noteCtrl.text.trim(),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Zimmet kaydı oluşturuldu.'), backgroundColor: AppColors.mint),
                    );
                    _loadStocks();
                    _loadPersonnelLoans();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.corporateRed),
                    );
                  }
                },
                child: const Text('Zimmetle'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- ZİMMET İŞLEME & KAPATMA MODALI ---

  void _showCloseLoanModal(Map<String, dynamic> loan) {
    if (!_canManageStock) return;
    final loanId = loan['id'];
    final totalLoanQty = _asInt(loan['quantity']);
    final productId = loan['product_id']?.toString() ?? loan['inventory']?['id']?.toString() ?? '';
    final personnelName = loan['personnel_name'] ?? 'Personel';
    final productObj = loan['inventory'] ?? {};
    final productName = productObj['displayName'] ?? productObj['name'] ?? 'Ürün';

    final consumedCtrl = TextEditingController(text: '0');
    final returnedCtrl = TextEditingController(text: totalLoanQty.toString());
    final defectiveCtrl = TextEditingController(text: '0');
    final faultDescCtrl = TextEditingController();
    String? selectedJobCode;
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final consumed = int.tryParse(consumedCtrl.text.trim()) ?? 0;
          final returned = int.tryParse(returnedCtrl.text.trim()) ?? 0;
          final defective = int.tryParse(defectiveCtrl.text.trim()) ?? 0;
          final totalAccounted = consumed + returned + defective;
          final remaining = totalLoanQty - totalAccounted;
          final isValid = totalAccounted > 0 && totalAccounted <= totalLoanQty;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.assignment_turned_in, color: AppColors.ink),
                const SizedBox(width: 8),
                Expanded(child: Text('Zimmeti İşle / Kapat: $personnelName')),
              ],
            ),
            content: SingleChildScrollView(
              child: Container(
                width: 500,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ürün: $productName (${productObj['code'] ?? ''})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Personeldeki Zimmetli Miktar: $totalLoanQty ${productObj['unit'] ?? 'Adet'}', style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: consumedCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Sarf Edilen *',
                              helperText: 'Projede kullanılan',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: returnedCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Sağlam İade *',
                              helperText: 'Stoğa geri teslim',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: defectiveCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Arızalı Ayrılan *',
                              helperText: 'Bozuk bildirilen',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (defective > 0) ...[
                      TextField(
                        controller: faultDescCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Arıza Sebebi / Açıklaması *',
                          hintText: 'Örn: Açılmıyor, röle çıkışı yanmış vb.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    DropdownButtonFormField<String>(
                      value: selectedJobCode,
                      decoration: const InputDecoration(
                        labelText: 'Sarf/Arıza Yapılan İş Kodu (İş Emri Bağlantısı)',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('Seçilmedi (Genel İşlemler)')),
                        ..._activeTickets.map((t) {
                          final code = t['job_code'] ?? t['id'];
                          final cust = t['customers'] is Map ? (t['customers']['name'] ?? '') : '';
                          return DropdownMenuItem<String>(
                            value: code.toString(),
                            child: Text('$code - $cust (${t['title'] ?? ''})', overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (val) => setModalState(() => selectedJobCode = val),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(labelText: 'Açıklama / Not', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),

                    // KISMI HESAPLAMA ÖZETİ
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isValid ? (remaining == 0 ? AppColors.mint.withOpacity(0.1) : AppColors.brass.withOpacity(0.1)) : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isValid ? (remaining == 0 ? AppColors.mint : AppColors.brass) : Colors.red,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sarf: $consumed | İade: $returned | Arızalı: $defective | Toplam İşlenen: $totalAccounted / $totalLoanQty',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          if (remaining > 0)
                            Text('• $remaining ${productObj['unit'] ?? 'Adet'} ürün personelin zimmetinde kalmaya devam edecek.', style: const TextStyle(fontSize: 12, color: AppColors.ink))
                          else if (remaining == 0)
                            const Text('• Bu zimmet kaydı tamamen kapatılacaktır.', style: const TextStyle(fontSize: 12, color: AppColors.mint))
                          else
                            const Text('• HATA: Sarf + İade + Arızalı miktarı toplam zimmetli miktardan fazla olamaz!', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                ),
                onPressed: isValid
                    ? () async {
                        Navigator.pop(ctx);
                        try {
                          await _stockService.processPersonnelLoanResolution(
                            loanId: loanId,
                            productId: productId,
                            personnelName: personnelName,
                            totalLoanQty: totalLoanQty,
                            consumedQty: consumed,
                            returnedQty: returned,
                            defectiveQty: defective,
                            faultDescription: faultDescCtrl.text.trim(),
                            jobCode: selectedJobCode,
                            note: noteCtrl.text.trim(),
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Zimmet işlemi başarıyla kaydedildi.'), backgroundColor: AppColors.mint),
                          );
                          _loadStocks();
                          _loadPersonnelLoans();
                          _loadDefectiveProducts();
                          _loadStockMovements();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.corporateRed),
                          );
                        }
                      }
                    : null,
                child: const Text('Zimmet İşlemini Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- ARIZALI ÜRÜN DURUM GÜNCELLEME MODALI ---

  void _showUpdateDefectiveStatusModal(Map<String, dynamic> defItem) {
    if (!_canManageStock) return;
    final defectiveId = defItem['id'];
    final productId = defItem['product_id']?.toString() ?? '';
    final qty = _asInt(defItem['quantity']);
    final currentStatus = defItem['status'] ?? 'in_faulty_stock';
    final productObj = defItem['inventory'] ?? {};
    final productName = productObj['displayName'] ?? productObj['name'] ?? 'Ürün';

    String newStatus = 'shipped_to_supplier';
    final trackingCtrl = TextEditingController(text: defItem['tracking_number'] ?? '');
    final supplierCtrl = TextEditingController(text: defItem['supplier_name'] ?? '');
    final noteCtrl = TextEditingController(text: defItem['notes'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.build_circle_outlined, color: AppColors.brass),
                const SizedBox(width: 8),
                Expanded(child: Text('Arızalı Ürün Süreci: $productName')),
              ],
            ),
            content: SingleChildScrollView(
              child: Container(
                width: 450,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Arızalı Miktar: $qty ${productObj['unit'] ?? 'Adet'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Mevcut Durum: ${_getDefectiveStatusLabel(currentStatus)}', style: const TextStyle(color: AppColors.ink)),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: newStatus,
                      decoration: const InputDecoration(labelText: 'Yeni Süreç Durumu *', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'shipped_to_supplier', child: Text('🚚 Tedarikçiye / Servise Kargolandı')),
                        DropdownMenuItem(value: 'repaired_returned', child: Text('✅ Tamir Edildi (Sağlam Stoğa Ekle)')),
                        DropdownMenuItem(value: 'replaced', child: Text('🔄 Yenisi Geldi (Sağlam Stoğa Ekle)')),
                        DropdownMenuItem(value: 'scrapped', child: Text('❌ Hurdaya Ayrıldı (Çöp)')),
                      ],
                      onChanged: (val) => setModalState(() => newStatus = val!),
                    ),
                    const SizedBox(height: 12),

                    if (newStatus == 'shipped_to_supplier') ...[
                      TextField(
                        controller: supplierCtrl,
                        decoration: const InputDecoration(labelText: 'Tedarikçi / Servis Firma Adı *', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: trackingCtrl,
                        decoration: const InputDecoration(labelText: 'Kargo Şirketi ve Takip Kodu *', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(labelText: 'Not / Süreç Açıklaması', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await _stockService.updateDefectiveStatus(
                      defectiveId: defectiveId,
                      newStatus: newStatus,
                      trackingNumber: trackingCtrl.text.trim(),
                      supplierName: supplierCtrl.text.trim(),
                      notes: noteCtrl.text.trim(),
                      productId: productId,
                      quantity: qty,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Arızalı ürün süreci güncellendi.'), backgroundColor: AppColors.mint),
                    );
                    _loadStocks();
                    _loadDefectiveProducts();
                    _loadStockMovements();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.corporateRed),
                    );
                  }
                },
                child: const Text('Durumu Güncelle'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getDefectiveStatusLabel(String status) {
    switch (status) {
      case 'in_faulty_stock':
        return 'Arızalı Depoda (Bekliyor)';
      case 'shipped_to_supplier':
        return 'Tedarikçiye Kargolandı';
      case 'repaired_returned':
        return 'Tamir Edildi (Sağlam Stoğa Eklendi)';
      case 'replaced':
        return 'Yenisi Geldi (Sağlam Stoğa Eklendi)';
      case 'scrapped':
        return 'Hurdaya Ayrıldı (Çöp)';
      default:
        return status;
    }
  }

  void _showBarcodeScannerModal() {
    if (!_canUseScanner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu cihazda barkod tarayıcı desteklenmiyor.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: 450,
          child: Column(
            children: [
              AppBar(
                title: const Text('Barkod / Karekod Taraması'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) async {
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final code = barcodes.first.rawValue ?? '';
                      if (code.isNotEmpty) {
                        Navigator.pop(ctx);
                        final match = await _stockService.getStockByBarcode(code);
                        if (!mounted) return;
                        if (match != null) {
                          setState(() {
                            _searchQuery = code;
                            _activeTab = 0;
                            _currentPage = 0;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Eşleşen Ürün Bulundu: ${match['displayName'] ?? match['name']}'), backgroundColor: AppColors.mint),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Barkod ($code) stokta bulunamadı.'), backgroundColor: AppColors.brass),
                          );
                        }
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _generateOrderPdfFromSelected() {
    if (_selectedProductIds.isEmpty) return;
    final selectedItems =
        _allStocks.where((s) => _selectedProductIds.contains(s['id'])).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          title: 'Sipariş Listesi PDF',
          pdfFileName: 'siparis_listesi.pdf',
          pdfGenerator: () => StockPdfService.generateOrderListPdfBytesFromList(selectedItems),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userProfile != null && !_canViewStock) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stok Durumu')),
        body: const Center(
          child: Text('Bu sayfaya erişim yetkiniz yok.', style: TextStyle(fontSize: 16)),
        ),
      );
    }

    final filteredStocks = _getFilteredStocks();
    final criticalStocks = _getCriticalStocks();
    final totalUnits = _allStocks.fold<int>(
      0,
      (sum, item) => sum + _asInt(item['quantity']),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.sand, // UzalTeklif Warm Sand Background (#F4EFE7)
      drawer: AppDrawer(
        currentPage: AppDrawerPage.stock,
        userName: _userProfile?.displayName,
        userRole: _userProfile?.role,
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.paper, // UzalTeklif Paper Surface (#FFFFFCF7)
        foregroundColor: AppColors.ink,    // UzalTeklif Primary Ink (#15304A)
        leadingWidth: 100,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.ink),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            SvgPicture.asset('assets/images/log.svg', width: 32, height: 32),
          ],
        ),
        title: const Text('Stok Yönetimi ERP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.ink)),
        actions: [
          if (_canUseScanner)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.ink),
              tooltip: 'Barkod Okut',
              onPressed: _showBarcodeScannerModal,
            ),
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.brass),
              tooltip: 'Seçilenlerden Sipariş PDF Oluştur',
              onPressed: _selectedProductIds.isEmpty ? null : _generateOrderPdfFromSelected,
            ),
          IconButton(
            icon: Icon(_isSelectionMode ? Icons.check_box_outlined : Icons.check_box_outline_blank, color: AppColors.ink),
            tooltip: _isSelectionMode ? 'Seçimi Kapat' : 'Çoklu Seçim Modu',
            onPressed: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                if (!_isSelectionMode) _selectedProductIds.clear();
              });
            },
          ),
          if (_canManageStock)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.ink),
              tooltip: 'Seçenekler',
              onSelected: (val) {
                if (val == 'reset_catalog') _showResetCatalogTrackingConfirmDialog();
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'reset_catalog',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services, color: AppColors.brass, size: 20),
                      SizedBox(width: 8),
                      Text('Sanal Katalog Stoklarını Temizle'),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.ink),
            tooltip: 'Yenile',
            onPressed: _loadAllData,
          ),
        ],
      ),
      floatingActionButton: _canManageStock
          ? FloatingActionButton.extended(
              onPressed: () => _showAddOrTrackStockModal(),
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_box_rounded),
              label: const Text('Stoğa Al / Ürün Ekle'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. KPI ÖZET KARTLARI BAR
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: _onlyTracked && _activeTab != 2 ? 'Depodaki Çeşit' : 'Katalog Çeşit',
                      value: '${_allStocks.length} Kalem',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Toplam Miktar',
                      value: '$totalUnits Adet',
                      icon: Icons.numbers_outlined,
                      color: AppColors.brass,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Kritik Stok',
                      value: '${criticalStocks.length} Ürün',
                      icon: Icons.warning_amber_rounded,
                      color: criticalStocks.isNotEmpty ? AppColors.brass : const Color(0xFF5A6E82),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Zimmetli Personel',
                      value: '${_getGroupedLoansMap().length} Personel',
                      icon: Icons.badge_outlined,
                      color: AppColors.mint,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Arızalı Ürünler',
                      value: '${_defectiveProducts.length} Kayıt',
                      icon: Icons.build_circle_outlined,
                      color: _defectiveProducts.isNotEmpty ? AppColors.corporateRed : const Color(0xFF5A6E82),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. KONTROL & FİLTRELEME BARI
              Container(
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.mist),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) => setState(() {
                          _searchQuery = val;
                          _currentPage = 0;
                        }),
                        style: const TextStyle(color: AppColors.ink, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: _activeTab == 2
                              ? 'Katalogda Ürün Kodu, İsim veya Marka Ara...'
                              : 'Depoda Ürün Kodu, İsim, Barkod veya Raf Ara...',
                          hintStyle: const TextStyle(color: Color(0xFF8A9BAE)),
                          prefixIcon: const Icon(Icons.search, color: AppColors.ink),
                          filled: true,
                          fillColor: Colors.white,
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Color(0xFF8A9BAE)),
                                  onPressed: () => setState(() {
                                    _searchQuery = '';
                                    _currentPage = 0;
                                  }),
                                )
                              : null,
                          border: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.mist)),
                          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.mist)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        style: const TextStyle(color: AppColors.ink, fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.mist)),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.mist)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        items: ['Tümü', ...StockService.categories]
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) => setState(() {
                          _selectedCategory = val!;
                          _currentPage = 0;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. SEKMELİ GEZİNTİ BUTONLARI
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabChip(0, 'Depodaki Stoklar (Fiziksel)', Icons.table_chart),
                    const SizedBox(width: 8),
                    _buildTabChip(1, 'Kritik Depo Stokları (${criticalStocks.length})', Icons.warning_amber),
                    const SizedBox(width: 8),
                    _buildTabChip(2, 'Tüm Ürün Kataloğu', Icons.menu_book),
                    const SizedBox(width: 8),
                    _buildTabChip(3, 'Personel Zimmetleri (${_getGroupedLoansMap().length} Personel)', Icons.badge),
                    const SizedBox(width: 8),
                    _buildTabChip(6, 'Arızalı Ürünler (RMA) (${_defectiveProducts.length})', Icons.build_circle),
                    const SizedBox(width: 8),
                    _buildTabChip(4, 'Stok Hareket Logları (${_stockMovements.length})', Icons.history),
                    const SizedBox(width: 8),
                    _buildTabChip(5, 'Eksik Malzemeli İşler (${_missingTickets.length})', Icons.assignment_late),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. İÇERİK TABLOSU (FULL-WIDTH STRETCHED DATAGRID)
              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.ink)))
              else ...[
                if (_activeTab == 0) _buildStockDataGrid(filteredStocks, showTrackButton: false),
                if (_activeTab == 1) _buildStockDataGrid(criticalStocks, showTrackButton: false),
                if (_activeTab == 2) _buildStockDataGrid(filteredStocks, showTrackButton: true),
                if (_activeTab == 3) _buildPersonnelLoansTable(),
                if (_activeTab == 6) _buildDefectiveProductsTable(),
                if (_activeTab == 4) _buildMovementsTable(),
                if (_activeTab == 5) _buildMissingTicketsTable(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mist),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5A6E82),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    return ChoiceChip(
      avatar: Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.ink),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.ink,
      backgroundColor: AppColors.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: isSelected ? AppColors.ink : AppColors.mist),
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.ink,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        fontSize: 13,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _activeTab = index;
            _onlyTracked = index != 2;
            _currentPage = 0;
          });
          _loadStocks();
        }
      },
    );
  }

  // --- TAM GENİŞLİK SAYFALAMALI DATAGRID STOK TABLOSU ---

  Widget _buildStockDataGrid(List<Map<String, dynamic>> stocks, {required bool showTrackButton}) {
    if (stocks.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.mist),
        ),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              const Text('Kriterlere uygun stok kaydı bulunamadı.', style: TextStyle(color: Color(0xFF5A6E82))),
              const SizedBox(height: 12),
              if (_canManageStock && !showTrackButton)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Katalogdan Ürün Stoğa Al'),
                  onPressed: () => _showAddOrTrackStockModal(),
                ),
            ],
          ),
        ),
      );
    }

    final totalItems = stocks.length;
    final totalPages = (totalItems / _pageSize).ceil();
    if (_currentPage >= totalPages) _currentPage = 0;

    final startIndex = _currentPage * _pageSize;
    final endIndex = (startIndex + _pageSize < totalItems) ? startIndex + _pageSize : totalItems;
    final pagedStocks = stocks.sublist(startIndex, endIndex);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mist),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppColors.ink),
                    headingRowHeight: 44,
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 56,
                    dividerThickness: 1,
                    horizontalMargin: 16,
                    columnSpacing: 20,
                    columns: [
                      if (_isSelectionMode) const DataColumn(label: Text('Seç', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      const DataColumn(label: Text('Ürün Kodu', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      const DataColumn(label: Text('Ürün Adı', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      const DataColumn(label: Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      const DataColumn(label: Text('Marka / Model', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      const DataColumn(label: Text('Stok Miktarı', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      const DataColumn(label: Text('Min. Stok', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      const DataColumn(label: Text('Raf / Kasa', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      const DataColumn(label: Text('Barkod', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      if (_canManageStock) const DataColumn(label: Text('İşlemler', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                    ],
                    rows: pagedStocks.map((item) {
                      final id = item['id'].toString();
                      final isSelected = _selectedProductIds.contains(id);
                      final qty = _asInt(item['quantity']);
                      final min = _asInt(item['critical_level']);
                      final isTracked = item['stock_tracking_started'] == true;
                      final isLow = isTracked && qty <= min;
                      final isOut = isTracked && qty == 0;
                      final titleDisplay = item['displayName'] ?? item['name'] ?? '-';
                      final subtitleDisplay = (item['displaySubtitle'] ?? '').toString();

                      return DataRow(
                        selected: isSelected,
                        onSelectChanged: _isSelectionMode
                            ? (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedProductIds.add(id);
                                  } else {
                                    _selectedProductIds.remove(id);
                                  }
                                });
                              }
                            : null,
                        cells: [
                          if (_isSelectionMode)
                            DataCell(
                              Checkbox(
                                value: isSelected,
                                activeColor: AppColors.brass,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedProductIds.add(id);
                                    } else {
                                      _selectedProductIds.remove(id);
                                    }
                                  });
                                },
                              ),
                            ),
                          DataCell(Text(item['code'] ?? item['id'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink))),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  titleDisplay,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink),
                                ),
                                if (subtitleDisplay.isNotEmpty)
                                  Text(
                                    subtitleDisplay,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF5A6E82), fontStyle: FontStyle.italic),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.sand,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.mist),
                              ),
                              child: Text(item['category'] ?? 'Diğer', style: const TextStyle(fontSize: 12, color: AppColors.ink, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          DataCell(Text('${item['brand'] ?? ''} ${item['model'] ?? ''}'.trim(), style: const TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600))),
                          DataCell(
                            isTracked
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isOut
                                          ? const Color(0xFFFEE2E2)
                                          : isLow
                                              ? const Color(0xFFFEF3C7)
                                              : const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$qty ${item['unit'] ?? 'Adet'}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: isOut
                                            ? const Color(0xFFB91C1C)
                                            : isLow
                                                ? const Color(0xFFB45309)
                                                : const Color(0xFF15803D),
                                      ),
                                    ),
                                  )
                                : const Text('Depoda Yok', style: TextStyle(color: Color(0xFF8A9BAE), fontStyle: FontStyle.italic, fontSize: 12)),
                          ),
                          DataCell(Text('$min ${item['unit'] ?? 'Adet'}', style: const TextStyle(fontSize: 13, color: AppColors.ink))),
                          DataCell(Text(item['shelf_location'] ?? '-', style: const TextStyle(fontSize: 13, color: AppColors.ink))),
                          DataCell(Text(item['barcode'] ?? '-', style: const TextStyle(fontSize: 13, color: AppColors.ink))),
                          if (_canManageStock)
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isTracked || showTrackButton)
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.brass,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        elevation: 0,
                                      ),
                                      icon: const Icon(Icons.add_shopping_cart, size: 14),
                                      label: const Text('Stoğa Al', style: TextStyle(fontSize: 12)),
                                      onPressed: () => _showStartTrackingForCatalogItem(item),
                                    )
                                  else ...[
                                    IconButton(
                                      icon: const Icon(Icons.arrow_circle_down, color: AppColors.mint, size: 22),
                                      tooltip: 'Stok Girişi (IN)',
                                      onPressed: () => _showStockMovementModal(item, 'in'),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.arrow_circle_up, color: AppColors.brass, size: 22),
                                      tooltip: 'Stok Çıkışı (OUT)',
                                      onPressed: () => _showStockMovementModal(item, 'out'),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.badge_outlined, color: AppColors.ink, size: 22),
                                      tooltip: 'Personele Zimmetle',
                                      onPressed: () => _showPersonnelLoanModal(item),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 18, color: AppColors.ink),
                                      onSelected: (val) {
                                        if (val == 'edit') _showAddOrTrackStockModal(item);
                                        if (val == 'untrack') _showStopTrackingConfirmDialog(item);
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                                        const PopupMenuItem(
                                          value: 'untrack',
                                          child: Text('Depodan Çıkar (Katalogda Sakla)', style: TextStyle(color: AppColors.corporateRed)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),

          // SAYFALAMA KONTROL BARI
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.paper,
              border: Border(top: BorderSide(color: AppColors.mist)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gösterilen: ${totalItems > 0 ? startIndex + 1 : 0} - $endIndex / $totalItems Ürün (Sayfa ${_currentPage + 1} / $totalPages)',
                  style: const TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<int>(
                        value: _pageSize,
                        style: const TextStyle(color: AppColors.ink, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Sayfa Başına',
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.mist)),
                          enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.mist)),
                        ),
                        items: const [25, 50, 100]
                            .map((sz) => DropdownMenuItem(value: sz, child: Text('$sz Ürün')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _pageSize = val;
                              _currentPage = 0;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.mist),
                        backgroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.chevron_left, size: 18),
                      label: const Text('Önceki'),
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.mist),
                        backgroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.chevron_right, size: 18),
                      label: const Text('Sonraki'),
                      onPressed: _currentPage < totalPages - 1
                          ? () => setState(() => _currentPage++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ARIZALI ÜRÜNLER TABLOSU (RMA) ---

  Widget _buildDefectiveProductsTable() {
    if (_defectiveProducts.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.mist),
        ),
        padding: const EdgeInsets.all(32),
        child: const Center(
          child: Text('Arızalı stok veya servis takibinde ürün bulunmuyor.', style: TextStyle(color: Color(0xFF5A6E82))),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mist),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.ink),
                headingRowHeight: 44,
                columns: const [
                  DataColumn(label: Text('Tarih', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Ürün Adı / Kod', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Miktar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Bildiren Personel', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('İş Kodu', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Arıza Sebebi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Süreç Durumu', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Tedarikçi / Kargo Takip', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('İşlem', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                ],
                rows: _defectiveProducts.map((def) {
                  final product = def['inventory'] ?? {};
                  final status = def['status'] ?? 'in_faulty_stock';
                  final tracking = (def['tracking_number'] ?? '').toString();
                  final supplier = (def['supplier_name'] ?? '').toString();

                  return DataRow(
                    cells: [
                      DataCell(Text(_formatDate(def['created_at']), style: const TextStyle(color: AppColors.ink))),
                      DataCell(Text('${product['displayName'] ?? product['name'] ?? 'Bilinmeyen'} (${product['code'] ?? ''})', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                          child: Text('${def['quantity']} ${product['unit'] ?? 'Adet'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB91C1C))),
                        ),
                      ),
                      DataCell(Text(def['reported_by_name'] ?? '-', style: const TextStyle(color: AppColors.ink))),
                      DataCell(Text(def['job_code'] ?? '-', style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold))),
                      DataCell(Text(def['fault_description'] ?? '-', style: const TextStyle(color: AppColors.ink))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'in_faulty_stock'
                                ? const Color(0xFFFEF3C7)
                                : status == 'shipped_to_supplier'
                                    ? AppColors.surfaceAccent
                                    : status == 'repaired_returned' || status == 'replaced'
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getDefectiveStatusLabel(status),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: status == 'in_faulty_stock'
                                  ? const Color(0xFFB45309)
                                  : status == 'shipped_to_supplier'
                                      ? AppColors.ink
                                      : status == 'repaired_returned' || status == 'replaced'
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          [
                            if (supplier.isNotEmpty) 'Firma: $supplier',
                            if (tracking.isNotEmpty) 'Kargo: $tracking',
                          ].join(' | ').ifEmpty('-'),
                          style: const TextStyle(fontSize: 12, color: AppColors.ink),
                        ),
                      ),
                      DataCell(
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white),
                          icon: const Icon(Icons.build_circle, size: 16),
                          label: const Text('Süreci Güncelle'),
                          onPressed: () => _showUpdateDefectiveStatusModal(def),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- PERSONEL BAZLI ZİMMET YÖNETİMİ (CARİ MANTIĞI) ---

  Map<String, Map<String, dynamic>> _getGroupedLoansMap() {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final loan in _personnelLoans) {
      final pName = (loan['personnel_name'] ?? 'Bilinmeyen Personel').toString().trim();
      final pId = (loan['personnel_id'] ?? pName).toString();
      final qty = _asInt(loan['quantity']);

      if (!grouped.containsKey(pName)) {
        grouped[pName] = {
          'personnel_id': pId,
          'personnel_name': pName,
          'total_quantity': 0,
          'item_count': 0,
          'latest_date': loan['borrowed_at'],
          'loans': <Map<String, dynamic>>[],
        };
      }

      final group = grouped[pName]!;
      group['total_quantity'] = (group['total_quantity'] as int) + qty;
      final loanList = group['loans'] as List<Map<String, dynamic>>;
      loanList.add(loan);
      group['item_count'] = loanList.length;
    }

    return grouped;
  }

  Widget _buildPersonnelLoansTable() {
    final groupedMap = _getGroupedLoansMap();

    if (groupedMap.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.mist),
        ),
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              const Text('Aktif personel zimmeti bulunmuyor.', style: TextStyle(color: Color(0xFF5A6E82))),
              const SizedBox(height: 12),
              if (_canManageStock)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white),
                  icon: const Icon(Icons.badge_outlined),
                  label: const Text('Personele Yeni Zimmet Ver'),
                  onPressed: () => _showPersonnelLoanModal(),
                ),
            ],
          ),
        ),
      );
    }

    final groupedList = groupedMap.values.toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mist),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppColors.ink),
                    headingRowHeight: 44,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 64,
                    columns: const [
                      DataColumn(label: Text('Teknik Personel (Cari Hesap)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      DataColumn(label: Text('Zimmetli Kalem Çeşidi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      DataColumn(label: Text('Toplam Ürün Adedi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      DataColumn(label: Text('Son Zimmet Tarihi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      DataColumn(label: Text('Zimmet İşlemleri', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                    ],
                    rows: groupedList.map((group) {
                      final pName = group['personnel_name'].toString();
                      final pId = group['personnel_id'].toString();
                      final itemCount = group['item_count'] as int;
                      final totalQty = group['total_quantity'] as int;
                      final latestDate = group['latest_date'];
                      final loans = group['loans'] as List<Map<String, dynamic>>;

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.brass.withOpacity(0.2),
                                  child: Text(
                                    pName.isNotEmpty ? pName[0].toUpperCase() : 'P',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink, fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(pName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.ink)),
                              ],
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.sand, borderRadius: BorderRadius.circular(6)),
                              child: Text('$itemCount Çeşit Ürün', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink, fontSize: 13)),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.surfaceAccent, borderRadius: BorderRadius.circular(6)),
                              child: Text('$totalQty Adet', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink, fontSize: 13)),
                            ),
                          ),
                          DataCell(Text(_formatDate(latestDate), style: const TextStyle(color: AppColors.ink))),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white),
                                  icon: const Icon(Icons.receipt_long, size: 16),
                                  label: Text('Zimmet Dökümü & İşle ($itemCount)'),
                                  onPressed: () => _showPersonnelDetailModal(pName, pId, loans),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.ink,
                                    side: const BorderSide(color: AppColors.mist),
                                    backgroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Zimmet Ekle'),
                                  onPressed: () => _showPersonnelLoanModal(null, pId),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- PERSONEL ZİMMET DETAY & EKSTRE MODALI (CARİ DÖKÜMÜ) ---

  void _showPersonnelDetailModal(String personnelName, String personnelId, List<Map<String, dynamic>> loans) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.badge, color: AppColors.ink),
            const SizedBox(width: 8),
            Expanded(child: Text('$personnelName - Zimmetli Ürün Dökümü')),
          ],
        ),
        content: SingleChildScrollView(
          child: Container(
            width: 750,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surfaceAccent, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Toplam ${loans.length} Kalem / ${loans.fold<int>(0, (sum, l) => sum + _asInt(l['quantity']))} Adet Zimmetli Ürün Var',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink, fontSize: 14),
                      ),
                      if (_canManageStock)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('+ Bu Personel İçin Yeni Zimmet Ver'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showPersonnelLoanModal(null, personnelId);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppColors.sand),
                    headingRowHeight: 38,
                    columns: const [
                      DataColumn(label: Text('Ürün Adı / Kod', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink))),
                      DataColumn(label: Text('Miktar', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink))),
                      DataColumn(label: Text('Veriliş Tarihi', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink))),
                      DataColumn(label: Text('Zimmet Notu / İş Kodu', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink))),
                      DataColumn(label: Text('İşlem', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink))),
                    ],
                    rows: loans.map((loan) {
                      final product = loan['inventory'] ?? {};
                      return DataRow(
                        cells: [
                          DataCell(Text('${product['displayName'] ?? product['name'] ?? 'Bilinmeyen'} (${product['code'] ?? ''})', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.brass.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text('${loan['quantity']} ${product['unit'] ?? 'Adet'}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
                            ),
                          ),
                          DataCell(Text(_formatDate(loan['borrowed_at']), style: const TextStyle(color: AppColors.ink))),
                          DataCell(Text(loan['note'] ?? '-', style: const TextStyle(color: AppColors.ink))),
                          DataCell(
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                              icon: const Icon(Icons.assignment_turned_in, size: 14),
                              label: const Text('Zimmeti İşle / Kapat', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showCloseLoanModal(loan);
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
        ],
      ),
    );
  }

  Widget _buildMovementsTable() {
    if (_stockMovements.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.mist),
        ),
        padding: const EdgeInsets.all(32),
        child: const Center(child: Text('Stok hareket kaydı bulunamadı.', style: TextStyle(color: Color(0xFF5A6E82)))),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mist),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.ink),
                headingRowHeight: 44,
                columns: const [
                  DataColumn(label: Text('Tarih', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Ürün Adı', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('İşlem Tipi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Miktar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Önce / Sonra', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Neden / Hedef', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Açıklama', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                ],
                rows: _stockMovements.map((mov) {
                  final isIn = mov['movement_type'] == 'in';
                  final product = mov['inventory'] ?? {};
                  return DataRow(
                    cells: [
                      DataCell(Text(_formatDate(mov['created_at']), style: const TextStyle(color: AppColors.ink))),
                      DataCell(Text(product['displayName'] ?? product['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink))),
                      DataCell(
                        Chip(
                          avatar: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, size: 14, color: Colors.white),
                          label: Text(isIn ? 'Stok Girişi (IN)' : 'Stok Çıkışı (OUT)'),
                          backgroundColor: isIn ? AppColors.mint : AppColors.brass,
                          labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                      DataCell(Text('${mov['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink))),
                      DataCell(Text('${mov['quantity_before']} ➔ ${mov['quantity_after']}', style: const TextStyle(color: AppColors.ink))),
                      DataCell(Text('${mov['reason'] ?? ''} ${mov['destination'] ?? ''}'.trim(), style: const TextStyle(color: AppColors.ink))),
                      DataCell(Text(mov['note'] ?? '-', style: const TextStyle(color: AppColors.ink))),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMissingTicketsTable() {
    if (_missingTickets.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.mist),
        ),
        padding: const EdgeInsets.all(32),
        child: const Center(child: Text('Eksik malzemesi olan iş emri kaydı bulunmuyor.', style: TextStyle(color: Color(0xFF5A6E82)))),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mist),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AppColors.ink),
                headingRowHeight: 44,
                columns: const [
                  DataColumn(label: Text('İş Kodu', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('İş Başlığı', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Müşteri', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Cihaz / Model', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('Eksik Malzeme Notu', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                  DataColumn(label: Text('İş Detayı', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                ],
                rows: _missingTickets.map((t) {
                  final customer = t['customers'];
                  final custName = customer is Map ? customer['name'] : '-';
                  return DataRow(
                    cells: [
                      DataCell(Text(t['job_code'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink))),
                      DataCell(Text(t['title'] ?? '-', style: const TextStyle(color: AppColors.ink))),
                      DataCell(Text(custName, style: const TextStyle(color: AppColors.ink))),
                      DataCell(Text('${t['device_brand'] ?? ''} ${t['device_model'] ?? ''}'.trim(), style: const TextStyle(color: AppColors.ink))),
                      DataCell(
                        Text(
                          t['missing_parts'] ?? '',
                          style: const TextStyle(color: AppColors.corporateRed, fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.open_in_new, color: AppColors.brass),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TicketDetailPage(ticketId: t['id'].toString()),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

extension _StringEmptyExt on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

// --- STOK KAYIT / KATALOGDAN STOĞA ALMA DİYALOĞU ---

class _StockAddOrTrackDialog extends StatefulWidget {
  const _StockAddOrTrackDialog();

  @override
  State<_StockAddOrTrackDialog> createState() => _StockAddOrTrackDialogState();
}

class _StockAddOrTrackDialogState extends State<_StockAddOrTrackDialog> {
  final StockService _stockService = StockService();

  int _selectedTab = 0; // 0: Katalogdan Stoğa Al, 1: Sıfırdan Özel Ürün Ekle

  // Tab 1 State: Katalog Arama
  List<Map<String, dynamic>> _catalogProducts = [];
  bool _loadingCatalog = false;
  Map<String, dynamic>? _selectedCatalogProduct;
  final TextEditingController _catalogSearchCtrl = TextEditingController();

  final _trackQtyCtrl = TextEditingController(text: '1');
  final _trackMinCtrl = TextEditingController(text: '5');
  final _trackShelfCtrl = TextEditingController();
  final _trackBarcodeCtrl = TextEditingController();

  // Tab 2 State: Sıfırdan Ürün Ekle
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'Adet');
  final _qtyCtrl = TextEditingController(text: '1');
  final _minCtrl = TextEditingController(text: '5');
  final _barcodeCtrl = TextEditingController();
  final _shelfCtrl = TextEditingController();
  String _category = StockService.categories.first;

  @override
  void initState() {
    super.initState();
    _fetchCatalog();
  }

  Future<void> _fetchCatalog([String? search]) async {
    setState(() => _loadingCatalog = true);
    try {
      final results = await _stockService.getCatalogProducts(search: search);
      if (mounted) {
        setState(() {
          _catalogProducts = results;
          _loadingCatalog = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        children: [
          const Text('Stok Kaydı / Depoya Ürün Ekleme', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Katalogdan Stoğa Al'),
                icon: Icon(Icons.search_outlined),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Sıfırdan Özel Ürün Ekle'),
                icon: Icon(Icons.add_circle_outline),
              ),
            ],
            selected: {_selectedTab},
            onSelectionChanged: (val) {
              setState(() => _selectedTab = val.first);
            },
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Container(
          width: 500,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _selectedTab == 0 ? _buildCatalogTrackTab() : _buildNewProductTab(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ink,
            foregroundColor: Colors.white,
          ),
          onPressed: _submit,
          child: Text(_selectedTab == 0 ? 'Stoğa Al ve Takip Başlat' : 'Ürünü ve Stoğu Kaydet'),
        ),
      ],
    );
  }

  Widget _buildCatalogTrackTab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _catalogSearchCtrl,
          decoration: InputDecoration(
            labelText: 'Katalogda Ürün Ara (Ad, Kod, Marka)',
            prefixIcon: const Icon(Icons.search, color: AppColors.ink),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward, color: AppColors.ink),
              onPressed: () => _fetchCatalog(_catalogSearchCtrl.text),
            ),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (val) => _fetchCatalog(val),
        ),
        const SizedBox(height: 12),

        if (_loadingCatalog)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.ink)))
        else if (_catalogProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Katalogda eşleşen ürün bulunamadı. "Sıfırdan Özel Ürün Ekle" sekmesini kullanabilirsiniz.'),
          )
        else
          Container(
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.mist),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: _catalogProducts.length,
              itemBuilder: (ctx, i) {
                final item = _catalogProducts[i];
                final isSelected = _selectedCatalogProduct?['id'] == item['id'];
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor: AppColors.surfaceAccent,
                  title: Text(item['displayName'] ?? item['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
                  subtitle: Text('Kod: ${item['code']} | Kat: ${item['category']} | Marka: ${item['brand']}'),
                  onTap: () {
                    setState(() {
                      _selectedCatalogProduct = item;
                      _trackShelfCtrl.text = item['shelf_location'] ?? '';
                      _trackBarcodeCtrl.text = item['barcode'] ?? '';
                    });
                  },
                );
              },
            ),
          ),

        if (_selectedCatalogProduct != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surfaceAccent, borderRadius: BorderRadius.circular(6)),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Seçilen Ürün: ${_selectedCatalogProduct!['displayName'] ?? _selectedCatalogProduct!['name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _trackQtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'İlk Stok Miktarı *', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _trackMinCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Kritik Seviye', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _trackShelfCtrl,
                  decoration: const InputDecoration(labelText: 'Raf / Kasa No', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _trackBarcodeCtrl,
                  decoration: const InputDecoration(labelText: 'Barkod / Karekod', border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNewProductTab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Ürün Adı *', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
                items: StockService.categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _category = val!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _unitCtrl,
                decoration: const InputDecoration(labelText: 'Birim (Adet/m/kg)', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _brandCtrl,
                decoration: const InputDecoration(labelText: 'Marka', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _modelCtrl,
                decoration: const InputDecoration(labelText: 'Model', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'İlk Stok Miktarı', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kritik Seviye', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _barcodeCtrl,
                decoration: const InputDecoration(labelText: 'Barkod / Karekod', border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _shelfCtrl,
                decoration: const InputDecoration(labelText: 'Raf / Kasa No', border: OutlineInputBorder()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _submit() async {
    if (_selectedTab == 0) {
      if (_selectedCatalogProduct == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen listeden stoğa alınacak bir katalog ürünü seçiniz.')),
        );
        return;
      }

      final qty = int.tryParse(_trackQtyCtrl.text.trim()) ?? 0;
      final min = int.tryParse(_trackMinCtrl.text.trim()) ?? 0;

      try {
        await _stockService.startStockTracking(
          productId: _selectedCatalogProduct!['id'].toString(),
          initialQuantity: qty,
          minimumStock: min,
          shelfLocation: _trackShelfCtrl.text.trim(),
          barcode: _trackBarcodeCtrl.text.trim(),
        );
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.corporateRed),
          );
        }
      }
    } else {
      if (_nameCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen ürün adını giriniz.')),
        );
        return;
      }

      final payload = {
        'name': _nameCtrl.text.trim(),
        'category': _category,
        'unit': _unitCtrl.text.trim(),
        'brand': _brandCtrl.text.trim(),
        'model': _modelCtrl.text.trim(),
        'quantity': int.tryParse(_qtyCtrl.text.trim()) ?? 0,
        'critical_level': int.tryParse(_minCtrl.text.trim()) ?? 0,
        'barcode': _barcodeCtrl.text.trim(),
        'shelf_location': _shelfCtrl.text.trim(),
      };

      try {
        await _stockService.addStock(payload);
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.corporateRed),
          );
        }
      }
    }
  }
}
