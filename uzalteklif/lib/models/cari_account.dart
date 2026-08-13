/// Cari kartina bagli yetkili kisi (iletisim kisi).
class CariContact {
  const CariContact({
    required this.name,
    this.title = '',
    this.phone = '',
    this.email = '',
    this.isPrimary = false,
  });

  final String name;
  final String title;
  final String phone;
  final String email;
  final bool isPrimary;

  CariContact copyWith({
    String? name,
    String? title,
    String? phone,
    String? email,
    bool? isPrimary,
  }) {
    return CariContact(
      name: name ?? this.name,
      title: title ?? this.title,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'title': title.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'is_primary': isPrimary,
      };

  factory CariContact.fromJson(Map<String, dynamic> json) {
    return CariContact(
      name: (json['name'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      phone: (json['phone'] as String? ?? '').trim(),
      email: (json['email'] as String? ?? '').trim(),
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}

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
    this.contacts = const [],
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
  final List<CariContact> contacts;

  /// Ana yetkiliyi veya ilk yetkiliyi getirir.
  CariContact? get primaryContact {
    if (contacts.isEmpty) {
      final name = contactName.trim();
      if (name.isEmpty && phone.isEmpty && email.isEmpty) return null;
      return CariContact(
        name: name,
        title: contactTitle,
        phone: phone,
        email: email,
        isPrimary: true,
      );
    }
    return contacts.firstWhere(
      (c) => c.isPrimary,
      orElse: () => contacts.first,
    );
  }

  /// Menu ve listelerdeki baslik etiketi.
  String get menuLabel {
    final company = companyName.trim();
    final contact = (primaryContact?.name ?? contactName).trim();
    if (company.isEmpty && contact.isEmpty) return '(Adsiz)';
    if (contact.isEmpty) return company;
    if (company.isEmpty) return contact;
    return '$company — $contact';
  }

  static String _normalize(String input) {
    return input
        .trim()
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .replaceAll('ı', 'i');
  }

  /// Belirli bir isimde yetkili var mi kontrol eder (case-insensitive).
  bool hasContact(String name) {
    final clean = _normalize(name);
    if (clean.isEmpty) return false;
    return contacts.any((c) => _normalize(c.name) == clean) ||
        _normalize(contactName) == clean;
  }

  CariAccount copyWith({
    String? id,
    String? companyName,
    String? contactName,
    String? contactTitle,
    String? phone,
    String? email,
    String? taxOffice,
    String? taxNumber,
    String? address,
    String? notes,
    DateTime? updatedAt,
    String? createdBy,
    List<CariContact>? contacts,
  }) {
    return CariAccount(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      contactName: contactName ?? this.contactName,
      contactTitle: contactTitle ?? this.contactTitle,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      taxOffice: taxOffice ?? this.taxOffice,
      taxNumber: taxNumber ?? this.taxNumber,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      contacts: contacts ?? this.contacts,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_name': companyName,
        'contact_name': primaryContact?.name ?? contactName,
        'contact_title': primaryContact?.title ?? contactTitle,
        'phone': primaryContact?.phone ?? phone,
        'email': primaryContact?.email ?? email,
        'tax_office': taxOffice,
        'tax_number': taxNumber,
        'address': address,
        'notes': notes,
        'updated_at': updatedAt.toIso8601String(),
        'created_by': createdBy,
        'contacts': contacts.map((c) => c.toJson()).toList(),
      };

  factory CariAccount.fromJson(Map<String, dynamic> json) {
    final rawContacts = json['contacts'] as List<dynamic>? ?? const [];
    List<CariContact> parsedContacts = rawContacts
        .cast<Map<String, dynamic>>()
        .map(CariContact.fromJson)
        .toList();

    final legacyContactName = (json['contact_name'] as String?)?.trim() ?? '';
    final legacyContactTitle = (json['contact_title'] as String?)?.trim() ?? '';
    final legacyPhone = (json['phone'] as String?)?.trim() ?? '';
    final legacyEmail = (json['email'] as String?)?.trim() ?? '';

    if (parsedContacts.isEmpty &&
        (legacyContactName.isNotEmpty ||
            legacyPhone.isNotEmpty ||
            legacyEmail.isNotEmpty)) {
      parsedContacts = [
        CariContact(
          name: legacyContactName,
          title: legacyContactTitle,
          phone: legacyPhone,
          email: legacyEmail,
          isPrimary: true,
        ),
      ];
    }

    final mainContact = parsedContacts.firstWhere(
      (c) => c.isPrimary,
      orElse: () => parsedContacts.isNotEmpty
          ? parsedContacts.first
          : CariContact(
              name: legacyContactName,
              title: legacyContactTitle,
              phone: legacyPhone,
              email: legacyEmail,
              isPrimary: true,
            ),
    );

    return CariAccount(
      id: json['id'] as String? ?? '',
      companyName: (json['company_name'] as String?)?.trim() ?? '',
      contactName: mainContact.name,
      contactTitle: mainContact.title,
      phone: mainContact.phone,
      email: mainContact.email,
      taxOffice: (json['tax_office'] as String?)?.trim() ?? '',
      taxNumber: (json['tax_number'] as String?)?.trim() ?? '',
      address: (json['address'] as String?)?.trim() ?? '',
      notes: (json['notes'] as String?)?.trim() ?? '',
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: (json['created_by'] as String?)?.trim(),
      contacts: parsedContacts,
    );
  }
}
