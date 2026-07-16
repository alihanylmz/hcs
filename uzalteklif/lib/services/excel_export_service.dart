import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_selector/file_selector.dart';

import '../models/quote.dart';

class ExcelExportService {
  const ExcelExportService();

  Future<String?> exportQuote(Quote quote) async {
    final excel = Excel.createExcel();
    final sheet = excel['Teklif'];

    sheet.appendRow([TextCellValue('Teklif No'), TextCellValue(quote.code)]);
    sheet.appendRow([
      TextCellValue('Musteri'),
      TextCellValue(quote.customerName),
    ]);
    sheet.appendRow([
      TextCellValue('Firma'),
      TextCellValue(quote.customerCompany),
    ]);
    sheet.appendRow([TextCellValue('Baslik'), TextCellValue(quote.title)]);
    sheet.appendRow(const []);
    sheet.appendRow([
      TextCellValue('Kalem'),
      TextCellValue('Miktar'),
      TextCellValue('Birim'),
      TextCellValue('Birim Fiyat (TL)'),
      TextCellValue('Iskonto %'),
      TextCellValue('Net Birim (TL)'),
      TextCellValue('Toplam (TL)'),
    ]);

    for (final item in quote.items) {
      // Gizli yukleme uplift'i uygulanmis efektif fiyatlar;
      // gizli kalemler Excel'de ayri satir olarak gozukmez, fiyatlara yedirilir.
      sheet.appendRow([
        TextCellValue(item.description),
        DoubleCellValue(item.quantity),
        TextCellValue(item.unit),
        DoubleCellValue(quote.effectiveUnitPriceTl(item)),
        DoubleCellValue(item.discountRate),
        DoubleCellValue(quote.effectiveNetUnitPriceTl(item)),
        DoubleCellValue(quote.effectiveLineTotalTl(item)),
      ]);
    }

    sheet.appendRow(const []);
    sheet.appendRow([
      TextCellValue('Genel Toplam'),
      DoubleCellValue(quote.subtotalTl),
    ]);

    final bytes = excel.encode();
    if (bytes == null) {
      return null;
    }

    final location = await getSaveLocation(
      suggestedName: '${quote.code}.xlsx',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    );

    if (location == null) {
      return null;
    }

    final file = File(location.path);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String?> exportMaterialRequest(Quote quote) async {
    final excel = Excel.createExcel();
    final sheet = excel['Istek Listesi'];

    sheet.appendRow([TextCellValue('Istek No'), TextCellValue(quote.code)]);
    sheet.appendRow([
      TextCellValue('Tarih'),
      TextCellValue(quote.formattedDate),
    ]);
    sheet.appendRow([
      TextCellValue('Tedarikci / Firma'),
      TextCellValue(
        quote.customerCompany.trim().isNotEmpty
            ? quote.customerCompany.trim()
            : quote.customerName.trim(),
      ),
    ]);
    sheet.appendRow([TextCellValue('Baslik'), TextCellValue(quote.title)]);
    sheet.appendRow(const []);
    sheet.appendRow([
      TextCellValue('Sira'),
      TextCellValue('Malzeme'),
      TextCellValue('Miktar'),
      TextCellValue('Birim'),
      TextCellValue('Not'),
    ]);

    var index = 1;
    for (final group in quote.sectionedItems) {
      if (quote.sections.isNotEmpty) {
        sheet.appendRow([
          TextCellValue(group.displayName),
          TextCellValue('${group.items.length} kalem'),
        ]);
      }
      for (final item in group.items) {
        sheet.appendRow([
          IntCellValue(index),
          TextCellValue(item.description),
          DoubleCellValue(item.quantity),
          TextCellValue(item.unit),
          TextCellValue(''),
        ]);
        index++;
      }
    }

    final bytes = excel.encode();
    if (bytes == null) {
      return null;
    }

    final location = await getSaveLocation(
      suggestedName: '${quote.code} - istek-listesi.xlsx',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    );

    if (location == null) {
      return null;
    }

    final file = File(location.path);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
