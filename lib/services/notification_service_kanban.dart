import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification.dart';
import 'dart:developer' as developer;

class NotificationServiceKanban {
  final SupabaseClient _client = Supabase.instance.client;

  /// Kullanıcının tüm bildirimlerini getirir
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
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
          .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      developer.log(
        '🔴 Bildirimler yüklenirken hata',
        name: 'NotificationServiceKanban.getNotifications',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Okunmamış bildirim sayısı
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
    } catch (e) {
      return 0;
    }
  }

  /// Bildirimi okundu olarak işaretle
  Future<void> markAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e, st) {
      developer.log(
        '🔴 Bildirim güncelleme hatası',
        name: 'NotificationServiceKanban.markAsRead',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Tüm bildirimleri okundu işaretle
  Future<void> markAllAsRead() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e, st) {
      developer.log(
        '🔴 Toplu bildirim güncelleme hatası',
        name: 'NotificationServiceKanban.markAllAsRead',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Bildirimi sil
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .delete()
          .eq('id', notificationId);
    } catch (e, st) {
      developer.log(
        '🔴 Bildirim silme hatası',
        name: 'NotificationServiceKanban.deleteNotification',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// OneSignal Player ID kaydet
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
    } catch (e, st) {
      developer.log(
        '🔴 Player ID kaydetme hatası',
        name: 'NotificationServiceKanban.savePlayerID',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Realtime subscription (yeni bildirimler geldiğinde)
  RealtimeChannel subscribeToNotifications(Function(AppNotification) onNewNotification) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Kullanıcı oturumu kapalı');

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
            final notification = AppNotification.fromJson(
              payload.newRecord as Map<String, dynamic>,
            );
            onNewNotification(notification);
          },
        )
        .subscribe();
  }
}
