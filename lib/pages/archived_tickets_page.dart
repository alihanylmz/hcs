import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_ticket_page.dart';
import 'ticket_detail_page.dart';

class ArchivedTicketsPage extends StatefulWidget {
  const ArchivedTicketsPage({super.key});

  @override
  State<ArchivedTicketsPage> createState() => _ArchivedTicketsPageState();
}

class _ArchivedTicketsPageState extends State<ArchivedTicketsPage> {
  late Future<List<Map<String, dynamic>>> _ticketsFuture;

  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String _priorityFilter = 'all'; // all, low, normal, high

  @override
  void initState() {
    super.initState();
    _ticketsFuture = _fetchArchivedTickets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchArchivedTickets() async {
    final supabase = Supabase.instance.client;

    final response = await supabase
        .from('tickets')
        .select('''
          id,
          title,
          status,
          priority,
          planned_date,
          archived_at,
          created_at,
          customers (
            id,
            name,
            address
          )
        ''')
        .eq('status', 'done')
        .order('created_at', ascending: false);

    final List data = response as List;
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> _refresh() async {
    setState(() {
      _ticketsFuture = _fetchArchivedTickets();
    });
  }

  Future<void> _deleteTicket(String ticketId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İşi Sil'),
        content: const Text('Arşivdeki bu işi kalıcı olarak silmek istiyor musun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final idValue = int.tryParse(ticketId) ?? ticketId;
    final supabase = Supabase.instance.client;
    await supabase.from('tickets').delete().eq('id', idValue);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kayıt silindi.')),
    );
    _refresh();
  }

  Future<void> _openDetail(String ticketId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketDetailPage(ticketId: ticketId),
      ),
    );
    _refresh();
  }

  Future<void> _editTicket(String ticketId) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditTicketPage(ticketId: ticketId),
      ),
    );
    if (updated == true) {
      _refresh();
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Açık';
      case 'in_progress':
        return 'Serviste';
      case 'done':
        return 'Tamamlandı';
      default:
        return status;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'low':
        return 'Düşük';
      case 'normal':
        return 'Normal';
      case 'high':
        return 'Yüksek';
      default:
        return priority;
    }
  }

  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> tickets) {
    final search = _searchText.trim().toLowerCase();

    return tickets.where((ticket) {
      final priority = (ticket['priority'] as String?) ?? '';

      final customer =
          ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final title = (ticket['title'] as String?) ?? '';
      final customerName = (customer['name'] as String?) ?? '';

      // Öncelik filtresi
      if (_priorityFilter != 'all' && priority != _priorityFilter) {
        return false;
      }

      // Arama metni (başlık + müşteri)
      if (search.isNotEmpty) {
        final combined =
            '${title.toLowerCase()} ${customerName.toLowerCase()}';
        if (!combined.contains(search)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biten İşler'),
      ),
      body: Column(
        children: [
          // Arama + filtreler
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Başlık / Müşteri ara...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _priorityFilter,
                        decoration: const InputDecoration(
                          labelText: 'Öncelik',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Tümü', overflow: TextOverflow.ellipsis),
                          ),
                          DropdownMenuItem(
                            value: 'low',
                            child: Text('Düşük', overflow: TextOverflow.ellipsis),
                          ),
                          DropdownMenuItem(
                            value: 'normal',
                            child: Text('Normal', overflow: TextOverflow.ellipsis),
                          ),
                          DropdownMenuItem(
                            value: 'high',
                            child: Text('Yüksek', overflow: TextOverflow.ellipsis),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _priorityFilter = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _ticketsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Yükleniyor...'),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Hata: ${snapshot.error}'),
                    );
                  }
                  final tickets = snapshot.data ?? [];
                  final filteredTickets = _applyFilters(tickets);

                  if (filteredTickets.isEmpty) {
                    return const Center(
                      child: Text('Filtreye uyan arşiv kaydı bulunamadı.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: filteredTickets.length,
                    itemBuilder: (context, index) {
                      final ticket = filteredTickets[index];
                      final customer =
                          ticket['customers'] as Map<String, dynamic>?;
                      final title = ticket['title'] as String? ?? '';
                      final status = ticket['status'] as String? ?? '';
                      final priority = ticket['priority'] as String? ?? '';
                      final plannedDate = ticket['planned_date'] as String?;
                      final archivedAt = ticket['archived_at'] as String?;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.archive_outlined),
                          title: Text(title),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (customer != null)
                                Text(
                                  customer['name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                              Row(
                                children: [
                                  Text('Durum: ${_statusLabel(status)}'),
                                  const SizedBox(width: 8),
                                  Text('Öncelik: ${_priorityLabel(priority)}'),
                                ],
                              ),
                              if (plannedDate != null)
                                Text('Plan Tarihi: $plannedDate'),
                              if (archivedAt != null)
                                Text('Arşive Alındı: $archivedAt'),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              final id = ticket['id'].toString();
                              switch (value) {
                                case 'detail':
                                  _openDetail(id);
                                  break;
                                case 'edit':
                                  _editTicket(id);
                                  break;
                                case 'delete':
                                  _deleteTicket(id);
                                  break;
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'detail',
                                child: Text('Detayı Aç'),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Düzenle'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Sil'),
                              ),
                            ],
                          ),
                          onTap: () => _openDetail(
                            ticket['id'].toString(),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
