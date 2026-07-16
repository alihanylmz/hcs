import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/admin_panel_page.dart';
import '../screens/cariler_page.dart';
import '../screens/home_page.dart';
import '../screens/profile_settings_page.dart';
import '../screens/quotes_page.dart';
import 'bootstrap.dart';
import '../services/app_update_coordinator.dart';

/// Ana [NavigationRail]: Stok, Teklifler, Cariler, Profil, Yönetim.
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
      if (!_isManager && _index > 3) _index = 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              setState(() => _index = i);
              if (i == 1 || i == 2 || i == 3) {
                _refreshRole();
              }
            },
            labelType: NavigationRailLabelType.all,
            leading: Column(
              children: [
                const SizedBox(height: 8),
                if (widget.onSignOut != null)
                  IconButton(
                    tooltip: 'Cikis',
                    onPressed: widget.onSignOut,
                    icon: const Icon(Icons.logout_rounded),
                  ),
              ],
            ),
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2_rounded),
                label: Text('Stok'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.request_quote_outlined),
                selectedIcon: Icon(Icons.request_quote_rounded),
                label: Text('Teklifler'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.business_outlined),
                selectedIcon: Icon(Icons.business_rounded),
                label: Text('Cariler'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: Text('Profil'),
              ),
              if (_isManager)
                const NavigationRailDestination(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  selectedIcon: Icon(Icons.admin_panel_settings_rounded),
                  label: Text('Yönetim'),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _pageForIndex(_index)),
        ],
      ),
    );
  }

  Widget _pageForIndex(int i) {
    switch (i) {
      case 0:
        return HomePage(
          productRepository: widget.bootstrap.productRepository,
          marketRateService: widget.bootstrap.marketRateService,
          priceAdjustmentRuleRepository:
              widget.bootstrap.priceAdjustmentRuleRepository,
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
          isManager: _isManager,
        );
      case 2:
        return CarilerPage(
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
        return ProfileSettingsPage(
          repository: widget.bootstrap.userProfileRepository,
          themePreferenceService: widget.bootstrap.themePreferenceService,
        );
      case 4:
        if (_isManager) {
          return AdminPanelPage(
            userProfileRepository: widget.bootstrap.userProfileRepository,
            adminRepository: widget.bootstrap.adminRepository,
            ownCompanyRepository: widget.bootstrap.ownCompanyRepository,
            priceAdjustmentRuleRepository:
                widget.bootstrap.priceAdjustmentRuleRepository,
          );
        }
        return ProfileSettingsPage(
          repository: widget.bootstrap.userProfileRepository,
          themePreferenceService: widget.bootstrap.themePreferenceService,
        );
      default:
        return ProfileSettingsPage(
          repository: widget.bootstrap.userProfileRepository,
          themePreferenceService: widget.bootstrap.themePreferenceService,
        );
    }
  }
}
