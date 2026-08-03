import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/app_logger.dart';
import '../models/user_app_access.dart';
import '../models/user_profile.dart';
import 'permission_service.dart';

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

      return UserProfile.fromJson(data);
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
    return PermissionService.canDeleteStock(profile);
  }

  Future<void> createProfile(
    String userId,
    String email,
    String? fullName,
  ) async {
    try {
      await _client.from('profiles').upsert({
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

  Future<Set<String>> getActiveAppUserIds(String appCode) async {
    try {
      final List<dynamic> rows = await _client
          .from('user_app_access')
          .select('user_id')
          .eq('app_code', appCode)
          .eq('is_active', true);

      return rows
          .map((row) => (row as Map<String, dynamic>)['user_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (error, stackTrace) {
      _logger.error(
        'get_active_app_users_failed',
        data: {'appCode': appCode},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<Map<String, Map<String, UserAppAccess>>> getAllUserAppAccess() async {
    try {
      final List<dynamic> rows = await _client
          .from('user_app_access')
          .select(
            'user_id, app_code, app_role, is_active, granted_at, updated_at',
          );
      final result = <String, Map<String, UserAppAccess>>{};
      for (final raw in rows) {
        final access = UserAppAccess.fromJson(
          Map<String, dynamic>.from(raw as Map),
        );
        if (access.userId.isEmpty || access.appCode.isEmpty) continue;
        result.putIfAbsent(access.userId, () => {})[access.appCode] = access;
      }
      return result;
    } catch (error, stackTrace) {
      _logger.error(
        'get_all_user_app_access_failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> saveUserAccessConfiguration({
    required UserProfile user,
    required UserAccessDraft draft,
  }) async {
    _validateAccessDraft(draft);
    final actorId = _client.auth.currentUser?.id;
    if (actorId == null) {
      throw Exception('Oturum bulunamadı.');
    }
    final actorProfile = await getCurrentUserProfile();
    if (actorProfile == null || !actorProfile.isAdmin) {
      throw Exception('Bu işlem için kullanıcı yönetimi yetkiniz yok.');
    }
    final targetQuoteAccess =
        await _client
            .from('user_app_access')
            .select('app_role')
            .eq('user_id', user.id)
            .eq('app_code', 'teklif')
            .maybeSingle();
    if (!actorProfile.isAdmin &&
        (user.isAdmin ||
            draft.isTakipRole == UserRole.admin ||
            targetQuoteAccess?['app_role'] == 'admin' ||
            draft.teklifRole == 'admin')) {
      throw Exception(
        'Patron, Genel Müdür hesabını değiştiremez veya tam yetki atayamaz.',
      );
    }
    if (actorId == user.id &&
        (!draft.isTakipActive ||
            draft.isTakipRole != UserRole.admin ||
            !draft.teklifActive ||
            draft.teklifRole != 'admin')) {
      throw Exception(
        'Genel Müdür kendi erişimini kapatamaz veya tam yetkisini düşüremez.',
      );
    }
    if (user.isAdmin &&
        (!draft.isTakipActive || draft.isTakipRole != UserRole.admin)) {
      final activeAdmins = await _client
          .from('user_app_access')
          .select('user_id')
          .eq('app_code', 'is_takip')
          .eq('app_role', 'admin')
          .eq('is_active', true);
      if (activeAdmins.length <= 1) {
        throw Exception(
          'Sistemde en az bir aktif sistem yöneticisi kalmalıdır.',
        );
      }
    }

    try {
      await _client.rpc(
        'manage_user_access',
        params: {
          'p_user_id': user.id,
          'p_is_takip_active': draft.isTakipActive,
          'p_is_takip_role': draft.isTakipRole,
          'p_teklif_active': draft.teklifActive,
          'p_teklif_role': draft.teklifRole,
          'p_partner_id': draft.partnerId,
        },
      );
      return;
    } on PostgrestException catch (error) {
      final functionMissing =
          error.code == 'PGRST202' ||
          error.message.contains('manage_user_access');
      if (!functionMissing) rethrow;
      _logger.warning(
        'manage_user_access_rpc_missing_fallback',
        data: {'userId': user.id},
      );
    }

    // Yeni RPC migrationı uygulanana kadar mevcut ortak tablo yapısıyla
    // geriye uyumlu çalışır.
    if (draft.isTakipActive) {
      await approveUserAccount(
        user.id,
        draft.isTakipRole,
        partnerId: draft.partnerId,
      );
    } else {
      await updateUserRole(user.id, UserRole.pending);
    }
    await _client.from('user_app_access').upsert({
      'user_id': user.id,
      'app_code': 'is_takip',
      'app_role': draft.isTakipRole,
      'is_active': draft.isTakipActive,
      'granted_by': actorId,
    }, onConflict: 'user_id,app_code');
    await _client.from('user_app_access').upsert({
      'user_id': user.id,
      'app_code': 'teklif',
      'app_role': draft.teklifRole,
      'is_active': draft.teklifActive,
      'granted_by': actorId,
    }, onConflict: 'user_id,app_code');
  }

  void _validateAccessDraft(UserAccessDraft draft) {
    final businessRoles =
        UserAccessCatalog.businessRoles.map((role) => role.code).toSet();
    const isTakipRoles = {
      UserRole.admin,
      UserRole.manager,
      UserRole.supervisor,
      UserRole.engineer,
      UserRole.technician,
      UserRole.user,
      UserRole.partnerUser,
    };
    const teklifRoles = {
      'admin',
      'manager',
      'sales',
      'finance',
      'operations',
      'viewer',
    };
    if (!businessRoles.contains(draft.businessRole)) {
      throw Exception('Geçersiz kurumsal rol.');
    }
    if (!isTakipRoles.contains(draft.isTakipRole)) {
      throw Exception('Geçersiz İş Takip rolü.');
    }
    if (!teklifRoles.contains(draft.teklifRole)) {
      throw Exception('Geçersiz Teklif rolü.');
    }
    if (draft.isTakipActive &&
        draft.isTakipRole == UserRole.partnerUser &&
        draft.partnerId == null) {
      throw Exception('Partner kullanıcı için firma seçilmelidir.');
    }
  }

  Future<void> setAppAccess({
    required UserProfile user,
    required String appCode,
    required bool isActive,
  }) async {
    try {
      await _client.from('user_app_access').upsert({
        'user_id': user.id,
        'app_code': appCode,
        'app_role': _appRoleFor(user.role),
        'is_active': isActive,
      }, onConflict: 'user_id,app_code');
    } catch (error, stackTrace) {
      _logger.error(
        'set_app_access_failed',
        data: {'userId': user.id, 'appCode': appCode, 'isActive': isActive},
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  String _appRoleFor(String profileRole) {
    switch (profileRole) {
      case UserRole.admin:
        return 'admin';
      case UserRole.manager:
        return 'manager';
      default:
        return 'sales';
    }
  }

  String _describeError(Object error) {
    final rawMessage = error.toString();
    if (rawMessage.contains('Failed to fetch') &&
        rawMessage.contains('approve-user')) {
      return 'approve-user Edge Function endpointine ulasilamiyor. '
          'Fonksiyon deploy edilmemis veya proje baglantisi eksik olabilir.';
    }
    if (error is PostgrestException) {
      return error.message;
    }
    if (error is AuthException) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> updateUserRole(
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
    } catch (error, stackTrace) {
      _logger.error(
        'update_user_role_failed',
        data: {'userId': userId, 'newRole': newRole, 'partnerId': partnerId},
        error: error,
        stackTrace: stackTrace,
      );
      throw Exception(_describeError(error));
    }
  }

  Future<void> approveUserAccount(
    String userId,
    String newRole, {
    int? partnerId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'approve-user',
        body: {'userId': userId, 'role': newRole, 'partnerId': partnerId},
      );

      if (response.status < 200 || response.status >= 300) {
        final data = response.data;
        if (data is Map<String, dynamic> && data['error'] != null) {
          throw Exception(data['error'].toString());
        }
        throw Exception('Onay islemi basarisiz oldu.');
      }
    } catch (error, stackTrace) {
      final rawMessage = error.toString();
      final isFunctionUnavailable =
          rawMessage.contains('Failed to fetch') &&
          rawMessage.contains('approve-user');

      if (isFunctionUnavailable) {
        _logger.warning(
          'approve_user_account_function_unavailable_fallback',
          data: {'userId': userId, 'newRole': newRole, 'partnerId': partnerId},
        );
        await updateUserRole(userId, newRole, partnerId: partnerId);
        return;
      }

      _logger.error(
        'approve_user_account_failed',
        data: {'userId': userId, 'newRole': newRole, 'partnerId': partnerId},
        error: error,
        stackTrace: stackTrace,
      );
      throw Exception(_describeError(error));
    }
  }
}
