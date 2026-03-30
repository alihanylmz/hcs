import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/team_message.dart';
import '../models/team_thread.dart';

class TeamConversationService {
  TeamConversationService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  Future<ConversationTotalsSnapshot> getConversationTotals(
    String teamId,
  ) async {
    final userId = _currentUserId;
    if (userId == null) {
      return const ConversationTotalsSnapshot(unreadCount: 0, mentionCount: 0);
    }

    await ensureDefaultThreads(teamId);

    final threadRows = await _client
        .from('team_threads')
        .select('id')
        .eq('team_id', teamId);

    final threadIds =
        (threadRows as List<dynamic>)
            .map((row) => (row as Map<String, dynamic>)['id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toList();

    if (threadIds.isEmpty) {
      return const ConversationTotalsSnapshot(unreadCount: 0, mentionCount: 0);
    }

    final messageRows = await _client
        .from('team_messages')
        .select('id, thread_id, user_id, created_at')
        .eq('team_id', teamId)
        .inFilter('thread_id', threadIds);

    final readRows = await _client
        .from('team_thread_reads')
        .select('thread_id, last_read_at')
        .eq('user_id', userId)
        .inFilter('thread_id', threadIds);

    final readsByThread = {
      for (final row in (readRows as List).cast<Map<String, dynamic>>())
        row['thread_id'].toString(): DateTime.tryParse(
          row['last_read_at'] as String? ?? '',
        ),
    };

    var unreadCount = 0;
    final unreadMessageIds = <String>{};

    for (final row in (messageRows as List).cast<Map<String, dynamic>>()) {
      if ((row['user_id']?.toString() ?? '') == userId) {
        continue;
      }

      final threadId = row['thread_id'].toString();
      final createdAt =
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final lastReadAt = readsByThread[threadId];
      final isUnread =
          lastReadAt == null || createdAt.isAfter(lastReadAt.toUtc());

      if (!isUnread) continue;
      unreadCount++;
      unreadMessageIds.add(row['id'].toString());
    }

    var mentionCount = 0;
    if (unreadMessageIds.isNotEmpty) {
      final mentionRows = await _client
          .from('team_message_mentions')
          .select('message_id')
          .eq('mentioned_user_id', userId)
          .inFilter('thread_id', threadIds);

      for (final row in (mentionRows as List).cast<Map<String, dynamic>>()) {
        if (unreadMessageIds.contains(row['message_id']?.toString() ?? '')) {
          mentionCount++;
        }
      }
    }

    return ConversationTotalsSnapshot(
      unreadCount: unreadCount,
      mentionCount: mentionCount,
    );
  }

  Future<void> ensureAnnouncementThread(String teamId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('Kullanici oturumu bulunamadi.');
    }

    final existing =
        await _client
            .from('team_threads')
            .select('*')
            .eq('team_id', teamId)
            .eq('type', TeamThreadType.announcement.dbValue)
            .maybeSingle();

    if (existing != null) {
      return;
    }

    await _client.from('team_threads').insert({
      'team_id': teamId,
      'type': TeamThreadType.announcement.dbValue,
      'title': 'Duyurular',
      'description':
          'Takim duyurulari ve resmi bilgilendirmeler burada tutulur.',
      'created_by': userId,
      'is_pinned': true,
    });
  }

  Future<void> ensureDefaultThreads(String teamId) async {
    await ensureGeneralThread(teamId);
    try {
      await ensureAnnouncementThread(teamId);
    } catch (_) {
      // Announcement kanali policy veya eski migration nedeniyle olusamasa da
      // genel sohbet akisini bozmamak icin burada sessizce devam ediyoruz.
    }
  }

  Future<void> ensureGeneralThread(String teamId) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('Kullanici oturumu bulunamadi.');
    }

    final existing =
        await _client
            .from('team_threads')
            .select('*')
            .eq('team_id', teamId)
            .eq('type', TeamThreadType.general.dbValue)
            .maybeSingle();

    if (existing != null) {
      return;
    }

    await _client.from('team_threads').insert({
      'team_id': teamId,
      'type': TeamThreadType.general.dbValue,
      'title': 'Genel',
      'description': 'Takim ici genel konusmalar burada toplanir.',
      'created_by': userId,
      'is_pinned': true,
    });
  }

  Future<List<TeamThread>> listThreads(String teamId) async {
    final userId = _currentUserId;
    if (userId == null) return [];

    await ensureDefaultThreads(teamId);

    final threadRows = await _client
        .from('team_threads')
        .select('*')
        .eq('team_id', teamId)
        .order('is_pinned', ascending: false)
        .order('last_message_at', ascending: false);

    final rows = (threadRows as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return const [];

    final threadIds = rows.map((row) => row['id'].toString()).toList();

    final messageRows = await _client
        .from('team_messages')
        .select('id, thread_id, user_id, body, created_at')
        .eq('team_id', teamId)
        .inFilter('thread_id', threadIds)
        .order('created_at', ascending: false);

    final readRows = await _client
        .from('team_thread_reads')
        .select('thread_id, last_read_at')
        .eq('user_id', userId)
        .inFilter('thread_id', threadIds);

    final messages = (messageRows as List).cast<Map<String, dynamic>>();
    final readsByThread = {
      for (final row in (readRows as List).cast<Map<String, dynamic>>())
        row['thread_id'].toString(): DateTime.tryParse(
          row['last_read_at'] as String? ?? '',
        ),
    };

    final lastMessageByThread = <String, Map<String, dynamic>>{};
    final unreadCountByThread = <String, int>{};
    final messageIds = <String>[];

    for (final message in messages) {
      final threadId = message['thread_id'].toString();
      lastMessageByThread.putIfAbsent(threadId, () => message);
      messageIds.add(message['id'].toString());

      final lastReadAt = readsByThread[threadId];
      final createdAt =
          DateTime.tryParse(message['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);

      if (message['user_id'] == userId) {
        continue;
      }

      final isUnread =
          lastReadAt == null || createdAt.isAfter(lastReadAt.toUtc());
      if (isUnread) {
        unreadCountByThread[threadId] =
            (unreadCountByThread[threadId] ?? 0) + 1;
      }
    }

    final mentionCountByThread = <String, int>{};
    if (messageIds.isNotEmpty) {
      final mentionRows = await _client
          .from('team_message_mentions')
          .select('message_id, thread_id')
          .eq('mentioned_user_id', userId)
          .inFilter('thread_id', threadIds);

      final unreadMessageIds = {
        for (final message in messages)
          if ((message['user_id']?.toString() ?? '') != userId)
            if (readsByThread[message['thread_id'].toString()] == null ||
                (DateTime.tryParse(message['created_at'] as String? ?? '') ??
                        DateTime.fromMillisecondsSinceEpoch(0))
                    .isAfter(
                      readsByThread[message['thread_id'].toString()]!.toUtc(),
                    ))
              message['id'].toString(),
      };

      for (final row in (mentionRows as List).cast<Map<String, dynamic>>()) {
        final messageId = row['message_id'].toString();
        if (!unreadMessageIds.contains(messageId)) {
          continue;
        }
        final threadId = row['thread_id'].toString();
        mentionCountByThread[threadId] =
            (mentionCountByThread[threadId] ?? 0) + 1;
      }
    }

    final profileIds =
        {
          for (final message in lastMessageByThread.values)
            if (message['user_id'] != null) message['user_id'].toString(),
        }.toList();

    final profileNames = await _fetchProfileNames(profileIds);

    return rows.map((row) {
      final threadId = row['id'].toString();
      final lastMessage = lastMessageByThread[threadId];

      return TeamThread.fromJson({
        ...row,
        'last_message_preview': _buildPreview(lastMessage?['body'] as String?),
        'last_message_author':
            profileNames[lastMessage?['user_id']?.toString()],
        'unread_count': unreadCountByThread[threadId] ?? 0,
        'mention_count': mentionCountByThread[threadId] ?? 0,
      });
    }).toList();
  }

  Future<TeamThread?> getThreadById(String threadId) async {
    final row =
        await _client
            .from('team_threads')
            .select('*')
            .eq('id', threadId)
            .maybeSingle();

    if (row == null) return null;
    return TeamThread.fromJson(row);
  }

  Future<TeamThread> getOrCreateCardThread({
    required String teamId,
    required String cardId,
    String? fallbackTitle,
  }) async {
    final existing =
        await _client
            .from('team_threads')
            .select('*')
            .eq('team_id', teamId)
            .eq('type', TeamThreadType.card.dbValue)
            .eq('card_id', cardId)
            .maybeSingle();

    if (existing != null) {
      return TeamThread.fromJson(existing);
    }

    final cardRow =
        await _client
            .from('cards')
            .select('id, title, description')
            .eq('id', cardId)
            .maybeSingle();

    final title =
        (cardRow?['title'] as String?)?.trim().isNotEmpty == true
            ? (cardRow!['title'] as String).trim()
            : (fallbackTitle?.trim().isNotEmpty == true
                ? fallbackTitle!.trim()
                : 'Kart Konusmasi');

    final description =
        (cardRow?['description'] as String?)?.trim().isNotEmpty == true
            ? (cardRow!['description'] as String).trim()
            : 'Bu kartla ilgili kararlar ve guncellemeler burada toplanir.';

    return createThread(
      teamId: teamId,
      type: TeamThreadType.card,
      title: title,
      description: description,
      cardId: cardId,
      pinned: true,
    );
  }

  Future<TeamThread> getOrCreateTicketThread({
    required String teamId,
    required String ticketId,
    String? fallbackTitle,
  }) async {
    final normalizedTicketId = ticketId.trim();
    if (normalizedTicketId.isEmpty) {
      throw Exception('Gecerli bir is emri kimligi girilmedi.');
    }

    final existing =
        await _client
            .from('team_threads')
            .select('*')
            .eq('team_id', teamId)
            .eq('type', TeamThreadType.ticket.dbValue)
            .eq('ticket_id', normalizedTicketId)
            .maybeSingle();

    if (existing != null) {
      return TeamThread.fromJson(existing);
    }

    final ticketRow =
        await _client
            .from('tickets')
            .select('id, title, job_code, description')
            .eq('id', normalizedTicketId)
            .maybeSingle();

    final title =
        (ticketRow?['title'] as String?)?.trim().isNotEmpty == true
            ? (ticketRow!['title'] as String).trim()
            : (fallbackTitle?.trim().isNotEmpty == true
                ? fallbackTitle!.trim()
                : 'Is Emri #$normalizedTicketId');

    final jobCode = (ticketRow?['job_code'] as String?)?.trim();
    final description =
        jobCode?.isNotEmpty == true
            ? 'Is emri baglami: $jobCode'
            : 'Bu is emriyle ilgili takim kararlari burada toplanir.';

    return createThread(
      teamId: teamId,
      type: TeamThreadType.ticket,
      title: title,
      description: description,
      ticketId: normalizedTicketId,
      pinned: true,
    );
  }

  Future<List<TeamMessage>> getMessages(String threadId) async {
    final messageRows = await _client
        .from('team_messages')
        .select('*')
        .eq('thread_id', threadId)
        .order('created_at', ascending: true);

    final rows = (messageRows as List).cast<Map<String, dynamic>>();
    if (rows.isEmpty) return const [];

    final userIds =
        {
          for (final row in rows)
            if (row['user_id'] != null) row['user_id'].toString(),
        }.toList();
    final messageIds = rows.map((row) => row['id'].toString()).toList();

    final profileNames = await _fetchProfileNames(userIds);
    final mentionRows = await _client
        .from('team_message_mentions')
        .select('message_id, mentioned_user_id')
        .inFilter('message_id', messageIds);

    final mentionsByMessage = <String, List<String>>{};
    for (final row in (mentionRows as List).cast<Map<String, dynamic>>()) {
      final messageId = row['message_id'].toString();
      mentionsByMessage.putIfAbsent(messageId, () => []);
      mentionsByMessage[messageId]!.add(row['mentioned_user_id'].toString());
    }

    return rows.map((row) {
      return TeamMessage.fromJson({
        ...row,
        'author_name': profileNames[row['user_id']?.toString()],
        'mentioned_user_ids': mentionsByMessage[row['id']?.toString()] ?? [],
      });
    }).toList();
  }

  Future<TeamThread> createThread({
    required String teamId,
    required TeamThreadType type,
    required String title,
    String? description,
    String? cardId,
    String? ticketId,
    bool pinned = false,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('Kullanici oturumu bulunamadi.');
    }

    final data =
        await _client
            .from('team_threads')
            .insert({
              'team_id': teamId,
              'type': type.dbValue,
              'title': title.trim(),
              'description':
                  description?.trim().isEmpty ?? true
                      ? null
                      : description!.trim(),
              'card_id': cardId,
              'ticket_id': ticketId,
              'created_by': userId,
              'is_pinned': pinned,
            })
            .select()
            .single();

    return TeamThread.fromJson(data);
  }

  Future<void> sendMessage({
    required String teamId,
    required String threadId,
    required String body,
    List<String> mentionUserIds = const [],
    String? replyToId,
    String? attachmentUrl,
    TeamMessageType type = TeamMessageType.message,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      throw Exception('Kullanici oturumu bulunamadi.');
    }

    final trimmedBody = body.trim();
    if (trimmedBody.isEmpty &&
        (attachmentUrl == null || attachmentUrl.isEmpty)) {
      return;
    }

    final inserted =
        await _client
            .from('team_messages')
            .insert({
              'thread_id': threadId,
              'team_id': teamId,
              'user_id': userId,
              'body': trimmedBody,
              'message_type': type.dbValue,
              'reply_to_id': replyToId,
              'attachment_url': attachmentUrl,
            })
            .select('id')
            .single();

    final messageId = inserted['id'].toString();
    final uniqueMentions = mentionUserIds.toSet().where((id) => id != userId);
    if (uniqueMentions.isNotEmpty) {
      await _client
          .from('team_message_mentions')
          .insert(
            uniqueMentions
                .map(
                  (mentionedUserId) => {
                    'message_id': messageId,
                    'thread_id': threadId,
                    'team_id': teamId,
                    'mentioned_user_id': mentionedUserId,
                  },
                )
                .toList(),
          );
    }

    await markThreadRead(threadId, lastReadMessageId: messageId);
  }

  Future<void> markThreadRead(
    String threadId, {
    String? lastReadMessageId,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return;

    await _client.from('team_thread_reads').upsert({
      'thread_id': threadId,
      'user_id': userId,
      'last_read_message_id': lastReadMessageId,
      'last_read_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> deleteThread(String threadId) async {
    final thread = await getThreadById(threadId);
    if (thread == null) {
      return;
    }
    if (thread.type == TeamThreadType.general ||
        thread.type == TeamThreadType.announcement) {
      throw Exception('Genel ve duyuru kanallari silinemez.');
    }
    await _client.from('team_threads').delete().eq('id', threadId);
  }

  RealtimeChannel subscribeToTeamConversations(
    String teamId,
    VoidCallback onChange,
  ) {
    return _client
        .channel('team-conversations:$teamId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'team_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'team_id',
            value: teamId,
          ),
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'team_threads',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'team_id',
            value: teamId,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<Map<String, String>> _fetchProfileNames(List<String> userIds) async {
    if (userIds.isEmpty) return const {};

    final rows = await _client
        .from('profiles')
        .select('id, full_name, email')
        .inFilter('id', userIds);

    return {
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        row['id'].toString():
            (row['full_name'] as String?)?.trim().isNotEmpty == true
                ? row['full_name'].toString().trim()
                : (row['email'] as String?)?.trim().isNotEmpty == true
                ? row['email'].toString().trim()
                : 'Kullanici',
    };
  }

  String? _buildPreview(String? rawText) {
    final text = rawText?.trim();
    if (text == null || text.isEmpty) return null;
    if (text.length <= 72) return text;
    return '${text.substring(0, 72)}...';
  }
}

class ConversationTotalsSnapshot {
  const ConversationTotalsSnapshot({
    required this.unreadCount,
    required this.mentionCount,
  });

  final int unreadCount;
  final int mentionCount;
}
