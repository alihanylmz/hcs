import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/own_company.dart';
import '../models/price_adjustment_rule.dart';
import '../models/user_quote_profile.dart';
import '../services/admin_repository.dart';
import '../services/company_stamp_service.dart';
import '../services/own_company_repository.dart';
import '../services/price_adjustment_rule_repository.dart';
import '../services/user_profile_repository.dart';
import '../widgets/workspace_background.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({
    super.key,
    required this.userProfileRepository,
    required this.adminRepository,
    required this.ownCompanyRepository,
    required this.priceAdjustmentRuleRepository,
  });

  final UserProfileRepository userProfileRepository;
  final AdminRepository adminRepository;
  final OwnCompanyRepository ownCompanyRepository;
  final PriceAdjustmentRuleRepository priceAdjustmentRuleRepository;

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<UserQuoteProfile> _users = const [];
  List<Map<String, dynamic>> _auditLogs = const [];
  List<Map<String, dynamic>> _revisions = const [];
  List<PriceAdjustmentRule> _priceRules = const [];
  List<OwnCompany> _companies = const [];
  final _stampService = const CompanyStampService();
  String? _stampPath;
  bool _loading = true;
  bool _isPickingStamp = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final users = await widget.userProfileRepository.fetchAll();
    final logs = await widget.adminRepository.fetchAuditLogs();
    final revisions = await widget.adminRepository.fetchQuoteRevisions();
    final rules = await widget.priceAdjustmentRuleRepository.fetchRules();
    final companies = await widget.ownCompanyRepository.fetchAll();
    final stamp = await _stampService.getExistingStampPath();
    if (!mounted) return;
    setState(() {
      _users = users;
      _auditLogs = logs;
      _revisions = revisions;
      _priceRules = rules;
      _companies = companies;
      _stampPath = stamp;
      _loading = false;
    });
  }

  Future<void> _changeRole(UserQuoteProfile user, String role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _RoleChangeDialog(user: user, role: role),
    );
    if (confirmed != true) return;
    await widget.userProfileRepository.updateRole(
      userId: user.userId,
      role: role,
    );
    await _reload();
  }

  Future<void> _pickStamp() async {
    if (_isPickingStamp) return;
    setState(() => _isPickingStamp = true);
    try {
      final path = await _stampService.pickAndStore();
      if (!mounted || path == null) return;
      setState(() => _stampPath = path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kurumsal onay mührü güncellendi.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mühür yüklenemedi: $error')));
    } finally {
      if (mounted) setState(() => _isPickingStamp = false);
    }
  }

  Future<void> _removeStamp() async {
    await _stampService.remove();
    if (!mounted) return;
    setState(() => _stampPath = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kurumsal onay mührü kaldırıldı.')),
    );
  }

  Future<void> _editCompany(OwnCompany? existing) async {
    final company = await showDialog<OwnCompany>(
      context: context,
      builder: (context) => _OwnCompanyDialog(existing: existing),
    );
    if (company == null) return;
    await widget.ownCompanyRepository.save(company);
    await _reload();
  }

  Future<void> _setDefaultCompany(OwnCompany company) async {
    await widget.ownCompanyRepository.setDefault(company.id);
    await _reload();
  }

  Future<void> _deleteCompany(OwnCompany company) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Firma silinsin mi?'),
        content: Text(company.menuLabel),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.ownCompanyRepository.deleteById(company.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kurumsal Yönetim'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_rounded), text: 'Kullanıcılar'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Audit Log'),
            Tab(icon: Icon(Icons.restore_page_rounded), text: 'Revizyonlar'),
            Tab(icon: Icon(Icons.apartment_rounded), text: 'Firmalar'),
            Tab(icon: Icon(Icons.percent_rounded), text: 'Fiyat Politikaları'),
            Tab(
              icon: Icon(Icons.settings_applications_rounded),
              text: 'Sistem',
            ),
          ],
        ),
      ),
      body: WorkspaceBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUsers(),
                    _buildReadableAuditLogs(),
                    _buildReadableRevisions(),
                    _buildCompanies(),
                    _buildPriceRules(),
                    _buildSystemSettings(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildUsers() {
    return _PanelTable(
      header: const Row(
        children: [
          Expanded(flex: 3, child: _Th('Kullanıcı')),
          Expanded(flex: 2, child: _Th('E-posta')),
          SizedBox(width: 220, child: _Th('Rol')),
        ],
      ),
      children: [
        for (final user in _users)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _Cell(
                  user.preparedByName.isEmpty
                      ? user.userId
                      : user.preparedByName,
                  strong: true,
                ),
              ),
              Expanded(flex: 2, child: _Cell(user.preparedByEmail)),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: UserQuoteProfile.normalizeRole(user.role),
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: _roles
                      .map(
                        (role) => DropdownMenuItem(
                          value: role,
                          child: Text(UserQuoteProfile.roleLabel(role)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    _changeRole(user, value);
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildReadableAuditLogs() {
    return _PanelTable(
      header: const Row(
        children: [
          SizedBox(width: 140, child: _Th('Tarih')),
          Expanded(flex: 2, child: _Th('Kullanıcı')),
          Expanded(flex: 2, child: _Th('İşlem')),
          Expanded(flex: 4, child: _Th('Kayıt Özeti')),
        ],
      ),
      children: [
        for (final log in _auditLogs)
          Row(
            children: [
              SizedBox(width: 140, child: _Cell(_date(log['created_at']))),
              Expanded(flex: 2, child: _Cell(_actorLabel(log['actor_id']))),
              Expanded(
                flex: 2,
                child: _Cell(_auditActionLabel(log), strong: true),
              ),
              Expanded(flex: 4, child: _Cell(_auditRecordSummary(log))),
            ],
          ),
      ],
    );
  }

  Widget _buildReadableRevisions() {
    return _PanelTable(
      header: const Row(
        children: [
          SizedBox(width: 140, child: _Th('Tarih')),
          Expanded(flex: 2, child: _Th('Kullanıcı')),
          Expanded(flex: 2, child: _Th('Teklif')),
          SizedBox(width: 90, child: _Th('Rev')),
          Expanded(flex: 4, child: _Th('Değişiklik Özeti')),
        ],
      ),
      children: [
        for (final rev in _revisions)
          Row(
            children: [
              SizedBox(width: 140, child: _Cell(_date(rev['created_at']))),
              Expanded(flex: 2, child: _Cell(_actorLabel(rev['changed_by']))),
              Expanded(
                flex: 2,
                child: _Cell(_revisionCodeLabel(rev), strong: true),
              ),
              SizedBox(width: 90, child: _Cell('${rev['revision_no'] ?? 0}')),
              Expanded(flex: 4, child: _Cell(_revisionSummary(rev))),
            ],
          ),
      ],
    );
  }

  String _actorLabel(dynamic actorId) {
    final id = '${actorId ?? ''}'.trim();
    if (id.isEmpty) return 'Sistem';
    for (final user in _users) {
      if (user.userId == id) {
        if (user.preparedByName.trim().isNotEmpty) {
          return user.preparedByName.trim();
        }
        if (user.preparedByEmail.trim().isNotEmpty) {
          return user.preparedByEmail.trim();
        }
      }
    }
    return 'Kullanıcı ${id.length > 8 ? id.substring(0, 8) : id}';
  }

  String _auditActionLabel(Map<String, dynamic> log) {
    final action = '${log['action'] ?? ''}'.toUpperCase();
    final table = _tableLabel('${log['table_name'] ?? ''}');
    return switch (action) {
      'INSERT' => '$table oluşturdu',
      'UPDATE' => '$table güncelledi',
      'DELETE' => '$table sildi',
      _ => '$table işlem yaptı',
    };
  }

  String _auditRecordSummary(Map<String, dynamic> log) {
    final action = '${log['action'] ?? ''}'.toUpperCase();
    final data = _mapFrom(
      action == 'DELETE' ? log['old_data'] : log['new_data'],
    );
    final oldData = _mapFrom(log['old_data']);
    final table = '${log['table_name'] ?? ''}';
    final title = _recordTitle(table, data.isEmpty ? oldData : data);
    final changes = action == 'UPDATE' ? _changedFields(oldData, data) : '';
    if (changes.isNotEmpty) return '$title - $changes';
    return title.isEmpty ? 'Kayıt: ${log['record_id'] ?? '-'}' : title;
  }

  String _revisionCodeLabel(Map<String, dynamic> rev) {
    final code = '${rev['code'] ?? ''}'.trim();
    if (code.isNotEmpty) return code;
    final snapshot = _mapFrom(rev['snapshot']);
    return '${snapshot['code'] ?? rev['quote_id'] ?? '-'}';
  }

  String _revisionSummary(Map<String, dynamic> rev) {
    final snapshot = _mapFrom(rev['snapshot']);
    final customer = [
      '${snapshot['customer_company'] ?? ''}'.trim(),
      '${snapshot['customer_name'] ?? ''}'.trim(),
    ].where((part) => part.isNotEmpty).join(' / ');
    final status = _statusLabel('${snapshot['status'] ?? ''}');
    final total = _formatMoney(snapshot['subtotal_tl']);
    return [
      if (customer.isNotEmpty) customer,
      if (status.isNotEmpty) 'Durum: $status',
      if (total.isNotEmpty) 'Tutar: $total',
    ].join(' - ');
  }

  Map<String, dynamic> _mapFrom(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

  String _recordTitle(String table, Map<String, dynamic> data) {
    switch (table) {
      case 'quotes':
        return [
          'Teklif',
          '${data['code'] ?? data['id'] ?? ''}'.trim(),
          '${data['customer_company'] ?? ''}'.trim(),
        ].where((part) => part.isNotEmpty).join(' - ');
      case 'customer_accounts':
        return [
          'Cari',
          '${data['company_name'] ?? ''}'.trim(),
          '${data['contact_name'] ?? ''}'.trim(),
        ].where((part) => part.isNotEmpty).join(' - ');
      case 'products':
        return [
          'Ürün',
          '${data['code'] ?? ''}'.trim(),
          '${data['name'] ?? ''}'.trim(),
        ].where((part) => part.isNotEmpty).join(' - ');
      case 'price_adjustment_rules':
        return [
          'Fiyat politikası',
          '${data['name'] ?? ''}'.trim(),
          '${data['percentage'] ?? ''}'.trim(),
        ].where((part) => part.isNotEmpty).join(' - ');
      case 'own_companies':
        return [
          'Firma',
          '${data['name'] ?? ''}'.trim(),
        ].where((part) => part.isNotEmpty).join(' - ');
      default:
        return '${data['id'] ?? ''}'.trim();
    }
  }

  String _tableLabel(String table) {
    return switch (table) {
      'quotes' => 'Teklif',
      'customer_accounts' => 'Cari',
      'products' => 'Ürün',
      'price_adjustment_rules' => 'Fiyat politikası',
      'own_companies' => 'Firma',
      _ => table.isEmpty ? 'Kayıt' : table,
    };
  }

  String _changedFields(
    Map<String, dynamic> oldData,
    Map<String, dynamic> data,
  ) {
    final labels = <String>[];
    const tracked = {
      'status': 'durum',
      'title': 'başlık',
      'customer_company': 'cari',
      'subtotal_tl': 'tutar',
      'sale_price': 'satış fiyatı',
      'stock_quantity': 'stok',
      'company_name': 'firma adı',
      'name': 'ad',
      'percentage': 'oran',
      'is_default': 'varsayılan',
    };
    for (final entry in tracked.entries) {
      if (!oldData.containsKey(entry.key) && !data.containsKey(entry.key)) {
        continue;
      }
      if ('${oldData[entry.key]}' != '${data[entry.key]}') {
        labels.add(entry.value);
      }
    }
    if (labels.isEmpty) return 'detaylar güncellendi';
    return '${labels.take(4).join(', ')} güncellendi';
  }

  String _statusLabel(String status) {
    return switch (status) {
      'draft' => 'Taslak',
      'sent' || 'pending' => 'Gönderildi',
      'approved' => 'Onaylandı',
      'rejected' => 'Reddedildi',
      'cancelled' => 'İptal',
      _ => status,
    };
  }

  String _formatMoney(dynamic raw) {
    final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (value == null || value <= 0) return '';
    return NumberFormat.currency(
      locale: 'tr_TR',
      symbol: 'TL ',
      decimalDigits: 2,
    ).format(value);
  }

  // ignore: unused_element
  Widget _buildAuditLogs() {
    return _PanelTable(
      header: const Row(
        children: [
          SizedBox(width: 140, child: _Th('Tarih')),
          SizedBox(width: 110, child: _Th('İşlem')),
          Expanded(flex: 2, child: _Th('Tablo')),
          Expanded(flex: 3, child: _Th('Kayıt')),
        ],
      ),
      children: [
        for (final log in _auditLogs)
          Row(
            children: [
              SizedBox(width: 140, child: _Cell(_date(log['created_at']))),
              SizedBox(
                width: 110,
                child: _Cell('${log['action'] ?? ''}', strong: true),
              ),
              Expanded(flex: 2, child: _Cell('${log['table_name'] ?? ''}')),
              Expanded(flex: 3, child: _Cell('${log['record_id'] ?? ''}')),
            ],
          ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildRevisions() {
    return _PanelTable(
      header: const Row(
        children: [
          SizedBox(width: 140, child: _Th('Tarih')),
          Expanded(flex: 2, child: _Th('Teklif')),
          SizedBox(width: 90, child: _Th('Rev')),
          Expanded(flex: 3, child: _Th('Kayıt ID')),
        ],
      ),
      children: [
        for (final rev in _revisions)
          Row(
            children: [
              SizedBox(width: 140, child: _Cell(_date(rev['created_at']))),
              Expanded(
                flex: 2,
                child: _Cell('${rev['code'] ?? ''}', strong: true),
              ),
              SizedBox(width: 90, child: _Cell('${rev['revision_no'] ?? 0}')),
              Expanded(flex: 3, child: _Cell('${rev['quote_id'] ?? ''}')),
            ],
          ),
      ],
    );
  }

  Widget _buildCompanies() {
    return _PanelTable(
      header: Row(
        children: [
          Expanded(flex: 3, child: _Th('Firma')),
          Expanded(flex: 3, child: _Th('Vergi / Adres')),
          SizedBox(width: 150, child: _Th('Durum')),
          SizedBox(width: 96, child: _Th('İşlem')),
        ],
      ),
      toolbar: Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: () => _editCompany(null),
          icon: const Icon(Icons.add_business_rounded),
          label: const Text('Firma Ekle'),
        ),
      ),
      children: [
        for (final company in _companies)
          Row(
            children: [
              Expanded(flex: 3, child: _Cell(company.name, strong: true)),
              Expanded(
                flex: 3,
                child: _Cell(
                  [
                    if (company.taxOffice.isNotEmpty) company.taxOffice,
                    if (company.taxNumber.isNotEmpty) company.taxNumber,
                    if (company.address.isNotEmpty) company.address,
                  ].join(' / '),
                ),
              ),
              SizedBox(
                width: 150,
                child: company.isDefault
                    ? const _Cell('Varsayılan', strong: true)
                    : TextButton(
                        onPressed: () => _setDefaultCompany(company),
                        child: const Text('Varsayılan Yap'),
                      ),
              ),
              SizedBox(
                width: 96,
                child: PopupMenuButton<String>(
                  tooltip: 'İşlemler',
                  onSelected: (value) {
                    if (value == 'edit') _editCompany(company);
                    if (value == 'delete') _deleteCompany(company);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                    PopupMenuItem(value: 'delete', child: Text('Sil')),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPriceRules() {
    return _PanelTable(
      header: const Row(
        children: [
          Expanded(flex: 3, child: _Th('Kural')),
          Expanded(flex: 2, child: _Th('Kapsam')),
          Expanded(flex: 2, child: _Th('Hedef')),
          SizedBox(width: 120, child: _Th('Oran')),
        ],
      ),
      children: [
        for (final rule in _priceRules)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _Cell(
                  rule.name.isEmpty ? rule.id : rule.name,
                  strong: true,
                ),
              ),
              Expanded(flex: 2, child: _Cell(rule.scope.label)),
              Expanded(
                flex: 2,
                child: _Cell(switch (rule.scope) {
                  PriceAdjustmentScope.brand => rule.brand,
                  PriceAdjustmentScope.category => rule.category,
                  PriceAdjustmentScope.brandAndCategory =>
                    '${rule.brand} / ${rule.category}',
                }),
              ),
              SizedBox(
                width: 120,
                child: _Cell(
                  '${rule.percentage >= 0 ? '+' : ''}${rule.percentage.toStringAsFixed(2)}%',
                  strong: true,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSystemSettings() {
    const ink = Color(0xFF17304C);
    const slate = Color(0xFF5B6F7F);
    final path = _stampPath;
    final hasStamp = path != null && path.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sistem Ayarları',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'PDF çıktıları ve kurumsal davranışlar bu alandan yönetilir.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: slate,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  border: Border.all(color: const Color(0xFFD7DEE6)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F4F8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD7DEE6)),
                      ),
                      child: hasStamp
                          ? Image.file(
                              File(path),
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.broken_image_outlined,
                                color: ink,
                              ),
                            )
                          : const Icon(
                              Icons.approval_rounded,
                              size: 30,
                              color: ink,
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kurumsal Onay Mührü',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: ink,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasStamp
                                ? 'Onaylı teklif PDF çıktılarında bu mühür kullanılır.'
                                : 'PNG, JPG, JPEG veya WEBP formatında mühür görseli yükleyin.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: slate,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: _isPickingStamp ? null : _pickStamp,
                      icon: _isPickingStamp
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              hasStamp
                                  ? Icons.swap_horiz_rounded
                                  : Icons.upload_file_rounded,
                            ),
                      label: Text(hasStamp ? 'Değiştir' : 'Yükle'),
                    ),
                    if (hasStamp) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Mührü kaldır',
                        onPressed: _removeStamp,
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: const Color(0xFF9D5C1D),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _roles = [
    'admin',
    'manager',
    'sales',
    'finance',
    'operations',
    'viewer',
  ];

  static String _date(dynamic raw) {
    if (raw is! String) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    return DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(dt.toLocal());
  }
}

class _RoleChangeDialog extends StatelessWidget {
  const _RoleChangeDialog({required this.user, required this.role});

  final UserQuoteProfile user;
  final String role;

  @override
  Widget build(BuildContext context) {
    final name = user.preparedByName.trim().isEmpty
        ? user.preparedByEmail
        : user.preparedByName;
    return AlertDialog(
      title: const Text('Rol Değişikliği'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.trim().isEmpty ? user.userId : name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: const Color(0xFF17304C),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu kullanıcının rolü "${UserQuoteProfile.roleLabel(role)}" olarak güncellenecek.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5B6F7F),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.admin_panel_settings_rounded),
          label: const Text('Rolü Güncelle'),
        ),
      ],
    );
  }
}

class _OwnCompanyDialog extends StatefulWidget {
  const _OwnCompanyDialog({this.existing});

  final OwnCompany? existing;

  @override
  State<_OwnCompanyDialog> createState() => _OwnCompanyDialogState();
}

class _OwnCompanyDialogState extends State<_OwnCompanyDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _shortName;
  late final TextEditingController _tagline;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _website;
  late final TextEditingController _address;
  late final TextEditingController _taxOffice;
  late final TextEditingController _taxNumber;
  late final TextEditingController _mersis;
  late final TextEditingController _bankName;
  late final TextEditingController _bankBranch;
  late final TextEditingController _bankAccountName;
  late final TextEditingController _bankIban;
  late final TextEditingController _bankSwift;
  late final TextEditingController _vatRate;
  late bool _isDefault;

  @override
  void initState() {
    super.initState();
    final company = widget.existing ?? OwnCompany.fallback();
    _name = TextEditingController(text: widget.existing?.name ?? company.name);
    _shortName = TextEditingController(text: widget.existing?.shortName ?? '');
    _tagline = TextEditingController(text: widget.existing?.tagline ?? '');
    _phone = TextEditingController(text: widget.existing?.phone ?? '');
    _email = TextEditingController(text: widget.existing?.email ?? '');
    _website = TextEditingController(text: widget.existing?.website ?? '');
    _address = TextEditingController(text: widget.existing?.address ?? '');
    _taxOffice = TextEditingController(text: widget.existing?.taxOffice ?? '');
    _taxNumber = TextEditingController(text: widget.existing?.taxNumber ?? '');
    _mersis = TextEditingController(text: widget.existing?.mersis ?? '');
    _bankName = TextEditingController(text: widget.existing?.bankName ?? '');
    _bankBranch = TextEditingController(
      text: widget.existing?.bankBranch ?? '',
    );
    _bankAccountName = TextEditingController(
      text: widget.existing?.bankAccountName ?? '',
    );
    _bankIban = TextEditingController(text: widget.existing?.bankIban ?? '');
    _bankSwift = TextEditingController(text: widget.existing?.bankSwift ?? '');
    _vatRate = TextEditingController(
      text: (widget.existing?.defaultVatRate ?? company.defaultVatRate)
          .toStringAsFixed(0),
    );
    _isDefault = widget.existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _shortName.dispose();
    _tagline.dispose();
    _phone.dispose();
    _email.dispose();
    _website.dispose();
    _address.dispose();
    _taxOffice.dispose();
    _taxNumber.dispose();
    _mersis.dispose();
    _bankName.dispose();
    _bankBranch.dispose();
    _bankAccountName.dispose();
    _bankIban.dispose();
    _bankSwift.dispose();
    _vatRate.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      OwnCompany(
        id:
            widget.existing?.id ??
            'company-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        shortName: _shortName.text.trim(),
        tagline: _tagline.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        website: _website.text.trim(),
        address: _address.text.trim(),
        taxOffice: _taxOffice.text.trim(),
        taxNumber: _taxNumber.text.trim(),
        mersis: _mersis.text.trim(),
        bankName: _bankName.text.trim(),
        bankBranch: _bankBranch.text.trim(),
        bankAccountName: _bankAccountName.text.trim(),
        bankIban: _bankIban.text.trim(),
        bankSwift: _bankSwift.text.trim(),
        defaultVatRate:
            double.tryParse(_vatRate.text.trim().replaceAll(',', '.')) ?? 20,
        isDefault: _isDefault,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Firma Ekle' : 'Firma Düzenle'),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _field(_name, 'Firma ünvanı *', isRequired: true, wide: true),
                _field(_shortName, 'Kısa ad'),
                _field(_tagline, 'Faaliyet / slogan'),
                _field(_phone, 'Telefon'),
                _field(_email, 'E-posta'),
                _field(_website, 'Web sitesi'),
                _field(_address, 'Adres', wide: true, maxLines: 2),
                _field(_taxOffice, 'Vergi dairesi'),
                _field(_taxNumber, 'Vergi numarası'),
                _field(_mersis, 'MERSİS'),
                _field(_vatRate, 'KDV (%)'),
                _field(_bankName, 'Banka adı'),
                _field(_bankBranch, 'Şube'),
                _field(_bankAccountName, 'Hesap ünvanı'),
                _field(_bankIban, 'IBAN', wide: true),
                _field(_bankSwift, 'SWIFT'),
                SizedBox(
                  width: 360,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isDefault,
                    onChanged: (value) =>
                        setState(() => _isDefault = value ?? false),
                    title: const Text('Varsayılan firma'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Kaydet'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool isRequired = false,
    bool wide = false,
    int maxLines = 1,
  }) {
    return SizedBox(
      width: wide ? 732 : 360,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: isRequired
            ? (value) =>
                  value == null || value.trim().isEmpty ? 'Zorunlu alan' : null
            : null,
      ),
    );
  }
}

class _PanelTable extends StatelessWidget {
  const _PanelTable({
    required this.header,
    required this.children,
    this.toolbar,
  });

  final Widget header;
  final List<Widget> children;
  final Widget? toolbar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (toolbar != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: toolbar,
              ),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              color: const Color(0xFFF6F8FA),
              child: header,
            ),
            Expanded(
              child: children.isEmpty
                  ? const Center(child: Text('Kayıt bulunmuyor.'))
                  : ListView.separated(
                      itemCount: children.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: children[index],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Th extends StatelessWidget {
  const _Th(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF5B6F7F),
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text, {this.strong = false});
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.isEmpty ? '-' : text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: strong ? const Color(0xFF17304C) : const Color(0xFF5B6F7F),
        fontSize: 12.5,
        fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
      ),
    );
  }
}
