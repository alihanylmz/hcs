import 'team.dart';

enum TeamHealthLevel {
  stable,
  attention,
  critical;

  String get label {
    switch (this) {
      case TeamHealthLevel.stable:
        return 'Stabil';
      case TeamHealthLevel.attention:
        return 'Dikkat';
      case TeamHealthLevel.critical:
        return 'Kritik';
    }
  }
}

class TeamListSummary {
  final Team team;
  final TeamRole role;
  final int memberCount;
  final int totalCards;
  final int activeCards;
  final int completedCards;
  final DateTime? lastActivityAt;
  final TeamHealthLevel healthLevel;

  const TeamListSummary({
    required this.team,
    required this.role,
    required this.memberCount,
    required this.totalCards,
    required this.activeCards,
    required this.completedCards,
    required this.lastActivityAt,
    required this.healthLevel,
  });
}

class TeamRecentActivity {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;

  const TeamRecentActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
  });
}

class TeamOverviewSnapshot {
  final Team team;
  final TeamRole role;
  final int memberCount;
  final int boardCount;
  final int totalCards;
  final int activeCards;
  final int completedCards;
  final double completionRate;
  final List<TeamRecentActivity> recentActivities;

  const TeamOverviewSnapshot({
    required this.team,
    required this.role,
    required this.memberCount,
    required this.boardCount,
    required this.totalCards,
    required this.activeCards,
    required this.completedCards,
    required this.completionRate,
    required this.recentActivities,
  });
}
