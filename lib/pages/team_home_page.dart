import 'package:flutter/material.dart';
import '../models/team.dart';
import '../services/team_service.dart';
import '../theme/app_colors.dart';
import '../widgets/sidebar/app_layout.dart';
import 'board_page.dart';
import 'team_analytics_page.dart';
import 'team_members_page.dart';

class TeamHomePage extends StatefulWidget {
  final String teamId;

  const TeamHomePage({super.key, required this.teamId});

  @override
  State<TeamHomePage> createState() => _TeamHomePageState();
}

class _TeamHomePageState extends State<TeamHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TeamService _teamService = TeamService();
  TeamRole _userRole = TeamRole.member;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await _teamService.getCurrentUserRole(widget.teamId);
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _userRole == TeamRole.owner || _userRole == TeamRole.admin;

    return AppLayout(
      title: 'Takım Detayı', 
      currentPage: AppPage.myTeams,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.corporateNavy,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.corporateNavy,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Pano', icon: Icon(Icons.dashboard_outlined)),
                Tab(text: 'Üyeler', icon: Icon(Icons.group_outlined)),
                Tab(text: 'Analiz', icon: Icon(Icons.analytics_outlined)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                BoardPage(teamId: widget.teamId),
                TeamMembersPage(teamId: widget.teamId, canManage: canManage),
                TeamAnalyticsPage(teamId: widget.teamId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
