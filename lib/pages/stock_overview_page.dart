import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/user_profile.dart';
import '../services/permission_service.dart';
import '../services/stock_pdf_service.dart';
import '../services/stock_service.dart';
import '../services/user_service.dart';
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

  bool _isLoading = true;
  bool _onlyTracked = true; // Varsayılan: Sadece depoda bulunan / takibi olan stoklar

  String _searchQuery = '';
  String _selectedCategory = 'Tümü';
  int _activeTab = 0; // 0: Depodaki Stoklar, 1: Kritik Stoklar, 2: Tüm Katalog, 3: Zimmetler, 4: Hareketler, 5: Eksik İşler

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
      // activeTab == 2 ise tüm kataloğu çeker, aksi halde sadece fiziksel stokları getirir
      final fetchOnlyTracked = _activeTab != 2 && _onlyTracked;
      final data = await _stockService.getStocks(onlyTracked: fetchOnlyTracked);
      if (mounted) {
        setState(() {
          _allStocks = data;
          _isLoading = false;
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
      final brand = (item['brand'] ?? '').toString().toLowerCase();
      final model = (item['model'] ?? '').toString().toLowerCase();
      final barcode = (item['barcode'] ?? '').toString().toLowerCase();
      final shelf = (item['shelf_location'] ?? '').toString().toLowerCase();
      return code.contains(query) ||
          name.contains(query) ||
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

  // --- YENİLENMİŞ STOK KAYIT / KATALOGDAN STOĞA ALMA MODALI ---

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
    final nameCtrl = TextEditingController(text: stock['name'] ?? '');
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
                    labelText: 'Ürün Adı *',
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
            const Icon(Icons.add_shopping_cart, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(child: Text('Stoğa Al: ${catalogItem['name']}')),
          ],
        ),
        content: Container(
          width: 420,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ürün Kod: ${catalogItem['code'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    backgroundColor: Colors.green,
                  ),
                );
                _loadStocks();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
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
              color: isIn ? Colors.green : Colors.orange,
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
              Text('Ürün: ${stock['name']} (${stock['code']})', style: const TextStyle(fontWeight: FontWeight.bold)),
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
              backgroundColor: isIn ? Colors.green : Colors.orange,
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
                    backgroundColor: Colors.green,
                  ),
                );
                _loadStocks();
                _loadStockMovements();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('İşlemi Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showPersonnelLoanModal(Map<String, dynamic> stock) async {
    if (!_canManageStock) return;
    final personnelList = await _stockService.listStockPersonnel();
    if (!mounted) return;

    if (personnelList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zimmet verilebilecek yetkili personel bulunamadı.')),
      );
      return;
    }

    String? selectedPersonnelId = personnelList.first['id']?.toString();
    final qtyCtrl = TextEditingController(text: '1');
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.badge_outlined, color: Colors.blue),
                SizedBox(width: 8),
                Text('Personele Zimmet Ver'),
              ],
            ),
            content: Container(
              width: 420,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ürün: ${stock['name']} (${stock['code']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Mevcut Stok: ${stock['quantity']} ${stock['unit'] ?? 'Adet'}'),
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
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Miktar *', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Zimmet Notu / İş Emri Kodu', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
              ElevatedButton(
                onPressed: () async {
                  if (selectedPersonnelId == null) return;
                  final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                  if (qty <= 0) return;
                  Navigator.pop(ctx);
                  try {
                    await _stockService.registerPersonnelLoan(
                      productId: stock['id'],
                      personnelId: selectedPersonnelId!,
                      quantity: qty,
                      note: noteCtrl.text.trim(),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Zimmet kaydı oluşturuldu.'), backgroundColor: Colors.green),
                    );
                    _loadStocks();
                    _loadPersonnelLoans();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
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

  void _showCloseLoanModal(Map<String, dynamic> loan) {
    if (!_canManageStock) return;
    final loanId = loan['id'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zimmeti Kapat / Durum Seç'),
        content: Text(
          '${loan['personnel_name']} üzerindeki ${loan['quantity']} adet ${loan['inventory']?['name'] ?? 'ürün'} zimmeti için işlem seçiniz:',
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.assignment_turned_in, color: Colors.blue),
            label: const Text('İşletmede Sarf Edildi (Consumed)'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _stockService.closePersonnelLoan(loanId: loanId, resolution: 'consumed');
              _loadPersonnelLoans();
              _loadStockMovements();
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.archive_outlined, color: Colors.white),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            label: const Text('Stoğa İade Alındı (Returned)'),
            onPressed: () async {
              Navigator.pop(ctx);
              await _stockService.closePersonnelLoan(loanId: loanId, resolution: 'returned');
              _loadStocks();
              _loadPersonnelLoans();
              _loadStockMovements();
            },
          ),
        ],
      ),
    );
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
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Eşleşen Ürün Bulundu: ${match['name']}'), backgroundColor: Colors.green),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Barkod ($code) stokta bulunamadı.'), backgroundColor: Colors.orange),
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

    final theme = Theme.of(context);
    final filteredStocks = _getFilteredStocks();
    final criticalStocks = _getCriticalStocks();
    final totalUnits = _allStocks.fold<int>(
      0,
      (sum, item) => sum + _asInt(item['quantity']),
    );

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
        backgroundColor: theme.cardColor,
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
        title: const Text('Stok Yönetimi ERP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          if (_canUseScanner)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded),
              tooltip: 'Barkod Okut',
              onPressed: _showBarcodeScannerModal,
            ),
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Seçilenlerden Sipariş PDF Oluştur',
              onPressed: _selectedProductIds.isEmpty ? null : _generateOrderPdfFromSelected,
            ),
          IconButton(
            icon: Icon(_isSelectionMode ? Icons.check_box_outlined : Icons.check_box_outline_blank),
            tooltip: _isSelectionMode ? 'Seçimi Kapat' : 'Çoklu Seçim Modu',
            onPressed: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                if (!_isSelectionMode) _selectedProductIds.clear();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _loadAllData,
          ),
        ],
      ),
      floatingActionButton: _canManageStock
          ? FloatingActionButton.extended(
              onPressed: () => _showAddOrTrackStockModal(),
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
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Toplam Miktar',
                      value: '$totalUnits Adet',
                      icon: Icons.numbers_outlined,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Kritik Stok',
                      value: '${criticalStocks.length} Ürün',
                      icon: Icons.warning_amber_rounded,
                      color: criticalStocks.isNotEmpty ? Colors.orange : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Aktif Zimmetler',
                      value: '${_personnelLoans.length} Kayıt',
                      icon: Icons.badge_outlined,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 2. KONTROL & FİLTRELEME BARI
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: _activeTab == 2
                                ? 'Katalogda Ürün Kodu, İsim veya Marka Ara...'
                                : 'Depoda Ürün Kodu, İsim, Barkod veya Raf Ara...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  )
                                : null,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Kategori',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ),
                          items: ['Tümü', ...StockService.categories]
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedCategory = val!),
                        ),
                      ),
                    ],
                  ),
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
                    _buildTabChip(3, 'Personel Zimmetleri (${_personnelLoans.length})', Icons.badge),
                    const SizedBox(width: 8),
                    _buildTabChip(4, 'Stok Hareket Logları (${_stockMovements.length})', Icons.history),
                    const SizedBox(width: 8),
                    _buildTabChip(5, 'Eksik Malzemeli İşler (${_missingTickets.length})', Icons.assignment_late),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. İÇERİK TABLOSU (DATAGRID)
              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
              else ...[
                if (_activeTab == 0) _buildStockDataGrid(filteredStocks, showTrackButton: false),
                if (_activeTab == 1) _buildStockDataGrid(criticalStocks, showTrackButton: false),
                if (_activeTab == 2) _buildStockDataGrid(filteredStocks, showTrackButton: true),
                if (_activeTab == 3) _buildPersonnelLoansTable(),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
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
      avatar: Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey.shade700),
      label: Text(label),
      selected: isSelected,
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _activeTab = index;
            _onlyTracked = index != 2;
          });
          _loadStocks();
        }
      },
    );
  }

  // --- ELEKTRONİK TABLO (DATAGRID) ---

  Widget _buildStockDataGrid(List<Map<String, dynamic>> stocks, {required bool showTrackButton}) {
    if (stocks.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Kriterlere uygun stok veya katalog ürünü bulunamadı.')),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          columns: [
            if (_isSelectionMode) const DataColumn(label: Text('Seç')),
            const DataColumn(label: Text('Kod / ID')),
            const DataColumn(label: Text('Ürün Adı')),
            const DataColumn(label: Text('Kategori')),
            const DataColumn(label: Text('Marka / Model')),
            const DataColumn(label: Text('Stok Miktarı')),
            const DataColumn(label: Text('Min. Stok')),
            const DataColumn(label: Text('Raf / Kasa')),
            const DataColumn(label: Text('Barkod')),
            if (_canManageStock) const DataColumn(label: Text('İşlemler')),
          ],
          rows: stocks.map((item) {
            final id = item['id'].toString();
            final isSelected = _selectedProductIds.contains(id);
            final qty = _asInt(item['quantity']);
            final min = _asInt(item['critical_level']);
            final isTracked = item['stock_tracking_started'] == true || qty > 0;
            final isLow = isTracked && qty <= min;
            final isOut = isTracked && qty == 0;

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
                DataCell(Text(item['code'] ?? item['id'] ?? '-')),
                DataCell(
                  Text(
                    item['name'] ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(Chip(label: Text(item['category'] ?? 'Diğer'), visualDensity: VisualDensity.compact)),
                DataCell(Text('${item['brand'] ?? ''} ${item['model'] ?? ''}'.trim())),
                DataCell(
                  isTracked
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOut
                                ? Colors.red.shade100
                                : isLow
                                    ? Colors.amber.shade100
                                    : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$qty ${item['unit'] ?? 'Adet'}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isOut
                                  ? Colors.red.shade900
                                  : isLow
                                      ? Colors.amber.shade900
                                      : Colors.green.shade900,
                            ),
                          ),
                        )
                      : const Text('Takip Yok', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                ),
                DataCell(Text('$min ${item['unit'] ?? 'Adet'}')),
                DataCell(Text(item['shelf_location'] ?? '-')),
                DataCell(Text(item['barcode'] ?? '-')),
                if (_canManageStock)
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isTracked || showTrackButton)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            icon: const Icon(Icons.add_shopping_cart, size: 14),
                            label: const Text('Stoğa Al'),
                            onPressed: () => _showStartTrackingForCatalogItem(item),
                          )
                        else ...[
                          IconButton(
                            icon: const Icon(Icons.arrow_circle_down, color: Colors.green),
                            tooltip: 'Stok Girişi (IN)',
                            onPressed: () => _showStockMovementModal(item, 'in'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_circle_up, color: Colors.orange),
                            tooltip: 'Stok Çıkışı (OUT)',
                            onPressed: () => _showStockMovementModal(item, 'out'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.badge, color: Colors.blue),
                            tooltip: 'Personele Zimmetle',
                            onPressed: () => _showPersonnelLoanModal(item),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'edit') _showAddOrTrackStockModal(item);
                              if (val == 'delete') {
                                _stockService.deleteStock(item['id']);
                                _loadStocks();
                              }
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                              const PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: Colors.red))),
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
  }

  Widget _buildPersonnelLoansTable() {
    if (_personnelLoans.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Aktif personel zimmeti bulunmuyor.')),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.purple.shade50),
          columns: const [
            DataColumn(label: Text('Zimmetli Personel')),
            DataColumn(label: Text('Ürün Adı / Kod')),
            DataColumn(label: Text('Miktar')),
            DataColumn(label: Text('Veriliş Tarihi')),
            DataColumn(label: Text('Zimmet Notu')),
            DataColumn(label: Text('İşlem')),
          ],
          rows: _personnelLoans.map((loan) {
            final product = loan['inventory'] ?? {};
            return DataRow(
              cells: [
                DataCell(Text(loan['personnel_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text('${product['name'] ?? 'Bilinmeyen'} (${product['code'] ?? ''})')),
                DataCell(Text('${loan['quantity']} ${product['unit'] ?? 'Adet'}')),
                DataCell(Text(_formatDate(loan['borrowed_at']))),
                DataCell(Text(loan['note'] ?? '-')),
                DataCell(
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Zimmeti Kapat'),
                    onPressed: () => _showCloseLoanModal(loan),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMovementsTable() {
    if (_stockMovements.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Stok hareket kaydı bulunamadı.')),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
          columns: const [
            DataColumn(label: Text('Tarih')),
            DataColumn(label: Text('Ürün Adı')),
            DataColumn(label: Text('İşlem Tipi')),
            DataColumn(label: Text('Miktar')),
            DataColumn(label: Text('Önce / Sonra')),
            DataColumn(label: Text('Neden / Hedef')),
            DataColumn(label: Text('Açıklama')),
          ],
          rows: _stockMovements.map((mov) {
            final isIn = mov['movement_type'] == 'in';
            final product = mov['inventory'] ?? {};
            return DataRow(
              cells: [
                DataCell(Text(_formatDate(mov['created_at']))),
                DataCell(Text(product['name'] ?? '-')),
                DataCell(
                  Chip(
                    avatar: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward, size: 14, color: Colors.white),
                    label: Text(isIn ? 'Stok Girişi (IN)' : 'Stok Çıkışı (OUT)'),
                    backgroundColor: isIn ? Colors.green : Colors.orange,
                    labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                DataCell(Text('${mov['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text('${mov['quantity_before']} ➔ ${mov['quantity_after']}')),
                DataCell(Text('${mov['reason'] ?? ''} ${mov['destination'] ?? ''}'.trim())),
                DataCell(Text(mov['note'] ?? '-')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMissingTicketsTable() {
    if (_missingTickets.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Eksik malzemesi olan iş emri kaydı bulunmuyor.')),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.red.shade50),
          columns: const [
            DataColumn(label: Text('İş Kodu')),
            DataColumn(label: Text('İş Başlığı')),
            DataColumn(label: Text('Müşteri')),
            DataColumn(label: Text('Cihaz / Model')),
            DataColumn(label: Text('Eksik Malzeme Notu')),
            DataColumn(label: Text('İş Detayı')),
          ],
          rows: _missingTickets.map((t) {
            final customer = t['customers'];
            final custName = customer is Map ? customer['name'] : '-';
            return DataRow(
              cells: [
                DataCell(Text(t['job_code'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(t['title'] ?? '-')),
                DataCell(Text(custName)),
                DataCell(Text('${t['device_brand'] ?? ''} ${t['device_model'] ?? ''}'.trim())),
                DataCell(
                  Text(
                    t['missing_parts'] ?? '',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  IconButton(
                    icon: const Icon(Icons.open_in_new, color: Colors.blue),
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
  }
}

// --- DÜZELTİLMİŞ STOK KAYIT / KATALOGDAN STOĞA ALMA DİYALOĞU ---

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
          const Text('Stok Kaydı / Depoya Ürün Ekleme', style: TextStyle(fontWeight: FontWeight.bold)),
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
            backgroundColor: Theme.of(context).primaryColor,
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
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: () => _fetchCatalog(_catalogSearchCtrl.text),
            ),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (val) => _fetchCatalog(val),
        ),
        const SizedBox(height: 12),

        if (_loadingCatalog)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
        else if (_catalogProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Katalogda eşleşen ürün bulunamadı. "Sıfırdan Özel Ürün Ekle" sekmesini kullanabilirsiniz.'),
          )
        else
          Container(
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
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
                  selectedTileColor: Colors.blue.shade50,
                  title: Text(item['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
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
            color: Colors.blue.shade50,
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Seçilen Ürün: ${_selectedCatalogProduct!['name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
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
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
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
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
