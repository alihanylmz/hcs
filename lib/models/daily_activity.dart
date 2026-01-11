/// Alt adımları temsil eden sınıf
class ActivityStep {
  String title;
  bool isCompleted;

  ActivityStep({required this.title, this.isCompleted = false});

  factory ActivityStep.fromJson(Map<String, dynamic> json) {
    return ActivityStep(
      title: json['title'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'isCompleted': isCompleted,
    };
  }
}

class DailyActivity {
  final String id;
  final String userId;
  final String creatorId;
  final String title;
  final DateTime activityDate;
  final DateTime createdAt;
  final List<ActivityStep> steps;
  final int? kpiScore; // KPI Puanı (Örn: 1-5 arası)

  // Manuel 'isCompleted' alanı artık 'steps' durumuna göre hesaplanabilir
  // Ancak geriye dönük uyumluluk veya "Adımsız işler" için veritabanındaki değeri de tutabiliriz.
  final bool _manualIsCompleted; 

  DailyActivity({
    required this.id,
    required this.userId,
    required this.creatorId,
    required this.title,
    required bool isCompleted,
    required this.activityDate,
    required this.createdAt,
    this.steps = const [],
    this.kpiScore,
  }) : _manualIsCompleted = isCompleted;

  // Getter: Ana iş bitti mi?
  bool get isCompleted {
    if (steps.isEmpty) return _manualIsCompleted;
    return steps.every((s) => s.isCompleted);
  }

  // Getter: İlerleme oranı (0.0 ile 1.0 arası)
  double get progress {
    if (steps.isEmpty) return _manualIsCompleted ? 1.0 : 0.0;
    final completed = steps.where((s) => s.isCompleted).length;
    return completed / steps.length;
  }

  /// Supabase'den gelen JSON verisini modele çevirir
  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    var stepsList = <ActivityStep>[];
    if (json['steps'] != null) {
      stepsList = (json['steps'] as List)
          .map((e) => ActivityStep.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return DailyActivity(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      creatorId: json['creator_id'] as String? ?? json['user_id'] as String,
      title: json['title'] as String,
      isCompleted: json['is_completed'] as bool? ?? false,
      activityDate: DateTime.parse(json['activity_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      steps: stepsList,
      kpiScore: json['kpi_score'] as int?,
    );
  }

  /// Modeli JSON'a çevirir (Supabase'e gönderirken)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'creator_id': creatorId,
      'title': title,
      'is_completed': steps.isNotEmpty ? steps.every((s) => s.isCompleted) : _manualIsCompleted,
      'activity_date': activityDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'steps': steps.map((s) => s.toJson()).toList(),
      'kpi_score': kpiScore,
    };
  }

  /// Nesnenin kopyasını oluşturur (Immutable update için)
  DailyActivity copyWith({
    String? id,
    String? userId,
    String? creatorId,
    String? title,
    bool? isCompleted,
    DateTime? activityDate,
    DateTime? createdAt,
    List<ActivityStep>? steps,
    int? kpiScore,
  }) {
    return DailyActivity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      creatorId: creatorId ?? this.creatorId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? (steps != null ? steps.every((s) => s.isCompleted) : this.isCompleted),
      activityDate: activityDate ?? this.activityDate,
      createdAt: createdAt ?? this.createdAt,
      steps: steps ?? this.steps,
      kpiScore: kpiScore ?? this.kpiScore,
    );
  }

  /// Yönetici tarafından mı atanmış?
  bool get isAssignedByManager => userId != creatorId;
}
