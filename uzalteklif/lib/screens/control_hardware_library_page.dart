import 'package:flutter/material.dart';

import '../models/control_hardware.dart';
import '../models/discovery_project.dart';
import '../models/product.dart';
import '../services/control_hardware_repository.dart';
import '../services/product_repository.dart';
import '../utils/product_category_labels.dart';
import '../widgets/workspace_background.dart';

class ControlHardwareLibraryPage extends StatefulWidget {
  const ControlHardwareLibraryPage({
    super.key,
    required this.repository,
    this.productRepository,
  });

  final ControlHardwareRepository repository;
  final ProductRepository? productRepository;

  @override
  State<ControlHardwareLibraryPage> createState() =>
      _ControlHardwareLibraryPageState();
}

class _ControlHardwareLibraryPageState
    extends State<ControlHardwareLibraryPage> {
  List<ControlHardware> _items = const [];
  List<Product> _products = const [];
  bool _loading = true;
  String _query = '';
  ControlHardwareType? _typeFilter;

  List<ControlHardware> get _visibleItems {
    final query = _query.trim().toLowerCase();
    return _items
        .where((item) {
          if (_typeFilter != null && item.type != _typeFilter) return false;
          if (query.isEmpty) return true;
          return [
            item.brand,
            item.model,
            item.family,
            item.connectionProtocol,
          ].join(' ').toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final items = await widget.repository.fetchAll();
      final products =
          await widget.productRepository?.fetchProducts() ?? const <Product>[];
      if (!mounted) return;
      setState(() {
        _items = items;
        _products = products;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('DDC/I/O kütüphanesi alınamadı: $error')),
      );
    }
  }

  Future<void> _edit({
    ControlHardware? existing,
    ControlHardwareType initialType = ControlHardwareType.controller,
  }) async {
    final item = await showDialog<ControlHardware>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _HardwareEditorDialog(
        existing: existing,
        initialType: initialType,
        createdBy: widget.repository.currentUserId,
        products: _products,
      ),
    );
    if (item == null) return;
    try {
      await widget.repository.save(item);
      if (mounted) await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ekipman kaydedilemedi: $error')));
    }
  }

  Future<void> _delete(ControlHardware item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ekipman silinsin mi?'),
        content: Text(item.displayName),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9D3418),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.repository.deleteById(item.id);
      if (mounted) await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ekipman silinemedi: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DDC ve I/O Kütüphanesi'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: WorkspaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildToolbar(),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 310,
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    labelText: 'Marka, model veya aile ara',
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              SegmentedButton<ControlHardwareType?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('Tümü')),
                  ButtonSegment(
                    value: ControlHardwareType.controller,
                    label: Text('Kontrolör'),
                  ),
                  ButtonSegment(
                    value: ControlHardwareType.ioModule,
                    label: Text('I/O Modülü'),
                  ),
                ],
                selected: {_typeFilter},
                onSelectionChanged: (selection) {
                  setState(() => _typeFilter = selection.first);
                },
              ),
              FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.memory_rounded),
                label: const Text('Kontrolör Ekle'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _edit(initialType: ControlHardwareType.ioModule),
                icon: const Icon(Icons.extension_rounded),
                label: const Text('I/O Modülü Ekle'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final items = _visibleItems;
    if (items.isEmpty) {
      return const Center(
        child: Text('Filtreye uygun kontrolör veya I/O modülü bulunamadı.'),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 3
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 380,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _HardwareCard(
              item: item,
              product: _productFor(item.productId),
              onEdit: () => _edit(existing: item),
              onDelete: () => _delete(item),
            );
          },
        );
      },
    );
  }

  Product? _productFor(String productId) {
    for (final product in _products) {
      if (product.id == productId) return product;
    }
    return null;
  }
}

class _HardwareCard extends StatelessWidget {
  const _HardwareCard({
    required this.item,
    this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final ControlHardware item;
  final Product? product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    child: Icon(
                      item.isController
                          ? Icons.memory_rounded
                          : Icons.extension_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          item.family.trim().isEmpty
                              ? 'Aile belirtilmedi'
                              : item.family,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                      PopupMenuItem(value: 'delete', child: Text('Sil')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  Chip(
                    avatar: Icon(
                      item.isController
                          ? Icons.memory_rounded
                          : Icons.extension_rounded,
                      size: 17,
                    ),
                    label: Text(item.type.label),
                  ),
                  Chip(
                    label: Text('${item.physicalChannelCount} fiziksel kanal'),
                  ),
                  if (!item.isActive) const Chip(label: Text('Pasif')),
                  if (product != null)
                    Chip(
                      avatar: const Icon(Icons.inventory_2_outlined, size: 17),
                      label: Text(
                        '${product!.code} · ${product!.formattedStock}',
                      ),
                    ),
                  if (item.productId.isEmpty)
                    const Chip(label: Text('Stok ürünü bağlı değil')),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: item.channelPools.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 7),
                  itemBuilder: (context, index) {
                    final pool = item.channelPools[index];
                    final capabilities = pool.supportedPointTypes
                        .map((type) => type.label)
                        .join(' · ');
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${pool.quantity} × ${pool.name}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            capabilities.isEmpty
                                ? 'Yetenek tanımlanmadı'
                                : capabilities,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (pool.supportedPointTypes.contains(
                                DiscoveryPointType.aiActive,
                              ) &&
                              !pool.supportsAiActive420mA)
                            const Text(
                              'AI-A 4–20 mA desteklenmez',
                              style: TextStyle(
                                color: Color(0xFF9D3418),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (item.note.trim().isNotEmpty)
                Text(
                  item.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockProductPickerDialog extends StatefulWidget {
  const _StockProductPickerDialog({
    required this.products,
    required this.selectedProductId,
    required this.hardwareType,
  });

  final List<Product> products;
  final String selectedProductId;
  final ControlHardwareType hardwareType;

  @override
  State<_StockProductPickerDialog> createState() =>
      _StockProductPickerDialogState();
}

class _StockProductPickerDialogState extends State<_StockProductPickerDialog> {
  String _query = '';
  late ProductMainCategory _group;
  String _category = '';

  @override
  void initState() {
    super.initState();
    Product? selectedProduct;
    for (final product in widget.products) {
      if (product.id == widget.selectedProductId) {
        selectedProduct = product;
        break;
      }
    }
    _group = selectedProduct == null
        ? (widget.hardwareType == ControlHardwareType.controller
              ? ProductMainCategory.controller
              : ProductMainCategory.ioModule)
        : productMainCategoryFor(selectedProduct);
  }

  List<String> get _categories {
    final result = widget.products
        .where(
          (product) =>
              product.isActive &&
              product.stockQuantity > 0 &&
              productMainCategoryFor(product) == _group,
        )
        .map(productSubcategoryTurkishLabel)
        .toSet()
        .toList();
    result.sort();
    return result;
  }

  int _groupCount(ProductMainCategory group) {
    return widget.products
        .where(
          (product) =>
              product.isActive &&
              product.stockQuantity > 0 &&
              productMainCategoryFor(product) == group,
        )
        .length;
  }

  List<Product> get _visibleProducts {
    final query = _query.trim().toLowerCase();
    return widget.products
        .where((product) {
          if (!product.isActive || product.stockQuantity <= 0) return false;
          if (productMainCategoryFor(product) != _group) return false;
          if (_category.isNotEmpty &&
              productSubcategoryTurkishLabel(product) != _category) {
            return false;
          }
          if (query.isEmpty) return true;
          return [
            product.code,
            product.name,
            product.brand,
            product.model,
            product.category,
          ].join(' ').toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final products = _visibleProducts;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Stoktan cihaz seç',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Ana Kategoriler',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final group in ProductMainCategory.values)
                    ChoiceChip(
                      selected: _group == group,
                      label: Text('${group.label} (${_groupCount(group)})'),
                      onSelected: (_) {
                        setState(() {
                          _group = group;
                          _category = '';
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('stock-category-${_group.name}'),
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Türkçe Alt Kategori',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Tüm alt kategoriler'),
                  ),
                  for (final category in _categories)
                    DropdownMenuItem(
                      value: category,
                      child: Text(category, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => setState(() => _category = value ?? ''),
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Ürün kodu, adı, marka veya model ara',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Text(
                '${products.length} stok ürünü',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: products.isEmpty
                    ? const Center(
                        child: Text('Aramaya uygun stok ürünü bulunamadı.'),
                      )
                    : ListView.separated(
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final selected =
                              product.id == widget.selectedProductId;
                          return ListTile(
                            selected: selected,
                            leading: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.inventory_2_outlined,
                            ),
                            title: Text(
                              '${product.code} · ${product.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${productSubcategoryTurkishLabel(product)} · '
                              '${product.brand} ${product.model} · '
                              '${product.formattedStock} · '
                              '${product.formattedSalePrice}',
                            ),
                            onTap: () => Navigator.pop(context, product),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HardwareEditorDialog extends StatefulWidget {
  const _HardwareEditorDialog({
    required this.initialType,
    required this.createdBy,
    required this.products,
    this.existing,
  });

  final ControlHardware? existing;
  final ControlHardwareType initialType;
  final String? createdBy;
  final List<Product> products;

  @override
  State<_HardwareEditorDialog> createState() => _HardwareEditorDialogState();
}

class _HardwareEditorDialogState extends State<_HardwareEditorDialog> {
  late ControlHardwareType _type;
  late HardwareCompatibilityMode _compatibilityMode;
  late bool _isActive;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _familyController;
  late final TextEditingController _productIdController;
  late final TextEditingController _maxModulesController;
  late final TextEditingController _protocolController;
  late final TextEditingController _compatibleFamiliesController;
  late final TextEditingController _noteController;
  late final List<_ChannelPoolDraft> _pools;
  int _idCounter = 0;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _type = existing?.type ?? widget.initialType;
    _compatibilityMode =
        existing?.compatibilityMode ?? HardwareCompatibilityMode.sameFamily;
    _isActive = existing?.isActive ?? true;
    _brandController = TextEditingController(text: existing?.brand ?? '');
    _modelController = TextEditingController(text: existing?.model ?? '');
    _familyController = TextEditingController(text: existing?.family ?? '');
    _productIdController = TextEditingController(
      text: existing?.productId ?? '',
    );
    _maxModulesController = TextEditingController(
      text: '${existing?.maxExpansionModules ?? 0}',
    );
    _protocolController = TextEditingController(
      text: existing?.connectionProtocol ?? '',
    );
    _compatibleFamiliesController = TextEditingController(
      text: existing?.compatibleFamilies.join(', ') ?? '',
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    _pools =
        existing?.channelPools
            .map(_ChannelPoolDraft.fromPool)
            .toList(growable: true) ??
        [_ChannelPoolDraft.empty(_buildId('pool'))];
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _familyController.dispose();
    _productIdController.dispose();
    _maxModulesController.dispose();
    _protocolController.dispose();
    _compatibleFamiliesController.dispose();
    _noteController.dispose();
    for (final pool in _pools) {
      pool.dispose();
    }
    super.dispose();
  }

  String _buildId(String prefix) {
    _idCounter += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
  }

  void _addPool() {
    setState(() => _pools.add(_ChannelPoolDraft.empty(_buildId('pool'))));
  }

  void _removePool(int index) {
    final removed = _pools.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Product? get _selectedProduct {
    final productId = _productIdController.text.trim();
    for (final product in widget.products) {
      if (product.id == productId) return product;
    }
    return null;
  }

  Future<void> _pickStockProduct() async {
    final product = await showDialog<Product>(
      context: context,
      builder: (context) => _StockProductPickerDialog(
        products: widget.products,
        selectedProductId: _productIdController.text.trim(),
        hardwareType: _type,
      ),
    );
    if (product == null) return;
    setState(() {
      _productIdController.text = product.id;
      _brandController.text = product.brand;
      _modelController.text = product.model.trim().isEmpty
          ? product.code
          : product.model;
    });
  }

  void _submit() {
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();
    if (brand.isEmpty || model.isEmpty) {
      setState(() => _error = 'Marka ve model zorunludur.');
      return;
    }
    if (_pools.isEmpty) {
      setState(() => _error = 'En az bir kanal grubu ekleyin.');
      return;
    }

    final pools = <HardwareChannelPool>[];
    for (final draft in _pools) {
      final pool = draft.build();
      if (pool == null) {
        setState(
          () => _error =
              'Kanal gruplarında ad, pozitif adet ve en az bir yetenek olmalı.',
        );
        return;
      }
      pools.add(pool);
    }

    final existing = widget.existing;
    final item = ControlHardware(
      id: existing?.id ?? _buildId('hardware'),
      type: _type,
      brand: brand,
      model: model,
      family: _familyController.text.trim(),
      productId: _productIdController.text.trim(),
      channelPools: pools,
      compatibilityMode: _compatibilityMode,
      connectionProtocol: _protocolController.text.trim(),
      compatibleFamilies: _compatibleFamiliesController.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      maxExpansionModules: int.tryParse(_maxModulesController.text.trim()) ?? 0,
      isActive: _isActive,
      note: _noteController.text.trim(),
      updatedAt: DateTime.now(),
      createdBy: existing?.createdBy ?? widget.createdBy,
    );
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.existing == null
        ? '${_type.label} Ekle'
        : '${_type.label} Düzenle';
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 14),
              child: Row(
                children: [
                  Icon(
                    _type == ControlHardwareType.controller
                        ? Icons.memory_rounded
                        : Icons.extension_rounded,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildIdentitySection(),
                  const SizedBox(height: 18),
                  _buildChannelSection(),
                  const SizedBox(height: 18),
                  _buildCompatibilitySection(),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Vazgeç'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Kaydet'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentitySection() {
    return _EditorSection(
      title: 'Ekipman Bilgileri',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<ControlHardwareType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Ekipman türü'),
              items: ControlHardwareType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
          ),
          _SizedField(
            width: 210,
            controller: _brandController,
            label: 'Marka *',
            hint: 'ABB',
          ),
          _SizedField(
            width: 240,
            controller: _modelController,
            label: 'Model *',
            hint: 'FBXi 8R8',
          ),
          _SizedField(
            width: 210,
            controller: _familyController,
            label: 'Aile/Seri',
            hint: 'FBXi',
          ),
          SizedBox(
            width: 360,
            child: OutlinedButton.icon(
              onPressed: widget.products.isEmpty ? null : _pickStockProduct,
              icon: const Icon(Icons.inventory_2_outlined),
              label: Text(
                _selectedProduct == null
                    ? 'Stoktan ürün bağla'
                    : '${_selectedProduct!.code} · '
                          '${_selectedProduct!.formattedStock}',
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 18,
                ),
              ),
            ),
          ),
          if (_selectedProduct != null)
            IconButton(
              tooltip: 'Stok bağlantısını kaldır',
              onPressed: () => setState(_productIdController.clear),
              icon: const Icon(Icons.link_off_rounded),
            ),
          if (_type == ControlHardwareType.controller)
            _SizedField(
              width: 210,
              controller: _maxModulesController,
              label: 'Maksimum ek modül',
              hint: '0',
              numeric: true,
            ),
          SizedBox(
            width: 180,
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: const Text('Aktif'),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelSection() {
    return _EditorSection(
      title: 'Kanal Grupları',
      trailing: OutlinedButton.icon(
        onPressed: _addPool,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kanal Grubu Ekle'),
      ),
      child: Column(
        children: [
          for (var index = 0; index < _pools.length; index++) ...[
            _ChannelPoolEditor(
              draft: _pools[index],
              onChanged: () => setState(() {}),
              onRemove: _pools.length == 1 ? null : () => _removePool(index),
            ),
            if (index < _pools.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildCompatibilitySection() {
    return _EditorSection(
      title: 'Uyumluluk ve Bağlantı',
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 270,
                child: DropdownButtonFormField<HardwareCompatibilityMode>(
                  initialValue: _compatibilityMode,
                  decoration: const InputDecoration(
                    labelText: 'Uyumluluk tipi',
                  ),
                  items: HardwareCompatibilityMode.values
                      .map(
                        (mode) => DropdownMenuItem(
                          value: mode,
                          child: Text(mode.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _compatibilityMode = value);
                    }
                  },
                ),
              ),
              _SizedField(
                width: 260,
                controller: _protocolController,
                label: 'Bağlantı/protokol',
                hint: 'Native, Modbus TCP...',
              ),
              _SizedField(
                width: 360,
                controller: _compatibleFamiliesController,
                label: 'Uyumlu aileler',
                hint: 'FBXi, Unitary (virgülle ayırın)',
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Teknik not',
              hintText: 'Kanal veya uyumluluk kısıtlarını yazın.',
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SizedField extends StatelessWidget {
  const _SizedField({
    required this.width,
    required this.controller,
    required this.label,
    this.hint,
    this.numeric = false,
  });

  final double width;
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        keyboardType: numeric ? TextInputType.number : null,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

class _ChannelPoolDraft {
  _ChannelPoolDraft({
    required this.id,
    required this.nameController,
    required this.quantityController,
    required this.supportedTypes,
    required this.supportsAiActive420mA,
  });

  factory _ChannelPoolDraft.empty(String id) {
    return _ChannelPoolDraft(
      id: id,
      nameController: TextEditingController(),
      quantityController: TextEditingController(text: '1'),
      supportedTypes: {DiscoveryPointType.di},
      supportsAiActive420mA: true,
    );
  }

  factory _ChannelPoolDraft.fromPool(HardwareChannelPool pool) {
    return _ChannelPoolDraft(
      id: pool.id,
      nameController: TextEditingController(text: pool.name),
      quantityController: TextEditingController(text: '${pool.quantity}'),
      supportedTypes: Set<DiscoveryPointType>.from(pool.supportedPointTypes),
      supportsAiActive420mA: pool.supportsAiActive420mA,
    );
  }

  final String id;
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final Set<DiscoveryPointType> supportedTypes;
  bool supportsAiActive420mA;

  HardwareChannelPool? build() {
    final name = nameController.text.trim();
    final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
    if (name.isEmpty || quantity < 1 || supportedTypes.isEmpty) return null;
    return HardwareChannelPool(
      id: id,
      name: name,
      quantity: quantity,
      supportedPointTypes: Set<DiscoveryPointType>.unmodifiable(supportedTypes),
      supportsAiActive420mA: supportsAiActive420mA,
    );
  }

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
  }
}

class _ChannelPoolEditor extends StatelessWidget {
  const _ChannelPoolEditor({
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final _ChannelPoolDraft draft;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  static const _ioTypes = [
    DiscoveryPointType.aiActive,
    DiscoveryPointType.aiPassive,
    DiscoveryPointType.ao,
    DiscoveryPointType.di,
    DiscoveryPointType.doOutput,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: draft.nameController,
                  decoration: const InputDecoration(
                    labelText: 'Grup adı',
                    hintText: 'UI, UIO, DO...',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 115,
                child: TextField(
                  controller: draft.quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kanal adedi',
                    isDense: true,
                  ),
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Kanal grubunu sil',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Kanal yetenekleri:',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                for (final type in _ioTypes)
                  FilterChip(
                    label: Text(type.label),
                    selected: draft.supportedTypes.contains(type),
                    onSelected: (selected) {
                      if (selected) {
                        draft.supportedTypes.add(type);
                      } else {
                        draft.supportedTypes.remove(type);
                      }
                      onChanged();
                    },
                  ),
              ],
            ),
          ),
          if (draft.supportedTypes.contains(DiscoveryPointType.aiActive)) ...[
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('AI-A 4–20 mA destekli'),
              subtitle: const Text(
                'Kapalıysa kanal AI-A olabilir ancak 4–20 mA sinyal alamaz.',
              ),
              value: draft.supportsAiActive420mA,
              onChanged: (value) {
                draft.supportsAiActive420mA = value;
                onChanged();
              },
            ),
          ],
        ],
      ),
    );
  }
}
