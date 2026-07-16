import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/company_profile.dart';
import '../models/user_quote_profile.dart';
import '../services/theme_preference_service.dart';
import '../services/user_profile_repository.dart';
import '../widgets/workspace_background.dart';

/// Kisisel hazirlayan bilgileri. Firma / sablon ayarlari [QuoteTemplatePage]'de.
class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({
    super.key,
    required this.repository,
    required this.themePreferenceService,
  });

  final UserProfileRepository repository;
  final ThemePreferenceService themePreferenceService;

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;

  late final TextEditingController _prepName;
  late final TextEditingController _prepTitle;
  late final TextEditingController _prepPhone;
  late final TextEditingController _prepEmail;

  String _roleLabel = 'Satış';

  @override
  void initState() {
    super.initState();
    _prepName = TextEditingController();
    _prepTitle = TextEditingController();
    _prepPhone = TextEditingController();
    _prepEmail = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final authMail =
        Supabase.instance.client.auth.currentUser?.email?.trim() ?? '';
    final row = await widget.repository.fetchMine();
    if (!mounted) return;

    void setOr(
      String Function(UserQuoteProfile) g,
      TextEditingController c,
      String fallback,
    ) {
      final v = row != null ? g(row).trim() : '';
      c.text = v.isNotEmpty ? v : fallback;
    }

    setOr((p) => p.preparedByName, _prepName, '');
    setOr((p) => p.preparedByTitle, _prepTitle, '');
    setOr((p) => p.preparedByPhone, _prepPhone, CompanyProfile.phone);
    setOr(
      (p) => p.preparedByEmail,
      _prepEmail,
      authMail.isNotEmpty ? authMail : CompanyProfile.email,
    );

    _roleLabel = UserQuoteProfile.roleLabel(row?.role ?? 'sales');

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _prepName.dispose();
    _prepTitle.dispose();
    _prepPhone.dispose();
    _prepEmail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null || !widget.repository.isRemoteReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil kaydi icin oturum ve Supabase gerekli.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final existing = await widget.repository.fetchMine();
      final vat = existing?.defaultVatRate ?? CompanyProfile.defaultVatRate;
      final profile = UserQuoteProfile(
        userId: uid,
        role: existing?.role ?? 'sales',
        preparedByName: _prepName.text.trim(),
        preparedByTitle: _prepTitle.text.trim(),
        preparedByPhone: _prepPhone.text.trim(),
        preparedByEmail: _prepEmail.text.trim(),
        companyName: existing?.companyName ?? '',
        companyTagline: existing?.companyTagline ?? '',
        companyPhone: existing?.companyPhone ?? '',
        companyEmail: existing?.companyEmail ?? '',
        companyWebsite: existing?.companyWebsite ?? '',
        companyAddress: existing?.companyAddress ?? '',
        companyTaxOffice: existing?.companyTaxOffice ?? '',
        companyTaxNumber: existing?.companyTaxNumber ?? '',
        companyMersis: existing?.companyMersis ?? '',
        bankName: existing?.bankName ?? '',
        bankBranch: existing?.bankBranch ?? '',
        bankAccountName: existing?.bankAccountName ?? '',
        bankIban: existing?.bankIban ?? '',
        bankSwift: existing?.bankSwift ?? '',
        defaultValidityText: existing?.defaultValidityText ?? '',
        defaultPaymentTerms: existing?.defaultPaymentTerms ?? '',
        defaultDeliveryTerms: existing?.defaultDeliveryTerms ?? '',
        defaultVatRate: vat,
      );
      await widget.repository.upsert(profile);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil kaydedildi.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
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
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hesap turu',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _roleLabel,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Rol değişiklikleri Yönetim Paneli veya Supabase SQL üzerinden yapılır.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: const Color(0xFF5B6F7F),
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Uygulama ayarlari',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 12),
                                SegmentedButton<ThemeMode>(
                                  segments: const [
                                    ButtonSegment(
                                      value: ThemeMode.system,
                                      icon: Icon(Icons.brightness_auto_rounded),
                                      label: Text('Sistem'),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.light,
                                      icon: Icon(Icons.light_mode_rounded),
                                      label: Text('Aydinlik'),
                                    ),
                                    ButtonSegment(
                                      value: ThemeMode.dark,
                                      icon: Icon(Icons.dark_mode_rounded),
                                      label: Text('Karanlik'),
                                    ),
                                  ],
                                  selected: {
                                    widget.themePreferenceService.mode,
                                  },
                                  onSelectionChanged: (values) {
                                    final mode = values.first;
                                    widget.themePreferenceService.setMode(mode);
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Teklifte gorunen hazirlayan',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        _field('Ad Soyad', _prepName),
                        _field('Unvan', _prepTitle),
                        _field('Telefon', _prepPhone),
                        _field('E-posta', _prepEmail),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
