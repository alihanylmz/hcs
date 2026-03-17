import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/ticket_status.dart';
import '../utils/pdf_helper.dart';

class TicketPdfService {
  // ignore: unused_field
  static const Map<String, String> _statusLabels = {
    'open': 'Açık',
    'panel_done_stock': 'Panosu Yapıldı Stokta',
    'panel_done_sent': 'Panosu Yapıldı Gönderildi',
    'in_progress': 'Serviste',
    'done': 'Tamamlandı',
    'archived': 'Arşivde',
    'cancelled': 'İptal',
  };

  static Future<Uint8List> generateSingleTicketPdfBytes(
    String ticketId, {
    String? technicianSignature,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final idValue = int.tryParse(ticketId) ?? ticketId;

      final ticketData =
          await supabase
              .from('tickets')
              .select('''
            *,
            customers (
              id,
              name,
              address,
              phone
            ),
            partners (
              id,
              name
            )
          ''')
              .eq('id', idValue)
              .maybeSingle();

      if (ticketData == null) {
        throw Exception('İş bulunamadı.');
      }

      final Map<String, dynamic> ticket = Map<String, dynamic>.from(ticketData);

      if (technicianSignature != null &&
          ticket['technician_signature_data'] == null) {
        ticket['technician_signature_data'] = technicianSignature;
      }

      final notesResponse = await supabase
          .from('ticket_notes')
          .select('*, profiles(full_name, role)')
          .eq('ticket_id', idValue)
          .neq('note_type', 'partner_note')
          .order('created_at', ascending: true);

      final notes = List<Map<String, dynamic>>.from(notesResponse);
      final enrichedNotes = await _enrichNotesWithImages(notes);

      final partner = ticket['partners'] as Map<String, dynamic>?;
      final partnerName = partner?['name'] as String?;

      pw.Document pdf;
      if (partnerName != null && partnerName.toLowerCase().contains('point')) {
        pdf = await _generatePointTicketPdf(ticket, enrichedNotes);
      } else if (partnerName != null &&
          partnerName.toLowerCase().contains('vensa')) {
        pdf = await _generateVensaTicketPdf(ticket, enrichedNotes);
      } else {
        pdf = await _generateStandardTicketPdf(ticket, enrichedNotes);
      }

      return await pdf.save();
    } catch (e) {
      throw Exception('PDF oluşturma hatası: $e');
    }
  }

  static Future<Uint8List> generateTicketListPdfBytesFromList({
    required List<Map<String, dynamic>> tickets,
    required String reportTitle,
    String? partnerName,
    String? generatedBy,
  }) async {
    try {
      return await _generateTicketListPdfReport(
        tickets: tickets,
        reportTitle: reportTitle,
        partnerName: partnerName,
        generatedBy: generatedBy,
      );
      final pdf = pw.Document();
      final font = await PdfHelper.loadTurkishFont();
      final now = DateTime.now();

      final lowerPartner = (partnerName ?? '').toLowerCase();
      final bool isPoint = lowerPartner.contains('point');
      final bool isVensa = lowerPartner.contains('vensa');

      final PdfColor themePrimary =
          isPoint
              ? const PdfColor.fromInt(0xFFD32F2F)
              : isVensa
              ? const PdfColor.fromInt(0xFF1976D2)
              : PdfHelper.primaryColor;

      final pw.ImageProvider? logo =
          isPoint
              ? await PdfHelper.loadPointLogo()
              : isVensa
              ? await PdfHelper.loadVensaLogo()
              : null;
      const PdfColor themeSurface = PdfColor.fromInt(0xFFF4F7FB);
      const PdfColor themeBorder = PdfColor.fromInt(0xFFD6E0EA);
      const PdfColor themeText = PdfColor.fromInt(0xFF172234);
      const PdfColor themeMuted = PdfColor.fromInt(0xFF617081);
      const PdfColor themeAccent = PdfColor.fromInt(0xFFC8953A);
      const PdfColor successColor = PdfColor.fromInt(0xFF1F7A5A);
      const PdfColor neutralChip = PdfColor.fromInt(0xFFE8EEF5);
      final uniquePartners =
          tickets
              .map(_extractPartnerName)
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      final partnerScope =
          (partnerName ?? '').trim().isNotEmpty
              ? partnerName!.trim()
              : uniquePartners.isEmpty
              ? 'Tum partnerler'
              : uniquePartners.length == 1
              ? uniquePartners.first
              : '${uniquePartners.length} partner';
      final highPriorityCount =
          tickets
              .where(
                (ticket) => (ticket['priority'] as String? ?? '') == 'high',
              )
              .length;
      final lastArchiveDate = tickets
          .map((ticket) => ticket['archived_at'] as String?)
          .whereType<String>()
          .map(DateTime.tryParse)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (latest, current) {
            if (latest == null || current.isAfter(latest)) {
              return current;
            }
            return latest;
          });

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
            theme: pw.ThemeData.withFont(base: font, bold: font),
          ),
          header:
              (context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          if (logo != null) ...[
                            pw.Container(
                              width: 56,
                              height: 56,
                              child: pw.Image(logo, fit: pw.BoxFit.contain),
                            ),
                            pw.SizedBox(width: 12),
                          ],
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                reportTitle,
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: themeText,
                                ),
                              ),
                              pw.SizedBox(height: 3),
                              pw.Text(
                                'Kurumsal arsiv raporu',
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 10,
                                  color: themeMuted,
                                ),
                              ),
                              if ((partnerName ?? '').trim().isNotEmpty)
                                pw.Text(
                                  PdfHelper.safeText(partnerName),
                                  style: pw.TextStyle(
                                    font: font,
                                    fontSize: 10,
                                    color: themePrimary,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(now),
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 9,
                              color: themeMuted,
                            ),
                          ),
                          pw.Text(
                            'Toplam kayit: ${tickets.length}',
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 9,
                              color: themeMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    height: 4,
                    decoration: pw.BoxDecoration(
                      color: themePrimary,
                      borderRadius: pw.BorderRadius.circular(999),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                ],
              ),
          footer:
              (context) => pw.Container(
                margin: const pw.EdgeInsets.only(top: 10),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'HanCoSys İş Takip Sistemi',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 8,
                        color: themeMuted,
                      ),
                    ),
                    pw.Text(
                      'Sayfa ${context.pageNumber} / ${context.pagesCount}',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 8,
                        color: themeMuted,
                      ),
                    ),
                  ],
                ),
              ),
          build: (context) {
            if (tickets.isEmpty)
              return [
                pw.Center(
                  child: pw.Text(
                    'Liste boş.',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 12,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ];

            return [
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: themeSurface,
                  borderRadius: pw.BorderRadius.circular(16),
                  border: pw.Border.all(color: themeBorder, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Rapor Ozeti',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: themeText,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _buildSummaryMetric(
                            label: 'Toplam arsiv kaydi',
                            value: '${tickets.length}',
                            font: font,
                            valueColor: themePrimary,
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: _buildSummaryMetric(
                            label: 'Partner kapsami',
                            value: partnerScope,
                            font: font,
                            valueColor: themeText,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _buildSummaryMetric(
                            label: 'Yuksek oncelik',
                            value: '$highPriorityCount',
                            font: font,
                            valueColor: themeAccent,
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: _buildSummaryMetric(
                            label: 'Son arsiv tarihi',
                            value: _formatTicketListDate(
                              lastArchiveDate?.toIso8601String(),
                            ),
                            font: font,
                            valueColor: successColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder(
                  top: pw.BorderSide(color: themeBorder, width: 1),
                  bottom: pw.BorderSide(color: themeBorder, width: 1),
                  horizontalInside: pw.BorderSide(color: themeBorder, width: 1),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.8),
                  1: pw.FlexColumnWidth(1.8),
                  2: pw.FlexColumnWidth(2.7),
                  3: pw.FlexColumnWidth(1.6),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: themePrimary),
                    children: [
                      _buildReportTableCell(
                        child: pw.Text(
                          'Is',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildReportTableCell(
                        child: pw.Text(
                          'Partner / Musteri',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildReportTableCell(
                        child: pw.Text(
                          'Is detayi',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildReportTableCell(
                        child: pw.Text(
                          'Durum / Tarih',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 9,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  ...tickets.asMap().entries.map((entry) {
                    final ticket = entry.value;
                    final customerName = _extractCustomerName(ticket);
                    final partnerValue = _extractPartnerName(ticket);
                    final jobTitle =
                        (ticket['title'] as String?)?.trim().isNotEmpty == true
                            ? (ticket['title'] as String).trim()
                            : 'Baslik girilmemis';
                    final detail = _extractTicketDetail(ticket);
                    final status = TicketStatus.labelOf(
                      ticket['status'] as String? ?? '-',
                    );
                    final priorityLabel = _priorityLabelOf(
                      ticket['priority'] as String?,
                    );
                    final planDate = _formatTicketListDate(
                      ticket['planned_date'] as String?,
                    );
                    final archiveDate = _formatTicketListDate(
                      ticket['archived_at'] as String?,
                    );
                    final deviceInfo = _extractDeviceInfo(ticket);

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color:
                            entry.key.isEven ? PdfColors.white : themeSurface,
                      ),
                      verticalAlignment: pw.TableCellVerticalAlignment.top,
                      children: [
                        _buildReportTableCell(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                PdfHelper.safeText(ticket['job_code']),
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 8,
                                  color: themePrimary,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                PdfHelper.safeText(_limitText(jobTitle, 90)),
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 10,
                                  color: themeText,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              if (deviceInfo.isNotEmpty) ...[
                                pw.SizedBox(height: 4),
                                pw.Text(
                                  'Cihaz: $deviceInfo',
                                  style: pw.TextStyle(
                                    font: font,
                                    fontSize: 8,
                                    color: themeMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        _buildReportTableCell(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                partnerValue.isEmpty
                                    ? 'Partner bilgisi yok'
                                    : partnerValue,
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 9,
                                  color: themeText,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                customerName.isEmpty
                                    ? 'Musteri bilgisi yok'
                                    : customerName,
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 8,
                                  color: themeMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildReportTableCell(
                          child: pw.Text(
                            detail,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 8,
                              color: themeText,
                            ),
                          ),
                        ),
                        _buildReportTableCell(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                status,
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 9,
                                  color: themeText,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'Oncelik: $priorityLabel',
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 8,
                                  color: themeMuted,
                                ),
                              ),
                              pw.Text(
                                'Plan: $planDate',
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 8,
                                  color: themeMuted,
                                ),
                              ),
                              pw.Text(
                                'Arsiv: $archiveDate',
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 8,
                                  color: themeMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ];

            final useModernLayout = reportTitle.trim().isNotEmpty;
            if (useModernLayout) {
              return [
                pw.Container(
                  padding: const pw.EdgeInsets.all(18),
                  decoration: pw.BoxDecoration(
                    color: themeSurface,
                    borderRadius: pw.BorderRadius.circular(18),
                    border: pw.Border.all(color: themeBorder, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Rapor Ozeti',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: themeText,
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: _buildSummaryMetric(
                              label: 'Toplam arsiv kaydi',
                              value: '${tickets.length}',
                              font: font,
                              valueColor: themePrimary,
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Expanded(
                            child: _buildSummaryMetric(
                              label: 'Partner kapsami',
                              value: partnerScope,
                              font: font,
                              valueColor: themeText,
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Expanded(
                            child: _buildSummaryMetric(
                              label: 'Yuksek oncelik',
                              value: '$highPriorityCount',
                              font: font,
                              valueColor: themeAccent,
                            ),
                          ),
                          pw.SizedBox(width: 10),
                          pw.Expanded(
                            child: _buildSummaryMetric(
                              label: 'Son arsiv tarihi',
                              value: _formatTicketListDate(
                                lastArchiveDate?.toIso8601String(),
                              ),
                              font: font,
                              valueColor: successColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 18),
                ...tickets.asMap().entries.map((entry) {
                  final index = entry.key;
                  final ticket = entry.value;
                  final customerName = _extractCustomerName(ticket);
                  final partnerValue = _extractPartnerName(ticket);
                  final jobTitle =
                      (ticket['title'] as String?)?.trim().isNotEmpty == true
                          ? (ticket['title'] as String).trim()
                          : 'Baslik girilmemis';
                  final detail = _extractTicketDetail(ticket);
                  final status = TicketStatus.labelOf(
                    ticket['status'] as String? ?? '-',
                  );
                  final priorityLabel = _priorityLabelOf(
                    ticket['priority'] as String?,
                  );
                  final deviceInfo = _extractDeviceInfo(ticket);

                  return pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 14),
                    padding: const pw.EdgeInsets.all(18),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(18),
                      border: pw.Border.all(color: themeBorder, width: 1),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 34,
                          height: 34,
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            color: themePrimary,
                            borderRadius: pw.BorderRadius.circular(10),
                          ),
                          child: pw.Text(
                            '${index + 1}',
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 10,
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Expanded(
                                    child: pw.Column(
                                      crossAxisAlignment:
                                          pw.CrossAxisAlignment.start,
                                      children: [
                                        pw.Text(
                                          PdfHelper.safeText(
                                            ticket['job_code'],
                                          ),
                                          style: pw.TextStyle(
                                            font: font,
                                            fontSize: 10,
                                            color: themePrimary,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                        ),
                                        pw.SizedBox(height: 4),
                                        pw.Text(
                                          PdfHelper.safeText(jobTitle),
                                          style: pw.TextStyle(
                                            font: font,
                                            fontSize: 13,
                                            color: themeText,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  pw.SizedBox(width: 8),
                                  _buildMetaChip(
                                    label: 'Durum',
                                    value: status,
                                    font: font,
                                    background: neutralChip,
                                    valueColor: themeText,
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 12),
                              pw.Container(
                                padding: const pw.EdgeInsets.all(14),
                                decoration: pw.BoxDecoration(
                                  color: themeSurface,
                                  borderRadius: pw.BorderRadius.circular(14),
                                ),
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    _buildTicketField(
                                      label: 'Partner',
                                      value:
                                          partnerValue.isEmpty
                                              ? 'Partner bilgisi yok'
                                              : partnerValue,
                                      font: font,
                                      labelColor: themeMuted,
                                      valueColor: themeText,
                                    ),
                                    pw.SizedBox(height: 8),
                                    _buildTicketField(
                                      label: 'Musteri',
                                      value:
                                          customerName.isEmpty
                                              ? 'Musteri bilgisi yok'
                                              : customerName,
                                      font: font,
                                      labelColor: themeMuted,
                                      valueColor: themeText,
                                    ),
                                    pw.SizedBox(height: 8),
                                    _buildTicketField(
                                      label: 'Is detayi',
                                      value: detail,
                                      font: font,
                                      labelColor: themeMuted,
                                      valueColor: themeText,
                                    ),
                                  ],
                                ),
                              ),
                              pw.SizedBox(height: 12),
                              pw.Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildMetaChip(
                                    label: 'Oncelik',
                                    value: priorityLabel,
                                    font: font,
                                    background: _priorityChipColor(
                                      ticket['priority'] as String?,
                                    ),
                                    valueColor: PdfColors.white,
                                  ),
                                  _buildMetaChip(
                                    label: 'Plan',
                                    value: _formatTicketListDate(
                                      ticket['planned_date'] as String?,
                                    ),
                                    font: font,
                                    background: neutralChip,
                                    valueColor: themeText,
                                  ),
                                  _buildMetaChip(
                                    label: 'Arsiv',
                                    value: _formatTicketListDate(
                                      ticket['archived_at'] as String?,
                                    ),
                                    font: font,
                                    background: neutralChip,
                                    valueColor: themeText,
                                  ),
                                  if (deviceInfo.isNotEmpty)
                                    _buildMetaChip(
                                      label: 'Cihaz',
                                      value: deviceInfo,
                                      font: font,
                                      background: neutralChip,
                                      valueColor: themeText,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ];
            }

            return [
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: const {
                  0: pw.FixedColumnWidth(70),
                  1: pw.FlexColumnWidth(2.5),
                  2: pw.FlexColumnWidth(2.2),
                  3: pw.FixedColumnWidth(70),
                  4: pw.FixedColumnWidth(70),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: themePrimary),
                    children:
                        ['KOD', 'MÜŞTERİ', 'İŞ', 'DURUM', 'TARİH']
                            .map(
                              (h) => pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(
                                  h,
                                  style: pw.TextStyle(
                                    font: font,
                                    fontSize: 9,
                                    color: PdfColors.white,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  ...tickets.asMap().entries.map((entry) {
                    final i = entry.key;
                    final t = entry.value;
                    final customer =
                        t['customers'] as Map<String, dynamic>? ?? {};
                    final status = TicketStatus.labelOf(
                      t['status'] as String? ?? '-',
                    );
                    String dateText = '-';
                    if (t['planned_date'] != null) {
                      final parsed = DateTime.tryParse(t['planned_date']);
                      if (parsed != null)
                        dateText = DateFormat(
                          'dd.MM.yyyy',
                          'tr_TR',
                        ).format(parsed);
                    }

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: i.isOdd ? PdfColors.grey50 : PdfColors.white,
                      ),
                      verticalAlignment: pw.TableCellVerticalAlignment.middle,
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            PdfHelper.safeText(t['job_code']),
                            style: pw.TextStyle(font: font, fontSize: 9),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            PdfHelper.safeText(customer['name']),
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            PdfHelper.safeText(t['title']),
                            style: pw.TextStyle(font: font, fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            status,
                            style: pw.TextStyle(font: font, fontSize: 9),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            dateText,
                            style: pw.TextStyle(font: font, fontSize: 9),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ];
          },
        ),
      );

      return pdf.save();
    } catch (e) {
      throw Exception('Ticket list PDF generation failed: $e');
    }
  }

  static Future<Uint8List> _generateTicketListPdfReport({
    required List<Map<String, dynamic>> tickets,
    required String reportTitle,
    String? partnerName,
    String? generatedBy,
  }) async {
    final pdf = pw.Document();
    final font = await PdfHelper.loadTurkishFont();
    final now = DateTime.now();

    final lowerPartner = (partnerName ?? '').toLowerCase();
    final bool isPoint = lowerPartner.contains('point');
    final bool isVensa = lowerPartner.contains('vensa');

    final PdfColor themePrimary =
        isPoint
            ? const PdfColor.fromInt(0xFFD32F2F)
            : isVensa
            ? const PdfColor.fromInt(0xFF1976D2)
            : const PdfColor.fromInt(0xFF183B63);
    const PdfColor themeSurface = PdfColor.fromInt(0xFFF4F7FB);
    const PdfColor themeBorder = PdfColor.fromInt(0xFFD6E0EA);
    const PdfColor themeText = PdfColor.fromInt(0xFF172234);
    const PdfColor themeMuted = PdfColor.fromInt(0xFF617081);
    const PdfColor themeAccent = PdfColor.fromInt(0xFFC8953A);
    const PdfColor successColor = PdfColor.fromInt(0xFF1F7A5A);

    final pw.ImageProvider? logo =
        isPoint
            ? await PdfHelper.loadPointLogo()
            : isVensa
            ? await PdfHelper.loadVensaLogo()
            : null;

    final uniquePartners =
        tickets
            .map(_extractPartnerName)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final partnerScope =
        (partnerName ?? '').trim().isNotEmpty
            ? partnerName!.trim()
            : uniquePartners.isEmpty
            ? 'All partners'
            : uniquePartners.length == 1
            ? uniquePartners.first
            : '${uniquePartners.length} partners';
    final highPriorityCount =
        tickets
            .where((ticket) => (ticket['priority'] as String? ?? '') == 'high')
            .length;
    final reportOwner =
        (generatedBy ?? '').trim().isEmpty
            ? 'Belirtilmedi'
            : PdfHelper.safeText(generatedBy);
    final lastArchiveDate = tickets
        .map((ticket) => ticket['archived_at'] as String?)
        .whereType<String>()
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, current) {
          if (latest == null || current.isAfter(latest)) {
            return current;
          }
          return latest;
        });

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          theme: pw.ThemeData.withFont(base: font, bold: font),
        ),
        header:
            (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (logo != null) ...[
                          pw.Container(
                            width: 42,
                            height: 42,
                            child: pw.Image(logo, fit: pw.BoxFit.contain),
                          ),
                          pw.SizedBox(width: 10),
                        ],
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Uzal Teknik Servis Raporu',
                              style: pw.TextStyle(
                                font: font,
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: themeText,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              PdfHelper.safeText(reportTitle),
                              style: pw.TextStyle(
                                font: font,
                                fontSize: 8,
                                color: themeMuted,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              'Raporu cikartan kisi: $reportOwner',
                              style: pw.TextStyle(
                                font: font,
                                fontSize: 8,
                                color: themePrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(now),
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 8,
                            color: themeMuted,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Total records: ${tickets.length}',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 8,
                            color: themeMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Divider(color: themeBorder, thickness: 0.8),
                pw.SizedBox(height: 6),
              ],
            ),
        footer:
            (context) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'UZAL TEKNIK  |  ${DateFormat('dd.MM.yyyy', 'tr_TR').format(now)}  |  Toplam listelenen is: ${tickets.length}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: themeMuted,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} / ${context.pagesCount}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: themeMuted,
                  ),
                ),
              ],
            ),
        build: (context) {
          if (tickets.isEmpty) {
            return [
              pw.Center(
                child: pw.Text(
                  'No archived records found.',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 12,
                    color: themeMuted,
                  ),
                ),
              ),
            ];
          }

          return [
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: themeSurface,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: themeBorder, width: 1),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Rapor Ozeti',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: themeText,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: _buildSummaryMetric(
                          label: 'Listelenen is',
                          value: '${tickets.length}',
                          font: font,
                          valueColor: themePrimary,
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: _buildSummaryMetric(
                          label: 'Partner kapsami',
                          value: partnerScope,
                          font: font,
                          valueColor: themeText,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: _buildSummaryMetric(
                          label: 'Yuksek oncelik',
                          value: '$highPriorityCount',
                          font: font,
                          valueColor: themeAccent,
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: _buildSummaryMetric(
                          label: 'Son arsiv tarihi',
                          value: _formatTicketListDate(
                            lastArchiveDate?.toIso8601String(),
                          ),
                          font: font,
                          valueColor: successColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            ...tickets.asMap().entries.expand((entry) {
              final ticket = entry.value;
              final jobTitle =
                  (ticket['title'] as String?)?.trim().isNotEmpty == true
                      ? (ticket['title'] as String).trim()
                      : 'No title';
              final partnerValue = _extractPartnerName(ticket);
              final customerName = _extractCustomerName(ticket);
              final status = TicketStatus.labelOf(
                ticket['status'] as String? ?? '-',
              );
              final priorityLabel = _priorityLabelOf(
                ticket['priority'] as String?,
              );
              final planDate = _formatTicketListDate(
                ticket['planned_date'] as String?,
              );
              final archiveDate = _formatTicketListDate(
                ticket['archived_at'] as String?,
              );
              final deviceInfo = _extractDeviceInfo(ticket);
              final hasSignature =
                  ticket['signature_data'] != null ||
                  ticket['technician_signature_data'] != null;

              return <pw.Widget>[
                pw.NewPage(freeSpace: 96),
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(10),
                  height: 78,
                  decoration: pw.BoxDecoration(
                    color: entry.key.isEven ? PdfColors.white : themeSurface,
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: themeBorder, width: 1),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${entry.key + 1}. ${PdfHelper.safeText(_limitText(jobTitle, 120))}',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 9,
                          color: themeText,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Job code: ${PdfHelper.safeText(ticket['job_code'])}',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 7,
                          color: themePrimary,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: _buildCompactField(
                              label: 'Partner',
                              value:
                                  partnerValue.isEmpty
                                      ? '-'
                                      : PdfHelper.safeText(
                                        _limitText(partnerValue, 18),
                                      ),
                              font: font,
                              labelColor: themeMuted,
                              valueColor: themeText,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: _buildCompactField(
                              label: 'Musteri',
                              value:
                                  customerName.isEmpty
                                      ? '-'
                                      : PdfHelper.safeText(
                                        _limitText(customerName, 18),
                                      ),
                              font: font,
                              labelColor: themeMuted,
                              valueColor: themeText,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: _buildCompactField(
                              label: 'Durum',
                              value: PdfHelper.safeText(_limitText(status, 14)),
                              font: font,
                              labelColor: themeMuted,
                              valueColor: themeText,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: _buildCompactField(
                              label: 'Oncelik',
                              value: priorityLabel,
                              font: font,
                              labelColor: themeMuted,
                              valueColor: themeText,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: _buildCompactField(
                              label: 'Plan',
                              value: planDate,
                              font: font,
                              labelColor: themeMuted,
                              valueColor: themeText,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: _buildCompactField(
                              label: 'Arsiv',
                              value: archiveDate,
                              font: font,
                              labelColor: themeMuted,
                              valueColor: themeText,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: _buildCompactField(
                              label: 'Imza',
                              value: hasSignature ? '[x] Var' : '[ ] Yok',
                              font: font,
                              labelColor: themeMuted,
                              valueColor: themeText,
                            ),
                          ),
                          pw.SizedBox(width: 8),
                          pw.Expanded(
                            child: _buildCompactField(
                              label: 'Cihaz',
                              value:
                                  deviceInfo.isEmpty
                                      ? '-'
                                      : PdfHelper.safeText(
                                        _limitText(deviceInfo, 16),
                                      ),
                              font: font,
                              labelColor: themeMuted,
                              valueColor: themeText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ];
            }),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryMetric({
    required String label,
    required String value,
    required pw.Font font,
    required PdfColor valueColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: font,
              fontSize: 7,
              color: const PdfColor.fromInt(0xFF617081),
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: 9,
              color: valueColor,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCompactField({
    required String label,
    required String value,
    required pw.Font font,
    required PdfColor labelColor,
    required PdfColor valueColor,
  }) {
    return pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: pw.TextStyle(font: font, fontSize: 7, color: labelColor),
          ),
          pw.TextSpan(
            text: value,
            style: pw.TextStyle(font: font, fontSize: 7, color: valueColor),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReportTableCell({required pw.Widget child}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: child,
    );
  }

  static pw.Widget _buildArchivedTicketReportCard({
    required int index,
    required Map<String, dynamic> ticket,
    required pw.Font font,
    required PdfColor themePrimary,
    required PdfColor themeSurface,
    required PdfColor themeBorder,
    required PdfColor themeText,
    required PdfColor themeMuted,
  }) {
    final customerName = _extractCustomerName(ticket);
    final partnerName = _extractPartnerName(ticket);
    final jobTitle =
        (ticket['title'] as String?)?.trim().isNotEmpty == true
            ? (ticket['title'] as String).trim()
            : 'Baslik girilmemis';
    final detail = _extractTicketDetail(ticket);
    final status = TicketStatus.labelOf(ticket['status'] as String? ?? '-');
    final priority = _priorityLabelOf(ticket['priority'] as String?);
    final planDate = _formatTicketListDate(ticket['planned_date'] as String?);
    final archiveDate = _formatTicketListDate(ticket['archived_at'] as String?);
    final deviceInfo = _extractDeviceInfo(ticket);

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: themeBorder, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 28,
                height: 28,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: themePrimary,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  '$index',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 9,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      PdfHelper.safeText(ticket['job_code']),
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        color: themePrimary,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      PdfHelper.safeText(_limitText(jobTitle, 110)),
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 13,
                        color: themeText,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: pw.BoxDecoration(
                  color: themeSurface,
                  borderRadius: pw.BorderRadius.circular(999),
                ),
                child: pw.Text(
                  status,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 8,
                    color: themeText,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: themeSurface,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: _buildTicketField(
                        label: 'Partner',
                        value:
                            partnerName.isEmpty
                                ? 'Partner bilgisi yok'
                                : partnerName,
                        font: font,
                        labelColor: themeMuted,
                        valueColor: themeText,
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: _buildTicketField(
                        label: 'Musteri',
                        value:
                            customerName.isEmpty
                                ? 'Musteri bilgisi yok'
                                : customerName,
                        font: font,
                        labelColor: themeMuted,
                        valueColor: themeText,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: _buildTicketField(
                        label: 'Plan tarihi',
                        value: planDate,
                        font: font,
                        labelColor: themeMuted,
                        valueColor: themeText,
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: _buildTicketField(
                        label: 'Arsiv tarihi',
                        value: archiveDate,
                        font: font,
                        labelColor: themeMuted,
                        valueColor: themeText,
                      ),
                    ),
                  ],
                ),
                if (deviceInfo.isNotEmpty) ...[
                  pw.SizedBox(height: 10),
                  _buildTicketField(
                    label: 'Cihaz',
                    value: deviceInfo,
                    font: font,
                    labelColor: themeMuted,
                    valueColor: themeText,
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          _buildMetaChip(
            label: 'Oncelik',
            value: priority,
            font: font,
            background: _priorityChipColor(ticket['priority'] as String?),
            valueColor: PdfColors.white,
          ),
          pw.SizedBox(height: 10),
          _buildTicketField(
            label: 'Is detayi',
            value: detail,
            font: font,
            labelColor: themeMuted,
            valueColor: themeText,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTicketField({
    required String label,
    required String value,
    required pw.Font font,
    required PdfColor labelColor,
    required PdfColor valueColor,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: font, fontSize: 7, color: labelColor),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(font: font, fontSize: 8, color: valueColor),
        ),
      ],
    );
  }

  static pw.Widget _buildMetaChip({
    required String label,
    required String value,
    required pw.Font font,
    required PdfColor background,
    required PdfColor valueColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: background,
        borderRadius: pw.BorderRadius.circular(999),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(font: font, fontSize: 8, color: valueColor),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: 8,
              color: valueColor,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static String _extractCustomerName(Map<String, dynamic> ticket) {
    final customer = ticket['customers'] as Map<String, dynamic>? ?? {};
    return (customer['name'] as String?)?.trim() ?? '';
  }

  static String _extractPartnerName(Map<String, dynamic> ticket) {
    final partner = ticket['partners'] as Map<String, dynamic>? ?? {};
    return (partner['name'] as String?)?.trim() ?? '';
  }

  static String _extractTicketDetail(Map<String, dynamic> ticket) {
    final description = (ticket['description'] as String?)?.trim() ?? '';
    if (description.isNotEmpty) {
      return _limitText(description.replaceAll('\n', ' '), 220);
    }

    final deviceInfo = _extractDeviceInfo(ticket);
    if (deviceInfo.isNotEmpty) {
      return 'Cihaz bilgisi: $deviceInfo';
    }

    return 'Bu kayit icin aciklama girilmemis.';
  }

  static String _extractDeviceInfo(Map<String, dynamic> ticket) {
    final brand = (ticket['device_brand'] as String?)?.trim() ?? '';
    final model = (ticket['device_model'] as String?)?.trim() ?? '';

    if (brand.isNotEmpty && model.isNotEmpty) {
      return '$brand / $model';
    }
    if (brand.isNotEmpty) {
      return brand;
    }
    if (model.isNotEmpty) {
      return model;
    }
    return '';
  }

  static String _formatTicketListDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '-';
    return DateFormat('dd.MM.yyyy', 'tr_TR').format(parsed.toLocal());
  }

  static String _priorityLabelOf(String? priority) {
    switch (priority) {
      case 'high':
        return 'Yuksek';
      case 'low':
        return 'Dusuk';
      case 'normal':
      default:
        return 'Normal';
    }
  }

  static PdfColor _priorityChipColor(String? priority) {
    switch (priority) {
      case 'high':
        return const PdfColor.fromInt(0xFFB5473D);
      case 'low':
        return const PdfColor.fromInt(0xFF2D7D5E);
      case 'normal':
      default:
        return const PdfColor.fromInt(0xFF5A6A7B);
    }
  }

  static String _limitText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3).trim()}...';
  }

  static Future<List<Map<String, dynamic>>> _enrichNotesWithImages(
    List<Map<String, dynamic>> notes,
  ) async {
    final List<Map<String, dynamic>> enriched = [];
    for (final raw in notes) {
      final note = Map<String, dynamic>.from(raw);
      List<String> urls = [];
      if (note['image_urls'] != null) {
        urls = List<String>.from(note['image_urls']);
      } else if (note['image_url'] != null) {
        urls.add(note['image_url'] as String);
      }

      final List<pw.ImageProvider> images = [];
      for (final url in urls) {
        try {
          final uri = Uri.tryParse(url);
          if (uri == null) continue;
          final resp = await http.get(uri);
          if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
            images.add(pw.MemoryImage(resp.bodyBytes));
          }
        } catch (_) {}
      }
      note['pdf_images'] = images;
      enriched.add(note);
    }
    return enriched;
  }

  static Future<pw.Document> _generateStandardTicketPdf(
    Map<String, dynamic> ticket,
    List<Map<String, dynamic>> notes,
  ) async {
    final pdf = pw.Document();
    final font = await PdfHelper.loadTurkishFont();
    final customer =
        ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final status = ticket['status'] as String? ?? 'open';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header:
            (context) => _buildHeader(
              ticket,
              font,
              "TEKNİK SERVİS HİZMETLERİ",
              PdfHelper.primaryColor,
              PdfHelper.accentColor,
            ),
        footer: (context) => _buildFooter(ticket, font),
        build:
            (context) => [
              _buildInfoSection(ticket, customer, font, status),
              _buildDescriptionSection(ticket, font),
              _buildTechnicalSection(ticket, font),
              _buildNotesSection(notes, font),
              ..._buildImagesSection(notes, font, PdfHelper.primaryColor),
            ],
      ),
    );
    return pdf;
  }

  static Future<pw.Document> _generatePointTicketPdf(
    Map<String, dynamic> ticket,
    List<Map<String, dynamic>> notes,
  ) async {
    final pdf = pw.Document();
    final font = await PdfHelper.loadTurkishFont();
    final logo = await PdfHelper.loadPointLogo();
    final customer =
        ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final status = ticket['status'] as String? ?? 'open';
    const primaryColor = PdfColor.fromInt(0xFFD32F2F);
    const accentColor = PdfColor.fromInt(0xFF424242);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          theme: pw.ThemeData.withFont(base: font, bold: font),
          buildBackground: (context) => _buildWatermark(logo),
        ),
        header:
            (context) => _buildHeaderWithLogo(
              ticket,
              font,
              logo,
              "Teknik Servis İş Emri ve Servis Formu",
              primaryColor,
            ),
        footer:
            (context) => _buildFooter(
              ticket,
              font,
              address: 'Dağyaka Mah. 2022.Cad No:18/1, KahramanKazan/ANKARA',
            ),
        build:
            (context) => [
              _buildInfoSection(
                ticket,
                customer,
                font,
                status,
                accentColor: accentColor,
              ),
              _buildDescriptionSection(ticket, font),
              _buildTechnicalSection(ticket, font),
              _buildNotesSection(notes, font, accentColor: accentColor),
              ..._buildImagesSection(notes, font, primaryColor),
            ],
      ),
    );
    return pdf;
  }

  static Future<pw.Document> _generateVensaTicketPdf(
    Map<String, dynamic> ticket,
    List<Map<String, dynamic>> notes,
  ) async {
    final pdf = pw.Document();
    final font = await PdfHelper.loadTurkishFont();
    final logo = await PdfHelper.loadVensaLogo();
    final customer =
        ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final status = ticket['status'] as String? ?? 'open';
    const primaryColor = PdfColor.fromInt(0xFF1976D2);
    const accentColor = PdfColor.fromInt(0xFF1565C0);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          theme: pw.ThemeData.withFont(base: font, bold: font),
          buildBackground: (context) => _buildWatermark(logo),
        ),
        header:
            (context) => _buildHeaderWithLogo(
              ticket,
              font,
              logo,
              "Teknik Servis İş Emri ve Servis Formu",
              primaryColor,
            ),
        footer:
            (context) => _buildFooter(
              ticket,
              font,
              address:
                  'Pursaklar Sanayi Sitesi 1643. Cad. No: 18 Altındağ, Ankara',
            ),
        build:
            (context) => [
              _buildInfoSection(
                ticket,
                customer,
                font,
                status,
                accentColor: accentColor,
              ),
              _buildDescriptionSection(ticket, font),
              _buildTechnicalSection(ticket, font),
              _buildNotesSection(notes, font, accentColor: accentColor),
              ..._buildImagesSection(notes, font, primaryColor),
            ],
      ),
    );
    return pdf;
  }

  // --- UI Components ---

  static pw.Widget _buildHeader(
    Map<String, dynamic> ticket,
    pw.Font font,
    String title,
    PdfColor primary,
    PdfColor accent,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: primary,
                  ),
                ),
                pw.Text(
                  'Servis Formu ve İş Emri Belgesi',
                  style: pw.TextStyle(font: font, fontSize: 10, color: accent),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfHelper.lightBgColor,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Text(
                    'İŞ NO: ${PdfHelper.safeText(ticket['job_code'])}',
                    style: pw.TextStyle(
                      font: font,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Tarih: ${PdfHelper.formatDate(DateTime.now().toIso8601String())}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: primary, thickness: 2),
      ],
    );
  }

  static pw.Widget _buildHeaderWithLogo(
    Map<String, dynamic> ticket,
    pw.Font font,
    pw.ImageProvider? logo,
    String title,
    PdfColor primary,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
              children: [
                if (logo != null) ...[
                  pw.Container(
                    width: 100,
                    height: 100,
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                  pw.SizedBox(width: 12),
                ],
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: primary,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfHelper.lightBgColor,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Text(
                    'İŞ NO: ${PdfHelper.safeText(ticket['job_code'])}',
                    style: pw.TextStyle(
                      font: font,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Tarih: ${PdfHelper.formatDate(DateTime.now().toIso8601String())}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: primary, thickness: 2),
      ],
    );
  }

  static pw.Widget _buildWatermark(pw.ImageProvider? logo) {
    if (logo == null) return pw.SizedBox();
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Center(
        child: pw.Opacity(
          opacity: 0.05,
          child: pw.Image(
            logo,
            width: 400,
            height: 400,
            fit: pw.BoxFit.contain,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildInfoSection(
    Map<String, dynamic> ticket,
    Map<String, dynamic> customer,
    pw.Font font,
    String status, {
    PdfColor? accentColor,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            children: [
              PdfHelper.buildSectionHeader('Müşteri Bilgileri', font),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfHelper.lightBgColor,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    PdfHelper.buildInfoRow(
                      'Ünvan',
                      PdfHelper.safeText(customer['name']),
                      font,
                      isFullWidth: true,
                    ),
                    pw.SizedBox(height: 5),
                    PdfHelper.buildInfoRow(
                      'Telefon',
                      PdfHelper.safeText(customer['phone']),
                      font,
                    ),
                    pw.Divider(height: 10),
                    PdfHelper.buildInfoRow(
                      'Adres',
                      PdfHelper.safeText(customer['address']),
                      font,
                      isFullWidth: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            children: [
              PdfHelper.buildSectionHeader('Servis Detayları', font),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    PdfHelper.buildInfoRow(
                      'Cihaz',
                      PdfHelper.safeText(ticket['device_model']),
                      font,
                    ),
                    pw.Divider(),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: PdfHelper.buildInfoRow(
                            'Tarih',
                            PdfHelper.formatDate(
                              ticket['planned_date'] as String?,
                            ),
                            font,
                          ),
                        ),
                        pw.Expanded(
                          child: PdfHelper.buildInfoRow(
                            'Durum',
                            TicketStatus.labelOf(status),
                            font,
                          ),
                        ),
                      ],
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

  static pw.Widget _buildDescriptionSection(
    Map<String, dynamic> ticket,
    pw.Font font,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfHelper.buildSectionHeader('İş Açıklaması', font),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(5),
          ),
          child: pw.Text(
            PdfHelper.safeText(ticket['description']),
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTechnicalSection(
    Map<String, dynamic> ticket,
    pw.Font font,
  ) {
    final aspKw = ticket['aspirator_kw'];
    final vantKw = ticket['vant_kw'];
    final hmiBrand = ticket['hmi_brand'];
    if (aspKw == null && vantKw == null && hmiBrand == null)
      return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        PdfHelper.buildSectionHeader('Teknik Bilgiler', font),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfHelper.lightBgColor),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Bileşen',
                    style: pw.TextStyle(
                      font: font,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    'Detay',
                    style: pw.TextStyle(
                      font: font,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
            if (aspKw != null)
              _buildZebraRow(
                'Aspiratör',
                '${PdfHelper.safeText(aspKw)} kW',
                font,
                0,
              ),
            if (vantKw != null)
              _buildZebraRow(
                'Vantilatör',
                '${PdfHelper.safeText(vantKw)} kW',
                font,
                1,
              ),
            if (hmiBrand != null)
              _buildZebraRow(
                'HMI Ekran',
                '${PdfHelper.safeText(hmiBrand)}',
                font,
                0,
              ),
          ],
        ),
      ],
    );
  }

  static pw.TableRow _buildZebraRow(
    String label,
    String value,
    pw.Font font,
    int index,
  ) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: index % 2 == 0 ? PdfColors.white : PdfColors.grey100,
      ),
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(5),
          child: pw.Text(value, style: pw.TextStyle(font: font, fontSize: 9)),
        ),
      ],
    );
  }

  static pw.Widget _buildNotesSection(
    List<Map<String, dynamic>> notes,
    pw.Font font, {
    PdfColor? accentColor,
  }) {
    if (notes.isEmpty) return pw.SizedBox();

    final List<pw.Widget> noteWidgets = [];
    noteWidgets.add(PdfHelper.buildSectionHeader('Servis Notları', font));

    for (int i = 0; i < notes.length; i++) {
      final note = notes[i];
      final userName = note['profiles']?['full_name'] ?? 'Teknisyen';
      final dateText = PdfHelper.formatDate(note['created_at']);
      final noteText = note['note'] as String? ?? '';
      final safeNoteText = PdfHelper.safeText(noteText);

      // Notu maksimum 800 karakterle sınırla
      final maxLength = 800;
      final displayText =
          safeNoteText.length > maxLength
              ? '${safeNoteText.substring(0, maxLength)}\n\n... (Not çok uzun - Tam metin için lütfen sisteme bakınız)'
              : safeNoteText;

      noteWidgets.add(
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(3),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                '${i + 1}. $userName - $dateText',
                style: pw.TextStyle(
                  font: font,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 8,
                  color: accentColor ?? PdfHelper.accentColor,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                displayText,
                style: pw.TextStyle(font: font, fontSize: 7),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: noteWidgets,
    );
  }

  static List<pw.Widget> _buildImagesSection(
    List<Map<String, dynamic>> notes,
    pw.Font font,
    PdfColor primary,
  ) {
    final imagesExist = notes.any(
      (n) => (n['pdf_images'] as List?)?.isNotEmpty ?? false,
    );
    if (!imagesExist) return [];

    return [
      pw.NewPage(),
      PdfHelper.buildSectionHeader('EK.1 - SERVİS FOTOĞRAF EKLERİ', font),
      ...notes.where((n) => (n['pdf_images'] as List?)?.isNotEmpty ?? false).map((
        note,
      ) {
        final List<pw.ImageProvider> images = List<pw.ImageProvider>.from(
          note['pdf_images'],
        );
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${note['profiles']?['full_name'] ?? 'Teknisyen'} - ${PdfHelper.formatDate(note['created_at'])}',
              style: pw.TextStyle(
                font: font,
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: primary,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Wrap(
              spacing: 5,
              runSpacing: 5,
              children:
                  images
                      .map(
                        (img) => pw.Container(
                          width: 110,
                          height: 110,
                          child: pw.Image(img, fit: pw.BoxFit.cover),
                        ),
                      )
                      .toList(),
            ),
            pw.SizedBox(height: 12),
          ],
        );
      }),
    ];
  }

  static pw.Widget _buildFooter(
    Map<String, dynamic> ticket,
    pw.Font font, {
    String? address,
  }) {
    return pw.Column(
      children: [
        _buildSignatureRow(ticket, font),
        pw.SizedBox(height: 10),
        if (address != null)
          pw.Center(
            child: pw.Text(
              address,
              style: pw.TextStyle(
                font: font,
                fontSize: 7,
                color: PdfColors.grey600,
              ),
            ),
          ),
        pw.Center(
          child: pw.Text(
            'Bu belge dijital olarak oluşturulmuştur.',
            style: pw.TextStyle(
              font: font,
              fontSize: 8,
              color: PdfColors.grey500,
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSignatureRow(
    Map<String, dynamic> ticket,
    pw.Font font,
  ) {
    final customerImage = PdfHelper.decodeSignatureImage(
      ticket['signature_data'] as String?,
    );
    final techImage = PdfHelper.decodeSignatureImage(
      ticket['technician_signature_data'] as String?,
    );

    // Müşteri imzası: ad ve soyad birleştir
    final customerName = ticket['signature_name'] as String? ?? '';
    final customerSurname = ticket['signature_surname'] as String? ?? '';
    final customerFullName =
        '${customerName.trim()} ${customerSurname.trim()}'.trim();

    // Teknisyen imzası: ad ve soyad birleştir
    final techName = ticket['technician_signature_name'] as String? ?? '';
    final techSurname = ticket['technician_signature_surname'] as String? ?? '';
    final techFullName = '${techName.trim()} ${techSurname.trim()}'.trim();

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            children: [
              pw.Text(
                'MÜŞTERİ ONAYI',
                style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              if (customerImage != null)
                pw.Image(customerImage, width: 100, height: 50)
              else
                pw.SizedBox(height: 50, width: 100),
              pw.Text(
                PdfHelper.safeText(customerFullName),
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
            ],
          ),
          pw.Column(
            children: [
              pw.Text(
                'SERVİS YETKİLİSİ',
                style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              if (techImage != null)
                pw.Image(techImage, width: 100, height: 50)
              else
                pw.SizedBox(height: 50, width: 100),
              pw.Text(
                PdfHelper.safeText(techFullName),
                style: pw.TextStyle(font: font, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
