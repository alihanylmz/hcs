import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import '../main.dart';
import '../pages/dashboard_page.dart';
import '../pages/stock_overview_page.dart';
import '../pages/archived_tickets_page.dart';
import '../pages/profile_page.dart';
import '../pages/ticket_list_page.dart';
import '../pages/login_page.dart';
import '../pages/partner_management_page.dart';
import '../pages/fault_codes_page.dart';
import '../pages/my_teams_page.dart';
import '../services/permission_service.dart';
import '../theme/app_colors.dart';

enum AppDrawerPage {
  ticketList,
  dashboard,
  stock,
  archived,
  profile,
  faultCodes,
  myTeams,
  notifications,
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

    final Color baseBg =
        isDark
            ? AppColors.sidebarBackgroundDark
            : AppColors.sidebarBackgroundLight;
    final Color divider = Colors.white.withOpacity(isDark ? 0.08 : 0.10);
    final Color textColor = AppColors.sidebarText;
    final Color iconMuted = AppColors.sidebarTextMuted;
    final Color activeBg =
        isDark ? AppColors.sidebarActiveDark : AppColors.sidebarActiveLight;
    final Color accent = AppColors.corporateYellow;

    return Drawer(
      width: 320,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          bottom: 12,
          left: 12,
          right: 12,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.15),
                blurRadius: 40,
                offset: const Offset(20, 0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: baseBg,
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),

                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: isDark ? 0.04 : 0.03,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _NoisePainter(isDark: isDark),
                        ),
                      ),
                    ),
                  ),
                ),

                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.black.withOpacity(isDark ? 0.12 : 0.08),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(isDark ? 0.12 : 0.08),
                          ],
                          stops: const [0.0, 0.18, 0.82, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProfileHeader(
                        userName: userName,
                        userRole: userRole,
                        isDark: isDark,
                        accent: accent,
                        textColor: textColor,
                        iconMuted: iconMuted,
                      ),
                      Divider(height: 1, thickness: 1, color: divider),
                      const SizedBox(height: 8),

                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 12),
                          children: [
                            _NavTile(
                              label: 'Tak\u0131mlar\u0131m',
                              icon: Icons.groups_outlined,
                              active: currentPage == AppDrawerPage.myTeams,
                              iconMuted: iconMuted,
                              textColor: textColor,
                              activeBg: activeBg,
                              accent: accent,
                              onTap:
                                  () => _navigate(
                                    context,
                                    AppDrawerPage.myTeams,
                                    MyTeamsPage(),
                                  ),
                            ),
                            // _NavTile(
                            //   label: 'Bildirimler',
                            //   icon: Icons.notifications_outlined,
                            //   active: currentPage == AppDrawerPage.notifications,
                            //   iconMuted: iconMuted,
                            //   textColor: textColor,
                            //   activeBg: activeBg,
                            //   accent: accent,
                            //   onTap: () => _navigate(context, AppDrawerPage.notifications, TeamNotificationsPage()),
                            // ),
                            _NavTile(
                              label: '\u0130\u015f Listesi',
                              icon: Icons.list_alt_rounded,
                              active: currentPage == AppDrawerPage.ticketList,
                              iconMuted: iconMuted,
                              textColor: textColor,
                              activeBg: activeBg,
                              accent: accent,
                              onTap:
                                  () => _navigate(
                                    context,
                                    AppDrawerPage.ticketList,
                                    const TicketListPage(),
                                  ),
                            ),
                            if (PermissionService.roleHasPermission(
                              userRole,
                              AppPermission.viewDashboard,
                            ))
                              _NavTile(
                                label: 'Y\u00f6netici Paneli',
                                icon: Icons.dashboard_rounded,
                                active: currentPage == AppDrawerPage.dashboard,
                                iconMuted: iconMuted,
                                textColor: textColor,
                                activeBg: activeBg,
                                accent: accent,
                                onTap:
                                    () => _navigate(
                                      context,
                                      AppDrawerPage.dashboard,
                                      const DashboardPage(),
                                    ),
                              ),
                            if (PermissionService.roleHasPermission(
                              userRole,
                              AppPermission.viewStock,
                            ))
                              _NavTile(
                                label: 'Stok Durumu',
                                icon: Icons.inventory_2_outlined,
                                active: currentPage == AppDrawerPage.stock,
                                iconMuted: iconMuted,
                                textColor: textColor,
                                activeBg: activeBg,
                                accent: accent,
                                onTap:
                                    () => _navigate(
                                      context,
                                      AppDrawerPage.stock,
                                      const StockOverviewPage(),
                                    ),
                              ),
                            _NavTile(
                              label: 'Biten \u0130\u015fler (Ar\u015fiv)',
                              icon: Icons.task_alt_rounded,
                              active: currentPage == AppDrawerPage.archived,
                              iconMuted: iconMuted,
                              textColor: textColor,
                              activeBg: activeBg,
                              accent: accent,
                              onTap:
                                  () => _navigate(
                                    context,
                                    AppDrawerPage.archived,
                                    const ArchivedTicketsPage(),
                                  ),
                            ),
                            _NavTile(
                              label: 'Ar\u0131za Rehberi',
                              icon: Icons.support_agent_rounded,
                              active: currentPage == AppDrawerPage.faultCodes,
                              iconMuted: iconMuted,
                              textColor: textColor,
                              activeBg: activeBg,
                              accent: accent,
                              onTap:
                                  () => _navigate(
                                    context,
                                    AppDrawerPage.faultCodes,
                                    const FaultCodesPage(),
                                  ),
                            ),

                            const SizedBox(height: 8),
                            Divider(height: 1, thickness: 1, color: divider),
                            const SizedBox(height: 8),

                            _NavTile(
                              label: 'Profilim',
                              icon: Icons.person_outline_rounded,
                              active: currentPage == AppDrawerPage.profile,
                              iconMuted: iconMuted,
                              textColor: textColor,
                              activeBg: activeBg,
                              accent: accent,
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (_) => const ProfilePage(),
                                      ),
                                    )
                                    .then((_) => onProfileReload?.call());
                              },
                            ),
                            _NavTile(
                              label:
                                  IsTakipApp.of(context)?.isDarkMode == true
                                      ? 'Ayd\u0131nl\u0131k Mod'
                                      : 'Karanl\u0131k Mod',
                              icon:
                                  IsTakipApp.of(context)?.isDarkMode == true
                                      ? Icons.light_mode_outlined
                                      : Icons.dark_mode_outlined,
                              active: false,
                              iconMuted: iconMuted,
                              textColor: textColor,
                              activeBg: activeBg,
                              accent: accent,
                              onTap:
                                  () => IsTakipApp.of(context)?.toggleTheme(),
                            ),

                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () async {
                                    await Supabase.instance.client.auth
                                        .signOut();
                                    if (context.mounted) {
                                      Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute(
                                          builder: (_) => const LoginPage(),
                                        ),
                                        (route) => false,
                                      );
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.logout_rounded,
                                          color: Colors.red.withOpacity(0.85),
                                          size: 22,
                                        ),
                                        const SizedBox(width: 14),
                                        Text(
                                          '\u00c7\u0131k\u0131\u015f Yap',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red.withOpacity(0.90),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
        ),
      ),
    );
  }

  void _navigate(BuildContext context, AppDrawerPage page, Widget widget) {
    Navigator.pop(context);
    if (currentPage != page) {
      // pushReplacement iOS geri-swipe/back davranÄ±ÅŸÄ±nÄ± bozar; push ile doÄŸal geri hareketi korunur.
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => widget));
    }
  }

  String _getUserRoleLabel(String? role) {
    return PermissionService.roleLabel(role).toUpperCase();
  }
}

class _ProfileHeader extends StatelessWidget {
  final String? userName;
  final String? userRole;
  final bool isDark;
  final Color accent;
  final Color textColor;
  final Color iconMuted;

  const _ProfileHeader({
    required this.userName,
    required this.userRole,
    required this.isDark,
    required this.accent,
    required this.textColor,
    required this.iconMuted,
  });

  @override
  Widget build(BuildContext context) {
    final displayName =
        (userName == null || userName!.trim().isEmpty)
            ? 'Kullan\u0131c\u0131'
            : userName!.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          // Avatar ring
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF0B1220) : Colors.white,
              ),
              child: CircleAvatar(
                backgroundColor:
                    isDark ? Colors.white10 : const Color(0xFFEAEAEA),
                child: Text(
                  displayName.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black54,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _roleLabel(userRole),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: iconMuted),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.close_rounded, color: iconMuted, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String? role) {
    return PermissionService.roleLabel(role);
  }
}

class _NavTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final Color textColor;
  final Color iconMuted;
  final Color activeBg;
  final Color accent;

  const _NavTile({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    required this.textColor,
    required this.iconMuted,
    required this.activeBg,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? activeBg : Colors.transparent;
    final fg = active ? textColor : textColor.withOpacity(0.95);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side:
              active
                  ? BorderSide(color: Colors.white.withOpacity(0.10))
                  : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 22, color: iconMuted),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
                if (active)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  final bool isDark;
  const _NoisePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(1337);
    final int count =
        ((size.width * size.height) / 1200).clamp(400, 1400).toInt();
    final paint =
        Paint()
          ..style = PaintingStyle.fill
          ..strokeWidth = 1;

    for (int i = 0; i < count; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final r = rnd.nextDouble() < 0.08 ? 1.2 : 0.8;
      final alpha = (rnd.nextDouble() * 35).toInt(); // subtle
      paint.color = (isDark ? Colors.white : Colors.black).withAlpha(alpha);
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
