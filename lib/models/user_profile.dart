class UserProfile {
  final String id;
  final String? email;
  final String? fullName;
  final String role; // 'admin', 'technician', 'manager'
  final DateTime? createdAt;

  UserProfile({
    required this.id,
    this.email,
    this.fullName,
    this.role = 'pending', // Varsayılan rol: onay bekliyor
    this.createdAt,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      // created_at genellikle güncellenmez
    };
  }

  // Yardımcı metodlar
  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager' || role == 'admin';

  String get displayName => fullName ?? email ?? 'Bilinmeyen Kullanıcı';

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

