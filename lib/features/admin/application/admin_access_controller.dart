import '../../../core/logging/app_logger.dart';
import '../../../models/user_profile.dart';
import '../../../services/permission_service.dart';
import '../../../services/user_service.dart';

class AdminAccessState {
  const AdminAccessState({
    required this.profile,
    required this.hasAccess,
    this.errorMessage,
  });

  final UserProfile? profile;
  final bool hasAccess;
  final String? errorMessage;
}

class AdminAccessController {
  AdminAccessController({UserService? userService})
    : _userService = userService ?? UserService();

  static const AppLogger _logger = AppLogger('AdminAccessController');
  final UserService _userService;

  Future<AdminAccessState> load() async {
    try {
      final profile = await _userService.getCurrentUserProfile();

      if (profile == null) {
        return const AdminAccessState(
          profile: null,
          hasAccess: false,
          errorMessage: 'Kullanici profili bulunamadi.',
        );
      }

      if (!PermissionService.canAccessAdminArea(profile)) {
        return AdminAccessState(profile: profile, hasAccess: false);
      }

      return AdminAccessState(profile: profile, hasAccess: true);
    } catch (error, stackTrace) {
      _logger.error(
        'load_admin_access_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const AdminAccessState(
        profile: null,
        hasAccess: false,
        errorMessage: 'Yetki bilgisi yuklenemedi.',
      );
    }
  }
}
