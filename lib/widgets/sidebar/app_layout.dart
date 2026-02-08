import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  final Widget child;
  final AppPage currentPage;
  final String? userName;
  final String? userRole;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final VoidCallback? onProfileReload;
  final bool showAppBar;

  const AppLayout({
    Key? key,
    required this.child,
    required this.currentPage,
    this.userName,
    this.userRole,
    required this.title,
    this.actions,
    this.floatingActionButton,
    this.onProfileReload,
    this.showAppBar = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 1024; // Desktop/Tablet landscape

    if (isWideScreen) {
      // Desktop Layout - Sidebar always visible
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Row(
          children: [
            Sidebar(
              activeMenuItem: _getActiveMenuItem(),
              userName: userName,
              userRole: userRole,
            ),
            Expanded(
              child: Column(
                children: [
                  if (showAppBar) _buildAppBar(context, isWideScreen: true),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    } else {
      // Mobile/Tablet Layout - Drawer
      final scaffoldKey = GlobalKey<ScaffoldState>();
      return Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF1F5F9),
        drawer: AppDrawer(
          currentPage: _convertToDrawerPage(),
          userName: userName,
          userRole: userRole,
          onProfileReload: onProfileReload,
        ),
        appBar: showAppBar
            ? AppBar(
                title: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                leadingWidth: 100,
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => scaffoldKey.currentState?.openDrawer(),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 0),
                      child: SvgPicture.asset(
                        'assets/images/log.svg',
                        width: 32,
                        height: 32,
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.white,
                elevation: 0,
                actions: actions,
              )
            : null,
        body: child,
        floatingActionButton: floatingActionButton,
      );
    }
  }

  Widget _buildAppBar(BuildContext context, {required bool isWideScreen}) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const Spacer(),
          if (actions != null) ...actions!,
        ],
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
      default:
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
      default:
        return AppDrawerPage.other;
    }
  }
}
