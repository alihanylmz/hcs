import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../main.dart';
import '../../services/app_module_service.dart';
import '../../theme/app_colors.dart';
import '../app_drawer.dart';
import 'nav_shell_colors.dart';
import 'sidebar.dart';

enum AppPage {
  ticketList,
  workshop,
  dashboard,
  stock,
  archived,
  profile,
  faultCodes,
  notifications,
  other,
}

class AppLayout extends StatelessWidget {
  const AppLayout({
    super.key,
    required this.child,
    required this.currentPage,
    required this.title,
    this.userName,
    this.userRole,
    this.actions,
    this.floatingActionButton,
    this.onProfileReload,
    this.showAppBar = true,
    this.searchController,
    this.searchHint,
    this.onSearchChanged,
  });

  final Widget child;
  final AppPage currentPage;
  final String? userName;
  final String? userRole;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final VoidCallback? onProfileReload;
  final bool showAppBar;
  // Ust cubuktaki arama pilini gercek, calisan bir alana donusturmek icin
  // sayfa kendi arama state'ini buraya baglar. Verilmezse pil sadece
  // sabit "Ara..." metniyle dekoratif kalir (baglanmamis sayfalarda
  // yaniltici olmasin diye).
  final TextEditingController? searchController;
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 1024;

    final layoutBody = Stack(
      children: [
        const Positioned.fill(child: _DashboardBackdrop()),
        if (isWideScreen)
          SafeArea(
            minimum: const EdgeInsets.all(12),
            child: Row(
              children: [
                RepaintBoundary(
                  child: Sidebar(
                    activeMenuItem: _getActiveMenuItem(),
                    userName: userName,
                    userRole: userRole,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      if (showAppBar)
                        RepaintBoundary(child: _buildDesktopAppBar(context)),
                      if (showAppBar) const SizedBox(height: 12),
                      Expanded(child: _DesktopContentShell(child: child)),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          SafeArea(top: false, child: child),
      ],
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer:
          isWideScreen
              ? null
              : AppDrawer(
                currentPage: _convertToDrawerPage(),
                userName: userName,
                userRole: userRole,
                onProfileReload: onProfileReload,
              ),
      appBar:
          isWideScreen
              ? null
              : (showAppBar ? _buildMobileAppBar(context) : null),
      body: layoutBody,
      floatingActionButton: floatingActionButton,
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      toolbarHeight: 64,
      titleSpacing: 0,
      surfaceTintColor: Colors.transparent,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _pageLabel(currentPage),
            style: theme.textTheme.labelMedium?.copyWith(
              letterSpacing: 1.0,
              color: isDark ? AppColors.textOnDarkMuted : AppColors.textLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
      leadingWidth: 88,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 8),
          Builder(
            builder: (buttonContext) {
              return IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(buttonContext).openDrawer(),
              );
            },
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.surfaceDarkMuted : AppColors.surfaceAccent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
              ),
            ),
            padding: const EdgeInsets.all(6),
            child: SvgPicture.asset('assets/images/log.svg'),
          ),
        ],
      ),
      backgroundColor:
          isDark
              ? AppColors.surfaceDarkRaised.withValues(alpha: 0.94)
              : Colors.white.withValues(alpha: 0.94),
      elevation: 0,
      actions: [
        _buildThemeToggle(context, compact: true),
        if (actions != null) ...actions!,
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
      ),
    );
  }

  Widget _buildDesktopAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final palette = NavShellColors.of(context);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: palette.surface,
        // Sol ust kose kare: sidebar'in ust ucuyla tam bitisik, tek parca
        // gibi duruyor.
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
          Container(
            width: 34,
            height: 34,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: SvgPicture.asset(
              'assets/images/log.svg',
              colorFilter: ColorFilter.mode(palette.accent, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(width: 16),
          _buildAppSwitcherChip(context, palette),
          const SizedBox(width: 16),
          Expanded(child: _buildSearchPill(palette)),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: 12),
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: actions!),
              ),
            ),
          ],
          const SizedBox(width: 12),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              'İş Takip',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: palette.accentOn,
              ),
            ),
          ),
          InkWell(
            onTap: () => AppModuleService.switchToQuote(context),
            borderRadius: BorderRadius.circular(7),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                'Teklif',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPill(NavShellPalette palette) {
    final hasSearch = searchController != null;

    return Container(
      height: 38,
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: palette.pageBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 17, color: palette.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child:
                hasSearch
                    ? TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      textInputAction: TextInputAction.search,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.textPrimary,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: searchHint ?? 'Ara...',
                        hintStyle: TextStyle(
                          fontSize: 12.5,
                          color: palette.textSecondary,
                        ),
                      ),
                    )
                    : Text(
                      'Ara...',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.textSecondary,
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

  Widget _buildThemeToggle(BuildContext context, {bool compact = false}) {
    final appState = IsTakipApp.of(context);
    final isDark =
        appState?.isDarkMode ??
        (Theme.of(context).brightness == Brightness.dark);
    final backgroundColor =
        isDark ? AppColors.surfaceDarkMuted : AppColors.surfaceSoft;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderSubtle;
    final iconColor =
        isDark ? AppColors.corporateYellow : AppColors.corporateBlue;
    final labelColor = isDark ? AppColors.textOnDark : AppColors.textDark;

    return Tooltip(
      message: isDark ? 'Acik temaya gec' : 'Koyu temaya gec',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => appState?.toggleTheme(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: compact ? 42 : 48,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 14,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: compact ? 28 : 32,
                  height: compact ? 28 : 32,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B1220) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.16 : 0.06,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    size: compact ? 16 : 18,
                    color: iconColor,
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 10),
                  Text(
                    isDark ? 'Koyu' : 'Acik',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: labelColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _pageLabel(AppPage page) {
    switch (page) {
      case AppPage.ticketList:
        return 'SERVIS MASASI';
      case AppPage.workshop:
        return 'ATOLYE';
      case AppPage.dashboard:
        return 'ANALITIK PANEL';
      case AppPage.stock:
        return 'ENVANTER';
      case AppPage.archived:
        return 'ARSIV';
      case AppPage.profile:
        return 'HESAP';
      case AppPage.faultCodes:
        return 'ARIZA REHBERI';
      case AppPage.notifications:
        return 'BILDIRIMLER';
      case AppPage.other:
        return 'WORKSPACE';
    }
  }

  String _getActiveMenuItem() {
    switch (currentPage) {
      case AppPage.ticketList:
        return 'ticket_list';
      case AppPage.workshop:
        return 'workshop';
      case AppPage.dashboard:
        return 'dashboard';
      case AppPage.stock:
        return 'stock';
      case AppPage.archived:
        return 'archived';
      case AppPage.profile:
        return 'profile';
      case AppPage.faultCodes:
        return 'fault_codes';
      case AppPage.notifications:
        return 'notifications';
      case AppPage.other:
        return '';
    }
  }

  AppDrawerPage _convertToDrawerPage() {
    switch (currentPage) {
      case AppPage.ticketList:
        return AppDrawerPage.ticketList;
      case AppPage.workshop:
        return AppDrawerPage.workshop;
      case AppPage.dashboard:
        return AppDrawerPage.dashboard;
      case AppPage.stock:
        return AppDrawerPage.stock;
      case AppPage.archived:
        return AppDrawerPage.archived;
      case AppPage.profile:
        return AppDrawerPage.profile;
      case AppPage.faultCodes:
        return AppDrawerPage.faultCodes;
      case AppPage.notifications:
        return AppDrawerPage.notifications;
      case AppPage.other:
        return AppDrawerPage.other;
    }
  }
}

class _DesktopContentShell extends StatelessWidget {
  const _DesktopContentShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = NavShellColors.of(context);

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

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    // Duz, acik lavanta-gri zemin (nav kabugunun referans paleti). Eski
    // izgara dokusu ve kum rengi zemin yeni tasarimla uyumsuzdu, kaldirildi.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NavShellColors.of(context).pageBackground,
      ),
    );
  }
}
