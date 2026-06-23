import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/card.dart';
import '../models/card_event.dart';
import '../models/card_comment.dart';
import '../models/card_linked_ticket.dart';
import '../models/ticket_linked_team_card.dart';
import '../models/ticket_status.dart';
import 'notification_service.dart';

class CardService {
  final _supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();
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

  String _workshopHaystack(String? title, String? description) {
    return '${title ?? ''} ${description ?? ''}'
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ç', 'c')
        .replaceAll('Ã¶', 'o')
        .replaceAll('Ã¼', 'u')
        .replaceAll('ÅŸ', 's')
        .replaceAll('ÄŸ', 'g')
        .replaceAll('Ã§', 'c');
  }

  bool _isWorkshopCardText(String? title, String? description) {
    final haystack = _workshopHaystack(title, description);
    return haystack.contains('atolye') ||
        haystack.contains('uretim') ||
        haystack.contains('[atolye]') ||
        haystack.contains('workshop_recipe_json') ||
        haystack.contains('uretim recetesi');
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

  Future<List<TicketLinkedTeamCard>> getWorkshopCards() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];

    final supportsLinkedTicketingEnabled = await supportsLinkedTicketing();
    if (!supportsLinkedTicketingEnabled) {
      return const [];
    }

    final memberships = await _supabase
        .from('team_members')
        .select('team_id')
        .eq('user_id', userId);
    final teamIds =
        (memberships as List<dynamic>)
            .map((row) => (row as Map<String, dynamic>)['team_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();
    if (teamIds.isEmpty) return const [];

    final response = await _supabase
        .from('cards')
        .select(
          'id, board_id, team_id, title, description, status, assignee_id, '
          'priority, due_date, created_at, updated_at, linked_ticket_id',
        )
        .inFilter('team_id', teamIds)
        .not('linked_ticket_id', 'is', null)
        .order('updated_at', ascending: false);

    final rows =
        (response as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .where((row) {
              final title = row['title']?.toString().toLowerCase() ?? '';
              final description =
                  row['description']?.toString().toLowerCase() ?? '';
              return title.contains('atolye') ||
                  title.contains('atölye') ||
                  title.contains('uretim') ||
                  title.contains('üretim') ||
                  description.contains('[atolye]') ||
                  description.contains('[atölye]') ||
                  description.contains('uretim recetesi') ||
                  description.contains('üretim reçetesi');
            })
            .toList();
    if (rows.isEmpty) return const [];

    final assigneeIds =
        rows
            .map((row) => row['assignee_id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();
    final teamRowIds =
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
    final teamNamesById = await _fetchNamesById('teams', teamRowIds);
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
        title: row['title']?.toString() ?? 'Atolye imalat emri',
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

  Future<TicketLinkedTeamCard?> getWorkshopCardForTicket(
    String ticketId,
  ) async {
    final linkedCards = await getLinkedCardsForTicket(ticketId);
    for (final card in linkedCards) {
      final isKnownWorkshop = _isWorkshopCardText(card.title, card.description);
      if (isKnownWorkshop) {
        if (card.status != CardStatus.done) {
          return card;
        }
        continue;
      }
      final title = card.title.toLowerCase();
      final description = (card.description ?? '').toLowerCase();
      final isWorkshop =
          title.contains('atolye') ||
          title.contains('atölye') ||
          title.contains('uretim') ||
          title.contains('üretim') ||
          description.contains('[atolye]') ||
          description.contains('[atölye]') ||
          description.contains('workshop_recipe_json') ||
          description.contains('uretim recetesi') ||
          description.contains('üretim reçetesi');
      if (isWorkshop && card.status != CardStatus.done) {
        return card;
      }
    }
    return null;
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

    await _notificationService.notifyCardCreated(
      teamId: teamId,
      cardId: response['id'].toString(),
      cardTitle: response['title']?.toString() ?? title,
      assigneeName: null,
    );

    if (assigneeId != null && assigneeId.trim().isNotEmpty) {
      await _notificationService.notifyCardAssigned(
        teamId: teamId,
        cardId: response['id'].toString(),
        cardTitle: response['title']?.toString() ?? title,
        assigneeId: assigneeId,
      );
    }

    return KanbanCard.fromJson(response);
  }

  Future<void> updateCardStatus(String cardId, CardStatus newStatus) async {
    final cardData =
        await _supabase
            .from('cards')
            .select('team_id, title, status')
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

    await _notificationService.notifyCardStatusChanged(
      teamId: teamId.toString(),
      cardId: cardId,
      cardTitle: cardData['title']?.toString() ?? 'Kart',
      oldStatus: oldStatus.toString(),
      newStatus: newStatus.toDb,
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
            .select(
              'team_id, title, description, assignee_id, linked_ticket_id, priority, due_date',
            )
            .eq('id', cardId)
            .single();

    final teamId = cardData['team_id'];
    final previousTitle = cardData['title']?.toString() ?? 'Kart';
    final previousDescription = cardData['description']?.toString();
    final previousAssigneeId = cardData['assignee_id']?.toString();
    final previousLinkedTicketId = cardData['linked_ticket_id']?.toString();
    final previousPriority = cardData['priority']?.toString();
    final previousDueDate = cardData['due_date']?.toString();
    final nextTitle = title ?? previousTitle;
    final nextDescription = description ?? previousDescription;
    final nextAssigneeId = updateAssignee ? assigneeId : previousAssigneeId;
    final nextLinkedTicketId =
        updateLinkedTicket ? normalizedLinkedTicketId : previousLinkedTicketId;
    final nextPriority = priority?.dbValue ?? previousPriority;
    final nextDueDateIso =
        updateDueDate ? dueDate?.toUtc().toIso8601String() : previousDueDate;
    final hasMeaningfulChange =
        nextTitle != previousTitle ||
        nextDescription != previousDescription ||
        nextAssigneeId != previousAssigneeId ||
        nextLinkedTicketId != previousLinkedTicketId ||
        nextPriority != previousPriority ||
        nextDueDateIso != previousDueDate;

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

    if (hasMeaningfulChange) {
      final recipientUserIds = await _getTeamMemberIds(
        teamId.toString(),
        excludeUserIds: {(_supabase.auth.currentUser?.id ?? '').trim()},
      );

      await _notificationService.notifyCardUpdated(
        teamId: teamId.toString(),
        cardId: cardId,
        cardTitle: nextTitle,
        recipientUserIds: recipientUserIds,
      );
    }

    if (updateAssignee &&
        nextAssigneeId != null &&
        nextAssigneeId.isNotEmpty &&
        nextAssigneeId != previousAssigneeId) {
      await _notificationService.notifyCardAssigned(
        teamId: teamId.toString(),
        cardId: cardId,
        cardTitle: nextTitle,
        assigneeId: nextAssigneeId,
      );
    }
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

    final cardDetails =
        await _supabase
            .from('cards')
            .select('title, created_by, assignee_id')
            .eq('id', cardId)
            .maybeSingle();

    final recipientUserIds =
        [
              cardDetails?['created_by']?.toString(),
              cardDetails?['assignee_id']?.toString(),
            ]
            .where((userId) => userId != null && userId.trim().isNotEmpty)
            .cast<String>()
            .where((userId) => userId != user.id)
            .toSet()
            .toList();

    await _notificationService.notifyCardCommented(
      teamId: teamId,
      cardId: cardId,
      cardTitle: cardDetails?['title']?.toString() ?? 'Kart',
      recipientUserIds: recipientUserIds,
    );
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

  Future<List<String>> _getTeamMemberIds(
    String teamId, {
    Set<String> excludeUserIds = const {},
  }) async {
    final response = await _supabase
        .from('team_members')
        .select('user_id')
        .eq('team_id', teamId);

    return (response as List<dynamic>)
        .map((row) => (row as Map<String, dynamic>)['user_id']?.toString())
        .where((userId) => userId != null && userId.isNotEmpty)
        .cast<String>()
        .where((userId) => !excludeUserIds.contains(userId))
        .toSet()
        .toList();
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
