import 'package:intl/intl.dart';

class MarketRate {
  const MarketRate({
    required this.code,
    required this.label,
    required this.unitLabel,
    required this.value,
    required this.updatedAt,
    this.isFallback = false,
  });

  final String code;
  final String label;
  final String unitLabel;
  final double value;
  final DateTime updatedAt;
  final bool isFallback;

  String get formattedValue {
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: 'TL ',
      decimalDigits: value >= 100 ? 2 : 4,
    );
    return formatter.format(value);
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'label': label,
    'unit_label': unitLabel,
    'value': value,
    'updated_at': updatedAt.toIso8601String(),
    'is_fallback': isFallback,
  };

  factory MarketRate.fromJson(Map<String, dynamic> json) {
    return MarketRate(
      code: json['code'] as String,
      label: json['label'] as String,
      unitLabel: json['unit_label'] as String,
      value: (json['value'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isFallback: json['is_fallback'] as bool? ?? false,
    );
  }
}
