import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/card.dart';
import '../models/card_event.dart';
import '../models/card_comment.dart';
import '../models/card_linked_ticket.dart';
import '../models/ticket_linked_team_card.dart';
import '../models/ticket_status.dart';

class CardService {
  final _supabase = Supabase.instance.client;
  bool? _supportsLinkedTicketingCache;

  String? _normalizeLinkedTicketId(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Exception _friendlyCardSchemaError(PostgrestException error) {
    final message = error.message.toLowerCase();
    if (message.contains('linked_ticket_id') &&
        message.contains('schema cache')) {
      return Exception(
        'Supabase cards tablosunda linked_ticket_id kolonu eksik. '
        'Is emri baglama ozelligi icin migration_card_notes_and_ticket_link.sql calistirilmali.',
      );
    }
    return Exception(error.message);
  }

  Future<bool> supportsLinkedTicketing() async {
    if (_supportsLinkedTicketingCache != null) {
      return _supportsLinkedTicketingCache!;
    }

    try {
      await _supabase.from('cards').select('linked_ticket_id').limit(1);
      _supportsLinkedTicketingCache = true;
      return true;
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('linked_ticket_id') &&
          message.contains('schema cache')) {
        _supportsLinkedTicketingCache = false;
        return false;
      }
      rethrow;
    }
  }

  Future<List<KanbanCard>> getBoardCards(String boardId) async {
    final response = await _supabase
        .from('cards')
        .select()
        .eq('board_id', boardId)
        .order('created_at', ascending: false);

    final cardsData =
        (response as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
    return _enrichCards(cardsData);
  }

  Future<List<TicketLinkedTeamCard>> getLinkedCardsForTicket(
    String ticketId,
  ) async {
    final normalizedTicketId = _normalizeLinkedTicketId(ticketId);
    if (normalizedTicketId == null) {
      return const [];
    }

    final supportsLinkedTicketingEnabled = await supportsLinkedTicketing();
    if (!supportsLinkedTicketingEnabled) {
      return const [];
    }

    final response = await _supabase
        .from('cards')
        .select(
          'id, board_id, team_id, title, description, status, assignee_id, '
          'priority, due_date, created_at, updated_at',
        )
        .eq('linked_ticket_id', normalizedTicketId)
        .order('updated_at', ascending: false);

    final rows =
        (response as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
    if (rows.isEmpty) {
      return const [];
    }

    final assigneeIds =
        rows
            .map((row) => row['assignee_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();
    final teamIds =
        rows
            .map((row) => row['team_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();
    final boardIds =
        rows
            .map((row) => row['board_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();

    final profilesById = await _fetchProfilesById(assigneeIds);
    final teamNamesById = await _fetchNamesById('teams', teamIds);
    final boardNamesById = await _fetchNamesById('boards', boardIds);

    return rows.map((row) {
      final teamId = row['team_id'].toString();
      final boardId = row['board_id'].toString();
      final assigneeId = row['assignee_id']?.toString();
      final assigneeName =
          assigneeId == null
              ? null
              : (profilesById[assigneeId]?['full_name']?.toString() ??
                  profilesById[assigneeId]?['email']?.toString());

      return TicketLinkedTeamCard(
        cardId: row['id'].toString(),
        teamId: teamId,
        teamName: teamNamesById[teamId] ?? 'Takim',
        boardId: boardId,
        boardName: boardNamesById[boardId] ?? 'Pano',
        title: row['title']?.toString() ?? 'Basliksiz kart',
        description: row['description']?.toString(),
        status: CardStatus.fromDb(row['status']?.toString() ?? 'TODO'),
        priority: CardPriority.fromDb(row['priority'] as String?),
        assigneeId: assigneeId,
        assigneeName: assigneeName,
        dueDate:
            (row['due_date'] as String?)?.isNotEmpty == true
                ? DateTime.tryParse(row['due_date'] as String)
                : null,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
    }).toList();
  }

  Future<KanbanCard> getCard(String cardId) async {
    final response =
        await _supabase.from('cards').select().eq('id', cardId).single();
    final items = await _enrichCards([
      Map<String, dynamic>.from(response as Map),
    ]);
    return items.first;
  }

  Future<List<CardEvent>> getCardHistory(String cardId) async {
    final response = await _supabase
        .from('card_events')
        .select()
        .eq('card_id', cardId)
        .order('created_at', ascending: false);

    return (response as List).map((item) => CardEvent.fromJson(item)).toList();
  }

  Future<KanbanCard> createCard({
    required String teamId,
    required String boardId,
    required String title,
    String? description,
    CardStatus status = CardStatus.todo,
    String? assigneeId,
    String? linkedTicketId,
    CardPriority priority = CardPriority.normal,
    DateTime? dueDate,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Oturum gerekli');
    final normalizedLinkedTicketId = _normalizeLinkedTicketId(linkedTicketId);

    final payload = <String, dynamic>{
      'team_id': teamId,
      'board_id': boardId,
      'title': title,
      'description': description,
      'status': status.toDb,
      'created_by': user.id,
      'assignee_id': assigneeId,
      if (normalizedLinkedTicketId != null)
        'linked_ticket_id': normalizedLinkedTicketId,
      'priority': priority.dbValue,
      'due_date': dueDate?.toUtc().toIso8601String(),
    };

    late final Map<String, dynamic> response;
    try {
      response = Map<String, dynamic>.from(
        await _supabase.from('cards').insert(payload).select().single() as Map,
      );
    } on PostgrestException catch (error) {
      throw _friendlyCardSchemaError(error);
    }

    await _logEvent(
      teamId: teamId,
      cardId: response['id'],
      eventType: 'CARD_CREATED',
      toStatus: status.toDb,
      toAssignee: assigneeId,
    );

    return KanbanCard.fromJson(response);
  }

  Future<void> updateCardStatus(String cardId, CardStatus newStatus) async {
    final cardData =
        await _supabase
            .from('cards')
            .select('team_id, status')
            .eq('id', cardId)
            .single();

    final oldStatus = cardData['status'];
    final teamId = cardData['team_id'];

    if (oldStatus == newStatus.toDb) return;

    await _supabase
        .from('cards')
        .update({
          'status': newStatus.toDb,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', cardId);

    await _logEvent(
      teamId: teamId,
      cardId: cardId,
      eventType: 'STATUS_CHANGED',
      fromStatus: oldStatus,
      toStatus: newStatus.toDb,
    );
  }

  Future<void> updateCardDetails(
    String cardId, {
    String? title,
    String? description,
    String? assigneeId,
    String? linkedTicketId,
    CardPriority? priority,
    DateTime? dueDate,
    bool updateDueDate = false,
    bool updateAssignee = false,
    bool updateLinkedTicket = false,
  }) async {
    final normalizedLinkedTicketId = _normalizeLinkedTicketId(linkedTicketId);
    final cardData =
        await _supabase
            .from('cards')
            .select('team_id')
            .eq('id', cardId)
            .single();

    final teamId = cardData['team_id'];

    try {
      await _supabase
          .from('cards')
          .update({
            if (title != null) 'title': title,
            if (description != null) 'description': description,
            if (priority != null) 'priority': priority.dbValue,
            if (updateDueDate) 'due_date': dueDate?.toUtc().toIso8601String(),
            if (updateAssignee) 'assignee_id': assigneeId,
            if (updateLinkedTicket)
              'linked_ticket_id': normalizedLinkedTicketId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', cardId);
    } on PostgrestException catch (error) {
      throw _friendlyCardSchemaError(error);
    }

    await _logEvent(teamId: teamId, cardId: cardId, eventType: 'UPDATED');
  }

  Future<void> deleteCard(String cardId) async {
    await _supabase.from('cards').delete().eq('id', cardId);
  }

  Future<List<CardLinkedTicket>> getLinkableTickets() async {
    try {
      final response = await _supabase
          .from('tickets')
          .select('id, job_code, title, status')
          .inFilter('status', TicketStatus.activeStatuses.toList())
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map(
            (item) => CardLinkedTicket.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<CardComment>> getCardComments(String cardId) async {
    final response = await _supabase
        .from('card_comments')
        .select()
        .eq('card_id', cardId)
        .order('created_at', ascending: false);

    final rows =
        (response as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
    if (rows.isEmpty) return const [];

    final userIds =
        rows
            .map((row) => row['user_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();

    final profilesById = await _fetchProfilesById(userIds);
    return rows.map((row) {
      final userId = row['user_id']?.toString();
      if (userId != null && profilesById.containsKey(userId)) {
        row['profiles'] = profilesById[userId];
      }
      return CardComment.fromJson(row);
    }).toList();
  }

  Future<void> addCardComment({
    required String cardId,
    required String teamId,
    required String comment,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Oturum gerekli');

    final trimmedComment = comment.trim();
    if (trimmedComment.isEmpty) return;

    await _supabase.from('card_comments').insert({
      'card_id': cardId,
      'team_id': teamId,
      'user_id': user.id,
      'comment': trimmedComment,
    });

    await _logEvent(teamId: teamId, cardId: cardId, eventType: 'COMMENTED');
  }

  Future<void> updateCardComment(String commentId, String comment) async {
    final trimmedComment = comment.trim();
    if (trimmedComment.isEmpty) return;

    await _supabase
        .from('card_comments')
        .update({'comment': trimmedComment})
        .eq('id', commentId);
  }

  Future<void> deleteCardComment(String commentId) async {
    await _supabase.from('card_comments').delete().eq('id', commentId);
  }

  Future<List<KanbanCard>> _enrichCards(
    List<Map<String, dynamic>> cardsData,
  ) async {
    final assigneeIds =
        cardsData
            .map((card) => card['assignee_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();

    final linkedTicketIds =
        cardsData
            .map((card) => card['linked_ticket_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();

    final profilesById = await _fetchProfilesById(assigneeIds);
    final ticketsById = await _fetchTicketsById(linkedTicketIds);

    return cardsData.map((item) {
      final assigneeId = item['assignee_id']?.toString();
      if (assigneeId != null && profilesById.containsKey(assigneeId)) {
        item['profiles'] = profilesById[assigneeId];
      }

      final linkedTicketId = item['linked_ticket_id']?.toString();
      if (linkedTicketId != null && ticketsById.containsKey(linkedTicketId)) {
        item['linked_ticket'] = ticketsById[linkedTicketId];
      }

      return KanbanCard.fromJson(item);
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> _fetchProfilesById(
    List<String> userIds,
  ) async {
    final profilesById = <String, Map<String, dynamic>>{};
    if (userIds.isEmpty) return profilesById;

    try {
      final profiles = await _supabase
          .from('profiles')
          .select('id, full_name, email')
          .inFilter('id', userIds);

      for (final profile in profiles as List<dynamic>) {
        final item = profile as Map<String, dynamic>;
        profilesById[item['id'].toString()] = item;
      }
    } catch (_) {
      // Profil join'i olmasa da akis devam eder.
    }

    return profilesById;
  }

  Future<Map<String, String>> _fetchNamesById(
    String table,
    List<String> ids,
  ) async {
    final namesById = <String, String>{};
    if (ids.isEmpty) return namesById;

    try {
      final rows = await _supabase
          .from(table)
          .select('id, name')
          .inFilter('id', ids);

      for (final row in rows as List<dynamic>) {
        final item = row as Map<String, dynamic>;
        final id = item['id']?.toString();
        final name = item['name']?.toString();
        if (id == null || id.isEmpty || name == null || name.isEmpty) {
          continue;
        }
        namesById[id] = name;
      }
    } catch (_) {
      // Etiket bilgisi gelmese de kart listesi acilmaya devam eder.
    }

    return namesById;
  }

  Future<Map<String, Map<String, dynamic>>> _fetchTicketsById(
    List<String> ticketIds,
  ) async {
    final ticketsById = <String, Map<String, dynamic>>{};
    if (ticketIds.isEmpty) return ticketsById;

    try {
      final tickets = await _supabase
          .from('tickets')
          .select('id, job_code, title, status')
          .inFilter('id', ticketIds);

      for (final ticket in tickets as List<dynamic>) {
        final item = ticket as Map<String, dynamic>;
        ticketsById[item['id'].toString()] = item;
      }
    } catch (_) {
      // Ticket join'i migration eksik ya da tip uyumsuz olsa bile akis devam eder.
    }

    return ticketsById;
  }

  Future<void> _logEvent({
    required String teamId,
    required String cardId,
    required String eventType,
    String? fromStatus,
    String? toStatus,
    String? fromAssignee,
    String? toAssignee,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('card_events').insert({
      'team_id': teamId,
      'card_id': cardId,
      'user_id': user.id,
      'event_type': eventType,
      'from_status': fromStatus,
      'to_status': toStatus,
      'from_assignee': fromAssignee,
      'to_assignee': toAssignee,
    });
  }
}
