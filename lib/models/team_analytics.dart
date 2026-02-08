class TeamAnalytics {
  final int totalCards;
  final int todoCount;
  final int doingCount;
  final int doneCount;
  final int sentCount;
  
  // Basit verimlilik metrikleri
  final double completionRate;

  TeamAnalytics({
    required this.totalCards,
    required this.todoCount,
    required this.doingCount,
    required this.doneCount,
    required this.sentCount,
    required this.completionRate,
  });
}
