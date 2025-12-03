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
import '../pages/partner_management_page.dart'; // Eklendi
import '../theme/app_colors.dart';

enum AppDrawerPage {
  ticketList,
  dashboard,
  stock,
  archived,
  profile,
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
    final user = Supabase.instance.client.auth.currentUser;
    final isDark = theme.brightness == Brightness.dark;
    // Arka plan rengi
    final drawerBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    // Metin renkleri
    final textColor = isDark ? Colors.white : AppColors.corporateNavy;
    final iconColor = isDark ? Colors.white70 : AppColors.textLight;

    return Drawer(
      backgroundColor: drawerBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // --- 1. ÖZEL TASARIM HEADER ---
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : AppColors.corporateNavy,
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(32), // Şık bir kavis
              ),
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
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SvgPicture.asset(
                        'assets/images/log.svg',
                        width: 32,
                        height: 32,
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
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          'SYSTEM',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Kullanıcı Bilgisi
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white,
                      child: Text(
                        (userName ?? 'T').substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.corporateNavy,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName ?? 'İsimsiz Kullanıcı',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              () {
                                switch (userRole) {
                                  case 'admin':
                                  case 'manager':
                                    return 'YÖNETİCİ';
                                  case 'partner_user':
                                    return 'PARTNER';
                                  case 'technician':
                                  default:
                                    return 'TEKNİSYEN';
                                }
                              }(),
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
              ],
            ),
          ),

          // --- 2. MENÜ LİSTESİ ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              children: [
                _buildModernDrawerItem(
                  icon: Icons.list_alt_rounded,
                  text: 'İş Listesi',
                  isActive: currentPage == AppDrawerPage.ticketList,
                  onTap: () {
                    Navigator.pop(context);
                    if (currentPage != AppDrawerPage.ticketList) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const TicketListPage()),
                      );
                    }
                  },
                  textColor: textColor,
                  activeColor: AppColors.corporateNavy,
                ),
                if (userRole == 'admin' || userRole == 'manager') ...[
                  const SizedBox(height: 4),
                  _buildModernDrawerItem(
                    icon: Icons.dashboard_rounded,
                    text: 'Yönetici Paneli',
                    isActive: currentPage == AppDrawerPage.dashboard,
                    textColor: textColor,
                    activeColor: AppColors.corporateNavy,
                    onTap: () {
                      Navigator.pop(context);
                      if (currentPage != AppDrawerPage.dashboard) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const DashboardPage()),
                        );
                      }
                    },
                  ),
                ],
                const SizedBox(height: 4),
                if (userRole != 'partner_user')
                  _buildModernDrawerItem(
                    icon: Icons.inventory_2_outlined,
                    text: 'Stok Durumu',
                    isActive: currentPage == AppDrawerPage.stock,
                    textColor: textColor,
                    activeColor: AppColors.corporateNavy,
                    onTap: () {
                      Navigator.pop(context);
                      if (currentPage != AppDrawerPage.stock) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const StockOverviewPage()),
                        );
                      }
                    },
                  ),
                const SizedBox(height: 4),
                _buildModernDrawerItem(
                  icon: Icons.task_alt_rounded,
                  text: 'Biten İşler (Arşiv)',
                  isActive: currentPage == AppDrawerPage.archived,
                  textColor: textColor,
                  activeColor: AppColors.corporateNavy,
                  onTap: () {
                    Navigator.pop(context);
                    if (currentPage != AppDrawerPage.archived) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const ArchivedTicketsPage()),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // --- 3. ALT FOOTER ---
          Padding(
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
                  icon: IsTakipApp.of(context)?.isDarkMode == true ? Icons.light_mode : Icons.dark_mode,
                  text: IsTakipApp.of(context)?.isDarkMode == true ? 'Aydınlık Mod' : 'Karanlık Mod',
                  isActive: false,
                  textColor: textColor,
                  activeColor: AppColors.corporateNavy,
                  onTap: () {
                    IsTakipApp.of(context)?.toggleTheme();
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.red),
                    title: const Text(
                      'Çıkış Yap',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () async {
                      await Supabase.instance.client.auth.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      }
                    },
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Özel Tasarım Menü Elemanı
  Widget _buildModernDrawerItem({
    required IconData icon,
    required String text,
    required bool isActive,
    required VoidCallback onTap,
    required Color textColor,
    required Color activeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isActive ? activeColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isActive ? activeColor : textColor.withOpacity(0.6),
          size: 24,
        ),
        title: Text(
          text,
          style: TextStyle(
            color: isActive ? activeColor : textColor,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minLeadingWidth: 24,
      ),
    );
  }
}

