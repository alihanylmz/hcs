import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../services/general_report_service.dart';
import '../services/notification_service.dart';
import '../pages/archived_tickets_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/edit_ticket_page.dart';
import '../pages/login_page.dart';
import '../pages/new_ticket_page.dart';
import '../pages/stock_overview_page.dart';
import '../pages/ticket_detail_page.dart';
import '../pages/notifications_page.dart';
import '../pages/profile_page.dart';
import '../services/pdf_export_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/sidebar/app_layout.dart';
import '../widgets/ui/ui.dart';
import '../widgets/notifications_dropdown.dart';
import 'pdf_viewer_page.dart';

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
    final Color baseColor =
        danger
            ? (isDark ? Colors.red.shade200 : AppColors.corporateRed)
            : (isDark ? Colors.white : AppColors.textDark);

    // Karanlık modda arka planı biraz daha belirgin yapalım
    final Color bg =
        danger
            ? (isDark
                ? Colors.red.withOpacity(0.16)
                : AppColors.corporateRed.withOpacity(0.08))
            : (isDark ? Colors.white.withOpacity(0.08) : AppColors.surfaceSoft);

    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: baseColor,
        backgroundColor: bg,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color:
                danger
                    ? (isDark
                        ? Colors.red.withOpacity(0.24)
                        : AppColors.corporateRed.withOpacity(0.16))
                    : (isDark
                        ? Colors.white.withOpacity(0.10)
                        : AppColors.borderSubtle),
          ),
        ),
        minimumSize: const Size(0, 34),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TicketListPageState extends State<TicketListPage> {
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
  int _unreadNotifications = 0; // Okunmamış bildirim sayısı
  final GlobalKey _notifIconKey = GlobalKey();
  OverlayEntry? _notifOverlay;

  @override
  void initState() {
    super.initState();
    _ticketsFuture = _fetchTickets();
    _loadUserProfile();
    _checkUnreadNotifications(); // Bildirim kontrolü
  }

  Future<void> _checkUnreadNotifications() async {
    final count = await NotificationService().getUnreadCount();
    if (mounted) {
      setState(() {
        _unreadNotifications = count;
      });
    }
  }

  void _closeNotificationsDropdown() {
    _notifOverlay?.remove();
    _notifOverlay = null;
    _checkUnreadNotifications();
  }

  void _openNotificationsDropdown() {
    if (_notifOverlay != null) {
      _closeNotificationsDropdown();
      return;
    }

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final renderBox =
        _notifIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final iconOffset = renderBox.localToGlobal(Offset.zero);
    final iconSize = renderBox.size;
    const panelWidth = 360.0;

    _notifOverlay = OverlayEntry(
      builder: (context) {
        final screen = MediaQuery.of(context).size;
        final left = (iconOffset.dx + iconSize.width) - panelWidth;
        final clampedLeft = left.clamp(8.0, screen.width - panelWidth - 8.0);
        final top = iconOffset.dy + iconSize.height + 8;

        return Stack(
          children: [
            // dışarı tıklanınca kapat
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeNotificationsDropdown,
                behavior: HitTestBehavior.translucent,
              ),
            ),
            // dropdown panel (zile bağlı)
            Positioned(
              left: clampedLeft,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: NotificationsDropdown(
                  width: panelWidth,
                  onClose: _closeNotificationsDropdown,
                  onOpenTicket: (ticketId) {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder:
                                (_) => TicketDetailPage(ticketId: ticketId),
                          ),
                        )
                        .then((_) => _refresh());
                  },
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_notifOverlay!);
  }

  Future<void> _loadUserProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final profile =
            await supabase
                .from('profiles')
                .select('full_name, role') // Rolü de çekiyoruz
                .eq('id', user.id)
                .maybeSingle();
        if (mounted) {
          setState(() {
            _userName =
                profile != null ? profile['full_name'] as String? : null;
            _userRole = profile != null ? profile['role'] as String? : null;
          });
        }
      } catch (_) {
        // Hata olursa varsayılan değer kalır
      }
    }
  }

  Future<void> _createPdfReport(
    List<Map<String, dynamic>> allTickets, {
    required bool isFiltered,
  }) async {
    // Partner kullanıcılar "günlük/genel rapor" alamaz; sadece ekranda gördüğü filtreli listeyi alabilir.
    if (_userRole == 'partner_user') {
      if (!isFiltered) return;

      final partnerName =
          allTickets.isNotEmpty
              ? (allTickets.first['device_brand'] as String?)
              : null;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => PdfViewerPage(
                title: 'İş Listesi',
                pdfFileName:
                    'Is_Listesi_${DateTime.now().toIso8601String().substring(0, 10)}.pdf',
                pdfGenerator:
                    () => PdfExportService.generateTicketListPdfBytesFromList(
                      tickets: allTickets,
                      reportTitle: 'İş Listesi (Filtrelenmiş)',
                      partnerName: partnerName,
                    ),
              ),
        ),
      );
      return;
    }

    // Diğer roller: mevcut genel rapor mantığı kalsın
    GeneralReportService().generateAndPrintReport(
      allTickets,
      _userName ?? 'Kullanıcı',
    );
  }

  /// PDF raporları için sayfalama olmadan tüm ticket'ları çeker.
  String _safePdfNameSegment(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'is_emri';
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  }

  Future<void> _openTicketPdf(Map<String, dynamic> ticket) async {
    final ticketId = ticket['id']?.toString();
    if (ticketId == null || ticketId.isEmpty) return;

    final jobCode = (ticket['job_code'] as String?) ?? 'is_emri';

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PdfViewerPage(
              title: 'Is Emri PDF',
              pdfFileName:
                  '${_safePdfNameSegment(jobCode)}_${DateTime.now().toIso8601String().substring(0, 10)}.pdf',
              pdfGenerator:
                  () => PdfExportService.generateSingleTicketPdfBytes(ticketId),
            ),
      ),
    );
  }

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
    _notifOverlay?.remove();
    _notifOverlay = null;
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchTickets() async {
    final supabase = Supabase.instance.client;

    // Teknisyenler, Admin ve Manager'lar tüm işleri görebilir (draft dahil)
    final hasFullAccess =
        _userRole == 'admin' ||
        _userRole == 'manager' ||
        _userRole == 'technician';

    var query = supabase.from('tickets').select('''
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
    // .neq('status', 'done') // Biten işleri de dahil ediyoruz (filtreleme ile yönetilecek)
    ;

    // Sadece yetkisi olmayanlar (örn: pending, partner_user) draftları görmesin
    // Aslında partner_user da draft görmemeli.
    // Eğer "bütün işleri görsün" dendiğinde teknisyen kastediliyorsa, burayı açıyoruz.
    if (!hasFullAccess) {
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
            result.write(
              String.fromCharCode(codeUnit + 32),
            ); // ASCII: A=65, a=97
          } else {
            // Diğer tüm karakterleri olduğu gibi bırak (küçük harfler, rakamlar, özel karakterler)
            result.write(char);
          }
          break;
      }
    }

    return result.toString().trim();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> tickets) {
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
          final s = DateTime(
            _startDate!.year,
            _startDate!.month,
            _startDate!.day,
          );
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
        final combined =
            '$normalizedTitle $normalizedCustomerName $normalizedJobCode';

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
      case 'open':
        return 'Açık';
      case 'done':
        return 'Bitti';
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

  Color _getStatusColor(String status, bool isDark) {
    switch (status) {
      case 'open':
        return isDark ? Colors.blue.shade300 : Colors.blue.shade700;
      case 'done':
        return isDark ? Colors.green.shade300 : Colors.green.shade700;
      default:
        return Colors.grey;
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
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: theme.textTheme.bodySmall?.color,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    /*
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 900;
    
    final customer = ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final deviceBrand = ticket['device_brand'] as String?; // Partner adı cihaz markası alanında
    final status = ticket['status'] as String? ?? '';
    final priority = ticket['priority'] as String? ?? '';
    final plannedDate = ticket['planned_date'] as String?;
    final title = ticket['title'] as String? ?? 'Başlık yok';
    final jobCode = ticket['job_code'] as String? ?? '---';

    final statusColor = _getStatusColor(status, isDark);
    final accent = AppColors.corporateYellow;

    IconData leadingIcon;
    switch (status) {
      case 'done':
        leadingIcon = Icons.check_circle_outline;
        break;
      case 'in_progress':
        leadingIcon = Icons.handyman_outlined;
        break;
      case 'open':
      default:
        leadingIcon = Icons.assignment_outlined;
        break;
    }

    String plannedText = '-';
    if (plannedDate != null && plannedDate.isNotEmpty) {
      final dt = DateTime.tryParse(plannedDate);
      if (dt != null) plannedText = DateFormat('dd.MM.yyyy').format(dt);
    }

    final cardBg = isDark ? const Color(0xFF1C1F26) : Colors.white;
    final primaryText = isDark ? const Color(0xFFF9FAFB) : AppColors.textDark;
    final secondaryText = isDark ? const Color(0xFF9CA3AF) : AppColors.textLight;
    final shadowColor = Colors.black.withOpacity(isDark ? 0.45 : 0.08);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          // Base + ambient shadow
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 40,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
          ),

          // Noise / grain overlay
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: IgnorePointer(
                child: Opacity(
                  opacity: isDark ? 0.035 : 0.02,
                  child: CustomPaint(
                    painter: _ListNoisePainter(
                      seed: (ticket['id'] ?? 1).hashCode,
                      // Mobil: daha hafif, Desktop/Web: biraz daha yoğun
                      densityDivisor: isWide ? 1200 : 1800,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Inner shadow overlay (very subtle)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      // Mobil: daha "material" hissi için tek eksen
                      begin: isWide ? Alignment.topLeft : Alignment.topCenter,
                      end: isWide ? Alignment.bottomRight : Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(isDark ? 0.22 : 0.08),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.white.withOpacity(isDark ? 0.04 : 0.10),
                      ],
                      stops: const [0.0, 0.20, 0.80, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left icon (brand accent ring)
                    Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cardBg,
                        ),
                        child: Icon(leadingIcon, color: statusColor, size: 22),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title / subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: primaryText,
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (customer['name'] as String? ?? 'Müşteri bilgisi yok'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (deviceBrand != null && deviceBrand.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              deviceBrand,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryText.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),

                    const SizedBox(width: 10),

                    // Right "value" column (job code + planned)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(isDark ? 0.10 : 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: accent.withOpacity(isDark ? 0.35 : 0.25)),
                          ),
                          child: Text(
                            jobCode,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plannedText,
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Divider(color: (isDark ? Colors.white10 : Colors.black12)),
                const SizedBox(height: 10),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _TicketActionButton(
                        label: 'Detay',
                        icon: Icons.visibility_outlined,
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => TicketDetailPage(ticketId: ticket['id'].toString())))
                            .then((_) => _refresh()),
                      ),
                      const SizedBox(width: 8),
                      if (_userRole != 'partner_user' && _userRole != 'technician')
                        _TicketActionButton(
                          label: 'Düzenle',
                          icon: Icons.edit_outlined,
                          onTap: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => EditTicketPage(ticketId: ticket['id'].toString())))
                              .then((_) => _refresh()),
                        ),
                      if (_userRole != 'technician' && _userRole != 'pending' && _userRole != 'partner_user') ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.withOpacity(0.85)),
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
                                    child: const Text('Sil', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    */
    return _buildTicketCardDense(ticket);
  }

  String _statusLabelModern(String status) {
    switch (status) {
      case 'open':
        return 'Açık';
      case 'in_progress':
        return 'Devam Ediyor';
      case 'panel_done_waiting_stock':
      case 'stock_waiting':
        return 'Stok Bekliyor';
      case 'panel_done_waiting_service':
      case 'service_required':
      case 'sent_to_service':
        return 'Serviste';
      case 'done':
        return 'Bitti';
      case 'archived':
        return 'Arşiv';
      default:
        return status;
    }
  }

  String _priorityLabelModern(String priority) {
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

  Color _statusColorModern(String status, bool isDark) {
    switch (status) {
      case 'open':
        return AppColors.statusOpen;
      case 'in_progress':
        return AppColors.statusProgress;
      case 'panel_done_waiting_stock':
      case 'stock_waiting':
        return AppColors.statusStock;
      case 'panel_done_waiting_service':
      case 'service_required':
      case 'sent_to_service':
        return AppColors.statusSent;
      case 'done':
        return AppColors.statusDone;
      case 'archived':
        return AppColors.statusArchived;
      default:
        return isDark ? const Color(0xFF94A3B8) : AppColors.textLight;
    }
  }

  Color _priorityColorModern(String priority) {
    switch (priority) {
      case 'high':
        return AppColors.corporateRed;
      case 'normal':
        return AppColors.corporateYellow;
      case 'low':
        return AppColors.statusDone;
      default:
        return AppColors.textLight;
    }
  }

  Widget _buildMetaChipModern({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketInfoPill({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    required bool isDark,
  }) {
    final primaryText = isDark ? Colors.white : AppColors.textDark;
    final secondaryText =
        isDark ? const Color(0xFFB1C0CF) : AppColors.textLight;

    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF102131) : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF2B3A47) : AppColors.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: secondaryText,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCardModern({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? const Color(0xFF162533) : AppColors.surfaceWhite;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.14 : 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isDark ? const Color(0xFFB1C0CF) : AppColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketActionWrap(
    Map<String, dynamic> ticket, {
    required bool isWide,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: isWide ? WrapAlignment.end : WrapAlignment.start,
      children: [
        _TicketActionButton(
          label: 'Detay',
          icon: Icons.visibility_outlined,
          onTap:
              () => Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder:
                          (_) => TicketDetailPage(
                            ticketId: ticket['id'].toString(),
                          ),
                    ),
                  )
                  .then((_) => _refresh()),
        ),
        _TicketActionButton(
          label: 'PDF',
          icon: Icons.picture_as_pdf_outlined,
          onTap: () => _openTicketPdf(ticket),
        ),
        if (_userRole != 'partner_user' && _userRole != 'technician')
          _TicketActionButton(
            label: 'Düzenle',
            icon: Icons.edit_outlined,
            onTap:
                () => Navigator.of(context)
                    .push(
                      MaterialPageRoute(
                        builder:
                            (_) => EditTicketPage(
                              ticketId: ticket['id'].toString(),
                            ),
                      ),
                    )
                    .then((_) => _refresh()),
          ),
        if (_userRole != 'technician' &&
            _userRole != 'pending' &&
            _userRole != 'partner_user')
          _TicketActionButton(
            label: 'Sil',
            icon: Icons.delete_outline,
            danger: true,
            onTap: () {
              showDialog(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Text('Sil'),
                      content: const Text(
                        'Bu işi silmek istediğine emin misin?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('İptal'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final supabase = Supabase.instance.client;
                            await supabase
                                .from('tickets')
                                .delete()
                                .eq('id', ticket['id']);
                            if (context.mounted) {
                              _refresh();
                            }
                          },
                          child: const Text(
                            'Sil',
                            style: TextStyle(color: AppColors.corporateRed),
                          ),
                        ),
                      ],
                    ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTicketCardModern(Map<String, dynamic> ticket) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 900;

    final customer =
        ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final customerName = (customer['name'] as String?) ?? 'Müşteri bilgisi yok';
    final customerAddress = (customer['address'] as String?) ?? '';
    final deviceBrand = ticket['device_brand'] as String?;
    final status = ticket['status'] as String? ?? '';
    final priority = ticket['priority'] as String? ?? '';
    final plannedDate = ticket['planned_date'] as String?;
    final title = ticket['title'] as String? ?? 'Başlık yok';
    final jobCode = ticket['job_code'] as String? ?? '---';

    final statusColor = _statusColorModern(status, isDark);
    final priorityColor = _priorityColorModern(priority);
    final surfaceColor =
        isDark ? const Color(0xFF162533) : AppColors.surfaceWhite;
    final insetColor = isDark ? const Color(0xFF0F2233) : AppColors.surfaceSoft;
    final borderColor =
        isDark ? const Color(0xFF2B3A47) : AppColors.borderSubtle;
    final primaryText = isDark ? Colors.white : AppColors.textDark;
    final secondaryText =
        isDark ? const Color(0xFFB1C0CF) : AppColors.textLight;

    IconData leadingIcon;
    switch (status) {
      case 'done':
        leadingIcon = Icons.check_circle_outline;
        break;
      case 'in_progress':
        leadingIcon = Icons.handyman_outlined;
        break;
      default:
        leadingIcon = Icons.assignment_outlined;
        break;
    }

    String plannedText = '-';
    if (plannedDate != null && plannedDate.isNotEmpty) {
      final dt = DateTime.tryParse(plannedDate);
      if (dt != null) {
        plannedText = DateFormat('dd.MM.yyyy').format(dt);
      }
    }

    final summaryPanel = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: insetColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment:
            isWide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            'İş Kodu',
            style: TextStyle(
              color: secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            jobCode,
            style: TextStyle(
              color: primaryText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Planlanan Tarih',
            style: TextStyle(
              color: secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            plannedText,
            style: TextStyle(
              color: primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withOpacity(0.20)),
              ),
              child: Icon(leadingIcon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (deviceBrand != null && deviceBrand.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      deviceBrand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: secondaryText),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMetaChipModern(
              label: _statusLabelModern(status),
              color: statusColor,
              icon: leadingIcon,
            ),
            if (priority.isNotEmpty)
              _buildMetaChipModern(
                label: _priorityLabelModern(priority),
                color: priorityColor,
                icon: Icons.flag_outlined,
              ),
          ],
        ),
        if (customerAddress.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            customerAddress,
            maxLines: isWide ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: secondaryText, fontSize: 13, height: 1.4),
          ),
        ],
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.16 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child:
          isWide
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: content),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        summaryPanel,
                        const SizedBox(height: 14),
                        _buildTicketActionWrap(ticket, isWide: true),
                      ],
                    ),
                  ),
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  content,
                  const SizedBox(height: 14),
                  summaryPanel,
                  const SizedBox(height: 14),
                  _buildTicketActionWrap(ticket, isWide: false),
                ],
              ),
    );
  }

  Widget _buildTicketCardCompact(Map<String, dynamic> ticket) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 860;

    final customer =
        ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final customerName =
        (customer['name'] as String?) ?? 'MÃ¼ÅŸteri bilgisi yok';
    final customerAddress = (customer['address'] as String?) ?? '';
    final deviceBrand = ticket['device_brand'] as String?;
    final status = ticket['status'] as String? ?? '';
    final priority = ticket['priority'] as String? ?? '';
    final plannedDate = ticket['planned_date'] as String?;
    final title = ticket['title'] as String? ?? 'BaÅŸlÄ±k yok';
    final jobCode = ticket['job_code'] as String? ?? '---';

    final statusColor = _statusColorModern(status, isDark);
    final priorityColor = _priorityColorModern(priority);
    final surfaceColor =
        isDark ? const Color(0xFF162533) : AppColors.surfaceWhite;
    final borderColor =
        isDark ? const Color(0xFF2B3A47) : AppColors.borderSubtle;
    final primaryText = isDark ? Colors.white : AppColors.textDark;
    final secondaryText =
        isDark ? const Color(0xFFB1C0CF) : AppColors.textLight;

    IconData leadingIcon;
    switch (status) {
      case 'done':
        leadingIcon = Icons.check_circle_outline;
        break;
      case 'in_progress':
        leadingIcon = Icons.handyman_outlined;
        break;
      default:
        leadingIcon = Icons.assignment_outlined;
        break;
    }

    String plannedText = '-';
    if (plannedDate != null && plannedDate.isNotEmpty) {
      final dt = DateTime.tryParse(plannedDate);
      if (dt != null) {
        plannedText = DateFormat('dd.MM.yyyy').format(dt);
      }
    }

    final infoPills = <Widget>[
      _buildTicketInfoPill(
        label: 'Ä°ÅŸ Kodu',
        value: jobCode,
        icon: Icons.badge_outlined,
        accent: AppColors.corporateBlue,
        isDark: isDark,
      ),
      _buildTicketInfoPill(
        label: 'Plan',
        value: plannedText,
        icon: Icons.event_outlined,
        accent: AppColors.statusOpen,
        isDark: isDark,
      ),
    ];

    if (deviceBrand != null && deviceBrand.trim().isNotEmpty) {
      infoPills.add(
        _buildTicketInfoPill(
          label: 'Marka / Partner',
          value: deviceBrand.trim(),
          icon: Icons.precision_manufacturing_outlined,
          accent: AppColors.corporateYellow,
          isDark: isDark,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.14 : 0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: statusColor.withOpacity(0.20)),
                ),
                child: Icon(leadingIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: isWide ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (deviceBrand != null &&
                        deviceBrand.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        deviceBrand.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: secondaryText),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetaChipModern(
                label: _statusLabelModern(status),
                color: statusColor,
                icon: leadingIcon,
              ),
              if (priority.isNotEmpty)
                _buildMetaChipModern(
                  label: _priorityLabelModern(priority),
                  color: priorityColor,
                  icon: Icons.flag_outlined,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: infoPills),
          if (customerAddress.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: secondaryText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    customerAddress,
                    maxLines: isWide ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 12),
          _buildTicketActionWrap(ticket, isWide: false),
        ],
      ),
    );
  }

  Widget _buildTicketCardDense(Map<String, dynamic> ticket) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 1080;

    final customer =
        ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final customerName = (customer['name'] as String?) ?? 'Musteri bilgisi yok';
    final customerAddress = (customer['address'] as String?) ?? '';
    final deviceBrand = (ticket['device_brand'] as String?)?.trim();
    final status = ticket['status'] as String? ?? '';
    final priority = ticket['priority'] as String? ?? '';
    final plannedDate = ticket['planned_date'] as String?;
    final title = ticket['title'] as String? ?? 'Baslik yok';
    final jobCode = ticket['job_code'] as String? ?? '---';

    final statusColor = _statusColorModern(status, isDark);
    final priorityColor = _priorityColorModern(priority);
    final surfaceColor =
        isDark ? const Color(0xFF162533) : AppColors.surfaceWhite;
    final borderColor =
        isDark ? const Color(0xFF2B3A47) : AppColors.borderSubtle;
    final primaryText = isDark ? Colors.white : AppColors.textDark;
    final secondaryText =
        isDark ? const Color(0xFFB1C0CF) : AppColors.textLight;

    IconData leadingIcon;
    switch (status) {
      case 'done':
        leadingIcon = Icons.check_circle_outline;
        break;
      case 'in_progress':
        leadingIcon = Icons.handyman_outlined;
        break;
      default:
        leadingIcon = Icons.assignment_outlined;
        break;
    }

    String plannedText = '-';
    if (plannedDate != null && plannedDate.isNotEmpty) {
      final dt = DateTime.tryParse(plannedDate);
      if (dt != null) {
        plannedText = DateFormat('dd.MM.yyyy').format(dt);
      }
    }

    Widget buildInlineInfo({
      required IconData icon,
      required String text,
      required Color color,
    }) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final metaWrap = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildMetaChipModern(
          label: _statusLabelModern(status),
          color: statusColor,
          icon: leadingIcon,
        ),
        if (priority.isNotEmpty)
          _buildMetaChipModern(
            label: _priorityLabelModern(priority),
            color: priorityColor,
            icon: Icons.flag_outlined,
          ),
        buildInlineInfo(
          icon: Icons.badge_outlined,
          text: jobCode,
          color: AppColors.corporateBlue,
        ),
        buildInlineInfo(
          icon: Icons.event_outlined,
          text: plannedText,
          color: AppColors.statusOpen,
        ),
        if (deviceBrand != null && deviceBrand.isNotEmpty)
          buildInlineInfo(
            icon: Icons.precision_manufacturing_outlined,
            text: deviceBrand,
            color: AppColors.corporateYellow,
          ),
      ],
    );

    final detailsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: isWide ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: primaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          customerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: secondaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        metaWrap,
        if (customerAddress.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            customerAddress,
            maxLines: isWide ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: secondaryText, fontSize: 13, height: 1.3),
          ),
        ],
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.12 : 0.035),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child:
          isWide
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: statusColor.withOpacity(0.20)),
                    ),
                    child: Icon(leadingIcon, color: statusColor, size: 21),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: detailsColumn),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 210,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: _buildTicketActionWrap(ticket, isWide: true),
                    ),
                  ),
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: statusColor.withOpacity(0.20),
                          ),
                        ),
                        child: Icon(leadingIcon, color: statusColor, size: 21),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: detailsColumn),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: borderColor, height: 1),
                  const SizedBox(height: 10),
                  _buildTicketActionWrap(ticket, isWide: false),
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
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder:
                              (_) => const NewTicketPage(deviceType: 'santral'),
                        ),
                      )
                      .then((_) => _refresh());
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
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder:
                              (_) => const NewTicketPage(deviceType: 'jet_fan'),
                        ),
                      )
                      .then((_) => _refresh());
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
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder:
                              (_) => const NewTicketPage(deviceType: 'other'),
                        ),
                      )
                      .then((_) => _refresh());
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

    return AppLayout(
      currentPage: AppPage.ticketList,
      userName: _userName,
      userRole: _userRole,
      title: 'İŞ TAKİP KONTROL',
      onProfileReload: _loadUserProfile,
      actions: [
        // Bildirim Butonu
        Stack(
          key: _notifIconKey,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Bildirimler',
              onPressed: _openNotificationsDropdown,
            ),
            if (_unreadNotifications > 0)
              Positioned(
                right: 8,
                top: 8,
                child: UiBadge(text: '$_unreadNotifications'),
              ),
          ],
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'Seçenekler',
          onSelected: (value) async {
            switch (value) {
              case 'pdf_filtered':
                final tickets = await _ticketsFuture;
                final filtered = _applyFilters(tickets);
                await _createPdfReport(filtered, isFiltered: true);
                break;
              case 'pdf_all':
                // Partner kullanıcılar tüm işleri PDF alamaz
                if (_userRole == 'partner_user') break;
                final allTickets = await _fetchAllTicketsForReport();
                await _createPdfReport(allTickets, isFiltered: false);
                break;
              case 'toggle_theme':
                IsTakipApp.of(context)?.toggleTheme();
                break;
              case 'refresh':
                _refresh();
                break;
            }
          },
          itemBuilder:
              (ctx) => [
                const PopupMenuItem(
                  value: 'pdf_filtered',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('Filtrelenmiş listeyi PDF al'),
                  ),
                ),
                if (_userRole != 'partner_user')
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
      floatingActionButton:
          (_userRole == 'admin' ||
                  _userRole == 'manager' ||
                  _userRole == 'technician')
              ? FloatingActionButton.extended(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NewTicketPage()),
                  );
                  _refresh();
                },
                label: const Text('Yeni İş Emri'),
                icon: const Icon(Icons.add),
                backgroundColor: AppColors.corporateNavy,
              )
              : null,
      child: UiMaxWidth(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _ticketsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const UiLoading(message: 'Yükleniyor...');
            }
            if (snapshot.hasError) {
              return UiErrorState(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }

            final tickets = snapshot.data ?? [];
            final filtered = _applyFilters(tickets);

            final openCount =
                tickets.where((e) => e['status'] == 'open').length;
            final doneCount =
                tickets.where((e) => e['status'] == 'done').length;

            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? const Color(0xFF162533)
                                  : AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color:
                                isDark
                                    ? const Color(0xFF2B3A47)
                                    : AppColors.borderSubtle,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.16 : 0.05,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hoşgeldin,',
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    isDark
                                        ? const Color(0xFFB1C0CF)
                                        : AppColors.textLight,
                              ),
                            ),
                            Text(
                              _userName ?? user?.email ?? 'Teknisyen',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color:
                                    isDark ? Colors.white : AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // İstatistik Kartları
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildStatCardModern(
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
                                  _buildStatCardModern(
                                    title: 'Biten İşler',
                                    value: doneCount.toString(),
                                    color: Colors.green,
                                    icon: Icons.check_circle_outline,
                                    onTap: () {
                                      setState(() {
                                        _statusFilter = 'done';
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (false)
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isDark
                                              ? const Color(0xFF0F2233)
                                              : AppColors.surfaceSoft,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color:
                                            isDark
                                                ? const Color(0xFF2B3A47)
                                                : AppColors.borderSubtle,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.format_list_bulleted_rounded,
                                          size: 18,
                                          color:
                                              isDark
                                                  ? Colors.white
                                                  : AppColors.textDark,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${filtered.length} iÅŸ gÃ¶rÃ¼ntÃ¼leniyor',
                                          style: TextStyle(
                                            color:
                                                isDark
                                                    ? Colors.white
                                                    : AppColors.textDark,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed:
                                        filtered.isEmpty
                                            ? null
                                            : () async {
                                              await _createPdfReport(
                                                filtered,
                                                isFiltered: true,
                                              );
                                            },
                                    icon: const Icon(
                                      Icons.picture_as_pdf_outlined,
                                    ),
                                    label: const Text(
                                      'GÃ¶rÃ¼nen Listeyi PDF Al',
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.corporateBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                  if (_userRole != 'partner_user')
                                    OutlinedButton.icon(
                                      onPressed:
                                          tickets.isEmpty
                                              ? null
                                              : () async {
                                                final allTickets =
                                                    await _fetchAllTicketsForReport();
                                                await _createPdfReport(
                                                  allTickets,
                                                  isFiltered: false,
                                                );
                                              },
                                      icon: const Icon(
                                        Icons.inventory_2_outlined,
                                      ),
                                      label: const Text('TÃ¼m Listeyi PDF Al'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            isDark
                                                ? Colors.white
                                                : AppColors.textDark,
                                        side: BorderSide(
                                          color:
                                              isDark
                                                  ? const Color(0xFF2B3A47)
                                                  : AppColors.borderStrong,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 24),

                            // Arama ve Filtreler
                            TextField(
                              controller: _searchController,
                              keyboardType: TextInputType.text,
                              textInputAction: TextInputAction.search,
                              enableSuggestions: true,
                              autocorrect: true,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppColors.surfaceWhite,
                                hintText: 'İş veya Müşteri Ara...',
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: AppColors.textLight,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _filtersExpanded
                                        ? Icons.filter_list_off
                                        : Icons.filter_list,
                                    color: AppColors.textLight,
                                  ),
                                  onPressed:
                                      () => setState(
                                        () =>
                                            _filtersExpanded =
                                                !_filtersExpanded,
                                      ),
                                ),
                              ),
                              onChanged:
                                  (val) => setState(() => _searchText = val),
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
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'all',
                                          child: Text(
                                            'Tümü',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'open',
                                          child: Text(
                                            'Açık',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'done',
                                          child: Text(
                                            'Bitti',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                      onChanged:
                                          (val) => setState(
                                            () => _statusFilter = val!,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: _priorityFilter,
                                      decoration: const InputDecoration(
                                        labelText: 'Öncelik',
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'all',
                                          child: Text(
                                            'Tümü',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'low',
                                          child: Text(
                                            'Düşük',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'normal',
                                          child: Text(
                                            'Normal',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'high',
                                          child: Text(
                                            'Yüksek',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                      onChanged:
                                          (val) => setState(
                                            () => _priorityFilter = val!,
                                          ),
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
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _startDate == null
                                                  ? 'Seçilmedi'
                                                  : DateFormat(
                                                    'dd.MM.yyyy',
                                                  ).format(_startDate!),
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.calendar_today,
                                              size: 16,
                                            ),
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
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _endDate == null
                                                  ? 'Seçilmedi'
                                                  : DateFormat(
                                                    'dd.MM.yyyy',
                                                  ).format(_endDate!),
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.calendar_today,
                                              size: 16,
                                            ),
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
                  ),

                  // Liste
                  if (filtered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: const UiEmptyState(
                        icon: Icons.search_off,
                        title: 'Kayıt bulunamadı',
                        subtitle: 'Filtreleri temizleyip tekrar deneyin.',
                      ),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => RepaintBoundary(
                            child: _buildTicketCardModern(filtered[index]),
                          ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
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
      ),
    );
  }
}
