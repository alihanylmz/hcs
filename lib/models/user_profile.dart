class UserProfile {
  final String id;
  final String? email;
  final String? fullName;
  final String role; // 'admin', 'technician', 'manager', 'partner_user'
  final DateTime? createdAt;
  final int? partnerId; // Partner ID (Eğer partner kullanıcısıysa)

  UserProfile({
    required this.id,
    this.email,
    this.fullName,
    this.role = 'pending', // Varsayılan rol: onay bekliyor
    this.createdAt,
    this.partnerId,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      role: json['role'] as String? ?? 'pending',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      partnerId: json['partner_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'partner_id': partnerId,
      // created_at genellikle güncellenmez
    };
  }

  // Yardımcı metodlar
  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager' || role == 'admin';
  bool get isPartner => role == 'partner_user';

  String get displayName => fullName ?? email ?? 'Bilinmeyen Kullanıcı';

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    DateTime? createdAt,
    int? partnerId,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      partnerId: partnerId ?? this.partnerId,
    );
  }
}

