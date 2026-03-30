enum CardStatus {
  todo,
  doing,
  done,
  sent;

  String get label {
    switch (this) {
      case CardStatus.todo:
        return 'YAPILACAK';
      case CardStatus.doing:
        return 'YAPILIYOR';
      case CardStatus.done:
        return 'BITTI';
      case CardStatus.sent:
        return 'GONDERILDI';
    }
  }

  String get toDb => name.toUpperCase();

  static CardStatus fromDb(String value) {
    return CardStatus.values.firstWhere(
      (item) => item.name.toUpperCase() == value.toUpperCase(),
      orElse: () => CardStatus.todo,
    );
  }
}

enum CardPriority {
  low,
  normal,
  high;

  String get dbValue => name;

  String get label {
    switch (this) {
      case CardPriority.low:
        return 'Dusuk';
      case CardPriority.normal:
        return 'Normal';
      case CardPriority.high:
        return 'Yuksek';
    }
  }

  static CardPriority fromDb(String? value) {
    return CardPriority.values.firstWhere(
      (item) => item.name == value,
      orElse: () => CardPriority.normal,
    );
  }
}

class KanbanCard {
  final String id;
  final String boardId;
  final String teamId;
  final String title;
  final String? description;
  final CardStatus status;
  final String createdBy;
  final String? assigneeId;
  final String? assigneeName;
  final String? linkedTicketId;
  final String? linkedJobCode;
  final String? linkedTicketTitle;
  final CardPriority priority;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  KanbanCard({
    required this.id,
    required this.boardId,
    required this.teamId,
    required this.title,
    this.description,
    required this.status,
    required this.createdBy,
    this.assigneeId,
    this.assigneeName,
    this.linkedTicketId,
    this.linkedJobCode,
    this.linkedTicketTitle,
    this.priority = CardPriority.normal,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KanbanCard.fromJson(Map<String, dynamic> json) {
    String? name;
    final profiles = json['profiles'];
    if (profiles is Map<String, dynamic>) {
      name =
          (profiles['full_name'] as String?)?.trim().isNotEmpty == true
              ? (profiles['full_name'] as String).trim()
              : (profiles['email'] as String?)?.trim();
    }

    return KanbanCard(
      id: json['id'],
      boardId: json['board_id'],
      teamId: json['team_id'],
      title: json['title'],
      description: json['description'],
      status: CardStatus.fromDb(json['status']),
      createdBy: json['created_by'],
      assigneeId: json['assignee_id'],
      assigneeName: name,
      linkedTicketId: json['linked_ticket_id']?.toString(),
      linkedJobCode:
          (json['linked_ticket'] as Map<String, dynamic>?)?['job_code']
              ?.toString(),
      linkedTicketTitle:
          (json['linked_ticket'] as Map<String, dynamic>?)?['title']
              ?.toString(),
      priority: CardPriority.fromDb(json['priority'] as String?),
      dueDate:
          (json['due_date'] as String?)?.isNotEmpty == true
              ? DateTime.tryParse(json['due_date'] as String)
              : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'board_id': boardId,
      'team_id': teamId,
      'title': title,
      'description': description,
      'status': status.toDb,
      'created_by': createdBy,
      'assignee_id': assigneeId,
      'linked_ticket_id': linkedTicketId,
      'priority': priority.dbValue,
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
