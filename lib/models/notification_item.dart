class NotificationItem {
  final String id;
  final String userId;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'].toString(),
      userId: json['user_id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      data:
          json['data'] is Map
              ? Map<String, dynamic>.from(json['data'] as Map)
              : null,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'message': message,
      'data': data,
      'is_read': isRead,
      // created_at usually handled by DB default
    };
  }
}
