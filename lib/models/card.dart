enum CardStatus {
  todo,
  doing,
  done,
  sent;

  String get label {
    switch (this) {
      case CardStatus.todo: return 'YAPILACAK';
      case CardStatus.doing: return 'YAPILIYOR';
      case CardStatus.done: return 'BİTTİ';
      case CardStatus.sent: return 'GÖNDERİLDİ';
    }
  }
  
  // Veritabanındaki enum değerleriyle eşleşme (büyük harf)
  String get toDb => name.toUpperCase();

  static CardStatus fromDb(String val) {
    return CardStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == val.toUpperCase(),
      orElse: () => CardStatus.todo,
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
    required this.createdAt,
    required this.updatedAt,
  });

  factory KanbanCard.fromJson(Map<String, dynamic> json) {
    // profiles ile join varsa: json['profiles']['full_name']
    String? name;
    if (json['profiles'] != null) {
      name = json['profiles']['full_name'] ?? json['profiles']['email'];
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
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
