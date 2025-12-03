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
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_drawer.dart';

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

  // Tarih filtresi
  DateTime? _startDate;
  DateTime? _endDate;

  // Sayfalama: ilk etapta 50 iş, "Daha Fazla Yükle" ile artırılacak
  int _pageLimit = 50;

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

  /// PDF raporları için sayfalama olmadan tüm ticket'ları çeker.
  Future<List<Map<String, dynamic>>> _fetchAllTicketsForReport() async {
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
          device_brand,
          missing_parts,
          customers (
            id,
            name,
            address
          )
        ''')
        .order('created_at', ascending: false);

    final List data = response as List;
    return data.cast<Map<String, dynamic>>();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchTickets() async {
    final supabase = Supabase.instance.client;

    // Teknisyenler için: draft durumundaki işleri gösterme
    // Admin ve manager'lar tüm işleri görebilir
    final isAdminOrManager = _userRole == 'admin' || _userRole == 'manager';
    
    var query = supabase
          .from('tickets')
        .select('''
          id,
          title,
          status,
          priority,
          planned_date,
          job_code,
          device_model,
          device_brand,
          missing_parts, 
          customers (
            id,
            name,
            address
          )
        ''')
        .neq('status', 'done');
    
    // Teknisyenler için draft durumundaki işleri filtrele
    if (!isAdminOrManager) {
      query = query.neq('status', 'draft');
    }
    
    final response = await query
        .order('created_at', ascending: false)
        .limit(_pageLimit);

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
    List<Map<String, dynamic>> tickets,
  ) {
    final search = _normalizeTurkish(_searchText.trim());

    return tickets.where((ticket) {
      final status = (ticket['status'] as String?) ?? '';
      final priority = (ticket['priority'] as String?) ?? '';
      final plannedDateStr = ticket['planned_date'] as String?;

      final customer =
          ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final title = (ticket['title'] as String?) ?? '';
      final customerName = (customer['name'] as String?) ?? '';
      final jobCode = (ticket['job_code'] as String?) ?? '';

      if (_statusFilter != 'all' && status != _statusFilter) {
        return false;
      }

      if (_priorityFilter != 'all' && priority != _priorityFilter) {
        return false;
      }

      // Tarih filtresi (planned_date'e göre)
      if (_startDate != null || _endDate != null) {
        if (plannedDateStr == null || plannedDateStr.isEmpty) {
          return false;
        }
        DateTime? ticketDate;
        try {
          ticketDate = DateTime.tryParse(plannedDateStr);
        } catch (_) {
          ticketDate = null;
        }
        if (ticketDate == null) return false;

        final d = DateTime(ticketDate.year, ticketDate.month, ticketDate.day);
        if (_startDate != null) {
          final s = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
          if (d.isBefore(s)) return false;
        }
        if (_endDate != null) {
          final e = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
          if (d.isAfter(e)) return false;
        }
      }

      if (search.isNotEmpty) {
        final normalizedTitle = _normalizeTurkish(title);
        final normalizedCustomerName = _normalizeTurkish(customerName);
        final normalizedJobCode = _normalizeTurkish(jobCode);
        final combined = '$normalizedTitle $normalizedCustomerName $normalizedJobCode';

        // 1) Normal metin araması (başlık + müşteri + iş kodu)
        bool matches = combined.contains(search);

        // 2) Ek: Sadece rakamdan oluşan aramalarda iş kodu rakamları içinde ara
        // Örn: H-001-23 için "23" veya "00123" gibi aramalar
        if (!matches) {
          final digitsInSearch = search.replaceAll(RegExp(r'\D'), '');
          if (digitsInSearch.isNotEmpty) {
            final jobCodeDigits = jobCode.replaceAll(RegExp(r'\D'), '');
            if (jobCodeDigits.contains(digitsInSearch)) {
              matches = true;
            }
          }
        }

        if (!matches) return false;
      }

      return true;
    }).toList();
  }

  /*
  Future<void> _loadDeviceBrands() async {
    try {
      final brands = await _deviceBrandService.getAllBrands();
      if (mounted) {
        setState(() {
          _deviceBrands = brands;
        });
      }
    } catch (_) {
      // tablo yoksa sessiz geç
    }
  }
  */

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final initial = _startDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.corporateNavy,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final initial = _endDate ?? _startDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.corporateNavy,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _endDate = picked);
    }
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



  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final customer = ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final deviceBrand = ticket['device_brand'] as String?; // Partner adı cihaz markası alanında
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
          // Partner kullanıcılar için kırmızı çerçeve de gösterilmesin
          color: (hasMissingParts && _userRole != 'partner_user')
              ? Colors.red.withOpacity(0.5)
              : theme.dividerColor.withOpacity(0.1),
          width: (hasMissingParts && _userRole != 'partner_user') ? 1.5 : 1.0,
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
          if (deviceBrand != null && deviceBrand.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.handshake_outlined, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    deviceBrand,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
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
          // Partner kullanıcılar iş listesinde stok eksikliği bilgisi görmesin
          if (hasMissingParts && _userRole != 'partner_user') ...[
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
                if (_userRole != 'partner_user')
                  _TicketActionButton(
                    label: 'Düzenle',
                    icon: Icons.edit_outlined,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditTicketPage(ticketId: ticket['id'].toString()))).then((_) => _refresh()),
                  ),
                // Teknisyenler ve partner kullanıcılar silme yapamaz
                if (_userRole != 'technician' && _userRole != 'pending' && _userRole != 'partner_user') ...[
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Cihaz Tipi Seçin',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.hvac, color: Colors.white),
                ),
                title: const Text('Klima Santrali'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const NewTicketPage(deviceType: 'santral')
                  )).then((_) => _refresh());
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.wind_power, color: Colors.white),
                ),
                title: const Text('Jet Fan / Otopark'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const NewTicketPage(deviceType: 'jet_fan')
                  )).then((_) => _refresh());
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.build, color: Colors.white),
                ),
                title: const Text('Diğer / Arıza'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const NewTicketPage(deviceType: 'other')
                  )).then((_) => _refresh());
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
      drawer: AppDrawer(
        currentPage: AppDrawerPage.ticketList,
        userName: _userName,
        userRole: _userRole,
        onProfileReload: _loadUserProfile,
      ),
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Seçenekler',
            onSelected: (value) async {
              switch (value) {
                case 'pdf_filtered':
                  final tickets = await _ticketsFuture;
                  final filtered = _applyFilters(tickets);
                  _createPdfReport(filtered);
                  break;
                case 'pdf_all':
                  final allTickets = await _fetchAllTicketsForReport();
                  _createPdfReport(allTickets);
                  break;
                case 'toggle_theme':
                  IsTakipApp.of(context)?.toggleTheme();
                  break;
                case 'refresh':
                  _refresh();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'pdf_filtered',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('Filtrelenmiş listeyi PDF al'),
                ),
              ),
              const PopupMenuItem(
                value: 'pdf_all',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.picture_as_pdf),
                  title: Text('Tüm işleri PDF al'),
                ),
              ),
              PopupMenuItem(
                value: 'toggle_theme',
                child: ListTile(
                  dense: true,
                  leading: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                  title: Text(isDark ? 'Açık tema' : 'Koyu tema'),
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.refresh),
                  title: Text('Yenile'),
                ),
              ),
            ],
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
                                icon: Icons.assignment_outlined,
                                onTap: () {
                                  setState(() {
                                    _statusFilter = 'open';
                                  });
                                },
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                title: 'Pano (Stok)', 
                                value: tickets.where((e) => e['status'] == 'panel_done_stock').length.toString(), 
                                color: Colors.purple, 
                                icon: Icons.inventory_2_outlined,
                                onTap: () {
                                  setState(() {
                                    _statusFilter = 'panel_done_stock';
                                  });
                                },
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                title: 'Pano (Gön.)', 
                                value: tickets.where((e) => e['status'] == 'panel_done_sent').length.toString(), 
                                color: Colors.indigo, 
                                icon: Icons.local_shipping_outlined,
                                onTap: () {
                                  setState(() {
                                    _statusFilter = 'panel_done_sent';
                                  });
                                },
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                title: 'Serviste', 
                                value: progressCount.toString(), 
                                color: Colors.orange, 
                                icon: Icons.build_circle_outlined,
                                onTap: () {
                                  setState(() {
                                    _statusFilter = 'in_progress';
                                  });
                                },
                              ),
                              const SizedBox(width: 12),
                              _buildStatCard(
                                title: 'Biten Hariç Tümü', 
                                value: tickets.length.toString(), 
                                color: Colors.green, 
                                icon: Icons.list_alt_outlined,
                                onTap: () {
                                  setState(() {
                                    _statusFilter = 'all';
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Arama ve Filtreler
                        TextField(
                          controller: _searchController,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.search,
                          enableSuggestions: true,
                          autocorrect: true,
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
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: _pickStartDate,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Başlangıç Tarihi',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _startDate == null
                                              ? 'Seçilmedi'
                                              : DateFormat('dd.MM.yyyy').format(_startDate!),
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        const Icon(Icons.calendar_today, size: 16),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: _pickEndDate,
                                  borderRadius: BorderRadius.circular(8),
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Bitiş Tarihi',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _endDate == null
                                              ? 'Seçilmedi'
                                              : DateFormat('dd.MM.yyyy').format(_endDate!),
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        const Icon(Icons.calendar_today, size: 16),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _statusFilter = 'all';
                                  _priorityFilter = 'all';
                                  // _deviceBrandFilter = 'all';
                                  _startDate = null;
                                  _endDate = null;
                                });
                              },
                              child: const Text('Filtreleri Temizle'),
                            ),
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
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildTicketCard(filtered[index]),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
                  if (tickets.length >= _pageLimit)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _pageLimit += 50;
                                _ticketsFuture = _fetchTickets();
                              });
                            },
                            icon: const Icon(Icons.expand_more),
                            label: Text('Daha Fazla Yükle ($_pageLimit+)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.corporateNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                ],
              ],
            ),
          );
        },
      ),
      // Teknisyenler, partner kullanıcılar ve onay bekleyenler yeni iş açamaz
      floatingActionButton: (_userRole != 'technician' && _userRole != 'pending' && _userRole != 'partner_user')
          ? FloatingActionButton.extended(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              onPressed: () => _showDeviceSelection(context),
              label: const Text('YENİ İŞ'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }
}
