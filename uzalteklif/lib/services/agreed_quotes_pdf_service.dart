import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/cari_account.dart';
import '../models/quote.dart';
import 'pdf_file_saver_stub.dart'
    if (dart.library.io) 'pdf_file_saver_io.dart'
    if (dart.library.html) 'pdf_file_saver_web.dart';

class AgreedQuotesPdfService {
  const AgreedQuotesPdfService();

  Future<String?> exportForCari({
    required CariAccount cari,
    required List<Quote> quotes,
  }) async {
    final bytes = await _build(cari: cari, quotes: quotes);
    return savePdfFile(
      fileName: 'anlasilan-teklifler-${cari.id}.pdf',
      bytes: Uint8List.fromList(bytes),
    );
  }

  Future<List<int>> _build({
    required CariAccount cari,
    required List<Quote> quotes,
  }) async {
    final sorted = List<Quote>.from(quotes)
      ..sort((a, b) {
        final aDate = a.acceptedAt ?? a.approvedAt ?? a.createdAt;
        final bDate = b.acceptedAt ?? b.approvedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });
    final totalTl = sorted.fold<double>(
      0,
      (sum, q) => sum + (q.acceptedTotalTl ?? 0),
    );
    final money = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: 'TL ',
      decimalDigits: 2,
    );
    final dt = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');

    final doc = pw.Document(title: 'Anlasilan Teklifler');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'Anlasilan Teklif Listesi',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Cari: ${cari.menuLabel}'),
          pw.Text('Rapor tarihi: ${dt.format(DateTime.now())}'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: const [
              'Teklif No',
              'Baslik',
              'Anlasma Tarihi',
              'Onaylayan',
              'Anlasilan Tutar',
              'TL Karsiligi',
            ],
            data: sorted
                .map(
                  (q) => [
                    q.code,
                    q.title.trim().isEmpty ? '-' : q.title.trim(),
                    dt.format(q.acceptedAt ?? q.approvedAt ?? q.createdAt),
                    q.approvedByName.trim().isEmpty ? '-' : q.approvedByName,
                    _formatAcceptedRaw(q),
                    money.format(q.acceptedTotalTl ?? 0),
                  ],
                )
                .toList(growable: false),
          ),
          pw.SizedBox(height: 8),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Toplam anlasilan tutar: ${money.format(totalTl)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  String _formatAcceptedRaw(Quote quote) {
    final amount = quote.acceptedAmount;
    if (amount == null) return '-';
    final code = quote.acceptedCurrencyCode.trim().isEmpty
        ? 'TL'
        : quote.acceptedCurrencyCode.trim();
    final symbol = switch (code) {
      'USDTRY' => r'$ ',
      'EURTRY' => 'EUR ',
      _ => 'TL ',
    };
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }
}
