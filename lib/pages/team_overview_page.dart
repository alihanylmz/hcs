import 'package:flutter/material.dart';

import '../models/team_overview.dart';
import '../services/team_overview_service.dart';
import '../theme/app_colors.dart';
import '../theme/team_visuals.dart';

class TeamOverviewPage extends StatefulWidget {
  final String teamId;
  final VoidCallback onOpenConversations;
  final VoidCallback onOpenBoard;
  final VoidCallback onOpenKnowledge;
  final VoidCallback onOpenMembers;
  final VoidCallback onOpenAnalytics;

  const TeamOverviewPage({
    super.key,
    required this.teamId,
    required this.onOpenConversations,
    required this.onOpenBoard,
    required this.onOpenKnowledge,
    required this.onOpenMembers,
    required this.onOpenAnalytics,
  });

  @override
  State<TeamOverviewPage> createState() => _TeamOverviewPageState();
}

class _TeamOverviewPageState extends State<TeamOverviewPage> {
  final TeamOverviewService _overviewService = TeamOverviewService();

  bool _isLoading = true;
  String? _error;
  TeamOverviewSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final snapshot = await _overviewService.getTeamOverview(widget.teamId);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Takim ozeti yuklenemedi: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    final snapshot = _snapshot;
    if (snapshot == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 1100;

    return RefreshIndicator(
      onRefresh: _loadOverview,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeroCard(theme, snapshot),
          const SizedBox(height: 18),
          _buildQuickActions(),
          const SizedBox(height: 18),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildMetricsGrid(snapshot)),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: _buildRecentActivity(theme, snapshot)),
              ],
            )
          else ...[
            _buildMetricsGrid(snapshot),
            const SizedBox(height: 18),
            _buildRecentActivity(theme, snapshot),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroCard(ThemeData theme, TeamOverviewSnapshot snapshot) {
    final accentColor = TeamVisuals.colorFromHex(snapshot.team.accentColor);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    snapshot.team.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              Text(
                snapshot.team.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              _buildInfoChip(
                label: snapshot.role.label,
                backgroundColor: accentColor.withValues(alpha: 0.12),
                textColor: accentColor,
              ),
              _buildInfoChip(
                label: _focusLabel(snapshot),
                backgroundColor: _focusColor(snapshot).withValues(alpha: 0.1),
                textColor: _focusColor(snapshot),
              ),
            ],
          ),
          if (snapshot.team.description != null &&
              snapshot.team.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              snapshot.team.description!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildMetaItem(
                Icons.group_outlined,
                '${snapshot.memberCount} uye',
              ),
              _buildMetaItem(
                Icons.view_kanban_outlined,
                '${snapshot.boardCount} pano',
              ),
              _buildMetaItem(
                Icons.assignment_outlined,
                '${snapshot.totalCards} toplam kart',
              ),
              _buildMetaItem(
                Icons.check_circle_outline_rounded,
                '%${(snapshot.completionRate * 100).toStringAsFixed(0)} tamamlanma',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildActionCard(
          icon: Icons.forum_outlined,
          title: 'Konusmalar',
          subtitle: 'Takim sohbetini ve mentionlari ac',
          onTap: widget.onOpenConversations,
        ),
        _buildActionCard(
          icon: Icons.view_kanban_outlined,
          title: 'Panoyu ac',
          subtitle: 'Kartlari ve akisi yonet',
          onTap: widget.onOpenBoard,
        ),
        _buildActionCard(
          icon: Icons.library_books_outlined,
          title: 'Bilgi merkezi',
          subtitle: 'Rehber ve SOP sayfalarini ac',
          onTap: widget.onOpenKnowledge,
        ),
        _buildActionCard(
          icon: Icons.group_outlined,
          title: 'Uyeler',
          subtitle: 'Takim rollerini ve davetleri gor',
          onTap: widget.onOpenMembers,
        ),
        _buildActionCard(
          icon: Icons.analytics_outlined,
          title: 'Analiz',
          subtitle: 'Performans ozetini incele',
          onTap: widget.onOpenAnalytics,
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 230,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.corporateNavy.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.corporateNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.corporateNavy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(TeamOverviewSnapshot snapshot) {
    final cards = [
      _MetricCardData(
        title: 'Aktif kartlar',
        value: '${snapshot.activeCards}',
        icon: Icons.pending_actions_outlined,
        color: const Color(0xFFF59E0B),
      ),
      _MetricCardData(
        title: 'Tamamlanan',
        value: '${snapshot.completedCards}',
        icon: Icons.task_alt_outlined,
        color: const Color(0xFF10B981),
      ),
      _MetricCardData(
        title: 'Uye sayisi',
        value: '${snapshot.memberCount}',
        icon: Icons.people_outline_rounded,
        color: AppColors.corporateNavy,
      ),
      _MetricCardData(
        title: 'Toplam kart',
        value: '${snapshot.totalCards}',
        icon: Icons.layers_outlined,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.55,
      ),
      itemBuilder: (context, index) {
        final item = cards[index];
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: item.color.withValues(alpha: 0.14)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, color: item.color),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: item.color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentActivity(ThemeData theme, TeamOverviewSnapshot snapshot) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.corporateNavy.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Son hareketler',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Takim icinde en son nelerin degistigini hizlica gor.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 14),
          if (snapshot.recentActivities.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.corporateNavy.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text('Henuz takim hareketi bulunmuyor.'),
            )
          else
            Column(
              children:
                  snapshot.recentActivities
                      .map(
                        (activity) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.corporateNavy.withValues(
                                alpha: 0.08,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.bolt_outlined,
                              color: AppColors.corporateNavy,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            activity.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${activity.description} - ${_formatDate(activity.createdAt)}',
                          ),
                        ),
                      )
                      .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildInfoChip({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }

  String _focusLabel(TeamOverviewSnapshot snapshot) {
    if (snapshot.activeCards >= 8) {
      return 'Yuksek is yuku';
    }
    if (snapshot.activeCards >= 3) {
      return 'Takip gerekli';
    }
    return 'Ritim iyi';
  }

  Color _focusColor(TeamOverviewSnapshot snapshot) {
    if (snapshot.activeCards >= 8) {
      return const Color(0xFFEF4444);
    }
    if (snapshot.activeCards >= 3) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF10B981);
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month - $hour:$minute';
  }
}

class _MetricCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
}
