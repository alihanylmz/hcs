import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import '../services/stock_service.dart';

class PdfExportService {
  // --- AYARLAR VE SABİTLER ---

  static const Map<String, String> _statusLabels = {
    'open': 'Açık',
    'in_progress': 'Serviste',
    'done': 'Tamamlandı',
    'archived': 'Arşivde',
  };

  static const Map<String, String> _priorityLabels = {
    'low': 'Düşük',
    'normal': 'Normal',
    'high': 'Yüksek',
  };

  static const PdfColor _primaryColor = PdfColors.blueGrey900;
  static const PdfColor _accentColor = PdfColors.teal700;
  static const PdfColor _lightBgColor = PdfColors.grey100;

  // --- YARDIMCI METODLAR ---

  static Future<pw.Font> _loadTurkishFont() async {
    try {
      return await PdfGoogleFonts.notoSansRegular();
    } catch (e) {
      print('Google Fonts yüklenemedi, yerel dosya deneniyor: $e');
      try {
        final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
        return pw.Font.ttf(fontData);
      } catch (e2) {
        print('Yerel font da bulunamadı: $e2');
        return pw.Font.helvetica();
      }
    }
  }

  static pw.ImageProvider? _decodeSignatureImage(String? base64Data) {
    if (base64Data == null || base64Data.isEmpty) return null;
    try {
      final bytes = base64Decode(base64Data);
      return pw.MemoryImage(bytes);
    } catch (e) {
      print('İmza decode hatası: $e');
      return null;
    }
  }

  static String _formatDate(String? iso) {
    if (iso == null) return '-';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return '${parsed.day.toString().padLeft(2, '0')}.'
        '${parsed.month.toString().padLeft(2, '0')}.'
        '${parsed.year} ${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
  }

  static String _safeText(dynamic value) {
    if (value == null) return '-';
    if (value is String && value.trim().isEmpty) return '-';
    return value.toString();
  }

  // --- TASARIM WIDGET'LARI ---

  static pw.Widget _buildSectionHeader(String title, pw.Font font) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10, top: 15),
      padding: const pw.EdgeInsets.only(bottom: 5),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _accentColor, width: 2)),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              font: font,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _primaryColor,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value, pw.Font font, {bool isFullWidth = false}) {
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

  // --- PDF GENERATION & ACTIONS ---

  /// Verileri çeker ve PDF baytlarını oluşturur
  static Future<Uint8List> generateSingleTicketPdfBytes(String ticketId) async {
    try {
      final supabase = Supabase.instance.client;
      final idValue = int.tryParse(ticketId) ?? ticketId;

      final ticket = await supabase
          .from('tickets')
          .select('''
            *,
            customers (
              id,
              name,
              address,
              phone
            )
          ''')
          .eq('id', idValue)
          .maybeSingle();

      if (ticket == null) {
        throw Exception('İş bulunamadı.');
      }

      final notesResponse = await supabase
          .from('ticket_notes')
          .select('*, profiles(full_name)')
          .eq('ticket_id', idValue)
          .order('created_at', ascending: true);
      
      final notes = List<Map<String, dynamic>>.from(notesResponse);

      final pdf = await _generateSingleTicketPdf(ticket, notes);
      return await pdf.save();
    } catch (e) {
      throw Exception('PDF oluşturma hatası: $e');
    }
  }

  /// PDF'i ekranda önizler (Yazdırma diyaloğu)
  static Future<void> viewPdf(Uint8List bytes, String fileName) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: fileName,
    );
  }

  /// PDF'i dosya olarak kaydeder (İndirir)
  static Future<String?> savePdf(Uint8List bytes, String fileName) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await Printing.sharePdf(bytes: bytes, filename: '$fileName.pdf');
        return 'Dosya paylaşım menüsü açıldı';
      } else {
        // Masaüstü: FilePicker ile kaydet
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
        return null; // Kullanıcı iptal etti
      }
    } catch (e) {
      throw Exception('PDF kaydetme hatası: $e');
    }
  }

  // Eski metodu geriye uyumluluk veya kolaylık için tutabiliriz ama ismini değiştirebiliriz.
  // Şimdilik viewSingleTicketPdf olarak kullanalım veya direk UI'dan çağıralım.
  
  // --- 1. TEKİL İŞ EMRİ PDF ÇIKTISI ---
  
  // Deprecated or wrapper
  static Future<void> exportSingleTicketToPdf(String ticketId) async {
     final bytes = await generateSingleTicketPdfBytes(ticketId);
     await viewPdf(bytes, 'Servis_Formu_$ticketId');
  }


  static Future<pw.Document> _generateSingleTicketPdf(Map<String, dynamic> ticket, List<Map<String, dynamic>> notes) async {
    final pdf = pw.Document();
    final turkishFont = await _loadTurkishFont();

    final customer = ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final status = ticket['status'] as String? ?? 'open';
    final companyName = "TEKNİK SERVİS HİZMETLERİ"; 

    // Teknik Veriler (HMI eklendi)
    final aspKw = ticket['aspirator_kw'];
    final vantKw = ticket['vant_kw'];
    final komp1Kw = ticket['kompresor_kw_1'];
    final komp2Kw = ticket['kompresor_kw_2'];
    final hmiBrand = ticket['hmi_brand'];
    final hmiSize = ticket['hmi_size'];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        theme: pw.ThemeData.withFont(base: turkishFont, bold: turkishFont),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(companyName, style: pw.TextStyle(font: turkishFont, fontSize: 18, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
                    pw.Text('Servis Formu ve İş Emri Belgesi', style: pw.TextStyle(font: turkishFont, fontSize: 10, color: _accentColor)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: pw.BoxDecoration(color: _lightBgColor, borderRadius: pw.BorderRadius.circular(4), border: pw.Border.all(color: PdfColors.grey300)),
                      child: pw.Text('İŞ NO: ${_safeText(ticket['job_code'])}', style: pw.TextStyle(font: turkishFont, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Tarih: ${_formatDate(DateTime.now().toIso8601String())}', style: pw.TextStyle(font: turkishFont, fontSize: 9, color: PdfColors.grey600)),
                  ]),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: _primaryColor, thickness: 2),
            ],
          );
        },
        footer: (pw.Context context) {
           return pw.Column(
             children: [
               _buildSignatureSection(ticket, turkishFont),
               pw.SizedBox(height: 10),
               pw.Center(child: pw.Text('Bu belge dijital olarak oluşturulmuştur.', style: pw.TextStyle(font: turkishFont, fontSize: 8, color: PdfColors.grey500))),
             ],
           );
        },
        build: (pw.Context context) => [
          // Müşteri ve Servis Bilgileri
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(flex: 5, child: pw.Column(children: [
                _buildSectionHeader('Müşteri Bilgileri', turkishFont),
                pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(color: _lightBgColor, borderRadius: pw.BorderRadius.circular(5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  _buildInfoRow('Ünvan', _safeText(customer['name']), turkishFont, isFullWidth: true),
                  pw.SizedBox(height: 5),
                  _buildInfoRow('Telefon', _safeText(customer['phone']), turkishFont),
                  pw.Divider(height: 10),
                  _buildInfoRow('Adres', _safeText(customer['address']), turkishFont, isFullWidth: true),
                ])),
              ])),
              pw.SizedBox(width: 20),
              pw.Expanded(flex: 4, child: pw.Column(children: [
                _buildSectionHeader('Servis Detayları', turkishFont),
                pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  _buildInfoRow('Cihaz', _safeText(ticket['device_model']), turkishFont),
                  pw.Divider(),
                  pw.Row(children: [
                    pw.Expanded(child: _buildInfoRow('Tarih', _formatDate(ticket['planned_date'] as String?), turkishFont)),
                    pw.Expanded(child: _buildInfoRow('Durum', _statusLabels[status] ?? status, turkishFont)),
                  ]),
                ])),
              ])),
            ],
          ),
          _buildSectionHeader('İş Açıklaması', turkishFont),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(5)),
            child: pw.Text(_safeText(ticket['description']), style: pw.TextStyle(font: turkishFont, fontSize: 10)),
          ),
          // Teknik Bilgiler Tablosu
          if (aspKw != null || vantKw != null || komp1Kw != null || hmiBrand != null) ...[
            _buildSectionHeader('Teknik Bilgiler', turkishFont),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(decoration: const pw.BoxDecoration(color: _lightBgColor), children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Bileşen', style: pw.TextStyle(font: turkishFont, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Detay', style: pw.TextStyle(font: turkishFont, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                ]),
                if (aspKw != null) pw.TableRow(children: [
                   pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Aspiratör', style: pw.TextStyle(font: turkishFont, fontSize: 9))),
                   pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${_safeText(aspKw)} kW', style: pw.TextStyle(font: turkishFont, fontSize: 9))),
                ]),
                if (vantKw != null) pw.TableRow(children: [
                   pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Vantilatör', style: pw.TextStyle(font: turkishFont, fontSize: 9))),
                   pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${_safeText(vantKw)} kW', style: pw.TextStyle(font: turkishFont, fontSize: 9))),
                ]),
                if (komp1Kw != null) pw.TableRow(children: [
                   pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Kompresör 1', style: pw.TextStyle(font: turkishFont, fontSize: 9))),
                   pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${_safeText(komp1Kw)} kW', style: pw.TextStyle(font: turkishFont, fontSize: 9))),
                ]),
                if (hmiBrand != null) pw.TableRow(children: [
                   pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('HMI Ekran', style: pw.TextStyle(font: turkishFont, fontSize: 9))),
                   pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${_safeText(hmiBrand)} - ${_safeText(hmiSize)} inç', style: pw.TextStyle(font: turkishFont, fontSize: 9))),
                ]),
              ],
            ),
          ],

          // --- TEKNİSYEN NOTLARI (Sadece Metin) ---
          if (notes.isNotEmpty) ...[
            _buildSectionHeader('Teknisyen Notları', turkishFont),
            pw.Column(
              children: notes.map((note) {
                final date = _formatDate(note['created_at']);
                final author = note['profiles']?['full_name'] ?? 'Teknisyen';
                final text = _safeText(note['note']);
                
                return pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(author, style: pw.TextStyle(font: turkishFont, fontWeight: pw.FontWeight.bold, fontSize: 9, color: _accentColor)),
                          pw.Text(date, style: pw.TextStyle(font: turkishFont, fontSize: 8, color: PdfColors.grey600)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(text, style: pw.TextStyle(font: turkishFont, fontSize: 10)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
    return pdf;
  }

  static pw.Widget _buildSignatureSection(Map<String, dynamic> ticket, pw.Font font) {
    final customerSignData = ticket['signature_data'] as String?;
    final techSignData = ticket['technician_signature_data'] as String?;

    final customerImage = _decodeSignatureImage(customerSignData);
    final techImage = _decodeSignatureImage(techSignData);

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400))),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(children: [
            pw.Text('MÜŞTERİ ONAYI', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            if (customerImage != null)
              pw.Image(customerImage, width: 120, height: 60, fit: pw.BoxFit.contain)
            else
              pw.SizedBox(height: 60, width: 120),
            pw.SizedBox(height: 5),
            pw.Text(_safeText(ticket['signature_name']), style: pw.TextStyle(font: font)),
          ]),
          pw.Column(children: [
            pw.Text('SERVİS YETKİLİSİ', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            if (techImage != null)
              pw.Image(techImage, width: 120, height: 60, fit: pw.BoxFit.contain)
            else
              pw.SizedBox(height: 60, width: 120),
            pw.SizedBox(height: 5),
            pw.Text(_safeText(ticket['technician_signature_name']), style: pw.TextStyle(font: font)),
          ]),
        ],
      ),
    );
  }

  // --- 2. RAPOR: STOK DURUM RAPORU (KATEGORİ BAZLI) ---

  static Future<Uint8List> generateStockReportPdfBytes() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('inventory').select().order('category', ascending: true).order('name', ascending: true);
      final List<Map<String, dynamic>> stocks = List<Map<String, dynamic>>.from(response);

      final pdf = pw.Document();
      final font = await _loadTurkishFont();

      // Kategorilere ayır
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
                      // Başlıklar
                      pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.grey100), children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Ürün Adı', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Adet', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Raf', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      ]),
                      // Satırlar
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

  // Deprecated wrapper
  static Future<void> exportStockReport() async {
    final bytes = await generateStockReportPdfBytes();
    await viewPdf(bytes, 'Stok_Raporu_${DateTime.now().toIso8601String().substring(0, 10)}');
  }

  // --- 3. RAPOR: YILLIK KULLANIM RAPORU (ARŞİV) ---

  static Future<Uint8List> generateAnnualUsageReportPdfBytes() async {
    try {
      final supabase = Supabase.instance.client;
      // Arşivlenmiş veya bitmiş işleri çek
      final response = await supabase.from('tickets')
          .select('planned_date, plc_model, aspirator_brand, aspirator_kw, vant_brand, vant_kw, hmi_brand, hmi_size')
          .or('status.eq.done,is_archived.eq.true');
          
      final List tickets = response as List;

      // Yıllara ve ürünlere göre grupla
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

        // PLC
        if (t['plc_model'] != null && t['plc_model'].toString().isNotEmpty) {
          addItem('PLC', '${t['plc_model']} PLC');
        }
        
        // Sürücüler
        if (t['aspirator_brand'] != null && t['aspirator_kw'] != null) {
           addItem('Sürücü', '${t['aspirator_brand']} ${t['aspirator_kw']} kW');
        }
        if (t['vant_brand'] != null && t['vant_kw'] != null) {
           addItem('Sürücü', '${t['vant_brand']} ${t['vant_kw']} kW');
        }

        // HMI
        if (t['hmi_brand'] != null && t['hmi_size'] != null) {
           addItem('HMI', '${t['hmi_brand']} ${t['hmi_size']} inç');
        }
      }

      final pdf = pw.Document();
      final font = await _loadTurkishFont();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: font),
          header: (context) => pw.Header(level: 0, child: pw.Text("YILLIK KULLANIM RAPORU", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          build: (context) {
            // Yılları sırala (Yeniden eskiye)
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

  // Deprecated wrapper
  static Future<void> exportAnnualUsageReport() async {
    final bytes = await generateAnnualUsageReportPdfBytes();
    await viewPdf(bytes, 'Yillik_Kullanim_Raporu');
  }
}

