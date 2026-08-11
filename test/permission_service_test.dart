import 'package:flutter_test/flutter_test.dart';
import 'package:istakip_app/models/user_profile.dart';
import 'package:istakip_app/services/permission_service.dart';

UserProfile _profile(String role) {
  return UserProfile(id: 'test-user', role: role);
}

void main() {
  group('PermissionService', () {
    test('admin keeps full access', () {
      final profile = _profile(UserRole.admin);

      expect(
        PermissionService.hasPermission(profile, AppPermission.viewDashboard),
        isTrue,
      );
      expect(
        PermissionService.hasPermission(profile, AppPermission.manageUsers),
        isTrue,
      );
      expect(
        PermissionService.hasPermission(
          profile,
          AppPermission.configureStockCatalog,
        ),
        isTrue,
      );
    });

    test('patron operasyonu yönetir fakat sistem yetkilerine erişemez', () {
      final profile = _profile(UserRole.manager);

      expect(
        PermissionService.hasPermission(profile, AppPermission.viewDashboard),
        isTrue,
      );
      expect(
        PermissionService.hasPermission(
          profile,
          AppPermission.configureStockCatalog,
        ),
        isFalse,
      );
      expect(
        PermissionService.hasPermission(profile, AppPermission.manageUsers),
        isFalse,
      );
      expect(
        PermissionService.hasPermission(
          profile,
          AppPermission.viewProfileAdminTools,
        ),
        isFalse,
      );
      expect(
        PermissionService.hasPermission(profile, AppPermission.manageStock),
        isTrue,
      );
    });

    test('supervisor can manage tickets without admin screens', () {
      final profile = _profile(UserRole.supervisor);

      expect(
        PermissionService.hasPermission(profile, AppPermission.createTicket),
        isTrue,
      );
      expect(
        PermissionService.hasPermission(profile, AppPermission.editTicket),
        isTrue,
      );
      expect(
        PermissionService.hasPermission(
          profile,
          AppPermission.viewDraftTickets,
        ),
        isTrue,
      );
      expect(
        PermissionService.hasPermission(profile, AppPermission.viewDashboard),
        isFalse,
      );
      expect(
        PermissionService.hasPermission(profile, AppPermission.manageUsers),
        isFalse,
      );
    });

    test('engineer can operate tickets without destructive admin rights', () {
      final profile = _profile(UserRole.engineer);

      expect(
        PermissionService.hasPermission(profile, AppPermission.createTicket),
        isTrue,
      );
      expect(
        PermissionService.hasPermission(profile, AppPermission.editTicket),
        isTrue,
      );
      expect(
        PermissionService.hasPermission(profile, AppPermission.deleteTicket),
        isFalse,
      );
      expect(
        PermissionService.hasPermission(
          profile,
          AppPermission.manageArchivedTickets,
        ),
        isFalse,
      );
      expect(
        PermissionService.hasPermission(profile, AppPermission.manageStock),
        isFalse,
      );
    });

    test('technician stays execution-focused', () {
      final profile = _profile(UserRole.technician);

      expect(
        PermissionService.hasPermission(
          profile,
          AppPermission.addServiceTicketNote,
        ),
        isTrue,
      );
      expect(
        PermissionService.hasPermission(
          profile,
          AppPermission.updateTicketWorkflow,
        ),
        isTrue,
      );
      expect(
        PermissionService.hasPermission(profile, AppPermission.createTicket),
        isFalse,
      );
      expect(
        PermissionService.hasPermission(profile, AppPermission.editTicket),
        isFalse,
      );
      expect(
        PermissionService.hasPermission(profile, AppPermission.viewStock),
        isFalse,
      );
    });

    test('stock menu is limited to management and stock manager roles', () {
      for (final role in [
        UserRole.admin,
        UserRole.manager,
        UserRole.stockManager,
      ]) {
        expect(
          PermissionService.hasPermission(
            _profile(role),
            AppPermission.viewStock,
          ),
          isTrue,
        );
      }

      for (final role in [
        UserRole.supervisor,
        UserRole.engineer,
        UserRole.technician,
        UserRole.user,
        UserRole.partnerUser,
      ]) {
        expect(
          PermissionService.hasPermission(
            _profile(role),
            AppPermission.viewStock,
          ),
          isFalse,
        );
      }
    });

    test('partner user stays scoped to partner actions', () {
      final profile = _profile(UserRole.partnerUser);

      expect(
        PermissionService.hasPermission(
          profile,
          AppPermission.addPartnerTicketNote,
        ),
        isTrue,
      );
      expect(
        PermissionService.hasPermission(
          profile,
          AppPermission.addServiceTicketNote,
        ),
        isFalse,
      );
      expect(
        PermissionService.hasPermission(profile, AppPermission.viewStock),
        isFalse,
      );
    });

    test('standard user remains read-focused', () {
      final profile = _profile(UserRole.user);

      expect(
        PermissionService.hasPermission(profile, AppPermission.viewTicketList),
        isTrue,
      );
      expect(
        PermissionService.hasPermission(profile, AppPermission.createTicket),
        isFalse,
      );
      expect(
        PermissionService.hasPermission(
          profile,
          AppPermission.addServiceTicketNote,
        ),
        isFalse,
      );
    });

    test('unknown roles fall back to blocked pending policy', () {
      expect(
        PermissionService.roleHasPermission(
          'unknown_role',
          AppPermission.createTicket,
        ),
        isFalse,
      );
      expect(
        PermissionService.roleHasPermission(
          'unknown_role',
          AppPermission.viewTicketList,
        ),
        isFalse,
      );
    });
  });
}
