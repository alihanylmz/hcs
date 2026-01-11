import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../models/daily_activity.dart';
import '../services/daily_activity_service.dart';
import '../utils/text_sanitizer.dart';

class DailyActivityReportService {
  final DailyActivityService _activityService = DailyActivityService();

  // --- PDF TEMASI ---
  static const PdfColor _primary = PdfColor.fromInt(0xFF1F2933);
  static const PdfColor _border = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor _mutedBg = PdfColors.grey200;

  // DİĞER SAYFALARDA ÇALIŞAN FONT YÜKLEME METODU
  Future<pw.Font> _loadTurkishFont({bool bold = false}) async {
    try {
      // Önce lokal asset'ten yüklemeyi dene (Web'de daha güvenilir)
      // NOT: Bold font asset'te yoksa regular'ı kullanacağız (Türkçe karakter desteği için)
      final fontPath = 'assets/fonts/NotoSans-Regular.ttf';
      final fontData = await rootBundle.load(fontPath);
      return pw.Font.ttf(fontData);
    } catch (e) {
      print('Yerel font yüklenemedi, Google Fonts deneniyor: $e');
      try {
        return bold ? await PdfGoogleFonts.notoSansBold() : await PdfGoogleFonts.notoSansRegular();
      } catch (e2) {
        print('Google Fonts da yüklenemedi: $e2');
        return pw.Font.helvetica();
      }
    }
  }

  Future<Uint8List> generateReport({
    required List<DailyActivity> activities,
    required DateTime date,
    String userName = "Personel",
  }) async {
    try {
      final pdf = pw.Document();
      
      // Fontları yükle
      final font = await _loadTurkishFont(bold: false);
      final fontBold = await _loadTurkishFont(bold: true);

      final totalTasks = activities.length;
      final completedTasks = activities.where((a) => a.isCompleted).length;
      final progress = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          ),
          build: (context) => [
            // BASİT BAŞLIK (Web uyumlu, karmaşık dekorasyon yok)
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("GÜNLÜK ÇALIŞMA RAPORU", style: pw.TextStyle(fontSize: 18, font: fontBold)),
                      pw.Text("HCS Otomasyon - İş Takip", style: pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(DateFormat('dd.MM.yyyy').format(date), style: pw.TextStyle(fontSize: 10, font: fontBold)),
                      pw.Text("Hazırlayan: ${TextSanitizer.stripEmoji(userName)}", style: pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // ÖZET TABLOSU
            pw.Table(
              border: pw.TableBorder.all(color: _border, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: _mutedBg),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("TOPLAM İŞ", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("TAMAMLANAN", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("İLERLEME", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("ORT. KPI", textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8))),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("$totalTasks", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: fontBold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("$completedTasks", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: fontBold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("%${(progress * 100).toInt()}", textAlign: pw.TextAlign.center, style: pw.TextStyle(font: fontBold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(_calculateAverageKpi(activities), textAlign: pw.TextAlign.center, style: pw.TextStyle(font: fontBold))),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 25),

            pw.Text("YAPILAN İŞLER", style: pw.TextStyle(fontSize: 12, font: fontBold)),
            pw.Divider(color: _border, thickness: 0.5),
            pw.SizedBox(height: 10),

            if (activities.isEmpty)
              pw.Text("Kayıtlı iş bulunamadı.")
            else
              ...activities.map((act) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border(left: pw.BorderSide(color: _primary, width: 2)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(child: pw.Text(TextSanitizer.stripEmoji(act.title), style: pw.TextStyle(font: fontBold, fontSize: 11))),
                        pw.Row(
                          children: [
                            if (act.kpiScore != null) ...[
                              pw.Text("KPI: ${act.kpiScore}/5", style: pw.TextStyle(fontSize: 9, font: fontBold, color: PdfColors.amber)),
                              pw.SizedBox(width: 8),
                            ],
                            pw.Text(act.isCompleted ? "[TAMAMLANDI]" : "[DEVAM EDİYOR]", 
                              style: pw.TextStyle(fontSize: 8, font: fontBold, color: act.isCompleted ? PdfColors.green : PdfColors.orange)),
                          ],
                        ),
                      ],
                    ),
                    if (act.steps.isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      ...act.steps.map((s) => pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 12, top: 3),
                        child: pw.Text("- ${TextSanitizer.stripEmoji(s.title)} ${s.isCompleted ? '(Tamamlandı)' : ''}", 
                          style: pw.TextStyle(fontSize: 9, color: s.isCompleted ? PdfColors.grey700 : PdfColors.black)),
                      )),
                    ]
                  ],
                ),
              )),
          ],
        ),
      );

      return await pdf.save();
    } catch (e) {
      print('PDF Üretim Hatası: $e');
      rethrow;
    }
  }

  Future<String> generateTextReport(DateTime date, {required bool isDetailed}) async {
    // ... metin raporu kodu ...
    return "";
  }

  String _calculateAverageKpi(List<DailyActivity> activities) {
    final scoredActivities = activities.where((a) => a.kpiScore != null).toList();
    if (scoredActivities.isEmpty) return "-";
    
    final total = scoredActivities.fold<int>(0, (sum, a) => sum + a.kpiScore!);
    final avg = total / scoredActivities.length;
    return avg.toStringAsFixed(1);
  }
}
