enum CardEventType {
  cardCreated,
  statusChanged,
  assigneeChanged,
  updated,
  commented; // Gelecekte eklenebilir

  String get toDb {
    switch (this) {
      case CardEventType.cardCreated: return 'CARD_CREATED';
      case CardEventType.statusChanged: return 'STATUS_CHANGED';
      case CardEventType.assigneeChanged: return 'ASSIGNEE_CHANGED';
      case CardEventType.updated: return 'UPDATED';
      case CardEventType.commented: return 'COMMENTED';
    }
  }

  static CardEventType fromDb(String val) {
    switch (val) {
      case 'CARD_CREATED': return CardEventType.cardCreated;
      case 'STATUS_CHANGED': return CardEventType.statusChanged;
      case 'ASSIGNEE_CHANGED': return CardEventType.assigneeChanged;
      case 'UPDATED': return CardEventType.updated;
      case 'COMMENTED': return CardEventType.commented;
      default: return CardEventType.updated;
    }
  }
}

class CardEvent {
  final String id;
  final String cardId;
  final String userId;
  final CardEventType eventType;
  final String? fromStatus;
  final String? toStatus;
  final String? fromAssignee;
  final String? toAssignee;
  final DateTime createdAt;
  
  // Join ile gelen kullanıcı bilgisi için opsiyonel alan
  final String? userEmail;

  CardEvent({
    required this.id,
    required this.cardId,
    required this.userId,
    required this.eventType,
    this.fromStatus,
    this.toStatus,
    this.fromAssignee,
    this.toAssignee,
    required this.createdAt,
    this.userEmail,
  });

  factory CardEvent.fromJson(Map<String, dynamic> json) {
    return CardEvent(
      id: json['id'],
      cardId: json['card_id'],
      userId: json['user_id'],
      eventType: CardEventType.fromDb(json['event_type']),
      fromStatus: json['from_status'],
      toStatus: json['to_status'],
      fromAssignee: json['from_assignee'],
      toAssignee: json['to_assignee'],
      createdAt: DateTime.parse(json['created_at']),
      userEmail: json['profiles']?['email'], // Supabase join
    );
  }
}
