import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/admin_panel_page.dart';
import '../screens/cariler_page.dart';
import '../screens/discovery_projects_page.dart';
import '../screens/home_page.dart';
import '../screens/profile_settings_page.dart';
import '../screens/quotes_page.dart';
import 'bootstrap.dart';
import '../services/app_update_coordinator.dart';

/// Ana [NavigationRail]: Stok, Teklifler, Cariler, Keşif, Profil, Yönetim.
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
      if (!_canManageSystem && _index > 4) _index = 4;
    });
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
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2_rounded),
                  label: 'Stok',
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

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: _selectDestination,
                labelType: NavigationRailLabelType.all,
                leading: Column(
                  children: [
                    const SizedBox(height: 8),
                    if (widget.onSignOut != null)
                      IconButton(
                        tooltip: 'Çıkış',
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
                    icon: Icon(Icons.account_tree_outlined),
                    selectedIcon: Icon(Icons.account_tree_rounded),
                    label: Text('Keşif'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded),
                    label: Text('Profil'),
                  ),
                  if (_canManageSystem)
                    const NavigationRailDestination(
                      icon: Icon(Icons.admin_panel_settings_outlined),
                      selectedIcon: Icon(Icons.admin_panel_settings_rounded),
                      label: Text('Yönetim'),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: page),
            ],
          ),
        );
      },
    );
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
      case 4:
        return ProfileSettingsPage(
          repository: widget.bootstrap.userProfileRepository,
          themePreferenceService: widget.bootstrap.themePreferenceService,
          ownCompanyRepository: widget.bootstrap.ownCompanyRepository,
          onSignOut: widget.onSignOut,
        );
      case 5:
        if (_canManageSystem) {
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
          ownCompanyRepository: widget.bootstrap.ownCompanyRepository,
          onSignOut: widget.onSignOut,
        );
      default:
        return ProfileSettingsPage(
          repository: widget.bootstrap.userProfileRepository,
          themePreferenceService: widget.bootstrap.themePreferenceService,
          ownCompanyRepository: widget.bootstrap.ownCompanyRepository,
          onSignOut: widget.onSignOut,
        );
    }
  }
}
