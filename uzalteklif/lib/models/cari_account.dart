/// Hizli teklif musterisi (cari karti).
class CariAccount {
  const CariAccount({
    required this.id,
    required this.companyName,
    required this.contactName,
    required this.contactTitle,
    required this.phone,
    required this.email,
    required this.taxOffice,
    required this.taxNumber,
    required this.address,
    required this.notes,
    required this.updatedAt,
    this.createdBy,
  });

  final String id;
  final String companyName;
  final String contactName;
  final String contactTitle;
  final String phone;
  final String email;
  final String taxOffice;
  final String taxNumber;
  final String address;
  final String notes;
  final DateTime updatedAt;
  final String? createdBy;

  String get menuLabel {
    final company = companyName.trim();
    final contact = contactName.trim();
    if (company.isEmpty && contact.isEmpty) return '(Adsiz)';
    if (contact.isEmpty) return company;
    if (company.isEmpty) return contact;
    return '$company — $contact';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_name': companyName,
        'contact_name': contactName,
        'contact_title': contactTitle,
        'phone': phone,
        'email': email,
        'tax_office': taxOffice,
        'tax_number': taxNumber,
        'address': address,
        'notes': notes,
        'updated_at': updatedAt.toIso8601String(),
        'created_by': createdBy,
      };

  factory CariAccount.fromJson(Map<String, dynamic> json) {
    return CariAccount(
      id: json['id'] as String? ?? '',
      companyName: (json['company_name'] as String?)?.trim() ?? '',
      contactName: (json['contact_name'] as String?)?.trim() ?? '',
      contactTitle: (json['contact_title'] as String?)?.trim() ?? '',
      phone: (json['phone'] as String?)?.trim() ?? '',
      email: (json['email'] as String?)?.trim() ?? '',
      taxOffice: (json['tax_office'] as String?)?.trim() ?? '',
      taxNumber: (json['tax_number'] as String?)?.trim() ?? '',
      address: (json['address'] as String?)?.trim() ?? '',
      notes: (json['notes'] as String?)?.trim() ?? '',
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: (json['created_by'] as String?)?.trim(),
    );
  }
}
