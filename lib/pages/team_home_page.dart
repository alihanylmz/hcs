import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/card.dart';
import '../models/team.dart';
import '../models/team_thread.dart';
import '../services/team_conversation_service.dart';
import '../services/team_service.dart';
import '../theme/app_colors.dart';
import '../widgets/sidebar/app_layout.dart';
import 'board_page.dart';
import 'team_analytics_page.dart';
import 'team_conversations_page.dart';
import 'team_knowledge_page.dart';
import 'team_members_page.dart';
import 'team_overview_page.dart';

class TeamHomePage extends StatefulWidget {
  final String teamId;
  final int initialTabIndex;
  final String? initialConversationThreadId;
  final String? initialConversationCardId;
  final String? initialConversationTicketId;

  const TeamHomePage({
    super.key,
    required this.teamId,
    this.initialTabIndex = 0,
    this.initialConversationThreadId,
    this.initialConversationCardId,
    this.initialConversationTicketId,
  });

  @override
  State<TeamHomePage> createState() => _TeamHomePageState();
}

class _TeamHomePageState extends State<TeamHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TeamService _teamService = TeamService();
  final TeamConversationService _conversationService =
      TeamConversationService();
  TeamRole _userRole = TeamRole.member;
  RealtimeChannel? _conversationChannel;
  TeamConversationTotals _conversationTotals = const TeamConversationTotals(
    unreadCount: 0,
    mentionCount: 0,
  );
  bool _isRefreshingConversationTotals = false;
  String? _conversationThreadId;
  String? _conversationCardId;
  String? _conversationTicketId;
  int _conversationRequestId = 0;

  @override
  void initState() {
    super.initState();
    _conversationThreadId = widget.initialConversationThreadId;
    _conversationCardId = widget.initialConversationCardId;
    _conversationTicketId = widget.initialConversationTicketId;
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 5),
    );
    _loadUserRole();
    _loadConversationTotals();
    _subscribeConversationTotals();
  }

  Future<void> _loadUserRole() async {
    final role = await _teamService.getCurrentUserRole(widget.teamId);
    if (!mounted) return;
    setState(() => _userRole = role);
  }

  void _goToTab(int index) {
    _tabController.animateTo(index);
  }

  void _openCardConversation(KanbanCard card) {
    setState(() {
      _conversationCardId = card.id;
      _conversationThreadId = null;
      _conversationTicketId = null;
      _conversationRequestId++;
    });
    _goToTab(1);
  }

  void _subscribeConversationTotals() {
    _conversationChannel = _conversationService.subscribeToTeamConversations(
      widget.teamId,
      () async {
        await _loadConversationTotals();
      },
    );
  }

  Future<void> _loadConversationTotals() async {
    if (_isRefreshingConversationTotals) return;
    _isRefreshingConversationTotals = true;
    try {
      final totals = await _conversationService.getConversationTotals(
        widget.teamId,
      );
      if (!mounted) return;
      setState(() {
        _conversationTotals = TeamConversationTotals(
          unreadCount: totals.unreadCount,
          mentionCount: totals.mentionCount,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _conversationTotals = const TeamConversationTotals(
          unreadCount: 0,
          mentionCount: 0,
        );
      });
    } finally {
      _isRefreshingConversationTotals = false;
    }
  }

  Widget _buildConversationTabLabel() {
    final badgeCount =
        _conversationTotals.mentionCount > 0
            ? _conversationTotals.mentionCount
            : _conversationTotals.unreadCount;
    final badgeColor =
        _conversationTotals.mentionCount > 0
            ? AppColors.corporateRed
            : AppColors.corporateBlue;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.forum_outlined),
        const SizedBox(width: 8),
        const Text('Konusmalar'),
        if (badgeCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$badgeCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    if (_conversationChannel != null) {
      Supabase.instance.client.removeChannel(_conversationChannel!);
    }
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canManage =
        _userRole == TeamRole.owner || _userRole == TeamRole.admin;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppLayout(
      title: 'Takim Detayi',
      currentPage: AppPage.myTeams,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: theme.colorScheme.onSurface,
              unselectedLabelColor:
                  isDark ? AppColors.textOnDarkMuted : AppColors.textLight,
              indicatorColor: theme.colorScheme.primary,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                const Tab(text: 'Pano', icon: Icon(Icons.dashboard_outlined)),
                Tab(child: _buildConversationTabLabel()),
                const Tab(
                  text: 'Bilgi Merkezi',
                  icon: Icon(Icons.library_books_outlined),
                ),
                const Tab(text: 'Uyeler', icon: Icon(Icons.group_outlined)),
                const Tab(text: 'Analiz', icon: Icon(Icons.analytics_outlined)),
                const Tab(
                  text: 'Genel Bakis',
                  icon: Icon(Icons.space_dashboard_outlined),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                BoardPage(
                  teamId: widget.teamId,
                  onOpenConversation: _openCardConversation,
                ),
                TeamConversationsPage(
                  teamId: widget.teamId,
                  canManage: canManage,
                  initialThreadId: _conversationThreadId,
                  initialCardId: _conversationCardId,
                  initialTicketId: _conversationTicketId,
                  contextRequestId: _conversationRequestId,
                  onTotalsChanged: (totals) {
                    if (!mounted) return;
                    setState(() => _conversationTotals = totals);
                  },
                ),
                TeamKnowledgePageView(
                  teamId: widget.teamId,
                  canManage: canManage,
                ),
                TeamMembersPage(teamId: widget.teamId, canManage: canManage),
                TeamAnalyticsPage(teamId: widget.teamId),
                TeamOverviewPage(
                  teamId: widget.teamId,
                  onOpenConversations: () => _goToTab(1),
                  onOpenBoard: () => _goToTab(0),
                  onOpenKnowledge: () => _goToTab(2),
                  onOpenMembers: () => _goToTab(3),
                  onOpenAnalytics: () => _goToTab(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
