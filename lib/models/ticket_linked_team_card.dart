import 'card.dart';

class TicketLinkedTeamCard {
  TicketLinkedTeamCard({
    required this.cardId,
    required this.teamId,
    required this.teamName,
    required this.boardId,
    required this.boardName,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.assigneeId,
    this.assigneeName,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  final String cardId;
  final String teamId;
  final String teamName;
  final String boardId;
  final String boardName;
  final String title;
  final String? description;
  final CardStatus status;
  final CardPriority priority;
  final String? assigneeId;
  final String? assigneeName;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
}
