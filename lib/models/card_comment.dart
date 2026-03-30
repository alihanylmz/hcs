class CardComment {
  const CardComment({
    required this.id,
    required this.cardId,
    required this.teamId,
    required this.userId,
    required this.comment,
    required this.createdAt,
    this.authorName,
  });

  final String id;
  final String cardId;
  final String teamId;
  final String userId;
  final String comment;
  final DateTime createdAt;
  final String? authorName;

  factory CardComment.fromJson(Map<String, dynamic> json) {
    String? authorName;
    final profiles = json['profiles'];
    if (profiles is Map<String, dynamic>) {
      final fullName = (profiles['full_name'] as String?)?.trim();
      final email = (profiles['email'] as String?)?.trim();
      authorName = (fullName?.isNotEmpty == true) ? fullName : email;
    }

    return CardComment(
      id: json['id'].toString(),
      cardId: json['card_id'].toString(),
      teamId: json['team_id'].toString(),
      userId: json['user_id'].toString(),
      comment: (json['comment'] as String? ?? '').trim(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      authorName: authorName,
    );
  }
}
