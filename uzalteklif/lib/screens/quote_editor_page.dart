import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/company_profile.dart';
import '../models/cari_account.dart';
import '../models/market_rate.dart';
import '../models/own_company.dart';
import '../models/product.dart';
import '../models/quote.dart';
import '../models/user_quote_profile.dart';
import '../services/cari_repository.dart';
import '../services/excel_export_service.dart';
import '../services/pdf_export_service.dart';
import '../services/own_company_repository.dart';
import '../services/price_adjustment_rule_repository.dart';
import '../services/quote_code_generator.dart';
import '../services/quote_repository.dart';
import '../services/user_profile_repository.dart';
import '../widgets/workspace_background.dart';
import 'cariler_page.dart';

class QuoteEditorPage extends StatefulWidget {
  QuoteEditorPage({
    super.key,
    required this.quoteRepository,
    required this.initialRates,
    required this.availableProducts,
    this.quoteToRevise,
    UserProfileRepository? userProfileRepository,
    CariRepository? cariRepository,
    OwnCompanyRepository? ownCompanyRepository,
    PriceAdjustmentRuleRepository? priceAdjustmentRuleRepository,
  }) : userProfileRepository = userProfileRepository ?? UserProfileRepository(),
       cariRepository = cariRepository ?? CariRepository(),
       ownCompanyRepository =
           ownCompanyRepository ?? const OwnCompanyRepository(),
       priceAdjustmentRuleRepository =
           priceAdjustmentRuleRepository ??
           const PriceAdjustmentRuleRepository();

  final QuoteRepository quoteRepository;
  final List<MarketRate> initialRates;
  final List<Product> availableProducts;

  /// Ayni teklifin revizyonu; kod tabani korunur, Rev numarasi artar.
  final Quote? quoteToRevise;

  final UserProfileRepository userProfileRepository;
  final CariRepository cariRepository;
  final OwnCompanyRepository ownCompanyRepository;
  final PriceAdjustmentRuleRepository priceAdjustmentRuleRepository;

  @override
  State<QuoteEditorPage> createState() => _QuoteEditorPageState();
}

class _QuoteEditorPageState extends State<QuoteEditorPage> {
  static const String _liveBuildMarker = 'quote-price-repair-20260710-f401';
  static const String _lineCurrencyFixMarker =
      'quote-line-currency-fix-20260710';

  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerCompanyController = TextEditingController();
  final _customerTitleController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  final _preparedByNameController = TextEditingController();
  final _preparedByTitleController = TextEditingController();
  final _preparedByPhoneController = TextEditingController();
  final _preparedByEmailController = TextEditingController();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController(
    text:
        'Teslim suresi ve odeme kosullari teklif onayi sonrasinda netlestirilir.',
  );
  final _validityController = TextEditingController(text: '15 gun');
  final _paymentTermsController = TextEditingController(
    text: 'Pesin veya mutabakata gore vade',
  );
  final _paymentTermDaysController = TextEditingController(text: '30');
  final _deliveryTermsController = TextEditingController(
    text: 'Termin teyidi ile',
  );
  final _productSearchController = TextEditingController();
  final _uncategorizedBulkDiscountController = TextEditingController(text: '0');
  final _money = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: 'TL ',
    decimalDigits: 2,
  );
  final _pdfExportService = const PdfExportService();
  final _excelExportService = const ExcelExportService();
  final List<_LineDraft> _items = [];
  final List<_SectionDraft> _sections = [];
  final List<_HiddenCostDraft> _hiddenCosts = [];
  String? _activeSectionId;
  bool _uncategorizedBulkDiscountEnabled = false;

  late final List<MarketRate> _rates = widget.initialRates;
  late final DateTime _draftTimestamp;

  String _selectedDisplayUnit = 'EURTRY';
  String _productCategoryFilter = 'Tum Kategoriler';
  bool _isSubmitting = false;
  bool _infoCollapsed = false;
  QuotePaymentMethod _paymentMethod = QuotePaymentMethod.cash;
  bool _hidePrices = false;
  String? _draftQuoteId;
  String? _draftQuoteCode;
  String? _draftShareToken;
  bool _legacyPriceRepairApplied = false;
  int _codeRefreshToken = 0;
  int _idSequence = 0;

  UserQuoteProfile? _issuerProfile;
  List<OwnCompany> _ownCompanies = [OwnCompany.fallback()];
  String _selectedOwnCompanyId = 'default-company';
  List<CariAccount> _cariler = const [];
  String _selectedCariId = '';

  @override
  void initState() {
    super.initState();
    debugPrint(_liveBuildMarker);
    debugPrint(_lineCurrencyFixMarker);
    final source = widget.quoteToRevise;
    _draftTimestamp = source?.createdAt ?? DateTime.now();
    _preparedByNameController.text = 'Alihan Uzal';
    _preparedByTitleController.text = 'Satis Muhendisi';
    _preparedByPhoneController.text = CompanyProfile.phone;
    _preparedByEmailController.text = CompanyProfile.email;

    if (source != null) {
      final repairedSource = _repairLikelyDoubleConvertedQuote(source);
      _loadFromExistingQuote(repairedSource);
      _repairLoadedDraftsAgainstSource(source);
    }

    if (!_displayUnits.any((u) => u.code == _selectedDisplayUnit)) {
      _selectedDisplayUnit = 'TL';
    }

    _refreshDraftQuoteCode();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _bootstrapEditorContext(),
    );
  }

  Future<void> _bootstrapEditorContext() async {
    final cariler = await widget.cariRepository.fetchAll();
    final companies = await widget.ownCompanyRepository.fetchAll();
    final prof = await widget.userProfileRepository.fetchMine();
    if (!mounted) return;
    setState(() {
      _cariler = cariler;
      _ownCompanies = companies.isEmpty ? [OwnCompany.fallback()] : companies;
      _selectedOwnCompanyId = _resolveOwnCompanySelection(companies);
      _issuerProfile = prof;
    });
    if (widget.quoteToRevise == null && prof != null) {
      _applyIssuerDefaults(prof);
      if (mounted) setState(() {});
    }
    await _restoreReasonableRevisionIfCurrentLooksInflated();
  }

  String _resolveOwnCompanySelection(List<OwnCompany> companies) {
    final existing = widget.quoteToRevise?.documentProfile.companyName.trim();
    if (existing != null && existing.isNotEmpty) {
      final matched = companies.where((c) => c.name.trim() == existing);
      if (matched.isNotEmpty) return matched.first.id;
    }
    final defaults = companies.where((c) => c.isDefault);
    if (defaults.isNotEmpty) return defaults.first.id;
    return companies.isNotEmpty ? companies.first.id : OwnCompany.fallback().id;
  }

  OwnCompany get _selectedOwnCompany {
    return _ownCompanies.firstWhere(
      (company) => company.id == _selectedOwnCompanyId,
      orElse: () => _ownCompanies.isNotEmpty
          ? _ownCompanies.first
          : OwnCompany.fallback(),
    );
  }

  void _applyIssuerDefaults(UserQuoteProfile p) {
    void use(String raw, TextEditingController c) {
      final v = raw.trim();
      if (v.isEmpty) return;
      c.text = v;
    }

    use(p.preparedByName, _preparedByNameController);
    use(p.preparedByTitle, _preparedByTitleController);
    use(p.preparedByPhone, _preparedByPhoneController);
    use(p.preparedByEmail, _preparedByEmailController);
    use(p.defaultValidityText, _validityController);
    use(p.defaultPaymentTerms, _paymentTermsController);
    use(p.defaultDeliveryTerms, _deliveryTermsController);
  }

  // ignore: unused_element
  String _docPick(String? stored, String fallback) {
    final t = stored?.trim() ?? '';
    return t.isNotEmpty ? t : fallback;
  }

  double _docVatRate() {
    final companyVat = _selectedOwnCompany.defaultVatRate;
    if (companyVat > 0 && companyVat <= 100) return companyVat;
    final p = _issuerProfile;
    if (p != null && p.defaultVatRate > 0 && p.defaultVatRate <= 100) {
      return p.defaultVatRate;
    }
    return CompanyProfile.defaultVatRate;
  }

  String _effectiveCariDropdownValue() {
    if (_selectedCariId.isEmpty) return '';
    return _cariler.any((c) => c.id == _selectedCariId) ? _selectedCariId : '';
  }

  void _applyCariToForm(CariAccount c) {
    _customerCompanyController.text = c.companyName;
    _customerNameController.text = c.contactName;
    _customerTitleController.text = c.contactTitle;
    _customerPhoneController.text = c.phone;
    _customerEmailController.text = c.email;
  }

  Future<void> _quickCreateCari() async {
    final company = TextEditingController(
      text: _customerCompanyController.text,
    );
    final contact = TextEditingController(text: _customerNameController.text);
    final title = TextEditingController(text: _customerTitleController.text);
    final phone = TextEditingController(text: _customerPhoneController.text);
    final email = TextEditingController(text: _customerEmailController.text);
    final taxOffice = TextEditingController();
    final taxNumber = TextEditingController();
    final address = TextEditingController();
    final notes = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hizli cari ekle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: company,
                decoration: const InputDecoration(labelText: 'Firma adi *'),
              ),
              TextField(
                controller: contact,
                decoration: const InputDecoration(labelText: 'Yetkili kisi'),
              ),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Unvan'),
              ),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'E-posta'),
              ),
              TextField(
                controller: taxOffice,
                decoration: const InputDecoration(labelText: 'Vergi dairesi'),
              ),
              TextField(
                controller: taxNumber,
                decoration: const InputDecoration(labelText: 'Vergi numarasi'),
              ),
              TextField(
                controller: address,
                decoration: const InputDecoration(labelText: 'Adres'),
                maxLines: 2,
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Not'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              if (company.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Kaydet ve sec'),
          ),
        ],
      ),
    );

    if (saved != true || !mounted) {
      company.dispose();
      contact.dispose();
      title.dispose();
      phone.dispose();
      email.dispose();
      taxOffice.dispose();
      taxNumber.dispose();
      address.dispose();
      notes.dispose();
      return;
    }

    final cari = CariAccount(
      id: 'cari-${DateTime.now().microsecondsSinceEpoch}',
      companyName: company.text.trim(),
      contactName: contact.text.trim(),
      contactTitle: title.text.trim(),
      phone: phone.text.trim(),
      email: email.text.trim(),
      taxOffice: taxOffice.text.trim(),
      taxNumber: taxNumber.text.trim(),
      address: address.text.trim(),
      notes: notes.text.trim(),
      updatedAt: DateTime.now().toUtc(),
    );

    company.dispose();
    contact.dispose();
    title.dispose();
    phone.dispose();
    email.dispose();
    taxOffice.dispose();
    taxNumber.dispose();
    address.dispose();
    notes.dispose();

    try {
      await widget.cariRepository.save(cari);
      final list = await widget.cariRepository.fetchAll();
      if (!mounted) return;
      setState(() {
        _cariler = list;
        _selectedCariId = cari.id;
        _applyCariToForm(cari);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cari kaydedilemedi: $error')));
    }
  }

  /// Mevcut bir teklifi revize modunda yuklerken tum controller'lari ve
  /// state listelerini bu veriyle doldurur. Teklifin kodu/id'si korunur;
  /// `_buildQuote` ayni kayit uzerine yazar.
  void _loadFromExistingQuote(Quote source) {
    _draftQuoteId = source.id;
    _draftQuoteCode = source.code;
    _draftShareToken = source.publicToken;
    _selectedDisplayUnit = source.displayUnit;
    _paymentMethod = source.paymentMethod;
    _hidePrices = source.hidePrices;
    _paymentTermDaysController.text = source.paymentTermDays == 0
        ? '30'
        : source.paymentTermDays.toString();

    _selectedCariId = source.cariId;
    _customerNameController.text = source.customerName;
    _customerCompanyController.text = source.customerCompany;
    _titleController.text = _extractQuoteTopic(source.title, source);
    _noteController.text = source.note;

    final profile = source.documentProfile;
    _customerTitleController.text = profile.customerContactTitle;
    _customerPhoneController.text = profile.customerPhone;
    _customerEmailController.text = profile.customerEmail;
    if (profile.preparedByName.isNotEmpty) {
      _preparedByNameController.text = profile.preparedByName;
    }
    if (profile.preparedByTitle.isNotEmpty) {
      _preparedByTitleController.text = profile.preparedByTitle;
    }
    if (profile.preparedByPhone.isNotEmpty) {
      _preparedByPhoneController.text = profile.preparedByPhone;
    }
    if (profile.preparedByEmail.isNotEmpty) {
      _preparedByEmailController.text = profile.preparedByEmail;
    }
    if (profile.validityText.isNotEmpty) {
      _validityController.text = profile.validityText;
    }
    if (profile.paymentTerms.isNotEmpty) {
      _paymentTermsController.text = profile.paymentTerms;
    }
    if (profile.deliveryTerms.isNotEmpty) {
      _deliveryTermsController.text = profile.deliveryTerms;
    }

    for (final section in source.sections) {
      _sections.add(_SectionDraft(id: section.id, name: section.name));
    }

    for (final item in source.items) {
      final productId = _findProductIdFromDescription(item.description);
      _items.add(
        _LineDraft(
          productId: productId,
          priceCurrencyCode: source.displayUnit,
          description: item.description,
          unit: item.unit,
          quantity: _formatQuantityForInput(item.quantity),
          unitPriceTl: _formatUnitPriceForEditableInput(
            item.unitPriceTl,
            source.displayUnit,
            source.rateLookup,
          ),
          discount: _formatQuantityForInput(item.discountRate),
          sectionId: item.sectionId,
        ),
      );
    }

    for (final hc in source.hiddenCosts) {
      _hiddenCosts.add(
        _HiddenCostDraft(
          id: hc.id,
          name: hc.name,
          note: hc.note,
          parameters: List<HiddenCostParameter>.from(hc.parameters),
        ),
      );
    }
  }

  Future<void> _restoreReasonableRevisionIfCurrentLooksInflated() async {
    final current = widget.quoteToRevise;
    if (current == null || current.displayUnit == 'TL') return;

    final currentTotal = current.totalFor(current.displayUnit);
    if (currentTotal <= 0) return;

    final client = Supabase.instance.client;
    if (client.auth.currentSession == null) return;

    try {
      final rows = await client
          .from('quote_revisions')
          .select('snapshot')
          .eq('quote_id', current.id)
          .order('created_at', ascending: false)
          .limit(20);

      Quote? best;
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final rawSnapshot = row['snapshot'];
        if (rawSnapshot is! Map) continue;
        final snapshot = Quote.fromJson(Map<String, dynamic>.from(rawSnapshot));
        if (snapshot.displayUnit != current.displayUnit) continue;
        final snapshotTotal = snapshot.totalFor(snapshot.displayUnit);
        if (snapshotTotal <= 0) continue;
        if (currentTotal > snapshotTotal * 3) {
          best = snapshot;
          break;
        }
      }

      if (best == null || !mounted) return;
      final restored = best;

      setState(() {
        _clearLoadedQuoteDrafts();
        _legacyPriceRepairApplied = true;
        _loadFromExistingQuote(restored);
        _repairLoadedDraftsAgainstSource(restored);
      });
    } catch (_) {
      // Revision access is manager-only in some installs; local repair below
      // still protects the editor from saving another multiplied value.
    }
  }

  void _repairLoadedDraftsAgainstSource(Quote source) {
    if (_selectedDisplayUnit == 'TL') return;
    final rate =
        source.rateLookup[_selectedDisplayUnit] ??
        _rateLookup[_selectedDisplayUnit];
    if (rate == null || rate <= 1) return;

    final expectedTotal = source.totalFor(_selectedDisplayUnit);
    if (expectedTotal <= 0) return;

    final loadedTotal = _subtotalTl / rate;
    if (loadedTotal <= expectedTotal * 3) return;

    for (final item in _items) {
      final raw = double.tryParse(item.unitPriceController.text.trim()) ?? 0;
      if (raw <= 0) continue;
      item.unitPriceController.text = (raw / rate).toStringAsFixed(2);
    }

    _legacyPriceRepairApplied = true;
  }

  void _clearLoadedQuoteDrafts() {
    for (final item in _items) {
      item.dispose();
    }
    for (final section in _sections) {
      section.dispose();
    }
    _items.clear();
    _sections.clear();
    _hiddenCosts.clear();
  }

  Quote _repairLikelyDoubleConvertedQuote(Quote source) {
    if (source.displayUnit == 'TL') return source;

    final rate =
        source.rateLookup[source.displayUnit] ??
        _rateLookup[source.displayUnit];
    if (rate == null || rate <= 1) return source;

    final displayedTotal = source.totalFor(source.displayUnit);
    if (displayedTotal < 100000) return source;

    _legacyPriceRepairApplied = true;
    return Quote(
      id: source.id,
      code: source.code,
      customerName: source.customerName,
      customerCompany: source.customerCompany,
      cariId: source.cariId,
      title: source.title,
      note: source.note,
      createdAt: source.createdAt,
      displayUnit: source.displayUnit,
      items: source.items
          .map(
            (item) => QuoteLineItem(
              id: item.id,
              description: item.description,
              quantity: item.quantity,
              unit: item.unit,
              unitPriceTl: item.unitPriceTl / rate,
              discountRate: item.discountRate,
              sectionId: item.sectionId,
            ),
          )
          .toList(growable: false),
      marketSnapshot: source.marketSnapshot,
      documentProfile: source.documentProfile,
      hiddenCosts: source.hiddenCosts
          .map(
            (cost) => HiddenCostItem(
              id: cost.id,
              name: cost.name,
              note: cost.note,
              parameters: cost.parameters
                  .map(
                    (p) => HiddenCostParameter(
                      label: p.label,
                      quantity: p.quantity,
                      unitPriceTl: p.unitPriceTl / rate,
                    ),
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
      publicToken: source.publicToken,
      paymentMethod: source.paymentMethod,
      paymentTermDays: source.paymentTermDays,
      hidePrices: source.hidePrices,
      sections: source.sections,
      status: source.status,
      submittedAt: source.submittedAt,
      approvedAt: source.approvedAt,
      approvedBy: source.approvedBy,
      approvedByName: source.approvedByName,
      approvalNote: source.approvalNote,
      acceptedTotalTl: source.acceptedTotalTl,
      acceptedAmount: source.acceptedAmount,
      acceptedCurrencyCode: source.acceptedCurrencyCode,
      acceptedFxRate: source.acceptedFxRate,
      acceptedNote: source.acceptedNote,
      acceptedAt: source.acceptedAt,
      acceptedBy: source.acceptedBy,
      acceptedByName: source.acceptedByName,
      revisionCount: source.revisionCount,
      createdBy: source.createdBy,
      createdByName: source.createdByName,
      archivedAt: source.archivedAt,
    );
  }

  /// Teklif kaleminin `description` metninden ("KOD - isim - marka model")
  /// ilgili urunu bulup `id`'sini doner. Urun bulunamazsa null doner (bu
  /// durumda satir atlanir, kullaniciya uyari dusmez).
  String? _findProductIdFromDescription(String description) {
    final code = description.split(' - ').first.trim();
    if (code.isEmpty) return null;
    for (final product in widget.availableProducts) {
      if (product.code == code) return product.id;
    }
    return null;
  }

  String _formatQuantityForInput(double value) {
    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  String _formatUnitPriceForEditableInput(
    double unitPriceTl,
    String displayUnit, [
    Map<String, double>? rates,
  ]) {
    unitPriceTl = _repairLikelyInflatedUnitPriceTl(
      unitPriceTl,
      displayUnit,
      rates,
    );
    if (displayUnit == 'TL') {
      return unitPriceTl.toStringAsFixed(2);
    }

    final rate = rates?[displayUnit] ?? _rateLookup[displayUnit];
    if (rate == null || rate == 0) {
      return unitPriceTl.toStringAsFixed(2);
    }

    return (unitPriceTl / rate).toStringAsFixed(2);
  }

  double _repairLikelyInflatedUnitPriceTl(
    double unitPriceTl,
    String displayUnit, [
    Map<String, double>? rates,
  ]) {
    if (displayUnit == 'TL') return unitPriceTl;
    final rate = rates?[displayUnit] ?? _rateLookup[displayUnit];
    if (rate == null || rate <= 1) return unitPriceTl;
    final displayAmount = unitPriceTl / rate;
    if (displayAmount < 50000) return unitPriceTl;
    _legacyPriceRepairApplied = true;
    return unitPriceTl / rate;
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerCompanyController.dispose();
    _customerTitleController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _preparedByNameController.dispose();
    _preparedByTitleController.dispose();
    _preparedByPhoneController.dispose();
    _preparedByEmailController.dispose();
    _titleController.dispose();
    _noteController.dispose();
    _validityController.dispose();
    _paymentTermsController.dispose();
    _paymentTermDaysController.dispose();
    _deliveryTermsController.dispose();
    _productSearchController.dispose();
    _uncategorizedBulkDiscountController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    for (final section in _sections) {
      section.dispose();
    }
    super.dispose();
  }

  List<_DisplayUnitOption> get _displayUnits => [
    const _DisplayUnitOption(code: 'TL', label: 'TL'),
    for (final rate in _rates)
      if (rate.code != 'XAUTRY_GRAM' && rate.code != 'XAGTRY_GRAM')
        _DisplayUnitOption(code: rate.code, label: rate.label),
  ];

  List<String> get _productCategories {
    final categories =
        widget.availableProducts
            .map((product) => product.category)
            .toSet()
            .toList()
          ..sort();
    return ['Tum Kategoriler', ...categories];
  }

  Map<String, double> get _rateLookup => {
    'TL': 1,
    for (final rate in _rates) rate.code: rate.value,
  };

  List<Product> get _filteredProductsForAdd {
    final query = _productSearchController.text.trim().toLowerCase();
    return widget.availableProducts
        .where((product) {
          final matchesCategory =
              _productCategoryFilter == 'Tum Kategoriler' ||
              product.category == _productCategoryFilter;
          final haystack = [
            product.code,
            product.name,
            product.brand,
            product.model,
            product.category,
            product.technicalSummary,
          ].join(' ').toLowerCase();
          final matchesSearch = query.isEmpty || haystack.contains(query);
          return matchesCategory && matchesSearch;
        })
        .toList(growable: false);
  }

  double get _visibleSubtotalTl {
    return _items.fold(0, (sum, item) => sum + _lineNetTotal(item));
  }

  double get _hiddenSubtotalTl {
    return _hiddenCosts.fold(0, (sum, item) => sum + item.totalTl);
  }

  double get _subtotalTl => _visibleSubtotalTl + _hiddenSubtotalTl;

  String get _visibleQuoteCode {
    return _draftQuoteCode ??
        QuoteCodeGenerator.buildCode(timestamp: _draftTimestamp);
  }

  Future<void> _refreshDraftQuoteCode() async {
    if (_draftQuoteId != null && _draftQuoteCode != null) {
      return;
    }

    final requestToken = ++_codeRefreshToken;
    final code = await widget.quoteRepository.generateQuoteCode(
      date: _draftTimestamp,
    );

    if (!mounted || requestToken != _codeRefreshToken) {
      return;
    }

    setState(() => _draftQuoteCode = code);
  }

  Future<void> _ensureDraftIdentity() async {
    _draftQuoteId ??= _newId('quote');
    _draftQuoteCode ??= await widget.quoteRepository.generateQuoteCode(
      date: _draftTimestamp,
    );
    _draftShareToken ??= QuoteCodeGenerator.buildShareToken();
  }

  String _composedQuoteTitle() {
    final company = _customerCompanyController.text.trim().isNotEmpty
        ? _customerCompanyController.text.trim()
        : _customerNameController.text.trim();
    final topic = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : 'Teklif';
    return [
      company.isEmpty ? 'Firma' : company,
      topic,
      _visibleQuoteCode,
    ].join(' - ');
  }

  String _extractQuoteTopic(String rawTitle, Quote source) {
    final title = rawTitle.trim();
    if (title.isEmpty) return '';

    final code = source.code.trim();
    final company = source.customerCompany.trim().isNotEmpty
        ? source.customerCompany.trim()
        : source.customerName.trim();
    final suffix = code.isEmpty ? '' : ' - $code';
    final prefix = company.isEmpty ? '' : '$company - ';

    var topic = title;
    if (suffix.isNotEmpty && topic.endsWith(suffix)) {
      topic = topic.substring(0, topic.length - suffix.length).trim();
    }
    if (prefix.isNotEmpty && topic.startsWith(prefix)) {
      topic = topic.substring(prefix.length).trim();
    }
    return topic.isEmpty ? title : topic;
  }

  Future<void> _saveQuote() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final quote = await _buildQuote(source: 'ARSIV');
      if (quote == null) {
        return;
      }

      await widget.quoteRepository.saveQuote(quote);
      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(quote);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Teklifi yonetici onayina gonderir: status=pending, submittedAt=now.
  /// Revize akisinda (mevcut teklifin gecmisi varsa) revizyon sayacini bir
  /// artirir ve onceki onaylayan/not alanlarini temizler.
  Future<void> _submitForApproval() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final built = await _buildQuote(source: 'ARSIV');
      if (built == null) return;

      final previousRevision = widget.quoteToRevise?.revisionCount ?? 0;
      final isRevision = widget.quoteToRevise != null;
      final quote = built.copyWith(
        status: QuoteStatus.pending,
        submittedAt: DateTime.now(),
        approvedAt: null,
        approvedByName: '',
        approvalNote: '',
        revisionCount: isRevision ? previousRevision + 1 : 0,
      );

      await widget.quoteRepository.saveQuote(quote);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRevision
                ? 'Revizyon onaya gonderildi (Rev ${quote.revisionCount})'
                : 'Teklif onaya gonderildi',
          ),
        ),
      );
      Navigator.of(context).pop(quote);
    } catch (error, stackTrace) {
      debugPrint('Submit for approval failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Onaya gonderilemedi: $error')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final quote = await _buildQuote(source: 'PDF');
      if (quote == null) {
        return;
      }

      // Supabase kaydini PDF ile seri bekletme; ag yavaslarsa UI kilitlenirdi.
      unawaited(
        widget.quoteRepository.saveQuote(quote).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint('Quote save failed (continuing with local PDF): $error');
          debugPrintStack(stackTrace: stackTrace);
        }),
      );

      final path = await _pdfExportService.exportQuote(
        quote,
        onAfterSaveLocation: () {
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(
              content: Text('PDF üretiliyor...'),
              duration: Duration(minutes: 1),
            ),
          );
        },
      );
      messenger.hideCurrentSnackBar();

      if (!mounted || path == null) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF kaydedildi: $path')));
    } catch (error, stackTrace) {
      messenger.hideCurrentSnackBar();
      debugPrint('PDF export failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF çıkarılamadı: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _exportExcel() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final quote = await _buildQuote(source: 'EXCEL');
      if (quote == null) {
        return;
      }

      try {
        await widget.quoteRepository.saveQuote(quote);
      } catch (error, stackTrace) {
        debugPrint('Quote save failed (continuing with local Excel): $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      final path = await _excelExportService.exportQuote(quote);
      if (!mounted || path == null) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Excel kaydedildi: $path')));
    } catch (error, stackTrace) {
      debugPrint('Excel export failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Excel çıkarılamadı: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _exportMaterialRequestPdf() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final quote = await _buildQuote(source: 'ISTEK_LISTESI_PDF');
      if (quote == null) {
        return;
      }

      final path = await _pdfExportService.exportMaterialRequest(
        quote,
        onAfterSaveLocation: () {
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Istek listesi PDF uretiliyor...'),
              duration: Duration(minutes: 1),
            ),
          );
        },
      );
      messenger.hideCurrentSnackBar();

      if (!mounted || path == null) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Istek listesi PDF: $path')));
    } catch (error, stackTrace) {
      messenger.hideCurrentSnackBar();
      debugPrint('Material request PDF export failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Istek listesi PDF cikarilamadi: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _exportMaterialRequestExcel() async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final quote = await _buildQuote(source: 'ISTEK_LISTESI_EXCEL');
      if (quote == null) {
        return;
      }

      final path = await _excelExportService.exportMaterialRequest(quote);
      if (!mounted || path == null) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Istek listesi Excel: $path')));
    } catch (error, stackTrace) {
      debugPrint('Material request Excel export failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Istek listesi Excel cikarilamadi: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<Quote?> _buildQuote({required String source}) async {
    final formState = _formKey.currentState;
    if (formState == null) {
      return null;
    }
    if (!formState.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Form alanlarinda hata var. Kirmizi kutucuklari kontrol edin.',
          ),
        ),
      );
      return null;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('En az bir kalem ekleyin.')));
      return null;
    }

    await _ensureDraftIdentity();
    if (!mounted) {
      return null;
    }

    final knownSectionIds = _sections.map((s) => s.id).toSet();
    final items = _items
        .map((draft) {
          final description = draft.descriptionController.text.trim();
          final unit = draft.unitController.text.trim();

          final quantity = double.parse(draft.quantityController.text.trim());
          final unitPrice = _lineUnitPriceTl(draft);
          final discount =
              double.tryParse(draft.discountController.text.trim()) ?? 0;

          final resolvedSectionId = knownSectionIds.contains(draft.sectionId)
              ? draft.sectionId
              : '';

          return QuoteLineItem(
            id: _newId('line'),
            description: description,
            quantity: quantity,
            unit: unit,
            unitPriceTl: unitPrice,
            discountRate: discount,
            sectionId: resolvedSectionId,
          );
        })
        .whereType<QuoteLineItem>()
        .where((item) => item.quantity > 0)
        .toList(growable: false);

    final sections = _sections
        .map((draft) => QuoteSection(id: draft.id, name: draft.name.trim()))
        .toList(growable: false);

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Kalemlerde aciklama, miktar, birim ve fiyat bilgisi olmali.',
          ),
        ),
      );
      return null;
    }

    final baseNote = _noteController.text.trim();
    final taggedNote = source == 'ARSIV'
        ? baseNote
        : '$baseNote\nCikti bicimi: $source';

    final hiddenCosts = _hiddenCosts
        .where((draft) => draft.totalTl > 0)
        .map(
          (draft) => HiddenCostItem(
            id: draft.id,
            name: draft.name.trim().isEmpty ? 'Ek Yukleme' : draft.name.trim(),
            note: draft.note.trim(),
            parameters: List<HiddenCostParameter>.from(draft.parameters),
          ),
        )
        .toList(growable: false);

    final paymentTermDays = _paymentMethod == QuotePaymentMethod.installment
        ? (int.tryParse(_paymentTermDaysController.text.trim()) ?? 0)
              .clamp(0, 365)
              .toInt()
        : 0;

    final p = _issuerProfile;
    final company = _selectedOwnCompany;
    final src = widget.quoteToRevise;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final resolvedCreatorId = src?.createdBy ?? uid;
    final prepared = _preparedByNameController.text.trim();
    final resolvedCreatorName = (src?.createdByName ?? '').trim().isNotEmpty
        ? src!.createdByName
        : (prepared.isNotEmpty
              ? prepared
              : ((p?.preparedByName ?? '').trim().isNotEmpty
                    ? p!.preparedByName.trim()
                    : Supabase.instance.client.auth.currentUser?.email
                              ?.trim() ??
                          ''));

    return Quote(
      id: _draftQuoteId!,
      code: _draftQuoteCode!,
      publicToken: _draftShareToken ?? '',
      paymentMethod: _paymentMethod,
      paymentTermDays: paymentTermDays,
      hidePrices: _hidePrices,
      customerName: _customerNameController.text.trim(),
      customerCompany: _customerCompanyController.text.trim(),
      title: _composedQuoteTitle(),
      note: taggedNote,
      createdAt: _draftTimestamp,
      displayUnit: _selectedDisplayUnit,
      items: items,
      sections: sections,
      hiddenCosts: hiddenCosts,
      marketSnapshot: _rates,
      cariId: _selectedCariId.trim(),
      documentProfile: company.toDocumentProfile(
        preparedByName: _preparedByNameController.text.trim(),
        preparedByTitle: _preparedByTitleController.text.trim(),
        preparedByPhone: _preparedByPhoneController.text.trim(),
        preparedByEmail: _preparedByEmailController.text.trim(),
        customerContactTitle: _customerTitleController.text.trim(),
        customerPhone: _customerPhoneController.text.trim(),
        customerEmail: _customerEmailController.text.trim(),
        validityText: _validityController.text.trim(),
        paymentTerms: _paymentTermsController.text.trim(),
        deliveryTerms: _deliveryTermsController.text.trim(),
        vatRate: _docVatRate(),
      ),
      status: src?.status ?? QuoteStatus.draft,
      submittedAt: src?.submittedAt,
      approvedAt: src?.approvedAt,
      approvedByName: src?.approvedByName ?? '',
      approvalNote: src?.approvalNote ?? '',
      revisionCount: src?.revisionCount ?? 0,
      createdBy: resolvedCreatorId,
      createdByName: resolvedCreatorName,
      archivedAt: src?.archivedAt,
    );
  }

  void _addProductToQuote(Product product) {
    final targetSectionId = _activeSectionId ?? '';
    final existingIndex = _items.indexWhere(
      (item) =>
          item.productId == product.id && item.sectionId == targetSectionId,
    );

    if (existingIndex != -1) {
      final existing = _items[existingIndex];
      final currentQuantity =
          double.tryParse(existing.quantityController.text.trim()) ?? 0;
      final nextQuantity = currentQuantity + 1;
      setState(() {
        existing.quantityController.text = nextQuantity.toStringAsFixed(
          nextQuantity.truncateToDouble() == nextQuantity ? 0 : 2,
        );
        final discount = _bulkDiscountForSection(targetSectionId);
        if (discount != null) {
          existing.discountController.text = discount;
        }
      });
      return;
    }

    final defaultUnitPrice = product.priceInTl(_rateLookup);
    final discount = _bulkDiscountForSection(targetSectionId) ?? '0';
    setState(() {
      _items.add(
        _LineDraft(
          productId: product.id,
          priceCurrencyCode: product.currencyCode,
          description:
              '${product.code} - ${product.name} - ${product.brand} ${product.model}',
          unit: product.unit,
          quantity: '1',
          unitPriceTl: _formatUnitPriceForEditableInput(
            defaultUnitPrice,
            product.currencyCode,
          ),
          discount: discount,
          sectionId: targetSectionId,
        ),
      );
    });
  }

  void _addCustomLine() {
    final targetSectionId = _activeSectionId ?? '';
    final discount = _bulkDiscountForSection(targetSectionId) ?? '0';
    setState(() {
      _items.add(
        _LineDraft(
          productId: null,
          priceCurrencyCode: _selectedDisplayUnit,
          description: '',
          unit: 'adet',
          quantity: '1',
          unitPriceTl: '0',
          discount: discount,
          sectionId: targetSectionId,
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // KATEGORI / BOLUM YONETIMI
  // ---------------------------------------------------------------------------

  int _itemCountForSection(String sectionId) {
    return _items.where((item) => item.sectionId == sectionId).length;
  }

  int get _uncategorizedItemCount {
    final knownIds = _sections.map((s) => s.id).toSet();
    return _items.where((item) => !knownIds.contains(item.sectionId)).length;
  }

  Future<void> _addSection() async {
    final name = await _promptSectionName(
      title: 'Yeni Kategori',
      initial: '',
      confirmLabel: 'Ekle',
    );
    if (name == null || name.isEmpty) return;

    final section = _SectionDraft(id: _newId('section'), name: name);
    setState(() {
      _sections.add(section);
      _activeSectionId = section.id;
    });
  }

  Future<void> _renameSection(_SectionDraft section) async {
    final name = await _promptSectionName(
      title: 'Kategori Adi',
      initial: section.name,
      confirmLabel: 'Kaydet',
    );
    if (name == null || name.isEmpty) return;
    setState(() => section.name = name);
  }

  Future<void> _deleteSection(_SectionDraft section) async {
    final itemCount = _itemCountForSection(section.id);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${section.name.isEmpty ? "Kategori" : section.name} silinsin mi?',
        ),
        content: Text(
          itemCount == 0
              ? 'Bu kategori silinecek.'
              : 'Bu kategoride $itemCount kalem var. Kategori silindiginde kalemler "Kategorisiz" kovasina tasinir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgec'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      for (final item in _items) {
        if (item.sectionId == section.id) {
          item.sectionId = '';
        }
      }
      _sections.remove(section);
      section.dispose();
      if (_activeSectionId == section.id) {
        _activeSectionId = null;
      }
    });
  }

  void _moveItemToSection(_LineDraft draft, String sectionId) {
    if (draft.sectionId == sectionId) return;
    setState(() {
      draft.sectionId = sectionId;
      final discount = _bulkDiscountForSection(sectionId);
      if (discount != null) {
        draft.discountController.text = discount;
      }
    });
  }

  String? _bulkDiscountForSection(String sectionId) {
    final controller = _bulkDiscountControllerForSection(sectionId);
    return controller == null ? null : _normalizedDiscountText(controller.text);
  }

  TextEditingController? _bulkDiscountControllerForSection(String sectionId) {
    if (sectionId.isEmpty) {
      return _uncategorizedBulkDiscountEnabled
          ? _uncategorizedBulkDiscountController
          : null;
    }
    _SectionDraft? section;
    for (final candidate in _sections) {
      if (candidate.id == sectionId) {
        section = candidate;
        break;
      }
    }
    if (section == null || !section.bulkDiscountEnabled) {
      return null;
    }
    return section.bulkDiscountController;
  }

  String _normalizedDiscountText(String value) {
    final parsed = (double.tryParse(value.trim()) ?? 0).clamp(-100, 100);
    final asDouble = parsed.toDouble();
    return asDouble == asDouble.truncateToDouble()
        ? asDouble.toStringAsFixed(0)
        : asDouble.toStringAsFixed(2);
  }

  void _applyBulkDiscountToGroup(_SectionGroup group) {
    final controller = group.draft == null
        ? _uncategorizedBulkDiscountController
        : group.draft!.bulkDiscountController;
    final discount = _normalizedDiscountText(controller.text);
    controller.text = discount;
    _setGroupDiscount(group, discount);
  }

  void _setGroupDiscount(_SectionGroup group, String discount) {
    for (final item in group.items) {
      item.discountController.text = discount;
    }
  }

  Future<String?> _promptSectionName({
    required String title,
    required String initial,
    required String confirmLabel,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _SectionNameDialog(
        title: title,
        initial: initial,
        confirmLabel: confirmLabel,
      ),
    );
    if (result == null) return null;
    return result.trim().isEmpty ? null : result.trim();
  }

  void _removeLine(_LineDraft draft) {
    setState(() {
      _items.remove(draft);
      draft.dispose();
    });
  }

  Future<void> _openHiddenCostDialog({_HiddenCostDraft? editing}) async {
    final result = await showDialog<_HiddenCostDraft>(
      context: context,
      builder: (ctx) => _HiddenCostDialog(
        money: _money,
        editing: editing,
        newIdBuilder: () => _newId('hidden'),
      ),
    );

    if (result == null) return;

    setState(() {
      if (editing != null) {
        final idx = _hiddenCosts.indexOf(editing);
        if (idx != -1) {
          _hiddenCosts[idx] = result;
          return;
        }
      }
      _hiddenCosts.add(result);
    });
  }

  void _removeHiddenCost(_HiddenCostDraft draft) {
    setState(() => _hiddenCosts.remove(draft));
  }

  String _newId(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    _idSequence++;
    return '$prefix-$now-$_idSequence';
  }

  Product? _findProductById(String? productId) {
    if (productId == null) {
      return null;
    }

    for (final product in widget.availableProducts) {
      if (product.id == productId) {
        return product;
      }
    }
    return null;
  }

  bool _isProductSelected(String productId) {
    return _items.any((item) => item.productId == productId);
  }

  double _lineNetTotal(_LineDraft draft) {
    final quantity = double.tryParse(draft.quantityController.text.trim()) ?? 0;
    final unitPrice = _lineUnitPriceTl(draft);
    final discount = double.tryParse(draft.discountController.text.trim()) ?? 0;
    final discountRatio = discount / 100;
    return quantity * unitPrice * (1 - discountRatio);
  }

  double _lineUnitPriceTl(_LineDraft draft) {
    final raw = double.tryParse(draft.unitPriceController.text.trim()) ?? 0;
    if (draft.priceCurrencyCode == 'TL') {
      return raw;
    }
    return raw * (_rateLookup[draft.priceCurrencyCode] ?? 1);
  }

  String _formatTotalForDisplay(double total, String unitCode) {
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: switch (unitCode) {
        'USDTRY' => r'$ ',
        'EURTRY' => 'EUR ',
        _ => 'TL ',
      },
      decimalDigits: unitCode == 'TL' ? 2 : 4,
    );
    return formatter.format(total);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1180;

    return Scaffold(
      appBar: AppBar(title: const Text('Teklif Olustur')),
      body: WorkspaceBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Form(
              key: _formKey,
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _buildFormPanel(expandList: true),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 3,
                          child: _buildSummaryPanel(expandActions: true),
                        ),
                      ],
                    )
                  : ListView(
                      children: [
                        _buildFormPanel(expandList: false),
                        const SizedBox(height: 20),
                        _buildSummaryPanel(expandActions: false),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Revize modunda seller'a yoneticinin sebebini + revizyon sayacini
  /// gosteren amber uyari bandi. Normal (yeni) teklifte bos doner.
  Widget _buildRevisionBanner() {
    final source = widget.quoteToRevise;
    if (source == null || source.approvalNote.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3B86C)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.history_rounded,
              size: 20,
              color: Color(0xFF9D5C1D),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yonetici notu - Rev ${source.revisionCount}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF9D5C1D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    source.approvalNote,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF624420),
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormPanel({required bool expandList}) {
    final filteredProducts = _filteredProductsForAdd;
    final lineList = _buildSectionedItemsList(expandList: expandList);

    final panelColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormHeader(),
        _buildRevisionBanner(),
        if (!_infoCollapsed) ...[
          const SizedBox(height: 24),
          _buildTopFormSections(),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                'Urun Katalogu',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${filteredProducts.length} urun',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5B6F7F),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Aradigin urunu listeden sec, dogrudan kalemlere al ve miktar-fiyat-iskonto bilgisini altta yonet.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5B6F7F)),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final searchField = TextField(
              controller: _productSearchController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Kod, urun adi, marka veya model ara',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            );
            final categoryField = DropdownButtonFormField<String>(
              initialValue: _productCategoryFilter,
              isDense: true,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: _productCategories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _productCategoryFilter = value);
                }
              },
            );

            if (constraints.maxWidth < 920) {
              return Column(
                children: [
                  searchField,
                  const SizedBox(height: 10),
                  categoryField,
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 3, child: searchField),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: categoryField),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _buildProductCatalog(filteredProducts: filteredProducts),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                'Secilen Kalemler',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${_items.length} kalem',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5B6F7F),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _money.format(_visibleSubtotalTl),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF17304C),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _addCustomLine,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Ozel Kalem Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.availableProducts.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFFFFF2E6),
              border: Border.all(color: const Color(0xFFE3C5A3)),
            ),
            child: const Text(
              'Katalogda kayitli urun yok. Ozel kalem ekleyerek teklif hazirlayabilirsiniz.',
            ),
          ),
        _buildCategoryBar(),
        const SizedBox(height: 12),
        lineList,
        const SizedBox(height: 22),
        _buildHiddenCostsSection(),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: expandList
            ? SingleChildScrollView(primary: false, child: panelColumn)
            : panelColumn,
      ),
    );
  }

  Widget _buildFormHeader() {
    final codePlate = _QuoteCodePlate(code: _visibleQuoteCode);
    final collapseTooltip = _infoCollapsed
        ? 'Bilgileri genislet'
        : 'Bilgileri kuculterek kalem alanina odaklan';
    final toggleButton = Tooltip(
      message: collapseTooltip,
      child: IconButton.filledTonal(
        onPressed: () => setState(() => _infoCollapsed = !_infoCollapsed),
        icon: Icon(
          _infoCollapsed
              ? Icons.unfold_more_rounded
              : Icons.unfold_less_rounded,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleRow = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Musteri ve Teklif Bilgileri',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            toggleButton,
          ],
        );
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleRow,
            const SizedBox(height: 8),
            Text(
              _infoCollapsed
                  ? 'Bilgi bolumu kapali. Asagida kalem listesi genisletildi.'
                  : 'Teklif kodu ustte sabit kalir; ayni kod PDF ve Excel dosya adina da yansir.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF5B6F7F)),
            ),
            if (_infoCollapsed) ...[
              const SizedBox(height: 10),
              _buildCollapsedInfoSummary(),
            ],
          ],
        );

        if (constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 16), codePlate],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 18),
            SizedBox(width: 360, child: codePlate),
          ],
        );
      },
    );
  }

  Widget _buildCollapsedInfoSummary() {
    final company = _customerCompanyController.text.trim();
    final contact = _customerNameController.text.trim();
    final title = _titleController.text.trim();
    final parts = <String>[
      if (company.isNotEmpty) company,
      if (contact.isNotEmpty) contact,
      if (title.isNotEmpty) title,
    ];
    final summary = parts.isEmpty
        ? 'Henuz bilgi girilmedi. Butona basarak acabilirsin.'
        : parts.join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFEEF3F8),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFF17304C),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF17304C),
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCatalog({required List<Product> filteredProducts}) {
    final hasProducts = widget.availableProducts.isNotEmpty;

    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.74),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!hasProducts) {
            return Center(
              child: Text(
                'Katalogda gosterilecek urun bulunmuyor.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }

          if (filteredProducts.isEmpty) {
            return Center(
              child: Text(
                'Filtreye uygun urun bulunamadi.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }

          if (constraints.maxWidth < 960) {
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: filteredProducts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                return _CompactCatalogItem(
                  product: product,
                  selected: _isProductSelected(product.id),
                  onAdd: () => _addProductToQuote(product),
                );
              },
            );
          }

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    SizedBox(width: 136, child: _CatalogLabel('Kod')),
                    Expanded(child: _CatalogLabel('Urun')),
                    SizedBox(width: 108, child: _CatalogLabel('Stok')),
                    SizedBox(
                      width: 132,
                      child: _CatalogLabel('Satis', alignEnd: true),
                    ),
                    SizedBox(width: 118),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return _CatalogRow(
                      product: product,
                      selected: _isProductSelected(product.id),
                      onAdd: () => _addProductToQuote(product),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHiddenCostsSection() {
    final hasCosts = _hiddenCosts.isNotEmpty;
    final totalText = _money.format(_hiddenSubtotalTl);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFF3EEFB),
        border: Border.all(color: const Color(0xFFD6C8EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gizli Yuklemeler',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF4A2C80),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PDF ve Excel ciktisinda ayri satir olarak gozukmez. '
                      'Toplam tutar, gorunur kalemlerin fiyatlarina orantili olarak yedirilir.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5B4684),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: () => _openHiddenCostDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yukleme Ekle'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasCosts)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.white.withValues(alpha: 0.75),
                border: Border.all(color: const Color(0xFFD6C8EC)),
              ),
              child: Text(
                'Henuz gizli yukleme eklenmedi. Devreye alma, egitim, nakliye gibi '
                'PDF\'te gorunmeyecek maliyetleri buradan tanimlayabilirsin.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5B4684),
                ),
              ),
            )
          else
            Column(
              children: [
                for (final draft in _hiddenCosts) ...[
                  _HiddenCostRow(
                    draft: draft,
                    money: _money,
                    onEdit: () => _openHiddenCostDialog(editing: draft),
                    onRemove: () => _removeHiddenCost(draft),
                  ),
                  const SizedBox(height: 10),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF4A2C80),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.visibility_off_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Gizli yukleme toplami (PDF\'e yansimaz, fiyatlara dagitilir)',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        totalText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyLineState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.76),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kalem listesi hazir degil',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Yukaridaki katalogdan urun secildiginde burada miktar, fiyat, iskonto ve toplam satir bazinda yonetilir.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5B6F7F)),
          ),
        ],
      ),
    );
  }

  /// Kategori secici bar: "Kategorisiz" + mevcut kategoriler + "+ Kategori".
  /// Aktif chip bir sonraki eklenecek urunun hangi kovaya gidecegini belirler.
  Widget _buildCategoryBar() {
    const ink = Color(0xFF17304C);
    const slate = Color(0xFF5B6F7F);

    final uncategorizedCount = _uncategorizedItemCount;
    final chips = <Widget>[
      _buildCategoryChip(
        label: 'Kategorisiz',
        count: uncategorizedCount,
        isActive: _activeSectionId == null,
        onTap: () => setState(() => _activeSectionId = null),
      ),
      for (final section in _sections)
        _buildCategoryChip(
          label: section.name.isEmpty ? 'Isimsiz' : section.name,
          count: _itemCountForSection(section.id),
          isActive: _activeSectionId == section.id,
          onTap: () => setState(() => _activeSectionId = section.id),
          onRename: () => _renameSection(section),
          onDelete: () => _deleteSection(section),
        ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.66),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category_rounded, size: 18, color: ink),
              const SizedBox(width: 8),
              Text(
                'Kategoriler',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addSection,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Kategori Ekle'),
                style: TextButton.styleFrom(
                  foregroundColor: ink,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Secili kategori bir sonraki eklenecek kalemin grubunu belirler.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: slate,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required int count,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onRename,
    VoidCallback? onDelete,
  }) {
    const ink = Color(0xFF17304C);
    final bg = isActive ? ink : const Color(0xFFF1F4F8);
    final fg = isActive ? Colors.white : ink;
    final counterBg = isActive
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.white;
    final counterFg = isActive ? Colors.white : const Color(0xFF5B6F7F);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            6,
            onRename == null && onDelete == null ? 14 : 4,
            6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: counterBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: counterFg,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onRename != null)
                IconButton(
                  onPressed: onRename,
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  color: fg,
                  tooltip: 'Yeniden adlandir',
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(28, 28),
                  ),
                ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 14),
                  color: fg,
                  tooltip: 'Kategoriyi sil',
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(4),
                    minimumSize: const Size(28, 28),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Kalemleri kategoriye gore gruplayarak uretir. Bos durum icin mevcut
  /// `_buildEmptyLineState()` kullanilir. Her grup kendi kartinda, varsa
  /// ara toplamla birlikte gorunur.
  Widget _buildSectionedItemsList({required bool expandList}) {
    if (_items.isEmpty) return _buildEmptyLineState();

    final groups = <_SectionGroup>[];
    for (final section in _sections) {
      final bucket = _items
          .where((item) => item.sectionId == section.id)
          .toList(growable: false);
      if (bucket.isEmpty) continue;
      groups.add(_SectionGroup(draft: section, items: bucket));
    }
    final knownIds = _sections.map((s) => s.id).toSet();
    final orphaned = _items
        .where((item) => !knownIds.contains(item.sectionId))
        .toList(growable: false);
    if (orphaned.isNotEmpty) {
      groups.add(_SectionGroup(draft: null, items: orphaned));
    }

    final children = <Widget>[];
    for (var i = 0; i < groups.length; i++) {
      if (i > 0) children.add(const SizedBox(height: 14));
      children.add(_buildSectionGroupCard(groups[i], expandList: expandList));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildSectionGroupCard(
    _SectionGroup group, {
    required bool expandList,
  }) {
    const ink = Color(0xFF17304C);
    const slate = Color(0xFF5B6F7F);
    final groupSubtotal = group.items.fold<double>(
      0,
      (sum, draft) => sum + _lineNetTotal(draft),
    );
    final isUncategorized = group.draft == null;
    final title = isUncategorized
        ? 'Kategorisiz'
        : (group.draft!.name.isEmpty ? 'Isimsiz' : group.draft!.name);
    final headerBg = isUncategorized
        ? const Color(0xFFF1F4F8)
        : const Color(0xFFE9EEF5);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.76),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              border: const Border(
                bottom: BorderSide(color: Color(0xFFD7DEE6)),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      isUncategorized
                          ? Icons.label_off_outlined
                          : Icons.folder_rounded,
                      size: 18,
                      color: ink,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                ),
                          ),
                          Text(
                            '${group.items.length} kalem',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: slate,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _money.format(groupSubtotal),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!isUncategorized) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Yeniden adlandir',
                        onPressed: () => _renameSection(group.draft!),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        tooltip: 'Kategoriyi sil',
                        onPressed: () => _deleteSection(group.draft!),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _buildBulkDiscountControl(group),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Column(
              children: [
                _QuoteLineSheetHeader(
                  priceCurrencyLabel: _displayUnitShortLabel(
                    _selectedDisplayUnit,
                  ),
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < group.items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 1),
                  Builder(
                    builder: (ctx) {
                      final draft = group.items[i];
                      final product = _findProductById(draft.productId);
                      return _QuoteLineEditorRow(
                        rowNumber: i + 1,
                        product: product,
                        draft: draft,
                        money: _money,
                        onChanged: () => setState(() {}),
                        onRemove: () => _removeLine(draft),
                        lineTotal: _lineNetTotal(draft),
                        displayUnit: draft.priceCurrencyCode,
                        useDesktopLayout: expandList,
                        discountLocked: _isBulkDiscountEnabled(group),
                        numberValidator: _numberValidator,
                        discountValidator: _discountValidator,
                        requiredTextValidator: _requiredTextValidator,
                        availableSections: _buildSectionMoveTargets(
                          currentSectionId: draft.sectionId,
                        ),
                        onMoveToSection: (targetId) =>
                            _moveItemToSection(draft, targetId),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _displayUnitShortLabel(String code) {
    return switch (code) {
      'USDTRY' => 'USD',
      'EURTRY' => 'EUR',
      _ => 'TL',
    };
  }

  Widget _buildBulkDiscountControl(_SectionGroup group) {
    final enabled = _isBulkDiscountEnabled(group);
    final controller = group.draft == null
        ? _uncategorizedBulkDiscountController
        : group.draft!.bulkDiscountController;

    return Row(
      children: [
        Checkbox(
          value: enabled,
          onChanged: (value) {
            setState(() {
              if (group.draft == null) {
                _uncategorizedBulkDiscountEnabled = value ?? false;
              } else {
                group.draft!.bulkDiscountEnabled = value ?? false;
              }
              if (value == true) {
                _applyBulkDiscountToGroup(group);
              }
            });
          },
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 2),
        const Text(
          'Toplu iskonto',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF17304C),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 96,
          child: TextFormField(
            controller: controller,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Iskonto %',
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: enabled ? _discountValidator : null,
            onChanged: (_) {
              if (!enabled) return;
              setState(() => _setGroupDiscount(group, controller.text));
            },
          ),
        ),
      ],
    );
  }

  bool _isBulkDiscountEnabled(_SectionGroup group) {
    return group.draft == null
        ? _uncategorizedBulkDiscountEnabled
        : group.draft!.bulkDiscountEnabled;
  }

  List<_SectionMoveTarget> _buildSectionMoveTargets({
    required String currentSectionId,
  }) {
    return [
      if (currentSectionId.isNotEmpty ||
          _sections.any((s) => s.id == currentSectionId))
        const _SectionMoveTarget(id: '', label: 'Kategorisiz'),
      for (final section in _sections)
        if (section.id != currentSectionId)
          _SectionMoveTarget(
            id: section.id,
            label: section.name.isEmpty ? 'Isimsiz' : section.name,
          ),
    ];
  }

  Widget _buildTopFormSections() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            children: [
              _buildOwnCompanyFields(),
              const SizedBox(height: 16),
              _buildPreparedByFields(),
              const SizedBox(height: 16),
              _buildCustomerFields(),
              const SizedBox(height: 16),
              _buildOfferFields(),
              const SizedBox(height: 16),
              _buildCommercialTermsFields(),
            ],
          );
        }

        return Column(
          children: [
            _buildOwnCompanyFields(),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildPreparedByFields()),
                const SizedBox(width: 16),
                Expanded(child: _buildCustomerFields()),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildOfferFields()),
                const SizedBox(width: 16),
                Expanded(child: _buildCommercialTermsFields()),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildOwnCompanyFields() {
    return _buildSectionCard(
      title: 'Teklifi Veren Firma',
      subtitle: 'PDF firma bilgileri seçilen karttan alınır.',
      child: DropdownButtonFormField<String>(
        initialValue: _ownCompanies.any((c) => c.id == _selectedOwnCompanyId)
            ? _selectedOwnCompanyId
            : _ownCompanies.first.id,
        decoration: const InputDecoration(labelText: 'Firma'),
        items: [
          for (final company in _ownCompanies)
            DropdownMenuItem(value: company.id, child: Text(company.menuLabel)),
        ],
        onChanged: widget.quoteToRevise != null
            ? null
            : (value) {
                if (value == null) return;
                setState(() => _selectedOwnCompanyId = value);
              },
      ),
    );
  }

  Widget _buildPreparedByFields() {
    return _buildSectionCard(
      title: 'Hazirlayan',
      subtitle: 'PDF kapaginda gozukur.',
      child: Column(
        children: [
          TextFormField(
            controller: _preparedByNameController,
            decoration: const InputDecoration(labelText: 'Ad Soyad'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Zorunlu alan' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _preparedByTitleController,
            decoration: const InputDecoration(labelText: 'Unvan'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Zorunlu alan' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _preparedByPhoneController,
            decoration: const InputDecoration(labelText: 'Telefon'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _preparedByEmailController,
            decoration: const InputDecoration(labelText: 'E-posta'),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerFields() {
    return _buildSectionCard(
      title: 'Musteri Yetkilisi',
      subtitle: 'Kapakta iletisim karti olarak yer alir.',
      child: Column(
        children: [
          if (widget.cariRepository.isRemoteReady) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Hizli cari',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF17304C),
                    ),
                  ),
                  if (_cariler.isEmpty)
                    Text(
                      'Kayit yok — Carileri yonet ile ekleyin.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF5B6F7F),
                      ),
                    )
                  else
                    SizedBox(
                      width: 280,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Kayitli cari',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _effectiveCariDropdownValue(),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('Manuel giris'),
                              ),
                              ..._cariler.map(
                                (c) => DropdownMenuItem<String>(
                                  value: c.id,
                                  child: Text(
                                    c.menuLabel,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (id) {
                              setState(() {
                                _selectedCariId = id ?? '';
                                if (_selectedCariId.isEmpty) return;
                                for (final c in _cariler) {
                                  if (c.id == _selectedCariId) {
                                    _applyCariToForm(c);
                                    break;
                                  }
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _quickCreateCari,
                    icon: const Icon(Icons.add_business_rounded, size: 18),
                    label: const Text('Hizli cari ekle'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (ctx) => CarilerPage(
                            repository: widget.cariRepository,
                            priceAdjustmentRuleRepository:
                                widget.priceAdjustmentRuleRepository,
                          ),
                        ),
                      );
                      final list = await widget.cariRepository.fetchAll();
                      if (!mounted) return;
                      setState(() => _cariler = list);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('Carileri yonet'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _customerCompanyController,
            decoration: const InputDecoration(labelText: 'Firma Adi'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Zorunlu alan' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerNameController,
            decoration: const InputDecoration(labelText: 'Yetkili Ad Soyad'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Zorunlu alan' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerTitleController,
            decoration: const InputDecoration(labelText: 'Unvan'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerPhoneController,
            decoration: const InputDecoration(labelText: 'Telefon'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerEmailController,
            decoration: const InputDecoration(labelText: 'E-posta'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferFields() {
    return _buildSectionCard(
      title: 'Teklif Kurgusu',
      subtitle:
          'Baslik otomatik olarak Firma - Konu - Kod seklinde kaydedilir.',
      child: Column(
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Konu',
              hintText: 'Jetfan Otopark, Chiller Bakim, DDC Pano...',
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Zorunlu alan' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Kayit adi: ${_composedQuoteTitle()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF5B6F7F),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Notlar / Kisa ozet'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommercialTermsFields() {
    return _buildSectionCard(
      title: 'Ticari Kosullar',
      subtitle: 'PDF ilk sayfada bilgi karti olarak gosterilir.',
      child: Column(
        children: [
          TextFormField(
            controller: _validityController,
            decoration: const InputDecoration(labelText: 'Teklif Gecerliligi'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _deliveryTermsController,
            decoration: const InputDecoration(labelText: 'Teslim Kosulu'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _paymentTermsController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Odeme Kosulu'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.66),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF17304C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF5B6F7F),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildSummaryPanel({required bool expandActions}) {
    final selectedRate = _selectedDisplayUnit == 'TL'
        ? null
        : _rates.firstWhere(
            (rate) => rate.code == _selectedDisplayUnit,
            orElse: () => _rates.first,
          );
    final convertedTotal = selectedRate == null || selectedRate.value == 0
        ? _subtotalTl
        : _subtotalTl / selectedRate.value;

    final isRevision = widget.quoteToRevise != null;
    final st = widget.quoteToRevise?.status;
    final canSubmitForApproval =
        st == null || st == QuoteStatus.draft || st == QuoteStatus.rejected;
    final actionButtons = Column(
      children: [
        if (canSubmitForApproval) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitForApproval,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                isRevision ? 'Revizyonu Onaya Gonder' : 'Onaya Gonder',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB8843C),
                foregroundColor: Colors.white,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: _isSubmitting ? null : _saveQuote,
            icon: const Icon(Icons.archive_outlined, size: 18),
            label: const Text('Taslak Olarak Kaydet'),
            style: FilledButton.styleFrom(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _exportPdf,
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('PDF Cikart'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _exportExcel,
                icon: const Icon(Icons.grid_on_rounded),
                label: const Text('Excel Cikart'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _exportMaterialRequestPdf,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Istek PDF'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _exportMaterialRequestExcel,
                icon: const Icon(Icons.list_alt_rounded),
                label: const Text('Istek Excel'),
              ),
            ),
          ],
        ),
      ],
    );

    final scrollableContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Donusum ve Cikti',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 18),
        Text(
          _visibleQuoteCode,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF5B6F7F),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          key: ValueKey(_selectedDisplayUnit),
          initialValue: _selectedDisplayUnit,
          decoration: const InputDecoration(labelText: 'Teklifi Cevir'),
          items: _displayUnits
              .map(
                (unit) =>
                    DropdownMenuItem(value: unit.code, child: Text(unit.label)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedDisplayUnit = value);
            }
          },
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF17304C), Color(0xFF274D67)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Genel Toplam',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatTotalForDisplay(convertedTotal, _selectedDisplayUnit),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                selectedRate == null
                    ? 'TL bazli fiyatlandirma aktif'
                    : '${selectedRate.label} bazli fiyatlandirma aktif',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        if (_legacyPriceRepairApplied) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3D08A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_fix_high_rounded,
                  size: 18,
                  color: Color(0xFF8A5A00),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Eski kur carpani hatasi algilandi; fiyatlar duzenleme icin onarildi.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6F4700),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_hiddenSubtotalTl > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD6C8EC)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.visibility_off_rounded,
                  size: 16,
                  color: Color(0xFF4A2C80),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Gizli yukleme (PDF\'e yansimaz)',
                    style: TextStyle(
                      color: Color(0xFF4A2C80),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _money.format(_hiddenSubtotalTl),
                  style: const TextStyle(
                    color: Color(0xFF4A2C80),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        _buildPaymentMethodPicker(),
        const SizedBox(height: 12),
        _buildHidePricesToggle(),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: expandActions
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      primary: false,
                      child: scrollableContent,
                    ),
                  ),
                  const SizedBox(height: 18),
                  actionButtons,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  scrollableContent,
                  const SizedBox(height: 18),
                  actionButtons,
                ],
              ),
      ),
    );
  }

  Widget _buildPaymentMethodPicker() {
    const ink = Color(0xFF17304C);
    const slate = Color(0xFF5B6F7F);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 18, color: ink),
              const SizedBox(width: 8),
              Text(
                'Odeme Yontemi',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'PDF\'te "Odeme" satirinda goruntulenir.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: slate,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<QuotePaymentMethod>(
            segments: const [
              ButtonSegment(
                value: QuotePaymentMethod.cash,
                label: Text('Nakit'),
                icon: Icon(Icons.payments_rounded, size: 16),
              ),
              ButtonSegment(
                value: QuotePaymentMethod.creditCard,
                label: Text('Kart'),
                icon: Icon(Icons.credit_card_rounded, size: 16),
              ),
              ButtonSegment(
                value: QuotePaymentMethod.installment,
                label: Text('Vadeli'),
                icon: Icon(Icons.event_rounded, size: 16),
              ),
            ],
            selected: {_paymentMethod},
            onSelectionChanged: (selected) {
              if (selected.isEmpty) return;
              setState(() => _paymentMethod = selected.first);
            },
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: const Color(0xFFF1F4F8),
              selectedBackgroundColor: ink,
              selectedForegroundColor: Colors.white,
              foregroundColor: ink,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topLeft,
            child: _paymentMethod == QuotePaymentMethod.installment
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextFormField(
                      controller: _paymentTermDaysController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Vade Gunu',
                        suffixText: 'gun',
                        isDense: true,
                      ),
                      validator: (value) {
                        if (_paymentMethod != QuotePaymentMethod.installment) {
                          return null;
                        }
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) return null;
                        final parsed = int.tryParse(trimmed);
                        if (parsed == null || parsed < 0 || parsed > 365) {
                          return '0-365 arasi bir deger girin';
                        }
                        return null;
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildHidePricesToggle() {
    const ink = Color(0xFF17304C);
    const slate = Color(0xFF5B6F7F);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _hidePrices = !_hidePrices),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _hidePrices ? const Color(0xFFFFF6E6) : Colors.white,
          border: Border.all(
            color: _hidePrices
                ? const Color(0xFFE3B86C)
                : const Color(0xFFD7DEE6),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _hidePrices
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 20,
              color: _hidePrices ? const Color(0xFFB8843C) : slate,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fiyatlari Gizle',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _hidePrices
                        ? 'PDF sadece malzeme listesi: aciklama, birim, miktar.'
                        : 'Kapali: tum fiyat ve toplam sutunlari gosterilir.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: slate,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: _hidePrices,
              onChanged: (value) => setState(() => _hidePrices = value),
            ),
          ],
        ),
      ),
    );
  }

  String? _numberValidator(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) {
      return 'Gecerli bir sayi girin';
    }
    return null;
  }

  String? _discountValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed < -100 || parsed > 100) {
      return '-100 ile 100 arasi girin';
    }
    return null;
  }

  String? _requiredTextValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Zorunlu';
    }
    return null;
  }
}

class _HiddenCostDraft {
  _HiddenCostDraft({
    required this.id,
    required this.name,
    this.note = '',
    List<HiddenCostParameter> parameters = const [],
  }) : parameters = List.of(parameters);

  final String id;
  String name;
  String note;
  List<HiddenCostParameter> parameters;

  double get totalTl =>
      parameters.fold(0, (sum, parameter) => sum + parameter.totalTl);
}

class _HiddenCostPreset {
  const _HiddenCostPreset({
    required this.key,
    required this.label,
    required this.defaultParameters,
  });

  final String key;
  final String label;
  final List<HiddenCostParameter> defaultParameters;
}

const List<_HiddenCostPreset> _hiddenCostPresets = [
  _HiddenCostPreset(
    key: 'devreye_alma',
    label: 'Devreye Alma',
    defaultParameters: [
      HiddenCostParameter(label: 'Pano sayisi', quantity: 1, unitPriceTl: 2500),
      HiddenCostParameter(
        label: 'Inverter sayisi',
        quantity: 1,
        unitPriceTl: 1500,
      ),
      HiddenCostParameter(
        label: 'Inverter toplam kW',
        quantity: 1,
        unitPriceTl: 50,
      ),
      HiddenCostParameter(
        label: 'Saha gunu (mobilizasyon)',
        quantity: 1,
        unitPriceTl: 3500,
      ),
    ],
  ),
  _HiddenCostPreset(
    key: 'egitim',
    label: 'Operator Egitimi',
    defaultParameters: [
      HiddenCostParameter(label: 'Egitim gunu', quantity: 1, unitPriceTl: 4000),
      HiddenCostParameter(label: 'Katilimci', quantity: 1, unitPriceTl: 250),
    ],
  ),
  _HiddenCostPreset(
    key: 'nakliye',
    label: 'Nakliye',
    defaultParameters: [
      HiddenCostParameter(label: 'Mesafe (km)', quantity: 1, unitPriceTl: 35),
      HiddenCostParameter(label: 'Arac ucreti', quantity: 1, unitPriceTl: 1500),
    ],
  ),
  _HiddenCostPreset(
    key: 'muhendislik',
    label: 'Muhendislik / Tasarim',
    defaultParameters: [
      HiddenCostParameter(
        label: 'Muhendislik adam-gunu',
        quantity: 1,
        unitPriceTl: 6000,
      ),
    ],
  ),
  _HiddenCostPreset(
    key: 'custom',
    label: 'Ozel / Serbest',
    defaultParameters: [
      HiddenCostParameter(label: '', quantity: 1, unitPriceTl: 0),
    ],
  ),
];

class _LineDraft {
  _LineDraft({
    required this.productId,
    required this.priceCurrencyCode,
    required String description,
    required String unit,
    required String quantity,
    required String unitPriceTl,
    required String discount,
    this.sectionId = '',
  }) : descriptionController = TextEditingController(text: description),
       unitController = TextEditingController(text: unit),
       quantityController = TextEditingController(text: quantity),
       unitPriceController = TextEditingController(text: unitPriceTl),
       discountController = TextEditingController(text: discount);

  final String? productId;
  final String priceCurrencyCode;
  final TextEditingController descriptionController;
  final TextEditingController unitController;
  final TextEditingController quantityController;
  final TextEditingController unitPriceController;
  final TextEditingController discountController;

  /// Kalemin baglandigi kategori kimligi. Bos ise "Kategorisiz" kovasinda.
  String sectionId;

  void dispose() {
    descriptionController.dispose();
    unitController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    discountController.dispose();
  }
}

/// Editor state icinde kategori (QuoteSection) temsilcisi. Isim alanini
/// serbestce degistirebildigimiz icin mutable birtaslaktir.
class _SectionDraft {
  _SectionDraft({required this.id, required this.name});

  final String id;
  String name;
  bool bulkDiscountEnabled = false;
  final TextEditingController bulkDiscountController = TextEditingController(
    text: '0',
  );

  void dispose() {
    bulkDiscountController.dispose();
  }
}

/// Editor icindeki render akisinda bir kategori grubunu temsil eder.
/// `draft == null` ise "Kategorisiz" kovasidir.
class _SectionGroup {
  const _SectionGroup({required this.draft, required this.items});

  final _SectionDraft? draft;
  final List<_LineDraft> items;
}

/// Kalem satirinin kategori tasima menusunde gorunen bir hedef. `id == ''`
/// ise "Kategorisiz" kovasi anlamina gelir.
class _SectionMoveTarget {
  const _SectionMoveTarget({required this.id, required this.label});

  final String id;
  final String label;
}

/// Yeni kategori ekleme / yeniden adlandirma dialog'u. Kendi
/// `TextEditingController`'ini yoneten StatefulWidget; bu sayede
/// controller'in omru dialog widget'inin omruyle esitlenir ve
/// "used after being disposed" uyarilarinin onune gecilir.
class _SectionNameDialog extends StatefulWidget {
  const _SectionNameDialog({
    required this.title,
    required this.initial,
    required this.confirmLabel,
  });

  final String title;
  final String initial;
  final String confirmLabel;

  @override
  State<_SectionNameDialog> createState() => _SectionNameDialogState();
}

class _SectionNameDialogState extends State<_SectionNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Kategori adi',
          hintText: 'Ornek: DDC Kontrolleri',
        ),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Vazgec'),
        ),
        FilledButton(onPressed: _confirm, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

class _DisplayUnitOption {
  const _DisplayUnitOption({required this.code, required this.label});

  final String code;
  final String label;
}

class _QuoteCodePlate extends StatelessWidget {
  const _QuoteCodePlate({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFFF5F8FB),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Teklif Kodu',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF5B6F7F),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            code,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF17304C),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogLabel extends StatelessWidget {
  const _CatalogLabel(this.label, {this.alignEnd = false});

  final String label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: const Color(0xFF667887),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.product,
    required this.selected,
    required this.onAdd,
  });

  final Product product;
  final bool selected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.84),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 136,
            child: Text(
              product.code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF17304C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.brand} - ${product.model} - ${product.category}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5B6F7F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 108,
            child: Text(
              product.formattedStock,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: product.isLowStock
                    ? const Color(0xFF9D5C1D)
                    : const Color(0xFF17304C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 132,
            child: Text(
              product.formattedSalePrice,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF17304C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 106,
            child: OutlinedButton(
              key: ValueKey('catalog-add-${product.id}'),
              onPressed: onAdd,
              child: Text(selected ? 'Arttir' : 'Kaleme Al'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactCatalogItem extends StatelessWidget {
  const _CompactCatalogItem({
    required this.product,
    required this.selected,
    required this.onAdd,
  });

  final Product product;
  final bool selected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.84),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                key: ValueKey('catalog-add-${product.id}'),
                onPressed: onAdd,
                child: Text(selected ? 'Arttir' : 'Kaleme Al'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${product.code} - ${product.brand} ${product.model}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF5B6F7F),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniInfoPill(label: product.category),
              _MiniInfoPill(label: product.formattedStock),
              _MiniInfoPill(label: product.formattedSalePrice),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  const _MiniInfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0xFFF5F8FB),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _QuoteLineEditorRow extends StatelessWidget {
  const _QuoteLineEditorRow({
    required this.rowNumber,
    required this.draft,
    required this.money,
    required this.onChanged,
    required this.onRemove,
    required this.lineTotal,
    required this.displayUnit,
    required this.useDesktopLayout,
    required this.discountLocked,
    required this.numberValidator,
    required this.discountValidator,
    required this.requiredTextValidator,
    this.product,
    this.availableSections = const [],
    this.onMoveToSection,
  });

  final int rowNumber;
  final Product? product;
  final _LineDraft draft;
  final NumberFormat money;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final double lineTotal;
  final String displayUnit;
  final bool useDesktopLayout;
  final bool discountLocked;
  final String? Function(String?) numberValidator;
  final String? Function(String?) discountValidator;
  final String? Function(String?) requiredTextValidator;

  /// Kalemin tasinabilecegi diger kategoriler (suanki kategori haric).
  final List<_SectionMoveTarget> availableSections;

  /// Seciminde `target.id` ile cagrilir; bos string "Kategorisiz" demek.
  final ValueChanged<String>? onMoveToSection;

  String get _priceCurrencyLabel => switch (displayUnit) {
    'USDTRY' => 'USD',
    'EURTRY' => 'EUR',
    _ => 'TL',
  };

  Widget _buildMoveMenu(Color color) {
    if (availableSections.isEmpty || onMoveToSection == null) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<String>(
      tooltip: 'Kategoriye tasi',
      icon: Icon(Icons.drive_file_move_outline, color: color, size: 20),
      onSelected: onMoveToSection,
      itemBuilder: (_) => [
        for (final target in availableSections)
          PopupMenuItem<String>(
            value: target.id,
            child: Row(
              children: [
                Icon(
                  target.id.isEmpty
                      ? Icons.label_off_outlined
                      : Icons.folder_rounded,
                  size: 16,
                  color: const Color(0xFF5B6F7F),
                ),
                const SizedBox(width: 8),
                Text(target.label),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rowKey =
        draft.productId ?? draft.descriptionController.hashCode.toString();
    final productMeta = product == null
        ? 'Ozel kalem'
        : '${product!.code} - ${product!.brand} ${product!.model}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final showDesktopRow = useDesktopLayout && constraints.maxWidth >= 720;

        if (!showDesktopRow) {
          return Container(
            key: ValueKey('quote-line-$rowKey'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD7DEE6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: draft.descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Kalem Aciklamasi',
                          hintText: 'Ozel urun / hizmet adi',
                          isDense: true,
                        ),
                        validator: requiredTextValidator,
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    _buildMoveMenu(const Color(0xFF5B6F7F)),
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                Text(
                  productMeta,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5B6F7F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: draft.quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Miktar',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: numberValidator,
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: draft.unitController,
                        decoration: const InputDecoration(
                          labelText: 'Birim',
                          isDense: true,
                        ),
                        validator: requiredTextValidator,
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: draft.unitPriceController,
                        decoration: InputDecoration(
                          labelText: 'Birim Fiyat ($_priceCurrencyLabel)',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: numberValidator,
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: draft.discountController,
                        enabled: !discountLocked,
                        decoration: InputDecoration(
                          labelText: discountLocked
                              ? 'Toplu iskonto'
                              : 'Iskonto %',
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: discountValidator,
                        onChanged: (_) => onChanged(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Satir net: ${money.format(lineTotal)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF17304C),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          key: ValueKey('quote-line-$rowKey'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: rowNumber.isEven
                ? const Color(0xFFFAFBFC)
                : Colors.white.withValues(alpha: 0.96),
            border: Border.all(color: const Color(0xFFD7DEE6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  rowNumber.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF5B6F7F),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const _SheetDivider(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: draft.descriptionController,
                      decoration: const InputDecoration(
                        hintText: 'Ozel urun / hizmet adi',
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                      ),
                      validator: requiredTextValidator,
                      onChanged: (_) => onChanged(),
                    ),
                    if (product != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                        child: Text(
                          productMeta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF5B6F7F),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              const _SheetDivider(),
              SizedBox(
                width: 88,
                child: TextFormField(
                  controller: draft.unitController,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  validator: requiredTextValidator,
                  onChanged: (_) => onChanged(),
                ),
              ),
              const _SheetDivider(),
              SizedBox(
                width: 96,
                child: TextFormField(
                  controller: draft.quantityController,
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: numberValidator,
                  onChanged: (_) => onChanged(),
                ),
              ),
              const _SheetDivider(),
              SizedBox(
                width: 128,
                child: TextFormField(
                  controller: draft.unitPriceController,
                  textAlign: TextAlign.end,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: numberValidator,
                  onChanged: (_) => onChanged(),
                ),
              ),
              const _SheetDivider(),
              SizedBox(
                width: 104,
                child: TextFormField(
                  controller: draft.discountController,
                  enabled: !discountLocked,
                  textAlign: TextAlign.end,
                  decoration: InputDecoration(
                    hintText: discountLocked ? 'Toplu' : null,
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: discountValidator,
                  onChanged: (_) => onChanged(),
                ),
              ),
              const _SheetDivider(),
              SizedBox(
                width: 132,
                child: Text(
                  money.format(lineTotal),
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF17304C),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const _SheetDivider(),
              _buildMoveMenu(const Color(0xFF5B6F7F)),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuoteLineSheetHeader extends StatelessWidget {
  const _QuoteLineSheetHeader({required this.priceCurrencyLabel});

  final String priceCurrencyLabel;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: const Color(0xFF17304C),
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
    );

    Widget cell(String text, double width, {TextAlign align = TextAlign.left}) {
      return SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(text, textAlign: align, style: style),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) return const SizedBox.shrink();

        return Container(
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEF5),
            border: Border.all(color: const Color(0xFFC6D0DA)),
          ),
          child: Row(
            children: [
              cell('#', 38, align: TextAlign.center),
              const _SheetDivider(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Kalem aciklamasi', style: style),
                ),
              ),
              const _SheetDivider(),
              cell('Birim', 88),
              const _SheetDivider(),
              cell('Miktar', 96, align: TextAlign.right),
              const _SheetDivider(),
              cell(
                'Birim fiyat ($priceCurrencyLabel)',
                128,
                align: TextAlign.right,
              ),
              const _SheetDivider(),
              cell('Isk. %', 104, align: TextAlign.right),
              const _SheetDivider(),
              cell('Satir net', 132, align: TextAlign.right),
              const _SheetDivider(),
              const SizedBox(width: 96),
            ],
          ),
        );
      },
    );
  }
}

class _SheetDivider extends StatelessWidget {
  const _SheetDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: const Color(0xFFD7DEE6));
  }
}

class _HiddenCostRow extends StatelessWidget {
  const _HiddenCostRow({
    required this.draft,
    required this.money,
    required this.onEdit,
    required this.onRemove,
  });

  final _HiddenCostDraft draft;
  final NumberFormat money;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: const Color(0xFFD6C8EC)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  draft.name.isEmpty ? 'Ek Yukleme' : draft.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF4A2C80),
                  ),
                ),
              ),
              Text(
                money.format(draft.totalTl),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF4A2C80),
                ),
              ),
              IconButton(
                tooltip: 'Duzenle',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 18),
              ),
              IconButton(
                tooltip: 'Sil',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ],
          ),
          if (draft.parameters.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final p in draft.parameters)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: const Color(0xFFF3EEFB),
                      border: Border.all(color: const Color(0xFFD6C8EC)),
                    ),
                    child: Text(
                      '${p.label.isEmpty ? "Parametre" : p.label}: '
                      '${_fmt(p.quantity)} x ${money.format(p.unitPriceTl)} '
                      '= ${money.format(p.totalTl)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF4A2C80),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (draft.note.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              draft.note.trim(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF5B4684),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}

class _HiddenCostDialog extends StatefulWidget {
  const _HiddenCostDialog({
    required this.money,
    required this.newIdBuilder,
    this.editing,
  });

  final NumberFormat money;
  final _HiddenCostDraft? editing;
  final String Function() newIdBuilder;

  @override
  State<_HiddenCostDialog> createState() => _HiddenCostDialogState();
}

class _HiddenCostDialogState extends State<_HiddenCostDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late String _presetKey;
  final List<_ParameterFieldDraft> _fields = [];

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _nameController = TextEditingController(text: editing?.name ?? '');
    _noteController = TextEditingController(text: editing?.note ?? '');

    if (editing == null) {
      _presetKey = _hiddenCostPresets.first.key;
      _applyPreset(_presetKey);
      _nameController.text = _hiddenCostPresets.first.label;
    } else {
      _presetKey = 'custom';
      for (final p in editing.parameters) {
        _fields.add(_ParameterFieldDraft.fromParameter(p));
      }
      if (_fields.isEmpty) {
        _fields.add(_ParameterFieldDraft.empty());
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  void _applyPreset(String key) {
    final preset = _hiddenCostPresets.firstWhere(
      (p) => p.key == key,
      orElse: () => _hiddenCostPresets.first,
    );
    for (final f in _fields) {
      f.dispose();
    }
    _fields
      ..clear()
      ..addAll(
        preset.defaultParameters.map(_ParameterFieldDraft.fromParameter),
      );
    if (_fields.isEmpty) {
      _fields.add(_ParameterFieldDraft.empty());
    }
  }

  double get _total =>
      _fields.fold(0, (sum, field) => sum + field.currentTotal);

  void _addField() {
    setState(() => _fields.add(_ParameterFieldDraft.empty()));
  }

  void _removeField(_ParameterFieldDraft field) {
    setState(() {
      _fields.remove(field);
      field.dispose();
      if (_fields.isEmpty) {
        _fields.add(_ParameterFieldDraft.empty());
      }
    });
  }

  void _save() {
    final parameters = <HiddenCostParameter>[];
    for (final field in _fields) {
      final label = field.labelController.text.trim();
      final quantity = double.tryParse(field.qtyController.text.trim()) ?? 0;
      final unit = double.tryParse(field.unitController.text.trim()) ?? 0;
      if (quantity <= 0 || unit <= 0) continue;
      parameters.add(
        HiddenCostParameter(
          label: label,
          quantity: quantity,
          unitPriceTl: unit,
        ),
      );
    }

    if (parameters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'En az bir parametreye gecerli miktar ve birim fiyat girin.',
          ),
        ),
      );
      return;
    }

    final result = _HiddenCostDraft(
      id: widget.editing?.id ?? widget.newIdBuilder(),
      name: _nameController.text.trim().isEmpty
          ? 'Ek Yukleme'
          : _nameController.text.trim(),
      note: _noteController.text.trim(),
      parameters: parameters,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.visibility_off_rounded,
                    color: Color(0xFF4A2C80),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.editing == null
                          ? 'Gizli Yukleme Ekle'
                          : 'Gizli Yuklemeyi Duzenle',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Bu kalem PDF ve Excel\'de gorunmez. Hesaplanan toplam, gorunur '
                'kalemlerin tutarlarina orantili olarak yedirilir.',
                style: TextStyle(color: Color(0xFF5B6F7F)),
              ),
              const SizedBox(height: 16),
              if (widget.editing == null)
                DropdownButtonFormField<String>(
                  initialValue: _presetKey,
                  decoration: const InputDecoration(labelText: 'Hazir sablon'),
                  items: _hiddenCostPresets
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.key,
                          child: Text(p.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _presetKey = value;
                      _applyPreset(value);
                      final preset = _hiddenCostPresets.firstWhere(
                        (p) => p.key == value,
                      );
                      if (preset.key != 'custom') {
                        _nameController.text = preset.label;
                      }
                    });
                  },
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Yukleme adi',
                  hintText: 'Devreye Alma, Egitim, Nakliye...',
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Parametreler',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ornek: Pano sayisi x TL/pano, Inverter kW x TL/kW gibi.',
                style: TextStyle(color: Color(0xFF5B6F7F)),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _fields.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final field = _fields[index];
                    return _ParameterFieldEditor(
                      field: field,
                      money: widget.money,
                      onChanged: () => setState(() {}),
                      onRemove: () => _removeField(field),
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addField,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Parametre ekle'),
                ),
              ),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Ic not (opsiyonel)',
                  hintText:
                      'Sadece ekipte gorunur; PDF\'e yansimaz, arsivde saklanir.',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A2C80),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Bu yuklemenin toplam tutari',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      widget.money.format(_total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('İptal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(widget.editing == null ? 'Ekle' : 'Guncelle'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParameterFieldDraft {
  _ParameterFieldDraft({
    required this.labelController,
    required this.qtyController,
    required this.unitController,
  });

  factory _ParameterFieldDraft.empty() => _ParameterFieldDraft(
    labelController: TextEditingController(),
    qtyController: TextEditingController(text: '1'),
    unitController: TextEditingController(text: '0'),
  );

  factory _ParameterFieldDraft.fromParameter(HiddenCostParameter p) {
    final q = p.quantity;
    final qText = q == q.truncateToDouble()
        ? q.toStringAsFixed(0)
        : q.toStringAsFixed(2);
    return _ParameterFieldDraft(
      labelController: TextEditingController(text: p.label),
      qtyController: TextEditingController(text: qText),
      unitController: TextEditingController(
        text: p.unitPriceTl.toStringAsFixed(2),
      ),
    );
  }

  final TextEditingController labelController;
  final TextEditingController qtyController;
  final TextEditingController unitController;

  double get currentTotal {
    final q = double.tryParse(qtyController.text.trim()) ?? 0;
    final u = double.tryParse(unitController.text.trim()) ?? 0;
    return q * u;
  }

  void dispose() {
    labelController.dispose();
    qtyController.dispose();
    unitController.dispose();
  }
}

class _ParameterFieldEditor extends StatelessWidget {
  const _ParameterFieldEditor({
    required this.field,
    required this.money,
    required this.onChanged,
    required this.onRemove,
  });

  final _ParameterFieldDraft field;
  final NumberFormat money;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final total = field.currentTotal;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF5F3FB),
        border: Border.all(color: const Color(0xFFD6C8EC)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: field.labelController,
                  decoration: const InputDecoration(
                    labelText: 'Parametre',
                    hintText: 'Pano sayisi',
                    isDense: true,
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: field.qtyController,
                  decoration: const InputDecoration(
                    labelText: 'Miktar',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: field.unitController,
                  decoration: const InputDecoration(
                    labelText: 'Birim Fiyat (TL)',
                    isDense: true,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'Parametreyi kaldir',
              ),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Ara toplam: ${money.format(total)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF4A2C80),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
