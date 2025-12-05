import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Otomatik bildirim gönderme servisi
/// OneSignal REST API kullanarak bildirim gönderir
class NotificationService {
  // OneSignal App ID (main.dart'dan alınan)
  static const String _oneSignalAppId = "faeed989-8a81-4fe0-9c73-2eb9ed2144a7";
  
  // OneSignal REST API endpoint
  static const String _oneSignalApiUrl = "https://onesignal.com/api/v1/notifications";

  /// OneSignal REST API Key'i .env dosyasından alır
  String? get _restApiKey {
    return dotenv.env['ONESIGNAL_REST_API_KEY'];
  }

  SupabaseClient get _supabase => Supabase.instance.client;

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
    try {
      final apiKey = _restApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        print('⚠️ OneSignal REST API Key bulunamadı. .env dosyasına ONESIGNAL_REST_API_KEY ekleyin.');
        return false;
      }

      final body = {
        "app_id": _oneSignalAppId,
        "included_segments": ["All"], // Tüm kullanıcılara gönder
        "headings": {"en": title, "tr": title},
        "contents": {"en": message, "tr": message},
        "data": data ?? {},
      };

      final response = await http.post(
        Uri.parse(_oneSignalApiUrl),
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Authorization": "Basic $apiKey",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print('✅ Bildirim başarıyla gönderildi');
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

    try {
      final apiKey = _restApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        print('⚠️ OneSignal REST API Key bulunamadı. .env dosyasına ONESIGNAL_REST_API_KEY ekleyin.');
        return false;
      }

      final body = {
        "app_id": _oneSignalAppId,
        "include_external_user_ids": externalUserIds,
        "headings": {"en": title, "tr": title},
        "contents": {"en": message, "tr": message},
        "data": data ?? {},
      };

      final response = await http.post(
        Uri.parse(_oneSignalApiUrl),
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Authorization": "Basic $apiKey",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print('✅ Bildirim başarıyla gönderildi (${externalUserIds.length} kullanıcı)');
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

    try {
      final apiKey = _restApiKey;
      if (apiKey == null || apiKey.isEmpty) {
        print('⚠️ OneSignal REST API Key bulunamadı. .env dosyasına ONESIGNAL_REST_API_KEY ekleyin.');
        return false;
      }

      final body = {
        "app_id": _oneSignalAppId,
        "include_player_ids": playerIds,
        "headings": {"en": title, "tr": title},
        "contents": {"en": message, "tr": message},
        "data": data ?? {},
      };

      final response = await http.post(
        Uri.parse(_oneSignalApiUrl),
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          "Authorization": "Basic $apiKey",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        print('✅ Bildirim başarıyla gönderildi (${playerIds.length} kullanıcı)');
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
}

