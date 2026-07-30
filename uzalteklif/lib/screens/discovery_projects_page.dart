import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/discovery_templates.dart';
import '../models/control_hardware.dart';
import '../models/discovery_project.dart';
import '../models/product.dart';
import '../services/cari_repository.dart';
import '../services/control_hardware_repository.dart';
import '../services/control_hardware_selector.dart';
import '../services/discovery_repository.dart';
import '../services/market_rate_service.dart';
import '../services/own_company_repository.dart';
import '../services/price_adjustment_rule_repository.dart';
import '../services/product_repository.dart';
import '../services/quote_repository.dart';
import '../services/user_profile_repository.dart';
import '../utils/discovery_product_matcher.dart';
import '../utils/product_category_labels.dart';
import '../widgets/workspace_background.dart';
import 'control_hardware_library_page.dart';
import 'product_category_management_page.dart';
import 'quote_editor_page.dart';

class DiscoveryProjectsPage extends StatefulWidget {
  const DiscoveryProjectsPage({
    super.key,
    required this.repository,
    required this.hardwareRepository,
    required this.productRepository,
    required this.quoteRepository,
    required this.marketRateService,
    required this.userProfileRepository,
    required this.cariRepository,
    required this.ownCompanyRepository,
    required this.priceAdjustmentRuleRepository,
  });

  final DiscoveryRepository repository;
  final ControlHardwareRepository hardwareRepository;
  final ProductRepository productRepository;
  final QuoteRepository quoteRepository;
  final MarketRateService marketRateService;
  final UserProfileRepository userProfileRepository;
  final CariRepository cariRepository;
  final OwnCompanyRepository ownCompanyRepository;
  final PriceAdjustmentRuleRepository priceAdjustmentRuleRepository;

  @override
  State<DiscoveryProjectsPage> createState() => _DiscoveryProjectsPageState();
}

class _DiscoveryProjectsPageState extends State<DiscoveryProjectsPage> {
  List<DiscoveryProject> _projects = const [];
  bool _loading = true;
  String _query = '';

  List<DiscoveryProject> get _visibleProjects {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _projects;
    return _projects
        .where(
          (project) => [
            project.projectName,
            project.projectCode,
            project.preparedBy,
          ].join(' ').toLowerCase().contains(query),
        )
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
      final projects = await widget.repository.fetchAll();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Keşif listesi alınamadı: $error')),
      );
    }
  }

  Future<void> _openEditor([DiscoveryProject? project]) async {
    final now = DateTime.now();
    final source =
        project ??
        DiscoveryProject(
          id: _newId('discovery'),
          projectName: '',
          projectCode: '',
          revision: '00',
          preparedBy: '',
          devices: const [],
          createdAt: now,
          updatedAt: now,
          createdBy: widget.repository.currentUserId,
        );
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => DiscoveryEditorPage(
          project: source,
          repository: widget.repository,
          hardwareRepository: widget.hardwareRepository,
          productRepository: widget.productRepository,
          quoteRepository: widget.quoteRepository,
          marketRateService: widget.marketRateService,
          userProfileRepository: widget.userProfileRepository,
          cariRepository: widget.cariRepository,
          ownCompanyRepository: widget.ownCompanyRepository,
          priceAdjustmentRuleRepository: widget.priceAdjustmentRuleRepository,
        ),
      ),
    );
    if (saved == true && mounted) await _reload();
  }

  Future<void> _delete(DiscoveryProject project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keşif silinsin mi?'),
        content: Text(
          project.projectName.trim().isEmpty
              ? project.projectCode
              : project.projectName,
        ),
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
      await widget.repository.deleteById(project.id);
      if (mounted) await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Keşif silinemedi: $error')));
    }
  }

  Future<void> _openHardwareLibrary() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ControlHardwareLibraryPage(
          repository: widget.hardwareRepository,
          productRepository: widget.productRepository,
        ),
      ),
    );
  }

  Future<void> _openCategoryManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ProductCategoryManagementPage(
          productRepository: widget.productRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keşif ve Nokta Analizi'),
        actions: [
          TextButton.icon(
            onPressed: _openCategoryManagement,
            icon: const Icon(Icons.category_outlined),
            label: const Text('Kategori Yönetimi'),
          ),
          TextButton.icon(
            onPressed: _openHardwareLibrary,
            icon: const Icon(Icons.memory_rounded),
            label: const Text('DDC/I/O Kütüphanesi'),
          ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          labelText: 'Proje adı, kodu veya hazırlayan ara',
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _openEditor(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Yeni Keşif'),
                    ),
                  ],
                ),
              ),
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

  Widget _buildList() {
    final projects = _visibleProjects;
    if (projects.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _query.trim().isEmpty
                        ? 'Henüz keşif oluşturulmadı'
                        : 'Aramaya uygun keşif bulunamadı',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pompa, kazan ve klima santrali şablonlarından otomatik '
                    'kontrol noktaları oluşturabilirsiniz.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 250,
          ),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            return _DiscoveryProjectCard(
              project: project,
              onOpen: () => _openEditor(project),
              onDelete: () => _delete(project),
            );
          },
        );
      },
    );
  }
}

class _DiscoveryProjectCard extends StatelessWidget {
  const _DiscoveryProjectCard({
    required this.project,
    required this.onOpen,
    required this.onDelete,
  });

  final DiscoveryProject project;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat(
      'dd.MM.yyyy HH:mm',
      'tr_TR',
    ).format(project.updatedAt);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.projectName.trim().isEmpty
                              ? 'İsimsiz Keşif'
                              : project.projectName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          project.projectCode.trim().isEmpty
                              ? 'Proje kodu girilmemiş'
                              : project.projectCode,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Sil'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallMetric(
                    label: 'Cihaz',
                    value: '${project.devices.length}',
                  ),
                  _SmallMetric(
                    label: 'Toplam nokta',
                    value: '${project.totalPoints}',
                  ),
                  _SmallMetric(
                    label: 'Rev.',
                    value: project.revision.isEmpty ? '00' : project.revision,
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 17),
                  const SizedBox(width: 6),
                  Text(date, style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiscoveryEditorPage extends StatefulWidget {
  const DiscoveryEditorPage({
    super.key,
    required this.project,
    required this.repository,
    required this.hardwareRepository,
    required this.productRepository,
    required this.quoteRepository,
    required this.marketRateService,
    required this.userProfileRepository,
    required this.cariRepository,
    required this.ownCompanyRepository,
    required this.priceAdjustmentRuleRepository,
  });

  final DiscoveryProject project;
  final DiscoveryRepository repository;
  final ControlHardwareRepository hardwareRepository;
  final ProductRepository productRepository;
  final QuoteRepository quoteRepository;
  final MarketRateService marketRateService;
  final UserProfileRepository userProfileRepository;
  final CariRepository cariRepository;
  final OwnCompanyRepository ownCompanyRepository;
  final PriceAdjustmentRuleRepository priceAdjustmentRuleRepository;

  @override
  State<DiscoveryEditorPage> createState() => _DiscoveryEditorPageState();
}

class _DiscoveryEditorPageState extends State<DiscoveryEditorPage> {
  late final TextEditingController _projectNameController;
  late final TextEditingController _projectCodeController;
  late final TextEditingController _revisionController;
  late final TextEditingController _preparedByController;
  late List<DiscoveryDevice> _devices;
  late List<DiscoveryPanelSettings> _panelSettings;
  List<ControlHardware> _hardware = const [];
  List<Product> _products = const [];
  List<DiscoveryDeviceTemplate> _savedDeviceTemplates = const [];
  List<PanelHardwareSolution> _hardwareSolutions = const [];
  bool _loadingHardware = true;
  bool _saving = false;
  int _idCounter = 0;

  @override
  void initState() {
    super.initState();
    _projectNameController = TextEditingController(
      text: widget.project.projectName,
    );
    _projectCodeController = TextEditingController(
      text: widget.project.projectCode,
    );
    _revisionController = TextEditingController(text: widget.project.revision);
    _preparedByController = TextEditingController(
      text: widget.project.preparedBy,
    );
    _devices = List<DiscoveryDevice>.from(widget.project.devices);
    _panelSettings = List<DiscoveryPanelSettings>.from(
      widget.project.panelSettings,
    );
    _loadHardware();
  }

  @override
  void dispose() {
    _projectNameController.dispose();
    _projectCodeController.dispose();
    _revisionController.dispose();
    _preparedByController.dispose();
    super.dispose();
  }

  String _buildId(String prefix) {
    _idCounter += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
  }

  DiscoveryProject get _currentProject => widget.project.copyWith(
    projectName: _projectNameController.text.trim(),
    projectCode: _projectCodeController.text.trim(),
    revision: _revisionController.text.trim(),
    preparedBy: _preparedByController.text.trim(),
    devices: List<DiscoveryDevice>.unmodifiable(_devices),
    panelSettings: List<DiscoveryPanelSettings>.unmodifiable(_panelSettings),
    updatedAt: DateTime.now(),
    createdBy: widget.project.createdBy ?? widget.repository.currentUserId,
  );

  List<String> get _existingPanelCodes {
    final codes = <String>[];
    for (final device in _devices) {
      final code = device.panelCode.trim().toUpperCase();
      if (code.isNotEmpty && !codes.contains(code)) codes.add(code);
    }
    return codes;
  }

  List<DiscoveryDeviceTemplate> get _availableDeviceTemplates => [
    ...DiscoveryTemplates.values,
    ..._savedDeviceTemplates,
  ];

  Map<String, int> get _selectedProductQuantities {
    final quantities = <String, int>{};
    for (final line in _selectedQuoteProductLines) {
      quantities.update(
        line.productId,
        (value) => value + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }
    return quantities;
  }

  List<QuoteInitialProductLine> get _selectedQuoteProductLines {
    final quantities = <String, int>{};
    String keyFor(String panelCode, String subcategory, String productId) =>
        '${panelCode.trim().toUpperCase()}::$subcategory::$productId';
    String panelForDevice(DiscoveryDevice device) =>
        device.panelCode.trim().isEmpty
        ? 'PANO BELİRTİLMEDİ'
        : device.panelCode.trim().toUpperCase();

    for (final device in _devices) {
      final panelCode = panelForDevice(device);
      for (final point in device.points) {
        if (point.productId.isEmpty) continue;
        final key = keyFor(panelCode, 'Saha Ekipmanları', point.productId);
        quantities.update(
          key,
          (value) => value + point.quantity,
          ifAbsent: () => point.quantity,
        );
      }
    }
    for (final settings in _panelSettings) {
      final panelCode = settings.panelCode.trim().isEmpty
          ? 'PANO BELİRTİLMEDİ'
          : settings.panelCode.trim().toUpperCase();
      if (settings.controllerHardwareId.isNotEmpty) {
        final controller = _hardware.where(
          (item) => item.id == settings.controllerHardwareId,
        );
        if (controller.isNotEmpty && controller.first.productId.isNotEmpty) {
          final key = keyFor(
            panelCode,
            'Kontrolörler',
            controller.first.productId,
          );
          quantities.update(key, (value) => value + 1, ifAbsent: () => 1);
        }
      }
      for (final moduleId in settings.ioModuleHardwareIds) {
        final module = _hardware.where((item) => item.id == moduleId);
        if (module.isEmpty || module.first.productId.isEmpty) continue;
        final key = keyFor(panelCode, 'I/O Modülleri', module.first.productId);
        quantities.update(key, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    for (final solution in _hardwareSolutions) {
      final settings = _settingsForPanel(solution.panelCode);
      final panelCode = solution.panelCode.trim().isEmpty
          ? 'PANO BELİRTİLMEDİ'
          : solution.panelCode.trim().toUpperCase();
      if (settings.controllerHardwareId.isEmpty &&
          solution.role == PanelHardwareRole.controller &&
          solution.controller?.productId.isNotEmpty == true) {
        final key = keyFor(
          panelCode,
          'Kontrolörler',
          solution.controller!.productId,
        );
        quantities.update(key, (value) => value + 1, ifAbsent: () => 1);
      }
      if (settings.ioModuleHardwareIds.isEmpty) {
        for (final module in solution.modules) {
          if (module.productId.isEmpty) continue;
          final key = keyFor(panelCode, 'I/O Modülleri', module.productId);
          quantities.update(key, (value) => value + 1, ifAbsent: () => 1);
        }
      }
    }
    return [
      for (final entry in quantities.entries)
        () {
          final parts = entry.key.split('::');
          return QuoteInitialProductLine(
            sectionName: '${parts[0]} / ${parts[1]}',
            productId: parts[2],
            quantity: entry.value,
          );
        }(),
    ];
  }

  Future<void> _loadHardware() async {
    try {
      final results = await Future.wait([
        widget.hardwareRepository.fetchAll(),
        widget.productRepository.fetchProducts(),
        widget.repository.fetchDeviceTemplates(),
      ]);
      final hardware = results[0] as List<ControlHardware>;
      final products = results[1] as List<Product>;
      final templates = results[2] as List<DiscoveryDeviceTemplate>;
      if (!mounted) return;
      setState(() {
        _hardware = hardware;
        _products = products;
        _savedDeviceTemplates = templates;
        _loadingHardware = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHardware = false);
    }
  }

  Future<void> _openCategoryManagement() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ProductCategoryManagementPage(
          productRepository: widget.productRepository,
        ),
      ),
    );
    if (!mounted) return;
    final products = await widget.productRepository.fetchProducts();
    if (!mounted) return;
    setState(() => _products = products);
  }

  Future<void> _selectProduct(int deviceIndex, int pointIndex) async {
    final point = _devices[deviceIndex].points[pointIndex];
    final result = await showDialog<_ProductSelectionResult>(
      context: context,
      builder: (context) =>
          _DiscoveryProductPickerDialog(point: point, products: _products),
    );
    if (result == null) return;
    final device = _devices[deviceIndex];
    final points = List<DiscoveryPoint>.from(device.points);
    points[pointIndex] = point.copyWith(productId: result.product?.id ?? '');
    setState(() => _devices[deviceIndex] = device.copyWith(points: points));
  }

  Future<void> _save() async {
    if (_projectNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proje adı boş bırakılamaz.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.save(_currentProject);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Keşif kaydedilemedi: $error')));
    }
  }

  Future<void> _createQuote() async {
    final quantities = _selectedProductQuantities;
    final productLines = _selectedQuoteProductLines;
    if (quantities.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Teklife aktarılacak ürün yok. Önce noktalara veya panolara '
            'stok ürünü bağlayın.',
          ),
        ),
      );
      return;
    }
    if (_projectNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Önce proje adını girin.')));
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.repository.save(_currentProject);
      var availableProducts = _products;
      final hasMissingProduct = quantities.keys.any(
        (productId) =>
            !availableProducts.any((product) => product.id == productId),
      );
      if (hasMissingProduct) {
        availableProducts = await widget.productRepository.fetchProducts();
        if (mounted) setState(() => _products = availableProducts);
      }
      final rates = await widget.marketRateService.fetchRates();
      if (!mounted) return;
      setState(() => _saving = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => QuoteEditorPage(
            quoteRepository: widget.quoteRepository,
            initialRates: rates,
            availableProducts: availableProducts,
            initialProductLines: productLines,
            initialTitle: _projectNameController.text.trim(),
            userProfileRepository: widget.userProfileRepository,
            cariRepository: widget.cariRepository,
            ownCompanyRepository: widget.ownCompanyRepository,
            priceAdjustmentRuleRepository: widget.priceAdjustmentRuleRepository,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Teklif hazırlanamadı: $error')));
    }
  }

  Future<void> _addDevice() async {
    final existingPanelCodes = _existingPanelCodes;
    final result = await showDialog<_DeviceDialogResult>(
      context: context,
      builder: (context) => _DeviceDialog(
        templates: _availableDeviceTemplates,
        onSaveTemplate: _persistDeviceTemplate,
        panelSuggestions: DiscoveryPanelCodeSuggestions.build(
          existingPanelCodes,
        ),
        initialPanelCode: DiscoveryPanelCodeSuggestions.initialValue(
          existingPanelCodes,
        ),
      ),
    );
    if (result == null) return;
    final device = result.template
        .instantiate(
          id: _buildId('device'),
          panelCode: result.panelCode,
          deviceCode: result.deviceCode,
          idBuilder: _buildId,
        )
        .copyWith(name: result.deviceName);
    setState(() {
      _devices.add(device);
      _ensurePanelSettings(device.panelCode);
      _hardwareSolutions = const [];
    });
  }

  Future<void> _editDevice(int index) async {
    final source = _devices[index];
    final result = await showDialog<_DeviceDialogResult>(
      context: context,
      builder: (context) => _DeviceDialog(
        existing: source,
        templates: _availableDeviceTemplates,
        onSaveTemplate: _persistDeviceTemplate,
        panelSuggestions: DiscoveryPanelCodeSuggestions.build(
          _existingPanelCodes,
        ),
        initialPanelCode: source.panelCode,
      ),
    );
    if (result == null) return;
    setState(() {
      _devices[index] = source.copyWith(
        name: result.deviceName,
        templateKey: result.template.key,
        panelCode: result.panelCode,
        deviceCode: result.deviceCode,
      );
      _ensurePanelSettings(result.panelCode);
      _hardwareSolutions = const [];
    });
  }

  Future<void> _saveDeviceAsTemplate(int deviceIndex) async {
    final device = _devices[deviceIndex];
    final result = await showDialog<_SaveDeviceTemplateResult>(
      context: context,
      builder: (context) => _SaveDeviceTemplateDialog(device: device),
    );
    if (result == null) return;
    final template = DiscoveryDeviceTemplate(
      key: 'user-template-${DateTime.now().microsecondsSinceEpoch}',
      name: result.name,
      categoryName: result.categoryName,
      points: [
        for (final point in device.points)
          DiscoveryTemplatePoint(
            point.name,
            point.type,
            quantity: point.quantity,
            analogSignal: point.analogSignal,
          ),
      ],
    );
    final saved = await _persistDeviceTemplate(template);
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${template.name} şablonlara kaydedildi. Yeni keşiflerde '
            'Cihaz Ekle penceresinde görünecek.',
          ),
        ),
      );
    }
  }

  Future<bool> _persistDeviceTemplate(DiscoveryDeviceTemplate template) async {
    try {
      await widget.repository.saveDeviceTemplate(template);
      if (!mounted) return false;
      setState(() {
        final templates = List<DiscoveryDeviceTemplate>.from(
          _savedDeviceTemplates,
        );
        final index = templates.indexWhere((item) => item.key == template.key);
        if (index == -1) {
          templates.add(template);
        } else {
          templates[index] = template;
        }
        _savedDeviceTemplates = templates;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cihaz şablonu kaydedilemedi: $error')),
      );
      return false;
    }
  }

  Future<void> _deleteDevice(int index) async {
    final device = _devices[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cihaz kaldırılsın mı?'),
        content: Text(
          '${device.deviceCode.isEmpty ? device.name : device.deviceCode} ve '
          '${device.totalPoints} kontrol noktası keşiften kaldırılacak.',
        ),
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
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _devices.removeAt(index);
        _hardwareSolutions = const [];
      });
    }
  }

  Future<void> _addPoint(int deviceIndex) async {
    final point = await showDialog<DiscoveryPoint>(
      context: context,
      builder: (context) => _PointDialog(id: _buildId('point')),
    );
    if (point == null) return;
    final device = _devices[deviceIndex];
    setState(() {
      _devices[deviceIndex] = device.copyWith(
        points: [...device.points, point],
      );
      _hardwareSolutions = const [];
    });
  }

  Future<void> _editPoint(int deviceIndex, int pointIndex) async {
    final device = _devices[deviceIndex];
    final point = await showDialog<DiscoveryPoint>(
      context: context,
      builder: (context) => _PointDialog(
        id: device.points[pointIndex].id,
        existing: device.points[pointIndex],
      ),
    );
    if (point == null) return;
    final points = List<DiscoveryPoint>.from(device.points);
    points[pointIndex] = point;
    setState(() {
      _devices[deviceIndex] = device.copyWith(points: points);
      _hardwareSolutions = const [];
    });
  }

  void _deletePoint(int deviceIndex, int pointIndex) {
    final device = _devices[deviceIndex];
    final points = List<DiscoveryPoint>.from(device.points)
      ..removeAt(pointIndex);
    setState(() {
      _devices[deviceIndex] = device.copyWith(points: points);
      _hardwareSolutions = const [];
    });
  }

  void _ensurePanelSettings(String panelCode) {
    final code = panelCode.trim().toUpperCase();
    if (code.isEmpty ||
        _panelSettings.any((settings) => settings.panelCode == code)) {
      return;
    }
    _panelSettings.add(DiscoveryPanelSettings(panelCode: code));
  }

  DiscoveryPanelSettings _settingsForPanel(String panelCode) {
    final code = panelCode.trim().toUpperCase();
    for (final settings in _panelSettings) {
      if (settings.panelCode == code) return settings;
    }
    return DiscoveryPanelSettings(panelCode: code);
  }

  Future<void> _editPanelSettings(String panelCode) async {
    final current = _settingsForPanel(panelCode);
    final result = await showDialog<DiscoveryPanelSettings>(
      context: context,
      builder: (context) => _PanelSettingsDialog(
        settings: current,
        availableParentPanels: _existingPanelCodes
            .where((code) => code != panelCode)
            .toList(growable: false),
      ),
    );
    if (result == null) return;
    setState(() {
      final index = _panelSettings.indexWhere(
        (settings) => settings.panelCode == panelCode,
      );
      if (index == -1) {
        _panelSettings.add(result);
      } else {
        _panelSettings[index] = result;
      }
      _hardwareSolutions = const [];
    });
  }

  Future<void> _selectPanelController(String panelCode) async {
    final current = _settingsForPanel(panelCode);
    final controllers = _hardware
        .where(
          (item) =>
              item.type == ControlHardwareType.controller && item.isActive,
        )
        .toList(growable: false);
    final capacities = <String, PanelHardwareCapacity>{
      for (final controller in controllers)
        controller.id: const ControlHardwareSelector().evaluatePanelCapacity(
          project: _currentProject,
          panelCode: panelCode,
          equipment: [controller],
        ),
    };
    final modules = _hardware
        .where(
          (item) => item.type == ControlHardwareType.ioModule && item.isActive,
        )
        .toList(growable: false);
    final recommendations = <String, PanelHardwareSolution>{
      for (final controller in controllers)
        controller.id: const ControlHardwareSelector().recommendPanelSolution(
          project: _currentProject,
          panelCode: panelCode,
          controller: controller,
          availableModules: modules,
        ),
    };
    final result = await showDialog<_ControllerSelectionResult>(
      context: context,
      builder: (context) => _PanelControllerPickerDialog(
        controllers: controllers,
        products: _products,
        capacities: capacities,
        recommendations: recommendations,
        selectedControllerId: current.controllerHardwareId,
      ),
    );
    if (result == null) return;
    final updated = current.copyWith(
      controllerHardwareId: result.controller?.id ?? '',
      ioModuleHardwareIds: const [],
      mode: result.controller == null
          ? current.mode
          : DiscoveryPanelMode.controllerRequired,
      parentPanelCode: result.controller == null ? current.parentPanelCode : '',
    );
    setState(() {
      final index = _panelSettings.indexWhere(
        (settings) => settings.panelCode == panelCode,
      );
      if (index == -1) {
        _panelSettings.add(updated);
      } else {
        _panelSettings[index] = updated;
      }
      _hardwareSolutions = const [];
    });
  }

  Future<void> _managePanelModules(String panelCode) async {
    final controller = _selectedControllerForPanel(panelCode);
    if (controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bu pano için kontrolör seçin.')),
      );
      return;
    }
    final current = _settingsForPanel(panelCode);
    final result = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PanelIoModuleDialog(
        project: _currentProject,
        panelCode: panelCode,
        controller: controller,
        modules: _hardware
            .where((item) => item.type == ControlHardwareType.ioModule)
            .toList(growable: false),
        products: _products,
        selectedModuleIds: current.ioModuleHardwareIds,
      ),
    );
    if (result == null) return;
    final updated = current.copyWith(ioModuleHardwareIds: result);
    setState(() {
      final index = _panelSettings.indexWhere(
        (settings) => settings.panelCode == panelCode,
      );
      if (index == -1) {
        _panelSettings.add(updated);
      } else {
        _panelSettings[index] = updated;
      }
      _hardwareSolutions = const [];
    });
  }

  int _moduleCountForPanel(String panelCode) {
    return _settingsForPanel(panelCode).ioModuleHardwareIds.length;
  }

  ControlHardware? _selectedControllerForPanel(String panelCode) {
    final id = _settingsForPanel(panelCode).controllerHardwareId;
    if (id.isEmpty) return null;
    for (final item in _hardware) {
      if (item.id == id && item.type == ControlHardwareType.controller) {
        return item;
      }
    }
    return null;
  }

  PanelHardwareCapacity? _capacityForPanel(String panelCode) {
    final controller = _selectedControllerForPanel(panelCode);
    if (controller == null) return null;
    final settings = _settingsForPanel(panelCode);
    final equipment = <ControlHardware>[controller];
    for (final moduleId in settings.ioModuleHardwareIds) {
      for (final item in _hardware) {
        if (item.id == moduleId && item.type == ControlHardwareType.ioModule) {
          equipment.add(item);
          break;
        }
      }
    }
    return const ControlHardwareSelector().evaluatePanelCapacity(
      project: _currentProject,
      panelCode: panelCode,
      equipment: equipment,
    );
  }

  PanelHardwareSolution? _recommendationForPanel(String panelCode) {
    final controller = _selectedControllerForPanel(panelCode);
    if (controller == null) return null;
    return const ControlHardwareSelector().recommendPanelSolution(
      project: _currentProject,
      panelCode: panelCode,
      controller: controller,
      availableModules: _hardware
          .where(
            (item) =>
                item.type == ControlHardwareType.ioModule && item.isActive,
          )
          .toList(growable: false),
    );
  }

  void _applyPanelRecommendation(
    String panelCode,
    PanelHardwareSolution recommendation,
  ) {
    if (recommendation.modules.isEmpty) return;
    final current = _settingsForPanel(panelCode);
    final updated = current.copyWith(
      ioModuleHardwareIds: recommendation.modules
          .map((module) => module.id)
          .toList(growable: false),
    );
    setState(() {
      final index = _panelSettings.indexWhere(
        (settings) => settings.panelCode == panelCode,
      );
      if (index == -1) {
        _panelSettings.add(updated);
      } else {
        _panelSettings[index] = updated;
      }
      _hardwareSolutions = const [];
    });
  }

  Future<void> _analyzeHardware() async {
    if (_devices.isEmpty) return;
    if (_hardware.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce DDC/I/O kütüphanesine ekipman ekleyin.'),
        ),
      );
      return;
    }
    final inStockProductIds = _products
        .where((product) => product.isActive && product.stockQuantity > 0)
        .map((product) => product.id)
        .toSet();
    final linkedInStockCount = _hardware
        .where((item) => inStockProductIds.contains(item.productId))
        .length;
    final brands =
        _hardware
            .where((item) => inStockProductIds.contains(item.productId))
            .map((item) => item.brand.trim())
            .where((brand) => brand.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final decision = await showDialog<_HardwareRuleDecision>(
      context: context,
      builder: (context) => _HardwareRuleDialog(
        panels: _existingPanelCodes,
        brands: brands,
        linkedInStockCount: linkedInStockCount,
      ),
    );
    if (decision == null || !mounted) return;

    final panelCodes = _existingPanelCodes;
    var analysisProject = _currentProject;
    if (decision.architecture == _HardwareArchitectureRule.panelSettings) {
      analysisProject = analysisProject.copyWith(
        panelSettings: [
          for (final panelCode in panelCodes)
            _settingsForPanel(panelCode).mode == DiscoveryPanelMode.automatic
                ? _settingsForPanel(
                    panelCode,
                  ).copyWith(mode: DiscoveryPanelMode.controllerRequired)
                : _settingsForPanel(panelCode),
        ],
      );
    } else {
      final firstPanel = panelCodes.isEmpty ? '' : panelCodes.first;
      analysisProject = analysisProject.copyWith(
        panelSettings: [
          for (final panelCode in panelCodes)
            DiscoveryPanelSettings(
              panelCode: panelCode,
              mode:
                  _settingsForPanel(
                        panelCode,
                      ).controllerHardwareId.isNotEmpty ||
                      decision.architecture ==
                          _HardwareArchitectureRule.independentControllers ||
                      panelCode == firstPanel
                  ? DiscoveryPanelMode.controllerRequired
                  : DiscoveryPanelMode.remoteAllowed,
              parentPanelCode:
                  _settingsForPanel(panelCode).controllerHardwareId.isEmpty &&
                      decision.architecture ==
                          _HardwareArchitectureRule.remoteIoPreferred &&
                      panelCode != firstPanel
                  ? firstPanel
                  : '',
              controllerHardwareId: _settingsForPanel(
                panelCode,
              ).controllerHardwareId,
            ),
        ],
      );
    }
    final solutions = const ControlHardwareSelector().select(
      project: analysisProject,
      hardware: _hardware,
      rules: ControlHardwareSelectionRules(
        preferredBrand: decision.brand,
        reservePercent: decision.reservePercent,
        onlyLinkedProductsInStock: decision.onlyInStock,
        inStockProductIds: inStockProductIds,
      ),
    );
    setState(() {
      _hardwareSolutions = solutions;
      for (final solution in solutions) {
        final index = _panelSettings.indexWhere(
          (settings) => settings.panelCode == solution.panelCode,
        );
        final current = index == -1
            ? DiscoveryPanelSettings(panelCode: solution.panelCode)
            : _panelSettings[index];
        final updated = current.copyWith(
          ioModuleHardwareIds: solution.modules
              .map((module) => module.id)
              .toList(growable: false),
        );
        if (index == -1) {
          _panelSettings.add(updated);
        } else {
          _panelSettings[index] = updated;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final project = _currentProject;
    final selectedProductQuantities = _selectedProductQuantities;
    final selectedProductCount = selectedProductQuantities.values.fold<int>(
      0,
      (sum, quantity) => sum + quantity,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keşif Düzenle'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.tonalIcon(
              onPressed: _saving ? null : _createQuote,
              icon: const Icon(Icons.request_quote_rounded),
              label: Text(
                selectedProductQuantities.isEmpty
                    ? 'Teklif Oluştur'
                    : 'Teklif Oluştur · $selectedProductCount ürün',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Kaydet'),
            ),
          ),
        ],
      ),
      body: WorkspaceBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            _buildProjectInformation(),
            const SizedBox(height: 14),
            _PointSummary(project: project),
            const SizedBox(height: 14),
            _buildPlacedProductSummary(),
            const SizedBox(height: 14),
            _buildHardwareAnalysis(),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cihazlar ve Kontrol Noktaları',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addDevice,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Cihaz Ekle'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_devices.isEmpty)
              _buildEmptyDevices()
            else
              _buildGroupedDevices(),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectInformation() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Proje Bilgileri',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 360,
                  child: TextField(
                    controller: _projectNameController,
                    decoration: const InputDecoration(labelText: 'Proje adı *'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: TextField(
                    controller: _projectCodeController,
                    decoration: const InputDecoration(labelText: 'Proje kodu'),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _revisionController,
                    decoration: const InputDecoration(labelText: 'Revizyon'),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _preparedByController,
                    decoration: const InputDecoration(labelText: 'Hazırlayan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareAnalysis() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub_rounded),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kurallı DDC / I/O Çözümü',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'Mimari, marka, stok ve yedek kapasite kararlarını '
                        'siz verin; sistem uygun cihazları hesaplasın.',
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loadingHardware ? null : _analyzeHardware,
                  icon: _loadingHardware
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Kuralları Belirle'),
                ),
              ],
            ),
            if (_hardwareSolutions.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final solution in _hardwareSolutions) ...[
                _HardwareSolutionTile(solution: solution),
                if (solution != _hardwareSolutions.last)
                  const SizedBox(height: 9),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlacedProductSummary() {
    final productsById = {for (final product in _products) product.id: product};
    final quantities = _selectedProductQuantities;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.playlist_add_check_circle_outlined),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Keşfe Yerleştirilen Ürünler',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Chip(label: Text('${quantities.length} kalem')),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _openCategoryManagement,
                  icon: const Icon(Icons.category_outlined),
                  label: const Text('Kategorileri Düzenle'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (quantities.isEmpty)
              const Text(
                'Henüz bir noktaya ürün yerleştirilmedi. Nokta satırındaki '
                '“Ürün Seç” alanını kullanabilirsiniz.',
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in quantities.entries)
                    Builder(
                      builder: (context) {
                        final product = productsById[entry.key];
                        return Chip(
                          avatar: const Icon(
                            Icons.inventory_2_outlined,
                            size: 17,
                          ),
                          label: Text(
                            product == null
                                ? '${entry.value} × Kayıtlı ürün'
                                : '${entry.value} × ${product.code} · '
                                      '${product.name}',
                          ),
                        );
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDevices() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          children: [
            const Icon(Icons.precision_manufacturing_outlined, size: 44),
            const SizedBox(height: 12),
            Text(
              'Bu keşifte henüz cihaz yok',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Pompa, kazan veya klima santrali eklediğinizde kontrol '
              'noktaları otomatik oluşturulur.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedDevices() {
    final panels = <String, List<_IndexedDevice>>{};
    for (var index = 0; index < _devices.length; index++) {
      final device = _devices[index];
      final panelCode = device.panelCode.trim().isEmpty
          ? 'PANO BELİRTİLMEDİ'
          : device.panelCode.trim().toUpperCase();
      panels
          .putIfAbsent(panelCode, () => <_IndexedDevice>[])
          .add(_IndexedDevice(index: index, device: device));
    }

    return Column(
      children: [
        for (final panelEntry in panels.entries) ...[
          _buildPanelGroup(panelEntry.key, panelEntry.value),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildPanelGroup(String panelCode, List<_IndexedDevice> devices) {
    final categories = <String, List<_IndexedDevice>>{};
    for (final indexed in devices) {
      categories
          .putIfAbsent(indexed.device.templateKey, () => <_IndexedDevice>[])
          .add(indexed);
    }
    final panelPointCounts = <DiscoveryPointType, int>{
      for (final type in DiscoveryPointType.values)
        type: devices.fold(
          0,
          (total, indexed) => total + indexed.device.countFor(type),
        ),
    };
    final capacity = _capacityForPanel(panelCode);
    final recommendation = capacity?.isSatisfied == false
        ? _recommendationForPanel(panelCode)
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.developer_board_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        panelCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 7,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${devices.length} cihaz',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ActionChip(
                        avatar: const Icon(
                          Icons.account_tree_outlined,
                          size: 18,
                        ),
                        label: Text(_settingsForPanel(panelCode).mode.label),
                        onPressed: () => _editPanelSettings(panelCode),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.memory_rounded, size: 18),
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 210),
                          child: Text(
                            _selectedControllerForPanel(
                                  panelCode,
                                )?.displayName ??
                                'Kontrolör Seç',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        onPressed: () => _selectPanelController(panelCode),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.extension_rounded, size: 18),
                        label: Text(
                          'I/O Modülleri (${_moduleCountForPanel(panelCode)})',
                        ),
                        onPressed: () => _managePanelModules(panelCode),
                      ),
                      _InlinePanelPointTotals(counts: panelPointCounts),
                    ],
                  ),
                ),
              ],
            ),
            if (capacity != null) ...[
              const SizedBox(height: 12),
              _PanelCapacitySummary(
                capacity: capacity,
                recommendation: recommendation,
                onApplyRecommendation:
                    recommendation != null &&
                        recommendation.modules.isNotEmpty &&
                        recommendation.matchedPoints > capacity.matchedTotal
                    ? () => _applyPanelRecommendation(panelCode, recommendation)
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            for (final categoryEntry in categories.entries) ...[
              _buildDeviceCategory(categoryEntry.key, categoryEntry.value),
              if (categoryEntry.key != categories.keys.last)
                const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCategory(
    String templateKey,
    List<_IndexedDevice> devices,
  ) {
    final categoryName =
        DiscoveryTemplates.findByKey(templateKey)?.categoryName ?? 'Diğer';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Row(
              children: [
                Icon(
                  _categoryIcon(templateKey),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  categoryName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('${devices.length}'),
                ),
              ],
            ),
          ),
          for (final indexed in devices) ...[
            _DevicePointCard(
              device: indexed.device,
              products: _products,
              onAddPoint: () => _addPoint(indexed.index),
              onEditDevice: () => _editDevice(indexed.index),
              onDeleteDevice: () => _deleteDevice(indexed.index),
              onSaveTemplate: () => _saveDeviceAsTemplate(indexed.index),
              onEditPoint: (pointIndex) =>
                  _editPoint(indexed.index, pointIndex),
              onDeletePoint: (pointIndex) =>
                  _deletePoint(indexed.index, pointIndex),
              onSelectProduct: (pointIndex) =>
                  _selectProduct(indexed.index, pointIndex),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  IconData _categoryIcon(String templateKey) {
    return switch (templateKey) {
      'pump' => Icons.water_rounded,
      'boiler' => Icons.local_fire_department_rounded,
      'ahu' => Icons.air_rounded,
      _ => Icons.precision_manufacturing_rounded,
    };
  }
}

class _IndexedDevice {
  const _IndexedDevice({required this.index, required this.device});

  final int index;
  final DiscoveryDevice device;
}

class _PanelCapacitySummary extends StatelessWidget {
  const _PanelCapacitySummary({
    required this.capacity,
    required this.recommendation,
    required this.onApplyRecommendation,
  });

  final PanelHardwareCapacity capacity;
  final PanelHardwareSolution? recommendation;
  final VoidCallback? onApplyRecommendation;

  static const _physicalPointTypes = [
    DiscoveryPointType.aiActive,
    DiscoveryPointType.aiPassive,
    DiscoveryPointType.ao,
    DiscoveryPointType.di,
    DiscoveryPointType.doOutput,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = capacity.isSatisfied
        ? const Color(0xFF2C7A5A)
        : colors.error;
    final headline = capacity.isSatisfied
        ? 'Kapasite yeterli'
        : 'Kapasite yetersiz';
    final detail = capacity.isSatisfied
        ? '${capacity.matchedTotal}/${capacity.requiredTotal} fiziksel nokta '
              'karşılandı · ${capacity.remainingChannels} boş kanal'
        : '${capacity.matchedTotal}/${capacity.requiredTotal} fiziksel nokta '
              'karşılandı · ${capacity.unmetTotal} nokta eksik';
    final recommendedModules = _moduleCounts(
      recommendation?.modules ?? const [],
    );
    final recommendationText = recommendedModules.isEmpty
        ? 'Uygun tamamlayıcı I/O modülü bulunamadı. DDC/I/O '
              'kütüphanesinde uyumlu modül ve genişleme sınırını kontrol edin.'
        : '${recommendation!.isSatisfied ? "Öneri" : "En iyi mevcut öneri"}: '
              '${recommendedModules.entries.map((entry) => '${entry.value} × ${entry.key}').join(', ')} ekle'
              '${recommendation!.isSatisfied ? " → bütün noktalar karşılanır." : " → ${recommendation!.unmetTotal} nokta yine eksik kalır."}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                capacity.isSatisfied
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: statusColor,
                size: 20,
              ),
              Text(
                headline,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(detail, style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final type in _physicalPointTypes)
                if ((capacity.requiredPoints[type] ?? 0) > 0)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      '${type.label} '
                      '${capacity.matchedPoints[type] ?? 0}/'
                      '${capacity.requiredPoints[type]}'
                      '${(capacity.unmetPoints[type] ?? 0) > 0 ? " · Eksik ${capacity.unmetPoints[type]}" : ""}',
                    ),
                  ),
            ],
          ),
          if (!capacity.isSatisfied) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  recommendedModules.isEmpty
                      ? Icons.info_outline_rounded
                      : Icons.auto_awesome_rounded,
                  color: recommendedModules.isEmpty
                      ? colors.onSurfaceVariant
                      : colors.primary,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recommendationText,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (onApplyRecommendation != null) ...[
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: onApplyRecommendation,
                    icon: const Icon(Icons.add_task_rounded, size: 18),
                    label: const Text('Öneriyi Uygula'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Map<String, int> _moduleCounts(List<ControlHardware> modules) {
    final result = <String, int>{};
    for (final module in modules) {
      result.update(
        module.displayName,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return result;
  }
}

class _HardwareSolutionTile extends StatelessWidget {
  const _HardwareSolutionTile({required this.solution});

  final PanelHardwareSolution solution;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = solution.isSatisfied
        ? const Color(0xFF2C7A5A)
        : colors.error;
    final equipment = <String>[
      if (solution.role == PanelHardwareRole.controller &&
          solution.controller != null)
        '1 × ${solution.controller!.displayName}',
      for (final entry in _moduleCounts(solution.modules).entries)
        '${entry.value} × ${entry.key}',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colors.outlineVariant),
        color: statusColor.withValues(alpha: 0.06),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            solution.isSatisfied
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            color: statusColor,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      solution.panelCode,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(solution.role.label),
                    ),
                    if (solution.parentPanelCode.isNotEmpty)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.link_rounded, size: 17),
                        label: Text('Ana pano: ${solution.parentPanelCode}'),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  equipment.isEmpty
                      ? 'Uygun ekipman kombinasyonu bulunamadı.'
                      : equipment.join('  •  '),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${solution.matchedPoints} / ${solution.totalDemand} '
                  'fiziksel nokta karşılandı',
                ),
                if (solution.unmetPoints.isNotEmpty)
                  Text(
                    'Eksik: ${solution.unmetPoints.entries.map((entry) => '${entry.value} ${entry.key.label}').join(', ')}',
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (solution.warning.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    solution.warning,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _moduleCounts(List<ControlHardware> modules) {
    final result = <String, int>{};
    for (final module in modules) {
      result.update(
        module.displayName,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return result;
  }
}

class _ControllerSelectionResult {
  const _ControllerSelectionResult(this.controller);

  final ControlHardware? controller;
}

class _PanelControllerPickerDialog extends StatefulWidget {
  const _PanelControllerPickerDialog({
    required this.controllers,
    required this.products,
    required this.capacities,
    required this.recommendations,
    required this.selectedControllerId,
  });

  final List<ControlHardware> controllers;
  final List<Product> products;
  final Map<String, PanelHardwareCapacity> capacities;
  final Map<String, PanelHardwareSolution> recommendations;
  final String selectedControllerId;

  @override
  State<_PanelControllerPickerDialog> createState() =>
      _PanelControllerPickerDialogState();
}

class _PanelControllerPickerDialogState
    extends State<_PanelControllerPickerDialog> {
  String _query = '';
  bool _onlyInStock = true;

  Product? _linkedProduct(ControlHardware controller) {
    for (final product in widget.products) {
      if (product.id == controller.productId) return product;
    }
    return null;
  }

  List<ControlHardware> get _visibleControllers {
    final query = _query.trim().toLowerCase();
    final controllers = widget.controllers.where((controller) {
      final product = _linkedProduct(controller);
      if (_onlyInStock &&
          (product == null ||
              !product.isActive ||
              product.stockQuantity <= 0)) {
        return false;
      }
      if (query.isEmpty) return true;
      return [
        controller.brand,
        controller.model,
        controller.family,
        product?.code ?? '',
        product?.name ?? '',
      ].join(' ').toLowerCase().contains(query);
    }).toList();
    controllers.sort((left, right) {
      final leftCapacity = widget.capacities[left.id];
      final rightCapacity = widget.capacities[right.id];
      if (leftCapacity != null && rightCapacity != null) {
        final leftRank = _recommendationRank(left.id, leftCapacity);
        final rightRank = _recommendationRank(right.id, rightCapacity);
        if (leftRank != rightRank) {
          return leftRank.compareTo(rightRank);
        }
        final fitComparison = leftRank == 0
            ? leftCapacity.remainingChannels.compareTo(
                rightCapacity.remainingChannels,
              )
            : (widget.recommendations[left.id]?.unmetTotal ?? 1 << 20)
                  .compareTo(
                    widget.recommendations[right.id]?.unmetTotal ?? 1 << 20,
                  );
        if (fitComparison != 0) return fitComparison;
      }
      return left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      );
    });
    return controllers;
  }

  int _recommendationRank(String controllerId, PanelHardwareCapacity capacity) {
    if (capacity.isSatisfied) return 0;
    if (widget.recommendations[controllerId]?.isSatisfied == true) return 1;
    return 2;
  }

  String _capacityRecommendationText(
    ControlHardware controller,
    PanelHardwareCapacity? capacity,
  ) {
    if (capacity == null) return 'Kapasite hesaplanamadı';
    if (capacity.isSatisfied) {
      return 'TEK BAŞINA YETERLİ · ${capacity.remainingChannels} boş kanal';
    }
    final recommendation = widget.recommendations[controller.id];
    final moduleCounts = <String, int>{};
    for (final module in recommendation?.modules ?? const <ControlHardware>[]) {
      moduleCounts.update(
        module.displayName,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    if (moduleCounts.isEmpty) {
      return 'TEK BAŞINA YETERSİZ · ${capacity.unmetTotal} nokta eksik · '
          'uygun tamamlayıcı modül yok';
    }
    final modules = moduleCounts.entries
        .map((entry) => '${entry.value}× ${entry.key}')
        .join(', ');
    return 'TEK BAŞINA YETERSİZ · ${capacity.unmetTotal} eksik · '
        'ÖNERİ: $modules'
        '${recommendation!.isSatisfied ? " ile yeterli" : " ile ${recommendation.unmetTotal} eksik kalır"}';
  }

  @override
  Widget build(BuildContext context) {
    final controllers = _visibleControllers;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.memory_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Panoya Kontrolör Eşleştir',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (widget.selectedControllerId.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        const _ControllerSelectionResult(null),
                      ),
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('Eşleştirmeyi Kaldır'),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Marka, model veya ürün kodu ara',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    selected: _onlyInStock,
                    label: const Text('Yalnız stoktakiler'),
                    onSelected: (value) => setState(() => _onlyInStock = value),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${controllers.length} kontrolör · '
                'Pano ihtiyacı: '
                '${widget.capacities.values.isEmpty ? 0 : widget.capacities.values.first.requiredTotal} '
                'fiziksel nokta · Yeterli olanlar üstte',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: controllers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.memory_outlined, size: 42),
                            const SizedBox(height: 10),
                            Text(
                              _onlyInStock
                                  ? 'Stokla eşleştirilmiş kontrolör bulunamadı.'
                                  : 'DDC/I/O kütüphanesinde kontrolör bulunamadı.',
                            ),
                            if (_onlyInStock) ...[
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: () =>
                                    setState(() => _onlyInStock = false),
                                child: const Text(
                                  'Stokta Olmayanları da Göster',
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: controllers.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final controller = controllers[index];
                          final product = _linkedProduct(controller);
                          final capacity = widget.capacities[controller.id];
                          final selected =
                              controller.id == widget.selectedControllerId;
                          final channels = controller.channelPools
                              .map((pool) => '${pool.quantity} ${pool.name}')
                              .join(' · ');
                          return ListTile(
                            selected: selected,
                            leading: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.memory_outlined,
                            ),
                            title: Text(
                              controller.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            subtitle: Text(
                              '${product == null ? "Stok ürünü bağlı değil" : "${product.code} · ${product.formattedStock}"}\n'
                              '${channels.isEmpty ? "Dahili I/O yok" : channels} · '
                              'En fazla ${controller.maxExpansionModules} modül\n'
                              '${_capacityRecommendationText(controller, capacity)}',
                            ),
                            isThreeLine: true,
                            trailing:
                                product != null &&
                                    product.isActive &&
                                    product.stockQuantity > 0
                                ? const Chip(label: Text('Stokta'))
                                : const Chip(label: Text('Stok dışı')),
                            onTap: () => Navigator.pop(
                              context,
                              _ControllerSelectionResult(controller),
                            ),
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

class _PanelIoModuleDialog extends StatefulWidget {
  const _PanelIoModuleDialog({
    required this.project,
    required this.panelCode,
    required this.controller,
    required this.modules,
    required this.products,
    required this.selectedModuleIds,
  });

  final DiscoveryProject project;
  final String panelCode;
  final ControlHardware controller;
  final List<ControlHardware> modules;
  final List<Product> products;
  final List<String> selectedModuleIds;

  @override
  State<_PanelIoModuleDialog> createState() => _PanelIoModuleDialogState();
}

class _PanelIoModuleDialogState extends State<_PanelIoModuleDialog> {
  final _selector = const ControlHardwareSelector();
  late final List<String> _selectedIds;
  String _query = '';
  bool _onlyCompatible = true;
  bool _onlyInStock = false;

  @override
  void initState() {
    super.initState();
    _selectedIds = List<String>.from(widget.selectedModuleIds);
  }

  Product? _linkedProduct(ControlHardware module) {
    for (final product in widget.products) {
      if (product.id == module.productId) return product;
    }
    return null;
  }

  ControlHardware? _moduleById(String id) {
    for (final module in widget.modules) {
      if (module.id == id) return module;
    }
    return null;
  }

  List<ControlHardware> get _selectedModules {
    final result = <ControlHardware>[];
    for (final id in _selectedIds) {
      final module = _moduleById(id);
      if (module != null &&
          module.isActive &&
          _selector.isModuleCompatible(
            module: module,
            controller: widget.controller,
          )) {
        result.add(module);
      }
    }
    return result;
  }

  Map<String, int> get _selectedCounts {
    final result = <String, int>{};
    for (final id in _selectedIds) {
      result.update(id, (count) => count + 1, ifAbsent: () => 1);
    }
    return result;
  }

  PanelHardwareCapacity get _capacity => _selector.evaluatePanelCapacity(
    project: widget.project,
    panelCode: widget.panelCode,
    equipment: [widget.controller, ..._selectedModules],
  );

  List<ControlHardware> get _visibleModules {
    final query = _query.trim().toLowerCase();
    final modules = widget.modules.where((module) {
      if (!module.isActive) return false;
      final compatible = _selector.isModuleCompatible(
        module: module,
        controller: widget.controller,
      );
      if (_onlyCompatible && !compatible) return false;
      final product = _linkedProduct(module);
      if (_onlyInStock &&
          (product == null ||
              !product.isActive ||
              product.stockQuantity <= 0)) {
        return false;
      }
      if (query.isEmpty) return true;
      return [
        module.brand,
        module.model,
        module.family,
        module.connectionProtocol,
        product?.code ?? '',
        product?.name ?? '',
      ].join(' ').toLowerCase().contains(query);
    }).toList();
    modules.sort((left, right) {
      final leftCompatible = _selector.isModuleCompatible(
        module: left,
        controller: widget.controller,
      );
      final rightCompatible = _selector.isModuleCompatible(
        module: right,
        controller: widget.controller,
      );
      if (leftCompatible != rightCompatible) return leftCompatible ? -1 : 1;
      return left.displayName.toLowerCase().compareTo(
        right.displayName.toLowerCase(),
      );
    });
    return modules;
  }

  void _addModule(ControlHardware module) {
    final compatible = _selector.isModuleCompatible(
      module: module,
      controller: widget.controller,
    );
    if (!compatible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bu modül seçilen kontrolörle uyumlu değil. Önce DDC/I/O '
            'kütüphanesindeki aile veya protokol ayarını düzeltin.',
          ),
        ),
      );
      return;
    }
    if (_selectedIds.length >= widget.controller.maxExpansionModules) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kontrolör en fazla ${widget.controller.maxExpansionModules} '
            'genişleme modülü destekliyor.',
          ),
        ),
      );
      return;
    }
    setState(() => _selectedIds.add(module.id));
  }

  void _removeModule(String moduleId) {
    final index = _selectedIds.lastIndexOf(moduleId);
    if (index == -1) return;
    setState(() => _selectedIds.removeAt(index));
  }

  String _channelSummary(ControlHardware module) {
    if (module.channelPools.isEmpty) return 'Fiziksel kanal tanımlı değil';
    return module.channelPools
        .map((pool) => '${pool.quantity} ${pool.name}')
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final capacity = _capacity;
    final visibleModules = _visibleModules;
    final counts = _selectedCounts;
    final statusColor = capacity.isSatisfied
        ? const Color(0xFF2C7A5A)
        : colors.error;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 820),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 14, 14),
              child: Row(
                children: [
                  const Icon(Icons.extension_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.panelCode} I/O Modülleri',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '${widget.controller.displayName} · '
                          '${_selectedIds.length}/'
                          '${widget.controller.maxExpansionModules} modül',
                        ),
                      ],
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Wrap(
                  spacing: 9,
                  runSpacing: 7,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      capacity.isSatisfied
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: statusColor,
                    ),
                    Text(
                      capacity.isSatisfied
                          ? 'Kapasite yeterli'
                          : 'Kapasite yetersiz',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${capacity.matchedTotal}/${capacity.requiredTotal} '
                      'nokta karşılandı',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        capacity.isSatisfied
                            ? '${capacity.remainingChannels} boş kanal'
                            : '${capacity.unmetTotal} eksik nokta',
                      ),
                    ),
                    for (final entry in capacity.unmetPoints.entries)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('${entry.key.label} eksik ${entry.value}'),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Modül, aile, protokol veya ürün kodu ara',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilterChip(
                    selected: _onlyCompatible,
                    label: const Text('Yalnız uyumlu'),
                    onSelected: (value) =>
                        setState(() => _onlyCompatible = value),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    selected: _onlyInStock,
                    label: const Text('Yalnız stokta'),
                    onSelected: (value) => setState(() => _onlyInStock = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  Row(
                    children: [
                      Text(
                        'Seçilen Modüller',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('${_selectedIds.length}'),
                      ),
                      const Spacer(),
                      if (_selectedIds.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => setState(_selectedIds.clear),
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: const Text('Tümünü Kaldır'),
                        ),
                    ],
                  ),
                  if (counts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Bu panoya henüz I/O modülü eklenmedi.'),
                    )
                  else
                    for (final entry in counts.entries)
                      Builder(
                        builder: (context) {
                          final module = _moduleById(entry.key);
                          if (module == null) return const SizedBox.shrink();
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.extension_rounded),
                              title: Text(
                                module.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              subtitle: Text(
                                '${_channelSummary(module)} · '
                                '${!module.isActive
                                    ? "Pasif"
                                    : _selector.isModuleCompatible(module: module, controller: widget.controller)
                                    ? "Uyumlu"
                                    : "Uyumsuz — kapasiteye dahil edilmez"}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Bir adet azalt',
                                    onPressed: () => _removeModule(module.id),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Text(
                                    '${entry.value}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Bir adet artır',
                                    onPressed: () => _addModule(module),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  const Divider(height: 28),
                  Text(
                    'Eklenebilir Modüller (${visibleModules.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (visibleModules.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('Filtreye uygun I/O modülü bulunamadı.'),
                      ),
                    )
                  else
                    for (final module in visibleModules)
                      Builder(
                        builder: (context) {
                          final compatible = _selector.isModuleCompatible(
                            module: module,
                            controller: widget.controller,
                          );
                          final product = _linkedProduct(module);
                          return ListTile(
                            leading: Icon(
                              compatible
                                  ? Icons.extension_rounded
                                  : Icons.link_off_rounded,
                            ),
                            title: Text(
                              module.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              '${_channelSummary(module)}\n'
                              '${product == null ? "Stok ürünü bağlı değil" : "${product.code} · ${product.formattedStock}"} · '
                              '${compatible ? "Uyumlu" : "Uyumsuz"}',
                            ),
                            isThreeLine: true,
                            trailing: FilledButton.tonalIcon(
                              onPressed:
                                  compatible &&
                                      _selectedIds.length <
                                          widget.controller.maxExpansionModules
                                  ? () => _addModule(module)
                                  : null,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Ekle'),
                            ),
                          );
                        },
                      ),
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
                    onPressed: () =>
                        Navigator.pop(context, List<String>.from(_selectedIds)),
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Modülleri Kaydet'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _HardwareArchitectureRule {
  panelSettings,
  independentControllers,
  remoteIoPreferred,
}

class _HardwareRuleDecision {
  const _HardwareRuleDecision({
    required this.architecture,
    required this.brand,
    required this.reservePercent,
    required this.onlyInStock,
  });

  final _HardwareArchitectureRule architecture;
  final String brand;
  final int reservePercent;
  final bool onlyInStock;
}

class _HardwareRuleDialog extends StatefulWidget {
  const _HardwareRuleDialog({
    required this.panels,
    required this.brands,
    required this.linkedInStockCount,
  });

  final List<String> panels;
  final List<String> brands;
  final int linkedInStockCount;

  @override
  State<_HardwareRuleDialog> createState() => _HardwareRuleDialogState();
}

class _HardwareRuleDialogState extends State<_HardwareRuleDialog> {
  _HardwareArchitectureRule _architecture =
      _HardwareArchitectureRule.panelSettings;
  String _brand = '';
  int _reservePercent = 10;
  bool _onlyInStock = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.rule_rounded),
          SizedBox(width: 10),
          Text('DDC / I/O seçim kuralları'),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.panels.length} pano için çözüm hazırlanacak. '
                'Kararı sistem değil, aşağıdaki mühendislik kuralları verir.',
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<_HardwareArchitectureRule>(
                initialValue: _architecture,
                decoration: const InputDecoration(
                  labelText: '1. Pano mimarisi',
                  prefixIcon: Icon(Icons.account_tree_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: _HardwareArchitectureRule.panelSettings,
                    child: Text(
                      'Pano kararlarımı kullan; tanımsızsa kontrolör seç',
                    ),
                  ),
                  DropdownMenuItem(
                    value: _HardwareArchitectureRule.independentControllers,
                    child: Text('Her panoda bağımsız kontrolör olsun'),
                  ),
                  DropdownMenuItem(
                    value: _HardwareArchitectureRule.remoteIoPreferred,
                    child: Text('İlk pano ana kontrolör, diğerleri Remote I/O'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _architecture = value);
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _brand,
                decoration: const InputDecoration(
                  labelText: '2. Marka tercihi',
                  prefixIcon: Icon(Icons.factory_outlined),
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Marka fark etmez'),
                  ),
                  for (final brand in widget.brands)
                    DropdownMenuItem(value: brand, child: Text(brand)),
                ],
                onChanged: (value) => setState(() => _brand = value ?? ''),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _reservePercent,
                decoration: const InputDecoration(
                  labelText: '3. Yedek I/O kapasitesi',
                  prefixIcon: Icon(Icons.safety_check_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Yedek bırakma')),
                  DropdownMenuItem(value: 10, child: Text('%10 yedek')),
                  DropdownMenuItem(value: 20, child: Text('%20 yedek')),
                  DropdownMenuItem(value: 30, child: Text('%30 yedek')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _reservePercent = value);
                },
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: const Text('Yalnız stokta bulunan cihazları kullan'),
                subtitle: Text(
                  '${widget.linkedInStockCount} DDC/I/O ekipmanı stok ürünüyle '
                  'bağlantılı ve kullanılabilir.',
                ),
                value: _onlyInStock,
                onChanged: (value) => setState(() => _onlyInStock = value),
              ),
              if (_onlyInStock && widget.linkedInStockCount == 0)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Stokla bağlantılı DDC/I/O bulunmuyor. Önce kütüphanede '
                    'cihazı bir stok ürünüyle eşleştirin.',
                    style: TextStyle(
                      color: Color(0xFF9D3418),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton.icon(
          onPressed: _onlyInStock && widget.linkedInStockCount == 0
              ? null
              : () => Navigator.pop(
                  context,
                  _HardwareRuleDecision(
                    architecture: _architecture,
                    brand: _brand,
                    reservePercent: _reservePercent,
                    onlyInStock: _onlyInStock,
                  ),
                ),
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Çözümleri Hesapla'),
        ),
      ],
    );
  }
}

class _PanelSettingsDialog extends StatefulWidget {
  const _PanelSettingsDialog({
    required this.settings,
    required this.availableParentPanels,
  });

  final DiscoveryPanelSettings settings;
  final List<String> availableParentPanels;

  @override
  State<_PanelSettingsDialog> createState() => _PanelSettingsDialogState();
}

class _PanelSettingsDialogState extends State<_PanelSettingsDialog> {
  late DiscoveryPanelMode _mode;
  late String _parentPanelCode;

  @override
  void initState() {
    super.initState();
    _mode = widget.settings.mode;
    _parentPanelCode =
        widget.availableParentPanels.contains(widget.settings.parentPanelCode)
        ? widget.settings.parentPanelCode
        : '';
  }

  bool get _canUseRemote =>
      _mode == DiscoveryPanelMode.remoteAllowed ||
      _mode == DiscoveryPanelMode.remoteOnly ||
      _mode == DiscoveryPanelMode.automatic;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.settings.panelCode} Çözüm Ayarı'),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<DiscoveryPanelMode>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: 'Pano çalışma rolü'),
              items: DiscoveryPanelMode.values
                  .map(
                    (mode) =>
                        DropdownMenuItem(value: mode, child: Text(mode.label)),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _mode = value;
                    if (!_canUseRemote) _parentPanelCode = '';
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _parentPanelCode,
              decoration: const InputDecoration(
                labelText: 'Ana kontrolör panosu',
                helperText:
                    'Boş bırakılırsa önceki uygun pano otomatik seçilir.',
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('Otomatik seç')),
                for (final panelCode in widget.availableParentPanels)
                  DropdownMenuItem(value: panelCode, child: Text(panelCode)),
              ],
              onChanged: _canUseRemote
                  ? (value) => setState(() => _parentPanelCode = value ?? '')
                  : null,
            ),
            const SizedBox(height: 12),
            const Text(
              'Remote I/O çözümü yalnız seçilen ana kontrolörle uyumlu '
              'modül ve yeterli modül kapasitesi varsa önerilir.',
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
            Navigator.pop(
              context,
              DiscoveryPanelSettings(
                panelCode: widget.settings.panelCode,
                mode: _mode,
                parentPanelCode: _canUseRemote ? _parentPanelCode : '',
                controllerHardwareId: _mode == DiscoveryPanelMode.remoteOnly
                    ? ''
                    : widget.settings.controllerHardwareId,
                ioModuleHardwareIds: _mode == DiscoveryPanelMode.remoteOnly
                    ? const []
                    : widget.settings.ioModuleHardwareIds,
              ),
            );
          },
          child: const Text('Uygula'),
        ),
      ],
    );
  }
}

class _PointSummary extends StatelessWidget {
  const _PointSummary({required this.project});

  final DiscoveryProject project;

  @override
  Widget build(BuildContext context) {
    const visibleTypes = [
      DiscoveryPointType.aiActive,
      DiscoveryPointType.aiPassive,
      DiscoveryPointType.ao,
      DiscoveryPointType.di,
      DiscoveryPointType.doOutput,
      DiscoveryPointType.modbusRtu,
      DiscoveryPointType.modbusTcp,
      DiscoveryPointType.bacnetMstp,
      DiscoveryPointType.bacnetIp,
    ];
    final panelCounts = <String, Map<DiscoveryPointType, int>>{};
    for (final device in project.devices) {
      final panelCode = device.panelCode.trim().isEmpty
          ? 'PANO BELİRTİLMEDİ'
          : device.panelCode.trim().toUpperCase();
      final counts = panelCounts.putIfAbsent(
        panelCode,
        () => <DiscoveryPointType, int>{
          for (final type in DiscoveryPointType.values) type: 0,
        },
      );
      for (final type in DiscoveryPointType.values) {
        counts[type] = (counts[type] ?? 0) + device.countFor(type);
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nokta Analizi',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text('${project.devices.length} cihaz'),
                    ],
                  ),
                ),
                for (final type in visibleTypes)
                  _SummaryMetric(
                    label: type.label,
                    value: project.countFor(type),
                  ),
                _SummaryMetric(label: 'TOPLAM', value: project.totalPoints),
              ],
            ),
            if (panelCounts.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Text(
                'Panolara Göre Nokta İhtiyacı',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                'Her panoya bağlanacak toplam saha noktalarını ayrı ayrı görün.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth >= 800
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final entry in panelCounts.entries)
                        _PanelPointTotals(
                          panelCode: entry.key,
                          counts: entry.value,
                          width: cardWidth,
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PanelPointTotals extends StatelessWidget {
  const _PanelPointTotals({required this.counts, this.panelCode, this.width});

  final String? panelCode;
  final Map<DiscoveryPointType, int> counts;
  final double? width;

  int _count(DiscoveryPointType type) => counts[type] ?? 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final analogInput =
        _count(DiscoveryPointType.aiActive) +
        _count(DiscoveryPointType.aiPassive);
    final physicalTotal =
        analogInput +
        _count(DiscoveryPointType.ao) +
        _count(DiscoveryPointType.di) +
        _count(DiscoveryPointType.doOutput);
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    final communicationTotal = total - physicalTotal;

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.developer_board_rounded,
                  color: colors.onPrimaryContainer,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      panelCode ?? '',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$physicalTotal kablolu saha noktası',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      '$total',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    Text(
                      'TOPLAM NOKTA',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 11),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SalesPointMetric(
                icon: Icons.sensors_rounded,
                label: 'Analog Giriş',
                value: analogInput,
                detail:
                    '${_count(DiscoveryPointType.aiActive)} aktif, '
                    '${_count(DiscoveryPointType.aiPassive)} pasif',
              ),
              _SalesPointMetric(
                icon: Icons.tune_rounded,
                label: 'Analog Çıkış',
                value: _count(DiscoveryPointType.ao),
              ),
              _SalesPointMetric(
                icon: Icons.input_rounded,
                label: 'Dijital Giriş',
                value: _count(DiscoveryPointType.di),
              ),
              _SalesPointMetric(
                icon: Icons.power_settings_new_rounded,
                label: 'Dijital Çıkış',
                value: _count(DiscoveryPointType.doOutput),
              ),
              if (communicationTotal > 0)
                _SalesPointMetric(
                  icon: Icons.hub_outlined,
                  label: 'Haberleşme',
                  value: communicationTotal,
                ),
            ],
          ),
        ],
      ),
    );

    return SizedBox(width: width ?? 390, child: card);
  }
}

class _InlinePanelPointTotals extends StatelessWidget {
  const _InlinePanelPointTotals({required this.counts});

  final Map<DiscoveryPointType, int> counts;

  int _count(DiscoveryPointType type) => counts[type] ?? 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final useShortLabels = MediaQuery.sizeOf(context).width < 1100;
    final analogInput =
        _count(DiscoveryPointType.aiActive) +
        _count(DiscoveryPointType.aiPassive);
    final physicalTotal =
        analogInput +
        _count(DiscoveryPointType.ao) +
        _count(DiscoveryPointType.di) +
        _count(DiscoveryPointType.doOutput);
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    final communicationTotal = total - physicalTotal;

    return Container(
      padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$total Toplam',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.onPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 9),
          _InlinePointValue(
            label: useShortLabels ? 'AG' : 'Analog G.',
            value: analogInput,
          ),
          _InlineDivider(color: colors.outlineVariant),
          _InlinePointValue(
            label: useShortLabels ? 'AÇ' : 'Analog Ç.',
            value: _count(DiscoveryPointType.ao),
          ),
          _InlineDivider(color: colors.outlineVariant),
          _InlinePointValue(
            label: useShortLabels ? 'DG' : 'Dijital G.',
            value: _count(DiscoveryPointType.di),
          ),
          _InlineDivider(color: colors.outlineVariant),
          _InlinePointValue(
            label: useShortLabels ? 'DÇ' : 'Dijital Ç.',
            value: _count(DiscoveryPointType.doOutput),
          ),
          if (communicationTotal > 0) ...[
            _InlineDivider(color: colors.outlineVariant),
            _InlinePointValue(
              label: useShortLabels ? 'HAB' : 'Haberleşme',
              value: communicationTotal,
            ),
          ],
        ],
      ),
    );
  }
}

class _InlinePointValue extends StatelessWidget {
  const _InlinePointValue({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text.rich(
        TextSpan(
          text: '$label ',
          children: [
            TextSpan(
              text: '$value',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

class _InlineDivider extends StatelessWidget {
  const _InlineDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 20, color: color);
  }
}

class _SalesPointMetric extends StatelessWidget {
  const _SalesPointMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final String label;
  final int value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 145),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label  $value',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 74),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$label: $value'),
    );
  }
}

class _DevicePointCard extends StatelessWidget {
  const _DevicePointCard({
    required this.device,
    required this.products,
    required this.onAddPoint,
    required this.onEditDevice,
    required this.onDeleteDevice,
    required this.onSaveTemplate,
    required this.onEditPoint,
    required this.onDeletePoint,
    required this.onSelectProduct,
  });

  final DiscoveryDevice device;
  final List<Product> products;
  final VoidCallback onAddPoint;
  final VoidCallback onEditDevice;
  final VoidCallback onDeleteDevice;
  final VoidCallback onSaveTemplate;
  final ValueChanged<int> onEditPoint;
  final ValueChanged<int> onDeletePoint;
  final ValueChanged<int> onSelectProduct;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        leading: CircleAvatar(child: Text('${device.totalPoints}')),
        title: Text(
          device.deviceCode.trim().isEmpty ? device.name : device.deviceCode,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${device.name} • Pano: '
          '${device.panelCode.trim().isEmpty ? "Belirtilmedi" : device.panelCode}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Cihazı ve noktalarını şablon olarak kaydet',
              onPressed: onSaveTemplate,
              icon: const Icon(Icons.bookmark_add_outlined),
            ),
            IconButton(
              tooltip: 'Cihaz bilgilerini düzenle',
              onPressed: onEditDevice,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Cihazı kaldır',
              onPressed: onDeleteDevice,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
            const Icon(Icons.expand_more_rounded),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onAddPoint,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Özel Nokta Ekle'),
            ),
          ),
          const SizedBox(height: 8),
          if (device.points.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Bu cihazda kontrol noktası bulunmuyor.'),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 26,
                columns: const [
                  DataColumn(label: Text('Kontrol Noktası')),
                  DataColumn(label: Text('Tür')),
                  DataColumn(label: Text('Adet'), numeric: true),
                  DataColumn(label: Text('Yerleştirilen Ürün')),
                  DataColumn(label: Text('İşlem')),
                ],
                rows: [
                  for (var index = 0; index < device.points.length; index++)
                    DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 560,
                            child: Text(device.points[index].name),
                          ),
                        ),
                        DataCell(
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              device.points[index].type ==
                                      DiscoveryPointType.aiActive
                                  ? '${device.points[index].type.label} · '
                                        '${device.points[index].analogSignal.label}'
                                  : device.points[index].type.label,
                            ),
                          ),
                        ),
                        DataCell(Text('${device.points[index].quantity}')),
                        DataCell(
                          _PointProductButton(
                            point: device.points[index],
                            product: _findProduct(
                              products,
                              device.points[index].productId,
                            ),
                            onPressed: () => onSelectProduct(index),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Noktayı düzenle',
                                onPressed: () => onEditPoint(index),
                                icon: const Icon(Icons.edit_outlined, size: 20),
                              ),
                              IconButton(
                                tooltip: 'Noktayı sil',
                                onPressed: () => onDeletePoint(index),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
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

  Product? _findProduct(List<Product> products, String productId) {
    if (productId.isEmpty) return null;
    for (final product in products) {
      if (product.id == productId) return product;
    }
    return null;
  }
}

class _PointProductButton extends StatelessWidget {
  const _PointProductButton({
    required this.point,
    required this.product,
    required this.onPressed,
  });

  final DiscoveryPoint point;
  final Product? product;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hasSelection = point.productId.isNotEmpty;
    final selectedProduct = product;
    return SizedBox(
      width: 310,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          hasSelection
              ? Icons.check_circle_rounded
              : Icons.add_shopping_cart_rounded,
          size: 18,
        ),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            selectedProduct == null
                ? (hasSelection ? 'Ürün kaydı bulunamadı' : 'Ürün Seç')
                : '${selectedProduct.code} · ${selectedProduct.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _ProductSelectionResult {
  const _ProductSelectionResult(this.product);

  final Product? product;
}

class _DiscoveryProductPickerDialog extends StatefulWidget {
  const _DiscoveryProductPickerDialog({
    required this.point,
    required this.products,
  });

  final DiscoveryPoint point;
  final List<Product> products;

  @override
  State<_DiscoveryProductPickerDialog> createState() =>
      _DiscoveryProductPickerDialogState();
}

class _DiscoveryProductPickerDialogState
    extends State<_DiscoveryProductPickerDialog> {
  String _query = '';
  bool _showAllProducts = false;
  bool _onlyInStock = true;

  DiscoveryProductRecommendation get _recommendation =>
      recommendationForDiscoveryPoint(widget.point);

  List<Product> get _visibleProducts {
    final query = _query.trim().toLowerCase();
    final result = widget.products
        .where((product) {
          if (!product.isActive) return false;
          if (_onlyInStock && product.stockQuantity <= 0) return false;
          if (!_showAllProducts && !_recommendation.matches(product)) {
            return false;
          }
          if (query.isEmpty) return true;
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
    result.sort((left, right) {
      final leftStock = left.stockQuantity > 0 ? 0 : 1;
      final rightStock = right.stockQuantity > 0 ? 0 : 1;
      if (leftStock != rightStock) return leftStock.compareTo(rightStock);
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final recommendation = _recommendation;
    final products = _visibleProducts;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.add_shopping_cart_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Noktaya Ürün Yerleştir',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          widget.point.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (widget.point.productId.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        const _ProductSelectionResult(null),
                      ),
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text('Seçimi Kaldır'),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        recommendation.mainCategory.isEmpty
                            ? recommendation.reason
                            : '${recommendation.mainCategory}'
                                  '${recommendation.subcategories.isEmpty ? "" : " › ${recommendation.subcategories.join(" / ")}"}\n'
                                  '${recommendation.reason}',
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          setState(() => _showAllProducts = !_showAllProducts),
                      icon: Icon(
                        _showAllProducts
                            ? Icons.filter_alt_rounded
                            : Icons.manage_search_rounded,
                      ),
                      label: Text(
                        _showAllProducts
                            ? 'Uygun Ürünlere Dön'
                            : 'Filtre Dışı Ürün Ara',
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
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: _showAllProducts
                            ? 'Tüm katalogda kod, ürün, marka veya model ara'
                            : 'Uygun ürünlerde ara',
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    selected: _onlyInStock,
                    label: const Text('Yalnız stoktakiler'),
                    onSelected: (value) => setState(() => _onlyInStock = value),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${products.length} ürün gösteriliyor'
                '${_showAllProducts ? " · filtre dışı arama açık" : ""}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 42),
                            const SizedBox(height: 10),
                            const Text('Filtreye uygun ürün bulunamadı.'),
                            const SizedBox(height: 8),
                            if (!_showAllProducts)
                              OutlinedButton.icon(
                                onPressed: () =>
                                    setState(() => _showAllProducts = true),
                                icon: const Icon(Icons.manage_search_rounded),
                                label: const Text('Tüm Ürünlerde Ara'),
                              ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: products.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final selected = product.id == widget.point.productId;
                          final recommended = recommendation.matches(product);
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
                              '${productMainCategoryTurkishLabel(product)} › '
                              '${productSubcategoryTurkishLabel(product)} · '
                              '${product.brand} ${product.model} · '
                              '${product.formattedStock}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: recommended
                                ? const Chip(
                                    avatar: Icon(Icons.check_rounded, size: 16),
                                    label: Text('Filtreye uygun'),
                                  )
                                : const Chip(label: Text('Manuel seçim')),
                            onTap: () => Navigator.pop(
                              context,
                              _ProductSelectionResult(product),
                            ),
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

class _SaveDeviceTemplateResult {
  const _SaveDeviceTemplateResult({
    required this.name,
    required this.categoryName,
  });

  final String name;
  final String categoryName;
}

class _SaveDeviceTemplateDialog extends StatefulWidget {
  const _SaveDeviceTemplateDialog({required this.device});

  final DiscoveryDevice device;

  @override
  State<_SaveDeviceTemplateDialog> createState() =>
      _SaveDeviceTemplateDialogState();
}

class _SaveDeviceTemplateDialogState extends State<_SaveDeviceTemplateDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.device.name);
    _categoryController = TextEditingController(
      text: '${widget.device.name} Şablonları',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cihazı Şablon Olarak Kaydet'),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.device.points.length} kontrol noktası cihazla '
              'birlikte kaydedilecek.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Şablon adı',
                hintText: 'Örn. Sirkülasyon Pompası',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Cihaz grubu',
                hintText: 'Örn. Pompalar',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton.icon(
          onPressed: () {
            final name = _nameController.text.trim();
            final category = _categoryController.text.trim();
            if (name.isEmpty || category.isEmpty) return;
            Navigator.pop(
              context,
              _SaveDeviceTemplateResult(name: name, categoryName: category),
            );
          },
          icon: const Icon(Icons.bookmark_add_rounded),
          label: const Text('Şablonu Kaydet'),
        ),
      ],
    );
  }
}

class _DeviceTemplateBuilderDialog extends StatefulWidget {
  const _DeviceTemplateBuilderDialog();

  @override
  State<_DeviceTemplateBuilderDialog> createState() =>
      _DeviceTemplateBuilderDialogState();
}

class _DeviceTemplateBuilderDialogState
    extends State<_DeviceTemplateBuilderDialog> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final List<DiscoveryPoint> _points = [];

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _addPoint() async {
    final id = 'template-point-${DateTime.now().microsecondsSinceEpoch}';
    final point = await showDialog<DiscoveryPoint>(
      context: context,
      builder: (context) => _PointDialog(id: id),
    );
    if (point == null || !mounted) return;
    setState(() => _points.add(point));
  }

  Future<void> _editPoint(int index) async {
    final point = await showDialog<DiscoveryPoint>(
      context: context,
      builder: (context) =>
          _PointDialog(id: _points[index].id, existing: _points[index]),
    );
    if (point == null || !mounted) return;
    setState(() => _points[index] = point);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni Hazır Cihaz Şablonu'),
      content: SizedBox(
        width: 620,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Şablon adı',
                      hintText: 'Örn. Boyler',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Cihaz grubu',
                      hintText: 'Örn. Boylerler',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Kontrol Noktaları',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _addPoint,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nokta Ekle'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _points.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Pompa şablonundaki gibi kontrol noktalarını ekleyin.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _points.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final point = _points[index];
                        return ListTile(
                          dense: true,
                          title: Text(point.name),
                          subtitle: Text(
                            '${point.type.label} · ${point.quantity} adet'
                            '${point.type == DiscoveryPointType.aiActive ? " · ${point.analogSignal.label}" : ""}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Düzenle',
                                onPressed: () => _editPoint(index),
                                icon: const Icon(Icons.edit_outlined, size: 19),
                              ),
                              IconButton(
                                tooltip: 'Sil',
                                onPressed: () =>
                                    setState(() => _points.removeAt(index)),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 19,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton.icon(
          onPressed: () {
            final name = _nameController.text.trim();
            final category = _categoryController.text.trim();
            if (name.isEmpty || category.isEmpty || _points.isEmpty) return;
            Navigator.pop(
              context,
              DiscoveryDeviceTemplate(
                key: 'user-template-${DateTime.now().microsecondsSinceEpoch}',
                name: name,
                categoryName: category,
                points: [
                  for (final point in _points)
                    DiscoveryTemplatePoint(
                      point.name,
                      point.type,
                      quantity: point.quantity,
                      analogSignal: point.analogSignal,
                    ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Şablonu Kaydet'),
        ),
      ],
    );
  }
}

class _DeviceDialogResult {
  const _DeviceDialogResult({
    required this.template,
    required this.deviceName,
    required this.panelCode,
    required this.deviceCode,
  });

  final DiscoveryDeviceTemplate template;
  final String deviceName;
  final String panelCode;
  final String deviceCode;
}

class _DeviceDialog extends StatefulWidget {
  const _DeviceDialog({
    required this.templates,
    required this.onSaveTemplate,
    required this.panelSuggestions,
    required this.initialPanelCode,
    this.existing,
  });

  final DiscoveryDevice? existing;
  final List<DiscoveryDeviceTemplate> templates;
  final Future<bool> Function(DiscoveryDeviceTemplate template) onSaveTemplate;
  final List<String> panelSuggestions;
  final String initialPanelCode;

  @override
  State<_DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<_DeviceDialog> {
  late List<DiscoveryDeviceTemplate> _templates;
  late DiscoveryDeviceTemplate _template;
  late final TextEditingController _nameController;
  late final TextEditingController _deviceController;
  late String _panelCode;

  @override
  void initState() {
    super.initState();
    _templates = List<DiscoveryDeviceTemplate>.from(widget.templates);
    final key = widget.existing?.templateKey;
    _template = _templates.firstWhere(
      (template) => template.key == key,
      orElse: () => DiscoveryTemplates.pump,
    );
    _panelCode = widget.existing?.panelCode.trim().isNotEmpty == true
        ? widget.existing!.panelCode.trim().toUpperCase()
        : widget.initialPanelCode.trim().toUpperCase();
    _deviceController = TextEditingController(
      text: widget.existing?.deviceCode ?? '',
    );
    _nameController = TextEditingController(
      text: widget.existing?.name ?? _template.name,
    );
  }

  Future<void> _createTemplate() async {
    final template = await showDialog<DiscoveryDeviceTemplate>(
      context: context,
      builder: (context) => const _DeviceTemplateBuilderDialog(),
    );
    if (template == null) return;
    final saved = await widget.onSaveTemplate(template);
    if (!saved || !mounted) return;
    setState(() {
      _templates = [..._templates, template];
      _template = template;
      _nameController.text = template.name;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _deviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Cihaz Bilgilerini Düzenle' : 'Keşfe Cihaz Ekle'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<DiscoveryDeviceTemplate>(
              initialValue: _template,
              decoration: const InputDecoration(labelText: 'Cihaz şablonu'),
              items: _templates
                  .map(
                    (template) => DropdownMenuItem(
                      value: template,
                      child: Text(
                        '${template.name} (${template.points.length} nokta)',
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: editing
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _template = value;
                        _nameController.text = value.name;
                      });
                    },
            ),
            if (!editing)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _createTemplate,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Yeni Şablon'),
                ),
              ),
            if (_template.key == DiscoveryTemplates.custom.key) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Özel cihaz adı',
                  hintText: 'Boyler, fan, eşanjör...',
                ),
              ),
            ],
            const SizedBox(height: 12),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _panelCode),
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.trim().toLowerCase();
                if (query.isEmpty) return widget.panelSuggestions;
                return widget.panelSuggestions.where(
                  (option) => option.toLowerCase().contains(query),
                );
              },
              onSelected: (value) => _panelCode = value,
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Pano kodu',
                        hintText: 'D yazın veya DDC-01 seçin',
                        prefixIcon: Icon(Icons.developer_board_outlined),
                        suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                      ),
                      onChanged: (value) => _panelCode = value,
                      onSubmitted: (_) => onFieldSubmitted(),
                    );
                  },
              optionsViewBuilder: (context, onSelected, options) {
                final values = options.toList(growable: false);
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 520,
                        maxHeight: 220,
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        itemCount: values.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final option = values[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.developer_board_rounded),
                            title: Text(
                              option,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Mevcut veya sıradaki pano önerilir; özel bir kod da yazabilirsiniz.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deviceController,
              decoration: const InputDecoration(
                labelText: 'Cihaz kodu',
                hintText: 'KS-1',
              ),
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
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              _DeviceDialogResult(
                template: _template,
                deviceName: name,
                panelCode: _panelCode.trim().toUpperCase(),
                deviceCode: _deviceController.text.trim(),
              ),
            );
          },
          child: Text(editing ? 'Uygula' : 'Ekle'),
        ),
      ],
    );
  }
}

class _PointDialog extends StatefulWidget {
  const _PointDialog({required this.id, this.existing});

  final String id;
  final DiscoveryPoint? existing;

  @override
  State<_PointDialog> createState() => _PointDialogState();
}

class _PointDialogState extends State<_PointDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late DiscoveryPointType _type;
  late DiscoveryAnalogSignal _analogSignal;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _quantityController = TextEditingController(
      text: '${widget.existing?.quantity ?? 1}',
    );
    _type = widget.existing?.type ?? DiscoveryPointType.di;
    _analogSignal =
        widget.existing?.analogSignal ?? DiscoveryAnalogSignal.unspecified;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Kontrol Noktasını Düzenle' : 'Özel Nokta Ekle'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Kontrol noktası adı',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<DiscoveryPointType>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'Nokta türü'),
                    items: DiscoveryPointType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) setState(() => _type = value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Adet'),
                  ),
                ),
              ],
            ),
            if (_type == DiscoveryPointType.aiActive) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<DiscoveryAnalogSignal>(
                initialValue: _analogSignal,
                decoration: const InputDecoration(
                  labelText: 'AI-A sinyal tipi',
                  helperText:
                      'Belirtilmedi seçimi güvenli olarak 4–20 mA kabul edilir.',
                ),
                items: DiscoveryAnalogSignal.values
                    .map(
                      (signal) => DropdownMenuItem(
                        value: signal,
                        child: Text(signal.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _analogSignal = value);
                  }
                },
              ),
            ],
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
            final name = _nameController.text.trim();
            final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
            if (name.isEmpty || quantity < 1) return;
            Navigator.pop(
              context,
              DiscoveryPoint(
                id: widget.id,
                name: name,
                type: _type,
                quantity: quantity,
                productId: widget.existing?.productId ?? '',
                analogSignal: _type == DiscoveryPointType.aiActive
                    ? _analogSignal
                    : DiscoveryAnalogSignal.unspecified,
              ),
            );
          },
          child: Text(editing ? 'Uygula' : 'Ekle'),
        ),
      ],
    );
  }
}

String _newId(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}';
