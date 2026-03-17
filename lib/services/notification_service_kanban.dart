import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/app_logger.dart';
import '../models/notification_item.dart';

class NotificationServiceKanban {
  static const AppLogger _logger = AppLogger('NotificationServiceKanban');

  final SupabaseClient _client = Supabase.instance.client;

  Future<List<NotificationItem>> getNotifications({int limit = 50}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map(
            (json) => NotificationItem.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (error, stackTrace) {
      _logger.error(
        'get_notifications_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (error, stackTrace) {
      _logger.error(
        'get_unread_count_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return 0;
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (error, stackTrace) {
      _logger.error(
        'mark_notification_as_read_failed',
        data: {'notificationId': notificationId},
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (error, stackTrace) {
      _logger.error(
        'mark_all_notifications_as_read_failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    try {
      await _client.from('notifications').delete().eq('id', notificationId);
    } catch (error, stackTrace) {
      _logger.error(
        'delete_notification_failed',
        data: {'notificationId': notificationId},
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> savePlayerID(String playerId, String deviceType) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client.from('user_push_tokens').upsert({
        'user_id': userId,
        'onesignal_player_id': playerId,
        'device_type': deviceType,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (error, stackTrace) {
      _logger.error(
        'save_player_id_failed',
        data: {'deviceType': deviceType},
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  RealtimeChannel subscribeToNotifications(
    Function(NotificationItem) onNewNotification,
  ) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Kullanici oturumu kapali');

    return _client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final notification = NotificationItem.fromJson(payload.newRecord);
            onNewNotification(notification);
          },
        )
        .subscribe();
  }
}
