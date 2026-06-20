import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../features/admin/application/admin_access_controller.dart';
import '../models/user_profile.dart';
import '../services/activity_log_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/access_denied_view.dart';
import '../widgets/sidebar/app_layout.dart';

enum _ActivityFilter { all, auto, manual, work, signature }

class ActivityLogsPage extends StatefulWidget {
  const ActivityLogsPage({super.key});

  @override
  State<ActivityLogsPage> createState() => _ActivityLogsPageState();
}

class _ActivityLogsPageState extends State<ActivityLogsPage> {
  final _accessController = AdminAccessController();
  final _logService = ActivityLogService();
  final _userService = UserService();

  UserProfile? _currentUser;
  List<UserProfile> _users = const [];
  List<Map<String, dynamic>> _logs = const [];
  String? _selectedUserId;
  _ActivityFilter _filter = _ActivityFilter.all;
  bool _loading = true;
  bool _hasAccess = false;

  List<Map<String, dynamic>> get _visibleLogs {
    return _logs
        .where((log) {
          final source = '${log['source'] ?? ''}'.toLowerCase();
          final key = '${log['action_key'] ?? ''}'.toLowerCase();
          final action = '${log['action'] ?? ''}'.toLowerCase();
          return switch (_filter) {
            _ActivityFilter.all => true,
            _ActivityFilter.auto => source != 'manual',
            _ActivityFilter.manual => source == 'manual',
            _ActivityFilter.work =>
              key.contains('ticket') ||
                  action.contains('iş') ||
                  action.contains('kart'),
            _ActivityFilter.signature =>
              key.contains('signature') || action.contains('imza'),
          };
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final access = await _accessController.load();
      if (!access.hasAccess) {
        if (!mounted) return;
        setState(() {
          _currentUser = access.profile;
          _hasAccess = false;
          _loading = false;
        });
        return;
      }

      final users = await _userService.getAllUsers();
      final logs = await _logService.fetchLogs(userId: _selectedUserId);
      if (!mounted) return;
      setState(() {
        _currentUser = access.profile;
        _hasAccess = true;
        _users = users;
        _logs = logs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hareketler yüklenemedi: $error'),
          backgroundColor: AppColors.corporateRed,
        ),
      );
    }
  }

  Future<void> _addManualNote() async {
    final result = await showDialog<_ManualLogNote>(
      context: context,
      builder: (_) => const _ManualLogNoteDialog(),
    );
    if (result == null || result.note.trim().isEmpty) return;
    await _logService.addManualNote(
      note: result.note,
      workCode: result.workCode,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: AppPage.dashboard,
      userName: _currentUser?.displayName,
      userRole: _currentUser?.role,
      title: 'Hareket Merkezi',
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child:
          !_loading && !_hasAccess
              ? const AccessDeniedView(
                message:
                    'Hareket merkezini yalnızca admin ve manager görebilir.',
              )
              : _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _load,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1040;
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        _buildHero(),
                        const SizedBox(height: 18),
                        _buildMetrics(),
                        const SizedBox(height: 18),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 360, child: _buildControlRail()),
                              const SizedBox(width: 18),
                              Expanded(child: _buildTimeline()),
                            ],
                          )
                        else ...[
                          _buildControlRail(),
                          const SizedBox(height: 18),
                          _buildTimeline(),
                        ],
                      ],
                    );
                  },
                ),
              ),
    );
  }

  Widget _buildHero() {
    UserProfile? selectedUser;
    for (final user in _users) {
      if (user.id == _selectedUserId) {
        selectedUser = user;
        break;
      }
    }
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(
        color: AppColors.corporateNavy,
        borderColor: Colors.transparent,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedUser == null
                      ? 'Ekip hareketleri'
                      : '${selectedUser.displayName} hareketleri',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'İş akışı, notlar, imzalar ve günlük aksiyonlar tek ekranda toplanır.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _addManualNote,
            icon: const Icon(Icons.add_comment_rounded),
            label: const Text('Not Ekle'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetrics() {
    final visible = _visibleLogs;
    final manual = visible.where((log) => log['source'] == 'manual').length;
    final work =
        visible.where((log) {
          final key = '${log['action_key'] ?? ''}'.toLowerCase();
          final action = '${log['action'] ?? ''}'.toLowerCase();
          return key.contains('ticket') || action.contains('iş');
        }).length;
    final signatures =
        visible.where((log) {
          final key = '${log['action_key'] ?? ''}'.toLowerCase();
          final action = '${log['action'] ?? ''}'.toLowerCase();
          return key.contains('signature') || action.contains('imza');
        }).length;

    final cards = [
      _MetricCard(
        icon: Icons.timeline_rounded,
        label: 'Görünen hareket',
        value: '${visible.length}',
        color: AppColors.corporateBlue,
      ),
      _MetricCard(
        icon: Icons.assignment_turned_in_rounded,
        label: 'İş aksiyonu',
        value: '$work',
        color: AppColors.statusDone,
      ),
      _MetricCard(
        icon: Icons.edit_note_rounded,
        label: 'Manuel not',
        value: '$manual',
        color: AppColors.corporateYellow,
      ),
      _MetricCard(
        icon: Icons.draw_rounded,
        label: 'İmza',
        value: '$signatures',
        color: AppColors.statusProgress,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        return compact
            ? Column(children: cards)
            : Row(
              children: cards.map((card) => Expanded(child: card)).toList(),
            );
      },
    );
  }

  Widget _buildControlRail() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PanelTitle(
                icon: Icons.tune_rounded,
                title: 'Görünüm',
                subtitle: 'Kullanıcı ve işlem türüne göre süz.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedUserId ?? '',
                decoration: const InputDecoration(labelText: 'Kullanıcı'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Tüm kullanıcılar'),
                  ),
                  for (final user in _users)
                    DropdownMenuItem(
                      value: user.id,
                      child: Text(user.displayName),
                    ),
                ],
                onChanged: (value) async {
                  setState(() {
                    _selectedUserId =
                        value == null || value.isEmpty ? null : value;
                  });
                  await _load();
                },
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChipButton(
                    label: 'Tümü',
                    selected: _filter == _ActivityFilter.all,
                    onTap: () => setState(() => _filter = _ActivityFilter.all),
                  ),
                  _FilterChipButton(
                    label: 'Otomatik',
                    selected: _filter == _ActivityFilter.auto,
                    onTap: () => setState(() => _filter = _ActivityFilter.auto),
                  ),
                  _FilterChipButton(
                    label: 'Manuel',
                    selected: _filter == _ActivityFilter.manual,
                    onTap:
                        () => setState(() => _filter = _ActivityFilter.manual),
                  ),
                  _FilterChipButton(
                    label: 'İşler',
                    selected: _filter == _ActivityFilter.work,
                    onTap: () => setState(() => _filter = _ActivityFilter.work),
                  ),
                  _FilterChipButton(
                    label: 'İmzalar',
                    selected: _filter == _ActivityFilter.signature,
                    onTap:
                        () =>
                            setState(() => _filter = _ActivityFilter.signature),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildPeoplePanel(),
      ],
    );
  }

  Widget _buildPeoplePanel() {
    final counts = <String, int>{};
    for (final log in _logs) {
      final actorId = '${log['actor_id'] ?? ''}'.trim();
      final actorName = '${log['actor_name'] ?? ''}'.trim();
      final key = actorId.isNotEmpty ? actorId : actorName;
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    final entries =
        counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            icon: Icons.groups_rounded,
            title: 'Ekip görünümü',
            subtitle: 'Son kayıtlarda en aktif kişiler.',
          ),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            const Text(
              'Henüz kullanıcı hareketi yok.',
              style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            for (final entry in entries.take(6))
              _PersonActivityRow(
                name: _actorName(entry.key),
                count: entry.value,
                selected: entry.key == _selectedUserId,
                onTap: () async {
                  setState(() {
                    _selectedUserId =
                        entry.key == _selectedUserId ? null : entry.key;
                  });
                  await _load();
                },
              ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final visible = _visibleLogs;
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const Expanded(
                  child: _PanelTitle(
                    icon: Icons.route_rounded,
                    title: 'Günlük akış',
                    subtitle: 'En yeni hareketler yukarıda gösterilir.',
                  ),
                ),
                Text(
                  '${visible.length} kayıt',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(44),
              child: Center(
                child: Text(
                  'Bu filtreye uygun hareket bulunmuyor.',
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              itemCount: visible.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return _ActivityTimelineTile(log: visible[index]);
              },
            ),
        ],
      ),
    );
  }

  String _actorName(String key) {
    for (final user in _users) {
      if (user.id == key) return user.displayName;
    }
    for (final log in _logs) {
      if ('${log['actor_name'] ?? ''}'.trim() == key) return key;
      if ('${log['actor_id'] ?? ''}'.trim() == key) {
        final name = '${log['actor_name'] ?? ''}'.trim();
        if (name.isNotEmpty) return name;
      }
    }
    return key.length > 8 ? 'Kullanıcı ${key.substring(0, 8)}' : key;
  }

  BoxDecoration _panelDecoration({Color? color, Color? borderColor}) {
    return BoxDecoration(
      color: color ?? Colors.white.withValues(alpha: 0.94),
      border: Border.all(color: borderColor ?? AppColors.borderSubtle),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}

class _ActivityTimelineTile extends StatelessWidget {
  const _ActivityTimelineTile({required this.log});

  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final actor = '${log['actor_name'] ?? ''}'.trim();
    final action = '${log['action'] ?? ''}'.trim();
    final workCode = '${log['work_code'] ?? ''}'.trim();
    final note = '${log['note'] ?? ''}'.trim();
    final source = '${log['source'] ?? ''}'.trim();
    final style = _styleFor(log);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(style.icon, color: style.color),
              ),
              const SizedBox(height: 6),
              Container(
                width: 2,
                height: note.isEmpty ? 20 : 38,
                color: AppColors.borderSubtle,
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      actor.isEmpty ? 'Sistem' : actor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      action.isEmpty ? 'işlem yaptı' : action,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (workCode.isNotEmpty) _ChipText(workCode),
                    if (source == 'manual') const _ChipText('Manuel'),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      note,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _formatDate(log['created_at']),
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static _ActivityStyle _styleFor(Map<String, dynamic> log) {
    final source = '${log['source'] ?? ''}'.toLowerCase();
    final key = '${log['action_key'] ?? ''}'.toLowerCase();
    final action = '${log['action'] ?? ''}'.toLowerCase();
    if (source == 'manual') {
      return const _ActivityStyle(
        Icons.edit_note_rounded,
        AppColors.corporateYellow,
      );
    }
    if (key.contains('signature') || action.contains('imza')) {
      return const _ActivityStyle(Icons.draw_rounded, AppColors.statusProgress);
    }
    if (key.contains('completed') || action.contains('tamam')) {
      return const _ActivityStyle(Icons.task_alt_rounded, AppColors.statusDone);
    }
    if (key.contains('file') || key.contains('photo')) {
      return const _ActivityStyle(Icons.attach_file_rounded, Color(0xFF7C3AED));
    }
    return const _ActivityStyle(Icons.bolt_rounded, AppColors.corporateBlue);
  }

  static String _formatDate(dynamic raw) {
    final dt = raw is String ? DateTime.tryParse(raw) : null;
    if (dt == null) return '';
    return DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(dt.toLocal());
  }
}

class _ActivityStyle {
  const _ActivityStyle(this.icon, this.color);

  final IconData icon;
  final Color color;
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surfaceAccent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.corporateBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonActivityRow extends StatelessWidget {
  const _PersonActivityRow({
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceAccent : AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.corporateBlue : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.corporateNavy,
                child: Text(
                  name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.corporateBlue.withValues(alpha: 0.14),
      labelStyle: TextStyle(
        color: selected ? AppColors.corporateBlue : AppColors.textLight,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? AppColors.corporateBlue : AppColors.borderSubtle,
        ),
      ),
    );
  }
}

class _ChipText extends StatelessWidget {
  const _ChipText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAccent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.corporateNavy,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      margin: const EdgeInsets.only(right: 12, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualLogNote {
  const _ManualLogNote({required this.note, required this.workCode});

  final String note;
  final String workCode;
}

class _ManualLogNoteDialog extends StatefulWidget {
  const _ManualLogNoteDialog();

  @override
  State<_ManualLogNoteDialog> createState() => _ManualLogNoteDialogState();
}

class _ManualLogNoteDialogState extends State<_ManualLogNoteDialog> {
  final _note = TextEditingController();
  final _workCode = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    _workCode.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _note.text.trim();
    if (note.isEmpty) return;
    Navigator.of(
      context,
    ).pop(_ManualLogNote(note: note, workCode: _workCode.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manuel Not'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _note,
              autofocus: true,
              maxLength: 240,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Kısa not'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _workCode,
              decoration: const InputDecoration(
                labelText: 'İş kodu (opsiyonel)',
                hintText: 'HCS-2026-0015',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Kaydet'),
        ),
      ],
    );
  }
}
