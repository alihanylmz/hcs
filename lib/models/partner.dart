class Partner {
  final int id;
  final String name;
  final String? contactInfo;
  final String? logoUrl;

  Partner({
    required this.id,
    required this.name,
    this.contactInfo,
    this.logoUrl,
  });

  factory Partner.fromJson(Map<String, dynamic> json) {
    return Partner(
      id: json['id'] as int,
      name: json['name'] as String,
      contactInfo: json['contact_info'] as String?,
      logoUrl: json['logo_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contact_info': contactInfo,
      'logo_url': logoUrl,
    };
  }
}

