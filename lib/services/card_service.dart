import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/card.dart';
import '../models/card_event.dart';

class CardService {
  final _supabase = Supabase.instance.client;

  Future<List<KanbanCard>> getBoardCards(String boardId) async {
    // 1. Kartları çek
    final response = await _supabase
        .from('cards')
        .select()
        .eq('board_id', boardId)
        .order('created_at', ascending: false);

    final List<dynamic> cardsData = response;
    
    // 2. Assignee ID'leri topla
    final assigneeIds = cardsData
        .map((c) => c['assignee_id'])
        .where((id) => id != null)
        .toList();

    // 3. Profilleri çek (Manuel Join - Code Side)
    Map<String, Map<String, dynamic>> profilesMap = {};
    if (assigneeIds.isNotEmpty) {
      try {
        final profiles = await _supabase
            .from('profiles')
            .select('id, full_name') // CSV'deki kolonlar
            .inFilter('id', assigneeIds);
            
        for (var p in profiles) {
          profilesMap[p['id']] = p;
        }
      } catch (e) {
        print('Profil verisi çekilemedi: $e');
      }
    }

    // 4. Verileri kod tarafında birleştir
    return cardsData.map((c) {
      final assigneeId = c['assignee_id'];
      final profile = profilesMap[assigneeId];
      
      final merged = Map<String, dynamic>.from(c);
      if (profile != null) {
        merged['profiles'] = profile;
      }
      return KanbanCard.fromJson(merged);
    }).toList();
  }

  Future<KanbanCard> getCard(String cardId) async {
    final response = await _supabase
        .from('cards')
        .select()
        .eq('id', cardId)
        .single();
    return KanbanCard.fromJson(response);
  }

  Future<List<CardEvent>> getCardHistory(String cardId) async {
    final response = await _supabase
        .from('card_events')
        .select()
        .eq('card_id', cardId)
        .order('created_at', ascending: false);

    return (response as List).map((e) => CardEvent.fromJson(e)).toList();
  }

  Future<KanbanCard> createCard({
    required String teamId,
    required String boardId,
    required String title,
    String? description,
    CardStatus status = CardStatus.todo,
    String? assigneeId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Oturum gerekli');

    final data = {
      'team_id': teamId,
      'board_id': boardId,
      'title': title,
      'description': description,
      'status': status.toDb,
      'created_by': user.id,
      'assignee_id': assigneeId,
    };

    final response = await _supabase
        .from('cards')
        .insert(data)
        .select()
        .single();

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
    final cardData = await _supabase
        .from('cards')
        .select('team_id, status')
        .eq('id', cardId)
        .single();
    
    final oldStatus = cardData['status'];
    final teamId = cardData['team_id'];

    if (oldStatus == newStatus.toDb) return;

    await _supabase.from('cards').update({
      'status': newStatus.toDb,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', cardId);

    await _logEvent(
      teamId: teamId,
      cardId: cardId,
      eventType: 'STATUS_CHANGED',
      fromStatus: oldStatus,
      toStatus: newStatus.toDb,
    );
  }

  Future<void> updateCardDetails(String cardId, {String? title, String? description}) async {
    final cardData = await _supabase
        .from('cards')
        .select('team_id')
        .eq('id', cardId)
        .single();
    
    final teamId = cardData['team_id'];

    await _supabase.from('cards').update({
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', cardId);

    await _logEvent(
      teamId: teamId,
      cardId: cardId,
      eventType: 'UPDATED',
    );
  }

  Future<void> deleteCard(String cardId) async {
     await _supabase.from('cards').delete().eq('id', cardId);
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
