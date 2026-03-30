import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../main.dart';
import '../../theme/app_colors.dart';
import '../app_drawer.dart';
import 'sidebar.dart';

enum AppPage {
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
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 1024;

    final body = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isDark
                  ? const [
                    Color(0xFF0B1520),
                    AppColors.backgroundDark,
                    Color(0xFF152638),
                  ]
                  : const [
                    Color(0xFFF8FAFD),
                    AppColors.backgroundGrey,
                    Color(0xFFECF3FA),
                  ],
        ),
      ),
      child:
          isWideScreen
              ? Row(
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
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ],
              )
              : child,
    );

    if (isWideScreen) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: body,
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: AppDrawer(
        currentPage: _convertToDrawerPage(),
        userName: userName,
        userRole: userRole,
        onProfileReload: onProfileReload,
      ),
      appBar: showAppBar ? _buildMobileAppBar(context) : null,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      titleSpacing: 0,
      title: Text(title),
      leadingWidth: 92,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
              ? AppColors.surfaceDarkRaised.withOpacity(0.96)
              : AppColors.surfaceWhite.withOpacity(0.97),
      elevation: 0,
      actions: [
        _buildThemeToggle(context, compact: true),
        if (actions != null) ...actions!,
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
      height: 76,
      margin: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color:
            isDark
                ? AppColors.surfaceDarkRaised.withOpacity(0.94)
                : AppColors.surfaceWhite.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.10 : 0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.appBarTheme.titleTextStyle,
            ),
          ),
          _buildThemeToggle(context),
          const SizedBox(width: 12),
          if (actions != null) ...actions!,
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
        isDark ? AppColors.surfaceDarkMuted : AppColors.surfaceMuted;
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
                    color: isDark ? const Color(0xFF102030) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.08 : 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
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
                      fontWeight: FontWeight.w700,
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

  String _getActiveMenuItem() {
    switch (currentPage) {
      case AppPage.ticketList:
        return 'ticket_list';
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
      case AppPage.myTeams:
        return 'my_teams';
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
      case AppPage.myTeams:
        return AppDrawerPage.myTeams;
      case AppPage.notifications:
        return AppDrawerPage.notifications;
      case AppPage.other:
        return AppDrawerPage.other;
    }
  }
}
