import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/app_logger.dart';
import '../models/notification_item.dart';
import '../models/ticket_status.dart';

/// Push gonderimleri sadece backend function uzerinden yapilir.
class NotificationService {
  static const String _oneSignalAppId = 'faeed989-8a81-4fe0-9c73-2eb9ed2144a7';
  static const AppLogger _logger = AppLogger('NotificationService');

  SupabaseClient get _supabase => Supabase.instance.client;

  Future<bool> _sendNotification({required Map<String, dynamic> body}) async {
    try {
      final response = await _supabase.functions.invoke(
        'send-notification',
        body: body,
      );
      final status = response.status;

      if (status >= 200 && status < 300) {
        return true;
      }

      _logger.warning(
        'send_notification_function_failed',
        data: {'status': status, 'body': response.data},
      );
      return false;
    } catch (error, stackTrace) {
      _logger.error(
        'send_notification_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> _saveNotificationsToDb({
    required List<String> userIds,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    if (userIds.isEmpty) return;

    try {
      final records =
          userIds
              .map(
                (userId) => {
                  'user_id': userId,
                  'title': title,
                  'message': message,
                  'data': data,
                  'is_read': false,
                },
              )
              .toList();

      await _supabase.from('notifications').insert(records);
    } catch (error, stackTrace) {
      _logger.error(
        'save_notifications_to_db_failed',
        data: {'userCount': userIds.length},
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

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

      final data = response as List;
      return data
          .map(
            (item) => NotificationItem.fromJson(item as Map<String, dynamic>),
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
      final user = _supabase.auth.currentUser;
      if (user == null) return 0;

      final response = await _supabase
          .from('notifications')
          .count()
          .eq('user_id', user.id)
          .eq('is_read', false);

      return response;
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
      await _supabase
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
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false);
    } catch (error, stackTrace) {
      _logger.error(
        'mark_all_notifications_as_read_failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> sendNotificationToAll({
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    final body = {
      'app_id': _oneSignalAppId,
      'included_segments': ['All'],
      'headings': {'en': title, 'tr': title},
      'contents': {'en': message, 'tr': message},
      'data': data ?? <String, dynamic>{},
    };

    return _sendNotification(body: body);
  }

  Future<bool> sendNotificationToExternalUsers({
    required List<String> externalUserIds,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    if (externalUserIds.isEmpty) {
      _logger.warning(
        'send_notification_to_external_users_skipped',
        data: {'reason': 'empty_target_list'},
      );
      return false;
    }

    await _saveNotificationsToDb(
      userIds: externalUserIds,
      title: title,
      message: message,
      data: data,
    );

    final body = {
      'app_id': _oneSignalAppId,
      'include_external_user_ids': externalUserIds,
      'headings': {'en': title, 'tr': title},
      'contents': {'en': message, 'tr': message},
      'data': data ?? <String, dynamic>{},
    };

    return _sendNotification(body: body);
  }

  Future<List<String>> _getTargetUserIdsForTicket(String ticketId) async {
    try {
      final idValue = int.tryParse(ticketId) ?? ticketId;

      final ticket =
          await _supabase
              .from('tickets')
              .select('partner_id')
              .eq('id', idValue)
              .maybeSingle();

      if (ticket == null) {
        return [];
      }

      final partnerId = ticket['partner_id'] as int?;

      final internalRes = await _supabase
          .from('profiles')
          .select('id, role')
          .inFilter('role', ['admin', 'manager']);

      final internalIds =
          (internalRes as List).map((item) => item['id'] as String).toList();

      var partnerIds = <String>[];
      if (partnerId != null) {
        final partnerRes = await _supabase
            .from('profiles')
            .select('id, role, partner_id')
            .eq('role', 'partner_user')
            .eq('partner_id', partnerId);

        partnerIds =
            (partnerRes as List).map((item) => item['id'] as String).toList();
      }

      final allIds = <String>{};
      allIds.addAll(internalIds);
      allIds.addAll(partnerIds);

      return allIds.toList();
    } catch (error, stackTrace) {
      _logger.error(
        'get_target_user_ids_for_ticket_failed',
        data: {'ticketId': ticketId},
        error: error,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<bool> sendNotificationToUsers({
    required List<String> playerIds,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    if (playerIds.isEmpty) {
      _logger.warning(
        'send_notification_to_users_skipped',
        data: {'reason': 'empty_player_ids'},
      );
      return false;
    }

    final body = {
      'app_id': _oneSignalAppId,
      'include_player_ids': playerIds,
      'headings': {'en': title, 'tr': title},
      'contents': {'en': message, 'tr': message},
      'data': data ?? <String, dynamic>{},
    };

    return _sendNotification(body: body);
  }

  Future<bool> notifyTicketCreated({
    required String ticketId,
    required String ticketTitle,
    String? jobCode,
    String? createdBy,
  }) async {
    final title = 'Yeni Is Emri Olusturuldu';
    final jobCodeText = jobCode ?? 'Is Kodu Yok';
    final message =
        createdBy != null
            ? '$createdBy tarafindan yeni is emri olusturuldu: $jobCodeText'
            : 'Yeni is emri olusturuldu: $jobCodeText';

    final userIds = await _getTargetUserIdsForTicket(ticketId);

    return sendNotificationToExternalUsers(
      externalUserIds: userIds,
      title: title,
      message: message,
      data: {
        'type': 'ticket_created',
        'ticket_id': ticketId,
        'ticket_title': ticketTitle,
        'job_code': jobCode ?? '',
      },
    );
  }

  Future<bool> notifyTicketStatusChanged({
    required String ticketId,
    required String ticketTitle,
    required String oldStatus,
    required String newStatus,
    String? changedBy,
    String? jobCode,
  }) async {
    final oldStatusLabel = TicketStatus.labelOf(oldStatus);
    final newStatusLabel = TicketStatus.labelOf(newStatus);

    final title = 'Is Emri Durumu Degisti';
    final actorPrefix = changedBy != null ? '$changedBy tarafindan ' : '';
    final message =
        jobCode != null
            ? '$actorPrefix$jobCode is emrinin durumu '
                '\'$oldStatusLabel\' -> \'$newStatusLabel\' olarak guncellendi'
            : '${actorPrefix}is emri durumu '
                '\'$oldStatusLabel\' -> \'$newStatusLabel\' olarak guncellendi';

    final userIds = await _getTargetUserIdsForTicket(ticketId);

    return sendNotificationToExternalUsers(
      externalUserIds: userIds,
      title: title,
      message: message,
      data: {
        'type': 'ticket_status_changed',
        'ticket_id': ticketId,
        'ticket_title': ticketTitle,
        'old_status': oldStatus,
        'new_status': newStatus,
        'job_code': jobCode,
      },
    );
  }

  Future<bool> notifyNoteAdded({
    required String ticketId,
    required String ticketTitle,
    required String noteAuthor,
    String? jobCode,
  }) async {
    final title = 'Yeni Not Eklendi';
    final message =
        jobCode != null
            ? '$noteAuthor, $jobCode is emrine not ekledi'
            : '$noteAuthor, is emrine not ekledi';

    final userIds = await _getTargetUserIdsForTicket(ticketId);

    return sendNotificationToExternalUsers(
      externalUserIds: userIds,
      title: title,
      message: message,
      data: {
        'type': 'note_added',
        'ticket_id': ticketId,
        'ticket_title': ticketTitle,
        'note_author': noteAuthor,
        'job_code': jobCode,
      },
    );
  }

  Future<bool> notifyPartnerNoteAdded({
    required String ticketId,
    required String ticketTitle,
    required String noteAuthor,
    String? jobCode,
  }) async {
    final title = 'Yeni Partner Notu';
    final message =
        jobCode != null
            ? '$noteAuthor, $jobCode is emrine partner notu ekledi'
            : '$noteAuthor, is emrine partner notu ekledi';

    final response = await _supabase.from('profiles').select('id').inFilter(
      'role',
      ['admin', 'manager'],
    );

    final userIds =
        (response as List).map((item) => item['id'] as String).toList();

    if (userIds.isEmpty) return false;

    return sendNotificationToExternalUsers(
      externalUserIds: userIds,
      title: title,
      message: message,
      data: {
        'type': 'partner_note_added',
        'ticket_id': ticketId,
        'ticket_title': ticketTitle,
        'note_author': noteAuthor,
        'job_code': jobCode,
      },
    );
  }

  Future<bool> notifyPriorityChanged({
    required String ticketId,
    required String ticketTitle,
    required String oldPriority,
    required String newPriority,
    String? jobCode,
  }) async {
    const priorityLabels = {
      'low': 'Dusuk Oncelik',
      'normal': 'Normal Oncelik',
      'high': 'Yuksek Oncelik',
    };

    final oldPriorityLabel = priorityLabels[oldPriority] ?? oldPriority;
    final newPriorityLabel = priorityLabels[newPriority] ?? newPriority;

    final title = 'Is Emri Onceligi Degisti';
    final message =
        jobCode != null
            ? '$jobCode is emrinin onceligi '
                '\'$oldPriorityLabel\' -> \'$newPriorityLabel\' olarak guncellendi'
            : 'Is emri onceligi '
                '\'$oldPriorityLabel\' -> \'$newPriorityLabel\' olarak guncellendi';

    final userIds = await _getTargetUserIdsForTicket(ticketId);

    return sendNotificationToExternalUsers(
      externalUserIds: userIds,
      title: title,
      message: message,
      data: {
        'type': 'priority_changed',
        'ticket_id': ticketId,
        'ticket_title': ticketTitle,
        'old_priority': oldPriority,
        'new_priority': newPriority,
        'job_code': jobCode,
      },
    );
  }

  Future<List<String>> _getTeamMemberIds(
    String teamId, {
    bool excludeSelf = true,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;

      final response = await _supabase
          .from('team_members')
          .select('user_id')
          .eq('team_id', teamId);

      final userIds =
          (response as List).map((item) => item['user_id'] as String).toList();

      if (excludeSelf && currentUserId != null) {
        userIds.remove(currentUserId);
      }

      return userIds;
    } catch (error, stackTrace) {
      _logger.error(
        'get_team_member_ids_failed',
        data: {'teamId': teamId, 'excludeSelf': excludeSelf},
        error: error,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<bool> notifyCardCreated({
    required String teamId,
    required String teamName,
    required String cardId,
    required String cardTitle,
    String? createdByName,
    String? assigneeName,
  }) async {
    final title = 'Yeni Kart Eklendi';
    final creatorText = createdByName ?? 'Bir uye';
    final assigneeText =
        assigneeName != null ? ' ($assigneeName kullanicisina atandi)' : '';
    final message =
        '$creatorText, $teamName takimina yeni kart ekledi: "$cardTitle"$assigneeText';

    final userIds = await _getTeamMemberIds(teamId, excludeSelf: true);

    if (userIds.isEmpty) {
      _logger.warning(
        'notify_card_created_skipped',
        data: {'teamId': teamId, 'cardId': cardId},
      );
      return false;
    }

    return sendNotificationToExternalUsers(
      externalUserIds: userIds,
      title: title,
      message: message,
      data: {
        'type': 'card_created',
        'team_id': teamId,
        'team_name': teamName,
        'card_id': cardId,
        'card_title': cardTitle,
      },
    );
  }

  Future<bool> notifyCardStatusChanged({
    required String teamId,
    required String teamName,
    required String cardId,
    required String cardTitle,
    required String oldStatus,
    required String newStatus,
    String? changedByName,
  }) async {
    const statusLabels = {
      'TODO': 'Yapilacak',
      'DOING': 'Yapiliyor',
      'DONE': 'Tamamlandi',
      'SENT': 'Gonderildi',
    };

    final oldLabel = statusLabels[oldStatus] ?? oldStatus;
    final newLabel = statusLabels[newStatus] ?? newStatus;

    final title = 'Kart Durumu Degisti';
    final changerText = changedByName ?? 'Bir uye';
    final message =
        '$changerText, "$cardTitle" kartini $oldLabel -> $newLabel olarak guncelledi';

    final userIds = await _getTeamMemberIds(teamId, excludeSelf: true);

    if (userIds.isEmpty) return false;

    return sendNotificationToExternalUsers(
      externalUserIds: userIds,
      title: title,
      message: message,
      data: {
        'type': 'card_status_changed',
        'team_id': teamId,
        'team_name': teamName,
        'card_id': cardId,
        'card_title': cardTitle,
        'old_status': oldStatus,
        'new_status': newStatus,
      },
    );
  }

  Future<bool> notifyCardAssigned({
    required String teamId,
    required String teamName,
    required String cardId,
    required String cardTitle,
    required String assigneeId,
    String? assignedByName,
  }) async {
    final title = 'Kart Size Atandi';
    final assignerText = assignedByName ?? 'Bir uye';
    final message = '$assignerText size "$cardTitle" kartini atadi ($teamName)';

    return sendNotificationToExternalUsers(
      externalUserIds: [assigneeId],
      title: title,
      message: message,
      data: {
        'type': 'card_assigned',
        'team_id': teamId,
        'team_name': teamName,
        'card_id': cardId,
        'card_title': cardTitle,
      },
    );
  }

  Future<bool> notifyMemberInvited({
    required String teamId,
    required String teamName,
    required String invitedUserId,
    String? invitedByName,
  }) async {
    final title = 'Takima Davet Edildiniz';
    final inviterText = invitedByName ?? 'Bir kullanici';
    final message = '$inviterText sizi "$teamName" takimina davet etti';

    return sendNotificationToExternalUsers(
      externalUserIds: [invitedUserId],
      title: title,
      message: message,
      data: {
        'type': 'member_invited',
        'team_id': teamId,
        'team_name': teamName,
      },
    );
  }
}
