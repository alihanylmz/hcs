class QuickParameter {
  final int id;
  final String deviceBrand;
  final String deviceModel;
  final String parameterCode;
  final String parameterName;
  final String? defaultValue;
  final String? description;

  QuickParameter({
    required this.id,
    required this.deviceBrand,
    required this.deviceModel,
    required this.parameterCode,
    required this.parameterName,
    this.defaultValue,
    this.description,
  });

  factory QuickParameter.fromJson(Map<String, dynamic> json) {
    return QuickParameter(
      id: json['id'] ?? 0,
      deviceBrand: json['device_brand']?.toString() ?? '',
      deviceModel: json['device_model']?.toString() ?? '',
      parameterCode: json['parameter_code']?.toString() ?? '',
      parameterName: json['parameter_name']?.toString() ?? '',
      defaultValue: json['default_value']?.toString(),
      description: json['description']?.toString(),
    );
  }
}
