import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_ticket_page.dart';
import 'ticket_detail_page.dart';
import '../services/user_service.dart';
import '../widgets/app_drawer.dart';

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
  String? _userRole;
  String? _userName;
  final _userService = UserService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _ticketsFuture = _fetchArchivedTickets();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final profile = await _userService.getCurrentUserProfile();
    if (mounted) {
      setState(() {
        _userRole = profile?.role;
        _userName = profile?.fullName;
      });
    }
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
    // Teknisyenler silme yapamaz
    if (_userRole == 'technician' || _userRole == 'pending') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teknisyenler iş silemez.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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

  // Türkçe karakter desteği için normalize fonksiyonu
  // Tüm karakterleri (büyük/küçük, Türkçe/İngilizce) normalize eder
  String _normalizeTurkish(String text) {
    if (text.isEmpty) return '';
    
    // Her karakteri tek tek işle
    StringBuffer result = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final codeUnit = char.codeUnitAt(0);
      
      // Türkçe büyük harfleri küçük harfe çevir
      switch (char) {
        case 'İ':
          result.write('i');
          break;
        case 'I':
          result.write('ı');
          break;
        case 'Ş':
          result.write('ş');
          break;
        case 'Ğ':
          result.write('ğ');
          break;
        case 'Ü':
          result.write('ü');
          break;
        case 'Ö':
          result.write('ö');
          break;
        case 'Ç':
          result.write('ç');
          break;
        default:
          // İngilizce büyük harfler (A-Z ama I hariç)
          if (codeUnit >= 65 && codeUnit <= 90 && codeUnit != 73) {
            result.write(String.fromCharCode(codeUnit + 32)); // ASCII: A=65, a=97
          } else {
            // Diğer tüm karakterleri olduğu gibi bırak (küçük harfler, rakamlar, özel karakterler)
            result.write(char);
          }
          break;
      }
    }
    
    return result.toString().trim();
  }

  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> tickets) {
    final search = _normalizeTurkish(_searchText.trim());

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

      // Arama metni (başlık + müşteri) - Türkçe karakter desteği ile
      if (search.isNotEmpty) {
        final normalizedTitle = _normalizeTurkish(title);
        final normalizedCustomerName = _normalizeTurkish(customerName);
        final combined = '$normalizedTitle $normalizedCustomerName';
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
      key: _scaffoldKey,
      drawer: AppDrawer(
        currentPage: AppDrawerPage.archived,
        userName: _userName,
        userRole: _userRole,
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
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
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.search,
                  enableSuggestions: true,
                  autocorrect: true,
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
                            itemBuilder: (context) {
                              final items = <PopupMenuItem<String>>[
                                const PopupMenuItem(
                                  value: 'detail',
                                  child: Text('Detayı Aç'),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Düzenle'),
                                ),
                              ];
                              
                              // Teknisyenler silme yapamaz
                              if (_userRole != 'technician' && _userRole != 'pending') {
                                items.add(
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Sil'),
                                  ),
                                );
                              }
                              
                              return items;
                            },
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
