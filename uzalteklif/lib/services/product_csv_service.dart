import 'dart:convert';

import 'package:file_selector/file_selector.dart';

import '../models/product.dart';

class ProductCsvImportResult {
  const ProductCsvImportResult({
    required this.products,
    required this.skippedRows,
  });

  final List<Product> products;
  final int skippedRows;
}

class ProductCsvService {
  const ProductCsvService();

  static const headers = [
    'code',
    'name',
    'category',
    'brand',
    'model',
    'unit',
    'currency_code',
    'sale_price',
    'stock_quantity',
    'minimum_stock',
    'vat_rate',
    'lead_time',
    'description',
    'technical_summary',
    'is_active',
  ];

  Future<bool> saveTemplate() async {
    const sample = [
      'SNS-QAE-2120',
      'Kanal Tipi Sicaklik Sensoru',
      'Sensor',
      'Siemens',
      'QAE2120.010',
      'adet',
      'TL',
      '1850',
      '26',
      '8',
      '20',
      '2 is gunu',
      'HVAC sensor aciklamasi',
      'PT1000, IP54',
      'true',
    ];
    final csv = '${_formatCsvRow(headers)}\n${_formatCsvRow(sample)}\n';
    return _saveCsv(csv, 'uzal-stok-sablon.csv');
  }

  Future<ProductCsvImportResult?> pickAndParse({
    required List<Product> existingProducts,
  }) async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'CSV / Excel metin listesi',
          extensions: ['csv', 'tsv', 'txt'],
        ),
      ],
    );
    if (file == null) return null;

    final content = await file.readAsString();
    return parseContent(content, existingProducts: existingProducts);
  }

  ProductCsvImportResult parseContent(
    String content, {
    required List<Product> existingProducts,
  }) {
    final rows = _parseDelimited(content);
    if (rows.isEmpty) {
      return const ProductCsvImportResult(products: [], skippedRows: 0);
    }

    final normalizedHeaders = rows.first
        .map(_normalizeHeader)
        .toList(growable: false);
    final hasHeader =
        normalizedHeaders.contains('code') &&
        normalizedHeaders.contains('name');

    if (!hasHeader) {
      return _parseSupplierPriceList(rows, existingProducts: existingProducts);
    }

    final indexByHeader = <String, int>{
      for (var i = 0; i < normalizedHeaders.length; i++)
        normalizedHeaders[i]: i,
    };

    final byCode = {
      for (final product in existingProducts)
        product.code.trim().toUpperCase(): product,
    };

    var skippedRows = 0;
    final products = <Product>[];
    for (final row in rows.skip(1)) {
      if (row.every((cell) => cell.trim().isEmpty)) continue;

      String read(String key) {
        final index = indexByHeader[key];
        if (index == null || index >= row.length) return '';
        return row[index].trim();
      }

      final code = read('code');
      final name = read('name');
      if (code.isEmpty || name.isEmpty) {
        skippedRows++;
        continue;
      }

      final now = DateTime.now().toUtc();
      final existing = byCode[code.toUpperCase()];
      products.add(
        Product(
          id:
              existing?.id ??
              'product-${now.microsecondsSinceEpoch}-${products.length}',
          code: code,
          name: name,
          category: _fallback(read('category'), 'Genel'),
          brand: read('brand'),
          model: read('model'),
          unit: _fallback(read('unit'), 'adet'),
          currencyCode: _normalizeCurrency(read('currency_code')),
          salePrice: _readDouble(read('sale_price')),
          stockQuantity: _readDouble(read('stock_quantity')),
          minimumStock: _readDouble(read('minimum_stock')),
          vatRate: _readDouble(read('vat_rate'), fallback: 20),
          leadTime: read('lead_time'),
          description: read('description'),
          technicalSummary: read('technical_summary'),
          isActive: _readBool(read('is_active')),
          updatedAt: now,
          imagePath: existing?.imagePath ?? '',
          specifications: existing?.specifications ?? const {},
        ),
      );
    }

    return ProductCsvImportResult(products: products, skippedRows: skippedRows);
  }

  ProductCsvImportResult _parseSupplierPriceList(
    List<List<String>> rows, {
    required List<Product> existingProducts,
  }) {
    final byCode = {
      for (final product in existingProducts)
        product.code.trim().toUpperCase(): product,
    };
    final productsByCode = <String, Product>{};
    var skippedRows = 0;

    for (final row in rows) {
      if (row.every((cell) => cell.trim().isEmpty)) continue;
      if (row.length < 7) {
        skippedRows++;
        continue;
      }

      // Desteklenen başlıksız tedarikçi listeleri:
      // 7 kolon: kategori, kod, açıklama, para birimi, fiyat, marka, durum
      // 9 kolon: grup, kategori, alt kategori, kod, açıklama,
      //          para birimi, fiyat, durum, menşei
      final isDetailedFormat = row.length >= 9;
      final category = row[isDetailedFormat ? 1 : 0].trim();
      final code = row[isDetailedFormat ? 3 : 1].trim();
      final name = row[isDetailedFormat ? 4 : 2].trim();
      if (code.isEmpty || name.isEmpty) {
        skippedRows++;
        continue;
      }

      final normalizedCode = code.toUpperCase();
      final now = DateTime.now().toUtc();
      final existing = byCode[normalizedCode];
      final supplierStatus = row[isDetailedFormat ? 7 : 6].trim();
      final specifications = Map<String, String>.from(
        existing?.specifications ?? const {},
      );
      if (isDetailedFormat) {
        specifications.addAll({
          'supplier_group': row[0].trim(),
          'supplier_subcategory': row[2].trim(),
          'supplier_status': supplierStatus,
          'origin_country': row[8].trim(),
        });
      }
      productsByCode[normalizedCode] = Product(
        id:
            existing?.id ??
            productsByCode[normalizedCode]?.id ??
            'product-${now.microsecondsSinceEpoch}-${productsByCode.length}',
        code: code,
        name: name,
        category: _fallback(category, 'Genel'),
        brand: isDetailedFormat
            ? _fallback(existing?.brand ?? '', 'Honeywell')
            : row[5].trim(),
        model: code,
        unit: 'adet',
        currencyCode: _normalizeCurrency(row[isDetailedFormat ? 5 : 3]),
        salePrice: _readDouble(row[isDetailedFormat ? 6 : 4]),
        stockQuantity: existing?.stockQuantity ?? 0,
        minimumStock: existing?.minimumStock ?? 0,
        vatRate: existing?.vatRate ?? 20,
        leadTime: existing?.leadTime ?? '',
        description: name,
        technicalSummary: isDetailedFormat
            ? [
                if (row[0].trim().isNotEmpty) 'Grup: ${row[0].trim()}',
                if (row[2].trim().isNotEmpty) 'Alt kategori: ${row[2].trim()}',
                if (row[8].trim().isNotEmpty) 'Menşei: ${row[8].trim()}',
                if (supplierStatus.isNotEmpty) 'Durum: $supplierStatus',
              ].join(' | ')
            : existing?.technicalSummary ?? '',
        isActive: isDetailedFormat
            ? _readDetailedSupplierStatus(supplierStatus)
            : _readBool(supplierStatus),
        updatedAt: now,
        imagePath: existing?.imagePath ?? '',
        specifications: specifications,
      );
    }

    return ProductCsvImportResult(
      products: productsByCode.values.toList(growable: false),
      skippedRows: skippedRows,
    );
  }

  Future<bool> _saveCsv(String csv, String suggestedName) async {
    final path = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    if (path == null) return false;

    await XFile.fromData(
      utf8.encode(csv),
      name: suggestedName,
      mimeType: 'text/csv',
    ).saveTo(path.path);
    return true;
  }

  static String _formatCsvRow(List<String> cells) {
    return cells.map(_escapeCsvCell).join(',');
  }

  static String _escapeCsvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }

  static List<List<String>> _parseDelimited(String input) {
    final delimiter = _detectDelimiter(input);
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '"') {
        if (inQuotes && i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == delimiter && !inQuotes) {
        row.add(cell.toString());
        cell.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        row.add(cell.toString());
        cell.clear();
        rows.add(row);
        row = <String>[];
      } else {
        cell.write(char);
      }
    }

    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }

  static String _detectDelimiter(String input) {
    final firstLine = input
        .split(RegExp(r'\r?\n'))
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
    final tabs = '\t'.allMatches(firstLine).length;
    final semicolons = ';'.allMatches(firstLine).length;
    final commas = ','.allMatches(firstLine).length;
    if (tabs > commas && tabs >= semicolons) return '\t';
    if (semicolons > commas) return ';';
    return ',';
  }

  static String _normalizeHeader(String value) {
    final normalized = value.trim().toLowerCase();
    return switch (normalized) {
      'kod' || 'ürün kodu' || 'urun kodu' => 'code',
      'ürün adı' || 'urun adi' || 'açıklama' || 'aciklama' => 'name',
      'kategori' => 'category',
      'marka' => 'brand',
      'model' => 'model',
      'birim' => 'unit',
      'para birimi' || 'döviz' || 'doviz' => 'currency_code',
      'fiyat' || 'satış fiyatı' || 'satis fiyati' => 'sale_price',
      'durum' || 'aktif' => 'is_active',
      _ => normalized,
    };
  }

  static String _fallback(String value, String fallback) {
    return value.trim().isEmpty ? fallback : value.trim();
  }

  static String _normalizeCurrency(String raw) {
    final value = raw.trim().toUpperCase();
    return switch (value) {
      'USD' || 'USDTRY' => 'USDTRY',
      'EUR' || 'EURTRY' => 'EURTRY',
      _ => 'TL',
    };
  }

  static double _readDouble(String raw, {double fallback = 0}) {
    final value = raw.replaceAll(RegExp(r'[^0-9,.\-]'), '').trim();
    if (value.isEmpty) return fallback;
    final normalized = value.contains(',')
        ? value.replaceAll('.', '').replaceAll(',', '.')
        : value;
    return double.tryParse(normalized) ?? fallback;
  }

  static bool _readBool(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return true;
    return value == 'true' ||
        value == '1' ||
        value == 'evet' ||
        value == 'yes' ||
        value == 'active' ||
        value == 'aktif';
  }

  static bool _readDetailedSupplierStatus(String raw) {
    final value = raw.trim().toLowerCase();
    return value == 'active' ||
        value == 'new' ||
        value == 'phase in' ||
        value.startsWith('active,');
  }
}
