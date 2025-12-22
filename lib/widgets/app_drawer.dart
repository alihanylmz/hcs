import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../main.dart';
import '../pages/dashboard_page.dart';
import '../pages/stock_overview_page.dart';
import '../pages/archived_tickets_page.dart';
import '../pages/profile_page.dart';
import '../pages/ticket_list_page.dart';
import '../pages/login_page.dart';
import '../pages/partner_management_page.dart';
import '../pages/fault_codes_page.dart';
import '../pages/daily_activities_page.dart';
import '../pages/reports_page.dart'; 
import '../theme/app_colors.dart';

enum AppDrawerPage {
  ticketList,
  dashboard,
  stock,
  archived,
  profile,
  faultCodes,
  dailyActivities,
  reports,
  other,
}

class AppDrawer extends StatelessWidget {
  final AppDrawerPage currentPage;
  final String? userName;
  final String? userRole;
  final VoidCallback? onProfileReload;

  const AppDrawer({
    super.key,
    required this.currentPage,
    this.userName,
    this.userRole,
    this.onProfileReload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Arka plan rengi
    final drawerBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    // Metin renkleri
    final textColor = isDark ? Colors.white : AppColors.corporateNavy;
    
    return Drawer(
      backgroundColor: drawerBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0), // Modern düz tasarım
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Column(
        children: [
          // --- 1. MODERN GRADIENT HEADER ---
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark 
                  ? [Colors.black87, const Color(0xFF0F172A)]
                  : [AppColors.corporateNavy, AppColors.corporateYellow],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo ve Marka
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: SvgPicture.asset(
                        'assets/images/log.svg',
                        width: 28,
                        height: 28,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HAN CONTROL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'SYSTEM',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                
                // Kullanıcı Kartı
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white,
                          child: Text(
                            (userName ?? 'T').substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: isDark ? const Color(0xFF0F172A) : AppColors.corporateNavy,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName ?? 'İsimsiz Kullanıcı',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.statusDone.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getUserRoleLabel(userRole),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- 2. MENÜ LİSTESİ ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              children: [
                _buildSectionHeader('ANA MENÜ', isDark),
                _buildModernDrawerItem(
                  icon: Icons.list_alt_rounded,
                  text: 'İş Listesi',
                  isActive: currentPage == AppDrawerPage.ticketList,
                  onTap: () => _navigate(context, AppDrawerPage.ticketList, const TicketListPage()),
                  textColor: textColor,
                  activeColor: AppColors.corporateNavy,
                ),
                const SizedBox(height: 6),
                _buildModernDrawerItem(
                  icon: Icons.calendar_month_rounded,
                  text: 'Günlük Planım',
                  isActive: currentPage == AppDrawerPage.dailyActivities,
                  onTap: () => _navigate(context, AppDrawerPage.dailyActivities, const DailyActivitiesPage()),
                  textColor: textColor,
                  activeColor: AppColors.corporateNavy,
                ),
                
                const SizedBox(height: 24),
                _buildSectionHeader('İŞLEMLER', isDark),
                
                _buildModernDrawerItem(
                  icon: Icons.analytics_outlined,
                  text: 'Rapor Oluştur',
                  isActive: currentPage == AppDrawerPage.reports,
                  onTap: () => _navigate(context, AppDrawerPage.reports, const ReportsPage()),
                  textColor: textColor,
                  activeColor: AppColors.corporateNavy,
                ),
                
                if (userRole == 'admin' || userRole == 'manager') ...[
                  const SizedBox(height: 6),
                  _buildModernDrawerItem(
                    icon: Icons.dashboard_rounded,
                    text: 'Yönetici Paneli',
                    isActive: currentPage == AppDrawerPage.dashboard,
                    onTap: () => _navigate(context, AppDrawerPage.dashboard, const DashboardPage()),
                    textColor: textColor,
                    activeColor: AppColors.corporateNavy,
                  ),
                ],
                
                if (userRole != 'partner_user') ...[
                  const SizedBox(height: 6),
                  _buildModernDrawerItem(
                    icon: Icons.inventory_2_outlined,
                    text: 'Stok Durumu',
                    isActive: currentPage == AppDrawerPage.stock,
                    onTap: () => _navigate(context, AppDrawerPage.stock, const StockOverviewPage()),
                    textColor: textColor,
                    activeColor: AppColors.corporateNavy,
                  ),
                ],
                
                const SizedBox(height: 6),
                _buildModernDrawerItem(
                  icon: Icons.task_alt_rounded,
                  text: 'Biten İşler (Arşiv)',
                  isActive: currentPage == AppDrawerPage.archived,
                  onTap: () => _navigate(context, AppDrawerPage.archived, const ArchivedTicketsPage()),
                  textColor: textColor,
                  activeColor: AppColors.corporateNavy,
                ),
                
                const SizedBox(height: 6),
                _buildModernDrawerItem(
                  icon: Icons.support_agent_rounded,
                  text: 'Arıza Rehberi',
                  isActive: currentPage == AppDrawerPage.faultCodes,
                  onTap: () => _navigate(context, AppDrawerPage.faultCodes, const FaultCodesPage()),
                  textColor: textColor,
                  activeColor: AppColors.corporateNavy,
                ),
              ],
            ),
          ),

          // --- 3. ALT FOOTER ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              children: [
                const Divider(),
                _buildModernDrawerItem(
                  icon: Icons.person_outline_rounded,
                  text: 'Profilim',
                  isActive: currentPage == AppDrawerPage.profile,
                  textColor: textColor,
                  activeColor: AppColors.corporateNavy,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    ).then((_) {
                      if (onProfileReload != null) {
                        onProfileReload!();
                      }
                    });
                  },
                ),
                _buildModernDrawerItem(
                  icon: IsTakipApp.of(context)?.isDarkMode == true ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  text: IsTakipApp.of(context)?.isDarkMode == true ? 'Aydınlık Mod' : 'Karanlık Mod',
                  isActive: false,
                  textColor: textColor,
                  activeColor: AppColors.corporateNavy,
                  onTap: () {
                    IsTakipApp.of(context)?.toggleTheme();
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.2)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Çıkış Yap',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _navigate(BuildContext context, AppDrawerPage page, Widget widget) {
    Navigator.pop(context);
    if (currentPage != page) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => widget),
      );
    }
  }
  
  String _getUserRoleLabel(String? role) {
    switch (role) {
      case 'admin':
      case 'manager':
        return 'YÖNETİCİ';
      case 'partner_user':
        return 'PARTNER';
      case 'technician':
      default:
        return 'TEKNİSYEN';
    }
  }
  
  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white54 : Colors.grey[600],
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildModernDrawerItem({
    required IconData icon,
    required String text,
    required bool isActive,
    required VoidCallback onTap,
    required Color textColor,
    required Color activeColor,
  }) {
    // Aktif öğe rengini ayarlama
    final color = isActive ? activeColor : textColor.withOpacity(0.8);
    final bgColor = isActive ? activeColor.withOpacity(0.1) : Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
                const SizedBox(width: 16),
                Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (isActive) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeColor,
                    ),
                  )
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
