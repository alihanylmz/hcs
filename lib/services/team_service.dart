import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/team.dart';

class TeamService {
  final _supabase = Supabase.instance.client;

  Future<List<Team>> listTeams() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // Get teams where user is a member
    final response = await _supabase
        .from('team_members')
        .select('team_id, teams(*)')
        .eq('user_id', userId);

    final List<Team> teams = [];
    for (var item in response) {
      if (item['teams'] != null) {
        teams.add(Team.fromJson(item['teams']));
      }
    }
    return teams;
  }

  Future<Team> createTeam({required String name, String? description}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Kullanıcı oturumu yok');

    // 1. Create Team
    final teamData = await _supabase
        .from('teams')
        .insert({
          'name': name,
          'description': description,
          'created_by': user.id,
        })
        .select()
        .single();

    final team = Team.fromJson(teamData);

    // 2. Add creator as owner
    await _supabase.from('team_members').insert({
      'team_id': team.id,
      'user_id': user.id,
      'role': 'owner',
    });

    return team;
  }
}
