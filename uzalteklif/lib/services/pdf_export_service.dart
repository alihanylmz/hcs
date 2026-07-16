import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../config/app_config.dart';
import '../models/quote.dart';
import 'pdf_file_saver_stub.dart'
    if (dart.library.io) 'pdf_file_saver_io.dart'
    if (dart.library.html) 'pdf_file_saver_web.dart';

/// `compute` ile ikinci isolate'e aktarilan ham asset + teklif verisi.
class _PdfIsolatePayload {
  const _PdfIsolatePayload({
    required this.quoteJson,
    required this.fontBytes,
    required this.logoBytes,
    this.stampBytes,
  });

  final Map<String, dynamic> quoteJson;
  final Uint8List fontBytes;
  final Uint8List logoBytes;
  final Uint8List? stampBytes;
}

Future<Uint8List> _pdfExportComputeEntry(_PdfIsolatePayload payload) async {
  await initializeDateFormatting('tr_TR');
  final quote = Quote.fromJson(payload.quoteJson);
  pw.Font? baseFont;
  if (payload.fontBytes.isNotEmpty) {
    try {
      baseFont = pw.Font.ttf(ByteData.sublistView(payload.fontBytes));
    } catch (_) {
      baseFont = null;
    }
  }
  final logo = payload.logoBytes.isEmpty
      ? null
      : pw.MemoryImage(payload.logoBytes);
  final stampRaw = payload.stampBytes;
  final stamp = (stampRaw == null || stampRaw.isEmpty)
      ? null
      : pw.MemoryImage(stampRaw);
  return const PdfExportService()._composePdfBytes(
    quote,
    baseFont,
    logo,
    stamp,
  );
}

/// Kurumsal teklif dosyasi uretir.
///
/// Tasarim A4 uzerine kurulmustur; her sayfada sabit bir baslik (logo + firma
/// kimlik bilgileri) ve alt bilgi (iletisim seridi + sayfa numarasi) yer alir.
/// Tek akisli bir `MultiPage` kullanilir; kalem sayisi arttikca sayfalar
/// otomatik olarak eklenir.
class PdfExportService {
  const PdfExportService();

  // Corporate palette
  static const _ink = PdfColor.fromInt(0xFF15304C);
  static const _accent = PdfColor.fromInt(0xFFB8843C);
  static const _slate = PdfColor.fromInt(0xFF5A6B7A);
  static const _mist = PdfColor.fromInt(0xFFD9DFE6);
  static const _hairline = PdfColor.fromInt(0xFFE4E8EC);
  static const _paper = PdfColor.fromInt(0xFFFFFFFF);
  static const _zebra = PdfColor.fromInt(0xFFF6F8FA);
  static const _chipBg = PdfColor.fromInt(0xFFF1F4F8);
  static const _categoryBg = PdfColor.fromInt(0xFFC6E2FF);
  static const _tableHeaderBg = PdfColor.fromInt(0xFFCFCFCF);

  /// [onAfterSaveLocation] secildi ve PDF baytlari uretilmeye baslaninca (opsiyonel).
  Future<String?> exportQuote(
    Quote quote, {
    void Function()? onAfterSaveLocation,
  }) async {
    onAfterSaveLocation?.call();
    final bytes = await buildQuotePdfBytes(quote);
    return savePdfFile(
      fileName: '${_quoteFileNameBase(quote)}.pdf',
      bytes: bytes,
      openAfterSave: true,
      archiveQuoteCode: quote.code,
    );
  }

  Future<Uint8List> buildQuotePdfBytes(Quote quote) async {
    var fontBytes = Uint8List(0);
    try {
      final data = await rootBundle.load('assets/fonts/NotoSans.ttf');
      fontBytes = data.buffer.asUint8List();
    } catch (_) {}

    var logoBytes = Uint8List(0);
    try {
      final data = await rootBundle.load('lib/assest/logo/uzal.png');
      logoBytes = data.buffer.asUint8List();
    } catch (_) {}

    // Mutabakat (accepted) PDF'lerinde kaşe/resim kullanilmaz; yalnizca metin
    // onay alani yeterlidir.
    const Uint8List? stampBytes = null;

    final payload = _PdfIsolatePayload(
      quoteJson: quote.toJson(),
      fontBytes: fontBytes,
      logoBytes: logoBytes,
      stampBytes: stampBytes,
    );

    // Bir kare boyunca UI nefes alsin; ardindan isolate'e gonder.
    await Future<void>.delayed(Duration.zero);
    return compute(_pdfExportComputeEntry, payload);
  }

  Future<String?> exportMaterialRequest(
    Quote quote, {
    void Function()? onAfterSaveLocation,
  }) async {
    onAfterSaveLocation?.call();
    final bytes = await buildMaterialRequestPdfBytes(quote);
    return savePdfFile(
      fileName: '${_quoteFileNameBase(quote)} - istek-listesi.pdf',
      bytes: bytes,
      openAfterSave: true,
    );
  }

  Future<Uint8List> buildMaterialRequestPdfBytes(Quote quote) async {
    pw.Font? baseFont;
    try {
      final data = await rootBundle.load('assets/fonts/NotoSans.ttf');
      baseFont = pw.Font.ttf(data);
    } catch (_) {
      baseFont = null;
    }

    pw.MemoryImage? logo;
    try {
      final data = await rootBundle.load('lib/assest/logo/uzal.png');
      logo = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      logo = null;
    }

    final theme = baseFont == null
        ? pw.ThemeData()
        : pw.ThemeData.withFont(base: baseFont, bold: baseFont);
    final doc = pw.Document(
      title: '${quote.code} - Malzeme Istek Listesi',
      author: quote.documentProfile.companyName,
      subject: 'Malzeme Istek Listesi',
      creator: quote.documentProfile.companyName,
      theme: theme,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 32),
        theme: theme,
        header: (ctx) => _buildHeader(quote, logo),
        footer: (ctx) => _buildFooter(ctx, quote),
        build: (ctx) => [
          pw.SizedBox(height: 8),
          _buildMaterialRequestTitleBand(quote),
          pw.SizedBox(height: 14),
          _buildMaterialRequestMeta(quote),
          pw.SizedBox(height: 16),
          ..._buildMaterialRequestItems(quote),
          pw.SizedBox(height: 18),
          _buildMaterialRequestNoteBox(),
        ],
      ),
    );

    return doc.save();
  }

  /// Agir `doc.save()` islemi [compute] ile cagrildigi icin burada kalir.
  Future<Uint8List> _composePdfBytes(
    Quote quote,
    pw.Font? baseFont,
    pw.MemoryImage? logo,
    pw.MemoryImage? stamp,
  ) async {
    final theme = baseFont == null
        ? pw.ThemeData()
        : pw.ThemeData.withFont(base: baseFont, bold: baseFont);
    final displayNote = _cleanNote(quote.note);
    final price = _PriceView.from(quote);

    final doc = pw.Document(
      title: quote.code,
      author: quote.documentProfile.companyName,
      subject: _quoteTopic(quote),
      creator: quote.documentProfile.companyName,
      theme: theme,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 32),
        theme: theme,
        header: (ctx) => _buildHeader(quote, logo),
        footer: (ctx) => _buildFooter(ctx, quote),
        build: (ctx) => [
          pw.SizedBox(height: 6),
          _buildTitleBand(quote),
          pw.SizedBox(height: 16),
          _buildMetaRow(quote, price),
          pw.SizedBox(height: 18),
          _buildPartiesBlock(quote),
          pw.SizedBox(height: 18),
          _buildTermsBlock(quote, displayNote),
          pw.SizedBox(height: 14),
          _buildBankBlock(quote),
          pw.NewPage(),
          ..._buildItemsArea(quote, price),
          if (!quote.hidePrices) ...[
            pw.SizedBox(height: 14),
            _buildTotalsBlock(quote, price),
          ],
          if (quote.status == QuoteStatus.accepted &&
              (quote.acceptedAmount != null ||
                  quote.acceptedTotalTl != null)) ...[
            pw.SizedBox(height: 18),
            _buildAgreementBlock(quote, price),
          ],
          // Accepted: mutabakat kutusu yeter; alt tekrarlayan imza/ANLASILDI
          // bandi ve kaşe alani cikarilmaz.
          if (quote.status != QuoteStatus.accepted) ...[
            pw.SizedBox(height: 24),
            _buildSignatureBlock(quote, stamp),
          ],
        ],
      ),
    );

    return doc.save();
  }

  // -------------------------------------------------------------------------
  // HEADER & FOOTER
  // -------------------------------------------------------------------------

  pw.Widget _buildHeader(Quote quote, pw.MemoryImage? logo) {
    final profile = quote.documentProfile;
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1.4)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 62,
            height: 62,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: _paper,
              border: pw.Border.all(color: _hairline),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            padding: const pw.EdgeInsets.all(6),
            child: logo != null
                ? pw.Image(logo, fit: pw.BoxFit.contain)
                : pw.Text(
                    'UZ',
                    style: pw.TextStyle(
                      color: _ink,
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  profile.companyName,
                  style: pw.TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  profile.companyTagline,
                  style: const pw.TextStyle(color: _slate, fontSize: 9),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _joinNonEmpty(' | ', [profile.companyAddress]),
                  style: const pw.TextStyle(color: _slate, fontSize: 8.5),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _miniMeta('Tel', profile.companyPhone),
              _miniMeta('E-posta', profile.companyEmail),
              _miniMeta('Web', profile.companyWebsite),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _miniMeta(String label, String value) {
    if (value.trim().isEmpty) {
      return pw.SizedBox.shrink();
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 1.5),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label ',
              style: const pw.TextStyle(color: _slate, fontSize: 8),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(
                color: _ink,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context, Quote quote) {
    final profile = quote.documentProfile;
    final leftLine = _joinNonEmpty(' | ', [
      profile.companyName,
      if (profile.companyTaxOffice.isNotEmpty &&
          profile.companyTaxNumber.isNotEmpty)
        '${profile.companyTaxOffice} - ${profile.companyTaxNumber}',
      if (profile.companyMersis.isNotEmpty) 'Mersis: ${profile.companyMersis}',
    ]);
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _hairline, width: 0.8)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              leftLine,
              style: const pw.TextStyle(color: _slate, fontSize: 7.5),
            ),
          ),
          pw.Text(
            '${quote.code}   Sayfa ${context.pageNumber}/${context.pagesCount}',
            style: pw.TextStyle(
              color: _ink,
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // TITLE & META
  // -------------------------------------------------------------------------

  pw.Widget _buildTitleBand(Quote quote) {
    final shareCard = _buildShareCard(quote);
    final titleColumn = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: pw.BoxDecoration(
            color: _accent,
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.Text(
            'TEKLIF / QUOTATION',
            style: pw.TextStyle(
              color: _paper,
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.6,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          _quoteCoverTitle(quote),
          style: pw.TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            lineSpacing: 1.5,
          ),
        ),
      ],
    );

    if (shareCard == null) {
      return titleColumn;
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: titleColumn),
        pw.SizedBox(width: 14),
        shareCard,
      ],
    );
  }

  String _quoteFileNameBase(Quote quote) {
    final company = _quoteCompany(quote);
    final topic = _quoteTopic(quote);
    final code = quote.code.trim();
    final parts = [
      if (company.isNotEmpty) company,
      if (topic.isNotEmpty) topic,
      if (code.isNotEmpty) code,
    ];
    return parts.isEmpty ? 'teklif' : parts.join(' - ');
  }

  String _quoteCoverTitle(Quote quote) {
    final topic = _quoteTopic(quote);
    return topic.isEmpty ? 'Teklif' : topic;
  }

  String _quoteTopic(Quote quote) {
    final title = quote.title.trim();
    if (title.isEmpty) return '';

    final code = quote.code.trim();
    final company = _quoteCompany(quote);
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

  String _quoteCompany(Quote quote) {
    return quote.customerCompany.trim().isNotEmpty
        ? quote.customerCompany.trim()
        : quote.customerName.trim();
  }

  /// PDF'in sag ust koselerinde yer alan QR + kisa link kartini uretir.
  /// Teklifin paylasim tokeni yoksa (eski kayitlar) null doner; bu durumda
  /// baslik eski (yalniz sol) duzenini korur.
  pw.Widget? _buildShareCard(Quote quote) {
    final token = quote.publicToken.trim();
    if (token.isEmpty) return null;

    final baseUrl = AppConfig.normalizedPublicQuoteBaseUrl;
    final shareUrl = quote.publicShareUrl(baseUrl);
    if (shareUrl.isEmpty) return null;

    final hostLabel = _extractHostLabel(baseUrl);
    final slug = quote.publicShareSlug;

    final qr = pw.Container(
      width: 76,
      height: 76,
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
        color: _paper,
        border: pw.Border.all(color: _hairline),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.BarcodeWidget(
        data: shareUrl,
        barcode: pw.Barcode.qrCode(
          errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium,
        ),
        color: _ink,
        drawText: false,
      ),
    );

    return pw.Container(
      width: 170,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: _paper,
        border: pw.Border.all(color: _hairline),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.UrlLink(destination: shareUrl, child: qr),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'ONLINE TEKLIF',
                  style: pw.TextStyle(
                    color: _accent,
                    fontSize: 7,
                    letterSpacing: 1.2,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Karekodu okutun',
                  style: const pw.TextStyle(color: _slate, fontSize: 7.5),
                ),
                pw.SizedBox(height: 6),
                if (hostLabel.isNotEmpty)
                  pw.Text(
                    hostLabel,
                    style: pw.TextStyle(
                      color: _ink,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                pw.UrlLink(
                  destination: shareUrl,
                  child: pw.Text(
                    slug,
                    style: pw.TextStyle(
                      color: _ink,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// `https://uzalteknik.com/t` gibi bir URL'den yalnizca host kismini
  /// ("uzalteknik.com") cikarir. Kullanici yanlis bir deger girdiyse ham
  /// metni doner, bos ise bos string doner.
  static String _extractHostLabel(String baseUrl) {
    if (baseUrl.isEmpty) return '';
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) return baseUrl;
    return uri.host;
  }

  pw.Widget _buildMetaRow(Quote quote, _PriceView price) {
    final profile = quote.documentProfile;
    final entries = <MapEntry<String, String>>[
      MapEntry('Teklif No', quote.code),
      MapEntry('Tarih', quote.formattedDate),
      MapEntry('Gecerlilik', _valueOrDash(profile.validityText)),
      if (!quote.hidePrices) MapEntry('Para Birimi', price.displaySymbol),
    ];
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _chipBg,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _hairline),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: pw.Row(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            pw.Expanded(child: _metaCell(entries[i].key, entries[i].value)),
            if (i != entries.length - 1)
              pw.Container(
                width: 1,
                height: 28,
                color: _hairline,
                margin: const pw.EdgeInsets.symmetric(horizontal: 10),
              ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildMaterialRequestTitleBand(Quote quote) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: pw.BoxDecoration(
        color: _ink,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'MALZEME ISTEK LISTESI',
            style: pw.TextStyle(
              color: _paper,
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _quoteTopic(quote).isEmpty ? quote.code : _quoteTopic(quote),
            style: const pw.TextStyle(color: _paper, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMaterialRequestMeta(Quote quote) {
    final supplier = _quoteCompany(quote);
    final entries = <MapEntry<String, String>>[
      MapEntry('Istek No', quote.code),
      MapEntry('Tarih', quote.formattedDate),
      MapEntry('Tedarikci', supplier.isEmpty ? '-' : supplier),
      MapEntry(
        'Hazirlayan',
        _valueOrDash(quote.documentProfile.preparedByName),
      ),
    ];
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _chipBg,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _hairline),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: pw.Row(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            pw.Expanded(child: _metaCell(entries[i].key, entries[i].value)),
            if (i != entries.length - 1)
              pw.Container(
                width: 1,
                height: 28,
                color: _hairline,
                margin: const pw.EdgeInsets.symmetric(horizontal: 10),
              ),
          ],
        ],
      ),
    );
  }

  pw.Widget _metaCell(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label.toUpperCase(),
          style: pw.TextStyle(
            color: _slate,
            fontSize: 7.5,
            letterSpacing: 0.8,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: _ink,
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // PARTIES
  // -------------------------------------------------------------------------

  pw.Widget _buildPartiesBlock(Quote quote) {
    final profile = quote.documentProfile;
    final preparedCard = _partyCard(
      label: 'TEKLIF EDEN',
      title: profile.companyName,
      rows: [
        _PartyRow('Hazirlayan', _valueOrDash(profile.preparedByName)),
        _PartyRow('Unvan', _valueOrDash(profile.preparedByTitle)),
        _PartyRow('Telefon', _valueOrDash(profile.preparedByPhone)),
        _PartyRow('E-posta', _valueOrDash(profile.preparedByEmail)),
        if (profile.companyTaxOffice.isNotEmpty ||
            profile.companyTaxNumber.isNotEmpty)
          _PartyRow(
            'Vergi',
            _joinNonEmpty(' / ', [
              profile.companyTaxOffice,
              profile.companyTaxNumber,
            ]),
          ),
      ],
      accent: _ink,
    );
    final customerCard = _partyCard(
      label: 'ALICI',
      title: _valueOrDash(quote.customerCompany),
      rows: [
        _PartyRow('Yetkili', _valueOrDash(quote.customerName)),
        _PartyRow('Unvan', _valueOrDash(profile.customerContactTitle)),
        _PartyRow('Telefon', _valueOrDash(profile.customerPhone)),
        _PartyRow('E-posta', _valueOrDash(profile.customerEmail)),
      ],
      accent: _accent,
    );
    return _equalColumns(preparedCard, customerCard);
  }

  pw.Widget _partyCard({
    required String label,
    required String title,
    required List<_PartyRow> rows,
    required PdfColor accent,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _paper,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _hairline),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: accent,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(4),
                topRight: pw.Radius.circular(4),
              ),
            ),
            child: pw.Text(
              label,
              style: pw.TextStyle(
                color: _paper,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.4,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                for (final row in rows) ...[
                  _partyRow(row.label, row.value),
                  pw.SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _partyRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 58,
          child: pw.Text(
            label,
            style: const pw.TextStyle(color: _slate, fontSize: 9),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              color: _ink,
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // ITEMS TABLE
  // -------------------------------------------------------------------------

  /// Kalem bolgesini uretir. Eger teklifte kategori tanimlanmissa her
  /// kategori icin ayri baslik + tablo + ara toplam bandi cikartir; yoksa
  /// eski tek tablo duzeni korunur.
  List<pw.Widget> _buildItemsArea(Quote quote, _PriceView price) {
    final groups = quote.sectionedItems;
    final hasRealSections =
        groups.any((g) => g.section != null) || quote.sections.isNotEmpty;

    if (!hasRealSections) {
      return [_buildSingleItemsTable(quote.items, quote, price, startIndex: 0)];
    }

    final widgets = <pw.Widget>[];
    var runningIndex = 0;
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      if (i > 0) widgets.add(pw.SizedBox(height: 10));
      widgets.add(_buildSectionBanner(group.displayName, group.items.length));
      widgets.add(
        _buildSingleItemsTable(
          group.items,
          quote,
          price,
          startIndex: runningIndex,
        ),
      );
      if (!quote.hidePrices) {
        widgets.add(
          _buildSectionSubtotalBanner(
            group.displayName,
            price.fmtAmount(group.subtotalTl),
          ),
        );
      }
      runningIndex += group.items.length;
    }
    return widgets;
  }

  /// Bir kalem listesi icin bagimsiz bir pw.Table olusturur. Fiyatli ve
  /// sade (hidePrices) modlarin ortak uretim noktasidir; `startIndex` global
  /// numaralandirmayi korumak icin kullanilir.
  pw.Widget _buildSingleItemsTable(
    List<QuoteLineItem> items,
    Quote quote,
    _PriceView price, {
    required int startIndex,
  }) {
    if (quote.hidePrices) {
      final rows = <List<String>>[];
      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        rows.add([
          '${startIndex + i + 1}',
          item.description,
          item.unit,
          _formatQuantity(item.quantity),
        ]);
      }
      return pw.Table(
        border: pw.TableBorder(
          top: const pw.BorderSide(color: _ink, width: 0.6),
          bottom: const pw.BorderSide(color: _ink, width: 0.6),
          left: const pw.BorderSide(color: _ink, width: 0.6),
          right: const pw.BorderSide(color: _ink, width: 0.6),
          horizontalInside: const pw.BorderSide(color: _hairline, width: 0.5),
          verticalInside: const pw.BorderSide(color: _hairline, width: 0.5),
        ),
        columnWidths: const {
          0: pw.FixedColumnWidth(22),
          1: pw.FlexColumnWidth(6),
          2: pw.FixedColumnWidth(56),
          3: pw.FixedColumnWidth(72),
        },
        children: [
          _tableHeaderRow(const [
            '#',
            'Aciklama',
            'Birim',
            'Miktar',
          ], repeat: true),
          for (var i = 0; i < rows.length; i++)
            _tableDataRow(rows[i], isZebra: i.isOdd, totalColumnIndex: -1),
        ],
      );
    }

    final rows = <List<String>>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      rows.add([
        '${startIndex + i + 1}',
        item.description,
        item.unit,
        _formatQuantity(item.quantity),
        price.fmtAmount(quote.effectiveUnitPriceTl(item)),
        price.fmtAmount(quote.effectiveNetUnitPriceTl(item)),
        price.fmtAmount(quote.effectiveLineTotalTl(item)),
      ]);
    }

    return pw.Table(
      border: pw.TableBorder(
        top: const pw.BorderSide(color: _ink, width: 0.6),
        bottom: const pw.BorderSide(color: _ink, width: 0.6),
        left: const pw.BorderSide(color: _ink, width: 0.6),
        right: const pw.BorderSide(color: _ink, width: 0.6),
        horizontalInside: const pw.BorderSide(color: _hairline, width: 0.5),
        verticalInside: const pw.BorderSide(color: _hairline, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(22),
        1: pw.FlexColumnWidth(4.2),
        2: pw.FixedColumnWidth(36),
        3: pw.FixedColumnWidth(42),
        4: pw.FlexColumnWidth(1.5),
        5: pw.FlexColumnWidth(1.5),
        6: pw.FlexColumnWidth(1.6),
      },
      children: [
        _tableHeaderRow([
          '#',
          'Aciklama',
          'Birim',
          'Miktar',
          'Birim Fiyat\n(${price.displaySymbol})',
          'Net Birim\n(${price.displaySymbol})',
          'Toplam\n(${price.displaySymbol})',
        ], repeat: true),
        for (var i = 0; i < rows.length; i++)
          _tableDataRow(rows[i], isZebra: i.isOdd, totalColumnIndex: 6),
      ],
    );
  }

  /// Kategori ustundeki "DDC Kontrolleri - 5 kalem" seklindeki kurumsal bant.
  pw.Widget _buildSectionBanner(String name, int itemCount) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _categoryBg,
        border: pw.Border.all(color: _hairline),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 3,
            height: 10,
            color: _accent,
            margin: const pw.EdgeInsets.only(right: 8),
          ),
          pw.Expanded(
            child: pw.Text(
              name.toUpperCase(),
              style: pw.TextStyle(
                color: _ink,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.6,
              ),
            ),
          ),
          pw.Text(
            '$itemCount kalem',
            style: const pw.TextStyle(color: _slate, fontSize: 8.5),
          ),
        ],
      ),
    );
  }

  /// Kategori tablosunun hemen altindaki "Ara Toplam: DDC ... | 602,57 EUR"
  /// bandini uretir. hidePrices modunda cagrilmaz.
  pw.Widget _buildSectionSubtotalBanner(String name, String amount) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const pw.BoxDecoration(color: _categoryBg),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '$name - Ara Toplam',
            style: pw.TextStyle(
              color: _ink,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          pw.Text(
            amount,
            style: pw.TextStyle(
              color: _ink,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _buildMaterialRequestItems(Quote quote) {
    final groups = quote.sectionedItems;
    final hasRealSections =
        groups.any((g) => g.section != null) || quote.sections.isNotEmpty;

    if (!hasRealSections) {
      return [_buildMaterialRequestTable(quote.items, startIndex: 0)];
    }

    final widgets = <pw.Widget>[];
    var runningIndex = 0;
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      if (i > 0) widgets.add(pw.SizedBox(height: 10));
      widgets.add(_buildSectionBanner(group.displayName, group.items.length));
      widgets.add(
        _buildMaterialRequestTable(group.items, startIndex: runningIndex),
      );
      runningIndex += group.items.length;
    }
    return widgets;
  }

  pw.Widget _buildMaterialRequestTable(
    List<QuoteLineItem> items, {
    required int startIndex,
  }) {
    final rows = <List<String>>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      rows.add([
        '${startIndex + i + 1}',
        item.description,
        _formatQuantity(item.quantity),
        item.unit,
        '',
      ]);
    }

    return pw.Table(
      border: pw.TableBorder(
        top: const pw.BorderSide(color: _ink, width: 0.6),
        bottom: const pw.BorderSide(color: _ink, width: 0.6),
        left: const pw.BorderSide(color: _ink, width: 0.6),
        right: const pw.BorderSide(color: _ink, width: 0.6),
        horizontalInside: const pw.BorderSide(color: _hairline, width: 0.5),
        verticalInside: const pw.BorderSide(color: _hairline, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FixedColumnWidth(24),
        1: pw.FlexColumnWidth(5.2),
        2: pw.FixedColumnWidth(58),
        3: pw.FixedColumnWidth(48),
        4: pw.FlexColumnWidth(1.8),
      },
      children: [
        _tableHeaderRow(const [
          '#',
          'Malzeme',
          'Miktar',
          'Birim',
          'Not',
        ], repeat: true),
        for (var i = 0; i < rows.length; i++)
          _tableDataRow(rows[i], isZebra: i.isOdd, totalColumnIndex: -1),
      ],
    );
  }

  pw.Widget _buildMaterialRequestNoteBox() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _chipBg,
        border: pw.Border.all(color: _hairline),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        'Bu dokuman malzeme tedarik talebi icindir. Fiyat, iskonto ve toplam bilgisi icermez.',
        style: pw.TextStyle(
          color: _ink,
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.TableRow _tableHeaderRow(List<String> cells, {bool repeat = false}) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: _tableHeaderBg),
      verticalAlignment: pw.TableCellVerticalAlignment.middle,
      repeat: repeat,
      children: [
        for (var i = 0; i < cells.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 7),
            child: pw.Text(
              cells[i],
              textAlign: _dataAlignmentByIndex(i, cells.length),
              style: pw.TextStyle(
                color: _ink,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.2,
                lineSpacing: 1.5,
              ),
            ),
          ),
      ],
    );
  }

  pw.TableRow _tableDataRow(
    List<String> cells, {
    required bool isZebra,
    required int totalColumnIndex,
  }) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: isZebra ? _zebra : _paper),
      children: [
        for (var i = 0; i < cells.length; i++)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 7),
            child: pw.Text(
              cells[i],
              textAlign: _dataAlignmentByIndex(i, cells.length),
              style: pw.TextStyle(
                color: _ink,
                fontSize: 9,
                fontWeight: i == totalColumnIndex
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }

  /// Veri ve baslik hucrelerinin sutun sayisina gore hizalanmasi. 4 sutunlu
  /// sade modda ilk sutun (#), birim ve miktar ortalanir; aciklama sola
  /// hizalanir. 8 sutunlu tam modda fiyat sutunlari saga hizalanir.
  pw.TextAlign _dataAlignmentByIndex(int index, int columnCount) {
    if (columnCount <= 4) {
      switch (index) {
        case 0:
        case 2:
        case 3:
          return pw.TextAlign.center;
        default:
          return pw.TextAlign.left;
      }
    }
    switch (index) {
      case 0:
      case 2:
      case 3:
      case 5:
        return pw.TextAlign.center;
      case 4:
      case 6:
      case 7:
        return pw.TextAlign.right;
      default:
        return pw.TextAlign.left;
    }
  }

  // -------------------------------------------------------------------------
  // TOTALS
  // -------------------------------------------------------------------------

  pw.Widget _buildTotalsBlock(Quote quote, _PriceView price) {
    final profile = quote.documentProfile;
    final subtotalTl = quote.subtotalTl;
    final vatRate = profile.vatRate;
    final vatAmountTl = subtotalTl * (vatRate / 100);
    final grandTotalTl = subtotalTl + vatAmountTl;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: pw.SizedBox()),
        pw.Container(
          width: 260,
          decoration: pw.BoxDecoration(
            color: _paper,
            border: pw.Border.all(color: _hairline),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _totalRow('Ara Toplam', price.fmtAmount(subtotalTl)),
              _totalRow(
                'KDV (%${_formatDiscount(vatRate)})',
                price.fmtAmount(vatAmountTl),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: const pw.BoxDecoration(color: _ink),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'GENEL TOPLAM',
                      style: pw.TextStyle(
                        color: _paper,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    pw.Text(
                      price.fmtAmount(grandTotalTl),
                      style: pw.TextStyle(
                        color: _paper,
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _totalRow(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _hairline)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(color: _slate, fontSize: 9.5),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: _ink,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // TERMS / NOTE / BANK / SIGNATURE
  // -------------------------------------------------------------------------

  pw.Widget _buildTermsBlock(Quote quote, String displayNote) {
    final profile = quote.documentProfile;
    final extraPaymentNote = profile.paymentTerms.trim();
    final paymentLine = extraPaymentNote.isEmpty
        ? quote.paymentSummaryLine
        : '${quote.paymentSummaryLine} | $extraPaymentNote';
    final bullets = <MapEntry<String, String>>[
      MapEntry('Gecerlilik', _valueOrDash(profile.validityText)),
      MapEntry('Odeme', _valueOrDash(paymentLine)),
      MapEntry('Teslim', _valueOrDash(profile.deliveryTerms)),
    ];
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _paper,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _hairline),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Teklif Sartlari'),
          pw.SizedBox(height: 8),
          _equalRow([
            for (final b in bullets) _termItem(b.key, b.value),
          ], gap: 10),
          if (displayNote.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _chipBg,
                borderRadius: pw.BorderRadius.circular(3),
                border: pw.Border.all(color: _hairline),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'NOT',
                    style: pw.TextStyle(
                      color: _slate,
                      fontSize: 7.5,
                      letterSpacing: 1.2,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    displayNote,
                    style: const pw.TextStyle(
                      color: _ink,
                      fontSize: 9.5,
                      lineSpacing: 2.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _termItem(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: _chipBg,
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              color: _accent,
              fontSize: 7.5,
              letterSpacing: 1.0,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: _ink,
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildBankBlock(Quote quote) {
    final profile = quote.documentProfile;
    final hasBank = profile.bankName.isNotEmpty || profile.bankIban.isNotEmpty;
    if (!hasBank) {
      return pw.SizedBox.shrink();
    }
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: _paper,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _hairline),
      ),
      padding: const pw.EdgeInsets.all(12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('Banka Hesap Bilgileri'),
          pw.SizedBox(height: 8),
          _equalColumns(
            _bankColumn([
              _PartyRow(
                'Banka',
                _joinNonEmpty(' / ', [profile.bankName, profile.bankBranch]),
              ),
              _PartyRow('Hesap Adi', profile.bankAccountName),
            ]),
            _bankColumn([
              _PartyRow('IBAN', profile.bankIban),
              if (profile.bankSwift.isNotEmpty)
                _PartyRow('SWIFT', profile.bankSwift),
            ]),
          ),
        ],
      ),
    );
  }

  pw.Widget _bankColumn(List<_PartyRow> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final row in rows) ...[
          _partyRow(row.label, _valueOrDash(row.value)),
          pw.SizedBox(height: 4),
        ],
      ],
    );
  }

  pw.Widget _buildSignatureBlock(Quote quote, pw.MemoryImage? stamp) {
    final profile = quote.documentProfile;
    final signatures = _equalColumns(
      _signatureBox(
        'Teklif Sorumlusu',
        profile.preparedByName,
        profile.preparedByTitle,
        stamp: stamp,
      ),
      _signatureBox(
        'Musteri Yetkilisi',
        quote.customerName,
        profile.customerContactTitle.isEmpty
            ? quote.customerCompany
            : '${profile.customerContactTitle} - ${quote.customerCompany}',
      ),
      gap: 16,
    );

    if (quote.status != QuoteStatus.accepted) {
      return signatures;
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _buildAcceptedBanner(quote),
        pw.SizedBox(height: 10),
        signatures,
      ],
    );
  }

  /// Onaylanan teklifin imza bloğunun üstüne düşen "Sirket Onayi" kurumsal
  /// bandi. Onaylayan kişi + tarih + varsa revizyon numarası yazar.
  pw.Widget _buildAgreementBlock(Quote quote, _PriceView price) {
    final acceptedTl = quote.acceptedTotalTl;
    final acceptedAmount = quote.acceptedAmount;
    final currencyCode = quote.acceptedCurrencyCode.trim().isEmpty
        ? 'TL'
        : quote.acceptedCurrencyCode.trim();
    final displayAmount = acceptedAmount == null
        ? (acceptedTl == null ? '-' : price.fmtAmount(acceptedTl))
        : _formatAcceptedAmount(acceptedAmount, currencyCode);
    final tlLine = acceptedTl == null
        ? ''
        : 'TL karsiligi: ${NumberFormat.currency(locale: 'tr_TR', symbol: 'TL ', decimalDigits: 2).format(acceptedTl)}';
    final note = quote.acceptedNote.trim();
    final date = quote.acceptedAt ?? quote.approvedAt;
    final dateLabel = date == null
        ? DateFormat('dd.MM.yyyy', 'tr_TR').format(DateTime.now())
        : DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(date);

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFFFAF0),
        border: pw.Border.all(color: _accent, width: 1.2),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      padding: const pw.EdgeInsets.all(14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(
            'TICARI MUTABAKAT',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: _accent,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            displayAmount,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: _ink,
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (tlLine.isNotEmpty && currencyCode != 'TL') ...[
            pw.SizedBox(height: 2),
            pw.Text(
              tlLine,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(color: _slate, fontSize: 9),
            ),
          ],
          if (note.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              note,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(color: _slate, fontSize: 9.5),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _paper,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: _hairline),
            ),
            child: pw.Text(
              'Taraflar, bu teklif kapsamindaki urun/hizmetler icin yukaridaki mutabakat tutari uzerinden anlasmaya vardigini kabul eder. Bu alan teklifin ticari kapanis ve karsilikli kabul kaydidir.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(
                color: _ink,
                fontSize: 9.5,
                lineSpacing: 2.0,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          _equalColumns(
            _agreementPartyBox(
              title: 'Firma Onayi',
              name: quote.documentProfile.companyName,
              subtitle: quote.acceptedByName.trim().isEmpty
                  ? quote.approvedByName
                  : quote.acceptedByName,
              dateLabel: dateLabel,
              stamped: true,
            ),
            _agreementPartyBox(
              title: 'Musteri Onayi',
              name: quote.customerCompany,
              subtitle: quote.customerName,
              dateLabel: dateLabel,
              stamped: false,
            ),
            gap: 14,
          ),
        ],
      ),
    );
  }

  pw.Widget _agreementPartyBox({
    required String title,
    required String name,
    required String subtitle,
    required String dateLabel,
    required bool stamped,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: pw.BoxDecoration(
        color: _paper,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _hairline),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              color: stamped ? _accent : _ink,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            _valueOrDash(name),
            style: pw.TextStyle(
              color: _ink,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              subtitle.trim(),
              style: const pw.TextStyle(color: _slate, fontSize: 8.5),
            ),
          ],
          pw.SizedBox(height: 18),
          pw.Container(height: 0.8, color: _mist),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                stamped ? 'Imza / onay' : 'Yetkili imza / e-posta onayi',
                style: const pw.TextStyle(color: _slate, fontSize: 7.5),
              ),
              pw.Text(
                dateLabel,
                style: pw.TextStyle(
                  color: _ink,
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAcceptedAmount(double amount, String currencyCode) {
    final symbol = switch (currencyCode) {
      'USDTRY' => r'$ ',
      'EURTRY' => 'EUR ',
      _ => 'TL ',
    };
    return NumberFormat.currency(
      locale: 'tr_TR',
      symbol: symbol,
      decimalDigits: 2,
    ).format(amount);
  }

  pw.Widget _buildAcceptedBanner(Quote quote) {
    final acceptedAt = quote.acceptedAt ?? quote.approvedAt;
    final dateLabel = acceptedAt == null
        ? ''
        : DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(acceptedAt);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFFF4E0),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE3B86C)),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFB8843C),
            ),
            child: pw.Text(
              'ANLASILDI',
              style: pw.TextStyle(
                color: _paper,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 0.9,
              ),
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(
              'Ticari mutabakat${dateLabel.isEmpty ? '' : ' - $dateLabel'}',
              style: pw.TextStyle(
                color: const PdfColor.fromInt(0xFF7A4D12),
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _signatureBox(
    String label,
    String name,
    String subtitle, {
    pw.MemoryImage? stamp,
  }) {
    final signatureArea = pw.SizedBox(
      height: stamp != null ? 68 : 18,
      child: stamp != null
          ? pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Opacity(
                opacity: 0.92,
                child: pw.Image(stamp, height: 62, fit: pw.BoxFit.contain),
              ),
            )
          : pw.SizedBox(),
    );

    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _hairline),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              color: _slate,
              fontSize: 7.5,
              letterSpacing: 1.2,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          signatureArea,
          pw.Container(
            height: 0.8,
            color: _mist,
            margin: const pw.EdgeInsets.only(bottom: 6),
          ),
          pw.Text(
            _valueOrDash(name),
            style: pw.TextStyle(
              color: _ink,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (subtitle.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                subtitle,
                style: const pw.TextStyle(color: _slate, fontSize: 8.5),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String label) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 3,
          height: 12,
          color: _accent,
          margin: const pw.EdgeInsets.only(right: 8),
        ),
        pw.Text(
          label,
          style: pw.TextStyle(
            color: _ink,
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // LAYOUT HELPERS
  // -------------------------------------------------------------------------

  /// Iki kutuyu yan yana ve ESIT yukseklikte konumlandirir.
  ///
  /// `MultiPage` icinde `Row(stretch)` sinirsiz yukseklik alip patladigi icin
  /// pw.Table kullaniyoruz; `TableCellVerticalAlignment.full` ile hucreler
  /// otomatik olarak satirin en uzun cocugu kadar uzar.
  pw.Widget _equalColumns(pw.Widget left, pw.Widget right, {double gap = 12}) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: pw.FixedColumnWidth(gap),
        2: const pw.FlexColumnWidth(1),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
      children: [
        pw.TableRow(children: [left, pw.SizedBox(), right]),
      ],
    );
  }

  /// N adet kutuyu yan yana esit genislik ve esit yukseklikte dizer.
  pw.Widget _equalRow(List<pw.Widget> children, {double gap = 10}) {
    if (children.isEmpty) return pw.SizedBox.shrink();
    if (children.length == 1) return children.first;

    final cells = <pw.Widget>[];
    final widths = <int, pw.TableColumnWidth>{};
    var col = 0;
    for (var i = 0; i < children.length; i++) {
      cells.add(children[i]);
      widths[col] = const pw.FlexColumnWidth(1);
      col++;
      if (i != children.length - 1) {
        cells.add(pw.SizedBox());
        widths[col] = pw.FixedColumnWidth(gap);
        col++;
      }
    }
    return pw.Table(
      columnWidths: widths,
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
      children: [pw.TableRow(children: cells)],
    );
  }

  // -------------------------------------------------------------------------
  // ASSETS
  // -------------------------------------------------------------------------

  // -------------------------------------------------------------------------
  // UTILITIES
  // -------------------------------------------------------------------------

  static String _valueOrDash(String value) {
    return value.trim().isEmpty ? '-' : value.trim();
  }

  static String _joinNonEmpty(String separator, List<String> parts) {
    return parts
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(separator);
  }

  static String _formatQuantity(double value) {
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }

  static String _formatDiscount(double value) {
    final isWhole = value.truncateToDouble() == value;
    return isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  }

  /// `Cikti bicimi: PDF` gibi dahili arsiv etiketlerini pdf'e yazmadan temizler.
  static String _cleanNote(String raw) {
    if (raw.isEmpty) return raw;
    final lines = raw.split(RegExp(r'\r?\n'));
    final filtered = lines
        .where((line) => !line.trim().toLowerCase().startsWith('cikti bicimi:'))
        .toList();
    return filtered.join('\n').trim();
  }
}

class _PartyRow {
  const _PartyRow(this.label, this.value);

  final String label;
  final String value;
}

/// Teklifin gosterim birimi ile TL arasindaki cevirileri tek yerde yonetir.
class _PriceView {
  _PriceView({
    required this.displayCode,
    required this.displaySymbol,
    required this.rate,
  });

  factory _PriceView.from(Quote quote) {
    final code = quote.displayUnit;
    final rate = quote.rateLookup[code];
    final safeRate = (rate == null || rate <= 0) ? 1.0 : rate;
    return _PriceView(
      displayCode: code,
      displaySymbol: _symbolFor(code),
      rate: safeRate,
    );
  }

  final String displayCode;
  final String displaySymbol;

  /// Gosterim biriminin TL karsiligi. TL secildiyse 1.
  final double rate;

  bool get isTl => displayCode == 'TL';

  double toDisplay(double tl) => isTl ? tl : tl / rate;

  String fmtAmount(double tlValue) {
    final value = toDisplay(tlValue);
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '',
      decimalDigits: 2,
    );
    return '${formatter.format(value)} $displaySymbol';
  }

  static String _symbolFor(String code) {
    switch (code) {
      case 'USDTRY':
        return 'USD';
      case 'EURTRY':
        return 'EUR';
      case 'XAUTRY_GRAM':
        return 'XAU/gr';
      case 'XAGTRY_GRAM':
        return 'XAG/gr';
      case 'TL':
        return 'TL';
      default:
        return code;
    }
  }
}
