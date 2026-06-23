import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../main.dart';
import '../../theme/app_colors.dart';
import '../app_drawer.dart';
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
            minimum: const EdgeInsets.all(16),
            child: Row(
              children: [
                RepaintBoundary(
                  child: Sidebar(
                    activeMenuItem: _getActiveMenuItem(),
                    userName: userName,
                    userRole: userRole,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      if (showAppBar)
                        RepaintBoundary(child: _buildDesktopAppBar(context)),
                      if (showAppBar) const SizedBox(height: 16),
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
      toolbarHeight: 76,
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
              borderRadius: BorderRadius.circular(12),
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color:
            isDark
                ? AppColors.surfaceDarkRaised.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.surfaceDarkMuted : AppColors.surfaceAccent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
              ),
            ),
            child: SvgPicture.asset('assets/images/log.svg'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pageLabel(currentPage),
                  style: theme.textTheme.labelMedium?.copyWith(
                    letterSpacing: 1.2,
                    color:
                        isDark
                            ? AppColors.textOnDarkMuted
                            : AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: 16),
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: actions!),
              ),
            ),
            const SizedBox(width: 12),
          ],
          _buildThemeToggle(context),
        ],
      ),
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
          borderRadius: BorderRadius.circular(18),
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
              borderRadius: BorderRadius.circular(18),
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
                    borderRadius: BorderRadius.circular(12),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color:
            isDark
                ? AppColors.surfaceDark.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(18), child: child),
    );
  }
}

class _DashboardBackdrop extends StatelessWidget {
  const _DashboardBackdrop();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? AppColors.backgroundDark : AppColors.backgroundGrey,
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: isDark ? 0.02 : 0.20),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
              ],
              stops: const [0.0, 0.24, 0.72, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
