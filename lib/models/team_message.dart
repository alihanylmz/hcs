enum TeamMessageType {
  message,
  system;

  String get dbValue => name;

  static TeamMessageType fromString(String value) {
    return TeamMessageType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => TeamMessageType.message,
    );
  }
}

class TeamMessage {
  const TeamMessage({
    required this.id,
    required this.threadId,
    required this.teamId,
    required this.userId,
    required this.body,
    required this.type,
    required this.createdAt,
    this.replyToId,
    this.attachmentUrl,
    this.authorName,
    this.mentionedUserIds = const [],
  });

  final String id;
  final String threadId;
  final String teamId;
  final String userId;
  final String body;
  final TeamMessageType type;
  final DateTime createdAt;
  final String? replyToId;
  final String? attachmentUrl;
  final String? authorName;
  final List<String> mentionedUserIds;

  bool isAuthoredBy(String? userId) => userId != null && this.userId == userId;

  factory TeamMessage.fromJson(Map<String, dynamic> json) {
    return TeamMessage(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      teamId: json['team_id'] as String,
      userId: json['user_id'] as String,
      body: json['body'] as String? ?? '',
      type: TeamMessageType.fromString(
        json['message_type'] as String? ?? 'message',
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      replyToId: json['reply_to_id'] as String?,
      attachmentUrl: json['attachment_url'] as String?,
      authorName: json['author_name'] as String?,
      mentionedUserIds:
          (json['mentioned_user_ids'] as List?)
              ?.map((item) => item.toString())
              .toList() ??
          const [],
    );
  }
}
