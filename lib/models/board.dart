class Board {
  final String id;
  final String teamId;
  final String name;
  final DateTime createdAt;

  Board({
    required this.id,
    required this.teamId,
    required this.name,
    required this.createdAt,
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'],
      teamId: json['team_id'],
      name: json['name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'team_id': teamId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
