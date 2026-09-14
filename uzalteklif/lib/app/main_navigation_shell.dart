import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/admin_panel_page.dart';
import '../screens/cariler_page.dart';
import '../screens/discovery_projects_page.dart';
import '../screens/home_page.dart';
import '../screens/my_workspace_page.dart';
import '../screens/profile_settings_page.dart';
import '../screens/quotes_page.dart';
import '../services/module_switcher.dart';
import 'bootstrap.dart';
import '../services/app_update_coordinator.dart';
import 'nav_shell_colors.dart';
import 'nav_shell_state.dart';

/// Ana navigasyon kabugu: genis ekranda Is Takip ile ayni gorsel dilde
/// (beyaz/acik lavanta zemin, mavi aksan, acilir/kapanir sol ray + ust
/// cubuk) bir Sidebar; dar ekranda alt gezinme cubugu (NavigationBar)
/// degismedi.
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({
    super.key,
    required this.bootstrap,
    this.onSignOut,
  });

  final AppBootstrap bootstrap;
  final Future<void> Function()? onSignOut;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _index = 0;
  bool _isManager = false;
  bool _canManageSystem = false;
  String? _userName;
  String? _userRoleLabel;

  @override
  void initState() {
    super.initState();
    _refreshRole();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(AppUpdateCoordinator.checkAndPrompt(context));
    });
  }

  Future<void> _refreshRole() async {
    final p = await widget.bootstrap.userProfileRepository.fetchMine();
    if (!mounted) return;
    setState(() {
      _isManager = p?.isManager ?? false;
      _canManageSystem = p?.canManageUsers ?? false;
      _userName = p?.preparedByName;
      _userRoleLabel = p == null ? null : _roleLabelOf(p.role);
      if (!_canManageSystem && _index > 4) _index = 4;
    });
  }

  String _roleLabelOf(String role) {
    // UserQuoteProfile.roleLabel statik yardimcisi zaten var; burada
    // dogrudan cagirmak icin import gerekmiyor cunku ayni paket icinde
    // erisilebilir degil (statik metod baska dosyada) - basit bir yerel
    // esleme yeterli, sidebar'da sadece kucuk bir rozet olarak gorunuyor.
    switch (role) {
      case 'admin':
        return 'Yönetici';
      case 'manager':
        return 'Müdür';
      case 'finance':
        return 'Finans';
      case 'operations':
        return 'Operasyon';
      case 'viewer':
        return 'İzleyici';
      default:
        return 'Satış';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 840;
        final page = _pageForIndex(_index);
        if (compact) {
          return Scaffold(
            body: page,
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              labelBehavior: constraints.maxWidth < 560
                  ? NavigationDestinationLabelBehavior.onlyShowSelected
                  : NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: _selectDestination,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard_rounded),
                  label: 'Masam',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.request_quote_outlined),
                  selectedIcon: Icon(Icons.request_quote_rounded),
                  label: 'Teklifler',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.business_outlined),
                  selectedIcon: Icon(Icons.business_rounded),
                  label: 'Cariler',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.account_tree_outlined),
                  selectedIcon: Icon(Icons.account_tree_rounded),
                  label: 'Keşif',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profil',
                ),
                if (_canManageSystem)
                  const NavigationDestination(
                    icon: Icon(Icons.admin_panel_settings_outlined),
                    selectedIcon: Icon(Icons.admin_panel_settings_rounded),
                    label: 'Yönetim',
                  ),
              ],
            ),
          );
        }

        final palette = NavShellColors.of(context);

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: palette.pageBackground),
                ),
              ),
              SafeArea(
                minimum: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RepaintBoundary(child: _buildSidebar(context, palette)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTopBar(context, palette),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _DesktopContentShell(
                              palette: palette,
                              child: page,
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
        );
      },
    );
  }

  // ---- Sol ray (Is Takip'teki Sidebar ile ayni gorsel dil) ----

  Widget _buildSidebar(BuildContext context, NavShellPalette palette) {
    return ValueListenableBuilder<bool>(
      valueListenable: NavShellState.railExpanded,
      builder: (context, expanded, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: expanded ? 240 : 76,
          decoration: BoxDecoration(
            color: palette.surface,
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLogoRow(palette, expanded),
                if (_userName != null && _userName!.isNotEmpty) ...[
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
                      _navItem(
                        palette,
                        expanded,
                        icon: Icons.space_dashboard_outlined,
                        selectedIcon: Icons.space_dashboard_rounded,
                        label: 'Masam',
                        index: 0,
                      ),
                      _navItem(
                        palette,
                        expanded,
                        icon: Icons.request_quote_outlined,
                        selectedIcon: Icons.request_quote_rounded,
                        label: 'Teklifler',
                        index: 1,
                      ),
                      _navItem(
                        palette,
                        expanded,
                        icon: Icons.business_outlined,
                        selectedIcon: Icons.business_rounded,
                        label: 'Cariler',
                        index: 2,
                      ),
                      _navItem(
                        palette,
                        expanded,
                        icon: Icons.inventory_2_outlined,
                        selectedIcon: Icons.inventory_2_rounded,
                        label: 'Stok',
                        index: 3,
                      ),
                      _navItem(
                        palette,
                        expanded,
                        icon: Icons.account_tree_outlined,
                        selectedIcon: Icons.account_tree_rounded,
                        label: 'Keşif',
                        index: 4,
                      ),
                      const SizedBox(height: 8),
                      _SidebarDivider(palette: palette),
                      const SizedBox(height: 8),
                      _navItem(
                        palette,
                        expanded,
                        icon: Icons.person_outline_rounded,
                        selectedIcon: Icons.person_rounded,
                        label: 'Profil',
                        index: 5,
                      ),
                      if (_canManageSystem)
                        _navItem(
                          palette,
                          expanded,
                          icon: Icons.admin_panel_settings_outlined,
                          selectedIcon: Icons.admin_panel_settings_rounded,
                          label: 'Yönetim',
                          index: 6,
                        ),
                    ],
                  ),
                ),
                _SidebarDivider(palette: palette),
                const SizedBox(height: 8),
                _buildTaskSwitchCard(context, palette, expanded),
                if (widget.onSignOut != null) ...[
                  const SizedBox(height: 8),
                  _buildLogoutRow(palette, expanded),
                ],
                const SizedBox(height: 4),
                _buildCollapseToggle(palette, expanded),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _navItem(
    NavShellPalette palette,
    bool expanded, {
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    final isActive = _index == index;
    return _SidebarItem(
      palette: palette,
      icon: isActive ? selectedIcon : icon,
      label: label,
      isActive: isActive,
      expanded: expanded,
      onTap: () => _selectDestination(index),
    );
  }

  Widget _buildLogoRow(NavShellPalette palette, bool expanded) {
    final logo = Container(
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset('lib/assest/logo/uzal.png', fit: BoxFit.contain),
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
              'Uzal Teklif',
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
                  _userName ?? '',
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

  Widget _buildTaskSwitchCard(
    BuildContext context,
    NavShellPalette palette,
    bool expanded,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ModuleSwitcher.switchToTask(context),
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
          child: expanded
              ? Row(
                  children: [
                    Icon(
                      Icons.assignment_outlined,
                      size: 18,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'İş Takip & Atölye',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                          Text(
                            'İş Takip Sistemine Geç ➔',
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
                    Icons.assignment_outlined,
                    size: 18,
                    color: palette.accent,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLogoutRow(NavShellPalette palette, bool expanded) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onSignOut,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 12 : 0,
            vertical: 9,
          ),
          child: Row(
            mainAxisAlignment: expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 18, color: palette.danger),
              if (expanded) ...[
                const SizedBox(width: 10),
                Text(
                  'Çıkış',
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
            mainAxisAlignment: expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
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

  // ---- Ust cubuk (Is Takip'teki masaustu AppBar ile ayni gorsel dil) ----

  Widget _buildTopBar(BuildContext context, NavShellPalette palette) {
    final theme = Theme.of(context);
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(color: palette.border),
          right: BorderSide(color: palette.border),
          bottom: BorderSide(color: palette.border),
        ),
      ),
      child: Row(
        children: [
          Text(
            _titleForIndex(_index),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(width: 16),
          _buildAppSwitcherChip(context, palette),
          const Spacer(),
          if (_userRoleLabel != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _userRoleLabel!,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: palette.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          _buildThemeToggle(context),
          const SizedBox(width: 12),
          Container(width: 1, height: 26, color: palette.border),
          const SizedBox(width: 12),
          _buildAvatar(palette),
        ],
      ),
    );
  }

  Widget _buildAppSwitcherChip(BuildContext context, NavShellPalette palette) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.pageBackground,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => ModuleSwitcher.switchToTask(context),
            borderRadius: BorderRadius.circular(7),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'İş Takip',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              'Teklif',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: palette.accentOn,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(NavShellPalette palette) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: palette.avatarBackground,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person_rounded, size: 17, color: palette.accent),
    );
  }

  Widget _buildThemeToggle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: isDark ? 'Açık temaya geç' : 'Koyu temaya geç',
      child: IconButton(
        icon: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
        onPressed: () {
          widget.bootstrap.themePreferenceService.setMode(
            isDark ? ThemeMode.light : ThemeMode.dark,
          );
        },
      ),
    );
  }

  String _titleForIndex(int index) {
    switch (index) {
      case 0:
        return 'MASAM';
      case 1:
        return 'TEKLIFLER';
      case 2:
        return 'CARILER';
      case 3:
        return 'STOK';
      case 4:
        return 'KEŞİF';
      case 5:
        return 'PROFIL';
      case 6:
        return 'YÖNETIM';
      default:
        return 'UZAL TEKLIF';
    }
  }

  void _selectDestination(int index) {
    setState(() => _index = index);
    if (index == 1 || index == 2 || index == 3 || index == 4) {
      _refreshRole();
    }
  }

  Widget _pageForIndex(int i) {
    switch (i) {
      case 0:
        return MyWorkspacePage(
          embedded: true,
          quoteRepository: widget.bootstrap.quoteRepository,
          productRepository: widget.bootstrap.productRepository,
          marketRateService: widget.bootstrap.marketRateService,
          userProfileRepository: widget.bootstrap.userProfileRepository,
          cariRepository: widget.bootstrap.cariRepository,
          ownCompanyRepository: widget.bootstrap.ownCompanyRepository,
          priceAdjustmentRuleRepository:
              widget.bootstrap.priceAdjustmentRuleRepository,
          personalNoteRepository: widget.bootstrap.personalNoteRepository,
          isManager: _isManager,
        );
      case 1:
        return QuotesPage(
          quoteRepository: widget.bootstrap.quoteRepository,
          productRepository: widget.bootstrap.productRepository,
          marketRateService: widget.bootstrap.marketRateService,
          ownCompanyRepository: widget.bootstrap.ownCompanyRepository,
          priceAdjustmentRuleRepository:
              widget.bootstrap.priceAdjustmentRuleRepository,
          userProfileRepository: widget.bootstrap.userProfileRepository,
          cariRepository: widget.bootstrap.cariRepository,
          personalNoteRepository: widget.bootstrap.personalNoteRepository,
          isManager: _isManager,
        );
      case 2:
        return CarilerPage(
          embedded: true,
          repository: widget.bootstrap.cariRepository,
          quoteRepository: widget.bootstrap.quoteRepository,
          productRepository: widget.bootstrap.productRepository,
          marketRateService: widget.bootstrap.marketRateService,
          ownCompanyRepository: widget.bootstrap.ownCompanyRepository,
          priceAdjustmentRuleRepository:
              widget.bootstrap.priceAdjustmentRuleRepository,
          userProfileRepository: widget.bootstrap.userProfileRepository,
          isManager: _isManager,
        );
      case 3:
        return HomePage(
          productRepository: widget.bootstrap.productRepository,
          marketRateService: widget.bootstrap.marketRateService,
          priceAdjustmentRuleRepository:
              widget.bootstrap.priceAdjustmentRuleRepository,
        );
      case 4:
        return DiscoveryProjectsPage(
          repository: widget.bootstrap.discoveryRepository,
          hardwareRepository: widget.bootstrap.controlHardwareRepository,
          productRepository: widget.bootstrap.productRepository,
          quoteRepository: widget.bootstrap.quoteRepository,
          marketRateService: widget.bootstrap.marketRateService,
          userProfileRepository: widget.bootstrap.userProfileRepository,
          cariRepository: widget.bootstrap.cariRepository,
          ownCompanyRepository: widget.bootstrap.ownCompanyRepository,
          priceAdjustmentRuleRepository:
              widget.bootstrap.priceAdjustmentRuleRepository,
        );
      case 5:
        return ProfileSettingsPage(
          repository: widget.bootstrap.userProfileRepository,
          themePreferenceService: widget.bootstrap.themePreferenceService,
          ownCompanyRepository: widget.bootstrap.ownCompanyRepository,
          onSignOut: widget.onSignOut,
          showOwnAppBar: false,
        );
      case 6:
        if (_canManageSystem) {
          return AdminPanelPage(
            userProfileRepository: widget.bootstrap.userProfileRepository,
            adminRepository: widget.bootstrap.adminRepository,
            ownCompanyRepository: widget.bootstrap.ownCompanyRepository,
            priceAdjustmentRuleRepository:
                widget.bootstrap.priceAdjustmentRuleRepository,
            productRepository: widget.bootstrap.productRepository,
          );
        }
        return ProfileSettingsPage(
          repository: widget.bootstrap.userProfileRepository,
          themePreferenceService: widget.bootstrap.themePreferenceService,
          ownCompanyRepository: widget.bootstrap.ownCompanyRepository,
          onSignOut: widget.onSignOut,
          showOwnAppBar: false,
        );
      default:
        return ProfileSettingsPage(
          repository: widget.bootstrap.userProfileRepository,
          themePreferenceService: widget.bootstrap.themePreferenceService,
          ownCompanyRepository: widget.bootstrap.ownCompanyRepository,
          onSignOut: widget.onSignOut,
          showOwnAppBar: false,
        );
    }
  }
}

/// Aktif ogede sol cizgi vurgusu + hafif tonlu arka plan - Is Takip'teki
/// `SidebarItem` ile ayni gorsel dil.
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.expanded = true,
  });

  final NavShellPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? palette.accent : palette.textSecondary;
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 12 : 0,
        vertical: 11,
      ),
      child: Row(
        mainAxisAlignment: expanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: color),
          if (expanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? palette.textPrimary : color,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Stack(
        children: [
          if (isActive)
            Positioned(
              left: 0,
              top: 4,
              bottom: 4,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(3),
                  ),
                ),
              ),
            ),
          Material(
            color: isActive ? palette.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider({required this.palette});

  final NavShellPalette palette;

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: palette.border);
  }
}

class _DesktopContentShell extends StatelessWidget {
  const _DesktopContentShell({required this.palette, required this.child});

  final NavShellPalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: child),
    );
  }
}
