import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../utils/pdf_helper.dart';

class StockPdfService {
  static Future<List<Map<String, dynamic>>> _fetchProductStocks() async {
    final supabase = Supabase.instance.client;
    const pageSize = 500;
    final stocks = <Map<String, dynamic>>[];
    var offset = 0;

    while (true) {
      final response = await supabase
          .from('products')
          .select('id, code, name, brand, model, unit, stock_quantity, minimum_stock, stock_tracking_started, specifications')
          .order('name', ascending: true)
          .range(offset, offset + pageSize - 1);
      final page = List<Map<String, dynamic>>.from(response);
      for (final product in page) {
        final specifications = Map<String, dynamic>.from(
          product['specifications'] as Map? ?? const <String, dynamic>{},
        );
        stocks.add({
          ...product,
          'quantity': (product['stock_quantity'] as num?)?.toInt() ?? 0,
          'critical_level': (product['minimum_stock'] as num?)?.toInt() ?? 0,
          'stock_tracking_started':
              product['stock_tracking_started'] == true ||
              ((product['stock_quantity'] as num?) ?? 0) > 0,
          'shelf_location': specifications['shelf_location'],
        });
      }
      if (page.length < pageSize) break;
      offset += pageSize;
    }

    return stocks;
  }

  static Future<Uint8List> generateStockReportPdfBytes() async {
    try {
      final stocks = await _fetchProductStocks();

      final pdf = pw.Document();
      final font = await PdfHelper.loadTurkishFont();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: font),
          header: (context) => pw.Header(level: 0, child: pw.Text("GÜNCEL STOK RAPORU", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          build: (context) {
            return [
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                children: [
                  pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey100), children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Ürün Adı', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Adet', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Raf', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ]),
                  ...stocks.map((item) {
                    final qty = item['quantity'] as int? ?? 0;
                    final critical = item['critical_level'] as int? ?? 0;
                    final isLow =
                        item['stock_tracking_started'] == true &&
                        qty <= critical;
                    return pw.TableRow(children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['name'] ?? '-')),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(qty.toString(), style: pw.TextStyle(color: isLow ? PdfColors.red : PdfColors.black, fontWeight: isLow ? pw.FontWeight.bold : null))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['shelf_location'] ?? '-')),
                    ]);
                  }),
                ],
              ),
            ];
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
      final allStocks = await _fetchProductStocks();
      final List<Map<String, dynamic>> orderItems = allStocks.where((stock) {
        if (stock['stock_tracking_started'] != true) return false;
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

            return [
              pw.SizedBox(height: 15),
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
                  ...orderItems.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(PdfHelper.safeText(item['name']), style: pw.TextStyle(font: font, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item['quantity'].toString(), style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item['critical_level'].toString(), style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
                    ],
                  )),
                ],
              ),
            ];
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

            return [
              pw.SizedBox(height: 15),
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
                  ...items.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(PdfHelper.safeText(item['name']), style: pw.TextStyle(font: font, fontSize: 9))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text((item['order_quantity'] ?? 1).toString(), style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(item['unit'] ?? 'adet', style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
                    ],
                  )),
                ],
              ),
            ];
          },
        ),
      );
      return await pdf.save();
    } catch (e) {
      throw Exception('Sipariş listesi hatası: $e');
    }
  }

  // --- DİNAMİK DEPO STOK PDF RAPORU ---
  static Future<Uint8List> generateWarehouseStockPdfBytesFromList(List<Map<String, dynamic>> stocks, {String title = 'DEPO FİZİKSEL STOK RAPORU'}) async {
    final pdf = pw.Document();
    final font = await PdfHelper.loadTurkishFont();
    final dateStr = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(DateTime.now());

    int totalQty = 0;
    int criticalCount = 0;

    for (final s in stocks) {
      final qty = (s['quantity'] as num?)?.toInt() ?? 0;
      final min = (s['critical_level'] as num?)?.toInt() ?? 0;
      totalQty += qty;
      if (qty <= min) criticalCount++;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfHelper.primaryColor)),
                pw.Text('Rapor Tarihi: $dateStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                pw.Text('Toplam Çeşit: ${stocks.length} Kalem  |  ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900)),
                pw.Text('Toplam Miktar: $totalQty Adet  |  ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text('Kritik Seviyedeki Stok: $criticalCount Ürün', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: criticalCount > 0 ? PdfColors.red700 : PdfColors.green700)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfHelper.primaryColor, thickness: 1.5),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (context) => [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.2),
              1: pw.FlexColumnWidth(2.5),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1.5),
              4: pw.FlexColumnWidth(0.9),
              5: pw.FlexColumnWidth(0.8),
              6: pw.FlexColumnWidth(0.9),
              7: pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfHelper.lightBgColor),
                children: [
                  _pdfHeaderCell('Ürün Kodu', font),
                  _pdfHeaderCell('Ürün Adı / Açıklama', font),
                  _pdfHeaderCell('Kategori', font),
                  _pdfHeaderCell('Marka / Model', font),
                  _pdfHeaderCell('Mevcut Stok', font, align: pw.TextAlign.center),
                  _pdfHeaderCell('Min. Stok', font, align: pw.TextAlign.center),
                  _pdfHeaderCell('Raf / Kasa', font),
                  _pdfHeaderCell('Barkod / Seri No', font),
                ],
              ),
              ...stocks.map((item) {
                final qty = (item['quantity'] as num?)?.toInt() ?? 0;
                final min = (item['critical_level'] as num?)?.toInt() ?? 0;
                final isLow = qty <= min;

                return pw.TableRow(
                  children: [
                    _pdfCell(PdfHelper.safeText(item['code']), font, isBold: true),
                    _pdfCell(PdfHelper.safeText(item['displayName'] ?? item['name']), font, isBold: true),
                    _pdfCell(PdfHelper.safeText(item['category']), font),
                    _pdfCell(PdfHelper.safeText('${item['brand'] ?? ''} ${item['model'] ?? ''}'.trim()), font),
                    _pdfCell('$qty ${item['unit'] ?? 'Adet'}', font, align: pw.TextAlign.center, isBold: isLow, textColor: isLow ? PdfColors.red700 : PdfColors.black),
                    _pdfCell('$min ${item['unit'] ?? 'Adet'}', font, align: pw.TextAlign.center),
                    _pdfCell(PdfHelper.safeText(item['shelf_location']), font),
                    _pdfCell(PdfHelper.safeText(item['barcode'] ?? item['specifications']?['serial_number']), font),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
    return await pdf.save();
  }

  // --- PERSONEL ZİMMETLERİ PDF RAPORU ---
  static Future<Uint8List> generatePersonnelLoansPdfBytes(List<Map<String, dynamic>> loans) async {
    final pdf = pw.Document();
    final font = await PdfHelper.loadTurkishFont();
    final dateStr = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(DateTime.now());

    int totalQty = 0;
    final Set<String> personnelSet = {};

    for (final l in loans) {
      totalQty += (l['quantity'] as num?)?.toInt() ?? 0;
      personnelSet.add((l['personnel_name'] ?? '').toString());
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('PERSONEL ZİMMET DÖKÜM VE EKSTRE RAPORU', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfHelper.primaryColor)),
                pw.Text('Rapor Tarihi: $dateStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                pw.Text('Zimmetli Personel Sayısı: ${personnelSet.length} Kişi  |  ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900)),
                pw.Text('Zimmetli Ürün Kalemi: ${loans.length} Çeşit  |  ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900)),
                pw.Text('Toplam Zimmetli Malzeme: $totalQty Adet', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfHelper.primaryColor, thickness: 1.5),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (context) => [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.8),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(2.2),
              3: pw.FlexColumnWidth(1.0),
              4: pw.FlexColumnWidth(1.2),
              5: pw.FlexColumnWidth(2.6),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfHelper.lightBgColor),
                children: [
                  _pdfHeaderCell('Teknik Personel', font),
                  _pdfHeaderCell('Ürün Kodu', font),
                  _pdfHeaderCell('Ürün Adı', font),
                  _pdfHeaderCell('Miktar', font, align: pw.TextAlign.center),
                  _pdfHeaderCell('Veriliş Tarihi', font),
                  _pdfHeaderCell('İş Kodu / Zimmet Notu', font),
                ],
              ),
              ...loans.map((l) {
                final product = l['inventory'] ?? {};
                final qty = (l['quantity'] as num?)?.toInt() ?? 0;
                final unit = product['unit'] ?? 'Adet';
                final borrowedAt = l['borrowed_at'] != null ? DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(DateTime.parse(l['borrowed_at'].toString()).toLocal()) : '-';

                return pw.TableRow(
                  children: [
                    _pdfCell(PdfHelper.safeText(l['personnel_name']), font, isBold: true),
                    _pdfCell(PdfHelper.safeText(product['code']), font),
                    _pdfCell(PdfHelper.safeText(product['displayName'] ?? product['name']), font),
                    _pdfCell('$qty $unit', font, align: pw.TextAlign.center, isBold: true),
                    _pdfCell(borrowedAt, font),
                    _pdfCell(PdfHelper.safeText(l['note']), font),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
    return await pdf.save();
  }

  // --- ARIZALI ÜRÜNLER (RMA) PDF RAPORU ---
  static Future<Uint8List> generateDefectiveProductsPdfBytes(List<Map<String, dynamic>> defectiveProducts) async {
    final pdf = pw.Document();
    final font = await PdfHelper.loadTurkishFont();
    final dateStr = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(DateTime.now());

    int totalQty = 0;
    for (final d in defectiveProducts) {
      totalQty += (d['quantity'] as num?)?.toInt() ?? 0;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('ARIZALI ÜRÜN VE GARANTİ / RMA TAKİP RAPORU', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                pw.Text('Rapor Tarihi: $dateStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                pw.Text('Arızalı Kayıt Sayısı: ${defectiveProducts.length} Adet Kayıt  |  ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900)),
                pw.Text('Toplam Arızalı Miktar: $totalQty Adet Malzeme', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfColors.red900, thickness: 1.5),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (context) => [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.1),
              1: pw.FlexColumnWidth(2.2),
              2: pw.FlexColumnWidth(0.8),
              3: pw.FlexColumnWidth(1.4),
              4: pw.FlexColumnWidth(1.1),
              5: pw.FlexColumnWidth(2.0),
              6: pw.FlexColumnWidth(1.4),
              7: pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfHelper.lightBgColor),
                children: [
                  _pdfHeaderCell('Tarih', font),
                  _pdfHeaderCell('Ürün Adı / Kod', font),
                  _pdfHeaderCell('Miktar', font, align: pw.TextAlign.center),
                  _pdfHeaderCell('Bildiren Personel', font),
                  _pdfHeaderCell('İş Kodu', font),
                  _pdfHeaderCell('Arıza Açıklaması', font),
                  _pdfHeaderCell('Süreç Durumu', font),
                  _pdfHeaderCell('Tedarikçi / Kargo Takip', font),
                ],
              ),
              ...defectiveProducts.map((d) {
                final product = d['inventory'] ?? {};
                final qty = (d['quantity'] as num?)?.toInt() ?? 0;
                final unit = product['unit'] ?? 'Adet';
                final createdAt = d['created_at'] != null ? DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(DateTime.parse(d['created_at'].toString()).toLocal()) : '-';
                final statusLabel = _getDefectiveStatusPdfLabel(d['status']);
                final tracking = (d['tracking_number'] ?? '').toString();
                final supplier = (d['supplier_name'] ?? '').toString();

                return pw.TableRow(
                  children: [
                    _pdfCell(createdAt, font),
                    _pdfCell(PdfHelper.safeText('${product['displayName'] ?? product['name']} (${product['code'] ?? ''})'), font, isBold: true),
                    _pdfCell('$qty $unit', font, align: pw.TextAlign.center, isBold: true, textColor: PdfColors.red800),
                    _pdfCell(PdfHelper.safeText(d['reported_by_name']), font),
                    _pdfCell(PdfHelper.safeText(d['job_code']), font),
                    _pdfCell(PdfHelper.safeText(d['fault_description']), font),
                    _pdfCell(statusLabel, font, isBold: true),
                    _pdfCell([if (supplier.isNotEmpty) 'Firma: $supplier', if (tracking.isNotEmpty) 'Kargo: $tracking'].join('\n').ifEmpty('-'), font),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
    return await pdf.save();
  }

  // --- STOK HAREKET LOGLARI PDF RAPORU ---
  static Future<Uint8List> generateStockMovementsPdfBytes(List<Map<String, dynamic>> movements) async {
    final pdf = pw.Document();
    final font = await PdfHelper.loadTurkishFont();
    final dateStr = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: font, bold: font),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('STOK HAREKET LOGLARI VE DENETİM RAPORU', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfHelper.primaryColor)),
                pw.Text('Rapor Tarihi: $dateStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Text('Toplam Hareket Kaydı: ${movements.length} İşlem', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900)),
            pw.SizedBox(height: 8),
            pw.Divider(color: PdfHelper.primaryColor, thickness: 1.5),
            pw.SizedBox(height: 4),
          ],
        ),
        build: (context) => [
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
            columnWidths: const {
              0: pw.FlexColumnWidth(1.2),
              1: pw.FlexColumnWidth(2.2),
              2: pw.FlexColumnWidth(1.1),
              3: pw.FlexColumnWidth(0.8),
              4: pw.FlexColumnWidth(1.1),
              5: pw.FlexColumnWidth(2.0),
              6: pw.FlexColumnWidth(1.6),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfHelper.lightBgColor),
                children: [
                  _pdfHeaderCell('Tarih', font),
                  _pdfHeaderCell('Ürün Adı', font),
                  _pdfHeaderCell('İşlem Tipi', font),
                  _pdfHeaderCell('Miktar', font, align: pw.TextAlign.center),
                  _pdfHeaderCell('Önce / Sonra', font, align: pw.TextAlign.center),
                  _pdfHeaderCell('Sebep / Hedef', font),
                  _pdfHeaderCell('Açıklama / Not', font),
                ],
              ),
              ...movements.map((m) {
                final product = m['inventory'] ?? {};
                final isIn = m['movement_type'] == 'in';
                final createdAt = m['created_at'] != null ? DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(DateTime.parse(m['created_at'].toString()).toLocal()) : '-';

                return pw.TableRow(
                  children: [
                    _pdfCell(createdAt, font),
                    _pdfCell(PdfHelper.safeText(product['displayName'] ?? product['name']), font, isBold: true),
                    _pdfCell(isIn ? 'GİRİŞ (IN)' : 'ÇIKIŞ (OUT)', font, isBold: true, textColor: isIn ? PdfColors.green800 : PdfColors.orange900),
                    _pdfCell('${m['quantity']}', font, align: pw.TextAlign.center, isBold: true),
                    _pdfCell('${m['quantity_before']} -> ${m['quantity_after']}', font, align: pw.TextAlign.center),
                    _pdfCell(PdfHelper.safeText('${m['reason'] ?? ''} ${m['destination'] ?? ''}'.trim()), font),
                    _pdfCell(PdfHelper.safeText(m['note']), font),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
    return await pdf.save();
  }

  static pw.Widget _pdfHeaderCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.black), textAlign: align),
    );
  }

  static pw.Widget _pdfCell(String text, pw.Font font, {pw.TextAlign align = pw.TextAlign.left, bool isBold = false, PdfColor textColor = PdfColors.black}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 8.5, fontWeight: isBold ? pw.FontWeight.bold : null, color: textColor), textAlign: align),
    );
  }

  static String _getDefectiveStatusPdfLabel(dynamic status) {
    switch (status?.toString()) {
      case 'in_faulty_stock':
        return 'Arızalı Depoda (Bekliyor)';
      case 'shipped_to_supplier':
        return 'Tedarikçiye Kargolandı';
      case 'repaired_returned':
        return 'Tamir Edildi (Stoğa Eklendi)';
      case 'replaced':
        return 'Yenisi Geldi (Stoğa Eklendi)';
      case 'scrapped':
        return 'Hurdaya Ayrıldı (Çöp)';
      default:
        return status?.toString() ?? '-';
    }
  }
}

extension _StringEmptyPdfExt on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

