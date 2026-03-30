import '../models/team.dart';

class TeamMember {
  final String id;
  final String teamId;
  final String userId;
  final TeamRole role;
  final DateTime joinedAt;
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
    Map<String, dynamic>? profile;
    if (json.containsKey('profiles')) {
      final rawProfile = json['profiles'];
      if (rawProfile is Map<String, dynamic>) {
        profile = rawProfile;
      }
    }

    return TeamMember(
      id: json['id'],
      teamId: json['team_id'],
      userId: json['user_id'],
      role: TeamRole.fromString(json['role']),
      joinedAt: DateTime.parse(json['joined_at']),
      email: profile?['email'] as String?,
      fullName: profile?['full_name'] as String?,
    );
  }

  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty)
      return fullName!.trim();
    if (email != null && email!.trim().isNotEmpty) return email!.trim();
    return 'Kullanici';
  }
}
