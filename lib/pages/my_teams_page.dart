import 'package:flutter/material.dart';

import '../models/team.dart';
import '../models/team_overview.dart';
import '../models/user_profile.dart';
import '../services/team_overview_service.dart';
import '../services/team_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/team_visuals.dart';
import '../widgets/sidebar/app_layout.dart';
import 'team_home_page.dart';

class MyTeamsPage extends StatefulWidget {
  const MyTeamsPage({super.key});

  @override
  State<MyTeamsPage> createState() => _MyTeamsPageState();
}

class _MyTeamsPageState extends State<MyTeamsPage> {
  final TeamService _teamService = TeamService();
  final TeamOverviewService _overviewService = TeamOverviewService();
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();

  List<TeamListSummary> _teams = [];
  bool _isLoading = false;
  String? _error;
  UserProfile? _currentUser;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _userService.getCurrentUserProfile();
      final teams = await _overviewService.listTeamSummaries();

      if (!mounted) return;
      setState(() {
        _currentUser = profile;
        _teams = teams;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Takim listesi yuklenemedi: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _showCreateTeamDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var selectedEmoji = Team.defaultEmoji;
    var selectedAccentColor = Team.defaultAccentColor;

    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: const Text('Yeni Takim'),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCreateTeamPreview(
                              theme: Theme.of(ctx),
                              name: nameController.text.trim(),
                              description: descController.text.trim(),
                              emoji: selectedEmoji,
                              accentColorHex: selectedAccentColor,
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: nameController,
                              decoration: const InputDecoration(
                                labelText: 'Takim adi',
                              ),
                              onChanged: (_) => setDialogState(() {}),
                              validator:
                                  (value) =>
                                      value == null || value.trim().isEmpty
                                          ? 'Zorunlu alan'
                                          : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: descController,
                              decoration: const InputDecoration(
                                labelText: 'Aciklama',
                              ),
                              maxLines: 2,
                              onChanged: (_) => setDialogState(() {}),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Emoji sec',
                              style: Theme.of(ctx).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  Team.emojiOptions
                                      .map(
                                        (emoji) => _buildEmojiOption(
                                          theme: Theme.of(ctx),
                                          emoji: emoji,
                                          isSelected: selectedEmoji == emoji,
                                          onTap:
                                              () => setDialogState(
                                                () => selectedEmoji = emoji,
                                              ),
                                        ),
                                      )
                                      .toList(),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Renk sec',
                              style: Theme.of(ctx).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children:
                                  Team.accentColorOptions
                                      .map(
                                        (hex) => _buildColorOption(
                                          colorHex: hex,
                                          isSelected:
                                              selectedAccentColor == hex,
                                          onTap:
                                              () => setDialogState(
                                                () =>
                                                    selectedAccentColor = hex,
                                              ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Iptal'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? false) {
                          Navigator.pop(ctx, true);
                        }
                      },
                      child: Text(
                        'Olustur',
                        style: TextStyle(
                          color: Theme.of(ctx).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
          ),
    );

    if (result != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final team = await _teamService.createTeam(
        name: nameController.text.trim(),
        description:
            descController.text.trim().isEmpty
                ? null
                : descController.text.trim(),
        emoji: selectedEmoji,
        accentColor: selectedAccentColor,
      );
      if (!mounted) return;

      setState(() => _isLoading = false);
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => TeamHomePage(teamId: team.id)));
      await _loadAll();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Takim olusturulamadi: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppLayout(
      currentPage: AppPage.myTeams,
      title: 'Takimlarim',
      userName: _currentUser?.displayName,
      userRole: _currentUser?.role,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.floatingActionButtonTheme.backgroundColor,
        onPressed: _showCreateTeamDialog,
        icon: Icon(
          Icons.add,
          color: theme.floatingActionButtonTheme.foregroundColor,
        ),
        label: Text(
          'Yeni Takim',
          style: TextStyle(
            color: theme.floatingActionButtonTheme.foregroundColor,
          ),
        ),
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    if (_teams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.groups_outlined,
                size: 56,
                color: AppColors.primary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Henuz bir takimin yok.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Yeni bir takim olusturup pano, bilgi merkezi ve ekip akisina baslayabilirsin.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showCreateTeamDialog,
                icon: Icon(Icons.add, color: theme.colorScheme.onPrimary),
                label: Text(
                  'Takim Olustur',
                  style: TextStyle(color: theme.colorScheme.onPrimary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filteredTeams =
        _teams.where((item) {
          if (_searchQuery.isEmpty) return true;
          return item.team.name.toLowerCase().contains(_searchQuery) ||
              (item.team.description ?? '').toLowerCase().contains(
                _searchQuery,
              );
        }).toList();

    final totalActiveCards = _teams.fold<int>(
      0,
      (sum, item) => sum + item.activeCards,
    );
    final criticalTeams =
        _teams
            .where((item) => item.healthLevel == TeamHealthLevel.critical)
            .length;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderSummary(totalActiveCards, criticalTeams),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Takim ara',
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final useGrid = constraints.maxWidth >= 900;
              if (!useGrid) {
                return Column(
                  children:
                      filteredTeams
                          .map(
                            (team) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildTeamCard(team),
                            ),
                          )
                          .toList(),
                );
              }

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children:
                    filteredTeams
                        .map(
                          (team) => SizedBox(
                            width: (constraints.maxWidth - 14) / 2,
                            child: _buildTeamCard(team),
                          ),
                        )
                        .toList(),
              );
            },
          ),
          if (filteredTeams.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Aramana uygun takim bulunamadi.',
                  style: TextStyle(
                    color:
                        isDark
                            ? AppColors.textOnDarkMuted
                            : AppColors.textLight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderSummary(int totalActiveCards, int criticalTeams) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
        ),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 18,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Takimlarim',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Hangi takim aktif, hangisi dikkat istiyor tek bakista gor.',
                style: TextStyle(
                  color:
                      isDark ? AppColors.textOnDarkMuted : AppColors.textLight,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildSummaryPill(
                icon: Icons.groups_outlined,
                value: '${_teams.length}',
                label: 'Takim',
                color: AppColors.corporateNavy,
              ),
              _buildSummaryPill(
                icon: Icons.pending_actions_outlined,
                value: '$totalActiveCards',
                label: 'Aktif kart',
                color: const Color(0xFFF59E0B),
              ),
              _buildSummaryPill(
                icon: Icons.warning_amber_rounded,
                value: '$criticalTeams',
                label: 'Kritik takim',
                color: const Color(0xFFEF4444),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontWeight: FontWeight.w800, color: color),
              ),
              Text(
                label,
                style: TextStyle(
                  color:
                      isDark ? AppColors.textOnDarkMuted : AppColors.textLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(TeamListSummary summary) {
    final healthColor = _healthColor(summary.healthLevel);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = TeamVisuals.colorFromHex(summary.team.accentColor);
    final canDelete = summary.role == TeamRole.owner;
    return InkWell(
      onTap: () => _openTeam(summary.team.id, 0),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accentColor.withValues(alpha: 0.24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(
                      alpha: isDark ? 0.24 : 0.14,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      summary.team.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            summary.team.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.team.description == null ||
                                summary.team.description!.trim().isEmpty
                            ? 'Aciklama eklenmemis'
                            : summary.team.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              isDark
                                  ? AppColors.textOnDarkMuted
                                  : AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canDelete)
                  PopupMenuButton<String>(
                    tooltip: 'Takim islemleri',
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteTeam(summary);
                      }
                    },
                    itemBuilder:
                        (context) => const [
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.corporateRed,
                                ),
                                SizedBox(width: 10),
                                Text('Takimi sil'),
                              ],
                            ),
                          ),
                        ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildInfoChip(summary.role.label, accentColor),
                _buildInfoChip(summary.healthLevel.label, healthColor),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricItem(
                    label: 'Uye',
                    value: '${summary.memberCount}',
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    label: 'Aktif',
                    value: '${summary.activeCards}',
                  ),
                ),
                Expanded(
                  child: _buildMetricItem(
                    label: 'Tamamlanan',
                    value: '${summary.completedCards}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? AppColors.surfaceDarkMuted.withValues(alpha: 0.72)
                        : AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color:
                        isDark
                            ? AppColors.textOnDarkMuted
                            : AppColors.textLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary.lastActivityAt == null
                          ? 'Henuz hareket yok'
                          : 'Son hareket: ${_formatDate(summary.lastActivityAt!)}',
                      style: TextStyle(
                        color:
                            isDark
                                ? AppColors.textOnDarkMuted
                                : AppColors.textLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openTeam(summary.team.id, 0),
                  icon: const Icon(Icons.view_kanban_outlined),
                  label: const Text('Pano'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openTeam(summary.team.id, 1),
                  icon: const Icon(Icons.forum_outlined),
                  label: const Text('Konusmalar'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openTeam(summary.team.id, 2),
                  icon: const Icon(Icons.library_books_outlined),
                  label: const Text('Bilgi'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openTeam(summary.team.id, 5),
                  icon: const Icon(Icons.space_dashboard_outlined),
                  label: const Text('Genel Bakis'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({required String label, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isDark ? AppColors.textOnDarkMuted : AppColors.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Color _healthColor(TeamHealthLevel level) {
    switch (level) {
      case TeamHealthLevel.stable:
        return const Color(0xFF10B981);
      case TeamHealthLevel.attention:
        return const Color(0xFFF59E0B);
      case TeamHealthLevel.critical:
        return const Color(0xFFEF4444);
    }
  }

  Future<void> _openTeam(String teamId, int tabIndex) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeamHomePage(teamId: teamId, initialTabIndex: tabIndex),
      ),
    );
    if (!mounted) return;
    await _loadAll();
  }

  String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }

  Future<void> _deleteTeam(TeamListSummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Takimi sil'),
            content: Text(
              '"${summary.team.name}" takimi silinsin mi?\n\n'
              'Bu islem panolari, kartlari, konusmalari ve takim verilerini kaldirir.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgec'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.corporateRed,
                ),
                child: const Text('Sil'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _teamService.deleteTeam(summary.team.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${summary.team.name} silindi.')),
      );
      await _loadAll();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Takim silinemedi: $error')));
    }
  }

  Widget _buildCreateTeamPreview({
    required ThemeData theme,
    required String name,
    required String description,
    required String emoji,
    required String accentColorHex,
  }) {
    final accentColor = TeamVisuals.colorFromHex(accentColorHex);
    final previewName = name.isEmpty ? 'Takim adi' : name;
    final previewDescription =
        description.isEmpty
            ? 'Kart gorunumu burada nasil duracagini gosterir.'
            : description;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        previewName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  previewDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiOption({
    required ThemeData theme,
    required String emoji,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final accentColor =
        isSelected ? theme.colorScheme.primary : theme.colorScheme.outline;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: isSelected ? 0.14 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accentColor.withValues(alpha: isSelected ? 0.42 : 0.18),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
      ),
    );
  }

  Widget _buildColorOption({
    required String colorHex,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final color = TeamVisuals.colorFromHex(colorHex);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          border: Border.all(
            color: color.withValues(alpha: isSelected ? 0.95 : 0.28),
            width: isSelected ? 2 : 1,
          ),
          shape: BoxShape.circle,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child:
              isSelected
                  ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                  : null,
        ),
      ),
    );
  }
}
