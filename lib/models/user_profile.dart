// MODELS/user_profile.dart

// Burada UserService import YOK, bağımlılık tersine dönmüyor. 🔥

/// Rol tanımlarını model ile birlikte tutmak en temiz çözüm.
class UserRole {
  static const String admin = 'admin';
  static const String manager = 'manager';
  static const String technician = 'technician';
  static const String supervisor = 'supervisor';
  static const String pending = 'pending';
  static const String partnerUser = 'partner_user';
}

class UserProfile {
  final String id;
  final String? email;
  final String? fullName;
  final String role;
  final DateTime? createdAt;
  final int? partnerId;
  final String? signatureData; // <--- Eklendi

  const UserProfile({
    required this.id,
    this.email,
    this.fullName,
    this.role = UserRole.pending,
    this.createdAt,
    this.partnerId,
    this.signatureData, // <--- Eklendi
  });

  // ---- Yardımcı statik parser fonksiyonları ----

  static String _validateRole(String? role) {
    const validRoles = {
      UserRole.admin,
      UserRole.manager,
      UserRole.technician,
      UserRole.supervisor,
      UserRole.pending,
      UserRole.partnerUser,
    };

    if (role != null && validRoles.contains(role)) {
      return role;
    }

    // Burada istersen dart:developer.log kullanabilirsin
    // developer.log("Geçersiz rol '$role', pending atanıyor", name: "UserProfile");
    return UserRole.pending;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static int? _parsePartnerId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    return int.tryParse(value.toString());
  }

  // ---- JSON Dönüşümleri ----

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String?,
      role: _validateRole(json['role'] as String?),
      createdAt: _parseDate(json['created_at']),
      partnerId: _parsePartnerId(json['partner_id']),
      signatureData: json['signature_data'] as String?, // <--- Eklendi
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'partner_id': partnerId,
      'signature_data': signatureData, // <--- Eklendi
    };
  }

  // ---- Yetki Getter'ları ----

  bool get isAdmin => role == UserRole.admin;

  bool get isManager =>
      role == UserRole.manager || role == UserRole.admin;

  bool get isTechnician => role == UserRole.technician;

  bool get isSupervisor => role == UserRole.supervisor;

  bool get isPending => role == UserRole.pending;

  bool get isPartnerUser => role == UserRole.partnerUser;

  bool get hasCompany => partnerId != null;

  /// Gösterilecek isim:
  /// 1) fullName doluysa → onu kullan
  /// 2) değilse email
  /// 3) o da yoksa id
  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!.trim();
    }
    if (email != null && email!.trim().isNotEmpty) {
      return email!.trim();
    }
    return id;
  }

  // ---- CopyWith ----

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    DateTime? createdAt,
    int? partnerId,
    String? signatureData, // <--- Eklendi
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      partnerId: partnerId ?? this.partnerId,
      signatureData: signatureData ?? this.signatureData, // <--- Eklendi
    );
  }

  // ---- Debug & Equality ----

  @override
  String toString() {
    return 'UserProfile(id: $id, fullName: $fullName, role: $role, partnerId: $partnerId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserProfile &&
        other.id == id &&
        other.email == email &&
        other.fullName == fullName &&
        other.role == role &&
        other.partnerId == partnerId;
    // İstersen createdAt'i de buraya dahil edebilirsin;
    // ben genelde identity + business fields ile sınırlarım.
  }

  @override
  int get hashCode =>
      id.hashCode ^
      (email?.hashCode ?? 0) ^
      (fullName?.hashCode ?? 0) ^
      role.hashCode ^
      (partnerId ?? 0).hashCode;
}
