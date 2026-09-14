import 'quote.dart';

/// `quote_revisions` tablosundaki bir satir: bir teklif her guncellendiginde
/// (veritabani tetikleyicisi `quotes_capture_revision` sayesinde) o ANDAKI
/// (henuz uzerine yazilmamis) hali otomatik olarak burada saklaniyor.
///
/// Bu tablo ve tetikleyici zaten vardi (bkz. `uzalteklif/supabase/schema.sql`),
/// sadece Flutter tarafinda hic gosterilmiyordu - kullanicinin "revize
/// edince onceki teklifle bagi tamamen kopuyor" hissinin gercek nedeni
/// buydu: veri kaybolmuyordu, sadece hicbir yerde goruntulenmiyordu.
class QuoteRevision {
  const QuoteRevision({
    required this.id,
    required this.quoteId,
    required this.code,
    required this.revisionNo,
    required this.snapshot,
    required this.createdAt,
    this.changedBy,
  });

  final String id;
  final String quoteId;
  final String code;
  final int revisionNo;
  final Map<String, dynamic> snapshot;
  final DateTime createdAt;
  final String? changedBy;

  /// Snapshot'i gercek bir [Quote] nesnesine coz - boylece mevcut teklif
  /// kart/ozet widget'lari degistirilmeden, o anki halini gostermek icin
  /// yeniden kullanilabilir.
  Quote get resolvedQuote => Quote.fromJson(snapshot);

  factory QuoteRevision.fromJson(Map<String, dynamic> json) {
    return QuoteRevision(
      id: json['id'] as String,
      quoteId: json['quote_id'] as String,
      code: (json['code'] as String?) ?? '',
      revisionNo: (json['revision_no'] as num?)?.toInt() ?? 0,
      snapshot: Map<String, dynamic>.from(
        json['snapshot'] as Map<dynamic, dynamic>? ?? const {},
      ),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      changedBy: json['changed_by'] as String?,
    );
  }
}
