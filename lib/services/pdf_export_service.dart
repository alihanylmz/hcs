import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/pdf_file_saver/pdf_file_saver.dart';
import 'ticket_pdf_service.dart';
import 'stock_pdf_service.dart';

class PdfExportService {
  /// Tekil iş emri PDF'i üretir
  static Future<Uint8List> generateSingleTicketPdfBytes(String ticketId, {String? technicianSignature}) {
    return TicketPdfService.generateSingleTicketPdfBytes(ticketId, technicianSignature: technicianSignature);
  }

  /// Güncel stok raporu PDF'i üretir
  static Future<Uint8List> generateStockReportPdfBytes() {
    return StockPdfService.generateStockReportPdfBytes();
  }

  /// Liste halindeki işleri PDF yapar
  static Future<Uint8List> generateTicketListPdfBytesFromList({
    required List<Map<String, dynamic>> tickets,
    required String reportTitle,
    String? partnerName,
  }) {
    return TicketPdfService.generateTicketListPdfBytesFromList(
      tickets: tickets,
      reportTitle: reportTitle,
      partnerName: partnerName,
    );
  }

  /// Verilen stok listesinden sipariş listesi üretir
  static Future<Uint8List> generateOrderListPdfBytesFromList(List<Map<String, dynamic>> items) {
    return StockPdfService.generateOrderListPdfBytesFromList(items);
  }

  /// Yıllık kullanım raporu PDF'i üretir
  static Future<Uint8List> generateAnnualUsageReportPdfBytes() {
    return StockPdfService.generateAnnualUsageReportPdfBytes();
  }

  /// Sipariş listesi PDF'i üretir
  static Future<Uint8List> generateOrderListPdfBytes() {
    return StockPdfService.generateOrderListPdfBytes();
  }

  /// PDF'i ekranda önizler
  static Future<void> viewPdf(Uint8List bytes, String fileName) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: fileName,
    );
  }

  /// PDF'i dosya olarak kaydeder
  static Future<String?> savePdf(Uint8List bytes, String fileName) async {
    try {
      if (kIsWeb) {
        await PdfFileSaver.save(bytes: bytes, filename: fileName);
        return 'Dosya indiriliyor';
      } else if (Platform.isAndroid || Platform.isIOS) {
        await Printing.sharePdf(bytes: bytes, filename: '$fileName.pdf');
        return 'Dosya paylaşım menüsü açıldı';
      } else {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'PDF Kaydet',
          fileName: '$fileName.pdf',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);
          return 'Dosya kaydedildi: $outputFile';
        }
        return null;
      }
    } catch (e) {
      throw Exception('PDF kaydetme hatası: $e');
    }
  }
}
