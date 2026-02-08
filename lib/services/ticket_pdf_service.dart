import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../utils/pdf_helper.dart';

class TicketPdfService {
  static const Map<String, String> _statusLabels = {
    'open': 'Açık',
    'panel_done_stock': 'Panosu Yapıldı Stokta',
    'panel_done_sent': 'Panosu Yapıldı Gönderildi',
    'in_progress': 'Serviste',
    'done': 'Tamamlandı',
    'archived': 'Arşivde',
    'cancelled': 'İptal',
  };

  static Future<Uint8List> generateSingleTicketPdfBytes(String ticketId, {String? technicianSignature}) async {
    try {
      final supabase = Supabase.instance.client;
      final idValue = int.tryParse(ticketId) ?? ticketId;

      final ticketData = await supabase
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

      if (technicianSignature != null && ticket['technician_signature_data'] == null) {
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
      } else if (partnerName != null && partnerName.toLowerCase().contains('vensa')) {
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
  }) async {
    try {
      final pdf = pw.Document();
      final font = await PdfHelper.loadTurkishFont();
      final now = DateTime.now();

      final lowerPartner = (partnerName ?? '').toLowerCase();
      final bool isPoint = lowerPartner.contains('point');
      final bool isVensa = lowerPartner.contains('vensa');

      final PdfColor themePrimary = isPoint
          ? const PdfColor.fromInt(0xFFD32F2F)
          : isVensa
              ? const PdfColor.fromInt(0xFF1976D2)
              : PdfHelper.primaryColor;

      final pw.ImageProvider? logo = isPoint
          ? await PdfHelper.loadPointLogo()
          : isVensa
              ? await PdfHelper.loadVensaLogo()
              : null;

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
            theme: pw.ThemeData.withFont(base: font, bold: font),
          ),
          header: (context) => pw.Column(
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
                        pw.Container(width: 56, height: 56, child: pw.Image(logo, fit: pw.BoxFit.contain)),
                        pw.SizedBox(width: 12),
                      ],
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(reportTitle, style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold, color: themePrimary)),
                          if ((partnerName ?? '').trim().isNotEmpty)
                            pw.Text(PdfHelper.safeText(partnerName), style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(now), style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                      pw.Text('Toplam: ${tickets.length}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: themePrimary, thickness: 2),
              pw.SizedBox(height: 6),
            ],
          ),
          footer: (context) => pw.Container(
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('HanCoSys İş Takip Sistemi', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
                pw.Text('Sayfa ${context.pageNumber} / ${context.pagesCount}', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
          ),
          build: (context) {
            if (tickets.isEmpty) return [pw.Center(child: pw.Text('Liste boş.', style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey700)))];

            return [
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
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
                    children: ['KOD', 'MÜŞTERİ', 'İŞ', 'DURUM', 'TARİH'].map((h) => pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(h, style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.white), textAlign: pw.TextAlign.center))).toList(),
                  ),
                  ...tickets.asMap().entries.map((entry) {
                    final i = entry.key;
                    final t = entry.value;
                    final customer = t['customers'] as Map<String, dynamic>? ?? {};
                    final status = _statusLabels[t['status']] ?? (t['status'] ?? '-');
                    String dateText = '-';
                    if (t['planned_date'] != null) {
                      final parsed = DateTime.tryParse(t['planned_date']);
                      if (parsed != null) dateText = DateFormat('dd.MM.yyyy', 'tr_TR').format(parsed);
                    }

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: i.isOdd ? PdfColors.grey50 : PdfColors.white),
                      verticalAlignment: pw.TableCellVerticalAlignment.middle,
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(PdfHelper.safeText(t['job_code']), style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(PdfHelper.safeText(customer['name']), style: pw.TextStyle(font: font, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(PdfHelper.safeText(t['title']), style: pw.TextStyle(font: font, fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(status, style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(dateText, style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
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
      throw Exception('Liste PDF oluşturma hatası: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> _enrichNotesWithImages(List<Map<String, dynamic>> notes) async {
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

  static Future<pw.Document> _generateStandardTicketPdf(Map<String, dynamic> ticket, List<Map<String, dynamic>> notes) async {
    final pdf = pw.Document();
    final font = await PdfHelper.loadTurkishFont();
    final customer = ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final status = ticket['status'] as String? ?? 'open';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header: (context) => _buildHeader(ticket, font, "TEKNİK SERVİS HİZMETLERİ", PdfHelper.primaryColor, PdfHelper.accentColor),
        footer: (context) => _buildFooter(ticket, font),
        build: (context) => [
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

  static Future<pw.Document> _generatePointTicketPdf(Map<String, dynamic> ticket, List<Map<String, dynamic>> notes) async {
    final pdf = pw.Document();
    final font = await PdfHelper.loadTurkishFont();
    final logo = await PdfHelper.loadPointLogo();
    final customer = ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
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
        header: (context) => _buildHeaderWithLogo(ticket, font, logo, "Teknik Servis İş Emri ve Servis Formu", primaryColor),
        footer: (context) => _buildFooter(ticket, font, address: 'Dağyaka Mah. 2022.Cad No:18/1, KahramanKazan/ANKARA'),
        build: (context) => [
          _buildInfoSection(ticket, customer, font, status, accentColor: accentColor),
          _buildDescriptionSection(ticket, font),
          _buildTechnicalSection(ticket, font),
          _buildNotesSection(notes, font, accentColor: accentColor),
          ..._buildImagesSection(notes, font, primaryColor),
        ],
      ),
    );
    return pdf;
  }

  static Future<pw.Document> _generateVensaTicketPdf(Map<String, dynamic> ticket, List<Map<String, dynamic>> notes) async {
    final pdf = pw.Document();
    final font = await PdfHelper.loadTurkishFont();
    final logo = await PdfHelper.loadVensaLogo();
    final customer = ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
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
        header: (context) => _buildHeaderWithLogo(ticket, font, logo, "Teknik Servis İş Emri ve Servis Formu", primaryColor),
        footer: (context) => _buildFooter(ticket, font, address: 'Pursaklar Sanayi Sitesi 1643. Cad. No: 18 Altındağ, Ankara'),
        build: (context) => [
          _buildInfoSection(ticket, customer, font, status, accentColor: accentColor),
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

  static pw.Widget _buildHeader(Map<String, dynamic> ticket, pw.Font font, String title, PdfColor primary, PdfColor accent) {
    return pw.Column(children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(title, style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold, color: primary)),
          pw.Text('Servis Formu ve İş Emri Belgesi', style: pw.TextStyle(font: font, fontSize: 10, color: accent)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: pw.BoxDecoration(color: PdfHelper.lightBgColor, borderRadius: pw.BorderRadius.circular(4), border: pw.Border.all(color: PdfColors.grey300)),
            child: pw.Text('İŞ NO: ${PdfHelper.safeText(ticket['job_code'])}', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Tarih: ${PdfHelper.formatDate(DateTime.now().toIso8601String())}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
        ]),
      ]),
      pw.SizedBox(height: 10),
      pw.Divider(color: primary, thickness: 2),
    ]);
  }

  static pw.Widget _buildHeaderWithLogo(Map<String, dynamic> ticket, pw.Font font, pw.ImageProvider? logo, String title, PdfColor primary) {
    return pw.Column(children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Row(children: [
          if (logo != null) ...[
            pw.Container(width: 100, height: 100, child: pw.Image(logo, fit: pw.BoxFit.contain)),
            pw.SizedBox(width: 12),
          ],
          pw.Text(title, style: pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold, color: primary)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: pw.BoxDecoration(color: PdfHelper.lightBgColor, borderRadius: pw.BorderRadius.circular(4), border: pw.Border.all(color: PdfColors.grey300)),
            child: pw.Text('İŞ NO: ${PdfHelper.safeText(ticket['job_code'])}', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 12)),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Tarih: ${PdfHelper.formatDate(DateTime.now().toIso8601String())}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
        ]),
      ]),
      pw.SizedBox(height: 10),
      pw.Divider(color: primary, thickness: 2),
    ]);
  }

  static pw.Widget _buildWatermark(pw.ImageProvider? logo) {
    if (logo == null) return pw.SizedBox();
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Center(
        child: pw.Opacity(
          opacity: 0.05,
          child: pw.Image(logo, width: 400, height: 400, fit: pw.BoxFit.contain),
        ),
      ),
    );
  }

  static pw.Widget _buildInfoSection(Map<String, dynamic> ticket, Map<String, dynamic> customer, pw.Font font, String status, {PdfColor? accentColor}) {
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Expanded(flex: 5, child: pw.Column(children: [
        PdfHelper.buildSectionHeader('Müşteri Bilgileri', font),
        pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(color: PdfHelper.lightBgColor, borderRadius: pw.BorderRadius.circular(5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          PdfHelper.buildInfoRow('Ünvan', PdfHelper.safeText(customer['name']), font, isFullWidth: true),
          pw.SizedBox(height: 5),
          PdfHelper.buildInfoRow('Telefon', PdfHelper.safeText(customer['phone']), font),
          pw.Divider(height: 10),
          PdfHelper.buildInfoRow('Adres', PdfHelper.safeText(customer['address']), font, isFullWidth: true),
        ])),
      ])),
      pw.SizedBox(width: 20),
      pw.Expanded(flex: 4, child: pw.Column(children: [
        PdfHelper.buildSectionHeader('Servis Detayları', font),
        pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          PdfHelper.buildInfoRow('Cihaz', PdfHelper.safeText(ticket['device_model']), font),
          pw.Divider(),
          pw.Row(children: [
            pw.Expanded(child: PdfHelper.buildInfoRow('Tarih', PdfHelper.formatDate(ticket['planned_date'] as String?), font)),
            pw.Expanded(child: PdfHelper.buildInfoRow('Durum', _statusLabels[status] ?? status, font)),
          ]),
        ])),
      ])),
    ]);
  }

  static pw.Widget _buildDescriptionSection(Map<String, dynamic> ticket, pw.Font font) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      PdfHelper.buildSectionHeader('İş Açıklaması', font),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(5)),
        child: pw.Text(PdfHelper.safeText(ticket['description']), style: pw.TextStyle(font: font, fontSize: 10)),
      ),
    ]);
  }

  static pw.Widget _buildTechnicalSection(Map<String, dynamic> ticket, pw.Font font) {
    final aspKw = ticket['aspirator_kw'];
    final vantKw = ticket['vant_kw'];
    final hmiBrand = ticket['hmi_brand'];
    if (aspKw == null && vantKw == null && hmiBrand == null) return pw.SizedBox();

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      PdfHelper.buildSectionHeader('Teknik Bilgiler', font),
      pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300),
        children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: PdfHelper.lightBgColor), children: [
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Bileşen', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 9))),
            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Detay', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 9))),
          ]),
          if (aspKw != null) _buildZebraRow('Aspiratör', '${PdfHelper.safeText(aspKw)} kW', font, 0),
          if (vantKw != null) _buildZebraRow('Vantilatör', '${PdfHelper.safeText(vantKw)} kW', font, 1),
          if (hmiBrand != null) _buildZebraRow('HMI Ekran', '${PdfHelper.safeText(hmiBrand)}', font, 0),
        ],
      ),
    ]);
  }

  static pw.TableRow _buildZebraRow(String label, String value, pw.Font font, int index) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: index % 2 == 0 ? PdfColors.white : PdfColors.grey100),
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(value, style: pw.TextStyle(font: font, fontSize: 9))),
      ],
    );
  }

  static pw.Widget _buildNotesSection(List<Map<String, dynamic>> notes, pw.Font font, {PdfColor? accentColor}) {
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
      final displayText = safeNoteText.length > maxLength
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

  static List<pw.Widget> _buildImagesSection(List<Map<String, dynamic>> notes, pw.Font font, PdfColor primary) {
    final imagesExist = notes.any((n) => (n['pdf_images'] as List?)?.isNotEmpty ?? false);
    if (!imagesExist) return [];

    return [
      pw.NewPage(),
      PdfHelper.buildSectionHeader('EK.1 - SERVİS FOTOĞRAF EKLERİ', font),
      ...notes.where((n) => (n['pdf_images'] as List?)?.isNotEmpty ?? false).map((note) {
        final List<pw.ImageProvider> images = List<pw.ImageProvider>.from(note['pdf_images']);
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('${note['profiles']?['full_name'] ?? 'Teknisyen'} - ${PdfHelper.formatDate(note['created_at'])}', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold, color: primary)),
          pw.SizedBox(height: 4),
          pw.Wrap(spacing: 5, runSpacing: 5, children: images.map((img) => pw.Container(width: 110, height: 110, child: pw.Image(img, fit: pw.BoxFit.cover))).toList()),
          pw.SizedBox(height: 12),
        ]);
      }),
    ];
  }

  static pw.Widget _buildFooter(Map<String, dynamic> ticket, pw.Font font, {String? address}) {
    return pw.Column(children: [
      _buildSignatureRow(ticket, font),
      pw.SizedBox(height: 10),
      if (address != null) pw.Center(child: pw.Text(address, style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600))),
      pw.Center(child: pw.Text('Bu belge dijital olarak oluşturulmuştur.', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500))),
    ]);
  }

  static pw.Widget _buildSignatureRow(Map<String, dynamic> ticket, pw.Font font) {
    final customerImage = PdfHelper.decodeSignatureImage(ticket['signature_data'] as String?);
    final techImage = PdfHelper.decodeSignatureImage(ticket['technician_signature_data'] as String?);

    // Müşteri imzası: ad ve soyad birleştir
    final customerName = ticket['signature_name'] as String? ?? '';
    final customerSurname = ticket['signature_surname'] as String? ?? '';
    final customerFullName = '${customerName.trim()} ${customerSurname.trim()}'.trim();

    // Teknisyen imzası: ad ve soyad birleştir
    final techName = ticket['technician_signature_name'] as String? ?? '';
    final techSurname = ticket['technician_signature_surname'] as String? ?? '';
    final techFullName = '${techName.trim()} ${techSurname.trim()}'.trim();

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(children: [
          pw.Text('MÜŞTERİ ONAYI', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          if (customerImage != null) pw.Image(customerImage, width: 100, height: 50) else pw.SizedBox(height: 50, width: 100),
          pw.Text(PdfHelper.safeText(customerFullName), style: pw.TextStyle(font: font, fontSize: 9)),
        ]),
        pw.Column(children: [
          pw.Text('SERVİS YETKİLİSİ', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          if (techImage != null) pw.Image(techImage, width: 100, height: 50) else pw.SizedBox(height: 50, width: 100),
          pw.Text(PdfHelper.safeText(techFullName), style: pw.TextStyle(font: font, fontSize: 9)),
        ]),
      ]),
    );
  }
}
