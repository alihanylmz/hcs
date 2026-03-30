import '../models/user_profile.dart';

enum AppPermission {
  viewDashboard,
  manageUsers,
  managePartners,
  viewTicketList,
  viewDraftTickets,
  createTicket,
  manageDraftTickets,
  editTicket,
  deleteTicket,
  viewArchivedTickets,
  manageArchivedTickets,
  exportFilteredTicketListPdf,
  exportAllTicketListPdf,
  addServiceTicketNote,
  addPartnerTicketNote,
  moderateTicketNotes,
  uploadTicketAttachments,
  updateTicketWorkflow,
  manageTicketSignatures,
  assignTicketPartner,
  viewStock,
  manageStock,
  deleteStock,
  configureStockCatalog,
  viewTeams,
  viewFaultCodes,
  viewProfileAdminTools,
}

class PermissionService {
  const PermissionService._();

  static final Set<AppPermission> _adminPermissions = Set.unmodifiable(
    AppPermission.values.toSet(),
  );

  static final Set<AppPermission> _managerPermissions = Set.unmodifiable(
    {..._adminPermissions}..remove(AppPermission.configureStockCatalog),
  );

  static final Set<AppPermission> _supervisorPermissions = Set.unmodifiable({
    AppPermission.viewTicketList,
    AppPermission.viewDraftTickets,
    AppPermission.createTicket,
    AppPermission.manageDraftTickets,
    AppPermission.editTicket,
    AppPermission.deleteTicket,
    AppPermission.viewArchivedTickets,
    AppPermission.manageArchivedTickets,
    AppPermission.exportFilteredTicketListPdf,
    AppPermission.exportAllTicketListPdf,
    AppPermission.addServiceTicketNote,
    AppPermission.uploadTicketAttachments,
    AppPermission.updateTicketWorkflow,
    AppPermission.manageTicketSignatures,
    AppPermission.viewStock,
    AppPermission.manageStock,
    AppPermission.viewTeams,
    AppPermission.viewFaultCodes,
  });

  static final Set<AppPermission> _engineerPermissions = Set.unmodifiable({
    AppPermission.viewTicketList,
    AppPermission.viewDraftTickets,
    AppPermission.createTicket,
    AppPermission.manageDraftTickets,
    AppPermission.editTicket,
    AppPermission.viewArchivedTickets,
    AppPermission.exportFilteredTicketListPdf,
    AppPermission.exportAllTicketListPdf,
    AppPermission.addServiceTicketNote,
    AppPermission.uploadTicketAttachments,
    AppPermission.updateTicketWorkflow,
    AppPermission.manageTicketSignatures,
    AppPermission.viewStock,
    AppPermission.viewTeams,
    AppPermission.viewFaultCodes,
  });

  static final Set<AppPermission> _technicianPermissions = Set.unmodifiable({
    AppPermission.viewTicketList,
    AppPermission.viewArchivedTickets,
    AppPermission.exportFilteredTicketListPdf,
    AppPermission.exportAllTicketListPdf,
    AppPermission.addServiceTicketNote,
    AppPermission.uploadTicketAttachments,
    AppPermission.updateTicketWorkflow,
    AppPermission.manageTicketSignatures,
    AppPermission.viewStock,
    AppPermission.viewTeams,
    AppPermission.viewFaultCodes,
  });

  static final Set<AppPermission> _partnerPermissions = Set.unmodifiable({
    AppPermission.viewTicketList,
    AppPermission.viewArchivedTickets,
    AppPermission.exportFilteredTicketListPdf,
    AppPermission.addPartnerTicketNote,
    AppPermission.viewTeams,
    AppPermission.viewFaultCodes,
  });

  static final Set<AppPermission> _userPermissions = Set.unmodifiable({
    AppPermission.viewTicketList,
    AppPermission.viewArchivedTickets,
    AppPermission.exportFilteredTicketListPdf,
    AppPermission.viewTeams,
    AppPermission.viewFaultCodes,
  });

  static final Set<AppPermission> _pendingPermissions = Set.unmodifiable(
    const <AppPermission>{},
  );

  static Set<AppPermission> permissionsForRole(String? role) {
    switch (_normalizeRole(role)) {
      case UserRole.admin:
        return _adminPermissions;
      case UserRole.manager:
        return _managerPermissions;
      case UserRole.supervisor:
        return _supervisorPermissions;
      case UserRole.engineer:
        return _engineerPermissions;
      case UserRole.technician:
        return _technicianPermissions;
      case UserRole.partnerUser:
        return _partnerPermissions;
      case UserRole.user:
        return _userPermissions;
      case UserRole.pending:
      default:
        return _pendingPermissions;
    }
  }

  static bool roleHasPermission(String? role, AppPermission permission) {
    return permissionsForRole(role).contains(permission);
  }

  static bool hasPermission(UserProfile? profile, AppPermission permission) {
    return roleHasPermission(profile?.role, permission);
  }

  static bool canAccessAdminArea(UserProfile? profile) {
    return hasPermission(profile, AppPermission.viewDashboard);
  }

  static bool canDeleteStock(UserProfile? profile) {
    return hasPermission(profile, AppPermission.deleteStock);
  }

  static String roleLabel(String? role) {
    switch (_normalizeRole(role)) {
      case UserRole.admin:
        return 'Sistem Yonetici';
      case UserRole.manager:
        return 'Yonetici';
      case UserRole.supervisor:
        return 'Supervizor';
      case UserRole.engineer:
        return 'Muhendis';
      case UserRole.technician:
        return 'Teknisyen';
      case UserRole.partnerUser:
        return 'Partner';
      case UserRole.user:
        return 'Kullanici';
      case UserRole.pending:
      default:
        return 'Beklemede';
    }
  }

  static String _normalizeRole(String? role) {
    switch (role) {
      case UserRole.admin:
      case UserRole.manager:
      case UserRole.supervisor:
      case UserRole.engineer:
      case UserRole.technician:
      case UserRole.partnerUser:
      case UserRole.user:
      case UserRole.pending:
        return role!;
      default:
        return UserRole.pending;
    }
  }
}
