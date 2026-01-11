class CommissioningStep {
  final int id;
  final String deviceBrand;
  final String deviceModel;
  final int stepNumber;
  final String title;
  final String? description;

  CommissioningStep({
    required this.id,
    required this.deviceBrand,
    required this.deviceModel,
    required this.stepNumber,
    required this.title,
    this.description,
  });

  factory CommissioningStep.fromJson(Map<String, dynamic> json) {
    return CommissioningStep(
      id: json['id'] ?? 0,
      deviceBrand: json['device_brand']?.toString() ?? '',
      deviceModel: json['device_model']?.toString() ?? '',
      stepNumber: json['step_number'] ?? 0,
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}

