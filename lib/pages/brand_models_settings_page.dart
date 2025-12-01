import 'package:flutter/material.dart';
import '../services/stock_service.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_header.dart';

class BrandModelsSettingsPage extends StatefulWidget {
  const BrandModelsSettingsPage({super.key});

  @override
  State<BrandModelsSettingsPage> createState() => _BrandModelsSettingsPageState();
}

class _BrandModelsSettingsPageState extends State<BrandModelsSettingsPage> {
  final StockService _stockService = StockService();
  final UserService _userService = UserService();
  
  Map<String, List<String>> _brandsByCategory = {}; // category -> [brands]
  List<Map<String, dynamic>> _brandModels = [];
  bool _isLoading = true;
  UserProfile? _userProfile;
  String _selectedCategory = 'Sürücü'; // Varsayılan kategori

  final List<String> _categories = ['Sürücü', 'PLC', 'HMI'];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadData();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userService.getCurrentUserProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final brands = await _stockService.getAllBrands();
      final models = await _stockService.getAllBrandModels();
      
      // Sabit listeleri de ekle (geriye dönük uyumluluk için)
      if (!brands.containsKey('Sürücü')) {
        brands['Sürücü'] = [];
      }
      // Sabit listedeki markaları ekle (veritabanında yoksa)
      for (var brand in StockService.driveBrands) {
        if (brand != 'Diğer' && !brands['Sürücü']!.contains(brand)) {
          brands['Sürücü']!.add(brand);
        }
      }
      
      if (!brands.containsKey('PLC')) {
        brands['PLC'] = [];
      }
      for (var brand in StockService.plcModels) {
        if (brand != 'Diğer' && !brands['PLC']!.contains(brand)) {
          brands['PLC']!.add(brand);
        }
      }
      
      if (!brands.containsKey('HMI')) {
        brands['HMI'] = [];
      }
      for (var brand in StockService.hmiBrands) {
        if (brand != 'Diğer' && !brands['HMI']!.contains(brand)) {
          brands['HMI']!.add(brand);
        }
      }
      
      // Alfabetik sırala
      brands.forEach((key, value) {
        value.sort();
      });
      
      if (mounted) {
        setState(() {
          _brandsByCategory = brands;
          _brandModels = models;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAddBrandDialog() async {
    final brandController = TextEditingController();
    String tempCategory = _selectedCategory;
    List<String> existingBrands = _brandsByCategory[tempCategory] ?? [];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Yeni Marka Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Kategori'),
                value: tempCategory,
                items: _categories.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) {
                  setState(() {
                    tempCategory = v ?? 'Sürücü';
                    existingBrands = _brandsByCategory[tempCategory] ?? [];
                  });
                },
              ),
              const SizedBox(height: 16),
              if (existingBrands.isNotEmpty) ...[
                Text(
                  'Mevcut Markalar: ${existingBrands.join(", ")}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: brandController,
                decoration: const InputDecoration(
                  labelText: 'Marka Adı',
                  hintText: 'Örn: GMT, Danfoss, ABB',
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (brandController.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );

    if (result == true && brandController.text.trim().isNotEmpty) {
      try {
        await _stockService.addBrand(brandController.text.trim(), tempCategory);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Marka başarıyla eklendi'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteBrand(String brandName, String category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Markayı Sil'),
        content: Text('$category - $brandName markasını ve tüm modellerini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _stockService.deleteBrand(brandName, category);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Marka silindi'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showAddModelDialog(String brandName, String category) async {
    final modelController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$brandName - Yeni Model Ekle'),
        content: TextField(
          controller: modelController,
          decoration: const InputDecoration(
            labelText: 'Model Adı',
            hintText: 'Örn: GAİN, FC51, İC2',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (modelController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (result == true && modelController.text.trim().isNotEmpty) {
      try {
        await _stockService.addBrandModel(brandName, modelController.text.trim(), category);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Model başarıyla eklendi'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteModel(int id, String brandName, String modelName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modeli Sil'),
        content: Text('$brandName - $modelName modelini silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _stockService.deleteBrandModel(id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Model silindi'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Admin kontrolü
    if (_userProfile?.isAdmin != true) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Bu sayfaya erişim yetkiniz yok', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : AppColors.backgroundGrey;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    // Kategoriye göre markaları filtrele
    final currentBrands = _brandsByCategory[_selectedCategory] ?? [];

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          const CustomHeader(
            title: 'Marka Modelleri',
            subtitle: 'Marka ve modelleri yönetin',
            showBackArrow: true,
          ),
          
          // Kategori Seçimi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: cardColor,
            child: Row(
              children: [
                const Text('Kategori: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Expanded(
                  child: SegmentedButton<String>(
                    segments: _categories.map((e) => ButtonSegment(value: e, label: Text(e))).toList(),
                    selected: {_selectedCategory},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedCategory = newSelection.first;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.corporateNavy))
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppColors.corporateNavy,
                    child: currentBrands.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text('$_selectedCategory kategorisinde henüz marka eklenmemiş', style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: currentBrands.length,
                            itemBuilder: (context, index) {
                              final brand = currentBrands[index];
                              // Bu markanın modellerini filtrele
                              final models = _brandModels
                                  .where((m) => m['brand_name'] == brand && m['category'] == _selectedCategory)
                                  .toList();

                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ExpansionTile(
                                  leading: const Icon(Icons.branding_watermark, color: AppColors.corporateNavy),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          brand,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                        onPressed: () => _deleteBrand(brand, _selectedCategory),
                                        tooltip: 'Markayı Sil',
                                      ),
                                    ],
                                  ),
                                  subtitle: Text('${models.length} model'),
                                  children: [
                                    ...models.map((model) {
                                      final modelName = model['model_name'] as String;
                                      final modelId = model['id'] as int;

                                      return ListTile(
                                        title: Text(modelName),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () => _deleteModel(modelId, brand, modelName),
                                        ),
                                      );
                                    }),
                                    ListTile(
                                      leading: const Icon(Icons.add, color: AppColors.corporateNavy),
                                      title: const Text('Yeni Model Ekle', style: TextStyle(color: AppColors.corporateNavy)),
                                      onTap: () => _showAddModelDialog(brand, _selectedCategory),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
          ),
          // Alt butonlar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showAddBrandDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Yeni Marka Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.corporateNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
