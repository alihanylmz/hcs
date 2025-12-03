import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/partner_service.dart';
import '../services/user_service.dart';
import '../services/pdf_export_service.dart';
import '../models/user_profile.dart';
import '../models/partner.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_header.dart';
import 'login_page.dart';
import 'pdf_viewer_page.dart';

class PartnerDashboardPage extends StatefulWidget {
  const PartnerDashboardPage({super.key});

  @override
  State<PartnerDashboardPage> createState() => _PartnerDashboardPageState();
}

class _PartnerDashboardPageState extends State<PartnerDashboardPage> {
  final PartnerService _partnerService = PartnerService();
  final UserService _userService = UserService();
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  UserProfile? _userProfile;
  Partner? _partnerInfo;
  List<Map<String, dynamic>> _tickets = [];
  Map<String, int> _stats = {'active': 0, 'completed': 0};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _userService.getCurrentUserProfile();
      _userProfile = profile;

      if (profile?.partnerId != null) {
        // Partner bilgilerini çek
        final partner = await _partnerService.getPartnerById(profile!.partnerId!);
        _partnerInfo = partner;

        // İşleri çek
        final tickets = await _partnerService.getPartnerTickets(profile.partnerId!);
        final stats = await _partnerService.getPartnerStats(profile.partnerId!);
        
        if (mounted) {
          setState(() {
            _tickets = tickets;
            _stats = stats;
            _isLoading = false;
          });
        }
      } else {
        // Partner ID yoksa hata veya yönlendirme
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Partner kaydı bulunamadı! Yöneticinizle görüşün.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Dashboard yükleme hatası: $e');
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
  
  Future<void> _downloadReport(Map<String, dynamic> ticket) async {
    // PDF Oluşturma ve Görüntüleme
    try {
      // Burada ticket nesnesini Ticket modeline çevirmek gerekebilir veya servise map olarak göndermek
      // Şimdilik basit bir rapor mantığı kuralım. Mevcut PDF servisiniz Ticket modeli bekliyor olabilir.
      // Bu örnek için PdfViewerPage'e basit bir generator gönderiyoruz.
      
      /* 
      // NOT: PdfExportService.generateTicketPdfBytes metodunun Map veya Model kabul ettiğini varsayıyoruz.
      // Eğer Model istiyorsa dönüşüm yapmalıyız.
      */
      
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapor hazırlanıyor... (Demo)')),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rapor hatası: $e')),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open': return Colors.orange;
      case 'completed': return Colors.green;
      case 'pending': return Colors.blue;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'open': return 'Açık / İşlemde';
      case 'completed': return 'Tamamlandı';
      case 'pending': return 'Beklemede';
      case 'cancelled': return 'İptal';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : AppColors.backgroundGrey;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.corporateNavy))
          : Column(
              children: [
                // Header
                CustomHeader(
                  title: _partnerInfo?.name ?? 'Partner Portalı',
                  subtitle: 'Hoş geldiniz, ${_userProfile?.fullName ?? ''}',
                  showBackArrow: false,
                  onBackPressed: () {}, // Drawer menü butonu olabilir
                ),
                
                // İstatistik Kartları
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard('Aktif İşler', _stats['active'].toString(), Colors.orange, Icons.work_history),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard('Tamamlanan', _stats['completed'].toString(), Colors.green, Icons.check_circle),
                      ),
                    ],
                  ),
                ),
                
                // İş Listesi Başlığı
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Son İş Kayıtları',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _loadDashboard,
                        tooltip: 'Yenile',
                      ),
                    ],
                  ),
                ),

                // Liste
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadDashboard,
                    child: _tickets.isEmpty
                        ? Center(
                            child: Text(
                              'Kayıtlı iş bulunamadı.',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _tickets.length,
                            itemBuilder: (context, index) {
                              final ticket = _tickets[index];
                              final status = ticket['status'] as String? ?? 'pending';
                              final date = ticket['created_at'] != null 
                                  ? DateTime.parse(ticket['created_at']).toString().substring(0, 10) 
                                  : '-';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                color: cardColor,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getStatusColor(status).withOpacity(0.1),
                                    child: Icon(
                                      status == 'completed' ? Icons.check : Icons.build,
                                      color: _getStatusColor(status),
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    ticket['device_name'] ?? 'Cihaz',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Konu: ${ticket['subject'] ?? '-'}'),
                                      Text('Tarih: $date', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                  trailing: status == 'completed' 
                                      ? IconButton(
                                          icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                          onPressed: () => _downloadReport(ticket),
                                          tooltip: 'Raporu İndir',
                                        )
                                      : Chip(
                                          label: Text(
                                            _getStatusText(status), 
                                            style: TextStyle(color: _getStatusColor(status), fontSize: 10),
                                          ),
                                          backgroundColor: _getStatusColor(status).withOpacity(0.1),
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                
                // Çıkış Yap Butonu (Geçici)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text('Oturumu Kapat'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

