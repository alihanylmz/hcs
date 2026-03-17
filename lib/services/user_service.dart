import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/app_logger.dart';
import '../models/user_profile.dart';

class UserService {
  UserService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const AppLogger _logger = AppLogger('UserService');
  final SupabaseClient _client;

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final data =
          await _client
              .from('profiles')
              .select('*')
              .eq('id', user.id)
              .maybeSingle();

      if (data == null) {
        _logger.warning('profile_not_found', data: {'userId': user.id});
        return null;
      }

      return UserProfile.fromJson(data as Map<String, dynamic>);
    } catch (error, stackTrace) {
      _logger.error(
        'get_current_user_profile_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  bool canDeleteStock(UserProfile? profile) {
    if (profile == null) return false;
    return profile.isAdmin == true || profile.isManager == true;
  }

  Future<void> createProfile(
    String userId,
    String email,
    String? fullName,
  ) async {
    try {
      await _client.from('profiles').insert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'role': UserRole.pending,
      });
    } catch (error, stackTrace) {
      _logger.error(
        'create_profile_failed',
        data: {'userId': userId, 'email': email},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> updateProfile(
    String userId, {
    String? fullName,
    String? signatureData,
  }) async {
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (signatureData != null) updates['signature_data'] = signatureData;

    if (updates.isEmpty) return;

    try {
      await _client.from('profiles').update(updates).eq('id', userId);
    } catch (error, stackTrace) {
      _logger.error(
        'update_profile_failed',
        data: {'userId': userId, 'updatedFields': updates.keys.join(',')},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> clearSignature(String userId) async {
    try {
      await _client
          .from('profiles')
          .update({'signature_data': null})
          .eq('id', userId);
    } catch (error, stackTrace) {
      _logger.error(
        'clear_signature_failed',
        data: {'userId': userId},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<UserProfile>> getAllUsers() async {
    try {
      final List<dynamic> rows = await _client
          .from('profiles')
          .select('*')
          .order('full_name', ascending: true);

      return rows
          .map((row) => UserProfile.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (error, stackTrace) {
      _logger.error(
        'get_all_users_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<bool> updateUserRole(
    String userId,
    String newRole, {
    int? partnerId,
  }) async {
    try {
      final data = <String, dynamic>{
        'role': newRole,
        'partner_id': newRole == UserRole.partnerUser ? partnerId : null,
      };

      await _client.from('profiles').update(data).eq('id', userId);
      return true;
    } catch (error, stackTrace) {
      _logger.error(
        'update_user_role_failed',
        data: {'userId': userId, 'newRole': newRole, 'partnerId': partnerId},
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
