import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/market_rate.dart';
import '../models/product.dart';
import '../models/quote.dart';
import '../services/cari_repository.dart';
import '../services/market_rate_service.dart';
import '../services/own_company_repository.dart';
import '../services/price_adjustment_rule_repository.dart';
import '../services/product_repository.dart';
import '../services/quote_repository.dart';
import '../services/user_profile_repository.dart';
import '../widgets/workspace_background.dart';
import 'quote_review_page.dart';

/// Personel Çalışma Masası (Personal Workspace / My Dashboard)
class MyWorkspacePage extends StatefulWidget {
  const MyWorkspacePage({
    super.key,
    required this.quoteRepository,
    required this.productRepository,
    required this.marketRateService,
    required this.userProfileRepository,
    required this.cariRepository,
    required this.ownCompanyRepository,
    required this.priceAdjustmentRuleRepository,
    required this.isManager,
    this.currentUserName = '',
  });

  final QuoteRepository quoteRepository;
  final ProductRepository productRepository;
  final MarketRateService marketRateService;
  final UserProfileRepository userProfileRepository;
  final CariRepository cariRepository;
  final OwnCompanyRepository ownCompanyRepository;
  final PriceAdjustmentRuleRepository priceAdjustmentRuleRepository;
  final bool isManager;
  final String currentUserName;

  @override
  State<MyWorkspacePage> createState() => _MyWorkspacePageState();
}

class _MyWorkspacePageState extends State<MyWorkspacePage> {
  List<Quote> _allQuotes = const [];
  List<Product> _products = const [];
  List<MarketRate> _rates = const [];
  bool _loading = true;

  /// Secili personel (bos string = Tum Sirket)
  late String _selectedPerson;
  List<String> _personList = const [];

  @override
  void initState() {
    super.initState();
    _selectedPerson = widget.currentUserName.trim();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final quotes = await widget.quoteRepository.fetchQuotes();
      final products = await widget.productRepository.fetchProducts();
      final rates = await widget.marketRateService.fetchRates();

      // Benzersiz personel isimlerini topla
      final persons = <String>{};
      for (final q in quotes) {
        final creator = q.createdByName.trim();
        if (creator.isNotEmpty) persons.add(creator);
        final prep = q.documentProfile.preparedByName.trim();
        if (prep.isNotEmpty) persons.add(prep);
      }
      if (widget.currentUserName.trim().isNotEmpty) {
        persons.add(widget.currentUserName.trim());
      }
      final sortedPersons = persons.toList()..sort();

      if (!mounted) return;
      setState(() {
        _allQuotes = quotes;
        _products = products;
        _rates = rates;
        _personList = sortedPersons;

        // Yonetici degilse sadece kendi adina sabitle
        if (!widget.isManager) {
          _selectedPerson = widget.currentUserName.trim();
        } else if (_selectedPerson.isEmpty && sortedPersons.isNotEmpty) {
          // Yonetici ise varsayilan olarak ilk personeli veya tumunu secebilir
          _selectedPerson = widget.currentUserName.trim().isNotEmpty
              ? widget.currentUserName.trim()
              : sortedPersons.first;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Secili personele ait teklifler
  List<Quote> get _personQuotes {
    if (_selectedPerson.isEmpty) return _allQuotes;
    return _allQuotes.where((q) {
      final creator = q.createdByName.trim();
      final prep = q.documentProfile.preparedByName.trim();
      return creator == _selectedPerson || prep == _selectedPerson;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final quotes = _personQuotes;

    // Metrikler
    final draftQuotes = quotes.where((q) => q.status == QuoteStatus.draft).toList();
    final pendingQuotes = quotes.where((q) => q.status == QuoteStatus.pending).toList();
    final approvedQuotes = quotes.where((q) => q.status == QuoteStatus.approved).toList();
    final wonQuotes = quotes.where((q) => q.status == QuoteStatus.accepted).toList();

    // Aksiyon gerektiren teklifler (Onayli ama e-posta atilmamis)
    final needsEmail = approvedQuotes.where((q) => q.emailSentAt == null).toList();
    // E-posta atilmis ama cevap bekleyenler
    final awaitingResponse = approvedQuotes.where((q) => q.emailSentAt != null && q.customerResponse == CustomerResponse.pending).toList();

    final wonTotal = wonQuotes.fold<double>(
      0,
      (sum, q) => sum + (q.acceptedTotalTl ?? q.totalFor('TL')),
    );

    final moneyFmt = NumberFormat.compactCurrency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 0,
    );

    return Scaffold(
      body: WorkspaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildTopHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Personel Secici & Hosgeldin Karti
                      _buildWelcomeCard(context, quotes.length),
                      const SizedBox(height: 16),

                      // KPI Metrik Kartlari
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final itemWidth = constraints.maxWidth >= 900
                              ? (constraints.maxWidth - 30) / 4
                              : constraints.maxWidth >= 540
                              ? (constraints.maxWidth - 10) / 2
                              : constraints.maxWidth;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _WorkspaceMetricCard(
                                width: itemWidth,
                                label: 'Taslak / Hazırlanan',
                                value: '${draftQuotes.length}',
                                subText: 'Düzenlemeye açık',
                                icon: Icons.edit_note_rounded,
                                color: const Color(0xFF5B6F7F),
                              ),
                              _WorkspaceMetricCard(
                                width: itemWidth,
                                label: 'Onay / Gönderim Bekleyen',
                                value: '${pendingQuotes.length}',
                                subText: 'Müşteriye iletilecek',
                                icon: Icons.hourglass_top_rounded,
                                color: const Color(0xFFD9822B),
                              ),
                              _WorkspaceMetricCard(
                                width: itemWidth,
                                label: 'Takipte / Cevap Bekleyen',
                                value: '${approvedQuotes.length}',
                                subText: '${awaitingResponse.length} yanıt bekliyor',
                                icon: Icons.mark_email_read_rounded,
                                color: const Color(0xFF2B82C9),
                              ),
                              _WorkspaceMetricCard(
                                width: itemWidth,
                                label: 'Kazanılan Toplam',
                                value: moneyFmt.format(wonTotal),
                                subText: '${wonQuotes.length} teklif kazanıldı',
                                icon: Icons.emoji_events_rounded,
                                color: const Color(0xFF29956F),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 20),

                      // Aksiyon Gerektirenler Paneli
                      if (needsEmail.isNotEmpty || awaitingResponse.isNotEmpty) ...[
                        _buildActionCenter(needsEmail, awaitingResponse),
                        const SizedBox(height: 20),
                      ],

                      // Personel Teklif Listesi
                      _buildQuotesSection(context, quotes),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE3EAF2))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF17304C)),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personel Çalışma Masası',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF17304C),
                ),
              ),
              const Text(
                'Kişisel teklif takibi ve müşteri karar yönetim paneli',
                style: TextStyle(fontSize: 11, color: Color(0xFF5B6F7F), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Verileri Yenile',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF5B6F7F)),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, int totalCount) {
    final displayName = _selectedPerson.isEmpty ? 'Tüm Ekip' : _selectedPerson;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF17304C), Color(0xFF254B75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF17304C).withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
            child: Text(
              displayName.characters.first.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Çalışma Masası: $displayName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sorumlu olunan toplam $totalCount teklif kaydı listeleniyor.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('İş Takip ve Atölye sistemine geçiliyor...'),
                  duration: Duration(seconds: 1),
                  backgroundColor: Color(0xFF2B82C9),
                ),
              );
              Future.delayed(const Duration(milliseconds: 300), () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              });
            },
            icon: const Icon(Icons.build_circle_outlined, size: 18),
            label: const Text('🛠️ İş Takip & Atölye ➔'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B82C9),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (widget.isManager && _personList.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPerson.isEmpty ? null : _selectedPerson,
                  hint: const Text(
                    '🏢 Tüm Şirket',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF17304C),
                    ),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF17304C)),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('🏢 Tüm Şirket Teklifleri'),
                    ),
                    ..._personList.map(
                      (person) => DropdownMenuItem<String>(
                        value: person,
                        child: Text('👤 $person'),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedPerson = val);
                    }
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCenter(List<Quote> needsEmail, List<Quote> awaitingResponse) {
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
            const Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 20,
                  color: Color(0xFFA07028),
                ),
                SizedBox(width: 8),
                Text(
                  'Aksiyon Bekleyen Teklifleriniz',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Color(0xFF7A5018),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (needsEmail.isNotEmpty) ...[
              const Text(
                '📧 Müşteriye Henüz E-posta Gönderilmemiş:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF9D5C1D)),
              ),
              const SizedBox(height: 6),
              for (final q in needsEmail) ...[
                _ActionQuoteTile(
                  quote: q,
                  actionText: 'E-posta Gönder',
                  icon: Icons.send_rounded,
                  btnColor: const Color(0xFF2B82C9),
                  onTap: () => _openQuoteReview(q),
                ),
                if (q != needsEmail.last) const SizedBox(height: 6),
              ],
            ],
            if (needsEmail.isNotEmpty && awaitingResponse.isNotEmpty)
              const Divider(height: 20),
            if (awaitingResponse.isNotEmpty) ...[
              const Text(
                '⏳ Müşteri Cevabı Bekleniyor:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2B82C9)),
              ),
              const SizedBox(height: 6),
              for (final q in awaitingResponse) ...[
                _ActionQuoteTile(
                  quote: q,
                  actionText: 'Karar Gir',
                  icon: Icons.edit_note_rounded,
                  btnColor: const Color(0xFF29956F),
                  onTap: () => _openQuoteReview(q),
                ),
                if (q != awaitingResponse.last) const SizedBox(height: 6),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuotesSection(BuildContext context, List<Quote> quotes) {
    if (quotes.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox_rounded, size: 48, color: const Color(0xFF5B6F7F).withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  'Bu personele ait kayıtlı teklif bulunmuyor.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF5B6F7F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF6F8FA),
            child: Row(
              children: [
                Text(
                  'Teklif Listesi (${quotes.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Color(0xFF17304C),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: quotes.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (ctx, index) {
              final q = quotes[index];
              final fmt = NumberFormat.currency(
                locale: 'tr_TR',
                symbol: q.displayUnit == 'USDTRY'
                    ? r'$ '
                    : q.displayUnit == 'EURTRY'
                    ? 'EUR '
                    : 'TL ',
                decimalDigits: 2,
              );
              return ListTile(
                onTap: () => _openQuoteReview(q),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Row(
                  children: [
                    Text(
                      q.code,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF17304C)),
                    ),
                    if (q.revisionCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4E0),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE3B86C)),
                        ),
                        child: Text(
                          'Rev ${q.revisionCount}',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF9D5C1D), fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        q.customerCompany.isEmpty ? q.customerName : '${q.customerCompany} - ${q.customerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF5B6F7F)),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Text(
                        DateFormat('dd.MM.yyyy', 'tr_TR').format(q.createdAt),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF5B6F7F), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      _StatusChip(status: q.status),
                      if (q.emailSentAt != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.email_rounded, size: 14, color: Color(0xFF2B82C9)),
                      ],
                    ],
                  ),
                ),
                trailing: Text(
                  fmt.format(q.totalFor(q.displayUnit)),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF17304C)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openQuoteReview(Quote quote) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuoteReviewPage(
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
    _loadData();
  }
}

class _WorkspaceMetricCard extends StatelessWidget {
  const _WorkspaceMetricCard({
    required this.width,
    required this.label,
    required this.value,
    required this.subText,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final String subText;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF5B6F7F)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF17304C)),
                  ),
                  Text(
                    subText,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
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

class _ActionQuoteTile extends StatelessWidget {
  const _ActionQuoteTile({
    required this.quote,
    required this.actionText,
    required this.icon,
    required this.btnColor,
    required this.onTap,
  });

  final Quote quote;
  final String actionText;
  final IconData icon;
  final Color btnColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8C88B)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${quote.code} — ${quote.customerCompany.isEmpty ? quote.customerName : quote.customerCompany}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: Color(0xFF17304C)),
                ),
                Text(
                  quote.title.isEmpty ? 'Başlıksız teklif' : quote.title,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF5B6F7F), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 14),
            label: Text(actionText),
            style: FilledButton.styleFrom(
              backgroundColor: btnColor,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final QuoteStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      QuoteStatus.draft => (const Color(0xFFF1F4F8), const Color(0xFF5B6F7F)),
      QuoteStatus.pending => (const Color(0xFFFFF4E0), const Color(0xFF8B5918)),
      QuoteStatus.approved => (const Color(0xFFE6F2FB), const Color(0xFF2B82C9)),
      QuoteStatus.accepted => (const Color(0xFFE5F5EE), const Color(0xFF29956F)),
      QuoteStatus.rejected => (const Color(0xFFFBE8E8), const Color(0xFF9D2C2C)),
      QuoteStatus.cancelled => (const Color(0xFFF3EFEA), const Color(0xFF705C49)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.displayLabel,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}
