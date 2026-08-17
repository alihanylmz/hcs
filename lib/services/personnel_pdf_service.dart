import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/user_profile.dart';
import '../utils/pdf_helper.dart';

class PersonnelPdfService {
  static Future<Uint8List> generatePersonnelStatementPdf({
    required UserProfile personnel,
    required List<Map<String, dynamic>> activeLoans,
    required List<Map<String, dynamic>> pastLoans,
    required List<Map<String, dynamic>> tickets,
    required List<Map<String, dynamic>> notes,
  }) async {
    final pdf = pw.Document();
    final font = await PdfHelper.loadTurkishFont();
    final nowFormatted = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());

    final consumedCount =
        pastLoans.where((l) => l['status'] == 'consumed').length;
    final returnedCount =
        pastLoans.where((l) => l['status'] == 'returned').length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header: (context) => _buildHeader(personnel, nowFormatted),
        footer: (context) => _buildFooter(context),
        build:
            (context) => [
              _buildSummaryCards(
                activeCount: activeLoans.length,
                consumedCount: consumedCount,
                returnedCount: returnedCount,
                ticketCount: tickets.length,
              ),
              pw.SizedBox(height: 14),

              // 1. AKTİF ZİMMETLER
              _buildSectionTitle(
                '1. ÜZERİNDEKİ AKTİF ZİMMETLİ CİHAZLAR & PARÇALAR (${activeLoans.length})',
              ),
              pw.SizedBox(height: 6),
              if (activeLoans.isEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                  child: pw.Text(
                    'Personelin üzerinde şu an aktif açık zimmetli cihaz bulunmamaktadır.',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                )
              else
                _buildLoansTable(activeLoans, isActive: true),

              pw.SizedBox(height: 14),

              // 2. GEÇMİŞ ZİMMET & SARFİYATLAR
              _buildSectionTitle(
                '2. GEÇMİŞ ZİMMET & SARFİYAT / İADE HAREKETLERİ (${pastLoans.length})',
              ),
              pw.SizedBox(height: 6),
              if (pastLoans.isEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                  child: pw.Text(
                    'Geçmiş zimmet kaydı bulunmamaktadır.',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                )
              else
                _buildLoansTable(pastLoans.take(20).toList(), isActive: false),

              pw.SizedBox(height: 14),

              // 3. İŞ EMİRLERİ
              _buildSectionTitle(
                '3. DAHİL OLDUĞU İŞ EMİRLERİ & SAHA GÖREVLERİ (${tickets.length})',
              ),
              pw.SizedBox(height: 6),
              if (tickets.isEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(4),
                    ),
                  ),
                  child: pw.Text(
                    'Kayıtlı iş emri bulunmamaktadır.',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                )
              else
                _buildTicketsTable(tickets.take(15).toList()),

              if (notes.isNotEmpty) ...[
                pw.SizedBox(height: 14),
                _buildSectionTitle(
                  '4. PERSONEL YÖNETİCİ NOTLARI (${notes.length})',
                ),
                pw.SizedBox(height: 6),
                _buildNotesList(notes),
              ],

              pw.SizedBox(height: 24),
              _buildSignatureBlock(personnel.displayName),
            ],
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildHeader(UserProfile personnel, String nowFormatted) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'UZAL TEKNİK MÜHENDİSLİK',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'PERSONEL ZİMMET, İŞ VE SARFİYAT EKSTRESİ',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey700,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Personel: ${personnel.displayName}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.Text(
                'Rol: ${formatRole(personnel.role)} | E-posta: ${personnel.email ?? '-'}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
              pw.Text(
                'Rapor Tarihi: $nowFormatted',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryCards({
    required int activeCount,
    required int consumedCount,
    required int returnedCount,
    required int ticketCount,
  }) {
    return pw.Row(
      children: [
        _buildMetricBox(
          'Aktif Zimmetli Cihaz',
          '$activeCount Adet',
          PdfColors.amber800,
          PdfColors.amber50,
        ),
        pw.SizedBox(width: 8),
        _buildMetricBox(
          'Sahada Sarf Edilen',
          '$consumedCount Adet',
          PdfColors.blue800,
          PdfColors.blue50,
        ),
        pw.SizedBox(width: 8),
        _buildMetricBox(
          'Depoya Sağlam İade',
          '$returnedCount Adet',
          PdfColors.green800,
          PdfColors.green50,
        ),
        pw.SizedBox(width: 8),
        _buildMetricBox(
          'Kayıtlı İş Emri',
          '$ticketCount Görev',
          PdfColors.purple800,
          PdfColors.purple50,
        ),
      ],
    );
  }

  static pw.Widget _buildMetricBox(
    String title,
    String value,
    PdfColor textColor,
    PdfColor bgColor,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: bgColor,
          border: pw.Border.all(color: textColor, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 7,
                color: textColor,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                color: textColor,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey900,
        ),
      ),
    );
  }

  static pw.Widget _buildLoansTable(
    List<Map<String, dynamic>> loans, {
    required bool isActive,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2), // Tarih
        1: const pw.FlexColumnWidth(1.4), // Seri No
        2: const pw.FlexColumnWidth(2.5), // Ürün Adı
        3: const pw.FlexColumnWidth(1.0), // Miktar
        4: const pw.FlexColumnWidth(1.2), // İş Kodu
        5: const pw.FlexColumnWidth(1.2), // Durum / Açıklama
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeaderCell('Veriliş Tarihi'),
            _tableHeaderCell('Seri Numarası'),
            _tableHeaderCell('Ürün / Cihaz Adı'),
            _tableHeaderCell('Adet'),
            _tableHeaderCell('İş Kodu'),
            _tableHeaderCell(isActive ? 'Not / Lokasyon' : 'Sonuç / Durum'),
          ],
        ),
        ...loans.map((loan) {
          final product = loan['inventory'] ?? {};
          final name = product['displayName'] ?? product['name'] ?? '-';
          final sn = loan['serial_number']?.toString() ?? '-';
          final qty = loan['quantity']?.toString() ?? '1';
          final jobCode = loan['job_code']?.toString() ?? '-';
          final dateStr = _formatDateStr(loan['borrowed_at']);
          final status = loan['status']?.toString();

          String statusLabel = '-';
          PdfColor statusColor = PdfColors.black;
          if (isActive) {
            statusLabel = loan['note']?.toString() ?? 'Zimmette';
          } else {
            if (status == 'consumed') {
              statusLabel = 'Sarf Edildi';
              statusColor = PdfColors.blue800;
            } else if (status == 'returned') {
              statusLabel = 'Stoğa İade';
              statusColor = PdfColors.green800;
            } else {
              statusLabel = status ?? '-';
            }
          }

          return pw.TableRow(
            children: [
              _tableBodyCell(dateStr),
              _tableBodyCell(sn, isBold: sn != '-'),
              _tableBodyCell(name),
              _tableBodyCell(qty, align: pw.TextAlign.center),
              _tableBodyCell(jobCode),
              _tableBodyCell(statusLabel, color: statusColor),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTicketsTable(List<Map<String, dynamic>> tickets) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2), // İş Kodu
        1: const pw.FlexColumnWidth(2.5), // Başlık
        2: const pw.FlexColumnWidth(2.0), // Müşteri
        3: const pw.FlexColumnWidth(1.2), // Durum
        4: const pw.FlexColumnWidth(1.2), // Planlanan Tarih
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _tableHeaderCell('İş Kodu'),
            _tableHeaderCell('İş Başlığı'),
            _tableHeaderCell('Müşteri'),
            _tableHeaderCell('Durum'),
            _tableHeaderCell('Tarih'),
          ],
        ),
        ...tickets.map((t) {
          final customer = t['customers'];
          final custName = customer is Map ? (customer['name'] ?? '-') : '-';
          return pw.TableRow(
            children: [
              _tableBodyCell(t['job_code']?.toString() ?? '-', isBold: true),
              _tableBodyCell(t['title']?.toString() ?? '-'),
              _tableBodyCell(custName.toString()),
              _tableBodyCell(t['status']?.toString() ?? '-'),
              _tableBodyCell(
                _formatDateStr(t['planned_date'] ?? t['created_at']),
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildNotesList(List<Map<String, dynamic>> notes) {
    return pw.Column(
      children:
          notes.map((n) {
            final date = _formatDateStr(n['created_at']);
            final creator =
                n['profiles'] is Map
                    ? (n['profiles']['full_name'] ??
                        n['profiles']['email'] ??
                        'Yönetici')
                    : 'Yönetici';
            final text = n['note']?.toString() ?? '';

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 4),
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '[$date - $creator]: ',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      text,
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  static pw.Widget _buildSignatureBlock(String personnelName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Container(
          width: 200,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Depo Sorumlusu / Yönetici',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Container(height: 1, color: PdfColors.grey500),
              pw.SizedBox(height: 2),
              pw.Text(
                'İmza / Kaşe',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        pw.Container(
          width: 200,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'Personel: $personnelName',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Container(height: 1, color: PdfColors.grey500),
              pw.SizedBox(height: 2),
              pw.Text(
                'İmza / Tarih',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Uzal Teknik ERP - Personel Takip Sistemi',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text(
            'Sayfa ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey900,
        ),
      ),
    );
  }

  static pw.Widget _tableBodyCell(
    String text, {
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
    PdfColor color = PdfColors.black,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isBold ? pw.FontWeight.bold : null,
          color: color,
        ),
      ),
    );
  }

  static String formatRole(String? role) {
    switch (role) {
      case 'admin':
        return 'Yönetici';
      case 'manager':
        return 'Müdür';
      case 'stock_manager':
        return 'Stok Sorumlusu';
      case 'technician':
        return 'Teknisyen';
      case 'supervisor':
        return 'Süpervizör';
      default:
        return role ?? 'Personel';
    }
  }

  static String _formatDateStr(dynamic dt) {
    if (dt == null) return '-';
    try {
      final parsed = DateTime.parse(dt.toString()).toLocal();
      return DateFormat('dd.MM.yyyy').format(parsed);
    } catch (_) {
      return dt.toString();
    }
  }
}
