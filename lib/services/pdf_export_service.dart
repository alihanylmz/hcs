import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../services/stock_service.dart';

import 'package:intl/intl.dart'; // <--- Eklendi

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
      // Önce lokal asset'ten yüklemeyi dene (daha hızlı ve offline çalışır)
      final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      return pw.Font.ttf(fontData);
    } catch (e) {
      print('Yerel font yüklenemedi, Google Fonts deneniyor: $e');
      try {
        // Lokal başarısız olursa Google Fonts'tan dene
        return await PdfGoogleFonts.notoSansRegular();
      } catch (e2) {
        print('Google Fonts da yüklenemedi: $e2');
        // En kötü ihtimalle varsayılan fonta dön
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

  /// Point logosunu yükler (sadece PNG)
  static Future<pw.ImageProvider?> _loadPointLogo() async {
    try {
      final pngData = await rootBundle.load('assets/images/point.png');
      final pngBytes = pngData.buffer.asUint8List();
      return pw.MemoryImage(pngBytes);
    } catch (e) {
      print('Point logosu yüklenemedi: $e');
      return null;
    }
  }

  /// Vensa logosunu yükler (sadece PNG)
  static Future<pw.ImageProvider?> _loadVensaLogo() async {
    try {
      final pngData = await rootBundle.load('assets/images/vensa.png');
      final pngBytes = pngData.buffer.asUint8List();
      return pw.MemoryImage(pngBytes);
    } catch (e) {
      print('Vensa logosu yüklenemedi: $e');
      return null;
    }
  }

  static String _formatDate(String? iso) {
    if (iso == null) return '-';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    // intl paketini kullanarak formatlama
    return DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(parsed);
  }

  static String _safeText(dynamic value) {
    if (value == null) return '-';
    if (value is String && value.trim().isEmpty) return '-';
    return value.toString();
  }

  /// Açıklama/tekst içindeki "Ekli PDF Dosyası: <url>" ifadesini gizlemek için kullanılır.
  static String _stripAttachedPdfText(String? text) {
    if (text == null) return '-';
    final cleaned = text.replaceAll(
      RegExp(r'Ekli PDF Dosyası: https?://[^\s]+'),
      '',
    ).trim();
    return cleaned.isEmpty ? '-' : cleaned;
  }

  /// Ticket notlarındaki resim URL'lerini indirip PDF'te kullanılacak hale getirir.
  static Future<List<Map<String, dynamic>>> _enrichNotesWithImages(
    List<Map<String, dynamic>> notes,
  ) async {
    final List<Map<String, dynamic>> enriched = [];

    for (final raw in notes) {
      final note = Map<String, dynamic>.from(raw);

      // Hem eski tekil image_url hem de yeni image_urls (liste) alanlarını destekle
      List<String> urls = [];
      if (note['image_urls'] != null) {
        urls = List<String>.from(note['image_urls']);
      } else if (note['image_url'] != null) {
        urls.add(note['image_url'] as String);
      }

      final List<pw.ImageProvider> images = [];

      for (final url in urls) {
        try {
          final uri = Uri.tryParse(url);
          if (uri == null) continue;

          final resp = await http.get(uri);
          if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
            images.add(pw.MemoryImage(resp.bodyBytes));
          }
        } catch (_) {
          // Hata olursa o resmi atla, PDF üretimini bozma
        }
      }

      note['pdf_images'] = images;
      enriched.add(note);
    }

    return enriched;
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
            ),
            partners (
              id,
              name
            )
          ''')
          .eq('id', idValue)
          .maybeSingle();

      if (ticket == null) {
        throw Exception('İş bulunamadı.');
      }

      final notesResponse = await supabase
          .from('ticket_notes')
          .select('*, profiles(full_name, role)')
          .eq('ticket_id', idValue)
          .neq('note_type', 'partner_note') // Partner notlarını PDF'den hariç tut
          .order('created_at', ascending: true);
      
      final notes = List<Map<String, dynamic>>.from(notesResponse);

      // Notlara eklenen resimleri indir ve PDF'e uygun nesnelere dönüştür
      final enrichedNotes = await _enrichNotesWithImages(notes);

      // Partner kontrolü - Point ve Vensa için özel PDF tasarımı
      final partner = ticket['partners'] as Map<String, dynamic>?;
      final partnerName = partner?['name'] as String?;
      
      pw.Document pdf;
      if (partnerName != null && partnerName.toLowerCase().contains('point')) {
        // Point partner'ı için özel PDF tasarımı
        pdf = await _generatePointTicketPdf(ticket, enrichedNotes);
      } else if (partnerName != null && partnerName.toLowerCase().contains('vensa')) {
        // Vensa partner'ı için özel PDF tasarımı
        pdf = await _generateVensaTicketPdf(ticket, enrichedNotes);
      } else {
        // Standart PDF tasarımı
        pdf = await _generateSingleTicketPdf(ticket, enrichedNotes);
      }
      
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
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Text(
              _stripAttachedPdfText(ticket['description'] as String?),
              style: pw.TextStyle(font: turkishFont, fontSize: 10),
            ),
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
                if (aspKw != null) 
                  _buildZebraRow('Aspiratör', '${_safeText(aspKw)} kW', turkishFont, 0),
                if (vantKw != null) 
                  _buildZebraRow('Vantilatör', '${_safeText(vantKw)} kW', turkishFont, 1),
                if (komp1Kw != null) 
                  _buildZebraRow('Kompresör 1', '${_safeText(komp1Kw)} kW', turkishFont, 0),
                if (hmiBrand != null) 
                  _buildZebraRow('HMI Ekran', '${_safeText(hmiBrand)} - ${_safeText(hmiSize)} inç', turkishFont, 1),
              ],
            ),
          ],

          // --- SERVİS NOTLARI (Sadece Metin) ---
          if (notes.isNotEmpty) ...[
            _buildSectionHeader('Servis Notları', turkishFont),
            pw.Column(
              children: notes.map<pw.Widget>((note) {
                final date = _formatDate(note['created_at']);
                final profile = note['profiles'] as Map<String, dynamic>?;
                final author = profile?['full_name'] ?? 'Teknisyen';
                final role = profile?['role'] as String?;
                String? roleLabel;
                if (role == 'technician') {
                  roleLabel = 'Teknisyen';
                } else if (role == 'manager' || role == 'admin') {
                  roleLabel = 'Mühendis';
                }
                final text = _stripAttachedPdfText(note['note'] as String?);
                
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
                          pw.Text(
                            roleLabel != null ? '$author ($roleLabel)' : author,
                            style: pw.TextStyle(
                              font: turkishFont,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 9,
                              color: _accentColor,
                            ),
                          ),
                          pw.Text(
                            date,
                            style: pw.TextStyle(
                              font: turkishFont,
                              fontSize: 8,
                              color: PdfColors.grey600,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        text,
                        style: pw.TextStyle(font: turkishFont, fontSize: 10),
                      ),
                      // Eğer notta resim varsa açıklama ekle
                      if ((note['pdf_images'] as List<pw.ImageProvider>?)?.isNotEmpty ?? false) ...[
                        pw.SizedBox(height: 6),
                        pw.Text(
                          'İlgili servise ait resimler ektedir.',
                          style: pw.TextStyle(
                            font: turkishFont,
                            fontSize: 9,
                            color: PdfColors.grey700,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // --- EK SAYFASI: FOTOĞRAFLAR (EK.1) ---
          if (notes.any((n) =>
              ((n['pdf_images'] as List<pw.ImageProvider>?)?.isNotEmpty ?? false))) ...[
            pw.NewPage(),
            _buildSectionHeader('EK.1 - SERVİS FOTOĞRAF EKLERİ', turkishFont),
            pw.SizedBox(height: 2),
            pw.Text(
              'Tarih: ${_formatDate(DateTime.now().toIso8601String())}',
              style: pw.TextStyle(font: turkishFont, fontSize: 8, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 8),
            ...notes.map<pw.Widget>((note) {
              final List<pw.ImageProvider> images =
                  (note['pdf_images'] as List<pw.ImageProvider>?) ?? const [];
              if (images.isEmpty) {
                return pw.SizedBox();
              }

              final date = _formatDate(note['created_at']);
              final author = note['profiles']?['full_name'] ?? 'Teknisyen';

              // 4 kolondan oluşan grid: her satırda 4 fotoğraf
              const cols = 4;
              const double cellSize = 110; // A4 sayfa için yaklaşık kare boyutu

              final List<pw.TableRow> rows = [];
              for (var i = 0; i < images.length; i += cols) {
                final rowChildren = <pw.Widget>[];
                for (var c = 0; c < cols; c++) {
                  final index = i + c;
                  if (index < images.length) {
                    rowChildren.add(
                      pw.Container(
                        width: cellSize,
                        height: cellSize,
                        margin: const pw.EdgeInsets.all(2),
                        decoration: pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                        ),
                        child: pw.ClipRect(
                          child: pw.Image(
                            images[index],
                            fit: pw.BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  } else {
                    // Boş hücre, grid hizalaması bozulmasın
                    rowChildren.add(pw.SizedBox(width: cellSize, height: cellSize));
                  }
                }
                rows.add(
                  pw.TableRow(
                    children: rowChildren,
                  ),
                );
              }

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '$author - $date',
                    style: pw.TextStyle(
                      font: turkishFont,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Table(
                    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                    children: rows,
                  ),
                  pw.SizedBox(height: 12),
                ],
              );
            }).toList(),
          ],
        ],
      ),
    );
    return pdf;
  }

  /// Point partner'ı için özel PDF tasarımı - Kırmızı tema
  static Future<pw.Document> _generatePointTicketPdf(Map<String, dynamic> ticket, List<Map<String, dynamic>> notes) async {
    final pdf = pw.Document();
    final turkishFont = await _loadTurkishFont();
    final pointLogo = await _loadPointLogo();

    final customer = ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final status = ticket['status'] as String? ?? 'open';
    final partner = ticket['partners'] as Map<String, dynamic>?;
    final partnerName = partner?['name'] as String? ?? 'Point';
    
    // Point için özel renkler - Professional Corporate Red
    const pointPrimaryColor = PdfColor.fromInt(0xFFD32F2F); // Professional Corporate Red
    const pointAccentColor = PdfColor.fromInt(0xFF424242); // Dark Grey (replaces Teal)
    const pointLightBgColor = PdfColors.grey100; // Keep light background for printer-friendly
    
    // Şirket bilgileri
    const companyAddress = 'Dağyaka Mahallesi 2022.Cad No:18/1, KahramanKazan/ANKARA';
    const companyPhone = '+90 (312) 394 57 69';
    const companyFax = '+90 (312) 394 32 79';
    const companyEmail = 'info@hytgrup.com';

    // Teknik Veriler
    final aspKw = ticket['aspirator_kw'];
    final vantKw = ticket['vant_kw'];
    final komp1Kw = ticket['kompresor_kw_1'];
    // final komp2Kw = ticket['kompresor_kw_2']; // Kullanılmıyorsa warning vermesin diye kapadım
    final hmiBrand = ticket['hmi_brand'];
    final hmiSize = ticket['hmi_size'];

    pdf.addPage(
      pw.MultiPage(
        // ✅ DÜZELTME: pageFormat, margin ve theme'i pageTheme içine taşıdık, çakışma yok artık
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          theme: pw.ThemeData.withFont(base: turkishFont, bold: turkishFont),
          // buildBackground her sayfanın en altına çizilir
          buildBackground: (context) {
            if (pointLogo == null) return pw.SizedBox();
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Opacity(
                  opacity: 0.08,
                  child: pw.Image(
                    pointLogo,
                    width: 400,
                    height: 400,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            );
          },
        ),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (pointLogo != null) ...[
                        pw.Container(
                          width: 130,
                          height: 130,
                          child: pw.Image(pointLogo, fit: pw.BoxFit.contain),
                        ),
                        pw.SizedBox(width: 12),
                      ],
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text(
                          'Teknik Servis İş Emri ve Servis Formu',
                          style: pw.TextStyle(
                            font: turkishFont,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: pointPrimaryColor,
                          ),
                        ),
                      ]),
                    ],
                  ),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: pointLightBgColor,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Text(
                        'İŞ NO: ${_safeText(ticket['job_code'])}',
                        style: pw.TextStyle(
                          font: turkishFont,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Tarih: ${_formatDate(DateTime.now().toIso8601String())}',
                      style: pw.TextStyle(
                        font: turkishFont,
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ]),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: pointPrimaryColor, thickness: 2),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              _buildSignatureSection(ticket, turkishFont),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  '$companyAddress | Tel: $companyPhone | Fax: $companyFax | $companyEmail',
                  style: pw.TextStyle(
                    font: turkishFont,
                    fontSize: 7,
                    color: PdfColors.grey600,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Bu belge dijital olarak oluşturulmuştur.',
                  style: pw.TextStyle(
                    font: turkishFont,
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ],
          );
        },
        build: (pw.Context context) {
          // 🛠️ ARTIK BURADA STACK KULLANMIYORUZ, DİREKT LİSTE DÖNÜYORUZ
          return [
            // Müşteri ve Servis Bilgileri
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(flex: 5, child: pw.Column(children: [
                  _buildPointSectionHeader('Müşteri Bilgileri', turkishFont, pointPrimaryColor, pointAccentColor),
                  pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(color: pointLightBgColor, borderRadius: pw.BorderRadius.circular(5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    _buildInfoRow('Ünvan', _safeText(customer['name']), turkishFont, isFullWidth: true),
                    pw.SizedBox(height: 5),
                    _buildInfoRow('Telefon', _safeText(customer['phone']), turkishFont),
                    pw.Divider(height: 10),
                    _buildInfoRow('Adres', _safeText(customer['address']), turkishFont, isFullWidth: true),
                  ])),
                ])),
                pw.SizedBox(width: 20),
                pw.Expanded(flex: 4, child: pw.Column(children: [
                  _buildPointSectionHeader('Servis Detayları', turkishFont, pointPrimaryColor, pointAccentColor),
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
            
            // İş Açıklaması
            _buildPointSectionHeader('İş Açıklaması', turkishFont, pointPrimaryColor, pointAccentColor),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Text(
                _stripAttachedPdfText(ticket['description'] as String?),
                style: pw.TextStyle(font: turkishFont, fontSize: 10),
              ),
            ),

            // Teknik Bilgiler
            if (aspKw != null || vantKw != null || komp1Kw != null || hmiBrand != null) ...[
              _buildPointSectionHeader('Teknik Bilgiler', turkishFont, pointPrimaryColor, pointAccentColor),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(decoration: const pw.BoxDecoration(color: pointLightBgColor), children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Bileşen', style: pw.TextStyle(font: turkishFont, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Detay', style: pw.TextStyle(font: turkishFont, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  ]),
                  if (aspKw != null) 
                    _buildZebraRow('Aspiratör', '${_safeText(aspKw)} kW', turkishFont, 0),
                  if (vantKw != null) 
                    _buildZebraRow('Vantilatör', '${_safeText(vantKw)} kW', turkishFont, 1),
                  if (komp1Kw != null) 
                    _buildZebraRow('Kompresör 1', '${_safeText(komp1Kw)} kW', turkishFont, 0),
                  if (hmiBrand != null) 
                    _buildZebraRow('HMI Ekran', '${_safeText(hmiBrand)} - ${_safeText(hmiSize)} inç', turkishFont, 1),
                ],
              ),
            ],

            // Servis Notları
            if (notes.isNotEmpty) ...[
              _buildPointSectionHeader('Servis Notları', turkishFont, pointPrimaryColor, pointAccentColor),
              pw.Column(
                children: notes.map<pw.Widget>((note) {
                  final date = _formatDate(note['created_at']);
                  final profile = note['profiles'] as Map<String, dynamic>?;
                  final author = profile?['full_name'] ?? 'Teknisyen';
                  final role = profile?['role'] as String?;
                  String? roleLabel;
                  if (role == 'technician') {
                    roleLabel = 'Teknisyen';
                  } else if (role == 'manager' || role == 'admin') {
                    roleLabel = 'Mühendis';
                  }
                  final text = _stripAttachedPdfText(note['note'] as String?);
                  
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
                            pw.Text(
                              roleLabel != null ? '$author ($roleLabel)' : author,
                              style: pw.TextStyle(
                                font: turkishFont,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9,
                                color: pointAccentColor,
                              ),
                            ),
                            pw.Text(
                              date,
                              style: pw.TextStyle(
                                font: turkishFont,
                                fontSize: 8,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          text,
                          style: pw.TextStyle(font: turkishFont, fontSize: 10),
                        ),
                        // Eğer notta resim varsa açıklama ekle
                        if ((note['pdf_images'] as List<pw.ImageProvider>?)?.isNotEmpty ?? false) ...[
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'İlgili servise ait resimler ektedir.',
                            style: pw.TextStyle(
                              font: turkishFont,
                              fontSize: 9,
                              color: PdfColors.grey700,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // EK SAYFASI: FOTOĞRAFLAR (EK.1)
            // Stack'e gerek yok, MultiPage otomatik sayfa atlatır.
            if (notes.any((n) => ((n['pdf_images'] as List<pw.ImageProvider>?)?.isNotEmpty ?? false))) ...[
              pw.NewPage(),
              _buildPointSectionHeader('EK.1 - SERVİS FOTOĞRAF EKLERİ', turkishFont, pointPrimaryColor, pointAccentColor),
              pw.SizedBox(height: 2),
              pw.Text(
                'Tarih: ${_formatDate(DateTime.now().toIso8601String())}',
                style: pw.TextStyle(font: turkishFont, fontSize: 8, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 8),
              ...notes.map<pw.Widget>((note) {
                final List<pw.ImageProvider> images =
                    (note['pdf_images'] as List<pw.ImageProvider>?) ?? const [];
                if (images.isEmpty) {
                  return pw.SizedBox();
                }

                final date = _formatDate(note['created_at']);
                final author = note['profiles']?['full_name'] ?? 'Teknisyen';

                // 4 kolondan oluşan grid: her satırda 4 fotoğraf
                const cols = 4;
                const double cellSize = 110; // A4 sayfa için yaklaşık kare boyutu

                final List<pw.TableRow> rows = [];
                for (var i = 0; i < images.length; i += cols) {
                  final rowChildren = <pw.Widget>[];
                  for (var c = 0; c < cols; c++) {
                    final index = i + c;
                    if (index < images.length) {
                      rowChildren.add(
                        pw.Container(
                          width: cellSize,
                          height: cellSize,
                          margin: const pw.EdgeInsets.all(2),
                          decoration: pw.BoxDecoration(
                            borderRadius: pw.BorderRadius.circular(4),
                            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                          ),
                          child: pw.ClipRect(
                            child: pw.Image(
                              images[index],
                              fit: pw.BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    } else {
                      rowChildren.add(pw.SizedBox(width: cellSize, height: cellSize));
                    }
                  }
                  rows.add(pw.TableRow(children: rowChildren));
                }

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '$author - $date',
                      style: pw.TextStyle(
                        font: turkishFont,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: pointPrimaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Table(
                      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                      children: rows,
                    ),
                    pw.SizedBox(height: 12),
                  ],
                );
              }).toList(),
            ],
          ];
        },
      ),
    );
    return pdf;
  }

  /// Vensa partner'ı için özel PDF tasarımı - Mavi tema
  static Future<pw.Document> _generateVensaTicketPdf(Map<String, dynamic> ticket, List<Map<String, dynamic>> notes) async {
    final pdf = pw.Document();
    final turkishFont = await _loadTurkishFont();
    final vensaLogo = await _loadVensaLogo();

    final customer = ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final status = ticket['status'] as String? ?? 'open';
    final partner = ticket['partners'] as Map<String, dynamic>?;
    final partnerName = partner?['name'] as String? ?? 'Vensa';
    
    // Vensa için özel renkler - Professional Corporate Blue
    const vensaPrimaryColor = PdfColor.fromInt(0xFF1976D2); // Material Blue 700
    const vensaAccentColor = PdfColor.fromInt(0xFF1565C0); // Material Blue 800
    const vensaLightBgColor = PdfColors.grey100; // Keep light background for printer-friendly
    
    // Şirket bilgileri - Vensa
    const companyAddress = 'Pursaklar Sanayi Sitesi 1643. Cad. No: 18 Altındağ, Ankara, Türkiye';
    const companyPhone = '+90 312 528 14 14';
    const companyEmail = 'info@vensaart.com';

    // Teknik Veriler
    final aspKw = ticket['aspirator_kw'];
    final vantKw = ticket['vant_kw'];
    final komp1Kw = ticket['kompresor_kw_1'];
    final hmiBrand = ticket['hmi_brand'];
    final hmiSize = ticket['hmi_size'];

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 30),
          theme: pw.ThemeData.withFont(base: turkishFont, bold: turkishFont),
          // buildBackground her sayfanın en altına çizilir
          buildBackground: (context) {
            if (vensaLogo == null) return pw.SizedBox();
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(
                child: pw.Opacity(
                  opacity: 0.08,
                  child: pw.Image(
                    vensaLogo,
                    width: 400,
                    height: 400,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            );
          },
        ),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (vensaLogo != null) ...[
                        pw.Container(
                          width: 140,
                          height: 140,
                          child: pw.Image(vensaLogo, fit: pw.BoxFit.contain),
                        ),
                        pw.SizedBox(width: 12),
                      ],
                      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text(
                          'Teknik Servis İş Emri ve Servis Formu',
                          style: pw.TextStyle(
                            font: turkishFont,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: vensaPrimaryColor,
                          ),
                        ),
                      ]),
                    ],
                  ),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: vensaLightBgColor,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Text(
                        'İŞ NO: ${_safeText(ticket['job_code'])}',
                        style: pw.TextStyle(
                          font: turkishFont,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Tarih: ${_formatDate(DateTime.now().toIso8601String())}',
                      style: pw.TextStyle(
                        font: turkishFont,
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ]),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: vensaPrimaryColor, thickness: 2),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              _buildSignatureSection(ticket, turkishFont),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Adres: $companyAddress',
                      style: pw.TextStyle(
                        font: turkishFont,
                        fontSize: 7,
                        color: PdfColors.grey600,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Telefon: $companyPhone E-Posta: $companyEmail',
                      style: pw.TextStyle(
                        font: turkishFont,
                        fontSize: 7,
                        color: PdfColors.grey600,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Bu belge dijital olarak oluşturulmuştur.',
                  style: pw.TextStyle(
                    font: turkishFont,
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Müşteri ve Servis Bilgileri
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(flex: 5, child: pw.Column(children: [
                  _buildVensaSectionHeader('Müşteri Bilgileri', turkishFont, vensaPrimaryColor, vensaAccentColor),
                  pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(color: vensaLightBgColor, borderRadius: pw.BorderRadius.circular(5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    _buildInfoRow('Ünvan', _safeText(customer['name']), turkishFont, isFullWidth: true),
                    pw.SizedBox(height: 5),
                    _buildInfoRow('Telefon', _safeText(customer['phone']), turkishFont),
                    pw.Divider(height: 10),
                    _buildInfoRow('Adres', _safeText(customer['address']), turkishFont, isFullWidth: true),
                  ])),
                ])),
                pw.SizedBox(width: 20),
                pw.Expanded(flex: 4, child: pw.Column(children: [
                  _buildVensaSectionHeader('Servis Detayları', turkishFont, vensaPrimaryColor, vensaAccentColor),
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
            
            // İş Açıklaması
            _buildVensaSectionHeader('İş Açıklaması', turkishFont, vensaPrimaryColor, vensaAccentColor),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Text(
                _stripAttachedPdfText(ticket['description'] as String?),
                style: pw.TextStyle(font: turkishFont, fontSize: 10),
              ),
            ),

            // Teknik Bilgiler
            if (aspKw != null || vantKw != null || komp1Kw != null || hmiBrand != null) ...[
              _buildVensaSectionHeader('Teknik Bilgiler', turkishFont, vensaPrimaryColor, vensaAccentColor),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(decoration: const pw.BoxDecoration(color: vensaLightBgColor), children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Bileşen', style: pw.TextStyle(font: turkishFont, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Detay', style: pw.TextStyle(font: turkishFont, fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  ]),
                  if (aspKw != null) 
                    _buildZebraRow('Aspiratör', '${_safeText(aspKw)} kW', turkishFont, 0),
                  if (vantKw != null) 
                    _buildZebraRow('Vantilatör', '${_safeText(vantKw)} kW', turkishFont, 1),
                  if (komp1Kw != null) 
                    _buildZebraRow('Kompresör 1', '${_safeText(komp1Kw)} kW', turkishFont, 0),
                  if (hmiBrand != null) 
                    _buildZebraRow('HMI Ekran', '${_safeText(hmiBrand)} - ${_safeText(hmiSize)} inç', turkishFont, 1),
                ],
              ),
            ],

            // Servis Notları
            if (notes.isNotEmpty) ...[
              _buildVensaSectionHeader('Servis Notları', turkishFont, vensaPrimaryColor, vensaAccentColor),
              pw.Column(
                children: notes.map<pw.Widget>((note) {
                  final date = _formatDate(note['created_at']);
                  final profile = note['profiles'] as Map<String, dynamic>?;
                  final author = profile?['full_name'] ?? 'Teknisyen';
                  final role = profile?['role'] as String?;
                  String? roleLabel;
                  if (role == 'technician') {
                    roleLabel = 'Teknisyen';
                  } else if (role == 'manager' || role == 'admin') {
                    roleLabel = 'Mühendis';
                  }
                  final text = _stripAttachedPdfText(note['note'] as String?);
                  
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
                            pw.Text(
                              roleLabel != null ? '$author ($roleLabel)' : author,
                              style: pw.TextStyle(
                                font: turkishFont,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 9,
                                color: vensaAccentColor,
                              ),
                            ),
                            pw.Text(
                              date,
                              style: pw.TextStyle(
                                font: turkishFont,
                                fontSize: 8,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          text,
                          style: pw.TextStyle(font: turkishFont, fontSize: 10),
                        ),
                        // Eğer notta resim varsa açıklama ekle
                        if ((note['pdf_images'] as List<pw.ImageProvider>?)?.isNotEmpty ?? false) ...[
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'İlgili servise ait resimler ektedir.',
                            style: pw.TextStyle(
                              font: turkishFont,
                              fontSize: 9,
                              color: PdfColors.grey700,
                              fontStyle: pw.FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // EK SAYFASI: FOTOĞRAFLAR (EK.1)
            if (notes.any((n) => ((n['pdf_images'] as List<pw.ImageProvider>?)?.isNotEmpty ?? false))) ...[
              pw.NewPage(),
              _buildVensaSectionHeader('EK.1 - SERVİS FOTOĞRAF EKLERİ', turkishFont, vensaPrimaryColor, vensaAccentColor),
              pw.SizedBox(height: 2),
              pw.Text(
                'Tarih: ${_formatDate(DateTime.now().toIso8601String())}',
                style: pw.TextStyle(font: turkishFont, fontSize: 8, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 8),
              ...notes.map<pw.Widget>((note) {
                final List<pw.ImageProvider> images =
                    (note['pdf_images'] as List<pw.ImageProvider>?) ?? const [];
                if (images.isEmpty) {
                  return pw.SizedBox();
                }

                final date = _formatDate(note['created_at']);
                final author = note['profiles']?['full_name'] ?? 'Teknisyen';

                // 4 kolondan oluşan grid: her satırda 4 fotoğraf
                const cols = 4;
                const double cellSize = 110; // A4 sayfa için yaklaşık kare boyutu

                final List<pw.TableRow> rows = [];
                for (var i = 0; i < images.length; i += cols) {
                  final rowChildren = <pw.Widget>[];
                  for (var c = 0; c < cols; c++) {
                    final index = i + c;
                    if (index < images.length) {
                      rowChildren.add(
                        pw.Container(
                          width: cellSize,
                          height: cellSize,
                          margin: const pw.EdgeInsets.all(2),
                          decoration: pw.BoxDecoration(
                            borderRadius: pw.BorderRadius.circular(4),
                            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                          ),
                          child: pw.ClipRect(
                            child: pw.Image(
                              images[index],
                              fit: pw.BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    } else {
                      rowChildren.add(pw.SizedBox(width: cellSize, height: cellSize));
                    }
                  }
                  rows.add(pw.TableRow(children: rowChildren));
                }

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '$author - $date',
                      style: pw.TextStyle(
                        font: turkishFont,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: vensaPrimaryColor,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Table(
                      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                      children: rows,
                    ),
                    pw.SizedBox(height: 12),
                  ],
                );
              }).toList(),
            ],
          ];
        },
      ),
    );
    return pdf;
  }

  /// Point için özel section header (red theme)
  static pw.Widget _buildPointSectionHeader(String title, pw.Font font, PdfColor primaryColor, PdfColor accentColor) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10, top: 15),
      padding: const pw.EdgeInsets.only(bottom: 5),
      decoration: pw.BoxDecoration(
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

  /// Vensa için özel section header (blue theme)
  static pw.Widget _buildVensaSectionHeader(String title, pw.Font font, PdfColor primaryColor, PdfColor accentColor) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10, top: 15),
      padding: const pw.EdgeInsets.only(bottom: 5),
      decoration: pw.BoxDecoration(
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


  // Zebra Striping için yardımcı metod
  static pw.TableRow _buildZebraRow(String label, String value, pw.Font font, int index) {
    return pw.TableRow(
      decoration: pw.BoxDecoration(
        color: index % 2 == 0 ? PdfColors.white : PdfColors.grey100,
      ),
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 9))),
        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(value, style: pw.TextStyle(font: font, fontSize: 9))),
      ],
    );
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

  // --- 4. RAPOR: SİPARİŞ LİSTESİ (KRİTİK SEVİYENİN ALTINDAKİ STOKLAR) ---

  static Future<Uint8List> generateOrderListPdfBytes() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('inventory')
          .select()
          .order('category', ascending: true)
          .order('name', ascending: true);
      
      final List<Map<String, dynamic>> allStocks = List<Map<String, dynamic>>.from(response);
      
      // Kritik seviyenin altındaki veya sıfır olan stokları filtrele
      final List<Map<String, dynamic>> orderItems = allStocks.where((stock) {
        final qty = stock['quantity'] as int? ?? 0;
        final critical = stock['critical_level'] as int? ?? 5;
        return qty <= critical;
      }).toList();

      final pdf = pw.Document();
      final font = await _loadTurkishFont();
      final now = DateTime.now();
      final dateStr = DateFormat('dd.MM.yyyy', 'tr_TR').format(now);

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
                        pw.Text(
                          'SİPARİŞ LİSTESİ',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Tarih: $dateStr',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.red50,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.red300),
                      ),
                      child: pw.Text(
                        '${orderItems.length} Ürün',
                        style: pw.TextStyle(
                          font: font,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColors.red700,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(color: _primaryColor, thickness: 2),
              ],
            );
          },
          footer: (context) {
            return pw.Column(
              children: [
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    'Bu liste kritik seviyenin altındaki stokları içermektedir.',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      color: PdfColors.grey500,
                    ),
                  ),
                ),
              ],
            );
          },
          build: (context) {
            if (orderItems.isEmpty) {
              return [
                pw.SizedBox(height: 50),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Container(
                        width: 60,
                        height: 60,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.green50,
                          shape: pw.BoxShape.circle,
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            '✓',
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 36,
                              color: PdfColors.green700,
                            ),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 16),
                      pw.Text(
                        'Tüm stoklar yeterli seviyede!',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 14,
                          color: PdfColors.green700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Sipariş gerektiren ürün bulunmamaktadır.',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            }

            // Kategorilere göre grupla
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
                  // Kategori başlığı
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: pw.BoxDecoration(
                      color: _primaryColor,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      entry.key.toUpperCase(),
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  // Tablo
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(4),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(1.5),
                      4: const pw.FlexColumnWidth(1.5),
                    },
                    children: [
                      // Başlık satırı
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: _lightBgColor),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Ürün Adı',
                              style: pw.TextStyle(
                                font: font,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Mevcut',
                              style: pw.TextStyle(
                                font: font,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Kritik',
                              style: pw.TextStyle(
                                font: font,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Eksik',
                              style: pw.TextStyle(
                                font: font,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Raf',
                              style: pw.TextStyle(
                                font: font,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      // Veri satırları
                      ...entry.value.asMap().entries.map((itemEntry) {
                        final index = itemEntry.key;
                        final item = itemEntry.value;
                        final qty = item['quantity'] as int? ?? 0;
                        final critical = item['critical_level'] as int? ?? 5;
                        final missing = critical - qty;
                        final isZero = qty == 0;

                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                          ),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                _safeText(item['name']),
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 9,
                                  fontWeight: isZero ? pw.FontWeight.bold : null,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                qty.toString(),
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 9,
                                  color: isZero ? PdfColors.red : PdfColors.orange700,
                                  fontWeight: isZero ? pw.FontWeight.bold : null,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                critical.toString(),
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 9,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                missing > 0 ? missing.toString() : '-',
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 9,
                                  color: PdfColors.red700,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                _safeText(item['shelf_location']),
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 9,
                                  color: PdfColors.grey600,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
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

  // Deprecated wrapper
  static Future<void> exportOrderList() async {
    final bytes = await generateOrderListPdfBytes();
    await viewPdf(bytes, 'Siparis_Listesi_${DateTime.now().toIso8601String().substring(0, 10)}');
  }

  // --- 5. RAPOR: MANUEL SİPARİŞ LİSTESİ (SEÇİLEN ÜRÜNLERDEN) ---

  static Future<Uint8List> generateOrderListPdfBytesFromList(List<Map<String, dynamic>> selectedStocks) async {
    try {
      if (selectedStocks.isEmpty) {
        throw Exception('Seçilen ürün bulunamadı');
      }

      final pdf = pw.Document();
      final font = await _loadTurkishFont();
      final now = DateTime.now();
      final dateStr = DateFormat('dd.MM.yyyy', 'tr_TR').format(now);

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
                        pw.Text(
                          'SİPARİŞ LİSTESİ',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: _primaryColor,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Tarih: $dateStr',
                          style: pw.TextStyle(
                            font: font,
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.blue300),
                      ),
                      child: pw.Text(
                        '${selectedStocks.length} Ürün',
                        style: pw.TextStyle(
                          font: font,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                          color: PdfColors.blue700,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Divider(color: _primaryColor, thickness: 2),
              ],
            );
          },
          footer: (context) {
            return pw.Column(
              children: [
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    'Bu liste manuel olarak seçilen ürünleri içermektedir.',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      color: PdfColors.grey500,
                    ),
                  ),
                ),
              ],
            );
          },
          build: (context) {
            // Kategorilere göre grupla
            final Map<String, List<Map<String, dynamic>>> grouped = {};
            for (var item in selectedStocks) {
              final cat = item['category'] as String? ?? 'Diğer';
              if (!grouped.containsKey(cat)) grouped[cat] = [];
              grouped[cat]!.add(item);
            }

            return grouped.entries.map((entry) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 15),
                  // Kategori başlığı
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: pw.BoxDecoration(
                      color: _primaryColor,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      entry.key.toUpperCase(),
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  // Tablo
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 1),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(4),
                      1: const pw.FlexColumnWidth(1.5),
                      2: const pw.FlexColumnWidth(1.5),
                      3: const pw.FlexColumnWidth(1.5),
                      4: const pw.FlexColumnWidth(1.5),
                    },
                    children: [
                      // Başlık satırı
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: _lightBgColor),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Ürün Adı',
                              style: pw.TextStyle(
                                font: font,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Mevcut',
                              style: pw.TextStyle(
                                font: font,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Kritik',
                              style: pw.TextStyle(
                                font: font,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Sipariş Adedi',
                              style: pw.TextStyle(
                                font: font,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              'Raf',
                              style: pw.TextStyle(
                                font: font,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      // Veri satırları
                      ...entry.value.asMap().entries.map((itemEntry) {
                        final index = itemEntry.key;
                        final item = itemEntry.value;
                        final qty = item['quantity'] as int? ?? 0;
                        final critical = item['critical_level'] as int? ?? 5;
                        final orderQty = item['order_quantity'] as int? ?? 1;
                        final isZero = qty == 0;

                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                          ),
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                _safeText(item['name']),
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 9,
                                  fontWeight: isZero ? pw.FontWeight.bold : null,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                qty.toString(),
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 9,
                                  color: isZero ? PdfColors.red : PdfColors.orange700,
                                  fontWeight: isZero ? pw.FontWeight.bold : null,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                critical.toString(),
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 9,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                orderQty.toString(),
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 9,
                                  color: PdfColors.blue700,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text(
                                _safeText(item['shelf_location']),
                                style: pw.TextStyle(
                                  font: font,
                                  fontSize: 9,
                                  color: PdfColors.grey600,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
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

