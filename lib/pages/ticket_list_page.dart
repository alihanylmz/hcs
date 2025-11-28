import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart'; // Eklendi
import 'package:intl/intl.dart'; // Tarih formatı için eklendi

import '../main.dart';
import '../services/general_report_service.dart'; // PDF Servisi
import '../pages/archived_tickets_page.dart';
import '../pages/dashboard_page.dart'; // DashboardPage importu
import '../pages/edit_ticket_page.dart';
import '../pages/login_page.dart';
import '../pages/new_ticket_page.dart';
import '../pages/stock_overview_page.dart';
import '../pages/ticket_detail_page.dart';
import '../pages/profile_page.dart';
import '../services/pdf_export_service.dart';

class TicketListPage extends StatefulWidget {
  const TicketListPage({super.key});

  @override
  State<TicketListPage> createState() => _TicketListPageState();
}

class _TicketActionButton extends StatelessWidget {
  const _TicketActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Buton renkleri ve tasarımı
    final Color baseColor = danger 
        ? (isDark ? Colors.redAccent.shade200 : Colors.red.shade600) 
        : (isDark ? Colors.white : const Color(0xFF0F172A));
        
    // Karanlık modda arka planı biraz daha belirgin yapalım
    final Color bg = danger 
        ? (isDark ? Colors.red.withOpacity(0.2) : Colors.red.withOpacity(0.1))
        : (isDark ? Colors.white.withOpacity(0.15) : const Color(0xFF0F172A).withOpacity(0.05));
    
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: baseColor,
        backgroundColor: bg,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), 
        ),
        minimumSize: const Size(0, 36),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18), 
      label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _TicketListPageState extends State<TicketListPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<List<Map<String, dynamic>>> _ticketsFuture;

  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  String _statusFilter = 'open'; // Varsayılan olarak sadece Açık işler
  String _priorityFilter = 'all';
  bool _filtersExpanded = false;

  String? _userName;
  String? _userRole; // Rol bilgisini tutacak değişken

  @override
  void initState() {
    super.initState();
    _ticketsFuture = _fetchTickets();
    _loadUserProfile(); 
  }

  Future<void> _loadUserProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final profile = await supabase
            .from('profiles')
            .select('full_name, role') // Rolü de çekiyoruz
            .eq('id', user.id)
            .maybeSingle();
        if (mounted) {
           setState(() {
             _userName = profile != null ? profile['full_name'] as String? : null;
             _userRole = profile != null ? profile['role'] as String? : null;
           });
        }
      } catch (_) {
        // Hata olursa varsayılan değer kalır
      }
    }
  }

  void _createPdfReport(List<Map<String, dynamic>> allTickets) {
    GeneralReportService().generateAndPrintReport(
      allTickets, 
      _userName ?? 'Kullanıcı'
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchTickets() async {
    final supabase = Supabase.instance.client;

    final response = await supabase
          .from('tickets')
        .select('''
          id,
          title,
          status,
          priority,
          planned_date,
          job_code,
          device_model,
          missing_parts, 
          customers (
            id,
            name,
            address
          )
        ''')
        .neq('status', 'done')
        .order('created_at', ascending: false);

    final List data = response as List;
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> _refresh() async {
    setState(() {
      _ticketsFuture = _fetchTickets();
    });
  }

  Future<void> _signOut() async {
    final supabase = Supabase.instance.client;
    await supabase.auth.signOut();
    // AuthGate will handle navigation
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> tickets,
  ) {
    final search = _searchText.trim().toLowerCase();

    return tickets.where((ticket) {
      final status = (ticket['status'] as String?) ?? '';
      final priority = (ticket['priority'] as String?) ?? '';

      final customer =
          ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final title = (ticket['title'] as String?) ?? '';
      final customerName = (customer['name'] as String?) ?? '';

      if (_statusFilter != 'all' && status != _statusFilter) {
        return false;
      }

      if (_priorityFilter != 'all' && priority != _priorityFilter) {
        return false;
      }

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

  String _statusLabel(String status) {
    switch (status) {
      case 'open': return 'Açık';
      case 'panel_done_stock': return 'Panosu Yapıldı Stokta';
      case 'panel_done_sent': return 'Panosu Yapıldı Gönderildi';
      case 'in_progress': return 'Serviste';
      case 'done': return 'İş Tamamlandı';
      default: return status;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'low': return 'Düşük';
      case 'normal': return 'Normal';
      case 'high': return 'Yüksek';
      default: return priority;
    }
  }
  
  Color _getStatusColor(String status, bool isDark) {
    switch (status) {
      case 'open': return isDark ? Colors.blue.shade300 : Colors.blue.shade700;
      case 'panel_done_stock': return isDark ? Colors.purple.shade300 : Colors.purple.shade700;
      case 'panel_done_sent': return isDark ? Colors.indigo.shade300 : Colors.indigo.shade700;
      case 'in_progress': return isDark ? Colors.orange.shade300 : Colors.orange.shade700;
      case 'done': return isDark ? Colors.green.shade300 : Colors.green.shade700;
      default: return Colors.grey;
    }
  }

  Drawer _buildDrawer(User? user, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final headerColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
            ),
            accountName: const Text(
              'İş Takip Platformu',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(user?.email ?? 'Teknisyen'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: theme.colorScheme.secondary,
              child: Text(
                (_userRole ?? 'T').substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // Sadece Admin ve Yöneticiler Görebilir
          if (_userRole == 'admin' || _userRole == 'manager')
            _drawerTile(
              icon: Icons.dashboard_outlined, 
              title: 'Yönetici Paneli', 
              subtitle: 'İstatistikler ve Özet', 
              onTap: () {
                Navigator.pop(context); // Drawer'ı kapat
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DashboardPage()));
              }
            ),
          _drawerTile(
            icon: Icons.list_alt, 
            title: 'İş Listesi', 
            subtitle: 'Ana Sayfa', 
            onTap: () {
              Navigator.pop(context); // Zaten buradayız
            }
          ),
          _drawerTile(
            icon: Icons.inventory_2_outlined, 
            title: 'Stok Durumu', 
            subtitle: 'Parça listesi', 
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StockOverviewPage()));
            }
          ),
          _drawerTile(
            icon: Icons.task_alt, 
            title: 'Biten İşler', 
            subtitle: 'Tamamlanan İşler', 
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArchivedTicketsPage()));
            }
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: Icon(
               IsTakipApp.of(context)?.isDarkMode == true ? Icons.light_mode : Icons.dark_mode,
               color: theme.iconTheme.color,
            ),
            title: Text(IsTakipApp.of(context)?.isDarkMode == true ? 'Aydınlık Mod' : 'Karanlık Mod'),
            onTap: () {
              IsTakipApp.of(context)?.toggleTheme();
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_circle, color: Colors.blue),
            title: const Text('Profilim'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilePage())).then((_) => _loadUserProfile());
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
            onTap: _signOut,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  ListTile _drawerTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    return Container(
        width: 130, // Genişlik artırıldı
        padding: const EdgeInsets.all(12), // Padding azaltıldı
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title, 
              style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final customer = ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final status = ticket['status'] as String? ?? '';
    final priority = ticket['priority'] as String? ?? '';
    final plannedDate = ticket['planned_date'] as String?;
    final title = ticket['title'] as String? ?? 'Başlık yok';
    final jobCode = ticket['job_code'] as String? ?? '---';
    final missingParts = ticket['missing_parts'] as String?; // Eklendi
    final hasMissingParts = missingParts != null && missingParts.isNotEmpty;

    final statusColor = _getStatusColor(status, isDark);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: theme.cardTheme.shadowColor != null 
          ? [BoxShadow(color: theme.cardTheme.shadowColor!, blurRadius: 8, offset: const Offset(0, 2))] 
          : null,
        border: Border.all(
          color: hasMissingParts ? Colors.red.withOpacity(0.5) : theme.dividerColor.withOpacity(0.1),
          width: hasMissingParts ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  jobCode,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
              ),
              Flexible(
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Text(
                    _statusLabel(status).toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.business, size: 14, color: theme.textTheme.bodySmall?.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  customer['name'] as String? ?? 'Müşteri bilgisi yok',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (plannedDate != null) ...[
             const SizedBox(height: 4),
             Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 6),
                  Text(
                    plannedDate.substring(0, 10),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodySmall?.color),
                  ),
                ],
             ),
          ],
          
          // Eksik Parça Uyarısı
          if (hasMissingParts) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Stokta Yok: $missingParts',
                      style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TicketActionButton(
                  label: 'Detay',
                  icon: Icons.visibility_outlined,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TicketDetailPage(ticketId: ticket['id'].toString()))).then((_) => _refresh()),
                ),
                const SizedBox(width: 8),
                _TicketActionButton(
                  label: 'Düzenle',
                  icon: Icons.edit_outlined,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditTicketPage(ticketId: ticket['id'].toString()))).then((_) => _refresh()),
                ),
                const SizedBox(width: 8),
                 IconButton(
                   icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                   onPressed: () {
                     showDialog(
                        context: context, 
                        builder: (ctx) => AlertDialog(
                          title: const Text('Sil'),
                          content: const Text('Bu işi silmek istediğine emin misin?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                final supabase = Supabase.instance.client;
                                await supabase.from('tickets').delete().eq('id', ticket['id']);
                                if (context.mounted) _refresh();
                              }, 
                              child: const Text('Sil', style: TextStyle(color: Colors.red))
                            ),
                          ],
                        )
                     );
                   },
                 ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(user, theme),
      appBar: AppBar(
        title: const Text('İŞ TAKİP KONTROL'),
        centerTitle: true,
        leadingWidth: 100, // Logo ve menü ikonu için genişlik
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            SvgPicture.asset(
              'assets/images/log.svg',
              width: 30,
              height: 30,
            ),
          ],
        ),
        actions: [
          IconButton(
             icon: const Icon(Icons.picture_as_pdf_outlined),
             tooltip: 'Genel Rapor Al',
             onPressed: () async {
               // Rapor için ham veriyi (filtrelenmemiş) çekmemiz lazım
               final tickets = await _ticketsFuture;
               _createPdfReport(tickets);
             },
          ),
          IconButton(
            icon: Icon(
              IsTakipApp.of(context)?.isDarkMode == true ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: 'Tema Değiştir',
            onPressed: () => IsTakipApp.of(context)?.toggleTheme(),
          ),
          IconButton(
             icon: const Icon(Icons.refresh),
             onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final tickets = snapshot.data ?? [];
          final filtered = _applyFilters(tickets);
          
          final openCount = tickets.where((e) => e['status'] == 'open').length;
          final progressCount = tickets.where((e) => e['status'] == 'in_progress').length;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hoşgeldin,',
                          style: TextStyle(fontSize: 14, color: theme.textTheme.bodySmall?.color),
                        ),
                        Text(
                          _userName ?? user?.email ?? 'Teknisyen',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        
                        // İstatistik Kartları
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildStatCard(
                                title: 'Açık İşler', 
                                value: openCount.toString(), 
                                color: Colors.blue, 
                                icon: Icons.assignment_outlined
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                title: 'Pano (Stok)', 
                                value: tickets.where((e) => e['status'] == 'panel_done_stock').length.toString(), 
                                color: Colors.purple, 
                                icon: Icons.inventory_2_outlined
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                title: 'Pano (Gön.)', 
                                value: tickets.where((e) => e['status'] == 'panel_done_sent').length.toString(), 
                                color: Colors.indigo, 
                                icon: Icons.local_shipping_outlined
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                title: 'Serviste', 
                                value: progressCount.toString(), 
                                color: Colors.orange, 
                                icon: Icons.build_circle_outlined
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Arama ve Filtreler
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'İş veya Müşteri Ara...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: IconButton(
                              icon: Icon(_filtersExpanded ? Icons.filter_list_off : Icons.filter_list),
                              onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
                            ),
                          ),
                          onChanged: (val) => setState(() => _searchText = val),
                        ),
                        
                        if (_filtersExpanded) ...[
                           const SizedBox(height: 12),
                           Row(
                             children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _statusFilter,
                                  decoration: const InputDecoration(
                                    labelText: 'Durum',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'all', child: Text('Tümü', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'open', child: Text('Açık', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'panel_done_stock', child: Text('Pano Yapıldı (Stok)', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'panel_done_sent', child: Text('Pano Yapıldı (Gönderildi)', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'in_progress', child: Text('Serviste', overflow: TextOverflow.ellipsis)),
                                  ],
                                  onChanged: (val) => setState(() => _statusFilter = val!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: _priorityFilter,
                                  decoration: const InputDecoration(
                                    labelText: 'Öncelik',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: const [
                                     DropdownMenuItem(value: 'all', child: Text('Tümü', overflow: TextOverflow.ellipsis)),
                                     DropdownMenuItem(value: 'low', child: Text('Düşük', overflow: TextOverflow.ellipsis)),
                                     DropdownMenuItem(value: 'normal', child: Text('Normal', overflow: TextOverflow.ellipsis)),
                                     DropdownMenuItem(value: 'high', child: Text('Yüksek', overflow: TextOverflow.ellipsis)),
                                  ],
                                  onChanged: (val) => setState(() => _priorityFilter = val!),
                                ),
                              ),
                             ],
                           ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Liste
                if (filtered.isEmpty)
                   SliverFillRemaining(
                     hasScrollBody: false,
                     child: Center(
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           Icon(Icons.search_off, size: 64, color: theme.disabledColor),
                           const SizedBox(height: 16),
                           Text('Kayıt bulunamadı.', style: TextStyle(color: theme.disabledColor)),
                         ],
                       ),
                     ),
                   )
                else
                   SliverPadding(
                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                     sliver: SliverList(
                       delegate: SliverChildBuilderDelegate(
                         (context, index) => _buildTicketCard(filtered[index]),
                         childCount: filtered.length,
                       ),
                     ),
                   ),
                   
                const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewTicketPage())).then((_) => _refresh()),
        label: const Text('YENİ İŞ'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
