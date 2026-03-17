import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../pages/archived_tickets_page.dart';
import '../../pages/dashboard_page.dart';
import '../../pages/fault_codes_page.dart';
import '../../pages/login_page.dart';
import '../../pages/my_teams_page.dart';
import '../../pages/profile_page.dart';
import '../../pages/stock_overview_page.dart';
import '../../pages/ticket_list_page.dart';
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
        isDark ? AppColors.sidebarActiveDark : AppColors.sidebarActiveLight;
    final textColor = AppColors.sidebarText;
    final mutedTextColor = AppColors.sidebarTextMuted;
    final iconColor = AppColors.sidebarTextMuted;

    return Container(
      width: 296,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            baseBg,
            Color.lerp(baseBg, Colors.black, isDark ? 0.12 : 0.06)!,
          ],
        ),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 24,
            offset: const Offset(6, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SvgPicture.asset('assets/images/log.svg'),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Is Takip',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Servis operasyon merkezi',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: mutedTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (userName != null) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        userName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      if (userRole != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _getRoleLabel(userRole!),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: mutedTextColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  SidebarItem(
                    icon: Icons.groups_outlined,
                    label: 'Takimlarim',
                    isActive: activeMenuItem == 'my_teams',
                    activeColor: activeColor,
                    iconColor: iconColor,
                    textColor: textColor,
                    onTap: () => _navigate(context, const MyTeamsPage()),
                  ),
                  SidebarItem(
                    icon: Icons.list_alt_rounded,
                    label: 'Is Listesi',
                    isActive: activeMenuItem == 'ticket_list',
                    activeColor: activeColor,
                    iconColor: iconColor,
                    textColor: textColor,
                    onTap: () => _navigate(context, const TicketListPage()),
                  ),
                  if (userRole == 'admin' || userRole == 'manager')
                    SidebarItem(
                      icon: Icons.dashboard_rounded,
                      label: 'Yonetici Paneli',
                      isActive: activeMenuItem == 'dashboard',
                      activeColor: activeColor,
                      iconColor: iconColor,
                      textColor: textColor,
                      onTap: () => _navigate(context, const DashboardPage()),
                    ),
                  if (userRole != 'partner_user')
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
                  const SizedBox(height: 8),
                  const SidebarDivider(),
                  const SizedBox(height: 8),
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
                    iconColor: const Color(0xFFF7A4A0),
                    textColor: const Color(0xFFF7A4A0),
                    onTap: () => _handleLogout(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Is Takip 2026',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: mutedTextColor,
                      ),
                    ),
                  ),
                  Text(
                    'v1.1.0',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: mutedTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    switch (role) {
      case 'admin':
      case 'manager':
        return 'Yonetici';
      case 'partner_user':
        return 'Partner';
      case 'technician':
      default:
        return 'Teknisyen';
    }
  }
}
