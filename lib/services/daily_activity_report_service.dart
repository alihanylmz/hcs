import 'dart:typed_data';
import 'package:flutter/services.dart'; // rootBundle için
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/daily_activity.dart';
import '../services/daily_activity_service.dart';

class DailyActivityReportService {
  final DailyActivityService _activityService = DailyActivityService();

  // --- PDF RAPORU ---
  Future<Uint8List> generateReport({
    required List<DailyActivity> activities,
    required DateTime date,
    String userName = "Personel",
  }) async {
    final pdf = pw.Document();

    // Fontları Yükle (Türkçe karakter desteği için)
    final fontRegular = await rootBundle.load("assets/fonts/NotoSans-Regular.ttf");
    final ttfRegular = pw.Font.ttf(fontRegular);

    // İstatistikler
    final totalTasks = activities.length;
    final completedTasks = activities.where((a) => a.isCompleted).length;
    final progress = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: ttfRegular),
        build: (context) => [
          _buildHeader(date, userName),
          pw.SizedBox(height: 20),
          _buildSummary(totalTasks, completedTasks, progress),
          pw.SizedBox(height: 20),
          pw.Text("Detaylı İş Listesi", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          pw.SizedBox(height: 10),
          ...activities.map((activity) => _buildActivityRow(activity)).toList(),
          pw.SizedBox(height: 30),
          _buildFooter(),
        ],
      ),
    );

    return pdf.save();
  }

  // --- METİN RAPORU (WhatsApp/Mail) ---
  Future<String> generateTextReport(DateTime date, {required bool isDetailed}) async {
    final activities = await _activityService.getActivities(date);
    
    if (activities.isEmpty) return "⚠️ ${DateFormat('dd.MM.yyyy').format(date)} tarihinde kayıtlı çalışma yok.";

    final sb = StringBuffer();
    sb.writeln("👷‍♂️ *GÜNLÜK FAALİYET RAPORU*");
    sb.writeln("📅 Tarih: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(date)}");
    sb.writeln("👤 Personel: Otomasyon Mühendisi");
    sb.writeln("-----------------------------------");
    sb.writeln("");

    // İstatistik
    // Adım bazlı değil, Ana İş Paketi bazlı hesaplama
    int totalSteps = 0;
    int completedSteps = 0;

    for (var act in activities) {
       if (act.steps.isNotEmpty) {
         totalSteps += act.steps.length;
         completedSteps += act.steps.where((s) => s.isCompleted).length;
       } else {
         totalSteps++;
         if (act.isCompleted) completedSteps++;
       }
    }
    double totalProgress = totalSteps > 0 ? (completedSteps / totalSteps) : 0.0;
    
    sb.writeln("📊 *GENEL İLERLEME:* %${(totalProgress * 100).toInt()}\n");

    for (var i = 0; i < activities.length; i++) {
      final act = activities[i];
      final statusIcon = act.isCompleted ? "✅" : (act.progress > 0 ? "⏳" : "🔴");
      
      // Ana Başlık
      sb.writeln("$statusIcon *${act.title}*");
      sb.writeln("   Durum: %${(act.progress * 100).toInt()} Tamamlandı");

      // Detaylı Mod ise Alt Adımları Dök
      if (isDetailed && act.steps.isNotEmpty) {
        for (var step in act.steps) {
          final stepIcon = step.isCompleted ? "☑️" : "⬜";
          sb.writeln("   $stepIcon ${step.title}");
        }
      }
      sb.writeln(""); // Boşluk
    }

    sb.writeln("-----------------------------------");
    sb.writeln("🚀 *HCS Otomasyon Sistemleri*");

    return sb.toString();
  }

  // ... (PDF Helper Metodları aynı kalıyor) ...
  
  pw.Widget _buildHeader(DateTime date, String userName) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("HCS OTOMASYON", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.Text("Günlük Faaliyet Raporu", style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(DateFormat('d MMMM yyyy', 'tr_TR').format(date), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text("Hazırlayan: $userName"),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSummary(int total, int completed, double progress) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Toplam İş Paketi", "$total"),
          _buildStatItem("Tamamlanan", "$completed", color: PdfColors.green700),
          _buildStatItem("Genel İlerleme", "%${(progress * 100).toInt()}", color: PdfColors.blue700),
        ],
      ),
    );
  }

  pw.Widget _buildStatItem(String label, String value, {PdfColor color = PdfColors.black}) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: color)),
        pw.Text(label, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
      ],
    );
  }

  pw.Widget _buildActivityRow(DailyActivity activity) {
    final isDone = activity.isCompleted;
    final statusColor = isDone ? PdfColors.green700 : PdfColors.blue700;
    final statusIcon = isDone ? "TAMAMLANDI" : "DEVAM EDİYOR (%${(activity.progress * 100).toInt()})";

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  activity.title,
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: isDone ? PdfColors.green50 : PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  statusIcon,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          if (activity.steps.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: activity.steps.map((step) {
                  return pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(step.isCompleted ? "[x] " : "[ ] ", style: const pw.TextStyle(fontSize: 10)),
                      pw.Expanded(
                        child: pw.Text(
                          step.title,
                          style: pw.TextStyle(
                            fontSize: 10,
                            color: step.isCompleted ? PdfColors.grey600 : PdfColors.black,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ]
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Text("Bu rapor otomatik olarak HCS Otomasyon İş Takip Sistemi tarafından oluşturulmuştur.", 
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
      ],
    );
  }
}
