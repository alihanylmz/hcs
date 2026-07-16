import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  @override
  State<CariDetailPage> createState() => _CariDetailPageState();
}

class _CariDetailPageState extends State<CariDetailPage> {
  List<Quote> _quotes = const [];
  List<Product> _products = const [];
  List<MarketRate> _rates = const [];
  bool _loading = true;
  _CariQuoteFilter _filter = _CariQuoteFilter.all;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final all = await widget.quoteRepository.fetchQuotes();
    final products = await widget.productRepository.fetchProducts();
    final rates = await widget.marketRateService.fetchRates();
    if (!mounted) return;
    final id = widget.cari.id;
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
        cari: widget.cari,
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
    final c = widget.cari;
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
                  padding: const EdgeInsets.all(16),
                  children: [
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
                              'Firma ve iletişim',
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
                              'Yetkili',
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
                          'Teklif geçmişi',
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
                          label: const Text('Onaylananlar'),
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
                                  Expanded(flex: 2, child: _Th('Teklif')),
                                  Expanded(flex: 2, child: _Th('Tarih')),
                                  Expanded(flex: 2, child: _Th('Durum')),
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
                                onTap: () => _openQuote(_filteredQuotes[i]),
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
  const _QuoteDataRow({required this.quote, required this.onTap});

  final Quote quote;
  final VoidCallback onTap;

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
      'dd.MM.yyyy HH:mm',
      'tr_TR',
    ).format(effectiveDate);
    final statusLabel = quote.acceptedTotalTl != null
        ? 'Anlasildi'
        : quote.status.displayLabel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
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
              Expanded(
                flex: 2,
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: _kInk,
                  ),
                ),
              ),
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

enum _CariQuoteFilter { all, approved, agreed }
