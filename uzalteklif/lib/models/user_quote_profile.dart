/// Oturum acik kullanicinin teklif PDF'inde kullanilan firma + hazirlayan
/// bilgileri (Supabase `user_profiles`).
class UserQuoteProfile {
  const UserQuoteProfile({
    required this.userId,
    required this.preparedByName,
    required this.preparedByTitle,
    required this.preparedByPhone,
    required this.preparedByEmail,
    required this.companyName,
    required this.companyTagline,
    required this.companyPhone,
    required this.companyEmail,
    required this.companyWebsite,
    required this.companyAddress,
    required this.companyTaxOffice,
    required this.companyTaxNumber,
    required this.companyMersis,
    required this.bankName,
    required this.bankBranch,
    required this.bankAccountName,
    required this.bankIban,
    required this.bankSwift,
    required this.defaultValidityText,
    required this.defaultPaymentTerms,
    required this.defaultDeliveryTerms,
    required this.defaultVatRate,
    this.role = 'seller',
  });

  final String userId;

  /// Kurumsal yetki: admin, manager, sales, finance, operations, viewer.
  final String role;

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'admin' || role == 'manager';
  bool get canManageUsers => isAdmin;
  bool get canApproveQuotes => isManager || role == 'finance';
  final String preparedByName;
  final String preparedByTitle;
  final String preparedByPhone;
  final String preparedByEmail;
  final String companyName;
  final String companyTagline;
  final String companyPhone;
  final String companyEmail;
  final String companyWebsite;
  final String companyAddress;
  final String companyTaxOffice;
  final String companyTaxNumber;
  final String companyMersis;
  final String bankName;
  final String bankBranch;
  final String bankAccountName;
  final String bankIban;
  final String bankSwift;
  final String defaultValidityText;
  final String defaultPaymentTerms;
  final String defaultDeliveryTerms;
  final double defaultVatRate;

  Map<String, dynamic> toRow() => {
        'user_id': userId,
        'prepared_by_name': preparedByName,
        'prepared_by_title': preparedByTitle,
        'prepared_by_phone': preparedByPhone,
        'prepared_by_email': preparedByEmail,
        'company_name': companyName,
        'company_tagline': companyTagline,
        'company_phone': companyPhone,
        'company_email': companyEmail,
        'company_website': companyWebsite,
        'company_address': companyAddress,
        'company_tax_office': companyTaxOffice,
        'company_tax_number': companyTaxNumber,
        'company_mersis': companyMersis,
        'bank_name': bankName,
        'bank_branch': bankBranch,
        'bank_account_name': bankAccountName,
        'bank_iban': bankIban,
        'bank_swift': bankSwift,
        'default_validity_text': defaultValidityText,
        'default_payment_terms': defaultPaymentTerms,
        'default_delivery_terms': defaultDeliveryTerms,
        'default_vat_rate': defaultVatRate,
        'role': role,
      };

  factory UserQuoteProfile.fromRow(Map<String, dynamic> json) {
    return UserQuoteProfile(
      userId: json['user_id'] as String? ?? '',
      preparedByName: (json['prepared_by_name'] as String?)?.trim() ?? '',
      preparedByTitle: (json['prepared_by_title'] as String?)?.trim() ?? '',
      preparedByPhone: (json['prepared_by_phone'] as String?)?.trim() ?? '',
      preparedByEmail: (json['prepared_by_email'] as String?)?.trim() ?? '',
      companyName: (json['company_name'] as String?)?.trim() ?? '',
      companyTagline: (json['company_tagline'] as String?)?.trim() ?? '',
      companyPhone: (json['company_phone'] as String?)?.trim() ?? '',
      companyEmail: (json['company_email'] as String?)?.trim() ?? '',
      companyWebsite: (json['company_website'] as String?)?.trim() ?? '',
      companyAddress: (json['company_address'] as String?)?.trim() ?? '',
      companyTaxOffice: (json['company_tax_office'] as String?)?.trim() ?? '',
      companyTaxNumber: (json['company_tax_number'] as String?)?.trim() ?? '',
      companyMersis: (json['company_mersis'] as String?)?.trim() ?? '',
      bankName: (json['bank_name'] as String?)?.trim() ?? '',
      bankBranch: (json['bank_branch'] as String?)?.trim() ?? '',
      bankAccountName: (json['bank_account_name'] as String?)?.trim() ?? '',
      bankIban: (json['bank_iban'] as String?)?.trim() ?? '',
      bankSwift: (json['bank_swift'] as String?)?.trim() ?? '',
      defaultValidityText:
          (json['default_validity_text'] as String?)?.trim() ?? '',
      defaultPaymentTerms:
          (json['default_payment_terms'] as String?)?.trim() ?? '',
      defaultDeliveryTerms:
          (json['default_delivery_terms'] as String?)?.trim() ?? '',
      defaultVatRate: (json['default_vat_rate'] as num?)?.toDouble() ?? 20,
      role: normalizeRole(json['role'] as String?),
    );
  }

  static String normalizeRole(String? raw) {
    switch ((raw ?? '').trim()) {
      case 'admin':
        return 'admin';
      case 'manager':
        return 'manager';
      case 'finance':
      case 'accountant':
        return 'finance';
      case 'operations':
        return 'operations';
      case 'viewer':
        return 'viewer';
      case 'sales':
      case 'sales_engineer':
      case 'mechatronics_engineer':
      case 'electrical_electronics_engineer':
      case 'seller':
      default:
        return 'sales';
    }
  }

  static String roleLabel(String role) {
    switch (normalizeRole(role)) {
      case 'admin':
        return 'Sistem Yöneticisi';
      case 'manager':
        return 'Yönetici';
      case 'finance':
        return 'Finans';
      case 'operations':
        return 'Operasyon';
      case 'viewer':
        return 'Görüntüleyici';
      default:
        return 'Satış';
    }
  }
}
