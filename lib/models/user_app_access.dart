class UserAppAccess {
  const UserAppAccess({
    required this.userId,
    required this.appCode,
    required this.appRole,
    required this.isActive,
    this.grantedAt,
    this.updatedAt,
  });

  final String userId;
  final String appCode;
  final String appRole;
  final bool isActive;
  final DateTime? grantedAt;
  final DateTime? updatedAt;

  factory UserAppAccess.fromJson(Map<String, dynamic> json) {
    return UserAppAccess(
      userId: json['user_id']?.toString() ?? '',
      appCode: json['app_code']?.toString() ?? '',
      appRole: json['app_role']?.toString() ?? 'user',
      isActive: json['is_active'] == true,
      grantedAt: DateTime.tryParse(json['granted_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }
}

class UserAccessDraft {
  const UserAccessDraft({
    required this.businessRole,
    required this.isTakipActive,
    required this.isTakipRole,
    required this.teklifActive,
    required this.teklifRole,
    this.partnerId,
  });

  final String businessRole;
  final bool isTakipActive;
  final String isTakipRole;
  final bool teklifActive;
  final String teklifRole;
  final int? partnerId;
}

class AppRoleDefinition {
  const AppRoleDefinition({
    required this.code,
    required this.label,
    required this.description,
    required this.permissions,
  });

  final String code;
  final String label;
  final String description;
  final List<String> permissions;
}

class BusinessRoleDefinition {
  const BusinessRoleDefinition({
    required this.code,
    required this.label,
    required this.department,
    required this.description,
    required this.isTakipActive,
    required this.isTakipRole,
    required this.teklifActive,
    required this.teklifRole,
    this.customerRole = false,
    this.restrictions = const [],
  });

  final String code;
  final String label;
  final String department;
  final String description;
  final bool isTakipActive;
  final String isTakipRole;
  final bool teklifActive;
  final String teklifRole;
  final bool customerRole;
  final List<String> restrictions;
}

class UserAccessCatalog {
  const UserAccessCatalog._();

  static const businessRoles = <BusinessRoleDefinition>[
    BusinessRoleDefinition(
      code: 'owner',
      label: 'Patron',
      department: 'Üst Yönetim',
      description:
          'Tüm operasyon, teklif ve finansal verilere erişir; sistem ayarlarını değiştiremez.',
      isTakipActive: true,
      isTakipRole: 'manager',
      teklifActive: true,
      teklifRole: 'manager',
      restrictions: ['Kullanıcı ve rol yönetimi', 'Sistem ayarları'],
    ),
    BusinessRoleDefinition(
      code: 'general_manager',
      label: 'Genel Müdür',
      department: 'Üst Yönetim',
      description: 'Günlük operasyonu, satış ve teknik ekipleri yönetir.',
      isTakipActive: true,
      isTakipRole: 'admin',
      teklifActive: true,
      teklifRole: 'admin',
    ),
    BusinessRoleDefinition(
      code: 'sales_representative',
      label: 'Satış Personeli',
      department: 'Satış Departmanı',
      description:
          'Cari, keşif ve teklif süreçlerini yürütür; teknik süreci izler.',
      isTakipActive: true,
      isTakipRole: 'user',
      teklifActive: true,
      teklifRole: 'sales',
      restrictions: [
        'Patronların hazırladığı teklifler',
        'Kullanıcı ve sistem ayarları',
      ],
    ),
    BusinessRoleDefinition(
      code: 'technical_manager',
      label: 'Teknik Sorumlu / Mühendis',
      department: 'Teknik Departman',
      description: 'Teknik ekibi, iş emirlerini ve saha planlamasını yönetir.',
      isTakipActive: true,
      isTakipRole: 'engineer',
      teklifActive: true,
      teklifRole: 'operations',
      restrictions: ['Ticari yönetim', 'Kullanıcı ve sistem ayarları'],
    ),
    BusinessRoleDefinition(
      code: 'technician',
      label: 'Teknisyen',
      department: 'Teknik Departman',
      description:
          'Kendisine atanan saha işlerini ve servis kayıtlarını yürütür.',
      isTakipActive: true,
      isTakipRole: 'technician',
      teklifActive: false,
      teklifRole: 'viewer',
      restrictions: ['Teklif ve finans', 'Kullanıcı ve sistem ayarları'],
    ),
    BusinessRoleDefinition(
      code: 'customer_admin',
      label: 'Müşteri Firma Yöneticisi',
      department: 'Müşteri Kullanıcısı',
      description:
          'Yalnızca bağlı firmasının servis kayıtlarını kurumsal kapsamda görür.',
      isTakipActive: true,
      isTakipRole: 'partner_user',
      teklifActive: false,
      teklifRole: 'operations',
      customerRole: true,
      restrictions: ['Diğer firmalar', 'İç operasyon ve finans'],
    ),
    BusinessRoleDefinition(
      code: 'customer_user',
      label: 'Müşteri Kullanıcısı',
      department: 'Müşteri Kullanıcısı',
      description: 'Bağlı firmasına ait izin verilen kayıtları görüntüler.',
      isTakipActive: true,
      isTakipRole: 'partner_user',
      teklifActive: false,
      teklifRole: 'viewer',
      customerRole: true,
      restrictions: ['Diğer firmalar', 'İç operasyon ve finans'],
    ),
  ];

  static const isTakipRoles = <AppRoleDefinition>[
    AppRoleDefinition(
      code: 'admin',
      label: 'Genel Müdür · Tam Yetki',
      description: 'Tüm modüller, şirket ayarları ve kullanıcı/yetki yönetimi.',
      permissions: [
        'Tüm iş emirleri',
        'Kullanıcılar',
        'Stok',
        'Sistem ayarları',
      ],
    ),
    AppRoleDefinition(
      code: 'manager',
      label: 'Patron · Operasyon Yetkisi',
      description:
          'Operasyonun tamamını yönetir; kullanıcı ve sistem ayarları hariç.',
      permissions: [
        'Tüm iş emirleri',
        'Raporlar',
        'Cari/partnerler',
        'Stok yönetimi',
      ],
    ),
    AppRoleDefinition(
      code: 'engineer',
      label: 'Teknik Yönetim',
      description: 'Teknik işleri, planlamayı ve saha ekibini yönetir.',
      permissions: [
        'İş oluşturma',
        'Teknik düzenleme',
        'Planlama',
        'Raporlama',
      ],
    ),
    AppRoleDefinition(
      code: 'technician',
      label: 'Saha Kullanımı',
      description: 'Atanan işleri yürütür, not, fotoğraf ve imza ekler.',
      permissions: ['Atanan işler', 'Servis notları', 'Fotoğraf', 'İmza'],
    ),
    AppRoleDefinition(
      code: 'user',
      label: 'Operasyon İzleme',
      description: 'İşleri ve temel raporları değişiklik yapmadan görüntüler.',
      permissions: ['İş listesi', 'Arşiv', 'Temel raporlar'],
    ),
    AppRoleDefinition(
      code: 'partner_user',
      label: 'Müşteri Firma Erişimi',
      description: 'Yalnızca bağlı olduğu firmanın servis kayıtlarına erişir.',
      permissions: ['Firma işleri', 'Servis belgeleri', 'Sınırlı raporlama'],
    ),
  ];

  static const teklifRoles = <AppRoleDefinition>[
    AppRoleDefinition(
      code: 'admin',
      label: 'Genel Müdür · Tam Yetki',
      description: 'Teklif uygulamasının tüm alanlarını ve ayarlarını yönetir.',
      permissions: [
        'Tüm teklifler',
        'Kullanıcılar',
        'Fiyat politikası',
        'Firma ayarları',
      ],
    ),
    AppRoleDefinition(
      code: 'manager',
      label: 'Patron · Ticari Yetki',
      description:
          'Teklif, cari ve ticari sonuçları yönetir; sistem ayarlarına erişemez.',
      permissions: [
        'Tüm teklifler',
        'Satış panosu',
        'Cari 360',
        'Fiyat ve raporlar',
      ],
    ),
    AppRoleDefinition(
      code: 'sales',
      label: 'Teklif Hazırlama',
      description: 'Teklif ve cari oluşturur, kendi satış sürecini yürütür.',
      permissions: ['Teklif oluşturma', 'Cari işlemleri', 'PDF/Excel çıktısı'],
    ),
    AppRoleDefinition(
      code: 'finance',
      label: 'Finans ve Fiyat',
      description: 'Fiyat, kur ve ticari sonuç alanlarını yönetir.',
      permissions: ['Fiyatlar', 'Kur bilgileri', 'Ticari raporlar'],
    ),
    AppRoleDefinition(
      code: 'operations',
      label: 'Keşif ve Teknik Hazırlık',
      description: 'Keşif, ürün ve operasyonel teklif hazırlığını yürütür.',
      permissions: ['Keşif', 'Ürünler', 'Operasyon verileri'],
    ),
    AppRoleDefinition(
      code: 'viewer',
      label: 'Salt Okunur',
      description: 'Teklif ve cari kayıtlarını değiştirmeden görüntüler.',
      permissions: ['Teklif görüntüleme', 'Cari görüntüleme'],
    ),
  ];

  static BusinessRoleDefinition businessRole(String code) {
    return businessRoles.firstWhere(
      (item) => item.code == code,
      orElse: () => businessRoles[4],
    );
  }

  static String inferBusinessRole({
    required String profileRole,
    required bool teklifActive,
    required String teklifRole,
  }) {
    if (profileRole == 'admin') return 'general_manager';
    if (profileRole == 'manager') return 'owner';
    if (profileRole == 'engineer') return 'technical_manager';
    if (profileRole == 'technician') return 'technician';
    if (profileRole == 'partner_user') {
      return teklifRole == 'operations' ? 'customer_admin' : 'customer_user';
    }
    if (teklifActive && teklifRole == 'sales') return 'sales_representative';
    return 'technician';
  }

  static AppRoleDefinition roleFor(String appCode, String role) {
    final roles = appCode == 'teklif' ? teklifRoles : isTakipRoles;
    return roles.firstWhere(
      (item) => item.code == role,
      orElse: () => roles.last,
    );
  }
}
