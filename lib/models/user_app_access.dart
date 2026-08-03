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
    required this.isTakipActive,
    required this.isTakipRole,
    required this.teklifActive,
    required this.teklifRole,
    this.partnerId,
  });

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

class UserAccessCatalog {
  const UserAccessCatalog._();

  static const isTakipRoles = <AppRoleDefinition>[
    AppRoleDefinition(
      code: 'admin',
      label: 'Sistem Yöneticisi',
      description: 'Tüm modüller, ayarlar ve kullanıcı yönetimi.',
      permissions: [
        'Tüm iş emirleri',
        'Kullanıcılar',
        'Stok',
        'Sistem ayarları',
      ],
    ),
    AppRoleDefinition(
      code: 'manager',
      label: 'Yönetici',
      description:
          'Operasyonun tamamını yönetir; kritik sistem ayarları hariç.',
      permissions: ['İş emirleri', 'Raporlar', 'Kullanıcılar', 'Stok yönetimi'],
    ),
    AppRoleDefinition(
      code: 'supervisor',
      label: 'Süpervizör',
      description: 'Saha işlerini, atamaları ve kapanışları yönetir.',
      permissions: ['İş planlama', 'Atama', 'PDF raporları', 'Stok işlemleri'],
    ),
    AppRoleDefinition(
      code: 'engineer',
      label: 'Mühendis',
      description: 'Teknik iş emirlerini oluşturur ve düzenler.',
      permissions: ['İş oluşturma', 'Teknik düzenleme', 'Raporlama'],
    ),
    AppRoleDefinition(
      code: 'technician',
      label: 'Teknisyen',
      description: 'Atanan işleri yürütür, not ve fotoğraf ekler.',
      permissions: ['Atanan işler', 'Servis notları', 'Fotoğraf', 'İmza'],
    ),
    AppRoleDefinition(
      code: 'user',
      label: 'Görüntüleyici',
      description: 'İşleri ve temel raporları salt okunur görüntüler.',
      permissions: ['İş listesi', 'Arşiv', 'Temel raporlar'],
    ),
    AppRoleDefinition(
      code: 'partner_user',
      label: 'Partner Kullanıcısı',
      description: 'Yalnızca bağlı olduğu partnerin işlerini görür.',
      permissions: ['Partner işleri', 'Partner notu', 'Sınırlı raporlama'],
    ),
  ];

  static const teklifRoles = <AppRoleDefinition>[
    AppRoleDefinition(
      code: 'admin',
      label: 'Teklif Yöneticisi',
      description: 'Teklif uygulamasının tüm alanlarını ve ayarlarını yönetir.',
      permissions: [
        'Tüm teklifler',
        'Kullanıcı rolleri',
        'Fiyat politikası',
        'Firma ayarları',
      ],
    ),
    AppRoleDefinition(
      code: 'manager',
      label: 'Satış Müdürü',
      description: 'Satış ekibini, teklifleri ve ticari sonuçları yönetir.',
      permissions: ['Tüm teklifler', 'Satış panosu', 'Cari 360', 'Raporlar'],
    ),
    AppRoleDefinition(
      code: 'sales',
      label: 'Satış',
      description: 'Teklif ve cari oluşturur, kendi satış sürecini yürütür.',
      permissions: ['Teklif oluşturma', 'Cari işlemleri', 'PDF/Excel çıktısı'],
    ),
    AppRoleDefinition(
      code: 'finance',
      label: 'Finans',
      description: 'Fiyat, kur ve ticari sonuç alanlarını yönetir.',
      permissions: ['Fiyatlar', 'Kur bilgileri', 'Ticari raporlar'],
    ),
    AppRoleDefinition(
      code: 'operations',
      label: 'Operasyon',
      description: 'Keşif, ürün ve operasyonel teklif hazırlığını yürütür.',
      permissions: ['Keşif', 'Ürünler', 'Operasyon verileri'],
    ),
    AppRoleDefinition(
      code: 'viewer',
      label: 'Görüntüleyici',
      description: 'Teklif ve cari kayıtlarını değiştirmeden görüntüler.',
      permissions: ['Teklif görüntüleme', 'Cari görüntüleme'],
    ),
  ];

  static AppRoleDefinition roleFor(String appCode, String role) {
    final roles = appCode == 'teklif' ? teklifRoles : isTakipRoles;
    return roles.firstWhere(
      (item) => item.code == role,
      orElse: () => roles.last,
    );
  }
}
