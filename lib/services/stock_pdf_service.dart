import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../utils/pdf_helper.dart';

class StockPdfService {
  static Future<Uint8List> generateStockReportPdfBytes() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('inventory').select().order('category', ascending: true).order('name', ascending: true);
      final List<Map<String, dynamic>> stocks = List<Map<String, dynamic>>.from(response);

      final pdf = pw.Document();
      final font = await PdfHelper.loadTurkishFont();

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var s in stocks) {
        final cat = s['category'] ?? 'Diğer';
        if (!grouped.containsKey(cat)) grouped[cat] = [];
        grouped[cat]!.add(s);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: font),
          header: (context) => pw.Header(level: 0, child: pw.Text("GÜNCEL STOK RAPORU", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          build: (context) {
            return grouped.entries.map((entry) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 10),
                  pw.Container(
                    width: double.infinity,
                    color: PdfColors.grey200,
                    padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                    child: pw.Text(entry.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  ),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    children: [
                      pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey100), children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Ürün Adı', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Adet', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Raf', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ]),
                      ...entry.value.map((item) {
                        final qty = item['quantity'] as int? ?? 0;
                        final critical = item['critical_level'] as int? ?? 0;
                        final isLow = qty <= critical;
                        return pw.TableRow(children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['name'] ?? '-')),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(qty.toString(), style: pw.TextStyle(color: isLow ? PdfColors.red : PdfColors.black, fontWeight: isLow ? pw.FontWeight.bold : null))),
                          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['shelf_location'] ?? '-')),
                        ]);
                      }).toList(),
                    ],
                  ),
                ],
              );
            }).toList();
          },
        ),
      );
      return await pdf.save();
    } catch (e) {
      throw Exception('Stok raporu hatası: $e');
    }
  }

  static Future<Uint8List> generateAnnualUsageReportPdfBytes() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('tickets')
          .select('planned_date, plc_model, aspirator_brand, aspirator_kw, vant_brand, vant_kw, hmi_brand, hmi_size')
          .or('status.eq.done,is_archived.eq.true');
          
      final List tickets = response as List;
      final Map<String, Map<String, Map<String, int>>> yearlyStats = {};

      for (var t in tickets) {
        final dateStr = t['planned_date'] as String?;
        if (dateStr == null) continue;
        final year = DateTime.parse(dateStr).year.toString();

        if (!yearlyStats.containsKey(year)) yearlyStats[year] = {};
        
        void addItem(String category, String name) {
          if (!yearlyStats[year]!.containsKey(category)) yearlyStats[year]![category] = {};
          final current = yearlyStats[year]![category]![name] ?? 0;
          yearlyStats[year]![category]![name] = current + 1;
        }

        if (t['plc_model'] != null && t['plc_model'].toString().isNotEmpty) {
          addItem('PLC', '${t['plc_model']} PLC');
        }
        if (t['aspirator_brand'] != null && t['aspirator_kw'] != null) {
           addItem('Sürücü', '${t['aspirator_brand']} ${t['aspirator_kw']} kW');
        }
        if (t['vant_brand'] != null && t['vant_kw'] != null) {
           addItem('Sürücü', '${t['vant_brand']} ${t['vant_kw']} kW');
        }
        if (t['hmi_brand'] != null && t['hmi_size'] != null) {
           addItem('HMI', '${t['hmi_brand']} ${t['hmi_size']} inç');
        }
      }

      final pdf = pw.Document();
      final font = await PdfHelper.loadTurkishFont();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: font),
          header: (context) => pw.Header(level: 0, child: pw.Text("YILLIK KULLANIM RAPORU", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          build: (context) {
            final sortedYears = yearlyStats.keys.toList()..sort((a, b) => b.compareTo(a));
            if (sortedYears.isEmpty) {
              return [pw.Text('Henüz veri bulunmamaktadır.')];
            }

            return sortedYears.map((year) {
              final categories = yearlyStats[year]!;
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 20),
                  pw.Text('YIL: $year', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Divider(),
                  ...categories.entries.map((catEntry) {
                     return pw.Column(
                       crossAxisAlignment: pw.CrossAxisAlignment.start,
                       children: [
                         pw.Padding(
                           padding: const pw.EdgeInsets.symmetric(vertical: 5),
                           child: pw.Text(catEntry.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, decoration: pw.TextDecoration.underline)),
                         ),
                         pw.Table(
                           border: pw.TableBorder.all(color: PdfColors.grey300),
                           columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)},
                           children: catEntry.value.entries.map((item) {
                             return pw.TableRow(children: [
                               pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.key)),
                               pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.value.toString(), textAlign: pw.TextAlign.right)),
                             ]);
                           }).toList(),
                         ),
                       ],
                     );
                  }).toList(),
                ],
              );
            }).toList();
          },
        ),
      );
      return await pdf.save();
    } catch (e) {
      throw Exception('Yıllık rapor hatası: $e');
    }
  }

  static Future<Uint8List> generateOrderListPdfBytes() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('inventory')
          .select()
          .order('category', ascending: true)
          .order('name', ascending: true);
      
      final List<Map<String, dynamic>> allStocks = List<Map<String, dynamic>>.from(response);
      final List<Map<String, dynamic>> orderItems = allStocks.where((stock) {
        final qty = stock['quantity'] as int? ?? 0;
        final critical = stock['critical_level'] as int? ?? 5;
        return qty <= critical;
      }).toList();

      final pdf = pw.Document();
      final font = await PdfHelper.loadTurkishFont();
      final dateStr = DateFormat('dd.MM.yyyy', 'tr_TR').format(DateTime.now());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          theme: pw.ThemeData.withFont(base: font, bold: font),
          header: (context) {
            return pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('SİPARİŞ LİSTESİ', style: pw.TextStyle(font: font, fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfHelper.primaryColor)),
                        pw.SizedBox(height: 4),
                        pw.Text('Tarih: $dateStr', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(color: PdfColors.red50, borderRadius: pw.BorderRadius.circular(4), border: pw.Border.all(color: PdfColors.red300)),
                      child: pw.Text('${orderItems.length} Ürün', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.red700)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(color: PdfHelper.primaryColor, thickness: 2),
              ],
            );
          },
          build: (context) {
            if (orderItems.isEmpty) {
              return [
                pw.SizedBox(height: 50),
                pw.Center(child: pw.Text('Tüm stoklar yeterli seviyede!', style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.green700, fontWeight: pw.FontWeight.bold))),
              ];
            }

            final Map<String, List<Map<String, dynamic>>> grouped = {};
            for (var item in orderItems) {
              final cat = item['category'] as String? ?? 'Diğer';
              if (!grouped.containsKey(cat)) grouped[cat] = [];
              grouped[cat]!.add(item);
            }

            return grouped.entries.map((entry) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 15),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: pw.BoxDecoration(color: PdfHelper.primaryColor, borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Text(entry.key.toUpperCase(), style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfHelper.lightBgColor),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Ürün Adı', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 10))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Mevcut', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 10))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Kritik', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        ],
                      ),
                      ...entry.value.map((item) {
                        return pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(PdfHelper.safeText(item['name']), style: pw.TextStyle(font: font, fontSize: 9))),
                            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item['quantity'].toString(), style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
                            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item['critical_level'].toString(), style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ],
              );
            }).toList();
          },
        ),
      );
      return await pdf.save();
    } catch (e) {
      throw Exception('Sipariş listesi hatası: $e');
    }
  }

  static Future<Uint8List> generateOrderListPdfBytesFromList(List<Map<String, dynamic>> items) async {
    try {
      final pdf = pw.Document();
      final font = await PdfHelper.loadTurkishFont();
      final dateStr = DateFormat('dd.MM.yyyy', 'tr_TR').format(DateTime.now());

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          theme: pw.ThemeData.withFont(base: font, bold: font),
          header: (context) {
            return pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('SİPARİŞ LİSTESİ', style: pw.TextStyle(font: font, fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfHelper.primaryColor)),
                        pw.SizedBox(height: 4),
                        pw.Text('Tarih: $dateStr', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(color: PdfColors.red50, borderRadius: pw.BorderRadius.circular(4), border: pw.Border.all(color: PdfColors.red300)),
                      child: pw.Text('${items.length} Ürün', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.red700)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(color: PdfHelper.primaryColor, thickness: 2),
              ],
            );
          },
          build: (context) {
            if (items.isEmpty) {
              return [
                pw.SizedBox(height: 50),
                pw.Center(child: pw.Text('Liste boş.', style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold))),
              ];
            }

            final Map<String, List<Map<String, dynamic>>> grouped = {};
            for (var item in items) {
              final cat = item['category'] as String? ?? 'Diğer';
              if (!grouped.containsKey(cat)) grouped[cat] = [];
              grouped[cat]!.add(item);
            }

            return grouped.entries.map((entry) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 15),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: pw.BoxDecoration(color: PdfHelper.primaryColor, borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Text(entry.key.toUpperCase(), style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(3),
                      1: pw.FlexColumnWidth(1),
                      2: pw.FlexColumnWidth(1),
                    },
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfHelper.lightBgColor),
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Ürün Adı', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 10))),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Adet', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center)),
                          pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Birim', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 10), textAlign: pw.TextAlign.center)),
                        ],
                      ),
                      ...entry.value.map((item) {
                        return pw.TableRow(
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(PdfHelper.safeText(item['name']), style: pw.TextStyle(font: font, fontSize: 9))),
                            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text((item['order_quantity'] ?? 1).toString(), style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
                            pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item['unit'] ?? 'adet', style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ],
              );
            }).toList();
          },
        ),
      );
      return await pdf.save();
    } catch (e) {
      throw Exception('Sipariş listesi hatası: $e');
    }
  }
}
