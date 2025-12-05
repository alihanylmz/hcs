  import 'package:flutter/material.dart';
  import 'dart:typed_data';
  import 'package:flutter_svg/flutter_svg.dart';
import '../services/stock_service.dart';
import '../services/pdf_export_service.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_colors.dart';
import 'pdf_viewer_page.dart';
import 'brand_models_settings_page.dart';

  class StockOverviewPage extends StatefulWidget {
    const StockOverviewPage({super.key});

    @override
    State<StockOverviewPage> createState() => _StockOverviewPageState();
  }

  class _StockOverviewPageState extends State<StockOverviewPage> {
    final StockService _stockService = StockService();
    final UserService _userService = UserService();
    
    List<Map<String, dynamic>> _allStocks = [];
    bool _isLoading = true;
    String _searchQuery = '';
    bool _isSelectionMode = false;
    Set<int> _selectedItems = {}; // Seçilen ürün ID'leri
    Map<int, int> _orderQuantities = {}; // Ürün ID -> Sipariş Adedi
    int _selectedIndex = 0; // Kategori seçimi için
    UserProfile? _userProfile; // Kullanıcı profili
    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

    // Kategoriler servisten gelenden biraz farklı olabilir (UI için)
    final List<String> _uiCategories = ['Tümü', 'Sürücü', 'PLC', 'HMI', 'Şalt', 'Diğer'];

    @override
    void initState() {
      super.initState();
      _loadUserProfile();
      _loadStocks();
    }

    Future<void> _loadUserProfile() async {
      final profile = await _userService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
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

    // Türkçe karakter desteği için normalize fonksiyonu
    // Tüm karakterleri (büyük/küçük, Türkçe/İngilizce) normalize eder
    String _normalizeTurkish(String text) {
      if (text.isEmpty) return '';
      
      // Her karakteri tek tek işle
      StringBuffer result = StringBuffer();
      
      for (int i = 0; i < text.length; i++) {
        final char = text[i];
        final codeUnit = char.codeUnitAt(0);
        
        // Türkçe büyük harfleri küçük harfe çevir
        switch (char) {
          case 'İ':
            result.write('i');
            break;
          case 'I':
            result.write('ı');
            break;
          case 'Ş':
            result.write('ş');
            break;
          case 'Ğ':
            result.write('ğ');
            break;
          case 'Ü':
            result.write('ü');
            break;
          case 'Ö':
            result.write('ö');
            break;
          case 'Ç':
            result.write('ç');
            break;
          default:
            // İngilizce büyük harfler (A-Z ama I hariç)
            if (codeUnit >= 65 && codeUnit <= 90 && codeUnit != 73) {
              result.write(String.fromCharCode(codeUnit + 32)); // ASCII: A=65, a=97
            } else {
              // Diğer tüm karakterleri olduğu gibi bırak (küçük harfler, rakamlar, özel karakterler)
              result.write(char);
            }
            break;
        }
      }
      
      return result.toString().trim();
    }

    List<Map<String, dynamic>> _getFilteredStocks() {
      // 1. Kategori Filtresi
      final currentTab = _uiCategories[_selectedIndex];
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

      // 2. Arama Filtresi (Türkçe karakter desteği ile)
      if (_searchQuery.trim().isNotEmpty) {
        final normalizedQuery = _normalizeTurkish(_searchQuery.trim());
        if (normalizedQuery.isNotEmpty) {
          list = list.where((s) {
            final name = _normalizeTurkish(s['name'] as String? ?? '');
            final shelf = _normalizeTurkish(s['shelf_location'] as String? ?? '');
            final category = _normalizeTurkish(s['category'] as String? ?? '');
            return name.contains(normalizedQuery) || 
                  shelf.contains(normalizedQuery) ||
                  category.contains(normalizedQuery);
          }).toList();
        }
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
      await showDialog(
        context: context,
        builder: (ctx) => StockFormDialog(
          type: type,
          editItem: editItem,
          onSave: (data, isEdit) async {
            try {
              if (isEdit) {
                await _stockService.updateStock(editItem!['id'], data);
              } else {
                await _stockService.addStock(data);
              }
              if (mounted) {
                _loadStocks();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kaydedildi'), backgroundColor: Colors.green),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
                );
              }
            }
          },
        ),
      );
    }

    Future<void> _deleteStock(int id) async {
      // Sadece admin ve yöneticiler silebilir
      if (!_userService.canDeleteStock(_userProfile)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu işlem için yetkiniz yok. Sadece yöneticiler stok silebilir.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stok Sil'),
          content: const Text('Bu stok kaydını silmek istediğinize emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      
      if (confirm == true && mounted) {
        try {
          await _stockService.deleteStock(id);
          if (mounted) {
            _loadStocks();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Stok başarıyla silindi'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Silme hatası: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
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
            pdfFileName: '$baseName.pdf',
            pdfGenerator: generator,
          ),
        ),
      );
    }

    Future<void> _handleItemSelection(Map<String, dynamic> item) async {
      if (!mounted) return;
      
      final itemId = item['id'] as int;
      
      if (_selectedItems.contains(itemId)) {
        // Zaten seçiliyse kaldır
        if (mounted) {
          setState(() {
            _selectedItems.remove(itemId);
            _orderQuantities.remove(itemId);
          });
        }
      } else {
        // Seçili değilse ekle ve adet sor
        final quantity = await _showQuantityDialog(item);
        if (mounted && quantity != null && quantity > 0) {
          setState(() {
            _selectedItems.add(itemId);
            _orderQuantities[itemId] = quantity;
          });
        }
      }
    }

    Future<int?> _showQuantityDialog(Map<String, dynamic> item) async {
      return await showDialog<int>(
        context: context,
        builder: (ctx) => StockOrderDialog(item: item),
      );
    }

    Future<void> _generateOrderListFromSelected() async {
      if (_selectedItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen en az bir ürün seçin')),
        );
        return;
      }

      // Seçilen ürünleri filtrele ve sipariş adetlerini ekle
      final selectedStocks = _allStocks
          .where((stock) => _selectedItems.contains(stock['id']))
          .map((stock) {
            final stockWithQty = Map<String, dynamic>.from(stock);
            stockWithQty['order_quantity'] = _orderQuantities[stock['id']] ?? 1;
            return stockWithQty;
          })
          .toList();

      await _handlePdfExport(
        generator: () => PdfExportService.generateOrderListPdfBytesFromList(selectedStocks),
        baseName: 'Siparis_Listesi_${DateTime.now().toIso8601String().substring(0, 10)}',
      );

      // Seçim modunu kapat
      setState(() {
        _isSelectionMode = false;
        _selectedItems.clear();
        _orderQuantities.clear();
      });
    }

    @override
    Widget build(BuildContext context) {
      // Partner kullanıcılar stok sayfasını hiç kullanamasın
      if (_userProfile?.role == 'partner_user') {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Stok Yönetimi'),
          ),
          body: const Center(
            child: Text(
              'Bu sayfaya erişim yetkiniz yok.',
              style: TextStyle(fontSize: 16),
            ),
          ),
        );
      }

      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      final filteredList = _getFilteredStocks();

      // Özet Bilgiler
      final totalStock = _allStocks.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 0));
      final lowStockCount = _allStocks.where((item) {
        final qty = item['quantity'] as int? ?? 0;
        final crit = item['critical_level'] as int? ?? 5;
        return qty <= crit;
      }).length;

      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: theme.scaffoldBackgroundColor,
        drawer: AppDrawer(
          currentPage: AppDrawerPage.stock,
          userName: _userProfile?.fullName,
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
              Padding(
                padding: const EdgeInsets.only(left: 0),
                child: SvgPicture.asset('assets/images/log.svg', width: 32, height: 32),
              ),
            ],
          ),
          title: Text(
            'Stok Yönetimi',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 24,
            ),
          ),
          actions: [
            // 1. Eğer seçim modundaysak sadece gerekli aksiyonlar görünsün
            if (_isSelectionMode) ...[
              IconButton(
                icon: const Icon(Icons.check_circle_outline_rounded),
                tooltip: 'Seçilenleri Sipariş Listesi Yap',
                color: theme.colorScheme.primary,
                onPressed: _selectedItems.isEmpty ? null : () => _generateOrderListFromSelected(),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Vazgeç',
                color: theme.colorScheme.error,
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedItems.clear();
                    _orderQuantities.clear();
                  });
                },
              ),
            ] else ...[
              // 2. Normal moddaysak sadece Yenile ve Menü butonu olsun
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: theme.iconTheme.color),
                onPressed: _loadStocks,
              ),
              
              // İŞTE O TEMİZ MENÜ (Popup Menu)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: theme.iconTheme.color),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                onSelected: (value) {
                  switch (value) {
                    case 'select':
                      setState(() {
                        _isSelectionMode = true;
                        _selectedItems.clear();
                        _orderQuantities.clear();
                      });
                      break;
                    case 'report_stock':
                      _handlePdfExport(
                        generator: PdfExportService.generateStockReportPdfBytes,
                        baseName: 'Stok_Raporu_${DateTime.now().toIso8601String().substring(0, 10)}',
                      );
                      break;
                    case 'report_annual':
                      _handlePdfExport(
                        generator: PdfExportService.generateAnnualUsageReportPdfBytes,
                        baseName: 'Yillik_Kullanim_Raporu',
                      );
                      break;
                    case 'brand_models':
                      if (_userProfile?.isAdmin == true) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BrandModelsSettingsPage()),
                        );
                      }
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'select',
                    child: Row(
                      children: [
                        Icon(Icons.checklist_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        const Text('Sipariş Listesi Oluştur'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'report_stock',
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf_rounded, color: theme.colorScheme.error),
                        const SizedBox(width: 12),
                        const Text('Stok Raporu Al'),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'report_annual',
                    child: Row(
                      children: [
                        Icon(Icons.insights_rounded, color: theme.colorScheme.secondary),
                        const SizedBox(width: 12),
                        const Text('Yıllık Kullanım'),
                      ],
                    ),
                  ),
                  if (_userProfile?.isAdmin == true) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'brand_models',
                      child: Row(
                        children: [
                          Icon(Icons.settings_applications_rounded, color: AppColors.corporateNavy),
                          const SizedBox(width: 12),
                          const Text('Marka Modelleri'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
        body: Column(
          children: [
            // 1. ÜST ÖZET KARTLARI (Dashboard Havası)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildSummaryCard(
                    'Toplam Ürün',
                    '$totalStock',
                    Icons.inventory_2_outlined,
                    theme.colorScheme.primary,
                    theme,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'Kritik Stok',
                    '$lowStockCount',
                    Icons.warning_amber_rounded,
                    theme.colorScheme.secondary,
                    theme,
                  ),
                ],
              ),
            ),

            // 2. ARAMA ÇUBUĞU (Daha yumuşak hatlı)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  enableSuggestions: true,
                  autocorrect: true,
                  decoration: InputDecoration(
                    hintText: 'Ürün, raf veya kategori ara...',
                    prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
              ),
            ),

            // 3. MODERN KATEGORİ SEÇİCİ (Chips)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: _uiCategories.asMap().entries.map((entry) {
                  final index = entry.key;
                  final label = entry.value;
                  final isSelected = _selectedIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? theme.colorScheme.primary 
                              : theme.cardTheme.color,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : theme.dividerTheme.color ?? Colors.grey.withOpacity(0.2),
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                              : [],
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected 
                                ? theme.colorScheme.onPrimary 
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // 4. LİSTE (Modern Kartlar)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text('Ürün bulunamadı', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final item = filteredList[index];
                            return _buildModernStockCard(item, theme);
                          },
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddSelectionDialog,
          backgroundColor: theme.colorScheme.primary,
          icon: Icon(Icons.add_rounded, color: theme.colorScheme.onPrimary),
          label: Text('Yeni Stok', style: TextStyle(color: theme.colorScheme.onPrimary)),
          elevation: 4,
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

    // Özet Bilgi Kartı
    Widget _buildSummaryCard(String title, String value, IconData icon, Color color, ThemeData theme) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    // MODERN ÜRÜN KARTI
    Widget _buildModernStockCard(Map<String, dynamic> item, ThemeData theme) {
      final qty = item['quantity'] as int? ?? 0;
      final critical = item['critical_level'] as int? ?? 5;
      final isLow = qty <= critical;
      
      // Doluluk oranı (Progress Bar için)
      // Eğer stok kritik seviyenin 3 katıysa bar dolu görünsün
      double progress = qty / (critical * 3);
      if (progress > 1.0) progress = 1.0;
      
      // Kategoriye göre ikon
      IconData catIcon = _getIconForCategory(item['category']);

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: isLow ? Border.all(color: theme.colorScheme.error.withOpacity(0.5), width: 1.5) : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _isSelectionMode
              ? () => _handleItemSelection(item)
              : () => _showSmartAddDialog('Diğer', editItem: item),
          onLongPress: _isSelectionMode || !_userService.canDeleteStock(_userProfile)
              ? null
              : () => _deleteStock(item['id']),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Sol Taraf: İkon Kutusu
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isLow ? theme.colorScheme.error.withOpacity(0.1) : theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: _isSelectionMode && _selectedItems.contains(item['id'])
                    ? Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 28)
                    : Icon(catIcon, color: isLow ? theme.colorScheme.error : theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 16),
                
                // Orta: Bilgiler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'],
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['shelf_location'] != null ? 'Raf: ${item['shelf_location']}' : 'Raf Yok',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      // Stok Durum Çubuğu (Mini Bar)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isLow ? theme.colorScheme.error : (progress > 0.5 ? Colors.green : theme.colorScheme.secondary),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),

                // Sağ Taraf: Miktar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$qty',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 22, 
                        fontWeight: FontWeight.w800,
                        color: isLow ? theme.colorScheme.error : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      item['unit'] ?? 'adet',
                      style: theme.textTheme.bodySmall,
                    ),
                    // Seçim modunda sipariş adedi badge'i
                    if (_isSelectionMode && _selectedItems.contains(item['id']) && _orderQuantities.containsKey(item['id']))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_orderQuantities[item['id']]}',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
  }

  // --- YARDIMCI DIALOG SINIFLARI ---

  class StockFormDialog extends StatefulWidget {
    final String type;
    final Map<String, dynamic>? editItem;
    final Function(Map<String, dynamic> data, bool isEdit) onSave;

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
    late TextEditingController _qtyCtrl;
    late TextEditingController _shelfCtrl;
    late TextEditingController _criticalCtrl;
    late TextEditingController _manualNameCtrl;

    String? _selectedBrand;
    String? _selectedModel; // Sürücü için alt model
    double? _selectedHmiSize;
    double? _selectedKw;
    late String _selectedUnit;
    List<String> _availableModels = []; // Seçili markanın alt modelleri
    List<String> _availableBrands = []; // Veritabanından gelen markalar (Sürücü için)
    final StockService _stockService = StockService();
    bool _loadingBrands = false;

    @override
    void initState() {
      super.initState();
      final item = widget.editItem;
      _qtyCtrl = TextEditingController(text: item?['quantity']?.toString() ?? '0');
      _shelfCtrl = TextEditingController(text: item?['shelf_location']);
      _criticalCtrl = TextEditingController(text: item?['critical_level']?.toString() ?? '5');
      _manualNameCtrl = TextEditingController(text: item?['name']);
      _selectedUnit = item?['unit'] ?? 'adet';
      
      // Veritabanından markaları yükle (Sürücü, PLC, HMI için)
      if ((widget.type == 'Sürücü' || widget.type == 'PLC' || widget.type == 'HMI') && widget.editItem == null) {
        _loadBrands();
      }
    }
    
    Future<void> _loadBrands() async {
      setState(() => _loadingBrands = true);
      try {
        final brands = await _stockService.getBrandsByCategory(widget.type);
        
        if (mounted) {
          setState(() {
            _availableBrands = brands; // Sadece veritabanından gelenleri kullan
            _loadingBrands = false;
          });
        }
      } catch (e) {
        // Hata durumunda boş liste veya varsayılanlar?
        // Kullanıcı silinebilir olmasını istediği için boş liste dönmek daha mantıklı.
        // Ama hata varsa belki de ağ hatasıdır.
        if (mounted) {
          setState(() {
             // Hata durumunda ne yapılacağına karar verilebilir
             // Şimdilik boş bırakalım, kullanıcı manuel ekleyebilir
            _availableBrands = [];
            _loadingBrands = false;
          });
        }
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
        title: Text(isEdit ? 'Stok Düzenle' : '${widget.type} Ekle'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isEdit) ...[
                if (widget.type == 'Sürücü') ...[
                  if (_loadingBrands)
                    const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                  else
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Marka'),
                        items: (_availableBrands.isEmpty 
                            ? const ['Diğer'] 
                            : _availableBrands)
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) async {
                        if (mounted) {
                          setState(() {
                            _selectedBrand = v;
                            _selectedModel = null; // Marka değişince modeli sıfırla
                            _availableModels = [];
                          });
                          
                          // Marka seçildiğinde alt modelleri yükle
                          if (v != null && v != 'Diğer') {
                            final models = await _stockService.getBrandModels(v, 'Sürücü');
                            if (mounted) {
                              setState(() {
                                _availableModels = models;
                              });
                            }
                          }
                        }
                      },
                      validator: (v) => v == null ? 'Seçiniz' : null,
                    ),
                  // Alt model seçimi (sadece modeller varsa göster)
                  if (_selectedBrand != null && _selectedBrand != 'Diğer' && _availableModels.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Model'),
                      items: _availableModels.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) {
                        if (mounted) setState(() => _selectedModel = v);
                      },
                      validator: (v) => v == null ? 'Seçiniz' : null,
                    ),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<double>(
                    decoration: const InputDecoration(labelText: 'Güç (kW)'),
                    items: StockService.kwValues.map((e) => DropdownMenuItem(value: e, child: Text('$e kW'))).toList(),
                    onChanged: (v) {
                      if (mounted) setState(() => _selectedKw = v);
                    },
                    validator: (v) => v == null ? 'Seçiniz' : null,
                  ),
                ] else if (widget.type == 'PLC') ...[
                    if (_loadingBrands)
                      const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                    else
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Marka'),
                        items: (_availableBrands.isEmpty 
                            ? StockService.plcModels 
                            : _availableBrands)
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) async {
                          if (mounted) {
                            setState(() {
                              _selectedBrand = v;
                              _selectedModel = null;
                              _availableModels = [];
                            });
                            
                            // Marka seçildiğinde alt modelleri yükle
                            if (v != null && v != 'Diğer') {
                              final models = await _stockService.getBrandModels(v, 'PLC');
                              if (mounted) {
                                setState(() {
                                  _availableModels = models;
                                });
                              }
                            }
                          }
                        },
                        validator: (v) => v == null ? 'Seçiniz' : null,
                      ),
                    // Alt model seçimi
                    if (_selectedBrand != null && _selectedBrand != 'Diğer' && _availableModels.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Model'),
                        items: _availableModels.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) {
                          if (mounted) setState(() => _selectedModel = v);
                        },
                        validator: (v) => v == null ? 'Seçiniz' : null,
                      ),
                    ],
                  ] else if (widget.type == 'HMI') ...[
                    if (_loadingBrands)
                      const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                    else
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Marka'),
                        items: (_availableBrands.isEmpty 
                            ? StockService.hmiBrands 
                            : _availableBrands)
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) async {
                          if (mounted) {
                            setState(() {
                              _selectedBrand = v;
                              _selectedModel = null;
                              _availableModels = [];
                            });
                            
                            // Marka seçildiğinde alt modelleri yükle
                            if (v != null && v != 'Diğer') {
                              final models = await _stockService.getBrandModels(v, 'HMI');
                              if (mounted) {
                                setState(() {
                                  _availableModels = models;
                                });
                              }
                            }
                          }
                        },
                        validator: (v) => v == null ? 'Seçiniz' : null,
                      ),
                    // Alt model seçimi
                    if (_selectedBrand != null && _selectedBrand != 'Diğer' && _availableModels.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Model'),
                        items: _availableModels.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (v) {
                          if (mounted) setState(() => _selectedModel = v);
                        },
                        validator: (v) => v == null ? 'Seçiniz' : null,
                      ),
                    ],
                    const SizedBox(height: 10),
                    DropdownButtonFormField<double>(
                      decoration: const InputDecoration(labelText: 'Ekran Boyutu (inç)'),
                      items: StockService.hmiSizes.map((e) => DropdownMenuItem(value: e, child: Text('$e inç'))).toList(),
                      onChanged: (v) {
                        if (mounted) setState(() => _selectedHmiSize = v);
                      },
                      validator: (v) => v == null ? 'Seçiniz' : null,
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _manualNameCtrl,
                      decoration: const InputDecoration(labelText: 'Malzeme Adı'),
                      validator: (v) => v!.isEmpty ? 'Zorunlu' : null,
                    ),
                  ]
                ] else ...[
                  TextFormField(
                    controller: _manualNameCtrl,
                    decoration: const InputDecoration(labelText: 'Malzeme Adı'),
                    validator: (v) => v!.isEmpty ? 'Zorunlu' : null,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qtyCtrl,
                        decoration: const InputDecoration(labelText: 'Adet'),
                        keyboardType: TextInputType.number,
                        validator: (v) => v!.isEmpty ? 'Zorunlu' : null,
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
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Zorunlu';
                    final num = int.tryParse(v);
                    if (num == null || num < 0) return 'Geçerli bir sayı girin';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) Navigator.pop(context);
            },
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;

              String finalName;
              String category = widget.type;

              if (isEdit) {
                finalName = _manualNameCtrl.text.trim();
                category = widget.editItem!['category'] ?? 'Diğer';
              } else {
              if (widget.type == 'Sürücü') {
                if (_selectedKw == null || _selectedBrand == null) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lütfen tüm alanları doldurun')),
                    );
                  }
                  return;
                }
                // Model varsa: "Marka Model kW Sürücü", yoksa: "Marka kW Sürücü"
                final kwStr = StockService.formatKw(_selectedKw!);
                if (_selectedModel != null && _selectedModel!.isNotEmpty) {
                  finalName = '$_selectedBrand $_selectedModel $kwStr kW Sürücü';
                } else {
                  finalName = '$_selectedBrand $kwStr kW Sürücü';
                }
                } else if (widget.type == 'PLC') {
                  if (_selectedBrand == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lütfen marka seçin')),
                      );
                    }
                    return;
                  }
                  if (_selectedModel != null && _selectedModel!.isNotEmpty) {
                    finalName = '$_selectedBrand $_selectedModel PLC';
                  } else {
                    finalName = '$_selectedBrand PLC';
                  }
                } else if (widget.type == 'HMI') {
                  if (_selectedHmiSize == null || _selectedBrand == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lütfen tüm alanları doldurun')),
                      );
                    }
                    return;
                  }
                  final inchStr = StockService.formatInch(_selectedHmiSize!);
                  if (_selectedModel != null && _selectedModel!.isNotEmpty) {
                    finalName = '$_selectedBrand $_selectedModel $inchStr inç HMI';
                  } else {
                    finalName = '$_selectedBrand $inchStr inç HMI';
                  }
                } else {
                  finalName = _manualNameCtrl.text.trim();
                  if (finalName.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Malzeme adı zorunludur')),
                      );
                    }
                    return;
                  }
                }
              }

              // Adet ve kritik seviye parse kontrolü
              final qty = int.tryParse(_qtyCtrl.text.trim());
              final critical = int.tryParse(_criticalCtrl.text.trim());
              
              if (qty == null || qty < 0) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Geçerli bir adet girin')),
                  );
                }
                return;
              }
              
              if (critical == null || critical < 0) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Geçerli bir kritik seviye girin')),
                  );
                }
                return;
              }

              final data = {
                'name': finalName,
                'category': category,
                'quantity': qty,
                'unit': _selectedUnit,
                'shelf_location': _shelfCtrl.text.trim().isEmpty ? null : _shelfCtrl.text.trim(),
                'critical_level': critical,
              };

              widget.onSave(data, isEdit);
              if (mounted) {
                Navigator.pop(context); // Dialog'u kapat
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      );
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
        title: const Text('Sipariş Adedi', style: TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item['name'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Text('Mevcut: $currentQty ${widget.item['unit'] ?? 'adet'}'),
              Text('Kritik Seviye: $critical ${widget.item['unit'] ?? 'adet'}'),
              const SizedBox(height: 16),
              TextField(
                controller: _qtyController,
                decoration: const InputDecoration(
                  labelText: 'Sipariş Adedi',
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
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(_qtyController.text);
              if (qty != null && qty > 0) {
                if (mounted) {
                  Navigator.pop(context, qty);
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Geçerli bir adet girin')),
                  );
                }
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      );
    }
  }
