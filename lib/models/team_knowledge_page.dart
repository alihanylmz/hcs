class TeamKnowledgePage {
  final String id;
  final String teamId;
  final String title;
  final String summary;
  final String icon;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TeamKnowledgePage({
    required this.id,
    required this.teamId,
    required this.title,
    required this.summary,
    required this.icon,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeamKnowledgePage.fromJson(Map<String, dynamic> json) {
    return TeamKnowledgePage(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      title: (json['title'] as String?) ?? '',
      summary: (json['summary'] as String?) ?? '',
      icon: (json['icon'] as String?) ?? 'DOC',
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  TeamKnowledgePage copyWith({
    String? id,
    String? teamId,
    String? title,
    String? summary,
    String? icon,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TeamKnowledgePage(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      icon: icon ?? this.icon,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
