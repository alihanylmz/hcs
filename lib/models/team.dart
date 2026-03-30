enum TeamRole {
  owner,
  admin,
  member;

  String get label {
    switch (this) {
      case TeamRole.owner:
        return 'Sahip';
      case TeamRole.admin:
        return 'Yonetici';
      case TeamRole.member:
        return 'Uye';
    }
  }

  static TeamRole fromString(String val) {
    return TeamRole.values.firstWhere(
      (item) => item.name == val,
      orElse: () => TeamRole.member,
    );
  }
}

class Team {
  static const String defaultEmoji = '🚀';
  static const String defaultAccentColor = '#2563EB';
  static const List<String> emojiOptions = [
    '🚀',
    '🛠️',
    '📦',
    '⚙️',
    '🧠',
    '🎯',
    '📈',
    '💡',
    '🧩',
    '🌿',
    '🔥',
    '🧪',
  ];
  static const List<String> accentColorOptions = [
    '#2563EB',
    '#0F766E',
    '#059669',
    '#F59E0B',
    '#DC2626',
    '#DB2777',
    '#7C3AED',
    '#0891B2',
    '#374151',
    '#65A30D',
  ];

  final String id;
  final String name;
  final String? description;
  final String emoji;
  final String accentColor;
  final String createdBy;
  final DateTime createdAt;

  Team({
    required this.id,
    required this.name,
    this.description,
    this.emoji = defaultEmoji,
    this.accentColor = defaultAccentColor,
    required this.createdBy,
    required this.createdAt,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      emoji: normalizeEmoji(json['emoji']),
      accentColor: normalizeAccentColor(json['accent_color']),
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'emoji': emoji,
      'accent_color': accentColor,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static String normalizeEmoji(dynamic value) {
    final trimmed = value?.toString().trim();
    if (trimmed == null || trimmed.isEmpty) {
      return defaultEmoji;
    }
    return trimmed;
  }

  static String normalizeAccentColor(dynamic value) {
    final trimmed = value?.toString().trim().toUpperCase();
    final isValidHex = trimmed != null &&
        RegExp(r'^#[0-9A-F]{6}$').hasMatch(trimmed);
    if (!isValidHex) {
      return defaultAccentColor;
    }
    return trimmed;
  }
}
