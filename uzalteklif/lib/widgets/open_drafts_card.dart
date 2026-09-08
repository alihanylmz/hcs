import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/quote.dart';

/// Calisma masasinda, henuz gonderilmemis tekliflerin listesi.
///
/// Takvimin yanina, ayri bir panel olarak duruyor. Takvim "ne zaman" sorusunu,
/// bu panel "elimde ne var" sorusunu cevapliyor; ikisini tek karta yigmak
/// yerine yan yana koymak ekrani okunur tutuyor.
class OpenDraftsCard extends StatelessWidget {
  const OpenDraftsCard({
    super.key,
    required this.quotes,
    required this.onQuoteTap,
    this.maxItems = 6,
    this.today,
  });

  final List<Quote> quotes;
  final ValueChanged<Quote> onQuoteTap;

  /// Panel uzayip sayfayi bozmasin diye gosterilen satir sayisi sinirli.
  final int maxItems;

  /// Testlerde sabitlemek icin; null ise bugun kullanilir.
  final DateTime? today;

  static const _ink = Color(0xFF17304C);
  static const _slate = Color(0xFF5B6F7F);
  static const _stale = Color(0xFFC2410C);

  /// Bir haftadan uzun suredir taslakta duran teklif ya unutulmus ya da
  /// sistem disinda gonderilmis demektir; ikisi de gorulmeli.
  static const _staleDays = 7;

  List<Quote> get _drafts {
    final list = quotes
        .where((q) => q.status == QuoteStatus.draft)
        .toList(growable: false);
    // En eski taslak en ustte: bekleyen is once gorulmeli.
    final sorted = [...list]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final now = today ?? DateTime.now();
    final drafts = _drafts;
    final shown = drafts.take(maxItems).toList(growable: false);
    final money = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '',
      decimalDigits: 0,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD7DEE6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.drafts_outlined,
                  size: 18,
                  color: _ink,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Gonderilmemis teklifler',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: _ink,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF3F8),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${drafts.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: _ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (drafts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'Bekleyen taslak yok.',
                  style: TextStyle(fontSize: 12, color: _slate),
                ),
              )
            else
              for (final q in shown) _row(q, now, money),
            if (drafts.length > shown.length) ...[
              const SizedBox(height: 6),
              Text(
                've ${drafts.length - shown.length} taslak daha',
                style: const TextStyle(fontSize: 11, color: _slate),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(Quote q, DateTime now, NumberFormat money) {
    final days = now.difference(q.createdAt).inDays;
    final isStale = days >= _staleDays;
    final company = q.customerCompany.trim().isEmpty
        ? q.customerName.trim().isEmpty
              ? q.code
              : q.customerName.trim()
        : q.customerCompany.trim();

    return InkWell(
      key: ValueKey('draft-row-${q.id}'),
      onTap: () => onQuoteTap(q),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    days == 0
                        ? 'bugun olusturuldu'
                        : days == 1
                        ? 'dun olusturuldu'
                        : '$days gundur bekliyor',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isStale ? FontWeight.w800 : FontWeight.w600,
                      color: isStale ? _stale : _slate,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              money.format(q.totalFor(q.displayUnit)),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: _ink,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
