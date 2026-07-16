import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/product_spec_templates.dart';
import '../models/product.dart';
import '../services/product_image_service.dart';
import '../services/product_repository.dart';
import '../widgets/product_preview_image.dart';
import '../widgets/workspace_background.dart';

/// Stok urununun detay sayfasi. Varsayilan olarak okunabilir duzende
/// butun alanlar bir arada gorulur; sag ustteki "Duzenle" butonuna basinca
/// TextField'lara donusur, "Kaydet" Supabase'e yazar ve ana sayfaya
/// guncellenmis urunu geri doner.
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.product,
    required this.productRepository,
    this.startInEditMode = false,
  });

  final Product product;
  final ProductRepository productRepository;
  final bool startInEditMode;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  static const _ink = Color(0xFF17304C);
  static const _slate = Color(0xFF5B6F7F);
  static const _accent = Color(0xFFB8843C);

  final _formKey = GlobalKey<FormState>();
  final _imageService = const ProductImageService();

  late Product _current;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isPickingImage = false;

  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _currencyCtrl;
  late final TextEditingController _salePriceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _minStockCtrl;
  late final TextEditingController _vatCtrl;
  late final TextEditingController _leadTimeCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _technicalSummaryCtrl;
  String _activeSpecCategory = '';

  /// Kategoriye gore sablondaki her `SpecField.key` icin bir controller.
  /// Sablon disindaki anahtarlar (kategori degisince) bu map'te tutulmaz;
  /// ancak yine de `_current.specifications` icinde saklanir ve bir sonraki
  /// uygun kategoriye gecildiginde tekrar gosterilir.
  final Map<String, TextEditingController> _specCtrls = {};

  @override
  void initState() {
    super.initState();
    _current = widget.product;
    _isEditing = widget.startInEditMode;
    _codeCtrl = TextEditingController(text: _current.code);
    _nameCtrl = TextEditingController(text: _current.name);
    _categoryCtrl = TextEditingController(text: _current.category);
    _brandCtrl = TextEditingController(text: _current.brand);
    _modelCtrl = TextEditingController(text: _current.model);
    _unitCtrl = TextEditingController(text: _current.unit);
    _currencyCtrl = TextEditingController(text: _current.currencyCode);
    _salePriceCtrl = TextEditingController(
      text: _current.salePrice.toStringAsFixed(2),
    );
    _stockCtrl = TextEditingController(
      text: _formatNumber(_current.stockQuantity),
    );
    _minStockCtrl = TextEditingController(
      text: _formatNumber(_current.minimumStock),
    );
    _vatCtrl = TextEditingController(text: _formatNumber(_current.vatRate));
    _leadTimeCtrl = TextEditingController(text: _current.leadTime);
    _descriptionCtrl = TextEditingController(text: _current.description);
    _technicalSummaryCtrl = TextEditingController(
      text: _current.technicalSummary,
    );
    _categoryCtrl.addListener(_handleCategoryChanged);
    _rebuildSpecControllers();
  }

  /// Mevcut kategoriye uygun sablondaki her alan icin bir
  /// `TextEditingController` olusturur. `_current.specifications`'tan
  /// mevcut degerleri yukler. Kategori degistiginde yeniden cagirilir.
  void _handleCategoryChanged() {
    final nextCategory = _categoryCtrl.text.trim();
    if (nextCategory == _activeSpecCategory) return;
    final values = _currentSpecValues();
    _rebuildSpecControllers(values: values);
    if (mounted) setState(() {});
  }

  Map<String, String> _currentSpecValues() {
    final values = <String, String>{..._current.specifications};
    for (final entry in _specCtrls.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        values.remove(entry.key);
      } else {
        values[entry.key] = value;
      }
    }
    return values;
  }

  void _rebuildSpecControllers({Map<String, String>? values}) {
    for (final controller in _specCtrls.values) {
      controller.dispose();
    }
    _specCtrls.clear();
    _activeSpecCategory = _categoryCtrl.text.trim();

    final template = ProductSpecTemplates.findForCategory(_categoryCtrl.text);
    if (template == null) return;

    final source = values ?? _current.specifications;
    for (final group in template.groups) {
      for (final field in group.fields) {
        _specCtrls[field.key] = TextEditingController(
          text: source[field.key] ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    _categoryCtrl.removeListener(_handleCategoryChanged);
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _unitCtrl.dispose();
    _currencyCtrl.dispose();
    _salePriceCtrl.dispose();
    _stockCtrl.dispose();
    _minStockCtrl.dispose();
    _vatCtrl.dispose();
    _leadTimeCtrl.dispose();
    _descriptionCtrl.dispose();
    _technicalSummaryCtrl.dispose();
    for (final controller in _specCtrls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _formatNumber(double value) {
    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  static String _generateProductCode(String name) {
    final cleaned = name
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final prefix = cleaned.isEmpty
        ? 'URUN'
        : cleaned.length > 12
        ? cleaned.substring(0, 12)
        : cleaned;
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    return '$prefix-${stamp.substring(stamp.length - 8)}';
  }

  static String _normalizeCurrency(String raw) {
    final value = raw.trim().toUpperCase();
    if (value == 'USD' || value == 'USDTRY') return 'USDTRY';
    if (value == 'EUR' || value == 'EURTRY') return 'EURTRY';
    return 'TL';
  }

  static const _currencyStorageValues = ['TL', 'USDTRY', 'EURTRY'];

  String _currencyStorageFromCtrl() =>
      _normalizeCurrency(_currencyCtrl.text);

  String _currencyMenuLabel(String storage) {
    switch (storage) {
      case 'USDTRY':
        return 'USD';
      case 'EURTRY':
        return 'EURO';
      default:
        return 'TL';
    }
  }

  List<String> _categoryMenuChoices() {
    final labels = List<String>.from(ProductSpecTemplates.presetCategoryLabels);
    final cur = _categoryCtrl.text.trim();
    if (cur.isNotEmpty && !labels.contains(cur)) {
      labels.insert(1, cur);
    }
    return labels;
  }

  String _effectiveCategoryDropdownValue(List<String> choices) {
    final cur = _categoryCtrl.text.trim();
    if (choices.contains(cur)) return cur;
    if (choices.contains('Genel')) return 'Genel';
    return choices.first;
  }

  /// Etiket + sagda `child` (metin veya form alani).
  Widget _labeledValueRow({
    required String label,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 520;
          final labelWidth = isWide ? 180.0 : 140.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Padding(
                  padding: EdgeInsets.only(top: _isEditing ? 14 : 2),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _slate,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }

  Widget _categoryPickerRow() {
    final choices = _categoryMenuChoices();
    if (_isEditing) {
      return _labeledValueRow(
        label: 'Kategori',
        child: InputDecorator(
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              borderRadius: BorderRadius.circular(16),
              value: _effectiveCategoryDropdownValue(choices),
              items: choices
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e,
                      child: Text(e, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _categoryCtrl.text = v);
              },
            ),
          ),
        ),
      );
    }
    final text = _categoryCtrl.text.trim();
    return _labeledValueRow(
      label: 'Kategori',
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          text.isEmpty ? '-' : text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: text.isEmpty ? _slate : _ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _currencyPickerRow() {
    if (_isEditing) {
      final storage = _currencyStorageValues.contains(_currencyStorageFromCtrl())
          ? _currencyStorageFromCtrl()
          : 'TL';
      return _labeledValueRow(
        label: 'Para Birimi',
        child: InputDecorator(
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              borderRadius: BorderRadius.circular(16),
              value: storage,
              items: _currencyStorageValues
                  .map(
                    (code) => DropdownMenuItem<String>(
                      value: code,
                      child: Text(_currencyMenuLabel(code)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() => _currencyCtrl.text = v);
              },
            ),
          ),
        ),
      );
    }
    return _labeledValueRow(
      label: 'Para Birimi',
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          _currencyMenuLabel(_currencyStorageFromCtrl()),
          style: const TextStyle(
            color: _ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Form alanlarinda hata var. Kirmizi kutulari kontrol edin.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Sablondan gelen alanlari `specifications` map'ine yaz; kategorinin
      // sablonunda yer almayan eski anahtarlari koru (kategori degisse de
      // daha once girilmis deger kaybolmasin).
      final nextSpecs = _currentSpecValues();
      final name = _nameCtrl.text.trim();
      final code = _codeCtrl.text.trim().isEmpty
          ? _generateProductCode(name)
          : _codeCtrl.text.trim();

      final updated = Product(
        id: _current.id,
        code: code,
        name: name,
        category: _categoryCtrl.text.trim(),
        brand: _brandCtrl.text.trim(),
        model: _modelCtrl.text.trim(),
        unit: _unitCtrl.text.trim().isEmpty ? 'adet' : _unitCtrl.text.trim(),
        currencyCode: _normalizeCurrency(_currencyCtrl.text),
        salePrice: _parseDouble(_salePriceCtrl.text),
        stockQuantity: _parseDouble(_stockCtrl.text),
        minimumStock: _parseDouble(_minStockCtrl.text),
        vatRate: _parseDouble(_vatCtrl.text, fallback: 20),
        leadTime: _leadTimeCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        technicalSummary: _technicalSummaryCtrl.text.trim(),
        isActive: _current.isActive,
        updatedAt: DateTime.now(),
        imagePath: _current.imagePath,
        specifications: nextSpecs,
      );

      await widget.productRepository.saveProduct(updated);
      if (!mounted) return;

      setState(() {
        _current = updated;
        _codeCtrl.text = updated.code;
        _isEditing = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Urun guncellendi.')));
    } catch (error, stackTrace) {
      debugPrint('Product save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kaydedilemedi: $error')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static double _parseDouble(String raw, {double fallback = 0}) {
    final cleaned = raw.trim().replaceAll(',', '.');
    return double.tryParse(cleaned) ?? fallback;
  }

  /// Resim secme + kaydetme akisi. Basarili ise urun kaydini guncellenmis
  /// `imagePath` ile Supabase'e yazar; kullanici iptal ederse hicbir sey
  /// yapmaz.
  Future<void> _pickImage() async {
    if (_isPickingImage || _isSaving) return;
    setState(() => _isPickingImage = true);
    try {
      final newPath = await _imageService.pickAndStore(
        productId: _current.id,
        replacing: _current.imagePath,
        supabase: Supabase.instance.client,
      );
      if (newPath == null || !mounted) return;

      final updated = _current.copyWithImage(newPath);
      await widget.productRepository.saveProduct(updated);
      if (!mounted) return;
      setState(() => _current = updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Urun resmi guncellendi.')));
    } catch (error, stackTrace) {
      debugPrint('Image pick failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Resim eklenemedi: $error')));
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _removeImage() async {
    if (_current.imagePath.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resmi kaldir?'),
        content: const Text(
          'Urun resmini kalidirmak istediginize emin misiniz? '
          'Dosya silinecek; istediginizde yeniden yukleyebilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9D3418),
              foregroundColor: Colors.white,
            ),
            child: const Text('Kaldir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final oldPath = _current.imagePath;
    try {
      final updated = _current.copyWithImage('');
      await widget.productRepository.saveProduct(updated);
      if (!mounted) return;
      setState(() => _current = updated);
      await _imageService.remove(
        oldPath,
        supabase: Supabase.instance.client,
        productId: _current.id,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Urun resmi kaldirildi.')));
    } catch (error, stackTrace) {
      debugPrint('Image remove failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Resim silinemedi: $error')));
      }
    }
  }

  void _cancelEditing() {
    _codeCtrl.text = _current.code;
    _nameCtrl.text = _current.name;
    _categoryCtrl.text = _current.category;
    _brandCtrl.text = _current.brand;
    _modelCtrl.text = _current.model;
    _unitCtrl.text = _current.unit;
    _currencyCtrl.text = _current.currencyCode;
    _salePriceCtrl.text = _current.salePrice.toStringAsFixed(2);
    _stockCtrl.text = _formatNumber(_current.stockQuantity);
    _minStockCtrl.text = _formatNumber(_current.minimumStock);
    _vatCtrl.text = _formatNumber(_current.vatRate);
    _leadTimeCtrl.text = _current.leadTime;
    _descriptionCtrl.text = _current.description;
    _technicalSummaryCtrl.text = _current.technicalSummary;
    _rebuildSpecControllers();
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_current.code.trim().isEmpty ? 'Yeni Urun' : _current.code),
        actions: [
          if (!_isEditing)
            FilledButton.tonalIcon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Duzenle'),
            )
          else ...[
            TextButton(
              onPressed: _isSaving ? null : _cancelEditing,
              child: const Text('Vazgec'),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveChanges,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Kaydet'),
            ),
          ],
          const SizedBox(width: 16),
        ],
      ),
      body: WorkspaceBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 12),
                    _buildDatasheetCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final statusColor = _current.isLowStock
        ? const Color(0xFF9D5C1D)
        : const Color(0xFF2C6957);
    final statusBg = _current.isLowStock
        ? const Color(0xFFFFE7D1)
        : const Color(0xFFE5F1EC);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildImageBlock(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _current.code,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _slate,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _current.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_current.brand} - ${_current.model}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _slate,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _isPickingImage || _isSaving
                            ? null
                            : _pickImage,
                        icon: _isPickingImage
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                _current.imagePath.isEmpty
                                    ? Icons.add_photo_alternate_rounded
                                    : Icons.image_rounded,
                                size: 16,
                              ),
                        label: Text(
                          _current.imagePath.isEmpty
                              ? 'Resim Ekle'
                              : 'Resmi Degistir',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      if (_current.imagePath.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: _isPickingImage || _isSaving
                              ? null
                              : _removeImage,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                          ),
                          label: const Text('Kaldir'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF9D5C1D),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: const Size(0, 36),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _current.isLowStock ? 'KRITIK STOK' : 'NORMAL',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openImageViewer() {
    final path = _current.imagePath.trim();
    if (path.isEmpty) return;
    final remote = ProductPreviewImage.isRemotePath(path);
    if (!remote) {
      final file = File(path);
      if (!file.existsSync()) return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) {
        final pad = MediaQuery.paddingOf(ctx);
        final size = MediaQuery.sizeOf(ctx);
        final viewW = size.width;
        final viewH = size.height - pad.top - pad.bottom;

        final imageChild = remote
            ? Image.network(
                path,
                fit: BoxFit.contain,
                width: viewW - 24,
                height: viewH - 76,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Resim acilamadi.\n$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                },
              )
            : Image.file(
                File(path),
                fit: BoxFit.contain,
                width: viewW - 24,
                height: viewH - 76,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Resim acilamadi.\n$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                },
              );

        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, pad.top + 52, 12, 24),
                  child: InteractiveViewer(
                    minScale: 0.4,
                    maxScale: 5,
                    boundaryMargin: const EdgeInsets.all(160),
                    clipBehavior: Clip.none,
                    child: Center(
                      child: imageChild,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: pad.top + 6,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Yakinlastirmak icin pinch; surukleyerek gezin.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.92),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Kapat',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Header icindeki 96x96 kare resim onizlemesi. Resim yoksa placeholder
  /// (paket ikonu + "Resim Yok" label), varsa yerel dosya veya Supabase URL.
  /// Resme dokununca tam ekran inceleme acilir.
  Widget _buildImageBlock() {
    final path = _current.imagePath.trim();
    final hasImage = path.isNotEmpty;
    final remote = ProductPreviewImage.isRemotePath(path);
    final localOk = !remote && hasImage && File(path).existsSync();
    final canOpen = hasImage && (remote || localOk);

    final preview = hasImage
        ? ProductPreviewImage(
            imagePath: path,
            fit: BoxFit.cover,
            width: 96,
            height: 96,
            cacheSize: 288,
            errorIconSize: 28,
          )
        : _placeholderImage();

    return Tooltip(
      message: canOpen ? 'Resmi buyutmek icin dokunun' : 'Resim yok',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canOpen ? _openImageViewer : null,
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F4F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD7DEE6)),
                ),
                child: preview,
              ),
              if (canOpen)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.zoom_in_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inventory_2_outlined, size: 28, color: _ink),
        const SizedBox(height: 4),
        const Text(
          'Resim yok',
          style: TextStyle(
            color: _slate,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------
  // DATASHEET (LIST) LAYOUT
  // --------------------------------------------------------------------

  /// Tum ticari + spesifikasyon + aciklama alanlarini tek kart icinde
  /// datasheet stilinde `Etiket : Deger` satirlariyla listeler. Bolumler
  /// ince ayrac + kucuk baslik ile bolunur.
  Widget _buildDatasheetCard() {
    final template = ProductSpecTemplates.findForCategory(_categoryCtrl.text);

    final items = <Widget>[];

    // --- KIMLIK ---
    items.add(_sectionHeader('Kimlik'));
    items.add(
      _listRow(
        label: 'Urun Kodu',
        controller: _codeCtrl,
        hint: 'Bos birakilirsa otomatik uretilir.',
      ),
    );
    items.add(
      _listRow(label: 'Urun Adi', controller: _nameCtrl, required: true),
    );
    items.add(_listRow(label: 'Marka', controller: _brandCtrl));
    items.add(_listRow(label: 'Model', controller: _modelCtrl));
    items.add(_categoryPickerRow());
    items.add(
      _listRow(
        label: 'Birim',
        controller: _unitCtrl,
        hint: 'adet, paket, set...',
      ),
    );

    // --- TICARI ---
    items.add(_sectionHeader('Ticari Bilgiler'));
    items.add(
      _listRow(
        label: 'Satis Fiyati',
        controller: _salePriceCtrl,
        numeric: true,
      ),
    );
    items.add(_currencyPickerRow());
    items.add(
      _listRow(label: 'Stok Miktari', controller: _stockCtrl, numeric: true),
    );
    items.add(
      _listRow(label: 'Minimum Stok', controller: _minStockCtrl, numeric: true),
    );
    items.add(_listRow(label: 'KDV (%)', controller: _vatCtrl, numeric: true));
    items.add(
      _listRow(
        label: 'Termin',
        controller: _leadTimeCtrl,
        hint: 'Orn: 3 is gunu',
      ),
    );

    // --- SPESIFIKASYONLAR ---
    if (template != null) {
      items.add(_sectionHeader('Spesifikasyonlar', badge: template.label));
      for (final group in template.groups) {
        items.add(_subHeader(group.title));
        for (final field in group.fields) {
          final ctrl = _specCtrls[field.key];
          if (ctrl == null) continue;
          items.add(
            _listRow(
              label: field.label,
              controller: ctrl,
              hint: field.hint,
              multiline: field.multiline,
            ),
          );
        }
      }
    }

    // --- ACIKLAMA ---
    items.add(_sectionHeader('Aciklama'));
    items.add(
      _listRow(
        label: 'Teknik Ozet',
        controller: _technicalSummaryCtrl,
        hint: 'Kisa teknik detaylar (kart arkasi gibi).',
        multiline: true,
      ),
    );
    items.add(
      _listRow(
        label: 'Aciklama',
        controller: _descriptionCtrl,
        hint: 'Urun aciklamasi ve katalog metni.',
        multiline: true,
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items,
        ),
      ),
    );
  }

  /// Datasheet icinde ana bolum basligi. Ust ince border + solda accent cizgi
  /// + metin + opsiyonel kucuk rozet (orn. sablon kategorisi "Inverter").
  Widget _sectionHeader(String title, {String? badge}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE4E8EC), width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 14,
              color: _accent,
              margin: const EdgeInsets.only(right: 8),
            ),
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2F8),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFB8C6D6)),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Spesifikasyon gruplarinin (Genel, Giris/Cikis vb.) alt basligi.
  Widget _subHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: _slate,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  /// Datasheet satiri: solda sabit genislikte label, sagda deger (okuma
  /// modunda metin, duzenleme modunda TextFormField).
  Widget _listRow({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool numeric = false,
    bool required = false,
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 520;
          final labelWidth = isWide ? 180.0 : 140.0;
          final labelBox = SizedBox(
            width: labelWidth,
            child: Padding(
              padding: EdgeInsets.only(top: _isEditing ? 14 : 2),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _slate,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          );

          Widget valueBlock;
          if (_isEditing) {
            valueBlock = TextFormField(
              controller: controller,
              maxLines: multiline ? 3 : 1,
              keyboardType: numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (required && trimmed.isEmpty) {
                  return '$label bos birakilamaz';
                }
                if (numeric && trimmed.isNotEmpty) {
                  final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
                  if (parsed == null) {
                    return 'Gecerli bir sayi girin';
                  }
                  if (parsed < 0) {
                    return 'Negatif deger giremezsiniz';
                  }
                }
                return null;
              },
            );
          } else {
            final raw = controller.text.trim();
            final value = raw.isEmpty ? '-' : raw;
            valueBlock = Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                value,
                maxLines: multiline ? 6 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: raw.isEmpty ? _slate : _ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelBox,
              const SizedBox(width: 8),
              Expanded(child: valueBlock),
            ],
          );
        },
      ),
    );
  }
}
