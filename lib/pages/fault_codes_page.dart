import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';
import '../models/commissioning_step.dart';
import '../models/quick_parameter.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/ui.dart';

class FaultCodesPage extends StatefulWidget {
  const FaultCodesPage({super.key});

  @override
  State<FaultCodesPage> createState() => _FaultCodesPageState();
}

class _FaultCodesPageState extends State<FaultCodesPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  
  List<Map<String, dynamic>> _faults = [];
  List<Map<String, dynamic>> _filteredFaults = [];
  
  List<CommissioningStep> _steps = [];
  List<CommissioningStep> _filteredSteps = [];
  
  List<QuickParameter> _params = [];
  List<QuickParameter> _filteredParams = [];
  
  bool _isLoading = true;
  String? _error;

  String _brandFilter = 'all';
  String _modelFilter = 'all';
  List<String> _brands = const ['all'];
  List<String> _models = const ['all'];
  
  late TabController _tabController;
  UserProfile? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    if (mounted) {
      setState(() {
        _currentUser = profile;
      });
    }
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final supabase = Supabase.instance.client;
      
      // 1. Arıza Kodları
      try {
        final faultsRes = await supabase.from('fault_codes').select().order('code', ascending: true);
        _faults = List<Map<String, dynamic>>.from(faultsRes);
      } catch (e) {
        debugPrint('Arıza kodları yüklenemedi: $e');
      }

      // 2. Devreye Alma
      try {
        final stepsRes = await supabase.from('commissioning_guides').select().order('step_number', ascending: true);
        _steps = List<Map<String, dynamic>>.from(stepsRes)
            .map((e) {
              try { return CommissioningStep.fromJson(e); } 
              catch (err) { debugPrint('Step parse hatası: $err'); return null; }
            })
            .whereType<CommissioningStep>()
            .toList();
      } catch (e) {
        debugPrint('Devreye alma rehberi yüklenemedi: $e');
      }

      // 3. Hızlı Parametreler
      try {
        final paramsRes = await supabase.from('quick_parameters').select().order('parameter_code', ascending: true);
        _params = List<Map<String, dynamic>>.from(paramsRes)
            .map((e) {
              try { return QuickParameter.fromJson(e); } 
              catch (err) { debugPrint('Param parse hatası: $err'); return null; }
            })
            .whereType<QuickParameter>()
            .toList();
      } catch (e) {
        debugPrint('Hızlı parametreler yüklenemedi: $e');
      }

      if (mounted) {
        setState(() {
          _rebuildFilters();
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Genel veri yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _error = 'Veriler yüklenirken bir hata oluştu.';
          _isLoading = false;
        });
      }
    }
  }

  void _rebuildFilters() {
    final brandSet = <String>{};
    final modelSet = <String>{};

    for (final f in _faults) {
      final b = (f['device_brand'] as String?)?.trim();
      final m = (f['device_model'] as String?)?.trim();
      if (b != null && b.isNotEmpty) brandSet.add(b);
      if (m != null && m.isNotEmpty) modelSet.add(m);
    }
    
    for (final s in _steps) {
      if (s.deviceBrand.isNotEmpty) brandSet.add(s.deviceBrand);
      if (s.deviceModel.isNotEmpty) modelSet.add(s.deviceModel);
    }
    
    for (final p in _params) {
      if (p.deviceBrand.isNotEmpty) brandSet.add(p.deviceBrand);
      if (p.deviceModel.isNotEmpty) modelSet.add(p.deviceModel);
    }

    final brands = brandSet.toList()..sort();
    final models = modelSet.toList()..sort();

    _brands = ['all', ...brands];
    _models = ['all', ...models];

    if (!_brands.contains(_brandFilter)) _brandFilter = 'all';
    if (!_models.contains(_modelFilter)) _modelFilter = 'all';
  }

  void _applyFilters() {
    final q = _normalizeTr(_searchController.text);
    
    setState(() {
      _filteredFaults = _faults.where((f) {
        final bRaw = (f['device_brand'] as String?) ?? '';
        final mRaw = (f['device_model'] as String?) ?? '';
        if (_brandFilter != 'all' && bRaw != _brandFilter) return false;
        if (_modelFilter != 'all' && mRaw != _modelFilter) return false;
        if (q.isEmpty) return true;
        
        return _normalizeTr(f['code'] ?? '').contains(q) || 
               _normalizeTr(f['description'] ?? '').contains(q);
      }).toList();

      _filteredSteps = _steps.where((s) {
        if (_brandFilter != 'all' && s.deviceBrand != _brandFilter) return false;
        if (_modelFilter != 'all' && s.deviceModel != _modelFilter) return false;
        if (q.isEmpty) return true;
        return _normalizeTr(s.title).contains(q) || _normalizeTr(s.description ?? '').contains(q);
      }).toList();

      _filteredParams = _params.where((p) {
        if (_brandFilter != 'all' && p.deviceBrand != _brandFilter) return false;
        if (_modelFilter != 'all' && p.deviceModel != _modelFilter) return false;
        if (q.isEmpty) return true;
        return _normalizeTr(p.parameterCode).contains(q) || 
               _normalizeTr(p.parameterName).contains(q) ||
               _normalizeTr(p.description ?? '').contains(q);
      }).toList();
    });
  }

  Widget _buildFiltersBar(bool isDark) {
    return UiMaxWidth(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Ara...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _applyFilters(); })
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : AppColors.surfaceWhite,
                ),
                onChanged: (_) => _applyFilters(),
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                value: _brandFilter,
                decoration: const InputDecoration(labelText: 'Marka', prefixIcon: Icon(Icons.business)),
                items: _brands.map((b) => DropdownMenuItem(value: b, child: Text(b == 'all' ? 'Tümü' : b, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) { setState(() => _brandFilter = val ?? 'all'); _applyFilters(); },
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                value: _modelFilter,
                decoration: const InputDecoration(labelText: 'Model', prefixIcon: Icon(Icons.precision_manufacturing_outlined)),
                items: _models.map((m) => DropdownMenuItem(value: m, child: Text(m == 'all' ? 'Tümü' : m, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) { setState(() => _modelFilter = val ?? 'all'); _applyFilters(); },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaultCodesTab() {
    if (_filteredFaults.isEmpty && !_isLoading) return const UiEmptyState(icon: Icons.search_off, title: 'Kayıt bulunamadı');
    
    return ListView.separated(
      key: const PageStorageKey('fault_codes_list'),
      padding: const EdgeInsets.all(16),
      itemCount: _filteredFaults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final fault = _filteredFaults[index];
        final String code = (fault['code'] ?? '').toString();
        final String description = (fault['description'] ?? '').toString();
        final String brand = (fault['device_brand'] ?? '').toString();
        final String model = (fault['device_model'] ?? '').toString();
        final String causes = (fault['possible_causes'] ?? 'Bilgi yok').toString();
        
        final bool isCritical = code.startsWith('F') || code.contains('Error');
        final badgeColor = isCritical ? AppColors.corporateRed : AppColors.corporateYellow;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey('fault_$code'),
              leading: SizedBox(
                width: 56,
                child: UiBadge(
                  text: code.isEmpty ? '?' : code, 
                  backgroundColor: badgeColor, 
                  textColor: isCritical ? Colors.white : Colors.black,
                  minSize: 32,
                ),
              ),
              title: Text(
                description.isEmpty ? 'Açıklama yok' : description,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                '${brand.isEmpty ? "—" : brand} ${model.isEmpty ? "—" : model}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.lightbulb_outline, size: 16, color: AppColors.corporateNavy),
                          SizedBox(width: 8),
                          Text(
                            'Olası Nedenler & Çözüm:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.corporateNavy),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        causes,
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommissioningTab() {
    if (_filteredSteps.isEmpty && !_isLoading) return const UiEmptyState(icon: Icons.assignment_outlined, title: 'Rehber bulunamadı');
    return ListView.builder(
      key: const PageStorageKey('commissioning_list'),
      padding: const EdgeInsets.all(16),
      itemCount: _filteredSteps.length,
      itemBuilder: (context, index) {
        final step = _filteredSteps[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.corporateNavy,
                      radius: 14,
                      child: Text('${step.stepNumber}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(step.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                  ],
                ),
                if (step.description != null) ...[
                  const SizedBox(height: 12),
                  Text(step.description!, style: const TextStyle(height: 1.5)),
                ],
                const SizedBox(height: 8),
                Text('${step.deviceBrand} ${step.deviceModel}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildParametersTab() {
    if (_filteredParams.isEmpty && !_isLoading) return const UiEmptyState(icon: Icons.list_alt, title: 'Parametre bulunamadı');
    return ListView(
      key: const PageStorageKey('parameters_list'),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Table(
            border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
            columnWidths: const {
              0: FixedColumnWidth(75),
              1: FlexColumnWidth(2),
              2: FixedColumnWidth(85),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(padding: EdgeInsets.all(10), child: Text('Kod', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  Padding(padding: EdgeInsets.all(10), child: Text('Parametre Adı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  Padding(padding: EdgeInsets.all(10), child: Text('Varsayılan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                ],
              ),
              ..._filteredParams.map((p) => TableRow(
                children: [
                  Padding(padding: const EdgeInsets.all(10), child: Text(p.parameterCode, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.corporateNavy, fontSize: 12))),
                  Padding(
                    padding: const EdgeInsets.all(10), 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.parameterName, style: const TextStyle(fontSize: 13)),
                        if (p.description != null && p.description!.isNotEmpty) 
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(p.description!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ),
                      ],
                    )
                  ),
                  Padding(padding: const EdgeInsets.all(10), child: Text(p.defaultValue ?? '-', style: const TextStyle(fontSize: 12))),
                ],
              )),
            ],
          ),
        ),
      ],
    );
  }

  String _normalizeTr(String text) {
    return text
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .replaceAll('Ş', 'ş')
        .replaceAll('Ğ', 'ğ')
        .replaceAll('Ü', 'ü')
        .replaceAll('Ö', 'ö')
        .replaceAll('Ç', 'ç')
        .toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('İNVERTÖR REHBERİ'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Arıza Kodları'),
            Tab(text: 'Devreye Alma'),
            Tab(text: 'Hızlı Parametre'),
          ],
        ),
      ),
      drawer: AppDrawer(
        currentPage: AppDrawerPage.faultCodes,
        userName: _currentUser?.displayName,
        userRole: _currentUser?.role,
      ),
      body: Column(
        children: [
          _buildFiltersBar(isDark),
          Expanded(
            child: _isLoading
                ? const UiLoading(message: 'Yükleniyor...')
                : _error != null
                    ? UiErrorState(message: _error, onRetry: _loadAllData)
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFaultCodesTab(),
                          _buildCommissioningTab(),
                          _buildParametersTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
