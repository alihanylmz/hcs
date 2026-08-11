import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/discovery_project.dart';
import 'pdf_file_saver_stub.dart'
    if (dart.library.io) 'pdf_file_saver_io.dart'
    if (dart.library.html) 'pdf_file_saver_web.dart';

class DiscoveryPointListPdfService {
  const DiscoveryPointListPdfService();

  static const _ink = PdfColor.fromInt(0xFF15304C);
  static const _accent = PdfColor.fromInt(0xFFB8843C);
  static const _slate = PdfColor.fromInt(0xFF5A6B7A);
  static const _mist = PdfColor.fromInt(0xFFE4E8EC);
  static const _zebra = PdfColor.fromInt(0xFFF7F9FB);

  Future<String?> export(DiscoveryProject project) async {
    final bytes = await buildBytes(project);
    return savePdfFile(
      fileName: '${_fileNameBase(project)} - nokta-listesi.pdf',
      bytes: bytes,
      openAfterSave: true,
    );
  }

  Future<Uint8List> buildBytes(DiscoveryProject project) async {
    final fontBytes = await _loadAssetBytes('assets/fonts/NotoSans.ttf');
    final logoBytes = await _loadAssetBytes('lib/assest/logo/uzal.png');
    final font = fontBytes.isEmpty
        ? null
        : pw.Font.ttf(ByteData.sublistView(fontBytes));
    final logo = logoBytes.isEmpty ? null : pw.MemoryImage(logoBytes);
    final theme = font == null
        ? pw.ThemeData()
        : pw.ThemeData.withFont(base: font, bold: font);
    final rows = _pointRows(project);
    final typeTotals = _typeTotals(project);

    final doc = pw.Document(
      title: 'Nokta Listesi',
      author: 'Uzal Teknik',
      subject: project.projectName.trim().isEmpty
          ? 'Nokta Listesi'
          : project.projectName.trim(),
      creator: 'Uzal Teknik',
      theme: theme,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(34, 28, 34, 30),
        theme: theme,
        header: (context) => _header(project, logo),
        footer: _footer,
        build: (context) => [
          pw.SizedBox(height: 10),
          _titleBand(project),
          pw.SizedBox(height: 14),
          if (rows.isEmpty)
            _emptyState()
          else ...[
            _pointTable(rows),
            pw.SizedBox(height: 14),
            _totalBand(project.totalPoints),
            pw.SizedBox(height: 10),
            _typeSummary(typeTotals),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static Future<Uint8List> _loadAssetBytes(String path) async {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return Uint8List(0);
    }
  }

  static pw.Widget _header(DiscoveryProject project, pw.MemoryImage? logo) {
    final code = project.projectCode.trim();
    final revision = project.revision.trim().isEmpty
        ? '00'
        : project.revision.trim();
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _mist, width: 1)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null)
            pw.Container(width: 76, height: 38, child: pw.Image(logo))
          else
            pw.Text(
              'UZAL',
              style: pw.TextStyle(
                color: _ink,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Uzal Teknik',
                  style: pw.TextStyle(
                    color: _ink,
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'Nokta Listesi',
                  style: const pw.TextStyle(color: _slate, fontSize: 9),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              if (code.isNotEmpty) _metaLine('Proje Kodu', code),
              _metaLine('Revizyon', revision),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _mist, width: 1)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'Uzal Teknik',
              style: const pw.TextStyle(color: _slate, fontSize: 8),
            ),
          ),
          pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(color: _slate, fontSize: 8),
          ),
        ],
      ),
    );
  }

  static pw.Widget _titleBand(DiscoveryProject project) {
    final title = project.projectName.trim().isEmpty
        ? 'Hazırlanan Nokta Listesi'
        : project.projectName.trim();
    final preparedBy = project.preparedBy.trim();
    final date = DateFormat('dd.MM.yyyy').format(DateTime.now());
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: pw.BoxDecoration(
        color: _ink,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (preparedBy.isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3),
                    child: pw.Text(
                      'Hazırlayan: $preparedBy',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: pw.BoxDecoration(
              color: _accent,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              date,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _pointTable(List<_PointPdfRow> rows) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: _mist, width: 0.6),
      headerDecoration: const pw.BoxDecoration(color: _ink),
      headerStyle: pw.TextStyle(
        color: PdfColors.white,
        fontWeight: pw.FontWeight.bold,
        fontSize: 9,
      ),
      cellStyle: const pw.TextStyle(color: _ink, fontSize: 8.5),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
      oddRowDecoration: const pw.BoxDecoration(color: _zebra),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.45),
        1: const pw.FlexColumnWidth(3.8),
        2: const pw.FlexColumnWidth(1.25),
        3: const pw.FlexColumnWidth(0.8),
      },
      headers: const ['#', 'Nokta', 'Nokta Cinsi', 'Toplam'],
      data: [
        for (var index = 0; index < rows.length; index++)
          [
            '${index + 1}',
            rows[index].name,
            rows[index].typeLabel,
            '${rows[index].quantity}',
          ],
      ],
    );
  }

  static pw.Widget _totalBand(int total) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: pw.BoxDecoration(
          color: _accent,
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.Text(
          'Nokta Toplamı: $total',
          style: pw.TextStyle(
            color: PdfColors.white,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
  }

  static pw.Widget _typeSummary(Map<DiscoveryPointType, int> totals) {
    final visible = DiscoveryPointType.values
        .where((type) => (totals[type] ?? 0) > 0)
        .toList(growable: false);
    if (visible.isEmpty) return pw.SizedBox.shrink();
    return pw.Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final type in visible)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _zebra,
              border: pw.Border.all(color: _mist, width: 0.6),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              '${type.label}: ${totals[type]}',
              style: pw.TextStyle(
                color: _ink,
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  static pw.Widget _emptyState() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _mist),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        'Bu keşifte kayıtlı nokta bulunmuyor.',
        style: const pw.TextStyle(color: _slate, fontSize: 10),
      ),
    );
  }

  static pw.Widget _metaLine(String label, String value) {
    return pw.Text(
      '$label: $value',
      style: const pw.TextStyle(color: _slate, fontSize: 8.5),
    );
  }

  static List<_PointPdfRow> _pointRows(DiscoveryProject project) {
    final rows = <_PointPdfRow>[];
    for (final device in project.devices) {
      for (final point in device.points) {
        rows.add(
          _PointPdfRow(
            name: point.name.trim().isEmpty ? '-' : point.name.trim(),
            typeLabel: _pointTypeLabel(point),
            quantity: point.quantity,
          ),
        );
      }
    }
    return rows;
  }

  static Map<DiscoveryPointType, int> _typeTotals(DiscoveryProject project) {
    return {
      for (final type in DiscoveryPointType.values)
        type: project.countFor(type),
    };
  }

  static String _pointTypeLabel(DiscoveryPoint point) {
    if (point.type == DiscoveryPointType.aiActive &&
        point.analogSignal != DiscoveryAnalogSignal.unspecified) {
      return '${point.type.label} / ${point.analogSignal.label}';
    }
    return point.type.label;
  }

  static String _fileNameBase(DiscoveryProject project) {
    final code = project.projectCode.trim();
    if (code.isNotEmpty) return code;
    final name = project.projectName.trim();
    if (name.isNotEmpty) return name;
    return 'uzal-nokta-listesi';
  }
}

class _PointPdfRow {
  const _PointPdfRow({
    required this.name,
    required this.typeLabel,
    required this.quantity,
  });

  final String name;
  final String typeLabel;
  final int quantity;
}
