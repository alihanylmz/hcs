import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/app_logger.dart';
import '../models/team.dart';
import '../models/team_member.dart';
import '../models/user_profile.dart';

class TeamService {
  TeamService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  static const AppLogger _logger = AppLogger('TeamService');
  static const String _createTeamRpcName = 'create_team_with_owner';
  static const String _listInvitableUsersRpcName =
      'list_team_invitable_profiles';
  final SupabaseClient _supabase;
  bool? _supportsTeamVisualIdentityCache;

  Future<List<Team>> listTeams() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('team_members')
          .select('team_id, teams(*)')
          .eq('user_id', userId);

      final teams = <Team>[];
      for (final item in response as List<dynamic>) {
        final row = item as Map<String, dynamic>;
        final teamJson = row['teams'] as Map<String, dynamic>?;
        if (teamJson == null) continue;
        teams.add(Team.fromJson(teamJson));
      }
      return teams;
    } catch (error, stackTrace) {
      _logger.error('list_teams_failed', error: error, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<Team> createTeam({
    required String name,
    String? description,
    String? emoji,
    String? accentColor,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Kullanici oturumu bulunamadi.');
    }

    final trimmedName = name.trim();
    final normalizedDescription = _normalizeOptionalText(description);
    final normalizedEmoji = Team.normalizeEmoji(emoji);
    final normalizedAccentColor = Team.normalizeAccentColor(accentColor);
    final wantsCustomStyle =
        normalizedEmoji != Team.defaultEmoji ||
        normalizedAccentColor != Team.defaultAccentColor;

    if (trimmedName.isEmpty) {
      throw Exception('Takim adi zorunludur.');
    }

    if (wantsCustomStyle) {
      final supportsVisualIdentity = await supportsTeamVisualIdentity();
      if (!supportsVisualIdentity) {
        throw Exception(
          'Takim karti emoji ve renk secimi icin migration_team_visual_identity.sql calistirilmali.',
        );
      }
    }

    try {
      final teamData = await _createTeamWithRpc(
        name: trimmedName,
        description: normalizedDescription,
      );
      var team = Team.fromJson(teamData);
      if (wantsCustomStyle) {
        team = await updateTeamAppearance(
          teamId: team.id,
          emoji: normalizedEmoji,
          accentColor: normalizedAccentColor,
        );
      }
      return team;
    } on PostgrestException catch (error, stackTrace) {
      if (_isMissingCreateTeamRpc(error)) {
        _logger.warning(
          'create_team_rpc_missing_fallback',
          data: {'name': trimmedName},
          error: error,
          stackTrace: stackTrace,
        );
      } else {
        _logger.error(
          'create_team_rpc_failed',
          data: {'name': trimmedName},
          error: error,
          stackTrace: stackTrace,
        );
        throw _mapCreateTeamError(error);
      }
    } catch (error, stackTrace) {
      _logger.error(
        'create_team_rpc_failed',
        data: {'name': trimmedName},
        error: error,
        stackTrace: stackTrace,
      );
      throw _mapCreateTeamError(error);
    }

    try {
      final teamData = await _createTeamLegacy(
        userId: user.id,
        name: trimmedName,
        description: normalizedDescription,
      );
      var team = Team.fromJson(teamData);
      if (wantsCustomStyle) {
        team = await updateTeamAppearance(
          teamId: team.id,
          emoji: normalizedEmoji,
          accentColor: normalizedAccentColor,
        );
      }
      return team;
    } catch (error, stackTrace) {
      _logger.error(
        'create_team_failed',
        data: {'name': trimmedName},
        error: error,
        stackTrace: stackTrace,
      );
      throw _mapCreateTeamError(error);
    }
  }

  String? _normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<Map<String, dynamic>> _createTeamWithRpc({
    required String name,
    String? description,
  }) async {
    final response = await _supabase.rpc(
      _createTeamRpcName,
      params: {'p_name': name, 'p_description': description},
    );
    return _decodeTeamRow(response);
  }

  Future<Map<String, dynamic>> _createTeamLegacy({
    required String userId,
    required String name,
    String? description,
  }) async {
    final teamData =
        await _supabase
            .from('teams')
            .insert({
              'name': name,
              'description': description,
              'created_by': userId,
            })
            .select()
            .single();

    final team = Team.fromJson(_decodeTeamRow(teamData));

    await _supabase.from('team_members').insert({
      'team_id': team.id,
      'user_id': userId,
      'role': TeamRole.owner.name,
      'invited_by': userId,
    });

    return team.toJson();
  }

  Map<String, dynamic> _decodeTeamRow(dynamic response) {
    if (response is Map<String, dynamic>) {
      return response;
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }

    throw Exception('Takim olusturma yaniti beklenen formatta degil.');
  }

  Future<List<UserProfile>> listInvitableUsers(String teamId) async {
    final normalizedTeamId = teamId.trim();
    if (normalizedTeamId.isEmpty) {
      throw Exception('Gecerli bir takim secin.');
    }

    try {
      final response = await _supabase.rpc(
        _listInvitableUsersRpcName,
        params: {'p_team_id': normalizedTeamId},
      );

      return (response as List<dynamic>)
          .map(
            (row) =>
                UserProfile.fromJson(Map<String, dynamic>.from(row as Map)),
          )
          .toList()
        ..sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
    } on PostgrestException catch (error, stackTrace) {
      _logger.error(
        'list_invitable_users_failed',
        data: {'teamId': normalizedTeamId},
        error: error,
        stackTrace: stackTrace,
      );
      if (_isMissingListInvitableUsersRpc(error)) {
        throw Exception(
          'Takim davet listesi icin fix_profiles_policy.sql calistirilmali.',
        );
      }
      rethrow;
    } catch (error, stackTrace) {
      _logger.error(
        'list_invitable_users_failed',
        data: {'teamId': normalizedTeamId},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<bool> supportsTeamVisualIdentity() async {
    if (_supportsTeamVisualIdentityCache != null) {
      return _supportsTeamVisualIdentityCache!;
    }

    try {
      await _supabase.from('teams').select('emoji, accent_color').limit(1);
      _supportsTeamVisualIdentityCache = true;
      return true;
    } on PostgrestException catch (error) {
      if (_isMissingTeamVisualIdentityColumns(error)) {
        _supportsTeamVisualIdentityCache = false;
        return false;
      }
      rethrow;
    }
  }

  Future<Team> updateTeamAppearance({
    required String teamId,
    required String emoji,
    required String accentColor,
  }) async {
    final response =
        await _supabase
            .from('teams')
            .update({
              'emoji': Team.normalizeEmoji(emoji),
              'accent_color': Team.normalizeAccentColor(accentColor),
            })
            .eq('id', teamId)
            .select()
            .single();

    return Team.fromJson(_decodeTeamRow(response));
  }

  bool _isMissingCreateTeamRpc(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains(_createTeamRpcName) &&
        (message.contains('schema cache') ||
            message.contains('not found') ||
            error.code == '42883');
  }

  bool _isMissingListInvitableUsersRpc(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains(_listInvitableUsersRpcName) &&
        (message.contains('schema cache') ||
            message.contains('not found') ||
            error.code == '42883');
  }

  bool _isMissingTeamVisualIdentityColumns(PostgrestException error) {
    final message = error.message.toLowerCase();
    final mentionsVisualIdentityColumns =
        message.contains('emoji') || message.contains('accent_color');
    final looksLikeSchemaIssue =
        message.contains('schema cache') ||
        message.contains('column') ||
        message.contains('does not exist') ||
        error.code == '42703';
    return mentionsVisualIdentityColumns && looksLikeSchemaIssue;
  }

  Exception _mapCreateTeamError(Object error) {
    if (error is PostgrestException) {
      final message = error.message;
      final normalized = message.toLowerCase();
      final missingTeamTables =
          (normalized.contains('team_members') ||
              normalized.contains('teams')) &&
          (normalized.contains('does not exist') ||
              normalized.contains('relation') ||
              normalized.contains('schema cache'));
      if (missingTeamTables) {
        return Exception(
          'Takim altyapisi Supabase tarafinda hazir degil. '
          'migration_team_kanban.sql veya migration_team_workspace_all_in_one.sql calistirilmali.',
        );
      }

      final looksLikeConversationTriggerRlsIssue =
          normalized.contains('team_threads') &&
          (normalized.contains('row-level security') ||
              normalized.contains('violates row-level security') ||
              normalized.contains('permission denied'));
      if (looksLikeConversationTriggerRlsIssue) {
        return Exception(
          'Takim olusturma, eski takim konusmalari tetikleyicisi nedeniyle engelleniyor. '
          'migration_fix_team_creation_rpc.sql calistirilmali.',
        );
      }

      return Exception(message);
    }

    if (error is Exception) {
      return error;
    }

    return Exception(error.toString());
  }

  Future<TeamRole> getCurrentUserRole(String teamId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return TeamRole.member;

    try {
      final response =
          await _supabase
              .from('team_members')
              .select('role')
              .eq('team_id', teamId)
              .eq('user_id', userId)
              .maybeSingle();

      if (response == null) {
        return TeamRole.member;
      }

      return TeamRole.fromString(response['role'] as String? ?? 'member');
    } catch (error, stackTrace) {
      _logger.error(
        'get_current_user_role_failed',
        data: {'teamId': teamId},
        error: error,
        stackTrace: stackTrace,
      );
      return TeamRole.member;
    }
  }

  Future<List<TeamMember>> getTeamMembers(String teamId) async {
    try {
      final response = await _supabase
          .from('team_members')
          .select('id, team_id, user_id, role, joined_at')
          .eq('team_id', teamId)
          .order('joined_at', ascending: true);

      final memberRows =
          (response as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map(Map<String, dynamic>.from)
              .toList();

      final userIds =
          memberRows
              .map((row) => row['user_id']?.toString())
              .where((id) => id != null && id.isNotEmpty)
              .cast<String>()
              .toList();

      final profilesById = await _fetchProfilesById(userIds);

      return memberRows.map((row) {
        final userId = row['user_id']?.toString();
        if (userId != null && profilesById.containsKey(userId)) {
          row['profiles'] = profilesById[userId];
        }
        return TeamMember.fromJson(row);
      }).toList();
    } catch (error, stackTrace) {
      _logger.error(
        'get_team_members_failed',
        data: {'teamId': teamId},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<Map<String, Map<String, dynamic>>> _fetchProfilesById(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return const {};

    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, email')
          .inFilter('id', userIds);

      final profiles = <String, Map<String, dynamic>>{};
      for (final item in response as List<dynamic>) {
        final row = Map<String, dynamic>.from(item as Map);
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        profiles[id] = row;
      }
      return profiles;
    } catch (error, stackTrace) {
      _logger.error(
        'fetch_profiles_failed',
        data: {'count': userIds.length},
        error: error,
        stackTrace: stackTrace,
      );
      return const {};
    }
  }

  Future<void> addMemberByEmail(
    String teamId,
    String email, {
    TeamRole role = TeamRole.member,
  }) async {
    final inviterUserId = _supabase.auth.currentUser?.id;
    if (inviterUserId == null) {
      throw Exception('Kullanici oturumu bulunamadi.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw Exception('Gecerli bir e-posta adresi girin.');
    }

    try {
      final userResponse =
          await _supabase
              .from('profiles')
              .select('id, email, role')
              .eq('email', normalizedEmail)
              .maybeSingle();

      if (userResponse == null) {
        throw Exception(
          'Bu e-posta ile eslesen kullanici bulunamadi. Kullanici once kayit olmalidir.',
        );
      }

      final userId = userResponse['id']?.toString();
      if (userId == null || userId.isEmpty) {
        throw Exception('Kullanici profili gecersiz.');
      }

      final userRole = userResponse['role']?.toString();
      if (userRole == UserRole.pending) {
        throw Exception('Onay bekleyen kullanici takima eklenemez.');
      }

      await _upsertTeamMember(
        teamId: teamId,
        userId: userId,
        inviterUserId: inviterUserId,
        role: role,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'add_member_by_email_failed',
        data: {'teamId': teamId, 'email': normalizedEmail},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> addMemberByUserId(
    String teamId,
    String userId, {
    TeamRole role = TeamRole.member,
  }) async {
    final inviterUserId = _supabase.auth.currentUser?.id;
    if (inviterUserId == null) {
      throw Exception('Kullanici oturumu bulunamadi.');
    }

    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw Exception('Gecerli bir kullanici secin.');
    }

    try {
      final userResponse =
          await _supabase
              .from('profiles')
              .select('id, role')
              .eq('id', normalizedUserId)
              .maybeSingle();

      if (userResponse == null) {
        throw Exception('Secilen kullanici bulunamadi.');
      }

      final userRole = userResponse['role']?.toString();
      if (userRole == UserRole.pending) {
        throw Exception('Onay bekleyen kullanici takima eklenemez.');
      }

      await _upsertTeamMember(
        teamId: teamId,
        userId: normalizedUserId,
        inviterUserId: inviterUserId,
        role: role,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'add_member_by_user_id_failed',
        data: {'teamId': teamId, 'userId': normalizedUserId},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _upsertTeamMember({
    required String teamId,
    required String userId,
    required String inviterUserId,
    required TeamRole role,
  }) async {
    await _supabase.from('team_members').upsert({
      'team_id': teamId,
      'user_id': userId,
      'role': role.name,
      'invited_by': inviterUserId,
    });
  }

  Future<void> removeMember(String teamId, String userId) async {
    try {
      await _supabase
          .from('team_members')
          .delete()
          .eq('team_id', teamId)
          .eq('user_id', userId);
    } catch (error, stackTrace) {
      _logger.error(
        'remove_member_failed',
        data: {'teamId': teamId, 'userId': userId},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> deleteTeam(String teamId) async {
    try {
      await _supabase.from('teams').delete().eq('id', teamId);
    } catch (error, stackTrace) {
      _logger.error(
        'delete_team_failed',
        data: {'teamId': teamId},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateMemberRole(
    String teamId,
    String userId,
    TeamRole newRole,
  ) async {
    try {
      await _supabase
          .from('team_members')
          .update({'role': newRole.name})
          .eq('team_id', teamId)
          .eq('user_id', userId);
    } catch (error, stackTrace) {
      _logger.error(
        'update_member_role_failed',
        data: {'teamId': teamId, 'userId': userId, 'role': newRole.name},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
