import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/ui.dart';

class FaultCodesPage extends StatefulWidget {
  const FaultCodesPage({super.key});

  @override
  State<FaultCodesPage> createState() => _FaultCodesPageState();
}

class _FaultCodesPageState extends State<FaultCodesPage> {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  List<Map<String, dynamic>> _faults = [];
  List<Map<String, dynamic>> _filteredFaults = [];
  bool _isLoading = true;
  String? _error;

  String _brandFilter = 'all';
  String _modelFilter = 'all';
  List<String> _brands = const ['all'];
  List<String> _models = const ['all'];

  Map<String, dynamic>? _selectedFault; // desktop split view
  
  // User Info
  UserProfile? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadFaultCodes();
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _loadFaultCodes() async {
    try {
      final response = await Supabase.instance.client
          .from('fault_codes')
          .select()
          .order('code', ascending: true);
      
      if (mounted) {
        setState(() {
          _faults = List<Map<String, dynamic>>.from(response);
          _rebuildFilters();
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Veriler yüklenirken hata oluştu: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _normalizeTr(String text) {
    if (text.isEmpty) return '';

    final sb = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      switch (ch) {
        case 'İ':
          sb.write('i');
          break;
        case 'I':
          sb.write('ı');
          break;
        default:
          sb.write(ch.toLowerCase());
          break;
      }
    }
    return sb.toString().trim();
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

    final brands = brandSet.toList()..sort();
    final models = modelSet.toList()..sort();

    _brands = ['all', ...brands];
    _models = ['all', ...models];
  }

  void _applyFilters() {
    final q = _normalizeTr(_searchController.text);
    setState(() {
      _filteredFaults = _faults.where((fault) {
        final codeRaw = (fault['code'] as String?) ?? '';
        final descRaw = (fault['description'] as String?) ?? '';
        final causesRaw = (fault['possible_causes'] as String?) ?? '';
        final brandRaw = (fault['device_brand'] as String?) ?? '';
        final modelRaw = (fault['device_model'] as String?) ?? '';

        if (_brandFilter != 'all' && brandRaw != _brandFilter) return false;
        if (_modelFilter != 'all' && modelRaw != _modelFilter) return false;

        if (q.isEmpty) return true;

        final code = _normalizeTr(codeRaw);
        final desc = _normalizeTr(descRaw);
        final causes = _normalizeTr(causesRaw);
        final brand = _normalizeTr(brandRaw);
        final model = _normalizeTr(modelRaw);
        
        if (code.startsWith(q) || desc.startsWith(q)) return true;

        return code.contains(q) ||
            desc.contains(q) ||
            causes.contains(q) ||
            brand.contains(q) ||
            model.contains(q);
      }).toList();

      if (_selectedFault != null &&
          !_filteredFaults.any((e) => e['id'] == _selectedFault!['id'])) {
        _selectedFault = null;
      }
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
                  hintText: 'Kod, açıklama, neden, marka/model ara...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : AppColors.surfaceWhite,
                ),
                onChanged: (_) => _applyFilters(),
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: _brandFilter,
                decoration: const InputDecoration(
                  labelText: 'Marka',
                  prefixIcon: Icon(Icons.business),
                ),
                items: _brands
                    .map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(b == 'all' ? 'Tümü' : b, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() => _brandFilter = val ?? 'all');
                  _applyFilters();
                },
              ),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: _modelFilter,
                decoration: const InputDecoration(
                  labelText: 'Model/Seri',
                  prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                ),
                items: _models
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m == 'all' ? 'Tümü' : m, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() => _modelFilter = val ?? 'all');
                  _applyFilters();
                },
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _brandFilter = 'all';
                  _modelFilter = 'all';
                  _searchController.clear();
                });
                _applyFilters();
              },
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Temizle'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaultList({required bool isDesktop}) {
    if (_filteredFaults.isEmpty) {
      return const UiEmptyState(
        icon: Icons.search_off,
        title: 'Kayıt bulunamadı',
        subtitle: 'Filtreleri temizleyip tekrar deneyin.',
      );
    }

    if (!isDesktop) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _filteredFaults.length,
        itemBuilder: (context, index) {
          final fault = _filteredFaults[index];
          final code = fault['code']?.toString() ?? '';
          final brand = (fault['device_brand'] ?? '').toString();
          final model = (fault['device_model'] ?? '').toString();

          final isFault = code.startsWith('F');
          final badgeColor = isFault ? AppColors.corporateRed : AppColors.corporateYellow;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor),
                ),
                child: Text(
                  code,
                  style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor),
                ),
              ),
              title: Text(
                (fault['description'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Text(
                '$brand $model'.trim(),
                style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Olası Nedenler',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Kodu kopyala',
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: code));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Kopyalandı')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (fault['possible_causes'] ?? 'Bilgi yok').toString(),
                        style: const TextStyle(fontSize: 14),
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

    return ListView.separated(
      padding: const EdgeInsets.only(left: 16, right: 12, top: 8, bottom: 16),
      itemCount: _filteredFaults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final fault = _filteredFaults[index];
        final code = fault['code']?.toString() ?? '';
        final desc = (fault['description'] ?? '').toString();
        final brand = (fault['device_brand'] ?? '').toString();
        final model = (fault['device_model'] ?? '').toString();
        final selected = _selectedFault != null && _selectedFault!['id'] == fault['id'];

        final isFault = code.startsWith('F');
        final badgeColor = isFault ? AppColors.corporateRed : AppColors.corporateYellow;

        return UiCard(
          onTap: () => setState(() => _selectedFault = fault),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UiBadge(
                text: code,
                backgroundColor: badgeColor,
                textColor: Colors.black,
                minSize: 22,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$brand $model'.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFaultDetails(Map<String, dynamic> fault) {
    final theme = Theme.of(context);
    final code = fault['code']?.toString() ?? '';
    final desc = (fault['description'] ?? '').toString();
    final causes = (fault['possible_causes'] ?? 'Bilgi yok').toString();
    final brand = (fault['device_brand'] ?? '').toString();
    final model = (fault['device_model'] ?? '').toString();

    final isFault = code.startsWith('F');
    final badgeColor = isFault ? AppColors.corporateRed : AppColors.corporateYellow;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 16, top: 8, bottom: 16),
      child: UiCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UiBadge(
                  text: code,
                  backgroundColor: badgeColor,
                  textColor: Colors.black,
                  minSize: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    desc,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Kodu kopyala',
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kopyalandı')),
                      );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$brand $model'.trim(),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Olası Nedenler',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(causes, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ARIZA REHBERİ'),
        centerTitle: true,
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
                    ? UiErrorState(message: _error, onRetry: _loadFaultCodes)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isDesktop = constraints.maxWidth >= 900;
                          if (!isDesktop) {
                            return _buildFaultList(isDesktop: false);
                          }

                          return Row(
                            children: [
                              Expanded(flex: 7, child: _buildFaultList(isDesktop: true)),
                              const VerticalDivider(width: 1),
                              Expanded(
                                flex: 8,
                                child: _selectedFault == null
                                    ? const UiEmptyState(
                                        icon: Icons.touch_app_outlined,
                                        title: 'Bir arıza kodu seçin',
                                        subtitle: 'Detayları sağ panelde göreceksiniz.',
                                      )
                                    : _buildFaultDetails(_selectedFault!),
                              ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

