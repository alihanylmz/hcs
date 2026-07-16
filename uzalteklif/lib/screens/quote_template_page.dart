import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/company_profile.dart';
import '../models/user_quote_profile.dart';
import '../services/user_profile_repository.dart';
import '../widgets/workspace_background.dart';

/// Firma / vergi / banka / varsayilan teklif metinleri — PDF sablonu ayarlari.
class QuoteTemplatePage extends StatefulWidget {
  const QuoteTemplatePage({super.key, required this.repository});

  final UserProfileRepository repository;

  @override
  State<QuoteTemplatePage> createState() => _QuoteTemplatePageState();
}

class _QuoteTemplatePageState extends State<QuoteTemplatePage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  late final TextEditingController _coName;
  late final TextEditingController _coTag;
  late final TextEditingController _coPhone;
  late final TextEditingController _coEmail;
  late final TextEditingController _coWeb;
  late final TextEditingController _coAddr;
  late final TextEditingController _taxOffice;
  late final TextEditingController _taxNo;
  late final TextEditingController _mersis;
  late final TextEditingController _bankName;
  late final TextEditingController _bankBranch;
  late final TextEditingController _bankAcc;
  late final TextEditingController _iban;
  late final TextEditingController _swift;
  late final TextEditingController _defValidity;
  late final TextEditingController _defPay;
  late final TextEditingController _defDeliv;
  late final TextEditingController _vat;

  @override
  void initState() {
    super.initState();
    _coName = TextEditingController();
    _coTag = TextEditingController();
    _coPhone = TextEditingController();
    _coEmail = TextEditingController();
    _coWeb = TextEditingController();
    _coAddr = TextEditingController();
    _taxOffice = TextEditingController();
    _taxNo = TextEditingController();
    _mersis = TextEditingController();
    _bankName = TextEditingController();
    _bankBranch = TextEditingController();
    _bankAcc = TextEditingController();
    _iban = TextEditingController();
    _swift = TextEditingController();
    _defValidity = TextEditingController();
    _defPay = TextEditingController();
    _defDeliv = TextEditingController();
    _vat = TextEditingController(text: '${CompanyProfile.defaultVatRate}');

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final row = await widget.repository.fetchMine();
    if (!mounted) return;

    void setOr(String Function(UserQuoteProfile) g, TextEditingController c, String fallback) {
      final v = row != null ? g(row).trim() : '';
      c.text = v.isNotEmpty ? v : fallback;
    }

    setOr((p) => p.companyName, _coName, CompanyProfile.name);
    setOr((p) => p.companyTagline, _coTag, CompanyProfile.tagline);
    setOr((p) => p.companyPhone, _coPhone, CompanyProfile.phone);
    setOr((p) => p.companyEmail, _coEmail, CompanyProfile.email);
    setOr((p) => p.companyWebsite, _coWeb, CompanyProfile.website);
    setOr((p) => p.companyAddress, _coAddr, CompanyProfile.address);
    setOr((p) => p.companyTaxOffice, _taxOffice, CompanyProfile.taxOffice);
    setOr((p) => p.companyTaxNumber, _taxNo, CompanyProfile.taxNumber);
    setOr((p) => p.companyMersis, _mersis, CompanyProfile.mersis);
    setOr((p) => p.bankName, _bankName, CompanyProfile.bankName);
    setOr((p) => p.bankBranch, _bankBranch, CompanyProfile.bankBranch);
    setOr((p) => p.bankAccountName, _bankAcc, CompanyProfile.bankAccountName);
    setOr((p) => p.bankIban, _iban, CompanyProfile.bankIban);
    setOr((p) => p.bankSwift, _swift, CompanyProfile.bankSwift);
    setOr((p) => p.defaultValidityText, _defValidity, '15 gun');
    setOr((p) => p.defaultPaymentTerms, _defPay, 'Pesin veya mutabakata gore vade');
    setOr((p) => p.defaultDeliveryTerms, _defDeliv, 'Termin teyidi ile');
    _vat.text = row != null && row.defaultVatRate > 0
        ? row.defaultVatRate.toStringAsFixed(0)
        : CompanyProfile.defaultVatRate.toStringAsFixed(0);

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _coName.dispose();
    _coTag.dispose();
    _coPhone.dispose();
    _coEmail.dispose();
    _coWeb.dispose();
    _coAddr.dispose();
    _taxOffice.dispose();
    _taxNo.dispose();
    _mersis.dispose();
    _bankName.dispose();
    _bankBranch.dispose();
    _bankAcc.dispose();
    _iban.dispose();
    _swift.dispose();
    _defValidity.dispose();
    _defPay.dispose();
    _defDeliv.dispose();
    _vat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || !widget.repository.isRemoteReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sablon kaydi icin oturum ve Supabase gerekli.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = await widget.repository.fetchMine();
      final vat = double.tryParse(_vat.text.trim().replaceAll(',', '.')) ?? 20;
      final profile = UserQuoteProfile(
        userId: uid,
        role: existing?.role ?? 'seller',
        preparedByName: existing?.preparedByName ?? '',
        preparedByTitle: existing?.preparedByTitle ?? '',
        preparedByPhone: existing?.preparedByPhone ?? '',
        preparedByEmail: existing?.preparedByEmail ?? '',
        companyName: _coName.text.trim(),
        companyTagline: _coTag.text.trim(),
        companyPhone: _coPhone.text.trim(),
        companyEmail: _coEmail.text.trim(),
        companyWebsite: _coWeb.text.trim(),
        companyAddress: _coAddr.text.trim(),
        companyTaxOffice: _taxOffice.text.trim(),
        companyTaxNumber: _taxNo.text.trim(),
        companyMersis: _mersis.text.trim(),
        bankName: _bankName.text.trim(),
        bankBranch: _bankBranch.text.trim(),
        bankAccountName: _bankAcc.text.trim(),
        bankIban: _iban.text.trim(),
        bankSwift: _swift.text.trim(),
        defaultValidityText: _defValidity.text.trim(),
        defaultPaymentTerms: _defPay.text.trim(),
        defaultDeliveryTerms: _defDeliv.text.trim(),
        defaultVatRate: vat.clamp(0, 100),
      );
      await widget.repository.upsert(profile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teklif sablonu kaydedildi.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydedilemedi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController c, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teklif sablonu'),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
        ],
      ),
      body: WorkspaceBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!widget.repository.isRemoteReady)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Oturum yok veya Supabase kapali; kayit yapilamaz.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        Text(
                          'Firma (PDF ust bilgi)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _field('Firma unvani', _coName),
                        _field('Slogan', _coTag),
                        _field('Firma telefon', _coPhone),
                        _field('Firma e-posta', _coEmail),
                        _field('Web sitesi', _coWeb),
                        _field('Adres', _coAddr, maxLines: 2),
                        const SizedBox(height: 16),
                        Text(
                          'Vergi',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        _field('Vergi dairesi', _taxOffice),
                        _field('Vergi no', _taxNo),
                        _field('MERSIS', _mersis),
                        const SizedBox(height: 16),
                        Text(
                          'Banka',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        _field('Banka adi', _bankName),
                        _field('Sube', _bankBranch),
                        _field('Hesap unvani', _bankAcc),
                        _field('IBAN', _iban),
                        _field('SWIFT', _swift),
                        const SizedBox(height: 16),
                        Text(
                          'Yeni teklif varsayilanlari',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        _field('Gecerlilik metni', _defValidity),
                        _field('Odeme kosulu', _defPay, maxLines: 3),
                        _field('Teslim kosulu', _defDeliv),
                        _field('KDV (%)', _vat),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
