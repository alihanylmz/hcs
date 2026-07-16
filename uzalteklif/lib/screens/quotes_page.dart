import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/market_rate.dart';
import '../models/product.dart';
import '../models/quote.dart';
import '../services/cari_repository.dart';
import '../services/company_stamp_service.dart';
import '../services/market_rate_service.dart';
import '../services/own_company_repository.dart';
import '../services/price_adjustment_rule_repository.dart';
import '../services/product_repository.dart';
import '../services/quote_repository.dart';
import '../services/user_profile_repository.dart';
import '../widgets/workspace_background.dart';
import 'quote_editor_page.dart';
import 'quote_review_page.dart';

/// Aktif teklifler (durum sekmeleri) ve kapanan teklif listesi.
class QuotesPage extends StatefulWidget {
  const QuotesPage({
    super.key,
    required this.quoteRepository,
    required this.productRepository,
    required this.marketRateService,
    required this.ownCompanyRepository,
    required this.priceAdjustmentRuleRepository,
    required this.userProfileRepository,
    required this.cariRepository,
    this.isManager = false,
  });

  final QuoteRepository quoteRepository;
  final ProductRepository productRepository;
  final MarketRateService marketRateService;
  final OwnCompanyRepository ownCompanyRepository;
  final PriceAdjustmentRuleRepository priceAdjustmentRuleRepository;
  final UserProfileRepository userProfileRepository;
  final CariRepository cariRepository;
  final bool isManager;

  @override
  State<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends State<QuotesPage> with TickerProviderStateMixin {
  static const _tabs = [
    _TabDefinition(
      label: 'Gönderilen',
      icon: Icons.hourglass_top_rounded,
      statuses: [QuoteStatus.pending],
    ),
    _TabDefinition(
      label: 'Taslaklar',
      icon: Icons.edit_note_rounded,
      statuses: [QuoteStatus.draft],
    ),
    _TabDefinition(
      label: 'Reddedilen',
      icon: Icons.block_rounded,
      statuses: [QuoteStatus.rejected],
    ),
    _TabDefinition(
      label: 'İptal',
      icon: Icons.cancel_schedule_send_rounded,
      statuses: [QuoteStatus.cancelled],
    ),
  ];

  final _stampService = const CompanyStampService();
  late final TabController _scopeTabController;
  late final TabController _statusTabController;

  List<Quote> _quotes = const [];
  List<Product> _products = const [];
  List<MarketRate> _rates = const [];
  String? _stampPath;
  bool _isLoading = true;
  bool _isPickingStamp = false;
  String _quoteQuery = '';
  String _quoteDateFilter = 'all';
  String _quoteSort = 'date_desc';
  bool _showQuoteCustomer = true;
  bool _showQuoteTitle = true;
  bool _showQuoteDate = true;
  bool _showQuoteStatus = true;
  bool _showQuoteAmount = true;

  List<Quote> get _activeQuotes => _filteredQuotes
      .where(
        (q) =>
            q.archivedAt == null &&
            q.status != QuoteStatus.approved &&
            q.status != QuoteStatus.accepted,
      )
      .toList(growable: false);

  List<Quote> get _archivedQuotes {
    final list = _filteredQuotes
        .where(
          (q) =>
              q.archivedAt != null ||
              q.status == QuoteStatus.approved ||
              q.status == QuoteStatus.accepted,
        )
        .toList(growable: false);
    list.sort((a, b) {
      final aDate = a.archivedAt ?? a.approvedAt ?? a.createdAt;
      final bDate = b.archivedAt ?? b.approvedAt ?? b.createdAt;
      return bDate.compareTo(aDate);
    });
    return list;
  }

  List<Quote> get _filteredQuotes {
    final query = _quoteQuery.trim().toLowerCase();
    final cutoff = _quoteCutoff();
    final list = _quotes
        .where((quote) {
          if (cutoff != null && quote.createdAt.isBefore(cutoff)) return false;
          if (query.isEmpty) return true;
          final haystack = [
            quote.code,
            quote.title,
            quote.customerCompany,
            quote.customerName,
            quote.createdByName,
            quote.status.displayLabel,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
    _sortQuoteList(list);
    return list;
  }

  DateTime? _quoteCutoff() {
    final now = DateTime.now();
    switch (_quoteDateFilter) {
      case '7':
        return now.subtract(const Duration(days: 7));
      case '30':
        return now.subtract(const Duration(days: 30));
      case '90':
        return now.subtract(const Duration(days: 90));
      default:
        return null;
    }
  }

  void _sortQuoteList(List<Quote> list) {
    int byDate(Quote a, Quote b) => b.createdAt.compareTo(a.createdAt);
    list.sort((a, b) {
      switch (_quoteSort) {
        case 'date_asc':
          return a.createdAt.compareTo(b.createdAt);
        case 'customer':
          return a.customerCompany.compareTo(b.customerCompany);
        case 'amount_desc':
          return b.totalFor(b.displayUnit).compareTo(a.totalFor(a.displayUnit));
        case 'amount_asc':
          return a.totalFor(a.displayUnit).compareTo(b.totalFor(b.displayUnit));
        default:
          return byDate(a, b);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _scopeTabController = TabController(length: 2, vsync: this);
    _statusTabController = TabController(length: _tabs.length, vsync: this);
    _scopeTabController.addListener(() {
      if (!_scopeTabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
    _reload();
  }

  @override
  void dispose() {
    _scopeTabController.dispose();
    _statusTabController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final quotes = await widget.quoteRepository.fetchQuotes();
    final products = await widget.productRepository.fetchProducts();
    final rates = await widget.marketRateService.fetchRates();
    if (!mounted) return;
    setState(() {
      _quotes = quotes;
      _products = products;
      _rates = rates;
      _isLoading = false;
    });
  }

  Future<void> _pickStamp() async {
    if (_isPickingStamp) return;
    setState(() => _isPickingStamp = true);
    try {
      final path = await _stampService.pickAndStore();
      if (!mounted || path == null) return;
      setState(() => _stampPath = path);
    } finally {
      if (mounted) setState(() => _isPickingStamp = false);
    }
  }

  Future<void> _removeStamp() async {
    await _stampService.remove();
    if (!mounted) return;
    setState(() => _stampPath = null);
  }

  Future<void> _openNewQuote() async {
    await Navigator.of(context).push<Quote>(
      MaterialPageRoute(
        builder: (context) => QuoteEditorPage(
          quoteRepository: widget.quoteRepository,
          initialRates: _rates,
          availableProducts: _products,
          userProfileRepository: widget.userProfileRepository,
          cariRepository: widget.cariRepository,
          ownCompanyRepository: widget.ownCompanyRepository,
          priceAdjustmentRuleRepository: widget.priceAdjustmentRuleRepository,
        ),
      ),
    );
    await _reload();
  }

  Future<void> _openQuote(Quote quote) async {
    await Navigator.of(context).push<Quote>(
      MaterialPageRoute(
        builder: (context) => QuoteReviewPage(
          quote: quote,
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

  double get _appBarBottomHeight => _scopeTabController.index == 0 ? 92 : 46;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Teklif Takip',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              'Aktif süreçler, kapanan teklifler ve resmi PDF çıktıları',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _isLoading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_appBarBottomHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                controller: _scopeTabController,
                tabs: [
                  Tab(text: 'Aktif (${_activeQuotes.length})'),
                  Tab(text: 'Gönderilen Teklifler (${_archivedQuotes.length})'),
                ],
              ),
              if (_scopeTabController.index == 0)
                TabBar(
                  controller: _statusTabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final tab in _tabs)
                      Tab(
                        icon: Icon(tab.icon, size: 18),
                        text: '${tab.label} (${_countFor(tab)})',
                        iconMargin: const EdgeInsets.only(bottom: 4),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _openNewQuote,
        icon: const Icon(Icons.add_chart_rounded),
        label: const Text('Yeni teklif oluştur'),
      ),
      body: WorkspaceBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _buildQuoteControlBar(),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _scopeTabController,
                        children: [
                          TabBarView(
                            controller: _statusTabController,
                            children: [
                              for (final tab in _tabs) _buildList(tab),
                            ],
                          ),
                          _buildArchiveList(),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildQuoteControlBar() {
    return Card(
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
                  labelText: 'Teklif, cari, kullanıcı ara',
                ),
                onChanged: (value) => setState(() => _quoteQuery = value),
              ),
            ),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: _quoteDateFilter,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Tarih',
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('Tümü')),
                  DropdownMenuItem(value: '7', child: Text('Son 7 gün')),
                  DropdownMenuItem(value: '30', child: Text('Son 30 gün')),
                  DropdownMenuItem(value: '90', child: Text('Son 90 gün')),
                ],
                onChanged: (value) =>
                    setState(() => _quoteDateFilter = value ?? 'all'),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _quoteSort,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Sıralama',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'date_desc',
                    child: Text('Yeni -> Eski'),
                  ),
                  DropdownMenuItem(
                    value: 'date_asc',
                    child: Text('Eski -> Yeni'),
                  ),
                  DropdownMenuItem(value: 'customer', child: Text('Cari adı')),
                  DropdownMenuItem(
                    value: 'amount_desc',
                    child: Text('Tutar yüksek'),
                  ),
                  DropdownMenuItem(
                    value: 'amount_asc',
                    child: Text('Tutar düşük'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _quoteSort = value ?? 'date_desc'),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Kolonlar',
              icon: const Icon(Icons.view_column_rounded),
              itemBuilder: (context) => [
                _columnMenuItem('customer', 'Cari', _showQuoteCustomer),
                _columnMenuItem('title', 'Başlık', _showQuoteTitle),
                _columnMenuItem('date', 'Tarih', _showQuoteDate),
                _columnMenuItem('status', 'Durum', _showQuoteStatus),
                _columnMenuItem('amount', 'Tutar', _showQuoteAmount),
              ],
              onSelected: (value) {
                setState(() {
                  if (value == 'customer') {
                    _showQuoteCustomer = !_showQuoteCustomer;
                  }
                  if (value == 'title') _showQuoteTitle = !_showQuoteTitle;
                  if (value == 'date') _showQuoteDate = !_showQuoteDate;
                  if (value == 'status') _showQuoteStatus = !_showQuoteStatus;
                  if (value == 'amount') _showQuoteAmount = !_showQuoteAmount;
                });
              },
            ),
          ],
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

  int _countFor(_TabDefinition tab) {
    return _activeQuotes.where((q) => tab.statuses.contains(q.status)).length;
  }

  Widget _buildList(_TabDefinition tab) {
    final items =
        _activeQuotes
            .where((q) => tab.statuses.contains(q.status))
            .toList(growable: false)
          ..sort((a, b) {
            final aDate = a.approvedAt ?? a.submittedAt ?? a.createdAt;
            final bDate = b.approvedAt ?? b.submittedAt ?? b.createdAt;
            return bDate.compareTo(aDate);
          });

    return _buildQuoteWorkspace(
      quotes: items,
      emptyText: 'Bu aşamada kayıt bulunmuyor.',
    );
  }

  Widget _buildArchiveList() {
    final items = _archivedQuotes;
    return _buildQuoteWorkspace(
      quotes: items,
      emptyText: 'Gönderilen teklif bulunmuyor.',
      showArchiveDate: true,
    );
  }

  Widget _buildQuoteWorkspace({
    required List<Quote> quotes,
    required String emptyText,
    bool showArchiveDate = false,
  }) {
    final main = quotes.isEmpty
        ? _buildEmptyState(emptyText)
        : _QuoteTable(
            quotes: quotes,
            onOpen: _openQuote,
            showArchiveDate: showArchiveDate,
            showCustomer: _showQuoteCustomer,
            showTitle: _showQuoteTitle,
            showDate: _showQuoteDate,
            showStatus: _showQuoteStatus,
            showAmount: _showQuoteAmount,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1080) return main;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: main),
            SizedBox(
              width: 300,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                child: _QuoteSidePanel(quotes: quotes),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: const Color(0xFF5B6F7F),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildStampCard() {
    return const SizedBox.shrink();
  }

  // ignore: unused_element
  Widget _legacyStampCard() {
    const ink = Color(0xFF17304C);
    const slate = Color(0xFF5B6F7F);
    final path = _stampPath;
    final hasStamp = path != null && path.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
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
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined, color: ink),
                    )
                  : const Icon(Icons.approval_rounded, size: 28, color: ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kurumsal onay mührü (PDF)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasStamp
                        ? 'Onaylı teklif PDF\'lerinde resmi mühür kullanılır; dosya yalnızca yönetici tarafından güncellenir.'
                        : 'Mühür görseli yüklenmedi. PNG veya JPEG yükleyin; onaylı çıktılarda sağ alt köşede yer alır.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: slate,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _isPickingStamp ? null : _pickStamp,
              icon: _isPickingStamp
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      hasStamp ? Icons.swap_horiz_rounded : Icons.add_rounded,
                      size: 16,
                    ),
              label: Text(hasStamp ? 'Mührü güncelle' : 'Mühür yükle'),
            ),
            if (hasStamp) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Kaseyi sil',
                onPressed: _removeStamp,
                icon: const Icon(Icons.delete_outline_rounded),
                color: const Color(0xFF9D5C1D),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuoteTable extends StatelessWidget {
  const _QuoteTable({
    required this.quotes,
    required this.onOpen,
    this.showArchiveDate = false,
    this.showCustomer = true,
    this.showTitle = true,
    this.showDate = true,
    this.showStatus = true,
    this.showAmount = true,
  });

  final List<Quote> quotes;
  final ValueChanged<Quote> onOpen;
  final bool showArchiveDate;
  final bool showCustomer;
  final bool showTitle;
  final bool showDate;
  final bool showStatus;
  final bool showAmount;

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(width: 126, child: _TableHeader('Teklif No')),
                  if (showCustomer)
                    const Expanded(flex: 3, child: _TableHeader('Cari')),
                  if (showTitle)
                    const Expanded(flex: 3, child: _TableHeader('Başlık')),
                  if (showDate)
                    const SizedBox(width: 132, child: _TableHeader('Tarih')),
                  if (showStatus)
                    const SizedBox(width: 118, child: _TableHeader('Durum')),
                  if (showAmount)
                    const SizedBox(
                      width: 126,
                      child: _TableHeader('Tutar', align: TextAlign.end),
                    ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: quotes.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final quote = quotes[index];
                  return _QuoteTableRow(
                    quote: quote,
                    showArchiveDate: showArchiveDate,
                    showCustomer: showCustomer,
                    showTitle: showTitle,
                    showDate: showDate,
                    showStatus: showStatus,
                    showAmount: showAmount,
                    onTap: () => onOpen(quote),
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

class _QuoteTableRow extends StatelessWidget {
  const _QuoteTableRow({
    required this.quote,
    required this.onTap,
    required this.showArchiveDate,
    required this.showCustomer,
    required this.showTitle,
    required this.showDate,
    required this.showStatus,
    required this.showAmount,
  });

  final Quote quote;
  final VoidCallback onTap;
  final bool showArchiveDate;
  final bool showCustomer;
  final bool showTitle;
  final bool showDate;
  final bool showStatus;
  final bool showAmount;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17304C);
    const slate = Color(0xFF5B6F7F);
    final statusStyle = _QuoteSummaryCard._statusStyleFor(quote.status);
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: switch (quote.displayUnit) {
        'USDTRY' => r'$ ',
        'EURTRY' => 'EUR ',
        _ => 'TL ',
      },
      decimalDigits: 2,
    );
    final customer = quote.customerCompany.trim().isEmpty
        ? quote.customerName.trim()
        : quote.customerCompany.trim();
    final date = showArchiveDate && quote.archivedAt != null
        ? quote.archivedAt!
        : quote.createdAt;

    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 126,
                child: Text(
                  quote.code,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (showCustomer)
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.isEmpty ? 'Cari bilgisi yok' : customer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      if (quote.customerName.trim().isNotEmpty)
                        Text(
                          quote.customerName.trim(),
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
              if (showTitle)
                Expanded(
                  flex: 3,
                  child: Text(
                    quote.title.trim().isEmpty
                        ? 'Başlıksız teklif'
                        : quote.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              if (showDate)
                SizedBox(
                  width: 132,
                  child: Text(
                    DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(date),
                    style: const TextStyle(
                      color: slate,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (showStatus)
                SizedBox(
                  width: 118,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusStyle.bg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        quote.status.displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: statusStyle.fg,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              if (showAmount)
                SizedBox(
                  width: 126,
                  child: Text(
                    formatter.format(quote.totalFor(quote.displayUnit)),
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              SizedBox(
                width: 44,
                child: IconButton(
                  tooltip: 'Detay',
                  onPressed: onTap,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text, {this.align = TextAlign.start});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: align,
      style: const TextStyle(
        color: Color(0xFF5B6F7F),
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _TabDefinition {
  const _TabDefinition({
    required this.label,
    required this.icon,
    required this.statuses,
  });

  final String label;
  final IconData icon;
  final List<QuoteStatus> statuses;
}

class _QuoteSidePanel extends StatelessWidget {
  const _QuoteSidePanel({required this.quotes});

  final List<Quote> quotes;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: 'TL ',
      decimalDigits: 2,
    );
    final total = quotes.fold<double>(
      0,
      (sum, quote) => sum + quote.totalFor('TL'),
    );
    int count(QuoteStatus status) =>
        quotes.where((quote) => quote.status == status).length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Özet Panel',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: const Color(0xFF17304C),
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _SideMetric(label: 'Kayıt', value: '${quotes.length}'),
            _SideMetric(label: 'Toplam', value: formatter.format(total)),
            const Divider(height: 24),
            _SideMetric(label: 'Taslak', value: '${count(QuoteStatus.draft)}'),
            _SideMetric(
              label: 'Gönderilen',
              value: '${count(QuoteStatus.pending)}',
            ),
            _SideMetric(
              label: 'Onaylanan',
              value: '${count(QuoteStatus.approved)}',
            ),
            _SideMetric(
              label: 'Anlaşıldı',
              value: '${count(QuoteStatus.accepted)}',
            ),
            _SideMetric(
              label: 'Reddedilen',
              value: '${count(QuoteStatus.rejected)}',
            ),
            _SideMetric(
              label: 'İptal',
              value: '${count(QuoteStatus.cancelled)}',
            ),
            const Spacer(),
            Text(
              'Liste filtreleri ve kolon görünümü üst işlem çubuğundan yönetilir.',
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

class _SideMetric extends StatelessWidget {
  const _SideMetric({required this.label, required this.value});

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
            textAlign: TextAlign.end,
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

class _QuoteSummaryCard extends StatelessWidget {
  const _QuoteSummaryCard({required this.quote, required this.onTap});

  final Quote quote;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17304C);
    const slate = Color(0xFF5B6F7F);
    final statusStyle = _statusStyleFor(quote.status);

    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: switch (quote.displayUnit) {
        'USDTRY' => r'$ ',
        'EURTRY' => 'EUR ',
        _ => 'TL ',
      },
      decimalDigits: 2,
    );
    final formattedTotal = formatter.format(quote.totalFor(quote.displayUnit));
    final archived = quote.archivedAt;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD7DEE6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      quote.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusStyle.bg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      quote.status.displayLabel.toUpperCase(),
                      style: TextStyle(
                        color: statusStyle.fg,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                quote.title.isEmpty ? 'İsimsiz teklif' : quote.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                quote.customerCompany.isEmpty
                    ? quote.customerName
                    : '${quote.customerCompany} - ${quote.customerName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: slate,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (quote.createdByName.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Teklif sorumlusu: ${quote.createdByName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF657888),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
              if (archived != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Kapanış: ${DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(archived)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8A2626),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.formattedDate,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: slate,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (quote.revisionCount > 0)
                          Text(
                            'Revizyon ${quote.revisionCount}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: const Color(0xFF9D5C1D),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    formattedTotal,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _StatusStyle _statusStyleFor(QuoteStatus status) {
    switch (status) {
      case QuoteStatus.draft:
        return const _StatusStyle(bg: Color(0xFFF1F4F8), fg: Color(0xFF5B6F7F));
      case QuoteStatus.pending:
        return const _StatusStyle(bg: Color(0xFFFFF4E0), fg: Color(0xFF9D5C1D));
      case QuoteStatus.approved:
        return const _StatusStyle(bg: Color(0xFFE5F1EC), fg: Color(0xFF2C6957));
      case QuoteStatus.accepted:
        return const _StatusStyle(bg: Color(0xFFFFF4E0), fg: Color(0xFF9D5C1D));
      case QuoteStatus.rejected:
        return const _StatusStyle(bg: Color(0xFFFBE4E4), fg: Color(0xFF8A2626));
      case QuoteStatus.cancelled:
        return const _StatusStyle(bg: Color(0xFFF3EFEA), fg: Color(0xFF705C49));
    }
  }
}

class _StatusStyle {
  const _StatusStyle({required this.bg, required this.fg});
  final Color bg;
  final Color fg;
}
