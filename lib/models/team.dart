enum TeamRole {
  owner,
  admin,
  member;

  String get label {
    switch (this) {
      case TeamRole.owner: return 'Sahip';
      case TeamRole.admin: return 'Yönetici';
      case TeamRole.member: return 'Üye';
    }
  }

  static TeamRole fromString(String val) {
    return TeamRole.values.firstWhere(
      (e) => e.name == val,
      orElse: () => TeamRole.member,
    );
  }
}

class Team {
  final String id;
  final String name;
  final String? description;
  final String createdBy;
  final DateTime createdAt;

  Team({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    required this.createdAt,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
