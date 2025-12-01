import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'ticket_list_page.dart';
import 'login_page.dart';
import '../widgets/app_drawer.dart';
import '../services/user_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _supabase = Supabase.instance.client;
  final _userService = UserService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  String? _userName;
  String? _userRole;
  
  // İstatistik Verileri
  int _monthlyTicketCount = 0;
  int _openTicketCount = 0;
  List<Map<String, dynamic>> _mostUsedPlcs = [];
  List<Map<String, dynamic>> _lowStockItems = [];
  
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadDashboardData();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userService.getCurrentUserProfile();
    if (mounted) {
      setState(() {
        _userName = profile?.fullName;
        _userRole = profile?.role;
      });
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

      // 1. Bu ay açılan iş emirleri sayısı (Sadece id'leri çek, performans için)
      final monthlyTicketsList = await _supabase
          .from('tickets')
          .select('id')
          .gte('created_at', startOfMonth.toIso8601String())
          .lt('created_at', startOfNextMonth.toIso8601String());
      
      // 2. Açık iş emirleri sayısı (Sadece id'leri çek, performans için)
      final openTicketsList = await _supabase
          .from('tickets')
          .select('id')
          .eq('status', 'open');

      // 3. En çok kullanılan PLC'ler (Basit bir analiz)
      // Supabase'de group by desteği sınırlı olabilir, client-side yapacağız
      // PERFORMANS: Son 1000 kayda bak, tüm veritabanını çekme!
      final plcsResponse = await _supabase
          .from('tickets')
          .select('plc_model')
          .not('plc_model', 'is', null)
          .order('created_at', ascending: false)
          .limit(1000); // Emniyet kemeri: Sadece son 1000 kayda bak
      
      final Map<String, int> plcCounts = {};
      for (var item in plcsResponse) {
        final model = item['plc_model'] as String?;
        if (model != null && model.isNotEmpty && model != 'Diğer') {
          plcCounts[model] = (plcCounts[model] ?? 0) + 1;
        }
      }
      
      final sortedPlcs = plcCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      final topPlcs = sortedPlcs.take(5).map((e) => {'name': e.key, 'count': e.value}).toList();

      // 4. Kritik Stok Durumu
      // critical_level kolonu yoksa hata verebilir, kontrol edelim.
      // Eğer critical_level null ise varsayılan 5 kabul edelim.
      final inventoryResponse = await _supabase
          .from('inventory')
          .select()
          .order('quantity', ascending: true);
          
      final List<Map<String, dynamic>> lowStock = [];
      for (var item in inventoryResponse) {
        final qty = item['quantity'] as int? ?? 0;
        final critical = item['critical_level'] as int? ?? 5; // Varsayılan kritik seviye
        
        if (qty <= critical) {
          lowStock.add(item);
        }
      }

      if (mounted) {
        setState(() {
          // Listelerden sayıyı al (sadece id çekildiği için hafif)
          _monthlyTicketCount = (monthlyTicketsList as List).length;
          _openTicketCount = (openTicketsList as List).length;
          _mostUsedPlcs = topPlcs;
          _lowStockItems = lowStock.take(10).toList(); // İlk 10 kritik ürün
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Dashboard veri hatası: $e');
      if (mounted) setState(() => _isLoading = false);
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
      backgroundColor: const Color(0xFFF1F5F9), // Açık gri arka plan
      drawer: AppDrawer(
        currentPage: AppDrawerPage.dashboard,
        userName: _userName,
        userRole: _userRole,
      ),
      appBar: AppBar(
        title: const Text('Yönetici Paneli', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
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
              child: SvgPicture.asset('assets/images/log.svg', width: 32, height: 32),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst Bilgi Kartları
                  _buildSummarySection(isWide),
                  
                  const SizedBox(height: 24),
                  
                  // Ana İçerik (Grafik ve Tablolar)
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildPlcChartCard()),
                        const SizedBox(width: 24),
                        Expanded(flex: 4, child: _buildLowStockCard()),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildPlcChartCard(),
                        const SizedBox(height: 24),
                        _buildLowStockCard(),
                      ],
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const TicketListPage()));
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
      childAspectRatio: 1.3, // Aspect ratio düşürüldü, kartlar uzadı
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
          '5', // Şimdilik sabit veya user tablosundan çekilebilir
          Icons.people_outline,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              color: color, // Sayıyı renkli yapalım
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

  Widget _buildPlcChartCard() {
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
            'En Çok Arızalanan PLC Modelleri',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
          ),
          const Divider(height: 30),
          if (_mostUsedPlcs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Veri bulunamadı.'),
            )
          else
            ..._mostUsedPlcs.asMap().entries.map((entry) {
              final index = entry.key; // Sıralama numarası (0, 1, 2...)
              final e = entry.value;
              final count = e['count'] as int;
              // Basit bir oranlama (en yüksek değere göre)
              final max = _mostUsedPlcs.first['count'] as int;
              final ratio = count / max;
              
              // İlk 3'e özel renk, diğerleri gri
              Color barColor;
              if (index == 0) {
                barColor = Colors.orange; // Altın 🥇
              } else if (index == 1) {
                barColor = Colors.grey.shade400; // Gümüş 🥈
              } else if (index == 2) {
                barColor = Colors.brown.shade300; // Bronz 🥉
              } else {
                barColor = Colors.indigoAccent.withOpacity(0.5);
              }
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e['name'], style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text('$count Adet', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade100,
                        color: barColor, // Dinamik renk
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
             ],
           ),
          const Divider(height: 30),
          if (_lowStockItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Kritik seviyenin altında ürün yok.', style: TextStyle(color: Colors.green)),
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
                  title: Text(item['name'] ?? '-', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      '$qty Adet', 
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

