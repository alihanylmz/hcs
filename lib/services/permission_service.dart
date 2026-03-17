import '../models/user_profile.dart';

class PermissionService {
  const PermissionService._();

  static bool canAccessAdminArea(UserProfile? profile) {
    if (profile == null) {
      return false;
    }

    return profile.isAdmin || profile.isManager;
  }
}
