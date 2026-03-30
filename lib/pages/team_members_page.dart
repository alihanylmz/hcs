import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/team.dart';
import '../models/team_member.dart';
import '../models/user_profile.dart';
import '../services/team_service.dart';
import '../theme/app_colors.dart';

class TeamMembersPage extends StatefulWidget {
  const TeamMembersPage({
    super.key,
    required this.teamId,
    this.canManage = false,
  });

  final String teamId;
  final bool canManage;

  @override
  State<TeamMembersPage> createState() => _TeamMembersPageState();
}

class _TeamMembersPageState extends State<TeamMembersPage> {
  final TeamService _teamService = TeamService();

  bool _isLoading = true;
  List<TeamMember> _members = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final members = await _teamService.getTeamMembers(widget.teamId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Uyeler yuklenemedi: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _showInviteDialog() async {
    final selectedUser = await showDialog<UserProfile>(
      context: context,
      builder:
          (ctx) => _UserPickerDialog(
            teamId: widget.teamId,
            teamService: _teamService,
            existingUserIds: _members.map((member) => member.userId).toSet(),
          ),
    );
    if (selectedUser == null) return;
    await _inviteUser(selectedUser);
  }

  Future<void> _inviteUser(UserProfile user) async {
    try {
      await _teamService.addMemberByUserId(widget.teamId, user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.displayName} takima eklendi.')),
      );
      await _loadMembers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Uye eklenemedi: $error')));
    }
  }

  Future<void> _removeMember(TeamMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Uyeyi cikar'),
            content: Text('${member.displayName} takimdan cikarilsin mi?'),
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
                child: const Text('Cikar'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await _teamService.removeMember(widget.teamId, member.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uye takimdan cikarildi.')));
      await _loadMembers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Uye cikarilamadi: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

    return RefreshIndicator(
      onRefresh: _loadMembers,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildHeader(theme),
          const SizedBox(height: 16),
          if (_members.isEmpty)
            _buildEmptyState(theme)
          else
            ..._members.map(
              (member) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMemberCard(theme, member),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 12,
        spacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Takim Uyeleri',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Rol dagilimi, katilim tarihi ve ekip yapisini buradan yonet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildHeaderChip(
                theme,
                icon: Icons.group_outlined,
                label: '${_members.length} uye',
                color: AppColors.corporateBlue,
              ),
              if (widget.canManage)
                FilledButton.icon(
                  onPressed: _showInviteDialog,
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Uye ekle'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.group_off_outlined,
            size: 40,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.54),
          ),
          const SizedBox(height: 10),
          Text(
            'Bu takimda henuz uye yok.',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(ThemeData theme, TeamMember member) {
    final roleColor = _getRoleColor(member.role);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: roleColor.withValues(alpha: 0.12),
            child: Text(
              _initialFor(member.displayName),
              style: TextStyle(color: roleColor, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      member.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    _buildRoleChip(theme, member.role),
                  ],
                ),
                const SizedBox(height: 6),
                if ((member.email ?? '').trim().isNotEmpty)
                  Text(
                    member.email!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.68,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Katildi: ${DateFormat('dd.MM.yyyy').format(member.joinedAt)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (widget.canManage && member.role != TeamRole.owner)
            IconButton(
              tooltip: 'Uyeyi cikar',
              onPressed: () => _removeMember(member),
              icon: const Icon(
                Icons.person_remove_outlined,
                color: AppColors.corporateRed,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(ThemeData theme, TeamRole role) {
    final color = _getRoleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        role.label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Color _getRoleColor(TeamRole role) {
    switch (role) {
      case TeamRole.owner:
        return AppColors.corporateYellow;
      case TeamRole.admin:
        return AppColors.corporateBlue;
      case TeamRole.member:
        return AppColors.statusDone;
    }
  }

  String _initialFor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }
}

class _UserPickerDialog extends StatefulWidget {
  const _UserPickerDialog({
    required this.teamId,
    required this.teamService,
    required this.existingUserIds,
  });

  final String teamId;
  final TeamService teamService;
  final Set<String> existingUserIds;

  @override
  State<_UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends State<_UserPickerDialog> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<UserProfile> _users = [];
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await widget.teamService.listInvitableUsers(widget.teamId);
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Kullanicilar yuklenemedi: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredUsers =
        _users.where((user) {
          if (_query.isEmpty) return true;
          return user.displayName.toLowerCase().contains(_query) ||
              (user.email ?? '').toLowerCase().contains(_query);
        }).toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kullanicidan uye ekle',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Aktif kullanicilar burada listelenir. Onay bekleyen hesaplar bu listede yer almaz.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.68,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Isim veya e-posta ile ara',
                  suffixIcon:
                      _query.isEmpty
                          ? null
                          : IconButton(
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.clear),
                          ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildBody(theme, filteredUsers)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kapat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, List<UserProfile> filteredUsers) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadUsers,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      );
    }

    if (filteredUsers.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty
              ? 'Gosterilecek kullanici bulunamadi.'
              : 'Aramana uygun kullanici bulunamadi.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildInfoChip(
              theme,
              label: '${_users.length} kayitli kullanici',
              color: AppColors.corporateBlue,
            ),
            _buildInfoChip(
              theme,
              label: '${widget.existingUserIds.length} kisi zaten takimda',
              color: AppColors.corporateYellow,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: filteredUsers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              final isExisting = widget.existingUserIds.contains(user.id);
              final roleColor = _roleColor(user.role);
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: roleColor.withValues(alpha: 0.12),
                      child: Text(
                        _initialFor(user.displayName),
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.w800,
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
                                user.displayName,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              _buildStatusBadge(
                                theme,
                                label: _roleLabel(user.role),
                                color: roleColor,
                              ),
                              if (isExisting)
                                _buildStatusBadge(
                                  theme,
                                  label: 'Ekli',
                                  color: AppColors.statusDone,
                                ),
                            ],
                          ),
                          if ((user.email ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              user.email!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.68,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isExisting)
                      OutlinedButton(
                        onPressed: null,
                        child: const Text('Takimda'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () => Navigator.pop(context, user),
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Ekle'),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(
    ThemeData theme, {
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(
    ThemeData theme, {
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case UserRole.admin:
        return AppColors.corporateRed;
      case UserRole.manager:
        return AppColors.corporateBlue;
      case UserRole.supervisor:
        return AppColors.corporateNavy;
      case UserRole.engineer:
        return Colors.indigo;
      case UserRole.partnerUser:
        return Colors.purple;
      case UserRole.user:
        return Colors.blueGrey;
      case UserRole.pending:
        return AppColors.corporateYellow;
      case UserRole.technician:
      default:
        return AppColors.statusDone;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Yonetici';
      case UserRole.supervisor:
        return 'Supervizor';
      case UserRole.engineer:
        return 'Muhendis';
      case UserRole.partnerUser:
        return 'Partner';
      case UserRole.user:
        return 'Kullanici';
      case UserRole.pending:
        return 'Onay bekliyor';
      case UserRole.technician:
      default:
        return 'Teknisyen';
    }
  }

  String _initialFor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }
}
