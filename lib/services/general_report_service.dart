import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class GeneralReportService {
  Future<void> generateAndPrintReport(List<Map<String, dynamic>> allTickets, String userName) async {
    final pdf = pw.Document();

    // Kurumsal ve ciddi duran fontlar (OpenSans - Daha geniş Türkçe karakter desteği)
    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();
    final fontItalic = await PdfGoogleFonts.openSansItalic();

    // İstatistikleri hesapla
    final openCount = allTickets.where((e) => e['status'] == 'open').length;
    final stockCount = allTickets.where((e) => e['status'] == 'panel_done_stock').length;
    final sentCount = allTickets.where((e) => e['status'] == 'panel_done_sent').length;
    final progressCount = allTickets.where((e) => e['status'] == 'in_progress').length;
    final totalCount = allTickets.length;

    // Renk Paleti (Kurumsal Lacivert ve Gri)
    final PdfColor primaryColor = PdfColors.blue900;
    final PdfColor accentColor = PdfColors.grey200;
    final PdfColor zebraColor = PdfColors.grey100;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        
        // --- ALT BİLGİ (Footer) ---
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'HanCoSys İş Takip Sistemi - Gizli Belge',
                  style: pw.TextStyle(font: fontItalic, fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Sayfa ${context.pageNumber} / ${context.pagesCount}',
                  style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            )
          );
        },
        build: (pw.Context context) {
          return [
            // --- KURUMSAL BAŞLIK ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('HANCOSYS', style: pw.TextStyle(font: fontBold, fontSize: 24, color: primaryColor)),
                    pw.Text('Teknik Servis & İş Takip', style: pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('GENEL DURUM RAPORU', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                    pw.Text(DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(DateTime.now()), style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                    pw.Text('Oluşturan: $userName', style: pw.TextStyle(font: fontItalic, fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 5),
            pw.Divider(color: primaryColor, thickness: 2),
            pw.SizedBox(height: 20),

            // --- İSTATİSTİK ÖZET TABLOSU ---
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: accentColor,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('AÇIK İŞLER', openCount.toString(), PdfColors.red900, fontBold),
                  _buildStatItem('SERVİSTE', progressCount.toString(), PdfColors.orange800, fontBold),
                  _buildStatItem('STOKTA (PANO)', stockCount.toString(), PdfColors.purple800, fontBold),
                  _buildStatItem('GÖNDERİLEN', sentCount.toString(), PdfColors.blue800, fontBold),
                  _buildStatItem('TOPLAM', totalCount.toString(), PdfColors.black, fontBold),
                ],
              ),
            ),
            pw.SizedBox(height: 25),

            // --- DETAYLI İŞ LİSTESİ ---
            pw.Text('İş Listesi Detayları', style: pw.TextStyle(font: fontBold, fontSize: 14, color: primaryColor)),
            pw.SizedBox(height: 10),
            
            // --- TABLO ---
            pw.Theme(
              data: pw.ThemeData.withFont(
                base: fontRegular,
                bold: fontBold,
                italic: fontItalic,
              ),
              child: pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(65),  // İş Kodu (Genişletildi)
                1: const pw.FlexColumnWidth(2.5),  // Müşteri Bilgisi (Ad + Adres)
                2: const pw.FlexColumnWidth(2),    // İş Başlığı
                3: const pw.FixedColumnWidth(70),  // Durum
                4: const pw.FixedColumnWidth(60),  // Tarih
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: primaryColor),
                  children: [
                    _buildHeaderCell('KOD', fontBold),
                    _buildHeaderCell('MÜŞTERİ BİLGİLERİ', fontBold),
                    _buildHeaderCell('İŞ BAŞLIĞI', fontBold),
                    _buildHeaderCell('DURUM', fontBold),
                    _buildHeaderCell('TARİH', fontBold),
                  ]
                ),
                // Data Rows
                ...List.generate(allTickets.length, (index) {
                  final ticket = allTickets[index];
                  final customer = ticket['customers'] as Map<String, dynamic>? ?? {};
                  final customerName = customer['name'] ?? 'İsimsiz';
                  final address = customer['address'] ?? '-';
                  final isOdd = index % 2 != 0;
                  
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: isOdd ? zebraColor : PdfColors.white),
                    verticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: [
                      _buildCell(ticket['job_code'] ?? '-', fontRegular, alignment: pw.Alignment.center),
                      
                      // Müşteri ve Adres (Zengin İçerik)
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(customerName, style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.black)),
                            pw.SizedBox(height: 2),
                            pw.Text(address, style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                      
                      // İş Başlığı ve Cihaz Modeli
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(ticket['title'] ?? '', style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                            if (ticket['device_model'] != null) ...[
                               pw.SizedBox(height: 2),
                               pw.Text(ticket['device_model'], style: pw.TextStyle(font: fontItalic, fontSize: 8, color: PdfColors.grey600)),
                            ]
                          ],
                        ),
                      ),
                      
                      // Durum Rozeti
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: _buildStatusBadge(ticket['status'], fontBold),
                      ),
                      
                      _buildCell(
                        ticket['planned_date'] != null 
                          ? DateFormat('dd.MM.yyyy').format(DateTime.parse(ticket['planned_date'])) 
                          : '-', 
                        fontRegular,
                        alignment: pw.Alignment.center
                      ),
                    ],
                  );
                }),
              ],
            ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'HanCoSys_Rapor_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
    );
  }

  pw.Widget _buildStatItem(String title, String value, PdfColor color, pw.Font font) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: 16, color: color)),
        pw.SizedBox(height: 2),
        pw.Text(title, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
      ],
    );
  }

  pw.Widget _buildHeaderCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, color: PdfColors.white, fontSize: 9),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildCell(String text, pw.Font font, {pw.Alignment alignment = pw.Alignment.centerLeft}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Align(
        alignment: alignment,
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9)),
      ),
    );
  }

  pw.Widget _buildStatusBadge(String? status, pw.Font font) {
    String label = '-';
    PdfColor color = PdfColors.grey;
    PdfColor textColor = PdfColors.white;

    switch (status) {
      case 'open':
        label = 'AÇIK';
        color = PdfColors.blue700;
        break;
      case 'panel_done_stock':
        label = 'STOKTA';
        color = PdfColors.purple700;
        break;
      case 'panel_done_sent':
        label = 'GÖNDERİLDİ';
        color = PdfColors.indigo700;
        break;
      case 'in_progress':
        label = 'SERVİSTE';
        color = PdfColors.orange700;
        break;
      case 'done':
        label = 'TAMAMLANDI';
        color = PdfColors.green700;
        break;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        label,
        style: pw.TextStyle(font: font, color: textColor, fontSize: 7),
      ),
    );
  }
}
