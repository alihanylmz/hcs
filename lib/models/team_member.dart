import '../models/team.dart';

class TeamMember {
  final String id; // team_members tablosundaki ID
  final String teamId;
  final String userId;
  final TeamRole role;
  final DateTime joinedAt;
  
  // Profil bilgileri (Join ile gelecek)
  final String? email;
  final String? fullName;

  TeamMember({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.email,
    this.fullName,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    // Supabase join sonucu: json['profiles'] içinde kullanıcı detayları olabilir
    // Veya view kullanılıyorsa direkt root'ta olabilir.
    
    // Gelen veri yapısına göre profili ayıkla
    Map<String, dynamic>? profile;
    if (json.containsKey('profiles')) {
      profile = json['profiles'];
    }
    
    return TeamMember(
      id: json['id'],
      teamId: json['team_id'],
      userId: json['user_id'],
      role: TeamRole.fromString(json['role']),
      joinedAt: DateTime.parse(json['joined_at']),
      email: profile?['email'], 
      fullName: profile?['full_name'],
    );
  }
  
  String get displayName {
    if (fullName != null && fullName!.isNotEmpty) return fullName!;
    if (email != null && email!.isNotEmpty) return email!;
    
    // Eğer isim yoksa, geçici olarak bir fallback gösterelim
    // Bu kısım normalde çalışmamalı çünkü fix_names.sql çalıştırılacak
    return 'Kullanıcı';
  }
}
