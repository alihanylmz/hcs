import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/quote.dart';
import '../models/quote_revision.dart';
import '../services/quote_repository.dart';

/// Bir teklifin gecmis hallerini gosteren alt sayfa (bottom sheet).
///
/// Veri, `quote_revisions` tablosundan geliyor - teklif her guncellendiginde
/// veritabani otomatik olarak (uygulama hic mudahale etmeden) o anki halini
/// buraya kopyaliyor. Kullanicinin "revize edince onceki teklifle bag
/// tamamen kopuyor" hissine cozum: artik "Rev N" rozetine dokununca o ana
/// kadarki tum onceki halleri (tarih, revizyon no, tutar, durum) gorebiliyor
/// ve birine dokununca salt okunur ozetini acabiliyor.
/// "Bu sürüme dön" ile bir revizyon geri yüklenirse, o yeni (geri
/// yüklenmiş) [Quote] döner - çağıran taraf kendi `_quote` durumunu
/// güncelleyebilsin diye. Geri yükleme yapılmadan kapatılırsa `null` döner.
Future<Quote?> showQuoteRevisionHistorySheet(
  BuildContext context, {
  required QuoteRepository quoteRepository,
  required Quote currentQuote,
}) {
  return showModalBottomSheet<Quote?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _RevisionHistorySheet(
      quoteRepository: quoteRepository,
      currentQuote: currentQuote,
    ),
  );
}

class _RevisionHistorySheet extends StatefulWidget {
  const _RevisionHistorySheet({
    required this.quoteRepository,
    required this.currentQuote,
  });

  final QuoteRepository quoteRepository;
  final Quote currentQuote;

  @override
  State<_RevisionHistorySheet> createState() => _RevisionHistorySheetState();
}

class _RevisionHistorySheetState extends State<_RevisionHistorySheet> {
  late Future<List<QuoteRevision>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.quoteRepository.fetchRevisions(widget.currentQuote.id);
  }

  String _friendly(DateTime dt) =>
      DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(dt);

  String _statusLabel(QuoteStatus status) {
    switch (status) {
      case QuoteStatus.draft:
        return 'Taslak';
      case QuoteStatus.approvalPending:
        return 'Onay Bekliyor';
      case QuoteStatus.approved:
        return 'Onaylandı';
      case QuoteStatus.sent:
        return 'Gönderildi';
      case QuoteStatus.viewed:
        return 'Görüntülendi';
      case QuoteStatus.negotiating:
        return 'Pazarlık';
      case QuoteStatus.won:
        return 'Kazanıldı';
      case QuoteStatus.lost:
        return 'Kaybedildi';
      case QuoteStatus.expired:
        return 'Süresi Doldu';
      case QuoteStatus.cancelled:
        return 'İptal';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaHeight = MediaQuery.sizeOf(context).height;
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: mediaHeight * 0.85),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Revizyon Geçmişi',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.currentQuote.code} teklifinin geçmiş halleri',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: FutureBuilder<List<QuoteRevision>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final revisions = snapshot.data ?? const <QuoteRevision>[];
                  if (revisions.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Bu teklif için kayıtlı bir geçmiş bulunamadı (ya '
                        'henüz hiç güncellenmedi, ya da geçmişi görüntüleme '
                        'yetkiniz yok).',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    itemCount: revisions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final revision = revisions[index];
                      final snapshotQuote = revision.resolvedQuote;
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFFF4E0),
                            child: Text(
                              'R${revision.revisionNo}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF9D5C1D),
                              ),
                            ),
                          ),
                          title: Text(
                            snapshotQuote.formattedTotal(
                              snapshotQuote.displayUnit,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${_friendly(revision.createdAt)} · '
                            '${_statusLabel(snapshotQuote.status)} · '
                            '${snapshotQuote.items.length} kalem',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () =>
                              _openSnapshot(context, snapshotQuote, revision),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSnapshot(
    BuildContext context,
    Quote snapshotQuote,
    QuoteRevision revision,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Rev ${revision.revisionNo} — ${_friendly(revision.createdAt)}',
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Durum: ${_statusLabel(snapshotQuote.status)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toplam: ${snapshotQuote.formattedTotal(snapshotQuote.displayUnit)}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Kalemler',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (snapshotQuote.items.isEmpty)
                  const Text('Kalem yok.')
                else
                  ...snapshotQuote.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.documentDescription.isEmpty
                                  ? item.resolvedProductCode
                                  : item.documentDescription,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${item.quantity} ${item.unit}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _restoreRevision(revision);
            },
            icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
            label: const Text('Bu sürüme dön'),
          ),
        ],
      ),
    );
  }

  /// Secilen gecmis surumu tekrar aktif teklife yukler ve alt sayfayi
  /// (bottom sheet) geri yuklenmis teklifle kapatir - cagiran taraf
  /// (`showQuoteRevisionHistorySheet`in donen degeri) kendi `_quote`
  /// durumunu bununla guncelleyebilsin diye.
  Future<void> _restoreRevision(QuoteRevision revision) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rev ${revision.revisionNo} sürümüne dönülsün mü?'),
        content: Text(
          'Bu, teklifi Rev ${revision.revisionNo} tarihindeki '
          '(${_friendly(revision.createdAt)}) kalemlere ve koşullara geri '
          'döndürür; teklif tekrar taslak durumuna alınır. Mevcut hali de '
          'ayrı bir revizyon olarak geçmişte saklı kalır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Geri yükle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final restored = revision.resolvedQuote.copyWith(
        status: QuoteStatus.draft,
        revisionCount: widget.currentQuote.revisionCount + 1,
        updatedAt: widget.currentQuote.updatedAt,
        approvalNote:
            'Rev ${revision.revisionNo} sürümünden geri yüklendi '
            '(${_friendly(DateTime.now())}).',
      );
      final saved = await widget.quoteRepository.saveQuote(restored);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Geri yükleme başarısız: $error')),
        );
      }
    }
  }
}
