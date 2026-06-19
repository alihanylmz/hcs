import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/notification_item.dart';
import '../services/notification_navigation_service.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/ui.dart';

class NotificationsDropdown extends StatefulWidget {
  const NotificationsDropdown({
    super.key,
    required this.onClose,
    this.limit = 10,
    this.width = 360,
    this.maxHeight = 420,
    this.onNavigate,
  });

  final VoidCallback onClose;
  final int limit;
  final double width;
  final double maxHeight;
  final Future<void> Function(Map<String, dynamic> data)? onNavigate;

  @override
  State<NotificationsDropdown> createState() => _NotificationsDropdownState();
}

class _NotificationsDropdownState extends State<NotificationsDropdown> {
  final NotificationService _notificationService = NotificationService();
  bool _loading = true;
  String? _error;
  List<NotificationItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _notificationService.getNotifications();
      final limited = list.take(widget.limit).toList();
      if (!mounted) return;
      setState(() {
        _items = limited;
        _loading = false;
      });

      // Açılınca okunmamışları sıfırla (badge hemen düşsün)
      await _notificationService.markAllAsRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onTap(NotificationItem item) {
    final data = item.data ?? const <String, dynamic>{};
    if (data.isNotEmpty && widget.onNavigate != null) {
      widget.onClose();
      widget.onNavigate!(data);
      return;
    }

    if (data.isNotEmpty) {
      final navigator = Navigator.of(context);
      widget.onClose();
      NotificationNavigationService.openFromData(navigator, data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.width,
        minWidth: widget.width,
        maxHeight: widget.maxHeight,
      ),
      child: UiCard(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Bildirimler',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Yenile',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
            Expanded(
              child:
                  _loading
                      ? const UiLoading(message: 'Yükleniyor...')
                      : _error != null
                      ? UiErrorState(message: _error, onRetry: _load)
                      : _items.isEmpty
                      ? const UiEmptyState(
                        icon: Icons.notifications_none,
                        title: 'Bildiriminiz bulunmuyor',
                        subtitle: 'Yeni bildirimler burada görünecek.',
                      )
                      : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                        itemCount: _items.length,
                        separatorBuilder:
                            (_, __) => Divider(
                              height: 1,
                              color: theme.dividerColor.withValues(alpha: 0.12),
                            ),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _NotificationRow(
                            item: item,
                            onTap: () => _onTap(item),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRead = item.isRead;

    IconData icon = Icons.notifications;
    Color iconColor = AppColors.corporateNavy;

    final data = item.data;
    if (data != null) {
      final type = data['type'];
      switch (type) {
        case 'ticket_created':
          icon = Icons.add_task;
          iconColor = Colors.green;
          break;
        case 'ticket_status_changed':
          icon = Icons.change_circle;
          iconColor = Colors.blue;
          break;
        case 'card_created':
          icon = Icons.add_box_outlined;
          iconColor = AppColors.corporateBlue;
          break;
        case 'card_updated':
          icon = Icons.edit_note;
          iconColor = AppColors.corporateBlue;
          break;
        case 'card_status_changed':
          icon = Icons.task_alt_outlined;
          iconColor = Colors.green;
          break;
        case 'card_assigned':
          icon = Icons.assignment_ind_outlined;
          iconColor = AppColors.corporateYellow;
          break;
        case 'card_comment':
          icon = Icons.chat_bubble_outline;
          iconColor = Colors.orange;
          break;
        case 'member_invited':
          icon = Icons.group_add_outlined;
          iconColor = AppColors.corporateBlue;
          break;
        case 'team_mention':
          icon = Icons.alternate_email;
          iconColor = AppColors.corporateRed;
          break;
        case 'note_added':
        case 'partner_note_added':
          icon = Icons.comment;
          iconColor = Colors.orange;
          break;
        case 'priority_changed':
          icon = Icons.priority_high;
          iconColor = AppColors.corporateRed;
          break;
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: iconColor.withValues(alpha: 0.10),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isRead ? FontWeight.w500 : FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(item.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: theme.hintColor),
          ],
        ),
      ),
    );
  }
}
