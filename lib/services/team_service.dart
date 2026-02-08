import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/team.dart';
import '../models/team_member.dart';

class TeamService {
  final _supabase = Supabase.instance.client;

  Future<List<Team>> listTeams() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

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

    await _supabase.from('team_members').insert({
      'team_id': team.id,
      'user_id': user.id,
      'role': 'owner',
    });

    return team;
  }

  // --- Üye Yönetimi ---

  Future<TeamRole> getCurrentUserRole(String teamId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return TeamRole.member;

    try {
      final response = await _supabase
          .from('team_members')
          .select('role')
          .eq('team_id', teamId)
          .eq('user_id', userId)
          .single();
      
      return TeamRole.fromString(response['role']);
    } catch (e) {
      return TeamRole.member;
    }
  }

  Future<List<TeamMember>> getTeamMembers(String teamId) async {
    // 1. Önce takım üyelerini çekelim
    final response = await _supabase
        .from('team_members')
        .select()
        .eq('team_id', teamId);
    
    final List<dynamic> memberData = response;
    final userIds = memberData.map((e) => e['user_id']).toList();

    // 2. Bu üyelerin profil bilgilerini 'profiles' tablosundan manuel çekelim
    // Böylece FK ilişkisi olmasa bile çalışır
    Map<String, Map<String, dynamic>> profilesMap = {};
    if (userIds.isNotEmpty) {
      try {
        final profiles = await _supabase
            .from('profiles') // CSV'de gördüğümüz tablo
            .select('id, full_name, role') // CSV kolonları
            .inFilter('id', userIds);
        
        for (var p in profiles) {
          profilesMap[p['id']] = p;
        }
      } catch (e) {
        print('Profil çekme hatası: $e');
      }
    }

    // 3. Verileri birleştir
    return memberData.map((e) {
      final userId = e['user_id'];
      final profile = profilesMap[userId];
      
      // JSON'a 'profiles' anahtarı altında ekliyoruz ki model bunu okuyabilsin
      final merged = Map<String, dynamic>.from(e);
      if (profile != null) {
        merged['profiles'] = {
          'full_name': profile['full_name'],
          'email': null, // CSV'de email yoktu, gerekirse auth'dan veya başka yerden
        };
      }
      return TeamMember.fromJson(merged);
    }).toList();
  }

  Future<void> addMemberByEmail(String teamId, String email, {TeamRole role = TeamRole.member}) async {
    // Email ile kullanıcı bulma kısmı:
    // Profiles tablosunda email kolonu yoksa (sadece full_name ve phone varsa),
    // Auth tablosuna erişimimiz kısıtlı olabilir.
    // Şimdilik RPC fonksiyonu veya auth.users araması gerekir.
    // Ancak profillerde email varsa:
    
    try {
        final userResponse = await _supabase
            .from('profiles')
            .select('id')
            .eq('email', email) // Eğer email kolonu eklendiyse
            .maybeSingle();

        if (userResponse != null) {
            final userId = userResponse['id'];
            await _supabase.from('team_members').insert({
              'team_id': teamId,
              'user_id': userId,
              'role': role.name,
              'invited_by': _supabase.auth.currentUser?.id,
            });
            return;
        }
    } catch(e) {
        // Hata
    }
    
    throw Exception('Kullanıcı bulunamadı veya e-posta ile davet sistemi yapılandırılmamış.');
  }

  Future<void> removeMember(String teamId, String userId) async {
    await _supabase
        .from('team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', userId);
  }

  Future<void> updateMemberRole(String teamId, String userId, TeamRole newRole) async {
    await _supabase
        .from('team_members')
        .update({'role': newRole.name})
        .eq('team_id', teamId)
        .eq('user_id', userId);
  }
}
