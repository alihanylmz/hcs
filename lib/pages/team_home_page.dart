import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/sidebar/app_layout.dart';
import 'board_page.dart';

class TeamHomePage extends StatefulWidget {
  final String teamId;

  const TeamHomePage({super.key, required this.teamId});

  @override
  State<TeamHomePage> createState() => _TeamHomePageState();
}

class _TeamHomePageState extends State<TeamHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: 'Takım Detayı', 
      currentPage: AppPage.myTeams,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.corporateNavy,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.corporateNavy,
              tabs: const [
                Tab(text: 'Pano'),
                Tab(text: 'Üyeler'),
                Tab(text: 'Analiz'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                BoardPage(teamId: widget.teamId),
                Center(child: Text('Üyeler - ${widget.teamId}')),
                Center(child: Text('Analiz - ${widget.teamId}')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
