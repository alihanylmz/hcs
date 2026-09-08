/// Excel/Sheets'ten kopyalanan tablo metnini kalem satirlarina cevirir.
///
/// Beklenen sutun sirasi ekrandaki tabloyla ayni:
/// `Aciklama, Miktar, Birim, Birim Fiyat, Iskonto`.
/// Eksik sutunlar varsayilanla doldurulur; fazlasi yok sayilir.
library;

class TabularPasteRow {
  const TabularPasteRow({
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.discount,
  });

  final String description;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double discount;
}

class TabularPasteParser {
  const TabularPasteParser._();

  /// Excel kopyalamasi sekme ile ayirir; elle hazirlanan CSV'lerde noktali
  /// virgul de yaygin oldugu icin ikisi de kabul ediliyor. Virgul BILEREK
  /// ayirici sayilmiyor: Turkce sayilarda ondalik ayraci o.
  static const _delimiters = ['\t', ';'];

  /// Turkce ve Ingilizce sayi bicimlerinin ikisini de okur.
  ///
  /// `1.234,56` (tr) ve `1,234.56` (en) ayni degeri vermeli. Ayirt etme
  /// kurali: son gorulen ayirici ondalik kabul edilir, digerleri binlik
  /// ayiraci olarak atilir. Tek ayirici varsa ve sagindaki grup tam 3 hane
  /// ise binlik sayilir (`1.234` -> 1234), degilse ondalik (`12,5` -> 12.5).
  static double? parseNumber(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;
    // Para simgeleri, bosluklar ve yuzde isareti temizlenir.
    s = s.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (s.isEmpty || s == '-') return null;

    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');

    String normalized;
    if (lastComma == -1 && lastDot == -1) {
      normalized = s;
    } else if (lastComma >= 0 && lastDot >= 0) {
      // Iki ayirici da var: sonuncusu ondalik.
      final decimalAt = lastComma > lastDot ? lastComma : lastDot;
      final intPart = s.substring(0, decimalAt).replaceAll(RegExp(r'[.,]'), '');
      final fracPart = s.substring(decimalAt + 1).replaceAll(RegExp(r'[.,]'), '');
      normalized = '$intPart.$fracPart';
    } else {
      final at = lastComma >= 0 ? lastComma : lastDot;
      final frac = s.substring(at + 1);
      if (frac.length == 3 && !s.substring(0, at).contains(RegExp(r'[.,]'))) {
        // `1.234` / `1,234`: binlik ayiraci kabul edilir.
        normalized = s.replaceAll(RegExp(r'[.,]'), '');
      } else {
        normalized = '${s.substring(0, at)}.$frac';
      }
    }
    return double.tryParse(normalized);
  }

  /// Yapistirilan metni satirlara ceviri. Bos satirlar atlanir.
  ///
  /// [skipHeader] true ise ilk satir baslik kabul edilip atlanir; cagiran
  /// taraf bunu kullaniciya sorabilir.
  static List<TabularPasteRow> parse(String text, {bool skipHeader = false}) {
    final lines = text
        .split(RegExp(r'\r\n|\r|\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return const [];

    final delimiter = _detectDelimiter(lines);
    final rows = <TabularPasteRow>[];

    for (var i = 0; i < lines.length; i++) {
      if (skipHeader && i == 0) continue;
      final cells = lines[i].split(delimiter).map((c) => c.trim()).toList();
      final description = cells.isNotEmpty ? cells[0] : '';
      if (description.isEmpty) continue;

      rows.add(
        TabularPasteRow(
          description: description,
          quantity: _cell(cells, 1, parseNumber) ?? 1,
          unit: cells.length > 2 && cells[2].isNotEmpty ? cells[2] : 'adet',
          unitPrice: _cell(cells, 3, parseNumber) ?? 0,
          discount: _cell(cells, 4, parseNumber) ?? 0,
        ),
      );
    }
    return rows;
  }

  /// Ilk satirin basliga benzeyip benzemedigini soyler: ikinci hucre sayi
  /// degilse buyuk ihtimalle "Miktar" gibi bir baslik metnidir.
  static bool looksLikeHeader(String text) {
    final lines = text
        .split(RegExp(r'\r\n|\r|\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return false;
    final cells = lines.first.split(_detectDelimiter(lines));
    if (cells.length < 2) return false;
    return parseNumber(cells[1]) == null;
  }

  static String _detectDelimiter(List<String> lines) {
    for (final d in _delimiters) {
      if (lines.any((l) => l.contains(d))) return d;
    }
    return '\t';
  }

  static T? _cell<T>(List<String> cells, int index, T? Function(String) parse) {
    if (index >= cells.length) return null;
    return parse(cells[index]);
  }
}
