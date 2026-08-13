import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/cari_account.dart';
import '../models/market_rate.dart';
import '../models/product.dart';
import '../models/quote.dart';
import '../services/agreed_quotes_pdf_service.dart';
import '../services/cari_repository.dart';
import '../services/market_rate_service.dart';
import '../services/own_company_repository.dart';
import '../services/price_adjustment_rule_repository.dart';
import '../services/product_repository.dart';
import '../services/quote_repository.dart';
import '../services/user_profile_repository.dart';
import '../widgets/workspace_background.dart';
import 'quote_editor_page.dart';
import 'quote_review_page.dart';

const _kInk = Color(0xFF17304C);
const _kSlate = Color(0xFF5B6F7F);

/// Cari karti ve bu cariye bagli son teklifler (RLS ile gorunen kayitlar).
class CariDetailPage extends StatefulWidget {
  const CariDetailPage({
    super.key,
    required this.cari,
    required this.quoteRepository,
    required this.productRepository,
    required this.marketRateService,
    required this.userProfileRepository,
    required this.cariRepository,
    required this.ownCompanyRepository,
    required this.priceAdjustmentRuleRepository,
    required this.isManager,
    this.onEdit,
  });

  final CariAccount cari;
  final QuoteRepository quoteRepository;
  final ProductRepository productRepository;
  final MarketRateService marketRateService;
  final UserProfileRepository userProfileRepository;
  final CariRepository cariRepository;
  final OwnCompanyRepository ownCompanyRepository;
  final PriceAdjustmentRuleRepository priceAdjustmentRuleRepository;
  final bool isManager;
  final Future<CariAccount?> Function(CariAccount current)? onEdit;

  @override
  State<CariDetailPage> createState() => _CariDetailPageState();
}

class _CariDetailPageState extends State<CariDetailPage> {
  late CariAccount _cari;
  List<Quote> _quotes = const [];
  List<Product> _products = const [];
  List<MarketRate> _rates = const [];
  bool _loading = true;
  _CariQuoteFilter _filter = _CariQuoteFilter.all;

  @override
  void initState() {
    super.initState();
    _cari = widget.cari;
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final all = await widget.quoteRepository.fetchQuotes();
    final products = await widget.productRepository.fetchProducts();
    final rates = await widget.marketRateService.fetchRates();
    if (!mounted) return;
    final id = _cari.id;
    final forCari = all.where((q) => q.cariId == id).toList(growable: false)
      ..sort((a, b) {
        final aDate = a.acceptedAt ?? a.approvedAt ?? a.createdAt;
        final bDate = b.acceptedAt ?? b.approvedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
    setState(() {
      _quotes = forCari;
      _products = products;
      _rates = rates;
      _loading = false;
    });
  }

  /// E-posta ile teklif gonder (url_launcher ile sistem e-posta istemcisi acar).
  /// Gonderim sonrasi email_sent_at ve email_sent_to guncellenir.
  /// E-posta ile teklif gonder dialogu (Alici yetkili & Gonderen hesap secimi)
  Future<void> _sendQuoteEmail(Quote q, [String? initialEmail]) async {
    // Cari yetkili e-postalari
    final availableEmails = <String>{};
    if (initialEmail != null && initialEmail.trim().isNotEmpty) {
      availableEmails.add(initialEmail.trim());
    }
    for (final c in _cari.contacts) {
      if (c.email.trim().isNotEmpty) availableEmails.add(c.email.trim());
    }
    if (_cari.email.trim().isNotEmpty) availableEmails.add(_cari.email.trim());
    if (q.documentProfile.customerEmail.trim().isNotEmpty) {
      availableEmails.add(q.documentProfile.customerEmail.trim());
    }

    final emailList = availableEmails.toList();
    String selectedToEmail = emailList.isNotEmpty ? emailList.first : '';
    final customEmailCtrl = TextEditingController();

    final companyEmail = q.documentProfile.companyEmail.trim();
    final preparedByEmail = q.documentProfile.preparedByEmail.trim();
    String selectedSenderAccount = 'default'; // 'default', 'preparedBy', 'company', 'custom'
    final customSenderCtrl = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.mark_email_read_rounded, color: Color(0xFF2B82C9)),
              const SizedBox(width: 8),
              Text('Teklif E-postası Gönder (${q.code})'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ALICI E-POSTA ADRESİ (MÜŞTERİ)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF5B6F7F)),
                ),
                const SizedBox(height: 6),
                if (emailList.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: emailList.map((e) {
                      final isSelected = selectedToEmail == e;
                      return ChoiceChip(
                        label: Text(e, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF2B82C9).withValues(alpha: 0.18),
                        onSelected: (val) {
                          if (val) setDlgState(() => selectedToEmail = e);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: customEmailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Veya Farklı E-posta Yazın',
                    hintText: 'ornek@musteri.com',
                    prefixIcon: Icon(Icons.alternate_email_rounded, size: 18),
                  ),
                  onChanged: (val) {
                    if (val.trim().isNotEmpty) {
                      setDlgState(() => selectedToEmail = val.trim());
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'BİLGİ (CC) / OTOMATİK ARŞİV HESABI',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF5B6F7F)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F2FB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFB8D0ED)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 16, color: Color(0xFF2B82C9)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'teklif@uzalteknik.com (Otomatik kopyalanır)',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF17304C)),
                        ),
                      ),
                      Icon(Icons.check_rounded, size: 16, color: Color(0xFF29956F)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'GÖNDEREN E-POSTA YÖNTEMİ / HESABI',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF5B6F7F)),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD7DEE6)),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => setDlgState(() => selectedSenderAccount = 'default'),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                selectedSenderAccount == 'default'
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 18,
                                color: selectedSenderAccount == 'default'
                                    ? const Color(0xFF29956F)
                                    : const Color(0xFF5B6F7F),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Varsayılan İstemci (Outlook/Mail App)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF17304C))),
                                    Text('Cihazınızda açık olan varsayılan e-posta hesabınız kullanılır.', style: TextStyle(fontSize: 10, color: Color(0xFF5B6F7F))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (preparedByEmail.isNotEmpty) ...[
                        const Divider(height: 1),
                        InkWell(
                          onTap: () => setDlgState(() => selectedSenderAccount = 'preparedBy'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  selectedSenderAccount == 'preparedBy'
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  size: 18,
                                  color: selectedSenderAccount == 'preparedBy'
                                      ? const Color(0xFF2B82C9)
                                      : const Color(0xFF5B6F7F),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Hazırlayan Personel Hesabı', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF17304C))),
                                      Text(preparedByEmail, style: const TextStyle(fontSize: 10.5, color: Color(0xFF9D5C1D), fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (companyEmail.isNotEmpty) ...[
                        const Divider(height: 1),
                        InkWell(
                          onTap: () => setDlgState(() => selectedSenderAccount = 'company'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  selectedSenderAccount == 'company'
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  size: 18,
                                  color: selectedSenderAccount == 'company'
                                      ? const Color(0xFF2B82C9)
                                      : const Color(0xFF5B6F7F),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Kurumsal Şirket Hesabı', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF17304C))),
                                      Text(companyEmail, style: const TextStyle(fontSize: 10.5, color: Color(0xFF2B82C9), fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const Divider(height: 1),
                      InkWell(
                        onTap: () => setDlgState(() => selectedSenderAccount = 'custom'),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    selectedSenderAccount == 'custom'
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    size: 18,
                                    color: selectedSenderAccount == 'custom'
                                        ? const Color(0xFF8B5CC7)
                                        : const Color(0xFF5B6F7F),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('➕ Farklı Gönderen E-posta Adresi Ekle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF8B5CC7))),
                                ],
                              ),
                              if (selectedSenderAccount == 'custom') ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: customSenderCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Gönderen E-posta Adresiniz',
                                    hintText: 'ad.soyad@firma.com',
                                    prefixIcon: Icon(Icons.mark_email_unread_rounded, size: 16),
                                    isDense: true,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Vazgeç'),
            ),
            FilledButton.icon(
              onPressed: () {
                final target = customEmailCtrl.text.trim().isNotEmpty
                    ? customEmailCtrl.text.trim()
                    : selectedToEmail;
                if (target.isEmpty) return;

                String senderAddr = '';
                if (selectedSenderAccount == 'preparedBy') senderAddr = preparedByEmail;
                if (selectedSenderAccount == 'company') senderAddr = companyEmail;
                if (selectedSenderAccount == 'custom') senderAddr = customSenderCtrl.text.trim();

                Navigator.pop(ctx, {
                  'toEmail': target,
                  'senderEmail': senderAddr,
                });
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('E-posta Gönder'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2B82C9)),
            ),
          ],
        ),
      ),
    );

    if (result == null || !result.containsKey('toEmail')) return;
    final finalToEmail = result['toEmail']!;
    final selectedSender = result['senderEmail'] ?? '';

    // Standart Dart Uri yapisi - tum bosluk ve turkce karakterleri otomatik ve hatasiz encode eder
    final uri = Uri(
      scheme: 'mailto',
      path: finalToEmail,
      queryParameters: {
        'cc': 'teklif@uzalteknik.com',
        'subject': 'Teklif: ${q.code}',
        'body': 'Sayin ${_cari.contactName.trim().isNotEmpty ? _cari.contactName.trim() : "Yetkili"},\n\n'
            '${q.code} kodlu teklifimizi incelemenize sunuyoruz.\n\n'
            '${q.publicToken.isNotEmpty ? "Cevrimici goruntuleme: ${q.publicShareSlug}" : ""}\n\n'
            'Bilgilerinize saygilarimizla.',
      },
    );

    try {
      bool launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = await launchUrl(uri);
      }

      if (launched) {
        await widget.quoteRepository.markEmailSent(q.id, finalToEmail);
        await _reload();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'E-posta istemcisi açıldı.${selectedSender.isNotEmpty ? " (Gönderen: $selectedSender)" : ""} Alıcı: $finalToEmail',
              ),
              backgroundColor: const Color(0xFF29956F),
            ),
          );
        }
      } else {
        throw Exception('Launch failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('E-posta istemcisi açılamadı ($finalToEmail). Lütfen cihazınızda aktif mail istemcisi tanımlı olduğundan emin olun.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _updateQuoteResponse(
    Quote q,
    CustomerResponse response,
  ) async {
    await widget.quoteRepository.updateCustomerResponse(q.id, response);
    await _reload();
  }

  Future<void> _openQuote(Quote q) async {
    await Navigator.of(context).push<Quote>(
      MaterialPageRoute(
        builder: (context) => QuoteReviewPage(
          quote: q,
          quoteRepository: widget.quoteRepository,
          productRepository: widget.productRepository,
          initialRates: _rates,
          availableProducts: _products,
          userProfileRepository: widget.userProfileRepository,
          cariRepository: widget.cariRepository,
          ownCompanyRepository: widget.ownCompanyRepository,
          priceAdjustmentRuleRepository: widget.priceAdjustmentRuleRepository,
          isManager: widget.isManager,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _openNewQuote() async {
    await Navigator.of(context).push<Quote>(
      MaterialPageRoute(
        builder: (context) => QuoteEditorPage(
          quoteRepository: widget.quoteRepository,
          productRepository: widget.productRepository,
          initialRates: _rates,
          availableProducts: _products,
          initialCariId: _cari.id,
          userProfileRepository: widget.userProfileRepository,
          cariRepository: widget.cariRepository,
          ownCompanyRepository: widget.ownCompanyRepository,
          priceAdjustmentRuleRepository: widget.priceAdjustmentRuleRepository,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _editCari() async {
    final edit = widget.onEdit;
    if (edit == null) return;
    final updated = await edit(_cari);
    if (!mounted || updated == null) return;
    setState(() => _cari = updated);
    await _reload();
  }

  List<Quote> get _filteredQuotes {
    switch (_filter) {
      case _CariQuoteFilter.all:
        return _quotes;
      case _CariQuoteFilter.approved:
        return _quotes
            .where((q) => q.status == QuoteStatus.approved)
            .toList(growable: false);
      case _CariQuoteFilter.agreed:
        return _quotes
            .where((q) => q.acceptedTotalTl != null)
            .toList(growable: false);
    }
  }

  Future<void> _exportAgreedListPdf() async {
    final agreed = _quotes
        .where((q) => q.acceptedTotalTl != null)
        .toList(growable: false);
    if (agreed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anlaşılan teklif bulunmuyor.')),
      );
      return;
    }
    try {
      final path = await const AgreedQuotesPdfService().exportForCari(
        cari: _cari,
        quotes: agreed,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Liste PDF kaydedildi: $path')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Liste PDF olusturulamadi: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _cari;
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Cari kartı',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              c.companyName.trim().isEmpty ? 'İsimsiz firma' : c.companyName,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Anlaşılan teklifler PDF listesi',
            onPressed: _loading ? null : _exportAgreedListPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded),
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
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsets.all(compact ? 10 : 16),
                  children: [
                    _buildCari360Header(context),
                    const SizedBox(height: 12),
                    _buildCariMetrics(context),
                    const SizedBox(height: 12),
                    _buildEmailActionPanel(context),
                    const SizedBox(height: 12),
                    _buildYetkililerCard(context),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0xFFD7DEE6)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Firma ve iletişim bilgileri',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: _kInk,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cari kodu: ${c.id}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: _kSlate,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const Divider(height: 22),
                            _cariRow(
                              context,
                              'Ana Yetkili',
                              [
                                c.contactName.trim(),
                                c.contactTitle.trim(),
                              ].where((e) => e.isNotEmpty).join(' · '),
                            ),
                            _cariRow(context, 'Telefon', c.phone),
                            _cariRow(context, 'E-posta', c.email),
                            _cariRow(
                              context,
                              'Vergi',
                              [
                                if (c.taxOffice.trim().isNotEmpty)
                                  c.taxOffice.trim(),
                                if (c.taxNumber.trim().isNotEmpty)
                                  c.taxNumber.trim(),
                              ].where((e) => e.isNotEmpty).join(' / '),
                            ),
                            _cariRow(context, 'Adres', c.address),
                            if (c.notes.trim().isNotEmpty)
                              _cariRow(context, 'Not', c.notes),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          'Satış ve teklif geçmişi',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: _kInk,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F4F8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_filteredQuotes.length} kayit',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _kSlate,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bu cariye bağlı teklifler. Anlaşılan toplam girildiyse listede o tutar esas alınır.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _kSlate,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Tum teklifler'),
                          selected: _filter == _CariQuoteFilter.all,
                          onSelected: (_) {
                            setState(() => _filter = _CariQuoteFilter.all);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Müşteriye gönderilen'),
                          selected: _filter == _CariQuoteFilter.approved,
                          onSelected: (_) {
                            setState(() => _filter = _CariQuoteFilter.approved);
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Anlaşılanlar'),
                          selected: _filter == _CariQuoteFilter.agreed,
                          onSelected: (_) {
                            setState(() => _filter = _CariQuoteFilter.agreed);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_filteredQuotes.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 28,
                            horizontal: 16,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 40,
                                color: _kSlate.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Bu cariye henüz bağlı aktif teklif bulunmuyor. '
                                  'Filtreyi degistirebilir veya teklifi bu cari ile iliskilendirebilirsiniz.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: _kSlate,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              color: const Color(0xFFF6F8FA),
                              child: const Row(
                                children: [
                                  Expanded(flex: 3, child: _Th('Teklif')),
                                  Expanded(flex: 2, child: _Th('Hazırlayan')),
                                  Expanded(flex: 2, child: _Th('Tarih')),
                                  Expanded(flex: 2, child: _Th('Durum')),
                                  Expanded(flex: 2, child: _Th('İletişim')),
                                  Expanded(
                                    flex: 2,
                                    child: _Th('Tutar', align: TextAlign.end),
                                  ),
                                ],
                              ),
                            ),
                            for (
                              var i = 0;
                              i < _filteredQuotes.length;
                              i++
                            ) ...[
                              if (i > 0) const Divider(height: 1),
                              _QuoteDataRow(
                                quote: _filteredQuotes[i],
                                cariContacts: _cari.contacts,
                                onTap: () => _openQuote(_filteredQuotes[i]),
                                onSendEmail: (email) => _sendQuoteEmail(_filteredQuotes[i], email),
                                onUpdateResponse: (r) => _updateQuoteResponse(_filteredQuotes[i], r),
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

  Widget _buildYetkililerCard(BuildContext context) {
    final contacts = _cari.contacts;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD7DEE6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Kayıtlı Yetkililer',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F4F8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${contacts.length} kişi',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _kSlate,
                        ),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditContactDialog(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Yetkili Ekle'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Bu cariye henüz kayıtlı yetkili eklenmedi. '
                  'Teklif oluştururken yazılan yetkililer buraya otomatik eklenecektir.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _kSlate,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < contacts.length; i++) ...[
                    if (i > 0) const Divider(height: 16),
                    _buildContactTile(context, contacts[i], i),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(
    BuildContext context,
    CariContact contact,
    int index,
  ) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: contact.isPrimary
              ? const Color(0xFFC98E4B).withValues(alpha: 0.18)
              : const Color(0xFFEBF0F5),
          child: Icon(
            contact.isPrimary
                ? Icons.star_rounded
                : Icons.person_outline_rounded,
            color: contact.isPrimary ? const Color(0xFFC98E4B) : _kSlate,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      contact.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: _kInk,
                      ),
                    ),
                  ),
                  if (contact.isPrimary) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC98E4B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Ana Yetkili',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFC98E4B),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (contact.title.isNotEmpty ||
                  contact.phone.isNotEmpty ||
                  contact.email.isNotEmpty)
                Text(
                  [
                    if (contact.title.isNotEmpty) contact.title,
                    if (contact.phone.isNotEmpty) contact.phone,
                    if (contact.email.isNotEmpty) contact.email,
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: _kSlate,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: contact.isPrimary ? 'Ana yetkili' : 'Ana yetkili yap',
          onPressed: contact.isPrimary ? null : () => _setPrimaryContact(index),
          icon: Icon(
            contact.isPrimary ? Icons.star_rounded : Icons.star_outline_rounded,
            color: contact.isPrimary ? const Color(0xFFC98E4B) : _kSlate,
            size: 20,
          ),
        ),
        IconButton(
          tooltip: 'Düzenle',
          onPressed: () =>
              _showAddEditContactDialog(existing: contact, index: index),
          icon: const Icon(Icons.edit_outlined, color: _kSlate, size: 20),
        ),
        IconButton(
          tooltip: 'Sil',
          onPressed: () => _deleteContact(index),
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
        ),
      ],
    );
  }

  Future<void> _setPrimaryContact(int index) async {
    final list = _cari.contacts
        .map((c) => c.copyWith(isPrimary: false))
        .toList();
    list[index] = list[index].copyWith(isPrimary: true);
    final updated = _cari.copyWith(
      contacts: list,
      contactName: list[index].name,
      contactTitle: list[index].title,
      phone: list[index].phone,
      email: list[index].email,
      updatedAt: DateTime.now().toUtc(),
    );
    setState(() => _cari = updated);
    await widget.cariRepository.save(updated);
  }

  Future<void> _deleteContact(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yetkiliyi Sil'),
        content: Text(
          '${_cari.contacts[index].name} kişisini silmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final list = List<CariContact>.from(_cari.contacts)..removeAt(index);
    if (list.isNotEmpty && !list.any((c) => c.isPrimary)) {
      list[0] = list[0].copyWith(isPrimary: true);
    }
    final primary = list.firstWhere(
      (c) => c.isPrimary,
      orElse: () => list.isNotEmpty ? list.first : const CariContact(name: ''),
    );
    final updated = _cari.copyWith(
      contacts: list,
      contactName: primary.name,
      contactTitle: primary.title,
      phone: primary.phone,
      email: primary.email,
      updatedAt: DateTime.now().toUtc(),
    );
    setState(() => _cari = updated);
    await widget.cariRepository.save(updated);
  }

  Future<void> _showAddEditContactDialog({
    CariContact? existing,
    int? index,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    bool isPrimary = existing?.isPrimary ?? (_cari.contacts.isEmpty);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Yeni Yetkili Ekle' : 'Yetkili Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Yetkili Adı Soyadı *',
                  hintText: 'Örn: Ahmet Yılmaz',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Unvanı',
                  hintText: 'Örn: Satın Alma Müdürü',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Telefon',
                  hintText: '05xx xxx xx xx',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'E-posta',
                  hintText: 'ornek@firma.com',
                ),
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setCheckState) => CheckboxListTile(
                  title: const Text('Ana Yetkili Yap'),
                  value: isPrimary,
                  onChanged: (val) =>
                      setCheckState(() => isPrimary = val ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (saved != true || nameCtrl.text.trim().isEmpty) return;

    final newContact = CariContact(
      name: nameCtrl.text.trim(),
      title: titleCtrl.text.trim(),
      phone: phoneCtrl.text.trim(),
      email: emailCtrl.text.trim(),
      isPrimary: isPrimary,
    );

    List<CariContact> list = List<CariContact>.from(_cari.contacts);
    if (index != null && index >= 0 && index < list.length) {
      list[index] = newContact;
    } else {
      list.add(newContact);
    }

    if (isPrimary) {
      list = list
          .map(
            (c) => c.name.toLowerCase() == newContact.name.toLowerCase()
                ? c.copyWith(isPrimary: true)
                : c.copyWith(isPrimary: false),
          )
          .toList();
    }

    final primary = list.firstWhere(
      (c) => c.isPrimary,
      orElse: () => list.first,
    );
    final updated = _cari.copyWith(
      contacts: list,
      contactName: primary.name,
      contactTitle: primary.title,
      phone: primary.phone,
      email: primary.email,
      updatedAt: DateTime.now().toUtc(),
    );

    setState(() => _cari = updated);
    await widget.cariRepository.save(updated);
  }

  Widget _buildCari360Header(BuildContext context) {
    final c = _cari;
    final compact = MediaQuery.sizeOf(context).width < 700;
    final companyName = c.companyName.trim().isEmpty
        ? 'İsimsiz firma'
        : c.companyName.trim();
    final initials = companyName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();

    return Card(
      elevation: 0,
      color: const Color(0xFF17304C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF58B69A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                initials.isEmpty ? 'C' : initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (c.contactName.trim().isNotEmpty) c.contactName.trim(),
                      if (c.phone.trim().isNotEmpty) c.phone.trim(),
                      'Cari 360',
                    ].join('  •  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (widget.onEdit != null) ...[
              if (compact)
                IconButton.outlined(
                  tooltip: 'Cariyi düzenle',
                  onPressed: _editCari,
                  color: Colors.white,
                  icon: const Icon(Icons.edit_outlined, size: 19),
                )
              else
                OutlinedButton.icon(
                  onPressed: _editCari,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Cariyi düzenle'),
                ),
              const SizedBox(width: 8),
            ],
            if (compact)
              IconButton.filled(
                tooltip: 'Yeni teklif',
                onPressed: _openNewQuote,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF58B69A),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
              )
            else
              FilledButton.icon(
                onPressed: _openNewQuote,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF58B69A),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Yeni teklif'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCariMetrics(BuildContext context) {
    final open = _quotes
        .where(
          (quote) =>
              quote.status == QuoteStatus.draft ||
              quote.status == QuoteStatus.pending ||
              quote.status == QuoteStatus.approved,
        )
        .toList(growable: false);
    final sent = _quotes
        .where((quote) => quote.status == QuoteStatus.approved)
        .length;
    final won = _quotes
        .where((quote) => quote.status == QuoteStatus.accepted)
        .toList(growable: false);
    final lost = _quotes
        .where(
          (quote) =>
              quote.status == QuoteStatus.rejected ||
              quote.status == QuoteStatus.cancelled,
        )
        .length;
    final openTotal = open.fold<double>(
      0,
      (sum, quote) => sum + quote.totalFor('TL'),
    );
    final wonTotal = won.fold<double>(
      0,
      (sum, quote) => sum + (quote.acceptedTotalTl ?? quote.totalFor('TL')),
    );
    final money = NumberFormat.compactCurrency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 40) / 5
            : constraints.maxWidth >= 560
            ? (constraints.maxWidth - 10) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Cari360Metric(
              width: itemWidth,
              label: 'Toplam teklif',
              value: '${_quotes.length}',
              icon: Icons.description_outlined,
              color: const Color(0xFF356FA5),
            ),
            _Cari360Metric(
              width: itemWidth,
              label: 'Açık fırsat',
              value: '${open.length} · ${money.format(openTotal)}',
              icon: Icons.track_changes_rounded,
              color: const Color(0xFF8B5CC7),
            ),
            _Cari360Metric(
              width: itemWidth,
              label: 'Müşteriye gönderilen',
              value: '$sent',
              icon: Icons.send_rounded,
              color: const Color(0xFF2B82C9),
            ),
            _Cari360Metric(
              width: itemWidth,
              label: 'Kazanılan',
              value: '${won.length} · ${money.format(wonTotal)}',
              icon: Icons.emoji_events_rounded,
              color: const Color(0xFF29956F),
            ),
            _Cari360Metric(
              width: itemWidth,
              label: 'Kaybedilen / iptal',
              value: '$lost',
              icon: Icons.trending_down_rounded,
              color: const Color(0xFFC45C54),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmailActionPanel(BuildContext context) {
    // Gonderilmemis veya cevap bekleyen teklifler — aksiyon gerektiren
    final actionRequired = _quotes.where((q) {
      final needsSend = q.status == QuoteStatus.approved &&
          q.emailSentAt == null;
      final needsResponse = q.status == QuoteStatus.approved &&
          q.emailSentAt != null &&
          q.customerResponse == CustomerResponse.pending;
      return needsSend || needsResponse;
    }).toList(growable: false);

    if (actionRequired.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE8B76A), width: 1.2),
      ),
      color: const Color(0xFFFFFBF0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  size: 18,
                  color: Color(0xFFA07028),
                ),
                const SizedBox(width: 8),
                Text(
                  'Aksiyon Gerektiren (${actionRequired.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Color(0xFF7A5018),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final q in actionRequired) ...[
              _ActionRequiredTile(
                quote: q,
                cariContacts: _cari.contacts,
                onSendEmail: (email) => _sendQuoteEmail(q, email),
                onUpdateResponse: (r) => _updateQuoteResponse(q, r),
              ),
              if (q != actionRequired.last) const Divider(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cariRow(BuildContext context, String label, String value) {
    final v = value.trim();
    if (v.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _kSlate,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _kInk,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cari360Metric extends StatelessWidget {
  const _Cari360Metric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _kSlate,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _kInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
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
}

class _Th extends StatelessWidget {
  const _Th(this.text, {this.align = TextAlign.start});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: align,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        color: _kSlate,
      ),
    );
  }
}

class _QuoteDataRow extends StatelessWidget {
  const _QuoteDataRow({
    required this.quote,
    required this.onTap,
    this.cariContacts = const [],
    this.onSendEmail,
    this.onUpdateResponse,
  });

  final Quote quote;
  final VoidCallback onTap;
  final List<CariContact> cariContacts;
  final void Function(String email)? onSendEmail;
  final void Function(CustomerResponse response)? onUpdateResponse;

  static const _kInk = Color(0xFF17304C);
  static const _kSlate = Color(0xFF5B6F7F);

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: switch (quote.displayUnit) {
        'USDTRY' => r'$ ',
        'EURTRY' => 'EUR ',
        _ => 'TL ',
      },
      decimalDigits: 2,
    );
    final effectiveDate =
        quote.acceptedAt ?? quote.approvedAt ?? quote.createdAt;
    final dateStr = DateFormat(
      'dd.MM.yyyy',
      'tr_TR',
    ).format(effectiveDate);
    final emailSent = quote.emailSentAt != null;
    final emailViewed = quote.emailViewedAt != null;
    final response = quote.customerResponse;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Teklif kodu + baslik + revizyon rozeti
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            quote.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: _kInk,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (quote.revisionCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4E0),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE3B86C)),
                            ),
                            child: Text(
                              'Rev ${quote.revisionCount}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF9D5C1D),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (quote.title.trim().isNotEmpty)
                      Text(
                        quote.title.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _kSlate,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              // Hazırlayan / Sorumlu Yetkili
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: const Color(0xFFE3EAF2),
                      child: Text(
                        (quote.createdByName.trim().isNotEmpty
                                ? quote.createdByName.trim()
                                : quote.documentProfile.preparedByName.trim().isNotEmpty
                                    ? quote.documentProfile.preparedByName.trim()
                                    : 'S')
                            .characters
                            .first
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF17304C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        quote.createdByName.trim().isNotEmpty
                            ? quote.createdByName.trim()
                            : (quote.documentProfile.preparedByName.trim().isNotEmpty
                                ? quote.documentProfile.preparedByName.trim()
                                : 'Belirtilmedi'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _kInk,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Tarih
              Expanded(
                flex: 2,
                child: Text(
                  dateStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _kSlate,
                    fontSize: 12,
                  ),
                ),
              ),
              // Durum rozeti
              Expanded(
                flex: 2,
                child: _StatusBadge(status: quote.status, hasDeal: quote.acceptedTotalTl != null),
              ),
              // İletisim durumu (e-posta + cevap)
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    _EmailIcon(
                      sent: emailSent,
                      viewed: emailViewed,
                      sentTo: quote.emailSentTo,
                      sentAt: quote.emailSentAt,
                      contacts: cariContacts,
                      primaryEmail: quote.documentProfile.customerEmail,
                      onSendEmail: onSendEmail,
                    ),
                    const SizedBox(width: 4),
                    if (emailSent)
                      _ResponseIcon(
                        response: response,
                        onUpdateResponse: onUpdateResponse,
                      ),
                  ],
                ),
              ),
              // Tutar
              Expanded(
                flex: 2,
                child: Text(
                  fmt.format(quote.totalFor(quote.displayUnit)),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: _kInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Teklif durum rozeti.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.hasDeal});
  final QuoteStatus status;
  final bool hasDeal;

  @override
  Widget build(BuildContext context) {
    if (hasDeal) {
      return _badge('Anlasildi', const Color(0xFF29956F), const Color(0xFFE5F5EE));
    }
    return switch (status) {
      QuoteStatus.draft => _badge('Taslak', const Color(0xFF5B6F7F), const Color(0xFFF1F4F8)),
      QuoteStatus.pending => _badge('Hazir', const Color(0xFF8B5918), const Color(0xFFFFF4E0)),
      QuoteStatus.approved => _badge('Gonderildi', const Color(0xFF2B82C9), const Color(0xFFE6F2FB)),
      QuoteStatus.accepted => _badge('Kazanildi', const Color(0xFF29956F), const Color(0xFFE5F5EE)),
      QuoteStatus.rejected => _badge('Kaybedildi', const Color(0xFF9D2C2C), const Color(0xFFFBE8E8)),
      QuoteStatus.cancelled => _badge('Iptal', const Color(0xFF5B6F7F), const Color(0xFFF1F4F8)),
    };
  }

  Widget _badge(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// E-posta gonderim ikonu + menu.
class _EmailIcon extends StatelessWidget {
  const _EmailIcon({
    required this.sent,
    required this.viewed,
    required this.sentTo,
    required this.contacts,
    required this.primaryEmail,
    this.sentAt,
    this.onSendEmail,
  });

  final bool sent;
  final bool viewed;
  final String sentTo;
  final DateTime? sentAt;
  final List<CariContact> contacts;
  final String primaryEmail;
  final void Function(String email)? onSendEmail;

  @override
  Widget build(BuildContext context) {
    if (sent) {
      // Gonderildi rozeti
      final tooltip = viewed
          ? 'Goruntulendi · $sentTo'
          : 'Gonderildi · $sentTo';
      return Tooltip(
        message: tooltip,
        child: Icon(
          viewed ? Icons.mark_email_read_rounded : Icons.email_rounded,
          size: 18,
          color: viewed ? const Color(0xFF29956F) : const Color(0xFF2B82C9),
        ),
      );
    }

    // Gonderilmedi — butonu goster
    if (onSendEmail == null) return const SizedBox.shrink();

    // E-posta adresi adaylari: contacts + documentProfile
    final emailOptions = <String>{};
    for (final c in contacts) {
      if (c.email.trim().isNotEmpty) emailOptions.add(c.email.trim());
    }
    if (primaryEmail.trim().isNotEmpty) emailOptions.add(primaryEmail.trim());

    if (emailOptions.isEmpty) {
      return Tooltip(
        message: 'E-posta adresi yok',
        child: Icon(
          Icons.email_outlined,
          size: 18,
          color: Colors.grey.shade400,
        ),
      );
    }

    if (emailOptions.length == 1) {
      return Tooltip(
        message: 'E-posta ile gonder: ${emailOptions.first}',
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => onSendEmail!(emailOptions.first),
          child: const Icon(
            Icons.send_rounded,
            size: 18,
            color: Color(0xFF8B5918),
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'E-posta ile gonder',
      icon: const Icon(Icons.send_rounded, size: 18, color: Color(0xFF8B5918)),
      iconSize: 18,
      padding: EdgeInsets.zero,
      itemBuilder: (ctx) => emailOptions
          .map(
            (e) => PopupMenuItem<String>(
              value: e,
              child: Text(e),
            ),
          )
          .toList(),
      onSelected: (email) => onSendEmail!(email),
    );
  }
}

/// Musteri cevap durumu ikonu.
class _ResponseIcon extends StatelessWidget {
  const _ResponseIcon({required this.response, this.onUpdateResponse});

  final CustomerResponse response;
  final void Function(CustomerResponse)? onUpdateResponse;

  @override
  Widget build(BuildContext context) {
    final (icon, color, tip) = switch (response) {
      CustomerResponse.pending => (
        Icons.hourglass_top_rounded,
        const Color(0xFF8B5918),
        'Cevap bekleniyor',
      ),
      CustomerResponse.accepted => (
        Icons.thumb_up_rounded,
        const Color(0xFF29956F),
        'Musteri kabul etti',
      ),
      CustomerResponse.rejected => (
        Icons.thumb_down_rounded,
        const Color(0xFF9D2C2C),
        'Musteri reddetti',
      ),
      CustomerResponse.noResponse => (
        Icons.do_not_disturb_alt_rounded,
        const Color(0xFF5B6F7F),
        'Cevap yok',
      ),
    };

    if (onUpdateResponse == null) {
      return Tooltip(message: tip, child: Icon(icon, size: 17, color: color));
    }

    return PopupMenuButton<CustomerResponse>(
      tooltip: tip,
      icon: Icon(icon, size: 17, color: color),
      iconSize: 17,
      padding: EdgeInsets.zero,
      itemBuilder: (ctx) => CustomerResponse.values
          .map(
            (r) => PopupMenuItem<CustomerResponse>(
              value: r,
              child: Text(r.displayLabel),
            ),
          )
          .toList(),
      onSelected: (r) => onUpdateResponse!(r),
    );
  }
}

/// Aksiyon gerektiren teklif satiri (E-posta Aksiyon Paneli icin).
class _ActionRequiredTile extends StatelessWidget {
  const _ActionRequiredTile({
    required this.quote,
    required this.cariContacts,
    required this.onSendEmail,
    required this.onUpdateResponse,
  });

  final Quote quote;
  final List<CariContact> cariContacts;
  final void Function(String email) onSendEmail;
  final void Function(CustomerResponse r) onUpdateResponse;

  @override
  Widget build(BuildContext context) {
    final needsSend = quote.emailSentAt == null;
    final dateStr = DateFormat('dd.MM.yyyy', 'tr_TR').format(quote.createdAt);

    return Row(
      children: [
        Icon(
          needsSend ? Icons.forward_to_inbox_rounded : Icons.schedule_rounded,
          size: 18,
          color: const Color(0xFFA07028),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quote.code,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Color(0xFF17304C),
                ),
              ),
              Text(
                needsSend
                    ? 'Onaylandi ama e-posta gonderilmedi ($dateStr)'
                    : 'E-posta gonderildi, musteri cevabi bekleniyor',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF7A5018),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (needsSend)
          _EmailIcon(
            sent: false,
            viewed: false,
            sentTo: '',
            contacts: cariContacts,
            primaryEmail: quote.documentProfile.customerEmail,
            onSendEmail: onSendEmail,
          )
        else
          _ResponseIcon(
            response: quote.customerResponse,
            onUpdateResponse: onUpdateResponse,
          ),
      ],
    );
  }
}

enum _CariQuoteFilter { all, approved, agreed }
