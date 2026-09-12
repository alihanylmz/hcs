// Musteriye gonderilen servis oncesi onay formunun (soru + Evet/Hayir
// cevabi + imza) PDF cikisi. Kullanicinin istegi acikti: sadece cevaplarla
// basit bir PDF - butun icerik metnini (contentText) tekrar basmiyoruz.
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/service_form.dart';
import '../utils/pdf_helper.dart';

class ServiceFormPdfService {
  static Future<Uint8List> generateAnswersPdfBytes(
    TicketServiceForm form, {
    String? ticketCode,
  }) async {
    final font = await PdfHelper.loadTurkishFont();
    final template = form.template;
    final pdf = pw.Document();

    final signatureImage = PdfHelper.decodeSignatureImage(
      form.signatureData,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                template?.name ?? 'Servis Onceki Onay Formu',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfHelper.primaryColor,
                ),
              ),
              if (ticketCode != null && ticketCode.trim().isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  'Is No: $ticketCode',
                  style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700),
                ),
              ],
              pw.SizedBox(height: 12),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: PdfHelper.buildInfoRow(
                      'Musteri',
                      PdfHelper.safeText(form.customerName),
                      font,
                    ),
                  ),
                  pw.Expanded(
                    child: PdfHelper.buildInfoRow(
                      'Imza Tarihi',
                      form.signedAt != null
                          ? PdfHelper.formatDate(form.signedAt!.toIso8601String())
                          : '-',
                      font,
                    ),
                  ),
                ],
              ),
              PdfHelper.buildSectionHeader('Cevaplar', font),
              pw.SizedBox(height: 4),
              if (template == null || template.checkboxes.isEmpty)
                pw.Text(
                  'Bu forma ait madde bulunamadi.',
                  style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
                )
              else
                pw.Table(
                  border: pw.TableBorder.symmetric(
                    inside: const pw.BorderSide(color: PdfColors.grey300),
                  ),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(4),
                    1: pw.FlexColumnWidth(1),
                  },
                  children: [
                    for (var i = 0; i < template.checkboxes.length; i++)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 4,
                            ),
                            child: pw.Text(
                              template.checkboxes[i].label,
                              style: pw.TextStyle(font: font, fontSize: 10),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 4,
                            ),
                            child: pw.Text(
                              _answerLabel(form, i),
                              style: pw.TextStyle(
                                font: font,
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: _answerColor(form, i),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              pw.SizedBox(height: 24),
              if (signatureImage != null) ...[
                pw.Text(
                  'Musteri Imzasi',
                  style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  height: 90,
                  width: 220,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                ),
              ],
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static String _answerLabel(TicketServiceForm form, int index) {
    final answer = form.answers[index];
    if (answer == true) return 'Evet';
    if (answer == false) return 'Hayir';
    // Eski kayitlarda `answers` sutunu bos olabilir; checkedItems'a bak.
    return form.checkedItems.contains(index) ? 'Evet' : 'Cevaplanmadi';
  }

  static PdfColor _answerColor(TicketServiceForm form, int index) {
    final answer = form.answers[index];
    if (answer == true) return PdfColors.green800;
    if (answer == false) return PdfColors.red800;
    return form.checkedItems.contains(index)
        ? PdfColors.green800
        : PdfColors.grey600;
  }
}
