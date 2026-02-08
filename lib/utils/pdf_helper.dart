import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'text_sanitizer.dart';

class PdfHelper {
  static const PdfColor primaryColor = PdfColors.blueGrey900;
  static const PdfColor accentColor = PdfColors.teal700;
  static const PdfColor lightBgColor = PdfColors.grey100;

  static Future<pw.Font> loadTurkishFont() async {
    try {
      final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      try {
        return await PdfGoogleFonts.notoSansRegular();
      } catch (e2) {
        return pw.Font.helvetica();
      }
    }
  }

  static pw.ImageProvider? decodeSignatureImage(String? base64Data) {
    if (base64Data == null || base64Data.isEmpty) return null;
    try {
      final bytes = base64Decode(base64Data);
      return pw.MemoryImage(bytes);
    } catch (e) {
      return null;
    }
  }

  static Future<pw.ImageProvider?> loadPointLogo() async {
    try {
      final pngData = await rootBundle.load('assets/images/point.png');
      final pngBytes = pngData.buffer.asUint8List();
      return pw.MemoryImage(pngBytes);
    } catch (e) {
      return null;
    }
  }

  static Future<pw.ImageProvider?> loadVensaLogo() async {
    try {
      final pngData = await rootBundle.load('assets/images/vensa.png');
      final pngBytes = pngData.buffer.asUint8List();
      return pw.MemoryImage(pngBytes);
    } catch (e) {
      return null;
    }
  }

  static String formatDate(String? iso) {
    if (iso == null) return '-';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(parsed);
  }

  static String safeText(dynamic value) {
    if (value == null) return '-';
    if (value is String && value.trim().isEmpty) return '-';
    return TextSanitizer.stripEmoji(value.toString());
  }

  static pw.Widget buildSectionHeader(String title, pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10, top: 15),
      padding: const pw.EdgeInsets.only(bottom: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: accentColor, width: 2)),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget buildInfoRow(String label, String value, pw.Font font, {bool isFullWidth = false}) {
    return pw.Container(
      width: isFullWidth ? double.infinity : null,
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.black),
          ),
        ],
      ),
    );
  }
}
