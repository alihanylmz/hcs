import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_item.dart';

/// Otomatik bildirim gönderme servisi
/// OneSignal REST API kullanarak bildirim gönderir
class NotificationService {
  // OneSignal App ID (main.dart'dan alınan)
  static const String _oneSignalAppId = "faeed989-8a81-4fe0-9c73-2eb9ed2144a7";
  
  // OneSignal REST API endpoint
  static const String _oneSignalApiUrl = "https://onesignal.com/api/v1/notifications";

  /// OneSignal REST API Key'i .env dosyasından alır
  /// Güvenlik uyarısı: Web build'de bu anahtarın client'ta olmaması gerekir.
  String? get _restApiKey {
    if (kIsWeb) return null; // Web'de anahtar kullanılmasın
    return dotenv.env['ONESIGNAL_REST_API_KEY'];
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Bildirim gönderir (Web'de server-side endpoint, mobil/desktop'ta doğrudan REST API)
  Future<bool> _sendNotification({
    required Map<String, dynamic> body,
  }) async {
    try {
      // Web'de isek veya API anahtarı yoksa Supabase Edge Function üzerinden gönder
      if (kIsWeb || _restApiKey == null) {
        print('🌐 Bildirim Web üzerinden (Edge Function) gönderiliyor...');
        final response = await _supabase.functions.invoke(
          'send-notification',
          body: body,
        );
        return response.status == 200;
      }

      // Mobil/Desktop'ta doğrudan OneSignal REST API kullan
      final response = await http.post(
        Uri.parse(_oneSignalApiUrl),
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Authorization": "Basic ${_restApiKey!}",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('❌ Bildirim gönderme hatası: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Bildirim gönderme hatası: $e');
      return false;
    }
  }

  /// Supabase'e bildirim kaydeder
  Future<void> _saveNotificationsToDb({
    required List<String> userIds,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    if (userIds.isEmpty) return;

    try {
      final List<Map<String, dynamic>> records = userIds.map((uid) {
        return {
          'user_id': uid,
          'title': title,
          'message': message,
          'data': data,
          'is_read': false,
        };
      }).toList();

      await _supabase.from('notifications').insert(records);
    } catch (e) {
      print('❌ Bildirim veritabanına kaydedilirken hata: $e');
    }
  }

  /// Kullanıcının bildirimlerini getirir
  Future<List<NotificationItem>> getNotifications() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      final List data = response as List;
      return data.map((e) => NotificationItem.fromJson(e)).toList();
    } catch (e) {
      print('❌ Bildirimler yüklenirken hata: $e');
      return [];
    }
  }

  /// Okunmamış bildirim sayısını getirir
  Future<int> getUnreadCount() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      final response = await _supabase
          .from('notifications')
          .count()
          .eq('user_id', user.id)
          .eq('is_read', false);
      
      return response;
    } catch (e) {
      return 0;
    }
  }

  /// Bildirimi okundu olarak işaretler
  Future<void> markAsRead(int notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('❌ Bildirim okundu yapılırken hata: $e');
    }
  }
  
  /// Tüm bildirimleri okundu olarak işaretler
  Future<void> markAllAsRead() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (e) {
      print('❌ Tüm bildirimleri okundu yaparken hata: $e');
    }
  }

  /// Tüm kullanıcılara bildirim gönderir
  /// 
  /// [title] Bildirim başlığı
  /// [message] Bildirim mesajı
  /// [data] Ek veri (opsiyonel)
  Future<bool> sendNotificationToAll({
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    final body = {
      "app_id": _oneSignalAppId,
      "included_segments": ["All"], // Tüm kullanıcılara gönder
      "headings": {"en": title, "tr": title},
      "contents": {"en": message, "tr": message},
      "data": data ?? {},
    };

    return await _sendNotification(body: body);
  }

  /// Supabase user_id'lerini (external_user_id) hedefleyerek bildirim gönderir
  ///
  /// OneSignal tarafında `OneSignal.login(user.id)` ile eşleştirilen kullanıcılar
  /// `include_external_user_ids` ile hedeflenir.
  Future<bool> sendNotificationToExternalUsers({
    required List<String> externalUserIds,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    if (externalUserIds.isEmpty) {
      print('⚠️ Bildirim için hedef kullanıcı bulunamadı');
      return false;
    }

    // 1. Önce Veritabanına kaydet (Log)
    await _saveNotificationsToDb(
      userIds: externalUserIds,
      title: title,
      message: message,
      data: data,
    );

    // 2. Sonra OneSignal ile gönder
    final body = {
      "app_id": _oneSignalAppId,
      "include_external_user_ids": externalUserIds,
      "headings": {"en": title, "tr": title},
      "contents": {"en": message, "tr": message},
      "data": data ?? {},
    };

    return await _sendNotification(body: body);
  }

  /// Belirli bir iş emri için hangi kullanıcıların bildirim alacağını hesaplar.
  ///
  /// Kural:
  /// - Admin ve manager rollerindeki tüm kullanıcılar daima bildirim alır.
  /// - Partner kullanıcıları (role = 'partner_user') SADECE kendi partner_id'sine ait işlerden bildirim alır.
  /// - Teknisyenler bildirim almaz.
  Future<List<String>> _getTargetUserIdsForTicket(String ticketId) async {
    try {
      final dynamic idValue = int.tryParse(ticketId) ?? ticketId;

      final ticket = await _supabase
          .from('tickets')
          .select('partner_id')
          .eq('id', idValue)
          .maybeSingle();

      if (ticket == null) {
        return [];
      }

      final int? partnerId = ticket['partner_id'] as int?;

      // 1. İç kullanıcılar (admin ve manager)
      final internalRes = await _supabase
          .from('profiles')
          .select('id, role')
          .inFilter('role', ['admin', 'manager']);

      final internalIds = (internalRes as List)
          .map((e) => e['id'] as String)
          .toList();

      // 2. Partner kullanıcıları (sadece ilgili partner_id)
      List<String> partnerIds = [];
      if (partnerId != null) {
        final partnerRes = await _supabase
            .from('profiles')
            .select('id, role, partner_id')
            .eq('role', 'partner_user')
            .eq('partner_id', partnerId);

        partnerIds = (partnerRes as List)
            .map((e) => e['id'] as String)
            .toList();
      }

      final allIds = <String>{};
      allIds.addAll(internalIds);
      allIds.addAll(partnerIds);

      return allIds.toList();
    } catch (e) {
      print('❌ Hedef kullanıcı listesi hesaplanırken hata: $e');
      return [];
    }
  }

  /// Belirli kullanıcılara bildirim gönderir
  /// 
  /// [playerIds] OneSignal Player ID'leri listesi
  /// [title] Bildirim başlığı
  /// [message] Bildirim mesajı
  /// [data] Ek veri (opsiyonel)
  Future<bool> sendNotificationToUsers({
    required List<String> playerIds,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    if (playerIds.isEmpty) {
      print('⚠️ Player ID listesi boş');
      return false;
    }
    
    // Not: Player ID'ler ile user_id'leri eşleştirmek zor olduğu için
    // burada DB kaydı yapamıyoruz (veya zor).
    // Ancak sendNotificationToExternalUsers metodu kullanılıyor genellikle.

    final body = {
      "app_id": _oneSignalAppId,
      "include_player_ids": playerIds,
      "headings": {"en": title, "tr": title},
      "contents": {"en": message, "tr": message},
      "data": data ?? {},
    };

    return await _sendNotification(body: body);
  }

  /// Yeni ticket oluşturulduğunda bildirim gönderir
  Future<bool> notifyTicketCreated({
    required String ticketId,
    required String ticketTitle,
    String? jobCode,
    String? createdBy,
  }) async {
    final title = "Yeni İş Emri Oluşturuldu";
    final jobCodeText = jobCode ?? 'İş Kodu Yok';
    final message = createdBy != null
        ? "$createdBy tarafından yeni iş emri oluşturuldu: $jobCodeText"
        : "Yeni iş emri oluşturuldu: $jobCodeText";

    final userIds = await _getTargetUserIdsForTicket(ticketId);

    return await sendNotificationToExternalUsers(
      externalUserIds: userIds,
      title: title,
      message: message,
      data: {
        "type": "ticket_created",
        "ticket_id": ticketId,
        "ticket_title": ticketTitle,
        "job_code": jobCode ?? '',
      },
    );
  }

  /// Ticket durumu değiştiğinde bildirim gönderir
  Future<bool> notifyTicketStatusChanged({
    required String ticketId,
    required String ticketTitle,
    required String oldStatus,
    required String newStatus,
    String? changedBy,
    String? jobCode,
  }) async {
    final statusLabels = {
      'open': 'Açık',
      'panel_done_stock': 'Panosu Yapıldı Stokta',
      'panel_done_sent': 'Panosu Yapıldı Gönderildi',
      'in_progress': 'Serviste',
      'done': 'İş Tamamlandı',
      'archived': 'Arşivde',
    };

    final oldStatusLabel = statusLabels[oldStatus] ?? oldStatus;
    final newStatusLabel = statusLabels[newStatus] ?? newStatus;

    final title = "İş Emri Durumu Değişti";
    final message = jobCode != null
        ? "$jobCode iş emrinin durumu '$oldStatusLabel' → '$newStatusLabel' olarak güncellendi"
        : "İş emri durumu '$oldStatusLabel' → '$newStatusLabel' olarak güncellendi";

    final userIds = await _getTargetUserIdsForTicket(ticketId);

    return await sendNotificationToExternalUsers(
      externalUserIds: userIds,
      title: title,
      message: message,
      data: {
        "type": "ticket_status_changed",
        "ticket_id": ticketId,
        "ticket_title": ticketTitle,
        "old_status": oldStatus,
        "new_status": newStatus,
        "job_code": jobCode,
      },
    );
  }

  /// Ticket'a not eklendiğinde bildirim gönderir
  Future<bool> notifyNoteAdded({
    required String ticketId,
    required String ticketTitle,
    required String noteAuthor,
    String? jobCode,
  }) async {
    final title = "Yeni Not Eklendi";
    final message = jobCode != null
        ? "$noteAuthor, $jobCode iş emrine not ekledi"
        : "$noteAuthor, iş emrine not ekledi";

    final userIds = await _getTargetUserIdsForTicket(ticketId);

    return await sendNotificationToExternalUsers(
      externalUserIds: userIds,
      title: title,
      message: message,
      data: {
        "type": "note_added",
        "ticket_id": ticketId,
        "ticket_title": ticketTitle,
        "note_author": noteAuthor,
        "job_code": jobCode,
      },
    );
  }

  /// Partner notu eklendiğinde sadece admin ve manager'lara bildirim gönderir
  Future<bool> notifyPartnerNoteAdded({
    required String ticketId,
    required String ticketTitle,
    required String noteAuthor,
    String? jobCode,
  }) async {
    final title = "Yeni Partner Notu";
    final message = jobCode != null
        ? "$noteAuthor, $jobCode iş emrine partner notu ekledi"
        : "$noteAuthor, iş emrine partner notu ekledi";

    // Sadece admin ve manager'lara bildirim gönder
    final response = await _supabase
        .from('profiles')
        .select('id')
        .inFilter('role', ['admin', 'manager']);

    final userIds = (response as List)
        .map((e) => e['id'] as String)
        .toList();

    if (userIds.isEmpty) return false;

    return await sendNotificationToExternalUsers(
      externalUserIds: userIds,
      title: title,
      message: message,
      data: {
        "type": "partner_note_added",
        "ticket_id": ticketId,
        "ticket_title": ticketTitle,
        "note_author": noteAuthor,
        "job_code": jobCode,
      },
    );
  }

  /// Ticket önceliği değiştiğinde bildirim gönderir
  Future<bool> notifyPriorityChanged({
    required String ticketId,
    required String ticketTitle,
    required String oldPriority,
    required String newPriority,
    String? jobCode,
  }) async {
    final priorityLabels = {
      'low': 'Düşük Öncelik',
      'normal': 'Normal Öncelik',
      'high': 'Yüksek Öncelik',
    };

    final oldPriorityLabel = priorityLabels[oldPriority] ?? oldPriority;
    final newPriorityLabel = priorityLabels[newPriority] ?? newPriority;

    final title = "İş Emri Önceliği Değişti";
    final message = jobCode != null
        ? "$jobCode iş emrinin önceliği '$oldPriorityLabel' → '$newPriorityLabel' olarak güncellendi"
        : "İş emri önceliği '$oldPriorityLabel' → '$newPriorityLabel' olarak güncellendi";

    final userIds = await _getTargetUserIdsForTicket(ticketId);

    return await sendNotificationToExternalUsers(
      externalUserIds: userIds,
      title: title,
      message: message,
      data: {
        "type": "priority_changed",
        "ticket_id": ticketId,
        "ticket_title": ticketTitle,
        "old_priority": oldPriority,
        "new_priority": newPriority,
        "job_code": jobCode,
      },
    );
  }

  // ==================== KANBAN KART BİLDİRİMLERİ ====================

  /// Takım üyelerinin user_id'lerini getirir (kendisi hariç)
  Future<List<String>> _getTeamMemberIds(String teamId, {bool excludeSelf = true}) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      final response = await _supabase
          .from('team_members')
          .select('user_id')
          .eq('team_id', teamId);

      final List<String> userIds = (response as List)
          .map((e) => e['user_id'] as String)
          .toList();

      // Kendisini hariç tut (isteğe bağlı)
      if (excludeSelf && currentUserId != null) {
        userIds.remove(currentUserId);
      }

      return userIds;
    } catch (e) {
      print('❌ Takım üyeleri alınırken hata: $e');
      return [];
    }
  }

  /// Yeni kart oluşturulduğunda takım üyelerine bildirim gönderir
  Future<bool> notifyCardCreated({
    required String teamId,
    required String teamName,
    required String cardId,
    required String cardTitle,
    String? createdByName,
    String? assigneeName,
  }) async {
    final title = "📋 Yeni Kart Eklendi";
    final creatorText = createdByName ?? 'Bir üye';
    final assigneeText = assigneeName != null ? " ($assigneeName'e atandı)" : '';
    final message = "$creatorText, $teamName takımına yeni kart ekledi: \"$cardTitle\"$assigneeText";

    final userIds = await _getTeamMemberIds(teamId, excludeSelf: true);

    if (userIds.isEmpty) {
      print('⚠️ Bildirim gönderilecek takım üyesi bulunamadı');
      return false;
    }

    return await sendNotificationToExternalUsers(
      externalUserIds: userIds,
      title: title,
      message: message,
      data: {
        "type": "card_created",
        "team_id": teamId,
        "team_name": teamName,
        "card_id": cardId,
        "card_title": cardTitle,
      },
    );
  }

  /// Kart durumu değiştiğinde takım üyelerine bildirim gönderir
  Future<bool> notifyCardStatusChanged({
    required String teamId,
    required String teamName,
    required String cardId,
    required String cardTitle,
    required String oldStatus,
    required String newStatus,
    String? changedByName,
  }) async {
    final statusLabels = {
      'TODO': 'Yapılacak',
      'DOING': 'Yapılıyor',
      'DONE': 'Tamamlandı',
      'SENT': 'Gönderildi',
    };

    final oldLabel = statusLabels[oldStatus] ?? oldStatus;
    final newLabel = statusLabels[newStatus] ?? newStatus;

    final title = "🔄 Kart Durumu Değişti";
    final changerText = changedByName ?? 'Bir üye';
    final message = "$changerText, \"$cardTitle\" kartını $oldLabel → $newLabel olarak güncelledi";

    final userIds = await _getTeamMemberIds(teamId, excludeSelf: true);

    if (userIds.isEmpty) return false;

    return await sendNotificationToExternalUsers(
      externalUserIds: userIds,
      title: title,
      message: message,
      data: {
        "type": "card_status_changed",
        "team_id": teamId,
        "team_name": teamName,
        "card_id": cardId,
        "card_title": cardTitle,
        "old_status": oldStatus,
        "new_status": newStatus,
      },
    );
  }

  /// Kart ataması değiştiğinde ilgili kişiye bildirim gönderir
  Future<bool> notifyCardAssigned({
    required String teamId,
    required String teamName,
    required String cardId,
    required String cardTitle,
    required String assigneeId,
    String? assignedByName,
  }) async {
    final title = "👤 Kart Size Atandı";
    final assignerText = assignedByName ?? 'Bir üye';
    final message = "$assignerText size \"$cardTitle\" kartını atadı ($teamName)";

    // Sadece atanan kişiye bildirim gönder
    return await sendNotificationToExternalUsers(
      externalUserIds: [assigneeId],
      title: title,
      message: message,
      data: {
        "type": "card_assigned",
        "team_id": teamId,
        "team_name": teamName,
        "card_id": cardId,
        "card_title": cardTitle,
      },
    );
  }

  /// Üye takıma davet edildiğinde bildirim gönderir
  Future<bool> notifyMemberInvited({
    required String teamId,
    required String teamName,
    required String invitedUserId,
    String? invitedByName,
  }) async {
    final title = "🎉 Takıma Davet Edildiniz";
    final inviterText = invitedByName ?? 'Bir kullanıcı';
    final message = "$inviterText sizi \"$teamName\" takımına davet etti";

    return await sendNotificationToExternalUsers(
      externalUserIds: [invitedUserId],
      title: title,
      message: message,
      data: {
        "type": "member_invited",
        "team_id": teamId,
        "team_name": teamName,
      },
    );
  }
}
