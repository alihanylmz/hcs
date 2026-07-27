import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/discovery_templates.dart';
import '../models/control_hardware.dart';
import '../models/discovery_project.dart';
import '../services/control_hardware_repository.dart';
import '../services/control_hardware_selector.dart';
import '../services/discovery_repository.dart';
import '../widgets/workspace_background.dart';
import 'control_hardware_library_page.dart';

class DiscoveryProjectsPage extends StatefulWidget {
  const DiscoveryProjectsPage({
    super.key,
    required this.repository,
    required this.hardwareRepository,
  });

  final DiscoveryRepository repository;
  final ControlHardwareRepository hardwareRepository;

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
        builder: (context) =>
            ControlHardwareLibraryPage(repository: widget.hardwareRepository),
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
  });

  final DiscoveryProject project;
  final DiscoveryRepository repository;
  final ControlHardwareRepository hardwareRepository;

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

  Future<void> _loadHardware() async {
    try {
      final hardware = await widget.hardwareRepository.fetchAll();
      if (!mounted) return;
      setState(() {
        _hardware = hardware;
        _loadingHardware = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHardware = false);
    }
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

  Future<void> _addDevice() async {
    final existingPanelCodes = _existingPanelCodes;
    final result = await showDialog<_DeviceDialogResult>(
      context: context,
      builder: (context) => _DeviceDialog(
        panelSuggestions: DiscoveryPanelCodeSuggestions.build(
          existingPanelCodes,
        ),
        initialPanelCode: DiscoveryPanelCodeSuggestions.initialValue(
          existingPanelCodes,
        ),
      ),
    );
    if (result == null) return;
    final device = result.template.instantiate(
      id: _buildId('device'),
      panelCode: result.panelCode,
      deviceCode: result.deviceCode,
      idBuilder: _buildId,
    );
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
        panelSuggestions: DiscoveryPanelCodeSuggestions.build(
          _existingPanelCodes,
        ),
        initialPanelCode: source.panelCode,
      ),
    );
    if (result == null) return;
    setState(() {
      _devices[index] = source.copyWith(
        name: result.template.name,
        panelCode: result.panelCode,
        deviceCode: result.deviceCode,
      );
      _ensurePanelSettings(result.panelCode);
      _hardwareSolutions = const [];
    });
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

  void _analyzeHardware() {
    if (_devices.isEmpty) return;
    if (_hardware.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce DDC/I/O kütüphanesine ekipman ekleyin.'),
        ),
      );
      return;
    }
    final solutions = const ControlHardwareSelector().select(
      project: _currentProject,
      hardware: _hardware,
    );
    setState(() => _hardwareSolutions = solutions);
  }

  @override
  Widget build(BuildContext context) {
    final project = _currentProject;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keşif Düzenle'),
        actions: [
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
                        'Otomatik DDC / I/O Çözümü',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'Pano rolleri, esnek kanal yetenekleri ve uyumlu '
                        'modüllere göre hesaplanır.',
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
                  label: const Text('Ekipmanları Hesapla'),
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
    final panelPointTotal = devices.fold(
      0,
      (total, indexed) => total + indexed.device.totalPoints,
    );

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
                Text(
                  '${devices.length} cihaz',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 10),
                ActionChip(
                  avatar: const Icon(Icons.account_tree_outlined, size: 18),
                  label: Text(_settingsForPanel(panelCode).mode.label),
                  onPressed: () => _editPanelSettings(panelCode),
                ),
                const Spacer(),
                _SmallMetric(label: 'Pano toplamı', value: '$panelPointTotal'),
              ],
            ),
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
              onAddPoint: () => _addPoint(indexed.index),
              onEditDevice: () => _editDevice(indexed.index),
              onDeleteDevice: () => _deleteDevice(indexed.index),
              onEditPoint: (pointIndex) =>
                  _editPoint(indexed.index, pointIndex),
              onDeletePoint: (pointIndex) =>
                  _deletePoint(indexed.index, pointIndex),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text('${project.devices.length} cihaz'),
                ],
              ),
            ),
            for (final type in visibleTypes)
              _SummaryMetric(label: type.label, value: project.countFor(type)),
            _SummaryMetric(label: 'TOPLAM', value: project.totalPoints),
          ],
        ),
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
    required this.onAddPoint,
    required this.onEditDevice,
    required this.onDeleteDevice,
    required this.onEditPoint,
    required this.onDeletePoint,
  });

  final DiscoveryDevice device;
  final VoidCallback onAddPoint;
  final VoidCallback onEditDevice;
  final VoidCallback onDeleteDevice;
  final ValueChanged<int> onEditPoint;
  final ValueChanged<int> onDeletePoint;

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
}

class _DeviceDialogResult {
  const _DeviceDialogResult({
    required this.template,
    required this.panelCode,
    required this.deviceCode,
  });

  final DiscoveryDeviceTemplate template;
  final String panelCode;
  final String deviceCode;
}

class _DeviceDialog extends StatefulWidget {
  const _DeviceDialog({
    required this.panelSuggestions,
    required this.initialPanelCode,
    this.existing,
  });

  final DiscoveryDevice? existing;
  final List<String> panelSuggestions;
  final String initialPanelCode;

  @override
  State<_DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<_DeviceDialog> {
  late DiscoveryDeviceTemplate _template;
  late final TextEditingController _deviceController;
  late String _panelCode;

  @override
  void initState() {
    super.initState();
    final key = widget.existing?.templateKey;
    _template = DiscoveryTemplates.values.firstWhere(
      (template) => template.key == key,
      orElse: () => DiscoveryTemplates.pump,
    );
    _panelCode = widget.existing?.panelCode.trim().isNotEmpty == true
        ? widget.existing!.panelCode.trim().toUpperCase()
        : widget.initialPanelCode.trim().toUpperCase();
    _deviceController = TextEditingController(
      text: widget.existing?.deviceCode ?? '',
    );
  }

  @override
  void dispose() {
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
              items: DiscoveryTemplates.values
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
                      if (value != null) setState(() => _template = value);
                    },
            ),
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
            Navigator.pop(
              context,
              _DeviceDialogResult(
                template: _template,
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
