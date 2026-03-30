enum TeamThreadType {
  general,
  card,
  ticket,
  announcement;

  String get dbValue => name;

  String get label {
    switch (this) {
      case TeamThreadType.general:
        return 'Genel';
      case TeamThreadType.card:
        return 'Kart';
      case TeamThreadType.ticket:
        return 'Is Emri';
      case TeamThreadType.announcement:
        return 'Duyuru';
    }
  }

  static TeamThreadType fromString(String value) {
    return TeamThreadType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => TeamThreadType.general,
    );
  }
}

class TeamThread {
  const TeamThread({
    required this.id,
    required this.teamId,
    required this.type,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessageAt,
    this.cardId,
    this.ticketId,
    this.lastMessagePreview,
    this.lastMessageAuthor,
    this.unreadCount = 0,
    this.mentionCount = 0,
  });

  final String id;
  final String teamId;
  final TeamThreadType type;
  final String title;
  final String? description;
  final String? cardId;
  final String? ticketId;
  final String createdBy;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageAuthor;
  final int unreadCount;
  final int mentionCount;

  bool get hasUnread => unreadCount > 0;
  bool get hasMentions => mentionCount > 0;

  factory TeamThread.fromJson(Map<String, dynamic> json) {
    return TeamThread(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      type: TeamThreadType.fromString(json['type'] as String? ?? 'general'),
      title: json['title'] as String? ?? 'Basliksiz',
      description: json['description'] as String?,
      cardId: json['card_id'] as String?,
      ticketId: json['ticket_id']?.toString(),
      createdBy: json['created_by'] as String,
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastMessageAt:
          DateTime.tryParse(json['last_message_at'] as String? ?? '') ??
          DateTime.parse(json['created_at'] as String),
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageAuthor: json['last_message_author'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      mentionCount: (json['mention_count'] as num?)?.toInt() ?? 0,
    );
  }

  TeamThread copyWith({
    String? title,
    String? description,
    String? lastMessagePreview,
    String? lastMessageAuthor,
    int? unreadCount,
    int? mentionCount,
    DateTime? lastMessageAt,
  }) {
    return TeamThread(
      id: id,
      teamId: teamId,
      type: type,
      title: title ?? this.title,
      description: description ?? this.description,
      cardId: cardId,
      ticketId: ticketId,
      createdBy: createdBy,
      isPinned: isPinned,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      lastMessageAuthor: lastMessageAuthor ?? this.lastMessageAuthor,
      unreadCount: unreadCount ?? this.unreadCount,
      mentionCount: mentionCount ?? this.mentionCount,
    );
  }
}

class TeamConversationTotals {
  const TeamConversationTotals({
    required this.unreadCount,
    required this.mentionCount,
  });

  final int unreadCount;
  final int mentionCount;
}
