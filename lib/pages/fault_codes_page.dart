import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/commissioning_step.dart';
import '../models/inverter_reference_value.dart';
import '../models/quick_parameter.dart';
import '../models/user_profile.dart';
import '../services/inverter_reference_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/sidebar/app_layout.dart';
import '../widgets/ui/ui.dart';

class FaultCodesPage extends StatefulWidget {
  const FaultCodesPage({super.key});

  @override
  State<FaultCodesPage> createState() => _FaultCodesPageState();
}

class _DeviceGroup<T> {
  const _DeviceGroup({
    required this.brand,
    required this.model,
    required this.items,
  });

  final String brand;
  final String model;
  final List<T> items;
}

class _DeviceCatalogItem {
  const _DeviceCatalogItem({
    required this.key,
    required this.brand,
    required this.model,
    required this.faultCount,
    required this.stepCount,
    required this.parameterCount,
    required this.referenceCount,
    this.isAll = false,
  });

  final String key;
  final String brand;
  final String model;
  final int faultCount;
  final int stepCount;
  final int parameterCount;
  final int referenceCount;
  final bool isAll;

  int get totalCount =>
      faultCount + stepCount + parameterCount + referenceCount;
}

class _ReferenceEditorDraft {
  const _ReferenceEditorDraft({
    required this.deviceBrand,
    required this.deviceModel,
    required this.title,
    required this.registerAddress,
    required this.storedValue,
    required this.unit,
    required this.category,
    required this.note,
    required this.sortOrder,
  });

  final String deviceBrand;
  final String deviceModel;
  final String title;
  final String registerAddress;
  final String storedValue;
  final String unit;
  final String category;
  final String note;
  final int sortOrder;
}

class _ReferenceEditorDialog extends StatefulWidget {
  const _ReferenceEditorDialog({
    required this.initialBrand,
    required this.initialModel,
    this.existing,
  });

  final String initialBrand;
  final String initialModel;
  final InverterReferenceValue? existing;

  @override
  State<_ReferenceEditorDialog> createState() => _ReferenceEditorDialogState();
}

class _ReferenceEditorDialogState extends State<_ReferenceEditorDialog> {
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _titleController;
  late final TextEditingController _registerController;
  late final TextEditingController _valueController;
  late final TextEditingController _unitController;
  late final TextEditingController _categoryController;
  late final TextEditingController _noteController;
  late final TextEditingController _sortOrderController;

  bool _showTitleError = false;

  @override
  void initState() {
    super.initState();
    _brandController = TextEditingController(
      text: widget.existing?.deviceBrand ?? widget.initialBrand,
    );
    _modelController = TextEditingController(
      text: widget.existing?.deviceModel ?? widget.initialModel,
    );
    _titleController = TextEditingController(
      text: widget.existing?.title ?? '',
    );
    _registerController = TextEditingController(
      text: widget.existing?.registerAddress ?? '',
    );
    _valueController = TextEditingController(
      text: widget.existing?.storedValue ?? '',
    );
    _unitController = TextEditingController(text: widget.existing?.unit ?? '');
    _categoryController = TextEditingController(
      text:
          widget.existing?.category.isNotEmpty == true
              ? widget.existing!.category
              : 'general',
    );
    _noteController = TextEditingController(text: widget.existing?.note ?? '');
    _sortOrderController = TextEditingController(
      text:
          widget.existing == null || widget.existing!.sortOrder == 0
              ? ''
              : widget.existing!.sortOrder.toString(),
    );
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _titleController.dispose();
    _registerController.dispose();
    _valueController.dispose();
    _unitController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _showTitleError = true);
      return;
    }

    Navigator.of(context).pop(
      _ReferenceEditorDraft(
        deviceBrand: _brandController.text.trim(),
        deviceModel: _modelController.text.trim(),
        title: _titleController.text.trim(),
        registerAddress: _registerController.text.trim(),
        storedValue: _valueController.text.trim(),
        unit: _unitController.text.trim(),
        category:
            _categoryController.text.trim().isEmpty
                ? 'general'
                : _categoryController.text.trim(),
        note: _noteController.text.trim(),
        sortOrder: int.tryParse(_sortOrderController.text.trim()) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Hizli referans ekle'
            : 'Hizli referans duzenle',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                onChanged: (_) {
                  if (_showTitleError &&
                      _titleController.text.trim().isNotEmpty) {
                    setState(() => _showTitleError = false);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Baslik',
                  hintText: 'Set frekans',
                  errorText: _showTitleError ? 'Baslik bos birakilamaz.' : null,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _brandController,
                      decoration: const InputDecoration(labelText: 'Marka'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _modelController,
                      decoration: const InputDecoration(labelText: 'Model'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _registerController,
                      decoration: const InputDecoration(
                        labelText: 'Register / Adres',
                        hintText: '40003',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _valueController,
                      decoration: const InputDecoration(
                        labelText: 'Deger',
                        hintText: '50',
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
                      controller: _unitController,
                      decoration: const InputDecoration(
                        labelText: 'Birim',
                        hintText: 'Hz',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Kategori',
                        hintText: 'modbus',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _sortOrderController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Sira'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Not',
                  hintText: 'Sahada dikkat edilecek bilgi...',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgec'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Kaydet')),
      ],
    );
  }
}

class _FaultCodesPageState extends State<FaultCodesPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  final InverterReferenceService _referenceService = InverterReferenceService();

  List<Map<String, dynamic>> _faults = [];
  List<Map<String, dynamic>> _filteredFaults = [];
  List<CommissioningStep> _steps = [];
  List<CommissioningStep> _filteredSteps = [];
  List<QuickParameter> _params = [];
  List<QuickParameter> _filteredParams = [];
  List<InverterReferenceValue> _referenceValues = [];
  List<InverterReferenceValue> _filteredReferenceValues = [];

  bool _isLoading = true;
  String? _error;
  bool _referenceStorageReady = true;

  String _brandFilter = 'all';
  String _modelFilter = 'all';
  List<String> _brands = const ['all'];
  List<String> _models = const ['all'];

  late final TabController _tabController;
  UserProfile? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadUserProfile();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userService.getCurrentUserProfile();
    if (!mounted) return;
    setState(() => _currentUser = profile);
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;

      try {
        final faultsRes = await supabase
            .from('fault_codes')
            .select()
            .order('device_brand', ascending: true)
            .order('device_model', ascending: true)
            .order('code', ascending: true);
        _faults = List<Map<String, dynamic>>.from(faultsRes);
      } catch (e) {
        debugPrint('Fault codes load failed: $e');
      }

      try {
        final stepsRes = await supabase
            .from('commissioning_guides')
            .select()
            .order('device_brand', ascending: true)
            .order('device_model', ascending: true)
            .order('step_number', ascending: true);
        _steps =
            List<Map<String, dynamic>>.from(stepsRes)
                .map((step) {
                  try {
                    return CommissioningStep.fromJson(step);
                  } catch (err) {
                    debugPrint('Commissioning step parse failed: $err');
                    return null;
                  }
                })
                .whereType<CommissioningStep>()
                .toList();
      } catch (e) {
        debugPrint('Commissioning guides load failed: $e');
      }

      try {
        final paramsRes = await supabase
            .from('quick_parameters')
            .select()
            .order('device_brand', ascending: true)
            .order('device_model', ascending: true)
            .order('parameter_code', ascending: true);
        _params =
            List<Map<String, dynamic>>.from(paramsRes)
                .map((param) {
                  try {
                    return QuickParameter.fromJson(param);
                  } catch (err) {
                    debugPrint('Quick parameter parse failed: $err');
                    return null;
                  }
                })
                .whereType<QuickParameter>()
                .toList();
      } catch (e) {
        debugPrint('Quick parameters load failed: $e');
      }

      try {
        _referenceValues = await _referenceService.listAll();
        _referenceStorageReady = true;
      } catch (e) {
        debugPrint('Reference values load failed: $e');
        _referenceValues = [];
        _referenceStorageReady =
            e is! PostgrestException ||
            (e.code != '42P01' &&
                !e.message.toLowerCase().contains('inverter_reference_values'));
      }

      _sortAllData();
      _syncCurrentDeviceSelection();

      if (!mounted) return;
      setState(_rebuildFilters);
      _applyFilters();
    } catch (e) {
      debugPrint('Fault guide load failed: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Veriler yuklenirken bir hata olustu.';
        _isLoading = false;
      });
    }
  }

  void _sortAllData() {
    _faults.sort((left, right) {
      final brandCompare = _compareText(
        _text(left['device_brand']),
        _text(right['device_brand']),
      );
      if (brandCompare != 0) return brandCompare;

      final modelCompare = _compareText(
        _text(left['device_model']),
        _text(right['device_model']),
      );
      if (modelCompare != 0) return modelCompare;

      return _compareCodes(_text(left['code']), _text(right['code']));
    });

    _steps.sort((left, right) {
      final brandCompare = _compareText(left.deviceBrand, right.deviceBrand);
      if (brandCompare != 0) return brandCompare;

      final modelCompare = _compareText(left.deviceModel, right.deviceModel);
      if (modelCompare != 0) return modelCompare;

      return left.stepNumber.compareTo(right.stepNumber);
    });

    _params.sort((left, right) {
      final brandCompare = _compareText(left.deviceBrand, right.deviceBrand);
      if (brandCompare != 0) return brandCompare;

      final modelCompare = _compareText(left.deviceModel, right.deviceModel);
      if (modelCompare != 0) return modelCompare;

      return _compareCodes(left.parameterCode, right.parameterCode);
    });

    _referenceValues.sort((left, right) {
      final brandCompare = _compareText(left.deviceBrand, right.deviceBrand);
      if (brandCompare != 0) return brandCompare;

      final modelCompare = _compareText(left.deviceModel, right.deviceModel);
      if (modelCompare != 0) return modelCompare;

      final categoryCompare = _compareText(left.category, right.category);
      if (categoryCompare != 0) return categoryCompare;

      if (left.sortOrder != right.sortOrder) {
        return left.sortOrder.compareTo(right.sortOrder);
      }

      return _compareText(left.title, right.title);
    });
  }

  void _rebuildFilters() {
    final brandSet = <String>{};
    final deviceScopes = <Map<String, String>>[];

    void addScope(String brand, String model) {
      final cleanBrand = brand.trim();
      final cleanModel = model.trim();

      if (cleanBrand.isNotEmpty) brandSet.add(cleanBrand);
      deviceScopes.add({'brand': cleanBrand, 'model': cleanModel});
    }

    for (final fault in _faults) {
      addScope(_text(fault['device_brand']), _text(fault['device_model']));
    }
    for (final step in _steps) {
      addScope(step.deviceBrand, step.deviceModel);
    }
    for (final param in _params) {
      addScope(param.deviceBrand, param.deviceModel);
    }
    for (final reference in _referenceValues) {
      addScope(reference.deviceBrand, reference.deviceModel);
    }

    final brands =
        brandSet.toList()..sort((left, right) => _compareText(left, right));
    _brands = ['all', ...brands];
    if (!_brands.contains(_brandFilter)) _brandFilter = 'all';

    final modelSet = <String>{};
    for (final scope in deviceScopes) {
      final brand = (scope['brand'] ?? '').trim();
      final model = (scope['model'] ?? '').trim();
      if (model.isEmpty) continue;
      if (_brandFilter != 'all' && brand != _brandFilter) continue;
      modelSet.add(model);
    }

    final models =
        modelSet.toList()..sort((left, right) => _compareText(left, right));
    _models = ['all', ...models];
    if (!_models.contains(_modelFilter)) _modelFilter = 'all';
  }

  void _applyFilters() {
    final query = _normalize(_searchController.text);
    if (!mounted) return;

    setState(() {
      _filteredFaults =
          _faults.where((fault) {
            final brand = _text(fault['device_brand']);
            final model = _text(fault['device_model']);
            if (!_matchesScope(brand, model)) return false;

            if (query.isEmpty) return true;

            final haystack = _normalize(
              [
                _text(fault['code']),
                _faultTitle(fault),
                _faultBody(fault),
                brand,
                model,
              ].join(' '),
            );
            return haystack.contains(query);
          }).toList();

      _filteredSteps =
          _steps.where((step) {
            if (!_matchesScope(step.deviceBrand, step.deviceModel)) {
              return false;
            }

            if (query.isEmpty) return true;

            final haystack = _normalize(
              [
                step.title,
                step.description ?? '',
                step.deviceBrand,
                step.deviceModel,
                '${step.stepNumber}',
              ].join(' '),
            );
            return haystack.contains(query);
          }).toList();

      _filteredParams =
          _params.where((param) {
            if (!_matchesScope(param.deviceBrand, param.deviceModel)) {
              return false;
            }

            if (query.isEmpty) return true;

            final haystack = _normalize(
              [
                param.parameterCode,
                param.parameterName,
                param.description ?? '',
                param.defaultValue ?? '',
                param.deviceBrand,
                param.deviceModel,
              ].join(' '),
            );
            return haystack.contains(query);
          }).toList();

      _filteredReferenceValues =
          _referenceValues.where((reference) {
            if (!_matchesScope(reference.deviceBrand, reference.deviceModel)) {
              return false;
            }

            if (query.isEmpty) return true;

            final haystack = _normalize(
              [
                reference.title,
                reference.registerAddress,
                reference.storedValue,
                reference.unit,
                reference.category,
                reference.note,
                reference.deviceBrand,
                reference.deviceModel,
              ].join(' '),
            );
            return haystack.contains(query);
          }).toList();

      _isLoading = false;
    });
  }

  bool _matchesScope(String brand, String model) {
    if (_brandFilter != 'all' && brand.trim() != _brandFilter) return false;
    if (_modelFilter != 'all' && model.trim() != _modelFilter) return false;
    return true;
  }

  int _compareText(String left, String right) {
    return _normalize(left).compareTo(_normalize(right));
  }

  int _compareCodes(String left, String right) {
    final leftNumber = int.tryParse(RegExp(r'\d+').stringMatch(left) ?? '');
    final rightNumber = int.tryParse(RegExp(r'\d+').stringMatch(right) ?? '');

    if (leftNumber != null &&
        rightNumber != null &&
        leftNumber != rightNumber) {
      return leftNumber.compareTo(rightNumber);
    }
    if (leftNumber != null && rightNumber == null) return -1;
    if (leftNumber == null && rightNumber != null) return 1;
    return _compareText(left, right);
  }

  String _text(Object? value) => value?.toString().trim() ?? '';

  String _faultTitle(Map<String, dynamic> fault) {
    final description = _text(fault['description']);
    if (description.isNotEmpty) return description;
    final faultName = _text(fault['fault_name']);
    if (faultName.isNotEmpty) return faultName;
    return 'Aciklama bulunamadi';
  }

  String _faultBody(Map<String, dynamic> fault) {
    final causes = _text(fault['possible_causes']);
    if (causes.isNotEmpty) return causes;
    final solution = _text(fault['solution']);
    if (solution.isNotEmpty) return solution;
    return 'Bu kod icin ek aciklama bulunamadi.';
  }

  String _normalize(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c')
        .replaceAll('ä±', 'i')
        .replaceAll('ä°', 'i')
        .replaceAll('å', 's')
        .replaceAll('ä', 'g')
        .replaceAll('ã¼', 'u')
        .replaceAll('ã¶', 'o')
        .replaceAll('ã§', 'c');
  }

  void _syncCurrentDeviceSelection() {
    final devices =
        _deviceCatalogItems(
          includeAll: false,
        ).where((device) => device.totalCount > 0).toList();

    if (devices.isEmpty) {
      _brandFilter = 'all';
      _modelFilter = 'all';
      return;
    }

    final currentKey = _selectedDeviceKey();
    final hasCurrent = devices.any((device) => device.key == currentKey);

    if ((_brandFilter == 'all' && _modelFilter == 'all') || !hasCurrent) {
      final device = devices.first;
      _brandFilter = device.brand.isEmpty ? 'all' : device.brand;
      _modelFilter = device.model.isEmpty ? 'all' : device.model;
    }
  }

  String _selectedDeviceKey() {
    if (_brandFilter == 'all' && _modelFilter == 'all') {
      return 'all_devices';
    }
    return _scopeKey(
      _brandFilter == 'all' ? '' : _brandFilter,
      _modelFilter == 'all' ? '' : _modelFilter,
    );
  }

  List<_DeviceCatalogItem> _deviceCatalogItems({bool includeAll = true}) {
    final counters = <String, Map<String, int>>{};
    final scopes = <String, Map<String, String>>{};

    void bump(String brand, String model, String field) {
      final cleanBrand = brand.trim();
      final cleanModel = model.trim();
      final key = _scopeKey(cleanBrand, cleanModel);

      counters.putIfAbsent(
        key,
        () => {'faults': 0, 'steps': 0, 'params': 0, 'references': 0},
      );
      scopes[key] = {'brand': cleanBrand, 'model': cleanModel};
      counters[key]![field] = (counters[key]![field] ?? 0) + 1;
    }

    for (final fault in _faults) {
      bump(
        _text(fault['device_brand']),
        _text(fault['device_model']),
        'faults',
      );
    }
    for (final step in _steps) {
      bump(step.deviceBrand, step.deviceModel, 'steps');
    }
    for (final param in _params) {
      bump(param.deviceBrand, param.deviceModel, 'params');
    }
    for (final reference in _referenceValues) {
      bump(reference.deviceBrand, reference.deviceModel, 'references');
    }

    final items =
        counters.entries.map((entry) {
          final counts = entry.value;
          final scope = scopes[entry.key] ?? const {'brand': '', 'model': ''};

          return _DeviceCatalogItem(
            key: entry.key,
            brand: scope['brand'] ?? '',
            model: scope['model'] ?? '',
            faultCount: counts['faults'] ?? 0,
            stepCount: counts['steps'] ?? 0,
            parameterCount: counts['params'] ?? 0,
            referenceCount: counts['references'] ?? 0,
          );
        }).toList();

    items.sort((left, right) {
      final leftScore = left.totalCount;
      final rightScore = right.totalCount;
      if (leftScore != rightScore) return rightScore.compareTo(leftScore);

      final brandCompare = _compareText(left.brand, right.brand);
      if (brandCompare != 0) return brandCompare;
      return _compareText(left.model, right.model);
    });

    if (!includeAll) return items;

    return [
      _DeviceCatalogItem(
        key: 'all_devices',
        brand: '',
        model: '',
        faultCount: _faults.length,
        stepCount: _steps.length,
        parameterCount: _params.length,
        referenceCount: _referenceValues.length,
        isAll: true,
      ),
      ...items,
    ];
  }

  _DeviceCatalogItem? _selectedCatalogItem() {
    final selectedKey = _selectedDeviceKey();
    for (final item in _deviceCatalogItems()) {
      if (item.key == selectedKey) return item;
    }
    return null;
  }

  bool get _showingAllDevices => _brandFilter == 'all' && _modelFilter == 'all';

  void _selectCatalogItem(_DeviceCatalogItem item) {
    setState(() {
      if (item.isAll) {
        _brandFilter = 'all';
        _modelFilter = 'all';
      } else {
        _brandFilter = item.brand.isEmpty ? 'all' : item.brand;
        _modelFilter = item.model.isEmpty ? 'all' : item.model;
      }
      _rebuildFilters();
    });
    _applyFilters();
  }

  List<_DeviceGroup<Map<String, dynamic>>> _groupedFaults() {
    return _groupByDevice<Map<String, dynamic>>(
      _filteredFaults,
      brandOf: (fault) => _text(fault['device_brand']),
      modelOf: (fault) => _text(fault['device_model']),
    );
  }

  List<_DeviceGroup<CommissioningStep>> _groupedSteps() {
    return _groupByDevice<CommissioningStep>(
      _filteredSteps,
      brandOf: (step) => step.deviceBrand,
      modelOf: (step) => step.deviceModel,
    );
  }

  List<_DeviceGroup<QuickParameter>> _groupedParams() {
    return _groupByDevice<QuickParameter>(
      _filteredParams,
      brandOf: (param) => param.deviceBrand,
      modelOf: (param) => param.deviceModel,
    );
  }

  List<_DeviceGroup<InverterReferenceValue>> _groupedReferenceValues() {
    return _groupByDevice<InverterReferenceValue>(
      _filteredReferenceValues,
      brandOf: (reference) => reference.deviceBrand,
      modelOf: (reference) => reference.deviceModel,
    );
  }

  List<_DeviceGroup<T>> _groupByDevice<T>(
    Iterable<T> items, {
    required String Function(T item) brandOf,
    required String Function(T item) modelOf,
  }) {
    final groupedItems = <String, List<T>>{};
    final scopes = <String, Map<String, String>>{};

    for (final item in items) {
      final brand = brandOf(item).trim();
      final model = modelOf(item).trim();
      final key = _scopeKey(brand, model);

      groupedItems.putIfAbsent(key, () => <T>[]).add(item);
      scopes[key] = {'brand': brand, 'model': model};
    }

    final groups =
        groupedItems.entries.map((entry) {
          final scope = scopes[entry.key] ?? const {'brand': '', 'model': ''};
          return _DeviceGroup<T>(
            brand: scope['brand'] ?? '',
            model: scope['model'] ?? '',
            items: entry.value,
          );
        }).toList();

    groups.sort((left, right) {
      final brandCompare = _compareText(left.brand, right.brand);
      if (brandCompare != 0) return brandCompare;
      return _compareText(left.model, right.model);
    });

    return groups;
  }

  String _scopeKey(String brand, String model) => '$brand|||$model';

  String _scopeTitle(String brand, String model) {
    final cleanBrand = brand.trim();
    final cleanModel = model.trim();

    if (cleanBrand.isEmpty && cleanModel.isEmpty) {
      return 'Marka ve model belirtilmedi';
    }
    if (cleanBrand.isEmpty) {
      return 'Model: $cleanModel';
    }
    if (cleanModel.isEmpty) {
      return cleanBrand;
    }
    return '$cleanBrand / $cleanModel';
  }

  String _scopeSubtitle(String brand, String model) {
    final cleanBrand = brand.trim();
    final cleanModel = model.trim();

    if (cleanBrand.isEmpty && cleanModel.isEmpty) {
      return 'Kayitlar cihaz bilgisi olmadan girilmis.';
    }
    if (cleanBrand.isEmpty) {
      return 'Marka girilmemis, model bazli listeleme yapiliyor.';
    }
    if (cleanModel.isEmpty) {
      return 'Model girilmemis, marka bazli listeleme yapiliyor.';
    }
    return 'Bu cihaz icin kayitlar ayni grupta toplandi.';
  }

  String _previewText(String text, {int maxLength = 110}) {
    final compact = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.length <= maxLength) return compact;
    return '${compact.substring(0, maxLength).trimRight()}...';
  }

  bool _isCompactWidth(BuildContext context, {double threshold = 720}) {
    return MediaQuery.of(context).size.width < threshold;
  }

  Widget _buildFiltersSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedDevice = _selectedCatalogItem();
    final activeLabel =
        selectedDevice == null
            ? 'Cihaz secilmedi'
            : selectedDevice.isAll
            ? 'Tum cihazlar'
            : _scopeTitle(selectedDevice.brand, selectedDevice.model);

    return UiMaxWidth(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 680;
            final fullWidth = constraints.maxWidth;

            return _buildSurface(
              padding: EdgeInsets.all(isCompact ? 14 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildSummaryPill(
                        icon: Icons.memory_rounded,
                        label: activeLabel,
                      ),
                      _buildSummaryPill(
                        icon: Icons.support_agent_rounded,
                        label: '${_filteredFaults.length} ariza',
                      ),
                      _buildSummaryPill(
                        icon: Icons.assignment_turned_in_outlined,
                        label: '${_filteredSteps.length} adim',
                      ),
                      _buildSummaryPill(
                        icon: Icons.tune_rounded,
                        label: '${_filteredParams.length} parametre',
                      ),
                      _buildSummaryPill(
                        icon: Icons.bookmarks_outlined,
                        label: '${_filteredReferenceValues.length} referans',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Cihaz sec, sonra kaydi tara.',
                    style: TextStyle(
                      fontSize: isCompact ? 18 : 20,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppColors.textOnDark : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Arama kutusu secili cihazin ariza kodu, devreye alma ve parametre verisini birlikte filtreler.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color:
                          isDark
                              ? AppColors.textOnDarkMuted
                              : AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: isCompact ? fullWidth : 360,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Kod, ariza, adim veya parametre ara...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon:
                                _searchController.text.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        _searchController.clear();
                                        _applyFilters();
                                      },
                                    )
                                    : null,
                          ),
                          onChanged: (_) => _applyFilters(),
                        ),
                      ),
                      if (isCompact) ...[
                        SizedBox(
                          width: fullWidth,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                            icon: const Icon(Icons.filter_alt_off_outlined),
                            label: const Text('Aramayi Temizle'),
                          ),
                        ),
                        SizedBox(
                          width: fullWidth,
                          child: FilledButton.icon(
                            onPressed: () {
                              final allItem = _deviceCatalogItems().firstWhere(
                                (item) => item.isAll,
                                orElse:
                                    () => const _DeviceCatalogItem(
                                      key: 'all_devices',
                                      brand: '',
                                      model: '',
                                      faultCount: 0,
                                      stepCount: 0,
                                      parameterCount: 0,
                                      referenceCount: 0,
                                      isAll: true,
                                    ),
                              );
                              _selectCatalogItem(allItem);
                            },
                            icon: const Icon(Icons.apps_rounded),
                            label: const Text('Tum cihazlari goster'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF163650),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ] else ...[
                        OutlinedButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text('Aramayi Temizle'),
                        ),
                        FilledButton.icon(
                          onPressed: () {
                            final allItem = _deviceCatalogItems().firstWhere(
                              (item) => item.isAll,
                              orElse:
                                  () => const _DeviceCatalogItem(
                                    key: 'all_devices',
                                    brand: '',
                                    model: '',
                                    faultCount: 0,
                                    stepCount: 0,
                                    parameterCount: 0,
                                    referenceCount: 0,
                                    isAll: true,
                                  ),
                            );
                            _selectCatalogItem(allItem);
                          },
                          icon: const Icon(Icons.apps_rounded),
                          label: const Text('Tum cihazlari goster'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF163650),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return UiMaxWidth(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildSurface(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicator: BoxDecoration(
              color: const Color(0xFF163650),
              borderRadius: BorderRadius.circular(16),
            ),
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor:
                Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textOnDarkMuted
                    : AppColors.textLight,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            tabs: const [
              Tab(text: 'Ariza Kodlari'),
              Tab(text: 'Devreye Alma'),
              Tab(text: 'Hizli Parametre'),
              Tab(text: 'Hizli Referans'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceChooserSection({required bool sidebar}) {
    final devices = _deviceCatalogItems();
    final isPhone = !sidebar && _isCompactWidth(context, threshold: 480);
    final list =
        sidebar
            ? ListView.separated(
              itemCount: devices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return _buildDeviceCatalogCard(devices[index], compact: false);
              },
            )
            : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: devices.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                return _buildDeviceCatalogCard(devices[index], compact: true);
              },
            );

    return _buildSurface(
      padding: EdgeInsets.all(isPhone ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cihazlar',
            style: TextStyle(
              fontSize: isPhone ? 17 : 18,
              fontWeight: FontWeight.w900,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textOnDark
                      : AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sidebar
                ? 'Sol listeden cihaz secip rehberi tek cihaza indir.'
                : 'Kaydirarak cihaz secimi yap.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textOnDarkMuted
                      : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(child: list),
        ],
      ),
    );
  }

  Widget _buildDeviceCatalogCard(
    _DeviceCatalogItem item, {
    required bool compact,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = item.key == _selectedDeviceKey();
    final isPhoneCompact = compact && _isCompactWidth(context, threshold: 480);
    final compactCardWidth =
        compact
            ? (MediaQuery.of(context).size.width - 48)
                .clamp(220.0, 280.0)
                .toDouble()
            : double.infinity;
    final Color accent =
        item.isAll ? const Color(0xFF4A7BFF) : const Color(0xFF2E9E8F);

    return SizedBox(
      width: compactCardWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _selectCatalogItem(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.all(isPhoneCompact ? 12 : 16),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? accent.withValues(alpha: isDark ? 0.20 : 0.12)
                      : (isDark ? const Color(0xFF162434) : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isSelected
                        ? accent.withValues(alpha: 0.65)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFD9E5EF)),
                width: isSelected ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child:
                compact
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: isPhoneCompact ? 30 : 34,
                              height: isPhoneCompact ? 30 : 34,
                              decoration: BoxDecoration(
                                color: accent.withValues(
                                  alpha: isSelected ? 0.22 : 0.14,
                                ),
                                borderRadius: BorderRadius.circular(
                                  isPhoneCompact ? 10 : 12,
                                ),
                              ),
                              child: Icon(
                                item.isAll
                                    ? Icons.apps_rounded
                                    : Icons.precision_manufacturing_rounded,
                                size: isPhoneCompact ? 16 : 18,
                                color: accent,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isPhoneCompact ? 7 : 8,
                                  vertical: isPhoneCompact ? 4 : 5,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Aktif',
                                  style: TextStyle(
                                    fontSize: isPhoneCompact ? 10 : 11,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: isPhoneCompact ? 10 : 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.isAll
                                    ? 'Tum Cihazlar'
                                    : _scopeTitle(item.brand, item.model),
                                maxLines: isPhoneCompact ? 2 : 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isPhoneCompact ? 14 : 15,
                                  height: 1.2,
                                  fontWeight: FontWeight.w900,
                                  color:
                                      isDark
                                          ? Colors.white
                                          : const Color(0xFF13304A),
                                ),
                              ),
                              SizedBox(height: isPhoneCompact ? 6 : 8),
                              Text(
                                item.isAll
                                    ? 'Tum marka ve modelleri birlikte gosterir.'
                                    : _scopeSubtitle(item.brand, item.model),
                                maxLines: isPhoneCompact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: isPhoneCompact ? 11 : 12,
                                  height: 1.4,
                                  color:
                                      isDark
                                          ? AppColors.textOnDarkMuted
                                          : AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isPhoneCompact ? 10 : 14),
                        Wrap(
                          spacing: isPhoneCompact ? 6 : 8,
                          runSpacing: isPhoneCompact ? 6 : 8,
                          children: [
                            _buildMiniCountChip(
                              'A',
                              item.faultCount,
                              const Color(0xFFE06C55),
                              compact: isPhoneCompact,
                            ),
                            _buildMiniCountChip(
                              'D',
                              item.stepCount,
                              const Color(0xFF3B9FA1),
                              compact: isPhoneCompact,
                            ),
                            _buildMiniCountChip(
                              'P',
                              item.parameterCount,
                              const Color(0xFFD09A2C),
                              compact: isPhoneCompact,
                            ),
                            _buildMiniCountChip(
                              'R',
                              item.referenceCount,
                              const Color(0xFF7C5CFF),
                              compact: isPhoneCompact,
                            ),
                          ],
                        ),
                      ],
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: accent.withValues(
                                  alpha: isSelected ? 0.22 : 0.14,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                item.isAll
                                    ? Icons.apps_rounded
                                    : Icons.precision_manufacturing_rounded,
                                size: 18,
                                color: accent,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Aktif',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: accent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.isAll
                              ? 'Tum Cihazlar'
                              : _scopeTitle(item.brand, item.model),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF13304A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.isAll
                              ? 'Tum marka ve modelleri birlikte gosterir.'
                              : _scopeSubtitle(item.brand, item.model),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color:
                                isDark
                                    ? AppColors.textOnDarkMuted
                                    : AppColors.textLight,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildMiniCountChip(
                              'A',
                              item.faultCount,
                              const Color(0xFFE06C55),
                            ),
                            _buildMiniCountChip(
                              'D',
                              item.stepCount,
                              const Color(0xFF3B9FA1),
                            ),
                            _buildMiniCountChip(
                              'P',
                              item.parameterCount,
                              const Color(0xFFD09A2C),
                            ),
                            _buildMiniCountChip(
                              'R',
                              item.referenceCount,
                              const Color(0xFF7C5CFF),
                            ),
                          ],
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniCountChip(
    String label,
    int count,
    Color accent, {
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w800,
          color: accent,
        ),
      ),
    );
  }

  ScrollPhysics? _tabScrollPhysics(bool embedded) {
    return embedded ? const NeverScrollableScrollPhysics() : null;
  }

  Widget _buildMobileTabContent() {
    if (_isLoading) {
      return const UiMaxWidth(
        child: UiLoading(message: 'Ariza rehberi yukleniyor...'),
      );
    }

    if (_error != null) {
      return UiMaxWidth(
        child: UiErrorState(message: _error, onRetry: _loadAllData),
      );
    }

    switch (_tabController.index) {
      case 0:
        return _buildFaultCodesTab(embedded: true);
      case 1:
        return _buildCommissioningTab(embedded: true);
      case 2:
        return _buildParametersTab(embedded: true);
      case 3:
        return _buildReferenceValuesTab(embedded: true);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFaultCodesTab({bool embedded = false}) {
    if (_filteredFaults.isEmpty && !_isLoading) {
      return const UiEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Ariza kaydi bulunamadi',
        subtitle: 'Filtreleri daralttiktan sonra tekrar deneyin.',
      );
    }

    if (!_showingAllDevices) {
      return ListView.separated(
        key: PageStorageKey(
          embedded
              ? 'fault_codes_single_device_embedded'
              : 'fault_codes_single_device',
        ),
        shrinkWrap: embedded,
        primary: !embedded,
        physics: _tabScrollPhysics(embedded),
        padding: EdgeInsets.only(bottom: embedded ? 0 : 24),
        itemCount: _filteredFaults.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return UiMaxWidth(
              child: _buildActiveDeviceSectionIntro(
                title: 'Ariza Kodlari',
                subtitle:
                    'Secili cihaz icin tum ariza kodlari asagida listeleniyor.',
                icon: Icons.support_agent_rounded,
                accent: AppColors.corporateYellow,
              ),
            );
          }
          return UiMaxWidth(child: _buildFaultTile(_filteredFaults[index - 1]));
        },
      );
    }

    final groups = _groupedFaults();

    return ListView.separated(
      key: PageStorageKey(
        embedded ? 'fault_codes_groups_embedded' : 'fault_codes_groups',
      ),
      shrinkWrap: embedded,
      primary: !embedded,
      physics: _tabScrollPhysics(embedded),
      padding: EdgeInsets.only(bottom: embedded ? 0 : 24),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildFaultGroup(group);
      },
    );
  }

  Widget _buildCommissioningTab({bool embedded = false}) {
    if (_filteredSteps.isEmpty && !_isLoading) {
      return const UiEmptyState(
        icon: Icons.assignment_outlined,
        title: 'Devreye alma adimi bulunamadi',
        subtitle: 'Marka veya model secimini degistirip tekrar deneyin.',
      );
    }

    if (!_showingAllDevices) {
      return ListView.separated(
        key: PageStorageKey(
          embedded
              ? 'commissioning_single_device_embedded'
              : 'commissioning_single_device',
        ),
        shrinkWrap: embedded,
        primary: !embedded,
        physics: _tabScrollPhysics(embedded),
        padding: EdgeInsets.only(bottom: embedded ? 0 : 24),
        itemCount: _filteredSteps.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return UiMaxWidth(
              child: _buildActiveDeviceSectionIntro(
                title: 'Devreye Alma',
                subtitle:
                    'Adimlari yukaridan asagi takip ederek ayni cihazda calis.',
                icon: Icons.assignment_turned_in_outlined,
                accent: AppColors.corporateBlue,
              ),
            );
          }
          return UiMaxWidth(
            child: _buildCommissioningStepTile(_filteredSteps[index - 1]),
          );
        },
      );
    }

    final groups = _groupedSteps();

    return ListView.separated(
      key: PageStorageKey(
        embedded ? 'commissioning_groups_embedded' : 'commissioning_groups',
      ),
      shrinkWrap: embedded,
      primary: !embedded,
      physics: _tabScrollPhysics(embedded),
      padding: EdgeInsets.only(bottom: embedded ? 0 : 24),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildCommissioningGroup(groups[index]);
      },
    );
  }

  Widget _buildParametersTab({bool embedded = false}) {
    if (_filteredParams.isEmpty && !_isLoading) {
      return const UiEmptyState(
        icon: Icons.tune_rounded,
        title: 'Parametre bulunamadi',
        subtitle: 'Mevcut filtrelerle eslesen hizli parametre kaydi yok.',
      );
    }

    if (!_showingAllDevices) {
      return ListView.separated(
        key: PageStorageKey(
          embedded
              ? 'parameters_single_device_embedded'
              : 'parameters_single_device',
        ),
        shrinkWrap: embedded,
        primary: !embedded,
        physics: _tabScrollPhysics(embedded),
        padding: EdgeInsets.only(bottom: embedded ? 0 : 24),
        itemCount: _filteredParams.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return UiMaxWidth(
              child: _buildActiveDeviceSectionIntro(
                title: 'Hizli Parametre',
                subtitle:
                    'Kod, varsayilan deger ve aciklama tek listede sunuluyor.',
                icon: Icons.tune_rounded,
                accent: AppColors.corporateYellow,
              ),
            );
          }
          return UiMaxWidth(
            child: _buildParameterTile(_filteredParams[index - 1]),
          );
        },
      );
    }

    final groups = _groupedParams();

    return ListView.separated(
      key: PageStorageKey(
        embedded ? 'parameters_groups_embedded' : 'parameters_groups',
      ),
      shrinkWrap: embedded,
      primary: !embedded,
      physics: _tabScrollPhysics(embedded),
      padding: EdgeInsets.only(bottom: embedded ? 0 : 24),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildParameterGroup(groups[index]);
      },
    );
  }

  Widget _buildReferenceValuesTab({bool embedded = false}) {
    if (!_referenceStorageReady) {
      return ListView(
        shrinkWrap: embedded,
        primary: !embedded,
        physics: _tabScrollPhysics(embedded),
        padding: EdgeInsets.only(bottom: embedded ? 0 : 24),
        children: [UiMaxWidth(child: _buildReferenceStorageSetupCard())],
      );
    }

    if (_filteredReferenceValues.isEmpty && !_isLoading) {
      return ListView(
        shrinkWrap: embedded,
        primary: !embedded,
        physics: _tabScrollPhysics(embedded),
        padding: EdgeInsets.only(bottom: embedded ? 0 : 24),
        children: [UiMaxWidth(child: _buildReferenceEmptyCard())],
      );
    }

    if (!_showingAllDevices) {
      return ListView.separated(
        key: PageStorageKey(
          embedded
              ? 'references_single_device_embedded'
              : 'references_single_device',
        ),
        shrinkWrap: embedded,
        primary: !embedded,
        physics: _tabScrollPhysics(embedded),
        padding: EdgeInsets.only(bottom: embedded ? 0 : 24),
        itemCount: _filteredReferenceValues.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return UiMaxWidth(
              child: _buildActiveDeviceSectionIntro(
                title: 'Hizli Referans',
                subtitle:
                    'Sahada surekli bakilan register, deger ve notlar burada tutulur.',
                icon: Icons.bookmarks_outlined,
                accent: const Color(0xFF7C5CFF),
              ),
            );
          }
          return UiMaxWidth(
            child: _buildReferenceValueTile(
              _filteredReferenceValues[index - 1],
            ),
          );
        },
      );
    }

    final groups = _groupedReferenceValues();

    return ListView.separated(
      key: PageStorageKey(
        embedded ? 'references_groups_embedded' : 'references_groups',
      ),
      shrinkWrap: embedded,
      primary: !embedded,
      physics: _tabScrollPhysics(embedded),
      padding: EdgeInsets.only(bottom: embedded ? 0 : 24),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildReferenceGroup(groups[index]);
      },
    );
  }

  Widget _buildReferenceStorageSetupCard() {
    return _buildSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hizli Referans tablosu henuz kurulmamis.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            'Supabase SQL Editor icinde `migration_inverter_reference_values.sql` dosyasini calistirdiginizda bu sekme veri saklamaya hazir olacak.',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textOnDarkMuted
                      : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceEmptyCard() {
    return _buildSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hizli referans kaydi yok.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            'Ornek kullanim: "Set frekans / 40003 / 50 Hz" veya "Modbus adresi / 40001 / 7". Sag ustteki + butonuyla ilk kaydi ekleyebilirsiniz.',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color:
                  Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textOnDarkMuted
                      : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openCreateReferenceDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ilk referansi ekle'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C5CFF),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReferenceGroup(_DeviceGroup<InverterReferenceValue> group) {
    return UiMaxWidth(
      child: _buildSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceSectionHeader(
              brand: group.brand,
              model: group.model,
              countLabel: '${group.items.length} referans',
              icon: Icons.bookmarks_outlined,
              accent: const Color(0xFF7C5CFF),
            ),
            const SizedBox(height: 14),
            ...List.generate(group.items.length, (index) {
              final reference = group.items[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == group.items.length - 1 ? 0 : 10,
                ),
                child: _buildReferenceValueTile(reference),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceValueTile(InverterReferenceValue reference) {
    final bodyColor =
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.textOnDarkMuted
            : AppColors.textDark;
    final isCompact = _isCompactWidth(context, threshold: 430);

    return _buildNestedPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCompact) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF7C5CFF).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                reference.category.trim().isEmpty
                    ? 'Genel'
                    : _referenceCategoryLabel(reference.category),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7C5CFF),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                tooltip: 'Referans islemleri',
                onSelected: (value) {
                  if (value == 'edit') {
                    _openEditReferenceDialog(reference);
                  } else if (value == 'delete') {
                    _confirmDeleteReference(reference);
                  }
                },
                itemBuilder:
                    (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Duzenle')),
                      PopupMenuItem(value: 'delete', child: Text('Sil')),
                    ],
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C5CFF).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    reference.category.trim().isEmpty
                        ? 'Genel'
                        : _referenceCategoryLabel(reference.category),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7C5CFF),
                    ),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Referans islemleri',
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openEditReferenceDialog(reference);
                    } else if (value == 'delete') {
                      _confirmDeleteReference(reference);
                    }
                  },
                  itemBuilder:
                      (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Duzenle')),
                        PopupMenuItem(value: 'delete', child: Text('Sil')),
                      ],
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            reference.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (reference.hasRegisterAddress)
                _buildSummaryPill(
                  icon: Icons.tag_outlined,
                  label: reference.registerAddress,
                ),
              _buildSummaryPill(
                icon: Icons.bolt_outlined,
                label: reference.displayValue,
              ),
              if (reference.sortOrder > 0)
                _buildSummaryPill(
                  icon: Icons.format_list_numbered_rounded,
                  label: 'Sira ${reference.sortOrder}',
                ),
            ],
          ),
          if (reference.hasNote) ...[
            const SizedBox(height: 12),
            Text(
              reference.note,
              style: TextStyle(fontSize: 13, height: 1.6, color: bodyColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveDeviceSectionIntro({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
  }) {
    final selected = _selectedCatalogItem();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color:
                        isDark
                            ? AppColors.textOnDarkMuted
                            : AppColors.textLight,
                  ),
                ),
                if (selected != null && !selected.isAll) ...[
                  const SizedBox(height: 12),
                  _buildDeviceScope(
                    brand: selected.brand,
                    model: selected.model,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageActions() {
    if (_tabController.index != 3 || !_referenceStorageReady) {
      return const <Widget>[];
    }

    return [
      IconButton(
        tooltip: 'Hizli referans ekle',
        onPressed: _openCreateReferenceDialog,
        icon: const Icon(Icons.add_rounded),
      ),
    ];
  }

  String _referenceCategoryLabel(String category) {
    switch (_normalize(category)) {
      case 'modbus':
        return 'Modbus';
      case 'frequency':
        return 'Frekans';
      case 'communication':
        return 'Haberlesme';
      case 'pid':
        return 'PID';
      case 'limits':
        return 'Limit';
      default:
        return category.trim().isEmpty ? 'Genel' : category.trim();
    }
  }

  Future<void> _openCreateReferenceDialog() async {
    await _openReferenceEditor();
  }

  Future<void> _openEditReferenceDialog(
    InverterReferenceValue reference,
  ) async {
    await _openReferenceEditor(existing: reference);
  }

  Future<void> _openReferenceEditor({InverterReferenceValue? existing}) async {
    final draft = await showDialog<_ReferenceEditorDraft>(
      context: context,
      builder:
          (_) => _ReferenceEditorDialog(
            existing: existing,
            initialBrand: _brandFilter == 'all' ? '' : _brandFilter,
            initialModel: _modelFilter == 'all' ? '' : _modelFilter,
          ),
    );

    if (draft == null) return;

    try {
      if (existing == null) {
        final created = await _referenceService.create(
          deviceBrand: draft.deviceBrand,
          deviceModel: draft.deviceModel,
          title: draft.title,
          registerAddress: draft.registerAddress,
          storedValue: draft.storedValue,
          unit: draft.unit,
          category: draft.category,
          note: draft.note,
          sortOrder: draft.sortOrder,
        );
        _upsertReferenceValue(created);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hizli referans kaydedildi.')),
          );
        }
      } else {
        final updated = await _referenceService.update(
          id: existing.id,
          deviceBrand: draft.deviceBrand,
          deviceModel: draft.deviceModel,
          title: draft.title,
          registerAddress: draft.registerAddress,
          storedValue: draft.storedValue,
          unit: draft.unit,
          category: draft.category,
          note: draft.note,
          sortOrder: draft.sortOrder,
        );
        _upsertReferenceValue(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hizli referans guncellendi.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Referans kaydedilemedi: $e')));
      }
    }
  }

  Future<void> _confirmDeleteReference(InverterReferenceValue reference) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Referansi sil'),
          content: Text(
            '"${reference.title}" kaydini silmek istediginizden emin misiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgec'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.corporateRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await _referenceService.delete(reference.id);
      _removeReferenceValue(reference.id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Referans silindi.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Referans silinemedi: $e')));
      }
    }
  }

  void _upsertReferenceValue(InverterReferenceValue value) {
    final index = _referenceValues.indexWhere((item) => item.id == value.id);
    if (index == -1) {
      _referenceValues.add(value);
    } else {
      _referenceValues[index] = value;
    }

    _sortAllData();
    _syncCurrentDeviceSelection();
    _rebuildFilters();
    _applyFilters();
  }

  void _removeReferenceValue(int id) {
    _referenceValues.removeWhere((item) => item.id == id);
    _sortAllData();
    _syncCurrentDeviceSelection();
    _rebuildFilters();
    _applyFilters();
  }

  Widget _buildFaultGroup(_DeviceGroup<Map<String, dynamic>> group) {
    return UiMaxWidth(
      child: _buildSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceSectionHeader(
              brand: group.brand,
              model: group.model,
              countLabel: '${group.items.length} ariza kodu',
              icon: Icons.support_agent_rounded,
              accent: AppColors.corporateYellow,
            ),
            const SizedBox(height: 14),
            ...List.generate(group.items.length, (index) {
              final fault = group.items[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == group.items.length - 1 ? 0 : 10,
                ),
                child: _buildFaultTile(fault),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFaultTile(Map<String, dynamic> fault) {
    final code = _text(fault['code']).isEmpty ? '?' : _text(fault['code']);
    final title = _faultTitle(fault);
    final body = _faultBody(fault);
    final isCritical =
        code.toUpperCase().startsWith('F') || code.contains('Err');
    final badgeColor =
        isCritical ? AppColors.corporateRed : AppColors.corporateYellow;
    final bodyColor =
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.textOnDarkMuted
            : AppColors.textDark;

    return _buildNestedPanel(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey(
            'fault_code_${_scopeKey(_text(fault['device_brand']), _text(fault['device_model']))}_$code',
          ),
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 62,
            child: UiBadge(
              text: code,
              minSize: 36,
              backgroundColor: badgeColor,
              textColor: isCritical ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _previewText(body),
              style: TextStyle(fontSize: 12, height: 1.45, color: bodyColor),
            ),
          ),
          children: [
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: _buildSectionLabel(
                icon: Icons.fact_check_outlined,
                label: 'Teknisyen kontrol notu',
              ),
            ),
            const SizedBox(height: 10),
            Text(body, style: TextStyle(height: 1.6, color: bodyColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildCommissioningGroup(_DeviceGroup<CommissioningStep> group) {
    return UiMaxWidth(
      child: _buildSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceSectionHeader(
              brand: group.brand,
              model: group.model,
              countLabel: '${group.items.length} devreye alma adimi',
              icon: Icons.assignment_turned_in_outlined,
              accent: AppColors.corporateBlue,
            ),
            const SizedBox(height: 14),
            ...List.generate(group.items.length, (index) {
              final step = group.items[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == group.items.length - 1 ? 0 : 10,
                ),
                child: _buildCommissioningStepTile(step),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildCommissioningStepTile(CommissioningStep step) {
    final bodyColor =
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.textOnDarkMuted
            : AppColors.textDark;

    return _buildNestedPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.corporateNavy,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              '${step.stepNumber}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if ((step.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    step.description!,
                    style: TextStyle(height: 1.6, color: bodyColor),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterGroup(_DeviceGroup<QuickParameter> group) {
    return UiMaxWidth(
      child: _buildSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceSectionHeader(
              brand: group.brand,
              model: group.model,
              countLabel: '${group.items.length} hizli parametre',
              icon: Icons.tune_rounded,
              accent: AppColors.corporateYellow,
            ),
            const SizedBox(height: 14),
            ...List.generate(group.items.length, (index) {
              final param = group.items[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == group.items.length - 1 ? 0 : 10,
                ),
                child: _buildParameterTile(param),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildParameterTile(QuickParameter param) {
    final defaultValue =
        (param.defaultValue == null || param.defaultValue!.trim().isEmpty)
            ? '-'
            : param.defaultValue!.trim();
    final bodyColor =
        Theme.of(context).brightness == Brightness.dark
            ? AppColors.textOnDarkMuted
            : AppColors.textDark;
    final isCompact = _isCompactWidth(context, threshold: 620);

    return _buildNestedPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCompact) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiBadge(
                  text: param.parameterCode,
                  backgroundColor: AppColors.corporateBlue,
                  textColor: Colors.white,
                  minSize: 34,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    param.parameterName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildValuePill(label: 'Varsayilan', value: defaultValue),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UiBadge(
                  text: param.parameterCode,
                  backgroundColor: AppColors.corporateBlue,
                  textColor: Colors.white,
                  minSize: 34,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    param.parameterName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildValuePill(label: 'Varsayilan', value: defaultValue),
              ],
            ),
          ],
          if ((param.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              param.description!,
              style: TextStyle(height: 1.6, color: bodyColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceSectionHeader({
    required String brand,
    required String model,
    required String countLabel,
    required IconData icon,
    required Color accent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompact = _isCompactWidth(context, threshold: 560);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCompact) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.22 : 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _scopeTitle(brand, model),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _scopeSubtitle(brand, model),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color:
                              isDark
                                  ? AppColors.textOnDarkMuted
                                  : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSummaryPill(icon: icon, label: countLabel),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isDark ? 0.22 : 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _scopeTitle(brand, model),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _scopeSubtitle(brand, model),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color:
                              isDark
                                  ? AppColors.textOnDarkMuted
                                  : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildSummaryPill(icon: icon, label: countLabel),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _buildDeviceScope(brand: brand, model: model),
        ],
      ),
    );
  }

  Widget _buildNestedPanel({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDarkMuted : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
      ),
      child: child,
    );
  }

  Widget _buildDeviceScope({
    required String brand,
    required String model,
    bool compact = false,
  }) {
    final hasBrand = brand.trim().isNotEmpty;
    final hasModel = model.trim().isNotEmpty;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildScopePill(
          icon: Icons.business_outlined,
          label: hasBrand ? brand : 'Marka belirtilmedi',
          compact: compact,
        ),
        _buildScopePill(
          icon: Icons.memory_rounded,
          label: hasModel ? model : 'Model belirtilmedi',
          compact: compact,
        ),
      ],
    );
  }

  Widget _buildSectionLabel({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.corporateNavy),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.corporateNavy,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryPill({required IconData icon, required String label}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxWidth =
        _isCompactWidth(context, threshold: 560)
            ? MediaQuery.of(context).size.width * 0.74
            : 320.0;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDarkMuted : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? AppColors.textOnDarkMuted : AppColors.textLight,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textOnDark : AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopePill({
    required IconData icon,
    required String label,
    required bool compact,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxWidth =
        _isCompactWidth(context, threshold: 560)
            ? MediaQuery.of(context).size.width * 0.74
            : 280.0;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDarkMuted : AppColors.surfaceAccent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 14 : 16,
            color: isDark ? AppColors.textOnDarkMuted : AppColors.textLight,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textOnDark : AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValuePill({required String label, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxWidth =
        _isCompactWidth(context, threshold: 620)
            ? MediaQuery.of(context).size.width - 88
            : 240.0;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            isDark
                ? AppColors.corporateYellow.withValues(alpha: 0.14)
                : AppColors.corporateYellow.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.corporateYellow.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textOnDarkMuted : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.textOnDark : AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color:
            isDark
                ? AppColors.surfaceDarkRaised.withValues(alpha: 0.94)
                : AppColors.surfaceWhite.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget desktopContent;

    if (_isLoading) {
      desktopContent = const UiLoading(message: 'Ariza rehberi yukleniyor...');
    } else if (_error != null) {
      desktopContent = UiErrorState(message: _error, onRetry: _loadAllData);
    } else {
      desktopContent = TabBarView(
        controller: _tabController,
        children: [
          _buildFaultCodesTab(),
          _buildCommissioningTab(),
          _buildParametersTab(),
          _buildReferenceValuesTab(),
        ],
      );
    }

    return AppLayout(
      currentPage: AppPage.faultCodes,
      title: 'Ariza Rehberi',
      userName: _currentUser?.displayName,
      userRole: _currentUser?.role,
      actions: _buildPageActions(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1180;
          final deviceChooserHeight =
              constraints.maxWidth < 420
                  ? 268.0
                  : constraints.maxWidth < 480
                  ? 248.0
                  : 204.0;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 320,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 0, 18),
                    child: _buildDeviceChooserSection(sidebar: true),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _buildFiltersSection(),
                      _buildTabs(),
                      Expanded(child: desktopContent),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView(
            key: const PageStorageKey('fault_codes_mobile_page'),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _buildFiltersSection(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  height: deviceChooserHeight,
                  child: _buildDeviceChooserSection(sidebar: false),
                ),
              ),
              _buildTabs(),
              _buildMobileTabContent(),
            ],
          );
        },
      ),
    );
  }
}
