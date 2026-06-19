import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../pages/archived_tickets_page.dart';
import '../../pages/dashboard_page.dart';
import '../../pages/fault_codes_page.dart';
import '../../pages/login_page.dart';
import '../../pages/profile_page.dart';
import '../../pages/stock_overview_page.dart';
import '../../pages/ticket_list_page.dart';
import '../../services/permission_service.dart';
import '../../theme/app_colors.dart';
import 'sidebar_item.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.activeMenuItem,
    this.userName,
    this.userRole,
  });

  final String activeMenuItem;
  final String? userName;
  final String? userRole;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseBg =
        isDark
            ? AppColors.sidebarBackgroundDark
            : AppColors.sidebarBackgroundLight;
    final activeColor =
        isDark ? const Color(0xFF1D4ED8) : const Color(0xFF1E40AF);
    final textColor = AppColors.sidebarText;
    final mutedTextColor = AppColors.sidebarTextMuted;
    final iconColor = AppColors.sidebarTextMuted;

    return Container(
      width: 304,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            baseBg,
            Color.lerp(baseBg, AppColors.corporateBlue, isDark ? 0.20 : 0.12)!,
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.16),
            blurRadius: 40,
            offset: const Offset(10, 20),
          ),
        ],
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBrandCard(textColor, mutedTextColor, isDark),
            if (userName != null) ...[
              const SizedBox(height: 16),
              _buildUserCard(textColor, mutedTextColor, isDark),
            ],
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'NAVIGASYON',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: mutedTextColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  SidebarItem(
                    icon: Icons.list_alt_rounded,
                    label: 'Is Listesi',
                    isActive: activeMenuItem == 'ticket_list',
                    activeColor: activeColor,
                    iconColor: iconColor,
                    textColor: textColor,
                    onTap: () => _navigate(context, const TicketListPage()),
                  ),
                  if (PermissionService.roleHasPermission(
                    userRole,
                    AppPermission.viewDashboard,
                  ))
                    SidebarItem(
                      icon: Icons.dashboard_rounded,
                      label: 'Yonetici Paneli',
                      isActive: activeMenuItem == 'dashboard',
                      activeColor: activeColor,
                      iconColor: iconColor,
                      textColor: textColor,
                      onTap: () => _navigate(context, const DashboardPage()),
                    ),
                  if (PermissionService.roleHasPermission(
                    userRole,
                    AppPermission.viewStock,
                  ))
                    SidebarItem(
                      icon: Icons.inventory_2_outlined,
                      label: 'Stok Durumu',
                      isActive: activeMenuItem == 'stock',
                      activeColor: activeColor,
                      iconColor: iconColor,
                      textColor: textColor,
                      onTap:
                          () => _navigate(context, const StockOverviewPage()),
                    ),
                  SidebarItem(
                    icon: Icons.task_alt_rounded,
                    label: 'Biten Isler',
                    isActive: activeMenuItem == 'archived',
                    activeColor: activeColor,
                    iconColor: iconColor,
                    textColor: textColor,
                    onTap:
                        () => _navigate(context, const ArchivedTicketsPage()),
                  ),
                  SidebarItem(
                    icon: Icons.support_agent_rounded,
                    label: 'Ariza Rehberi',
                    isActive: activeMenuItem == 'fault_codes',
                    activeColor: activeColor,
                    iconColor: iconColor,
                    textColor: textColor,
                    onTap: () => _navigate(context, const FaultCodesPage()),
                  ),
                  const SizedBox(height: 10),
                  const SidebarDivider(),
                  const SizedBox(height: 10),
                  SidebarItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Profilim',
                    isActive: activeMenuItem == 'profile',
                    activeColor: activeColor,
                    iconColor: iconColor,
                    textColor: textColor,
                    onTap: () => _navigate(context, const ProfilePage()),
                  ),
                  SidebarItem(
                    icon: Icons.logout_rounded,
                    label: 'Cikis Yap',
                    isActive: false,
                    activeColor: AppColors.corporateRed,
                    iconColor: const Color(0xFFFECACA),
                    textColor: const Color(0xFFFECACA),
                    onTap: () => _handleLogout(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const SidebarDivider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Is Takip Workspace',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Web dashboard temasi',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: mutedTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Text(
                    'v1.1.10',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: mutedTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandCard(Color textColor, Color mutedTextColor, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SvgPicture.asset('assets/images/log.svg'),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'OPERATIONS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: mutedTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Is Takip',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Servis, stok ve saha operasyonlarini tek ekranda yonetin.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: mutedTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Color textColor, Color mutedTextColor, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userRole == null
                      ? 'Aktif kullanici'
                      : _getRoleLabel(userRole!),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mutedTextColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.statusDone,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, Widget page) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _handleLogout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  String _getRoleLabel(String role) {
    return PermissionService.roleLabel(role);
  }
}
