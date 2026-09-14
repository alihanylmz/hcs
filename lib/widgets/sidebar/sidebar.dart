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
import '../../pages/workshop_page.dart';
import '../../services/app_module_service.dart';
import '../../services/permission_service.dart';
import 'nav_shell_colors.dart';
import 'nav_shell_state.dart';
import 'sidebar_item.dart';

/// Onaylanan ortak navigasyon tasariminin sol rayi: acik/beyaz yuzey,
/// "Hos geldin" karsilama satiri, aktif ogede sol cizgi vurgusu, ve en
/// altta daralt/genislet oku. Menu mantigi (rol bazli gorunurluk, sayfa
/// gecisleri, cikis, Uzal Teklif'e gecis) oncekiyle birebir ayni - sadece
/// gorsel katman degisti.
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
    final palette = NavShellColors.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: NavShellState.railExpanded,
      builder: (context, expanded, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: expanded ? 240 : 76,
          decoration: BoxDecoration(
            color: palette.surface,
            // Sag kenar kare birakiliyor: sidebar ust cubukla tam bitisik,
            // aralarinda bosluk/golge olmadan tek bir yuzey gibi duruyor.
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            border: Border(
              top: BorderSide(color: palette.border),
              left: BorderSide(color: palette.border),
              bottom: BorderSide(color: palette.border),
              right: BorderSide(color: palette.border),
            ),
          ),
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLogoRow(context, palette, expanded),
                if (userName != null) ...[
                  const SizedBox(height: 12),
                  _buildWelcomeRow(palette, expanded),
                ],
                const SizedBox(height: 14),
                if (expanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'MODULLER',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      SidebarItem(
                        icon: Icons.assignment_outlined,
                        label: 'Saha İş Emirleri & Servisler',
                        isActive: activeMenuItem == 'ticket_list',
                        expanded: expanded,
                        onTap: () => _navigate(context, const TicketListPage()),
                      ),
                      SidebarItem(
                        icon: Icons.precision_manufacturing_outlined,
                        label: 'Atölye İmalat & Pano Reçeteleri',
                        isActive: activeMenuItem == 'workshop',
                        expanded: expanded,
                        onTap: () => _navigate(context, const WorkshopPage()),
                      ),
                      if (PermissionService.roleHasPermission(
                        userRole,
                        AppPermission.viewStock,
                      ))
                        SidebarItem(
                          icon: Icons.inventory_2_outlined,
                          label: 'Stok ve Ekipman Kataloğu',
                          isActive: activeMenuItem == 'stock',
                          expanded: expanded,
                          onTap:
                              () =>
                                  _navigate(context, const StockOverviewPage()),
                        ),
                      SidebarItem(
                        icon: Icons.task_alt_rounded,
                        label: 'Biten İşler ve Tamamlananlar',
                        isActive: activeMenuItem == 'archived',
                        expanded: expanded,
                        onTap:
                            () =>
                                _navigate(context, const ArchivedTicketsPage()),
                      ),
                      if (PermissionService.roleHasPermission(
                        userRole,
                        AppPermission.viewDashboard,
                      ))
                        SidebarItem(
                          icon: Icons.dashboard_rounded,
                          label: 'Yönetici Performans Panosu',
                          isActive: activeMenuItem == 'dashboard',
                          expanded: expanded,
                          onTap:
                              () => _navigate(context, const DashboardPage()),
                        ),
                      SidebarItem(
                        icon: Icons.support_agent_rounded,
                        label: 'Arıza & Teknik Kılavuz',
                        isActive: activeMenuItem == 'fault_codes',
                        expanded: expanded,
                        onTap: () => _navigate(context, const FaultCodesPage()),
                      ),
                      const SizedBox(height: 8),
                      const SidebarDivider(),
                      const SizedBox(height: 8),
                      SidebarItem(
                        icon: Icons.person_outline_rounded,
                        label: 'Profilim & Ayarlar',
                        isActive: activeMenuItem == 'profile',
                        expanded: expanded,
                        onTap: () => _navigate(context, const ProfilePage()),
                      ),
                    ],
                  ),
                ),
                const SidebarDivider(),
                const SizedBox(height: 8),
                _buildQuoteSwitchCard(context, palette, expanded),
                const SizedBox(height: 8),
                _buildLogoutRow(context, palette, expanded),
                const SizedBox(height: 4),
                _buildCollapseToggle(palette, expanded),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoRow(
    BuildContext context,
    NavShellPalette palette,
    bool expanded,
  ) {
    final logo = Container(
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: SvgPicture.asset(
        'assets/images/log.svg',
        colorFilter: ColorFilter.mode(palette.accent, BlendMode.srcIn),
      ),
    );
    if (!expanded) {
      return Center(child: logo);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          logo,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'İş Takip',
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeRow(NavShellPalette palette, bool expanded) {
    final avatar = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: palette.avatarBackground,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person_rounded, size: 18, color: palette.accent),
    );
    if (!expanded) {
      return Center(child: avatar);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hoş geldin,',
                  style: TextStyle(fontSize: 11, color: palette.textSecondary),
                ),
                Text(
                  userName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteSwitchCard(
    BuildContext context,
    NavShellPalette palette,
    bool expanded,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => AppModuleService.switchToQuote(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 12 : 0,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: palette.accentSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.accent.withValues(alpha: 0.3)),
          ),
          child:
              expanded
                  ? Row(
                    children: [
                      Icon(
                        Icons.description_outlined,
                        size: 18,
                        color: palette.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Uzal Teklif & Keşif',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: palette.textPrimary,
                              ),
                            ),
                            Text(
                              'Teklif Sistemine Geç ➔',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: palette.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                  : Center(
                    child: Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: palette.accent,
                    ),
                  ),
        ),
      ),
    );
  }

  Widget _buildLogoutRow(
    BuildContext context,
    NavShellPalette palette,
    bool expanded,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleLogout(context),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 12 : 0,
            vertical: 9,
          ),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 18, color: palette.danger),
              if (expanded) ...[
                const SizedBox(width: 10),
                Text(
                  'Oturumu Kapat',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: palette.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseToggle(NavShellPalette palette, bool expanded) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: NavShellState.toggleRail,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 12 : 0,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment:
                expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: palette.textSecondary,
                ),
              ),
              if (expanded) ...[
                const SizedBox(width: 8),
                Text(
                  'Daralt',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ],
          ),
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
}
