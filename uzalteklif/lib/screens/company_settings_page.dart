import 'package:flutter/material.dart';

import '../models/own_company.dart';
import '../services/own_company_repository.dart';
import '../widgets/workspace_background.dart';

class CompanySettingsPage extends StatefulWidget {
  const CompanySettingsPage({super.key, required this.repository});

  final OwnCompanyRepository repository;

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{
    for (final key in const [
      'name',
      'shortName',
      'tagline',
      'phone',
      'email',
      'website',
      'address',
      'taxOffice',
      'taxNumber',
      'mersis',
      'bankName',
      'bankBranch',
      'bankAccountName',
      'bankIban',
      'bankSwift',
      'vatRate',
    ])
      key: TextEditingController(),
  };

  List<OwnCompany> _companies = const [];
  OwnCompany? _selected;
  bool _loading = true;
  bool _saving = false;

  TextEditingController _controller(String key) => _controllers[key]!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final companies = await widget.repository.fetchAll();
      if (!mounted) return;
      final selected = companies.where((company) => company.isDefault);
      _companies = companies;
      _selectCompany(
        selected.isNotEmpty
            ? selected.first
            : (companies.isNotEmpty ? companies.first : OwnCompany.fallback()),
        notify: false,
      );
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firma bilgileri alınamadı: $error')),
      );
    }
  }

  void _selectCompany(OwnCompany company, {bool notify = true}) {
    _selected = company;
    _controller('name').text = company.name;
    _controller('shortName').text = company.shortName;
    _controller('tagline').text = company.tagline;
    _controller('phone').text = company.phone;
    _controller('email').text = company.email;
    _controller('website').text = company.website;
    _controller('address').text = company.address;
    _controller('taxOffice').text = company.taxOffice;
    _controller('taxNumber').text = company.taxNumber;
    _controller('mersis').text = company.mersis;
    _controller('bankName').text = company.bankName;
    _controller('bankBranch').text = company.bankBranch;
    _controller('bankAccountName').text = company.bankAccountName;
    _controller('bankIban').text = company.bankIban;
    _controller('bankSwift').text = company.bankSwift;
    _controller('vatRate').text = company.defaultVatRate.toStringAsFixed(0);
    if (notify && mounted) setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final source = _selected ?? OwnCompany.fallback();
    setState(() => _saving = true);
    try {
      final company = OwnCompany(
        id: source.id,
        name: _controller('name').text.trim(),
        shortName: _controller('shortName').text.trim(),
        tagline: _controller('tagline').text.trim(),
        phone: _controller('phone').text.trim(),
        email: _controller('email').text.trim(),
        website: _controller('website').text.trim(),
        address: _controller('address').text.trim(),
        taxOffice: _controller('taxOffice').text.trim(),
        taxNumber: _controller('taxNumber').text.trim(),
        mersis: _controller('mersis').text.trim(),
        bankName: _controller('bankName').text.trim(),
        bankBranch: _controller('bankBranch').text.trim(),
        bankAccountName: _controller('bankAccountName').text.trim(),
        bankIban: _controller('bankIban').text.trim(),
        bankSwift: _controller('bankSwift').text.trim(),
        defaultVatRate:
            double.tryParse(
              _controller('vatRate').text.trim().replaceAll(',', '.'),
            ) ??
            20,
        isDefault: source.isDefault || _companies.length == 1,
        updatedAt: DateTime.now().toUtc(),
      );
      await widget.repository.save(company);
      if (!mounted) return;
      _selected = company;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Firma bilgileri kaydedildi. Yeni teklifler PDF’ye bu bilgilerle yansıyacak.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kaydedilemedi: $error')));
    }
  }

  Widget _field(
    String key,
    String label, {
    bool required = false,
    bool wide = false,
    int maxLines = 1,
  }) {
    final availableWidth = (MediaQuery.sizeOf(context).width - 80)
        .clamp(240.0, 732.0)
        .toDouble();
    return SizedBox(
      width: wide
          ? availableWidth
          : availableWidth.clamp(240.0, 360.0).toDouble(),
      child: TextFormField(
        controller: _controller(key),
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) =>
                  value == null || value.trim().isEmpty ? 'Zorunlu alan' : null
            : null,
      ),
    );
  }

  Widget _section({
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 3),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: children),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Firma Bilgileri'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _loading || _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('Kaydet'),
            ),
          ),
        ],
      ),
      body: WorkspaceBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
                  children: [
                    if (_companies.length > 1) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _selected?.id,
                        decoration: const InputDecoration(
                          labelText: 'Düzenlenecek firma',
                          prefixIcon: Icon(Icons.apartment_rounded),
                        ),
                        items: [
                          for (final company in _companies)
                            DropdownMenuItem(
                              value: company.id,
                              child: Text(company.menuLabel),
                            ),
                        ],
                        onChanged: (id) {
                          if (id == null) return;
                          _selectCompany(
                            _companies.firstWhere(
                              (company) => company.id == id,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    _section(
                      title: 'PDF Üst Bilgisi',
                      description:
                          'Teklif PDF’sinin en üstünde görünecek kurumsal bilgiler.',
                      children: [
                        _field('name', 'Firma ünvanı *', required: true),
                        _field('shortName', 'Kısa ad'),
                        _field('tagline', 'Faaliyet / slogan'),
                        _field('phone', 'Telefon'),
                        _field('email', 'E-posta'),
                        _field('website', 'Web sitesi'),
                        _field('address', 'Adres', wide: true, maxLines: 2),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _section(
                      title: 'Vergi Bilgileri',
                      description:
                          'Teklif ve ticari belgelerde kullanılacak resmi bilgiler.',
                      children: [
                        _field('taxOffice', 'Vergi dairesi'),
                        _field('taxNumber', 'Vergi numarası'),
                        _field('mersis', 'MERSİS'),
                        _field('vatRate', 'Varsayılan KDV (%)'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _section(
                      title: 'Banka Bilgileri',
                      description:
                          'PDF ödeme ve banka bölümünde gösterilecek hesap bilgileri.',
                      children: [
                        _field('bankName', 'Banka adı'),
                        _field('bankBranch', 'Şube'),
                        _field('bankAccountName', 'Hesap ünvanı'),
                        _field('bankIban', 'IBAN', wide: true),
                        _field('bankSwift', 'SWIFT'),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
