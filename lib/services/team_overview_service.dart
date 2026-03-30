import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/app_logger.dart';
import '../models/team.dart';
import '../models/team_overview.dart';

class TeamOverviewService {
  TeamOverviewService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const AppLogger _logger = AppLogger('TeamOverviewService');
  final SupabaseClient _client;

  Future<List<TeamListSummary>> listTeamSummaries() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final membershipRows = await _client
          .from('team_members')
          .select('team_id, role, teams(*)')
          .eq('user_id', userId);

      final memberships = membershipRows as List<dynamic>;
      if (memberships.isEmpty) return [];

      final teamIds = <String>[];
      final teamsById = <String, Team>{};
      final rolesByTeamId = <String, TeamRole>{};

      for (final row in memberships) {
        final item = row as Map<String, dynamic>;
        final teamJson = item['teams'] as Map<String, dynamic>?;
        if (teamJson == null) continue;
        final team = Team.fromJson(teamJson);
        teamIds.add(team.id);
        teamsById[team.id] = team;
        rolesByTeamId[team.id] = TeamRole.fromString(item['role'] as String);
      }

      final memberRows = await _client
          .from('team_members')
          .select('team_id')
          .inFilter('team_id', teamIds);

      final cardRows = await _client
          .from('cards')
          .select('team_id, status, updated_at')
          .inFilter('team_id', teamIds);

      final memberCountByTeamId = <String, int>{};
      for (final row in memberRows as List<dynamic>) {
        final teamId = (row as Map<String, dynamic>)['team_id'] as String;
        memberCountByTeamId[teamId] = (memberCountByTeamId[teamId] ?? 0) + 1;
      }

      final totalByTeamId = <String, int>{};
      final activeByTeamId = <String, int>{};
      final completedByTeamId = <String, int>{};
      final lastActivityByTeamId = <String, DateTime?>{};

      for (final row in cardRows as List<dynamic>) {
        final item = row as Map<String, dynamic>;
        final teamId = item['team_id'] as String;
        final status = (item['status'] as String?) ?? 'TODO';
        final updatedAt = DateTime.tryParse(
          (item['updated_at'] as String?) ?? '',
        );

        totalByTeamId[teamId] = (totalByTeamId[teamId] ?? 0) + 1;

        if (status == 'TODO' || status == 'DOING') {
          activeByTeamId[teamId] = (activeByTeamId[teamId] ?? 0) + 1;
        }
        if (status == 'DONE' || status == 'SENT') {
          completedByTeamId[teamId] = (completedByTeamId[teamId] ?? 0) + 1;
        }

        final currentLatest = lastActivityByTeamId[teamId];
        if (updatedAt != null &&
            (currentLatest == null || updatedAt.isAfter(currentLatest))) {
          lastActivityByTeamId[teamId] = updatedAt;
        }
      }

      final summaries =
          teamIds.map((teamId) {
            final totalCards = totalByTeamId[teamId] ?? 0;
            final activeCards = activeByTeamId[teamId] ?? 0;
            final completedCards = completedByTeamId[teamId] ?? 0;
            final lastActivityAt = lastActivityByTeamId[teamId];

            return TeamListSummary(
              team: teamsById[teamId]!,
              role: rolesByTeamId[teamId] ?? TeamRole.member,
              memberCount: memberCountByTeamId[teamId] ?? 1,
              totalCards: totalCards,
              activeCards: activeCards,
              completedCards: completedCards,
              lastActivityAt: lastActivityAt,
              healthLevel: _resolveHealthLevel(
                activeCards: activeCards,
                lastActivityAt: lastActivityAt,
              ),
            );
          }).toList();

      summaries.sort((a, b) {
        final healthCompare = b.healthLevel.index.compareTo(
          a.healthLevel.index,
        );
        if (healthCompare != 0) return healthCompare;
        final activeCompare = b.activeCards.compareTo(a.activeCards);
        if (activeCompare != 0) return activeCompare;
        final aDate = a.lastActivityAt;
        final bDate = b.lastActivityAt;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      return summaries;
    } catch (error, stackTrace) {
      _logger.error(
        'list_team_summaries_failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<TeamOverviewSnapshot> getTeamOverview(String teamId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Oturum gerekli');
    }

    try {
      final teamResponse =
          await _client.from('teams').select().eq('id', teamId).single();
      final team = Team.fromJson(teamResponse as Map<String, dynamic>);

      final roleResponse =
          await _client
              .from('team_members')
              .select('role')
              .eq('team_id', teamId)
              .eq('user_id', userId)
              .maybeSingle();
      final role =
          roleResponse == null
              ? TeamRole.member
              : TeamRole.fromString(roleResponse['role'] as String);

      final memberRows = await _client
          .from('team_members')
          .select('user_id')
          .eq('team_id', teamId);

      final boardRows = await _client
          .from('boards')
          .select('id')
          .eq('team_id', teamId);

      final cardRows = await _client
          .from('cards')
          .select('id, title, status')
          .eq('team_id', teamId);

      final totalCards = (cardRows as List<dynamic>).length;
      int activeCards = 0;
      int completedCards = 0;
      final cardTitleById = <String, String>{};

      for (final row in cardRows) {
        final item = row as Map<String, dynamic>;
        final cardId = item['id'] as String;
        final status = (item['status'] as String?) ?? 'TODO';
        cardTitleById[cardId] = (item['title'] as String?) ?? 'Kart';

        if (status == 'TODO' || status == 'DOING') {
          activeCards++;
        }
        if (status == 'DONE' || status == 'SENT') {
          completedCards++;
        }
      }

      final eventRows = await _client
          .from('card_events')
          .select('id, card_id, event_type, created_at, to_status')
          .eq('team_id', teamId)
          .order('created_at', ascending: false)
          .limit(6);

      final activities =
          (eventRows as List<dynamic>).map((row) {
            final item = row as Map<String, dynamic>;
            final eventType = (item['event_type'] as String?) ?? 'UPDATED';
            final cardId = item['card_id'] as String?;
            final title = cardTitleById[cardId] ?? 'Kart';
            return TeamRecentActivity(
              id: item['id'] as String,
              title: _eventLabel(eventType),
              description: title,
              createdAt: DateTime.parse(item['created_at'] as String),
            );
          }).toList();

      return TeamOverviewSnapshot(
        team: team,
        role: role,
        memberCount: (memberRows as List<dynamic>).length,
        boardCount: (boardRows as List<dynamic>).length,
        totalCards: totalCards,
        activeCards: activeCards,
        completedCards: completedCards,
        completionRate: totalCards == 0 ? 0 : completedCards / totalCards,
        recentActivities: activities,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'get_team_overview_failed',
        data: {'teamId': teamId},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  TeamHealthLevel _resolveHealthLevel({
    required int activeCards,
    required DateTime? lastActivityAt,
  }) {
    if (activeCards >= 8) {
      return TeamHealthLevel.critical;
    }

    if (activeCards >= 3) {
      return TeamHealthLevel.attention;
    }

    if (lastActivityAt == null) {
      return TeamHealthLevel.stable;
    }

    final daysSinceActivity = DateTime.now().difference(lastActivityAt).inDays;
    if (daysSinceActivity >= 7 && activeCards > 0) {
      return TeamHealthLevel.attention;
    }

    return TeamHealthLevel.stable;
  }

  String _eventLabel(String eventType) {
    switch (eventType) {
      case 'CARD_CREATED':
        return 'Yeni kart olusturuldu';
      case 'STATUS_CHANGED':
        return 'Kart durumu guncellendi';
      case 'ASSIGNEE_CHANGED':
        return 'Kart atamasi degisti';
      case 'COMMENTED':
        return 'Kart yorumu eklendi';
      case 'UPDATED':
      default:
        return 'Kart guncellendi';
    }
  }
}
