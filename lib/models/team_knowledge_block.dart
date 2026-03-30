enum TeamKnowledgeBlockType {
  paragraph,
  checklist,
  callout,
  ticketLink,
  cardLink;

  String get dbValue {
    switch (this) {
      case TeamKnowledgeBlockType.paragraph:
        return 'paragraph';
      case TeamKnowledgeBlockType.checklist:
        return 'checklist';
      case TeamKnowledgeBlockType.callout:
        return 'callout';
      case TeamKnowledgeBlockType.ticketLink:
        return 'ticket_link';
      case TeamKnowledgeBlockType.cardLink:
        return 'card_link';
    }
  }

  String get label {
    switch (this) {
      case TeamKnowledgeBlockType.paragraph:
        return 'Metin';
      case TeamKnowledgeBlockType.checklist:
        return 'Checklist';
      case TeamKnowledgeBlockType.callout:
        return 'Uyari';
      case TeamKnowledgeBlockType.ticketLink:
        return 'Is Emri';
      case TeamKnowledgeBlockType.cardLink:
        return 'Kart';
    }
  }

  static TeamKnowledgeBlockType fromDb(String? value) {
    switch (value) {
      case 'checklist':
        return TeamKnowledgeBlockType.checklist;
      case 'callout':
        return TeamKnowledgeBlockType.callout;
      case 'ticket_link':
        return TeamKnowledgeBlockType.ticketLink;
      case 'card_link':
        return TeamKnowledgeBlockType.cardLink;
      case 'paragraph':
      default:
        return TeamKnowledgeBlockType.paragraph;
    }
  }
}

class TeamKnowledgeBlock {
  final String id;
  final String pageId;
  final TeamKnowledgeBlockType type;
  final String title;
  final String value;
  final bool checked;
  final int sortOrder;

  const TeamKnowledgeBlock({
    required this.id,
    required this.pageId,
    required this.type,
    required this.title,
    required this.value,
    required this.checked,
    required this.sortOrder,
  });

  factory TeamKnowledgeBlock.fromJson(Map<String, dynamic> json) {
    final content = Map<String, dynamic>.from(
      (json['content'] as Map<String, dynamic>?) ?? const {},
    );

    return TeamKnowledgeBlock(
      id: json['id'] as String,
      pageId: json['page_id'] as String,
      type: TeamKnowledgeBlockType.fromDb(json['block_type'] as String?),
      title: (content['title'] as String?) ?? '',
      value: (content['value'] as String?) ?? '',
      checked: (content['checked'] as bool?) ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  TeamKnowledgeBlock copyWith({
    String? id,
    String? pageId,
    TeamKnowledgeBlockType? type,
    String? title,
    String? value,
    bool? checked,
    int? sortOrder,
  }) {
    return TeamKnowledgeBlock(
      id: id ?? this.id,
      pageId: pageId ?? this.pageId,
      type: type ?? this.type,
      title: title ?? this.title,
      value: value ?? this.value,
      checked: checked ?? this.checked,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toInsertJson(String pageId, int sortOrder) {
    return {
      'page_id': pageId,
      'block_type': type.dbValue,
      'sort_order': sortOrder,
      'content': {'title': title, 'value': value, 'checked': checked},
    };
  }
}
