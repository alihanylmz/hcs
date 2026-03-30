class InverterReferenceValue {
  const InverterReferenceValue({
    required this.id,
    required this.deviceBrand,
    required this.deviceModel,
    required this.title,
    required this.registerAddress,
    required this.storedValue,
    required this.unit,
    required this.category,
    required this.note,
    required this.sortOrder,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String deviceBrand;
  final String deviceModel;
  final String title;
  final String registerAddress;
  final String storedValue;
  final String unit;
  final String category;
  final String note;
  final int sortOrder;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get hasRegisterAddress => registerAddress.trim().isNotEmpty;
  bool get hasStoredValue => storedValue.trim().isNotEmpty;
  bool get hasUnit => unit.trim().isNotEmpty;
  bool get hasNote => note.trim().isNotEmpty;

  String get displayValue {
    final value = storedValue.trim();
    final normalizedUnit = unit.trim();
    if (value.isEmpty) return '-';
    if (normalizedUnit.isEmpty) return value;
    return '$value $normalizedUnit';
  }

  factory InverterReferenceValue.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) {
      final raw = value?.toString().trim() ?? '';
      if (raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    return InverterReferenceValue(
      id: (json['id'] as num?)?.toInt() ?? 0,
      deviceBrand: json['device_brand']?.toString() ?? '',
      deviceModel: json['device_model']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      registerAddress: json['register_address']?.toString() ?? '',
      storedValue: json['stored_value']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      note: json['note']?.toString() ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdBy: json['created_by']?.toString(),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }
}
