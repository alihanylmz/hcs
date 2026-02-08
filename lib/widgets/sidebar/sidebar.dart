import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'sidebar_item.dart';
import '../../pages/ticket_list_page.dart';
import '../../pages/my_teams_page.dart';
import '../../pages/dashboard_page.dart';
import '../../pages/stock_overview_page.dart';
import '../../pages/archived_tickets_page.dart';
import '../../pages/fault_codes_page.dart';
import '../../pages/profile_page.dart';
import '../../pages/login_page.dart';
import '../../theme/app_colors.dart';

class Sidebar extends StatelessWidget {
  final String activeMenuItem;
  final String? userName;
  final String? userRole;

  const Sidebar({
    Key? key,
    required this.activeMenuItem,
    this.userName,
    this.userRole,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseBg = isDark ? const Color(0xFF111827) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final iconColor = isDark ? Colors.white70 : AppColors.corporateNavy;
    final activeColor = AppColors.corporateNavy;
    
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: baseBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          
          // Logo/Brand Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/images/log.svg',
                  width: 40,
                  height: 40,
                ),
                const SizedBox(width: 12),
                Text(
                  'İş Takip',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: activeColor,
                  ),
                ),
              ],
            ),
          ),
          
          // User Info
          if (userName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (userRole != null)
                    Text(
                      _getRoleLabel(userRole!),
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
            ),
          
          Divider(color: textColor.withOpacity(0.1)),
          const SizedBox(height: 8),
          
          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                SidebarItem(
                  icon: Icons.groups_outlined,
                  label: 'Takımlarım',
                  isActive: activeMenuItem == 'my_teams',
                  activeColor: activeColor,
                  iconColor: iconColor,
                  textColor: textColor,
                  onTap: () => _navigate(context, MyTeamsPage()),
                ),
                SidebarItem(
                  icon: Icons.list_alt_rounded,
                  label: 'İş Listesi',
                  isActive: activeMenuItem == 'ticket_list',
                  activeColor: activeColor,
                  iconColor: iconColor,
                  textColor: textColor,
                  onTap: () => _navigate(context, const TicketListPage()),
                  ),
                if (userRole == 'admin' || userRole == 'manager')
                  SidebarItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Yönetici Paneli',
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
                    onTap: () => _navigate(context, const StockOverviewPage()),
                  ),
                SidebarItem(
                  icon: Icons.task_alt_rounded,
                  label: 'Biten İşler',
                  isActive: activeMenuItem == 'archived',
                  activeColor: activeColor,
                  iconColor: iconColor,
                  textColor: textColor,
                  onTap: () => _navigate(context, const ArchivedTicketsPage()),
                ),
                SidebarItem(
                  icon: Icons.support_agent_rounded,
                  label: 'Arıza Rehberi',
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
                  icon: Icons.logout,
                  label: 'Çıkış Yap',
                  isActive: false,
                  activeColor: Colors.red,
                  iconColor: Colors.red,
                  textColor: Colors.red,
                  onTap: () => _handleLogout(context),
                ),
              ],
            ),
          ),
          
          // Footer
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İş Takip ©2025',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textColor.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: textColor.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, Widget page) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
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
        return 'Yönetici';
      case 'partner_user':
        return 'Partner';
      case 'technician':
      default:
        return 'Teknisyen';
    }
  }
}
