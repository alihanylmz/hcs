import '../config/company_profile.dart';
import 'quote.dart';

class OwnCompany {
  const OwnCompany({
    required this.id,
    required this.name,
    required this.shortName,
    required this.tagline,
    required this.phone,
    required this.email,
    required this.website,
    required this.address,
    required this.taxOffice,
    required this.taxNumber,
    required this.mersis,
    required this.bankName,
    required this.bankBranch,
    required this.bankAccountName,
    required this.bankIban,
    required this.bankSwift,
    required this.defaultVatRate,
    required this.isDefault,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String shortName;
  final String tagline;
  final String phone;
  final String email;
  final String website;
  final String address;
  final String taxOffice;
  final String taxNumber;
  final String mersis;
  final String bankName;
  final String bankBranch;
  final String bankAccountName;
  final String bankIban;
  final String bankSwift;
  final double defaultVatRate;
  final bool isDefault;
  final DateTime updatedAt;

  String get menuLabel {
    if (shortName.trim().isNotEmpty) return shortName.trim();
    if (name.trim().isNotEmpty) return name.trim();
    return 'Firma';
  }

  QuoteDocumentProfile toDocumentProfile({
    required String preparedByName,
    required String preparedByTitle,
    required String preparedByPhone,
    required String preparedByEmail,
    required String customerContactTitle,
    required String customerPhone,
    required String customerEmail,
    required String validityText,
    required String paymentTerms,
    required String deliveryTerms,
    required double vatRate,
  }) {
    return QuoteDocumentProfile(
      companyName: _pick(name, CompanyProfile.name),
      companyTagline: _pick(tagline, CompanyProfile.tagline),
      companyPhone: _pick(phone, CompanyProfile.phone),
      companyEmail: _pick(email, CompanyProfile.email),
      companyWebsite: _pick(website, CompanyProfile.website),
      companyAddress: _pick(address, CompanyProfile.address),
      preparedByName: preparedByName,
      preparedByTitle: preparedByTitle,
      preparedByPhone: preparedByPhone,
      preparedByEmail: preparedByEmail,
      customerContactTitle: customerContactTitle,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      validityText: validityText,
      paymentTerms: paymentTerms,
      deliveryTerms: deliveryTerms,
      companyTaxOffice: _pick(taxOffice, CompanyProfile.taxOffice),
      companyTaxNumber: _pick(taxNumber, CompanyProfile.taxNumber),
      companyMersis: _pick(mersis, CompanyProfile.mersis),
      bankName: _pick(bankName, CompanyProfile.bankName),
      bankBranch: _pick(bankBranch, CompanyProfile.bankBranch),
      bankAccountName: _pick(bankAccountName, CompanyProfile.bankAccountName),
      bankIban: _pick(bankIban, CompanyProfile.bankIban),
      bankSwift: _pick(bankSwift, CompanyProfile.bankSwift),
      vatRate: vatRate,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'short_name': shortName,
    'tagline': tagline,
    'phone': phone,
    'email': email,
    'website': website,
    'address': address,
    'tax_office': taxOffice,
    'tax_number': taxNumber,
    'mersis': mersis,
    'bank_name': bankName,
    'bank_branch': bankBranch,
    'bank_account_name': bankAccountName,
    'bank_iban': bankIban,
    'bank_swift': bankSwift,
    'default_vat_rate': defaultVatRate,
    'is_default': isDefault,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory OwnCompany.fromJson(Map<String, dynamic> json) {
    return OwnCompany(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      shortName: (json['short_name'] as String?)?.trim() ?? '',
      tagline: (json['tagline'] as String?)?.trim() ?? '',
      phone: (json['phone'] as String?)?.trim() ?? '',
      email: (json['email'] as String?)?.trim() ?? '',
      website: (json['website'] as String?)?.trim() ?? '',
      address: (json['address'] as String?)?.trim() ?? '',
      taxOffice: (json['tax_office'] as String?)?.trim() ?? '',
      taxNumber: (json['tax_number'] as String?)?.trim() ?? '',
      mersis: (json['mersis'] as String?)?.trim() ?? '',
      bankName: (json['bank_name'] as String?)?.trim() ?? '',
      bankBranch: (json['bank_branch'] as String?)?.trim() ?? '',
      bankAccountName: (json['bank_account_name'] as String?)?.trim() ?? '',
      bankIban: (json['bank_iban'] as String?)?.trim() ?? '',
      bankSwift: (json['bank_swift'] as String?)?.trim() ?? '',
      defaultVatRate:
          (json['default_vat_rate'] as num?)?.toDouble() ??
          CompanyProfile.defaultVatRate,
      isDefault: json['is_default'] as bool? ?? false,
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static OwnCompany fallback() => OwnCompany(
    id: 'default-company',
    name: CompanyProfile.name,
    shortName: CompanyProfile.shortName,
    tagline: CompanyProfile.tagline,
    phone: CompanyProfile.phone,
    email: CompanyProfile.email,
    website: CompanyProfile.website,
    address: CompanyProfile.address,
    taxOffice: CompanyProfile.taxOffice,
    taxNumber: CompanyProfile.taxNumber,
    mersis: CompanyProfile.mersis,
    bankName: CompanyProfile.bankName,
    bankBranch: CompanyProfile.bankBranch,
    bankAccountName: CompanyProfile.bankAccountName,
    bankIban: CompanyProfile.bankIban,
    bankSwift: CompanyProfile.bankSwift,
    defaultVatRate: CompanyProfile.defaultVatRate,
    isDefault: true,
    updatedAt: DateTime.now(),
  );

  static String _pick(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty ? trimmed : fallback;
  }
}
