import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/stock_service.dart';
import '../services/pdf_export_service.dart';
import 'pdf_viewer_page.dart';

class StockOverviewPage extends StatefulWidget {
  const StockOverviewPage({super.key});

  @override
  State<StockOverviewPage> createState() => _StockOverviewPageState();
}

class _StockOverviewPageState extends State<StockOverviewPage> with SingleTickerProviderStateMixin {
  final StockService _stockService = StockService();
  late TabController _tabController;
  
  List<Map<String, dynamic>> _allStocks = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Kategoriler servisten gelenden biraz farklı olabilir (UI için)
  final List<String> _uiCategories = ['Tümü', 'Sürücü', 'PLC', 'HMI', 'Şalt', 'Diğer'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _uiCategories.length, vsync: this);
    _loadStocks();
    
    // Tab değişince filtreyi tetikle (gerekirse)
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStocks() async {
    setState(() => _isLoading = true);
    try {
      final data = await _stockService.getStocks();
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

  List<Map<String, dynamic>> _getFilteredStocks() {
    // 1. Kategori Filtresi
    final currentTab = _uiCategories[_tabController.index];
    List<Map<String, dynamic>> list;
    
    if (currentTab == 'Tümü') {
      list = _allStocks;
    } else {
      list = _allStocks.where((s) {
        final cat = s['category'] as String? ?? 'Diğer';
        // "Diğer" sekmesi, ana kategoriler dışındakileri göstersin
        if (currentTab == 'Diğer') {
          return !['Sürücü', 'PLC', 'Şalt'].contains(cat);
        }
        return cat == currentTab;
      }).toList();
    }

    // 2. Arama Filtresi
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((s) {
        final name = (s['name'] as String).toLowerCase();
        final shelf = (s['shelf_location'] as String?)?.toLowerCase() ?? '';
        return name.contains(q) || shelf.contains(q);
      }).toList();
    }

    return list;
  }

  // --- AKILLI STOK EKLEME DIALOGLARI ---

  void _showAddSelectionDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ne eklemek istiyorsunuz?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.speed, color: Colors.blue),
              title: const Text('Sürücü (Hız Kontrol)'),
              onTap: () { Navigator.pop(ctx); _showSmartAddDialog('Sürücü'); },
            ),
            ListTile(
              leading: const Icon(Icons.memory, color: Colors.orange),
              title: const Text('PLC'),
              onTap: () { Navigator.pop(ctx); _showSmartAddDialog('PLC'); },
            ),
            ListTile(
              leading: const Icon(Icons.monitor, color: Colors.blueAccent),
              title: const Text('HMI Ekran'),
              onTap: () { Navigator.pop(ctx); _showSmartAddDialog('HMI'); },
            ),
            ListTile(
              leading: const Icon(Icons.electric_bolt, color: Colors.red),
              title: const Text('Şalt / Sigorta / Kontaktör'),
              onTap: () { Navigator.pop(ctx); _showSmartAddDialog('Şalt'); },
            ),
            ListTile(
              leading: const Icon(Icons.category, color: Colors.grey),
              title: const Text('Diğer Malzeme'),
              onTap: () { Navigator.pop(ctx); _showSmartAddDialog('Diğer'); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSmartAddDialog(String type, {Map<String, dynamic>? editItem}) async {
    final isEdit = editItem != null;
    final formKey = GlobalKey<FormState>();
    
    // Ortak alanlar
    final qtyCtrl = TextEditingController(text: editItem?['quantity']?.toString() ?? '0');
    final shelfCtrl = TextEditingController(text: editItem?['shelf_location']);
    final criticalCtrl = TextEditingController(text: editItem?['critical_level']?.toString() ?? '5');
    
    // Diğer/Manuel ekleme için isim alanı
    final manualNameCtrl = TextEditingController(text: editItem?['name']);

    // Seçimler
    String? selectedBrand;
    // HMI için
    double? selectedHmiSize;

    String? selectedModel;
    double? selectedKw;
    String selectedUnit = editItem?['unit'] ?? 'adet';

    // Düzenleme modundaysak, mevcut ismi parse etmeye çalışmak yerine manuel moda atabiliriz
    // Veya basitçe düzenlemede sadece miktar/raf güncellemeye izin verebiliriz.
    // Karmaşıklığı önlemek için: Düzenleme modu "Diğer" mantığında çalışsın, isim değiştirilebilsin.
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEdit ? 'Stok Düzenle' : '$type Ekle'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isEdit) ...[
                      // TİPE ÖZEL ALANLAR (SADECE YENİ EKLERKEN)
                      if (type == 'Sürücü') ...[
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Marka'),
                          items: StockService.driveBrands.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => selectedBrand = v),
                          validator: (v) => v == null ? 'Seçiniz' : null,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<double>(
                          decoration: const InputDecoration(labelText: 'Güç (kW)'),
                          items: StockService.kwValues.map((e) => DropdownMenuItem(value: e, child: Text('$e kW'))).toList(),
                          onChanged: (v) => setState(() => selectedKw = v),
                          validator: (v) => v == null ? 'Seçiniz' : null,
                        ),
                      ] else if (type == 'PLC') ...[
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Marka/Model'),
                          items: StockService.plcModels.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => selectedBrand = v), // PLC'de brand değişkenini model için kullanalım
                          validator: (v) => v == null ? 'Seçiniz' : null,
                        ),
                      ] else if (type == 'HMI') ...[
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Marka'),
                          items: StockService.hmiBrands.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setState(() => selectedBrand = v),
                          validator: (v) => v == null ? 'Seçiniz' : null,
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<double>(
                          decoration: const InputDecoration(labelText: 'Ekran Boyutu (inç)'),
                          items: StockService.hmiSizes.map((e) => DropdownMenuItem(value: e, child: Text('$e inç'))).toList(),
                          onChanged: (v) => setState(() => selectedHmiSize = v),
                          validator: (v) => v == null ? 'Seçiniz' : null,
                        ),
                      ] else ...[
                        // Şalt veya Diğer için manuel isim
                        TextFormField(
                          controller: manualNameCtrl,
                          decoration: const InputDecoration(labelText: 'Malzeme Adı'),
                          validator: (v) => v!.isEmpty ? 'Zorunlu' : null,
                        ),
                      ]
                    ] else ...[
                      // Düzenleme modunda isim textfield olarak gelir
                      TextFormField(
                        controller: manualNameCtrl,
                        decoration: const InputDecoration(labelText: 'Malzeme Adı'),
                        validator: (v) => v!.isEmpty ? 'Zorunlu' : null,
                      ),
                    ],

                    const SizedBox(height: 16),
                    // ORTAK ALANLAR
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: qtyCtrl,
                            decoration: const InputDecoration(labelText: 'Adet'),
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Zorunlu' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: shelfCtrl,
                            decoration: const InputDecoration(labelText: 'Raf Yeri'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                     TextFormField(
                        controller: criticalCtrl,
                        decoration: const InputDecoration(labelText: 'Kritik Seviye'),
                        keyboardType: TextInputType.number,
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    String finalName;
                    String category = type;

                    if (isEdit) {
                      finalName = manualNameCtrl.text.trim();
                      category = editItem['category'] ?? 'Diğer'; // Kategori değişmez
                    } else {
                      // OTOMATİK İSİM OLUŞTURMA
                      if (type == 'Sürücü') {
                        final kwStr = StockService.formatKw(selectedKw!);
                        finalName = '$selectedBrand $kwStr kW Sürücü';
                      } else if (type == 'PLC') {
                        finalName = '$selectedBrand PLC';
                      } else if (type == 'HMI') {
                         final inchStr = StockService.formatInch(selectedHmiSize!);
                         finalName = '$selectedBrand $inchStr inç HMI';
                      } else {
                        finalName = manualNameCtrl.text.trim();
                      }
                    }

                    final data = {
                      'name': finalName,
                      'category': category,
                      'quantity': int.parse(qtyCtrl.text),
                      'unit': selectedUnit,
                      'shelf_location': shelfCtrl.text.trim(),
                      'critical_level': int.parse(criticalCtrl.text),
                    };

                    if (isEdit) {
                      await _stockService.updateStock(editItem['id'], data);
                    } else {
                      await _stockService.addStock(data);
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      _loadStocks();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi')));
                    }
                  }
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteStock(int id) async {
     final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sil'),
        content: const Text('Silmek istediğine emin misin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _stockService.deleteStock(id);
      _loadStocks();
    }
  }

  Future<void> _handlePdfExport({
    required Future<Uint8List> Function() generator,
    required String baseName,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          title: baseName,
          pdfGenerator: generator,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredList = _getFilteredStocks();
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('STOK YÖNETİMİ'),
        leadingWidth: 40,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: SvgPicture.asset('assets/images/log.svg'),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _uiCategories.map((e) => Tab(text: e)).toList(),
          labelColor: theme.colorScheme.primary,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Stok Raporu',
            onPressed: () => _handlePdfExport(
              generator: PdfExportService.generateStockReportPdfBytes,
              baseName: 'Stok_Raporu_${DateTime.now().toIso8601String().substring(0, 10)}',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.assessment),
            tooltip: 'Yıllık Kullanım',
            onPressed: () => _handlePdfExport(
              generator: PdfExportService.generateAnnualUsageReportPdfBytes,
              baseName: 'Yillik_Kullanim_Raporu',
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStocks),
        ],
      ),
      body: Column(
        children: [
          Padding(
             padding: const EdgeInsets.all(12),
             child: TextField(
               decoration: InputDecoration(
                 hintText: 'Ara...',
                 prefixIcon: const Icon(Icons.search),
                 filled: true,
                 fillColor: theme.cardTheme.color,
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                 contentPadding: const EdgeInsets.symmetric(vertical: 0),
               ),
               onChanged: (v) => setState(() => _searchQuery = v),
             ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : filteredList.isEmpty 
                ? const Center(child: Text('Kayıt yok', style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 80, left: 12, right: 12),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      final qty = item['quantity'] as int? ?? 0;
                      final critical = item['critical_level'] as int? ?? 5;
                      final isLow = qty <= critical;
                      
                      return Card(
                        elevation: 0,
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isLow ? const BorderSide(color: Colors.red, width: 1) : BorderSide.none,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isLow ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                            child: Icon(
                              _getIconForCategory(item['category']),
                              color: isLow ? Colors.red : Colors.blue,
                              size: 20,
                            ),
                          ),
                          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: item['shelf_location'] != null 
                              ? Text('Raf: ${item['shelf_location']}', style: const TextStyle(fontSize: 12)) 
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$qty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isLow ? Colors.red : null)),
                              const SizedBox(width: 4),
                              Text(item['unit'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          onTap: () => _showSmartAddDialog('Diğer', editItem: item), // Düzenleme için
                          onLongPress: () => _deleteStock(item['id']),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSelectionDialog,
        icon: const Icon(Icons.add),
        label: const Text('STOK EKLE'),
      ),
    );
  }

  IconData _getIconForCategory(String? cat) {
    switch (cat) {
      case 'Sürücü': return Icons.speed;
      case 'PLC': return Icons.memory;
      case 'HMI': return Icons.monitor;
      case 'Şalt': return Icons.electric_bolt;
      default: return Icons.category;
    }
  }
}
