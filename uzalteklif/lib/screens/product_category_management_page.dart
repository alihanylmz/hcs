import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_repository.dart';
import '../utils/product_category_labels.dart';
import '../widgets/workspace_background.dart';

class ProductCategoryManagementPage extends StatefulWidget {
  const ProductCategoryManagementPage({
    super.key,
    required this.productRepository,
  });

  final ProductRepository productRepository;

  @override
  State<ProductCategoryManagementPage> createState() =>
      _ProductCategoryManagementPageState();
}

class _ProductCategoryManagementPageState
    extends State<ProductCategoryManagementPage> {
  List<Product> _products = const [];
  bool _loading = true;
  bool _saving = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final products = await widget.productRepository.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ürün kategorileri alınamadı: $error')),
      );
    }
  }

  Future<void> _editClassification(List<Product> products) async {
    if (products.isEmpty || _saving) return;
    final firstMain = productMainCategoryTurkishLabel(products.first);
    final firstSub = productSubcategoryTurkishLabel(products.first);
    final sameMain = products.every(
      (product) => productMainCategoryTurkishLabel(product) == firstMain,
    );
    final sameSub = products.every(
      (product) => productSubcategoryTurkishLabel(product) == firstSub,
    );
    final result = await showDialog<_CategoryEditResult>(
      context: context,
      builder: (context) => _CategoryEditDialog(
        productCount: products.length,
        initialMain: sameMain ? firstMain : '',
        initialSub: sameSub ? firstSub : '',
        mainSuggestions: {
          ...ProductMainCategory.values.map((category) => category.label),
          ..._products.map(productMainCategoryTurkishLabel),
        }.toList()..sort(),
        subSuggestions:
            _products.map(productSubcategoryTurkishLabel).toSet().toList()
              ..sort(),
      ),
    );
    if (result == null) return;
    setState(() => _saving = true);
    try {
      final updated = products
          .map(
            (product) => withProductCatalogClassification(
              product,
              mainCategory: result.mainCategory,
              subcategory: result.subcategory,
            ),
          )
          .toList(growable: false);
      await widget.productRepository.saveProducts(updated);
      final updatedById = {for (final product in updated) product.id: product};
      if (!mounted) return;
      setState(() {
        _products = [
          for (final product in _products) updatedById[product.id] ?? product,
        ];
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${updated.length} ürünün kategori eşleştirmesi güncellendi.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kategori güncellenemedi: $error')),
      );
    }
  }

  Map<String, List<Product>> get _rawCategoryGroups {
    final result = <String, List<Product>>{};
    for (final product in _products) {
      final category = product.category.trim().isEmpty
          ? 'Kategorisiz'
          : product.category.trim();
      result.putIfAbsent(category, () => []).add(product);
    }
    return result;
  }

  List<Product> get _visibleProducts {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _products;
    return _products
        .where((product) {
          return [
            product.code,
            product.name,
            product.brand,
            product.model,
            product.category,
            productMainCategoryTurkishLabel(product),
            productSubcategoryTurkishLabel(product),
          ].join(' ').toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ürün Kategori Yönetimi'),
          actions: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(right: 18),
                child: Center(
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Yenile',
              onPressed: _loading || _saving ? null : _reload,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.account_tree_outlined),
                text: 'CSV Kategori Eşleme',
              ),
              Tab(
                icon: Icon(Icons.inventory_2_outlined),
                text: 'Ürün İstisnaları',
              ),
            ],
          ),
        ),
        body: WorkspaceBackground(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    _buildRawCategoryMapping(),
                    _buildProductOverrides(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildRawCategoryMapping() {
    final entries = _rawCategoryGroups.entries.toList()
      ..sort(
        (left, right) =>
            left.key.toLowerCase().compareTo(right.key.toLowerCase()),
      );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _InfoCard(
          text:
              'CSV’den gelen kategoriyi bir kez Türkçe ana ve alt kategoriyle '
              'eşleştirin. Bu işlem o gruptaki bütün ürünleri günceller.',
        ),
        const SizedBox(height: 12),
        for (final entry in entries)
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.folder_copy_outlined),
              ),
              title: Text(
                entry.key,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(_classificationSummary(entry.value)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Chip(label: Text('${entry.value.length} ürün')),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit_outlined),
                ],
              ),
              onTap: _saving ? null : () => _editClassification(entry.value),
            ),
          ),
      ],
    );
  }

  Widget _buildProductOverrides() {
    final products = _visibleProducts;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Ürün kodu, adı, marka veya kategori ara',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: products.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(
                  '${product.code} · ${product.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${productMainCategoryTurkishLabel(product)} › '
                  '${productSubcategoryTurkishLabel(product)}\n'
                  'Kaynak: ${product.category.trim().isEmpty ? "Kategorisiz" : product.category}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.edit_outlined),
                onTap: _saving ? null : () => _editClassification([product]),
              );
            },
          ),
        ),
      ],
    );
  }

  String _classificationSummary(List<Product> products) {
    final pairs = products
        .map(
          (product) =>
              '${productMainCategoryTurkishLabel(product)} › '
              '${productSubcategoryTurkishLabel(product)}',
        )
        .toSet();
    if (pairs.length == 1) return pairs.first;
    return '${pairs.length} farklı eşleştirme · düzenlemek için tıklayın';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _CategoryEditResult {
  const _CategoryEditResult({
    required this.mainCategory,
    required this.subcategory,
  });

  final String mainCategory;
  final String subcategory;
}

class _CategoryEditDialog extends StatefulWidget {
  const _CategoryEditDialog({
    required this.productCount,
    required this.initialMain,
    required this.initialSub,
    required this.mainSuggestions,
    required this.subSuggestions,
  });

  final int productCount;
  final String initialMain;
  final String initialSub;
  final List<String> mainSuggestions;
  final List<String> subSuggestions;

  @override
  State<_CategoryEditDialog> createState() => _CategoryEditDialogState();
}

class _CategoryEditDialogState extends State<_CategoryEditDialog> {
  late final TextEditingController _mainController;
  late final TextEditingController _subController;

  @override
  void initState() {
    super.initState();
    _mainController = TextEditingController(text: widget.initialMain);
    _subController = TextEditingController(text: widget.initialSub);
  }

  @override
  void dispose() {
    _mainController.dispose();
    _subController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kategori Eşleştirmesini Düzenle'),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.productCount} ürün güncellenecek.'),
            const SizedBox(height: 16),
            _SuggestionField(
              controller: _mainController,
              label: 'Türkçe ana kategori',
              suggestions: widget.mainSuggestions,
            ),
            const SizedBox(height: 12),
            _SuggestionField(
              controller: _subController,
              label: 'Türkçe alt kategori',
              suggestions: widget.subSuggestions,
            ),
            const SizedBox(height: 8),
            Text(
              'Listede olmayan yeni bir kategori adını doğrudan yazabilirsiniz.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            final main = _mainController.text.trim();
            final sub = _subController.text.trim();
            if (main.isEmpty || sub.isEmpty) return;
            Navigator.pop(
              context,
              _CategoryEditResult(mainCategory: main, subcategory: sub),
            );
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _SuggestionField extends StatelessWidget {
  const _SuggestionField({
    required this.controller,
    required this.label,
    required this.suggestions,
  });

  final TextEditingController controller;
  final String label;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: FocusNode(),
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return suggestions.take(12);
        return suggestions
            .where((item) => item.toLowerCase().contains(query))
            .take(12);
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
          ),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final values = options.toList(growable: false);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540, maxHeight: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: values.length,
                itemBuilder: (context, index) => ListTile(
                  dense: true,
                  title: Text(values[index]),
                  onTap: () => onSelected(values[index]),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
