import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';

class UserService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        // Profil yoksa oluştur (opsiyonel, genellikle trigger ile yapılır)
        // Onay bekleyen profil döndürelim
        return UserProfile(
          id: user.id,
          email: user.email,
          role: 'pending',
        );
      }

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Profil çekme hatası: $e');
      return null;
    }
  }
  
  bool canDeleteStock(UserProfile? profile) {
    return profile?.isAdmin == true || profile?.isManager == true;
  }
  
  Future<void> createProfile(String userId, String email, String? fullName) async {
    await _client.from('profiles').insert({
      'id': userId,
      'email': email,
      'full_name': fullName,
      'role': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateProfile(String userId, {String? fullName}) async {
    await _client.from('profiles').update({'full_name': fullName}).eq('id', userId);
  }

  Future<List<UserProfile>> getAllUsers() async {
    final response = await _client.from('profiles').select().order('full_name', ascending: true);
    return (response as List).map((e) => UserProfile.fromJson(e)).toList();
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await _client.from('profiles').update({'role': newRole}).eq('id', userId);
  }
}

