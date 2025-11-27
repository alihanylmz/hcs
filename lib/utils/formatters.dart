class Formatters {
  static String date(String? iso) {
    if (iso == null) return '-';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return '${parsed.day.toString().padLeft(2, '0')}.'
        '${parsed.month.toString().padLeft(2, '0')}.'
        '${parsed.year} ${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
  }

  static String safeText(dynamic value) {
    if (value == null) return '-';
    final str = value.toString();
    if (str.trim().isEmpty) return '-';
    return str;
  }
}

