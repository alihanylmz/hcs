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
        XTypeGroup(label: 'CSV', extensions: ['csv']),
      ],
    );
    if (file == null) return null;

    final content = await file.readAsString();
    final rows = _parseCsv(content);
    if (rows.isEmpty) {
      return const ProductCsvImportResult(products: [], skippedRows: 0);
    }

    final normalizedHeaders = rows.first
        .map((header) => header.trim().toLowerCase())
        .toList(growable: false);
    final indexByHeader = <String, int>{
      for (var i = 0; i < normalizedHeaders.length; i++)
        normalizedHeaders[i]: i,
    };

    final byCode = {
      for (final product in existingProducts) product.code.trim(): product,
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
      final existing = byCode[code];
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

  static List<List<String>> _parseCsv(String input) {
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
      } else if (char == ',' && !inQuotes) {
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
    final value = raw.trim();
    if (value.isEmpty) return fallback;
    final normalized = value.contains(',')
        ? value.replaceAll('.', '').replaceAll(',', '.')
        : value;
    return double.tryParse(normalized) ?? fallback;
  }

  static bool _readBool(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.isEmpty) return true;
    return value == 'true' || value == '1' || value == 'evet' || value == 'yes';
  }
}
