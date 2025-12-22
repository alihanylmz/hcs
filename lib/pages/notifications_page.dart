import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification_item.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui/ui.dart';
import 'ticket_detail_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final items = await _notificationService.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = items;
        _isLoading = false;
      });
      // Sayfa açıldığında tümünü okundu olarak işaretleyelim mi? 
      // Kullanıcı deneyimi açısından, kullanıcı tıkladıkça veya "Tümünü Okundu Yap" butonu ile yapmak daha iyi olabilir.
      // Ancak genellikle bildirim ekranına girince okunmuş sayılır.
      // Şimdilik burada hepsini okundu yapalım.
      _markAllRead();
    }
  }

  Future<void> _markAllRead() async {
    await _notificationService.markAllAsRead();
  }

  void _handleNotificationTap(NotificationItem item) {
    if (item.data != null && item.data!.containsKey('ticket_id')) {
      final ticketId = item.data!['ticket_id'].toString();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TicketDetailPage(ticketId: ticketId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: UiMaxWidth(
        child: _isLoading
            ? const UiLoading(message: 'Yükleniyor...')
            : _notifications.isEmpty
                ? const UiEmptyState(
                    icon: Icons.notifications_none,
                    title: 'Bildiriminiz bulunmuyor',
                    subtitle: 'Yeni bildirimler burada görünecek.',
                  )
                : ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
                      return _NotificationTile(
                        item: item,
                        onTap: () => _handleNotificationTap(item),
                      );
                    },
                  ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRead = item.isRead;
    
    IconData icon = Icons.notifications;
    Color iconColor = AppColors.corporateNavy;

    // Tipe göre ikon belirleme
    if (item.data != null) {
      final type = item.data!['type'];
      switch (type) {
        case 'ticket_created':
          icon = Icons.add_task;
          iconColor = Colors.green;
          break;
        case 'ticket_status_changed':
          icon = Icons.change_circle;
          iconColor = Colors.blue;
          break;
        case 'note_added':
        case 'partner_note_added':
          icon = Icons.comment;
          iconColor = Colors.orange;
          break;
        case 'priority_changed':
          icon = Icons.priority_high;
          iconColor = Colors.red;
          break;
      }
    }

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.1),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(item.message),
          const SizedBox(height: 4),
          Text(
            DateFormat('dd.MM.yyyy HH:mm').format(item.createdAt),
            style: TextStyle(fontSize: 11, color: theme.disabledColor),
          ),
        ],
      ),
      tileColor: isRead ? null : theme.primaryColor.withOpacity(0.05),
    );
  }
}

