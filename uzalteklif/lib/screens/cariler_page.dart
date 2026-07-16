import 'package:flutter/material.dart';

import '../models/cari_account.dart';
import '../services/cari_repository.dart';
import '../services/market_rate_service.dart';
import '../services/own_company_repository.dart';
import '../services/price_adjustment_rule_repository.dart';
import '../services/product_repository.dart';
import '../services/quote_repository.dart';
import '../services/user_profile_repository.dart';
import '../widgets/workspace_background.dart';
import 'cari_detail_page.dart';

/// Cari kartlari: ana menude detay + son teklifler; editorde yalnizca hizli duzenleme.
class CarilerPage extends StatefulWidget {
  const CarilerPage({
    super.key,
    required this.repository,
    this.quoteRepository,
    this.productRepository,
    this.marketRateService,
    this.ownCompanyRepository,
    this.priceAdjustmentRuleRepository,
    this.userProfileRepository,
    this.isManager = false,
  });

  final CariRepository repository;
  final QuoteRepository? quoteRepository;
  final ProductRepository? productRepository;
  final MarketRateService? marketRateService;
  final OwnCompanyRepository? ownCompanyRepository;
  final PriceAdjustmentRuleRepository? priceAdjustmentRuleRepository;
  final UserProfileRepository? userProfileRepository;
  final bool isManager;

  @override
  State<CarilerPage> createState() => _CarilerPageState();
}

class _CarilerPageState extends State<CarilerPage> {
  List<CariAccount> _list = const [];
  bool _loading = true;
  String _query = '';
  String _sort = 'company';
  bool _showContact = true;
  bool _showPhone = true;
  bool _showEmail = true;
  bool _showTax = true;

  List<CariAccount> get _filteredList {
    final query = _query.trim().toLowerCase();
    final list = _list
        .where((cari) {
          if (query.isEmpty) return true;
          return [
            cari.companyName,
            cari.contactName,
            cari.contactTitle,
            cari.phone,
            cari.email,
            cari.taxOffice,
            cari.taxNumber,
            cari.address,
          ].join(' ').toLowerCase().contains(query);
        })
        .toList(growable: false);
    list.sort((a, b) {
      switch (_sort) {
        case 'contact':
          return a.contactName.compareTo(b.contactName);
        case 'updated_desc':
          return b.updatedAt.compareTo(a.updatedAt);
        default:
          return a.companyName.compareTo(b.companyName);
      }
    });
    return list;
  }

  bool get _canOpenDetail =>
      widget.quoteRepository != null &&
      widget.productRepository != null &&
      widget.marketRateService != null &&
      widget.ownCompanyRepository != null &&
      widget.priceAdjustmentRuleRepository != null &&
      widget.userProfileRepository != null;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final rows = await widget.repository.fetchAll();
    if (!mounted) return;
    setState(() {
      _list = rows;
      _loading = false;
    });
  }

  Future<void> _edit(CariAccount? existing) async {
    final cari = await showDialog<CariAccount>(
      context: context,
      builder: (ctx) => _CariFormDialog(existing: existing),
    );
    if (cari == null || !mounted) return;

    try {
      await widget.repository.save(cari);
      if (!mounted) return;
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cari kaydedilemedi: $error')));
    }
  }

  Future<void> _openDetail(CariAccount c) async {
    if (!_canOpenDetail) {
      await _edit(c);
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CariDetailPage(
          cari: c,
          quoteRepository: widget.quoteRepository!,
          productRepository: widget.productRepository!,
          marketRateService: widget.marketRateService!,
          userProfileRepository: widget.userProfileRepository!,
          cariRepository: widget.repository,
          ownCompanyRepository: widget.ownCompanyRepository!,
          priceAdjustmentRuleRepository: widget.priceAdjustmentRuleRepository!,
          isManager: widget.isManager,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _confirmDelete(CariAccount c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cari silinsin mi?'),
        content: Text(c.menuLabel),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgec'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF9D3418),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.repository.deleteById(c.id);
      if (mounted) await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cari silinemedi: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Kartları'),
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
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : !widget.repository.isRemoteReady
              ? const Center(
                  child: Text('Cariler icin oturum ve Supabase gerekli.'),
                )
              : Column(
                  children: [
                    _buildControlBar(),
                    Expanded(child: _buildCariWorkspace()),
                  ],
                ),
        ),
      ),
      floatingActionButton: widget.repository.isRemoteReady
          ? FloatingActionButton.extended(
              onPressed: () => _edit(null),
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Cari ekle'),
            )
          : null,
    );
  }

  Widget _buildControlBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search_rounded),
                    labelText: 'Firma, yetkili, vergi ara',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  initialValue: _sort,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Sıralama',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'company',
                      child: Text('Firma adı'),
                    ),
                    DropdownMenuItem(value: 'contact', child: Text('Yetkili')),
                    DropdownMenuItem(
                      value: 'updated_desc',
                      child: Text('Son güncel'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _sort = value ?? 'company'),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Kolonlar',
                icon: const Icon(Icons.view_column_rounded),
                itemBuilder: (context) => [
                  _columnMenuItem('contact', 'Yetkili', _showContact),
                  _columnMenuItem('phone', 'Telefon', _showPhone),
                  _columnMenuItem('email', 'E-posta', _showEmail),
                  _columnMenuItem('tax', 'Vergi', _showTax),
                ],
                onSelected: (value) {
                  setState(() {
                    if (value == 'contact') _showContact = !_showContact;
                    if (value == 'phone') _showPhone = !_showPhone;
                    if (value == 'email') _showEmail = !_showEmail;
                    if (value == 'tax') _showTax = !_showTax;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _columnMenuItem(
    String value,
    String label,
    bool shown,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            shown
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildCariWorkspace() {
    final table = _CariTable(
      cariler: _filteredList,
      onOpen: _openDetail,
      onEdit: _edit,
      onDelete: _confirmDelete,
      showContact: _showContact,
      showPhone: _showPhone,
      showEmail: _showEmail,
      showTax: _showTax,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1080) return table;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: table),
            SizedBox(
              width: 300,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                child: _CariSidePanel(cariler: _filteredList),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CariSidePanel extends StatelessWidget {
  const _CariSidePanel({required this.cariler});

  final List<CariAccount> cariler;

  @override
  Widget build(BuildContext context) {
    final withContact = cariler
        .where((c) => c.contactName.trim().isNotEmpty)
        .length;
    final withTax = cariler
        .where(
          (c) => c.taxOffice.trim().isNotEmpty || c.taxNumber.trim().isNotEmpty,
        )
        .length;
    final withEmail = cariler.where((c) => c.email.trim().isNotEmpty).length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cari Özeti',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: const Color(0xFF17304C),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _CariMetric(label: 'Listelenen', value: '${cariler.length}'),
            _CariMetric(label: 'Yetkili tanımlı', value: '$withContact'),
            _CariMetric(label: 'E-posta tanımlı', value: '$withEmail'),
            _CariMetric(label: 'Vergi bilgisi', value: '$withTax'),
            const Spacer(),
            Text(
              'Cari kartı; firma, yetkili, vergi ve adres bilgilerinin tekliflere düzenli aktarılması için ana kayıttır.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF5B6F7F),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CariMetric extends StatelessWidget {
  const _CariMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF5B6F7F),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF17304C),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CariFormDialog extends StatefulWidget {
  const _CariFormDialog({this.existing});

  final CariAccount? existing;

  @override
  State<_CariFormDialog> createState() => _CariFormDialogState();
}

class _CariFormDialogState extends State<_CariFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _company;
  late final TextEditingController _contact;
  late final TextEditingController _title;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _taxOffice;
  late final TextEditingController _taxNumber;
  late final TextEditingController _address;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _company = TextEditingController(text: existing?.companyName ?? '');
    _contact = TextEditingController(text: existing?.contactName ?? '');
    _title = TextEditingController(text: existing?.contactTitle ?? '');
    _phone = TextEditingController(text: existing?.phone ?? '');
    _email = TextEditingController(text: existing?.email ?? '');
    _taxOffice = TextEditingController(text: existing?.taxOffice ?? '');
    _taxNumber = TextEditingController(text: existing?.taxNumber ?? '');
    _address = TextEditingController(text: existing?.address ?? '');
    _notes = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _company.dispose();
    _contact.dispose();
    _title.dispose();
    _phone.dispose();
    _email.dispose();
    _taxOffice.dispose();
    _taxNumber.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.existing;
    Navigator.of(context).pop(
      CariAccount(
        id: existing?.id ?? 'cari-${DateTime.now().microsecondsSinceEpoch}',
        companyName: _company.text.trim(),
        contactName: _contact.text.trim(),
        contactTitle: _title.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        taxOffice: _taxOffice.text.trim(),
        taxNumber: _taxNumber.text.trim(),
        address: _address.text.trim(),
        notes: _notes.text.trim(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Yeni Cari Kartı' : 'Cari Kartını Düzenle',
      ),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _field(_company, 'Firma adı *', isRequired: true),
                _field(_contact, 'Yetkili ad soyad'),
                _field(_title, 'Yetkili unvan'),
                _field(_phone, 'Telefon'),
                _field(_email, 'E-posta'),
                _field(_taxOffice, 'Vergi dairesi'),
                _field(_taxNumber, 'Vergi numarası'),
                _field(_address, 'Adres', maxLines: 2, wide: true),
                _field(_notes, 'Not', maxLines: 2, wide: true),
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
      width: wide ? 704 : 346,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: isRequired
            ? (value) => value == null || value.trim().isEmpty
                  ? 'Bu alan zorunlu'
                  : null
            : null,
      ),
    );
  }
}

class _CariTable extends StatelessWidget {
  const _CariTable({
    required this.cariler,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.showContact,
    required this.showPhone,
    required this.showEmail,
    required this.showTax,
  });

  final List<CariAccount> cariler;
  final ValueChanged<CariAccount> onOpen;
  final ValueChanged<CariAccount> onEdit;
  final ValueChanged<CariAccount> onDelete;
  final bool showContact;
  final bool showPhone;
  final bool showEmail;
  final bool showTax;

  @override
  Widget build(BuildContext context) {
    if (cariler.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Kayitli cari bulunmuyor.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: const Color(0xFF5B6F7F),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              color: const Color(0xFFF6F8FA),
              child: Row(
                children: [
                  const Expanded(flex: 3, child: _CariHeader('Firma')),
                  if (showContact)
                    const Expanded(flex: 2, child: _CariHeader('Yetkili')),
                  if (showPhone)
                    const SizedBox(width: 150, child: _CariHeader('Telefon')),
                  if (showEmail)
                    const Expanded(flex: 2, child: _CariHeader('E-posta')),
                  if (showTax)
                    const Expanded(flex: 2, child: _CariHeader('Vergi')),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: cariler.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final cari = cariler[index];
                  return _CariTableRow(
                    cari: cari,
                    onOpen: () => onOpen(cari),
                    onEdit: () => onEdit(cari),
                    onDelete: () => onDelete(cari),
                    showContact: showContact,
                    showPhone: showPhone,
                    showEmail: showEmail,
                    showTax: showTax,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CariTableRow extends StatelessWidget {
  const _CariTableRow({
    required this.cari,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.showContact,
    required this.showPhone,
    required this.showEmail,
    required this.showTax,
  });

  final CariAccount cari;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showContact;
  final bool showPhone;
  final bool showEmail;
  final bool showTax;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17304C);
    const slate = Color(0xFF5B6F7F);
    final tax = [
      if (cari.taxOffice.trim().isNotEmpty) cari.taxOffice.trim(),
      if (cari.taxNumber.trim().isNotEmpty) cari.taxNumber.trim(),
    ].join(' / ');

    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cari.companyName.trim().isEmpty
                          ? '(Firma yok)'
                          : cari.companyName.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    if (cari.address.trim().isNotEmpty)
                      Text(
                        cari.address.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: slate,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
              ),
              if (showContact)
                Expanded(
                  flex: 2,
                  child: Text(
                    [
                      if (cari.contactName.trim().isNotEmpty)
                        cari.contactName.trim(),
                      if (cari.contactTitle.trim().isNotEmpty)
                        cari.contactTitle.trim(),
                    ].join(' - '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              if (showPhone)
                SizedBox(
                  width: 150,
                  child: Text(
                    cari.phone.trim().isEmpty ? '-' : cari.phone.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: slate,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              if (showEmail)
                Expanded(
                  flex: 2,
                  child: Text(
                    cari.email.trim().isEmpty ? '-' : cari.email.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: slate,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              if (showTax)
                Expanded(
                  flex: 2,
                  child: Text(
                    tax.isEmpty ? '-' : tax,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: slate,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              SizedBox(
                width: 48,
                child: PopupMenuButton<String>(
                  tooltip: 'Islemler',
                  onSelected: (v) {
                    if (v == 'open') onOpen();
                    if (v == 'edit') onEdit();
                    if (v == 'del') onDelete();
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'open', child: Text('Detay')),
                    PopupMenuItem(value: 'edit', child: Text('Duzenle')),
                    PopupMenuItem(value: 'del', child: Text('Sil')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CariHeader extends StatelessWidget {
  const _CariHeader(this.text);

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
