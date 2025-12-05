import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'ticket_list_page.dart';
import 'login_page.dart';
import 'ticket_detail_page.dart';
import 'partner_management_page.dart';
import 'user_management_page.dart';
import '../widgets/app_drawer.dart';
import '../services/user_service.dart';
import '../services/partner_service.dart';
import '../models/user_profile.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _supabase = Supabase.instance.client;
  final _userService = UserService();
  final PartnerService _partnerService = PartnerService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // User Profile - Loaded first
  UserProfile? _currentUser;
  
  // Loading & Error States
  bool _isLoading = true;
  String? _errorMessage;
  
  // Dashboard Statistics
  int _monthlyTicketCount = 0;
  int _openTicketCount = 0;
  int _recentOpenCount = 0;
  int _recentInProgressCount = 0;
  int _recentPanelStockCount = 0;
  int _recentPanelSentCount = 0;
  
  // Dashboard Data Lists
  List<Map<String, dynamic>> _lowStockItems = [];
  List<Map<String, dynamic>> _recentTickets = [];
  List<Map<String, dynamic>> _partnerOverview = [];
  
  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  /// Sequential Loading: First load user profile, then dashboard data
  Future<void> _initDashboard() async {
    try {
      // Step 1: Load user profile first (CRITICAL)
      final profile = await _userService.getCurrentUserProfile();
      
      if (!mounted) return;
      
      if (profile == null) {
        setState(() {
          _errorMessage = 'Kullanıcı profili bulunamadı.';
          _isLoading = false;
        });
        return;
      }
      
      setState(() {
        _currentUser = profile;
      });
      
      // Step 2: Only after user profile is loaded, fetch dashboard data
      await _loadDashboardData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Dashboard yüklenirken hata oluştu: ${e.toString()}';
          _isLoading = false;
        });
        _showErrorSnackBar('Veri yüklenirken hata oluştu');
      }
    }
  }

  /// Load all dashboard data with optimized queries
  Future<void> _loadDashboardData() async {
    if (_currentUser == null) return;
    
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

      // 1. Monthly Tickets Count - Using count() for performance
      final monthlyTicketsCount = await _supabase
          .from('tickets')
          .select('id')
          .gte('created_at', startOfMonth.toIso8601String())
          .lt('created_at', startOfNextMonth.toIso8601String())
          .count(CountOption.exact);
      
      // 2. Open Tickets Count - Using count() for performance
      final openTicketsCount = await _supabase
          .from('tickets')
          .select('id')
          .eq('status', 'open')
          .count(CountOption.exact);

      // 3. Recent Tickets with Partner Join - Optimized single query
      // Filters must come before order() and limit()
      var recentTicketsQuery = _supabase
          .from('tickets')
          .select('*, partners(name)');
      
      // Role-based filtering: Non-admin/manager users don't see draft tickets
      if (!_currentUser!.isAdmin && !_currentUser!.isManager) {
        recentTicketsQuery = recentTicketsQuery.neq('status', 'draft');
      }
      
      final recentTicketsResponse = await recentTicketsQuery
          .order('created_at', ascending: false)
          .limit(50);
      final recentTicketsList = (recentTicketsResponse as List)
          .cast<Map<String, dynamic>>();

      // Count statuses from recent tickets
      int recentOpen = 0;
      int recentInProgress = 0;
      int recentPanelStock = 0;
      int recentPanelSent = 0;

      for (final t in recentTicketsList) {
        final status = t['status'] as String? ?? 'open';
        switch (status) {
          case 'open':
            recentOpen++;
            break;
          case 'in_progress':
            recentInProgress++;
            break;
          case 'panel_done_stock':
            recentPanelStock++;
            break;
          case 'panel_done_sent':
            recentPanelSent++;
            break;
        }
      }

      // 4. Partner Overview with optimized query
      final partnersResponse = await _partnerService.getAllPartners();
      
      var partnerTicketsQuery = _supabase
          .from('tickets')
          .select('id, partner_id, status, job_code, title')
          .not('partner_id', 'is', null)
          .neq('status', 'done');
      
      // Role-based filtering
      if (!_currentUser!.isAdmin && !_currentUser!.isManager) {
        partnerTicketsQuery = partnerTicketsQuery.neq('status', 'draft');
      }
      
      final partnerTicketsResponse = await partnerTicketsQuery;
      final partnerTicketsList = (partnerTicketsResponse as List)
          .cast<Map<String, dynamic>>();

      final Map<int, Map<String, int>> partnerCounts = {};
      final Map<int, List<Map<String, dynamic>>> partnerOpenJobs = {};
      
      for (final t in partnerTicketsList) {
        final pid = t['partner_id'] as int?;
        final status = t['status'] as String? ?? 'open';
        if (pid == null) continue;
        
        partnerCounts.putIfAbsent(pid, () => {
          'total': 0,
          'open': 0,
          'in_progress': 0,
        });
        
        partnerCounts[pid]!['total'] = (partnerCounts[pid]!['total'] ?? 0) + 1;
        
        if (status == 'open') {
          partnerCounts[pid]!['open'] = (partnerCounts[pid]!['open'] ?? 0) + 1;
          partnerOpenJobs.putIfAbsent(pid, () => []);
          if (partnerOpenJobs[pid]!.length < 3) {
            partnerOpenJobs[pid]!.add({
              'id': t['id'],
              'job_code': t['job_code'],
              'title': t['title'],
            });
          }
        } else if (status == 'in_progress') {
          partnerCounts[pid]!['in_progress'] = (partnerCounts[pid]!['in_progress'] ?? 0) + 1;
        }
      }

      final List<Map<String, dynamic>> partnerOverview = [];
      for (final p in partnersResponse) {
        final counts = partnerCounts[p.id];
        if (counts == null) continue; // Skip partners with no active jobs
        
        partnerOverview.add({
          'id': p.id,
          'name': p.name,
          'total': counts['total'] ?? 0,
          'open': counts['open'] ?? 0,
          'in_progress': counts['in_progress'] ?? 0,
          'openJobs': (partnerOpenJobs[p.id] ?? []),
        });
      }
      partnerOverview.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

      // 5. Low Stock Items
      final inventoryResponse = await _supabase
          .from('inventory')
          .select()
          .order('quantity', ascending: true)
          .limit(50);
          
      final List<Map<String, dynamic>> lowStock = [];
      final inventoryList = (inventoryResponse as List).cast<Map<String, dynamic>>();
      
      for (var item in inventoryList) {
        final qty = item['quantity'] as int? ?? 0;
        final critical = item['critical_level'] as int? ?? 5;
        
        if (qty <= critical) {
          lowStock.add(item);
        }
      }

      if (mounted) {
        setState(() {
          // Extract counts from Supabase count responses
          _monthlyTicketCount = monthlyTicketsCount.count ?? 0;
          _openTicketCount = openTicketsCount.count ?? 0;
          _recentOpenCount = recentOpen;
          _recentInProgressCount = recentInProgress;
          _recentPanelStockCount = recentPanelStock;
          _recentPanelSentCount = recentPanelSent;
          _recentTickets = recentTicketsList.take(8).toList();
          _partnerOverview = partnerOverview.take(6).toList();
          _lowStockItems = lowStock.take(10).toList();
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Dashboard veri hatası: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Veri yüklenirken hata oluştu: ${e.toString()}';
        });
        _showErrorSnackBar('Veri yüklenirken hata oluştu');
      }
    }
  }

  /// Refresh dashboard data (for RefreshIndicator)
  Future<void> _refreshDashboard() async {
    await _loadDashboardData();
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Get dynamic appbar title based on user role
  String _getAppBarTitle() {
    if (_currentUser == null) return 'Yükleniyor...';
    
    if (_currentUser!.isAdmin) {
      return 'Yönetici Paneli';
    } else if (_currentUser!.isManager) {
      return 'Yönetici Paneli';
    } else if (_currentUser!.isTechnician) {
      return 'Teknisyen Paneli';
    } else {
      return 'Saha Yönetimi';
    }
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: AppDrawer(
        currentPage: AppDrawerPage.dashboard,
        userName: _currentUser?.displayName,
        userRole: _currentUser?.role,
      ),
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        leadingWidth: 100,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 0),
              child: SvgPicture.asset(
                'assets/images/log.svg',
                width: 32,
                height: 32,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Management menu (only for admin/manager)
          if (_currentUser != null &&
              (_currentUser!.isAdmin || _currentUser!.isManager))
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: Color(0xFF0F172A),
              ),
              onSelected: (value) {
                switch (value) {
                  case 'users':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const UserManagementPage(),
                      ),
                    );
                    break;
                  case 'partners':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PartnerManagementPage(),
                      ),
                    );
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'users',
                  child: Row(
                    children: [
                      Icon(Icons.people_outline, color: Color(0xFF0F172A)),
                      SizedBox(width: 12),
                      Text('Kullanıcı Yönetimi'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'partners',
                  child: Row(
                    children: [
                      Icon(Icons.business_rounded, color: Color(0xFF0F172A)),
                      SizedBox(width: 12),
                      Text('Partner Firmalar'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initDashboard,
                        child: const Text('Yeniden Dene'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshDashboard,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Summary Cards
                        _buildSummarySection(isWide),
                        
                        const SizedBox(height: 24),

                        // Status Overview + Recent Tickets
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildStatusOverviewCard()),
                              const SizedBox(width: 24),
                              Expanded(flex: 4, child: _buildRecentTicketsCard()),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildStatusOverviewCard(),
                              const SizedBox(height: 24),
                              _buildRecentTicketsCard(),
                            ],
                          ),

                        const SizedBox(height: 24),
                        
                        // Partner Overview + Low Stock
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildPartnerOverviewCard()),
                              const SizedBox(width: 24),
                              Expanded(flex: 4, child: _buildLowStockCard()),
                            ],
                          )
                        else
                          Column(
                            children: [
                              _buildPartnerOverviewCard(),
                              const SizedBox(height: 24),
                              _buildLowStockCard(),
                            ],
                          ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TicketListPage()),
          );
        },
        label: const Text('İş Emirleri Listesi'),
        icon: const Icon(Icons.list_alt),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildSummarySection(bool isWide) {
    return GridView.count(
      crossAxisCount: isWide ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      childAspectRatio: 1.0,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Aylık Servis',
          _monthlyTicketCount.toString(),
          Icons.calendar_month,
          Colors.blue,
        ),
        _buildStatCard(
          'Açık İşler',
          _openTicketCount.toString(),
          Icons.assignment_late_outlined,
          Colors.orange,
        ),
        _buildStatCard(
          'Kritik Stok',
          _lowStockItems.length.toString(),
          Icons.inventory_2_outlined,
          Colors.red,
        ),
        _buildStatCard(
          'Personel',
          '5', // TODO: Fetch from users table if needed
          Icons.people_outline,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatusOverviewCard() {
    final totalRecent = _recentOpenCount +
        _recentInProgressCount +
        _recentPanelStockCount +
        _recentPanelSentCount;

    Widget buildRow(String label, int count, Color color) {
      final ratio = (totalRecent > 0) ? count / totalRecent : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade100,
                  color: color.withOpacity(0.9),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Durum Özeti (Son 50 İş)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          if (totalRecent == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Gösterilecek iş bulunamadı.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else ...[
            buildRow('Açık', _recentOpenCount, Colors.blue),
            buildRow('Serviste', _recentInProgressCount, Colors.orange),
            buildRow('Pano Yapıldı (Stok)', _recentPanelStockCount, Colors.purple),
            buildRow(
              'Pano Yapıldı (Gönderildi)',
              _recentPanelSentCount,
              Colors.indigo,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentTicketsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Son İş Emirleri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'En son açılan 8 iş emri',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (_recentTickets.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Henüz iş emri açılmamış.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentTickets.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final t = _recentTickets[index];
                final status = t['status'] as String? ?? 'open';
                final title = t['title'] as String? ?? 'Başlıksız';
                final plannedDate = t['planned_date'] as String?;
                final jobCode = t['job_code'] as String? ?? '---';
                
                // Extract partner name from joined data
                final partnerData = t['partners'] as Map<String, dynamic>?;
                final partnerName = partnerData?['name'] as String?;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TicketDetailPage(
                          ticketId: t['id'].toString(),
                        ),
                      ),
                    );
                  },
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            jobCode,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          if (plannedDate != null) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.calendar_today,
                              size: 11,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              plannedDate.substring(0, 10),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (partnerName != null && partnerName.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.handshake_outlined,
                              size: 11,
                              color: Colors.deepPurple,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                partnerName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Partner İş Durumu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Aktif işi bulunan partnerler',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (_partnerOverview.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Şu anda partnerlere atanmış aktif iş bulunmuyor.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _partnerOverview.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = _partnerOverview[index];
                final total = p['total'] as int? ?? 0;
                final open = p['open'] as int? ?? 0;
                final inProgress = p['in_progress'] as int? ?? 0;
                final ratio = total > 0 ? inProgress / total : 0.0;

                final openJobs = (p['openJobs'] as List<dynamic>? ?? [])
                    .cast<Map<String, dynamic>>();

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    p['name'] as String? ?? '-',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Açık: $open',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Serviste: $inProgress',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (openJobs.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: openJobs.map((job) {
                            final code = (job['job_code'] as String?) ?? 'Kod yok';
                            return InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TicketDetailPage(
                                      ticketId: job['id'].toString(),
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  code,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 6),
                      ],
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade100,
                          color: Colors.purpleAccent.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'İş',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLowStockCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Stok Uyarı Listesi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          if (_lowStockItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Kritik seviyenin altında ürün yok.',
                style: TextStyle(color: Colors.green),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lowStockItems.length,
              separatorBuilder: (ctx, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _lowStockItems[index];
                final qty = item['quantity'] as int? ?? 0;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item['name'] ?? '-',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      '$qty Adet',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Status label and colors (consistent with ticket list)
  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Açık';
      case 'panel_done_stock':
        return 'Pano (Stok)';
      case 'panel_done_sent':
        return 'Pano (Gön.)';
      case 'in_progress':
        return 'Serviste';
      case 'done':
        return 'Tamamlandı';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.blue;
      case 'panel_done_stock':
        return Colors.purple;
      case 'panel_done_sent':
        return Colors.indigo;
      case 'in_progress':
        return Colors.orange;
      case 'done':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
