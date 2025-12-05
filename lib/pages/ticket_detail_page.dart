import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Yeni oluşturduğumuz modülleri import ediyoruz
import '../services/pdf_export_service.dart';
import '../services/user_service.dart';
import '../services/ticket_service.dart'; // <--- Yeni Service
import '../models/user_profile.dart';
import '../pages/edit_ticket_page.dart';
import 'signature_page.dart';
import 'pdf_viewer_page.dart';
import '../theme/app_colors.dart'; // <--- Renkler
import '../utils/formatters.dart'; // <--- Formatlayıcılar
import '../widgets/add_note_dialog.dart'; // <--- Dialog Widget

class TicketDetailPage extends StatefulWidget {
  final String ticketId;

  const TicketDetailPage({super.key, required this.ticketId});

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> with SingleTickerProviderStateMixin {
  final _ticketService = TicketService();
  
  Map<String, dynamic>? _ticket;
  UserProfile? _userProfile;
  bool _loading = true;
  bool _isUpdating = false;
  String? _error;
  
  // Teknisyen notları için state
  List<Map<String, dynamic>> _notes = [];
  bool _notesLoading = false;
  
  // Tab controller
  late TabController _tabController;

  // --- UI İÇİN SABİTLER ---
  static const Map<String, String> _statusLabels = {
    'open': 'Açık',
    'panel_done_stock': 'Panosu Yapıldı Stokta',
    'panel_done_sent': 'Panosu Yapıldı Gönderildi',
    'in_progress': 'Serviste',
    'done': 'İş Tamamlandı',
    'archived': 'Arşivde'
  };

  static const Map<String, String> _priorityLabels = {
    'low': 'Düşük Öncelik',
    'normal': 'Normal Öncelik',
    'high': 'Yüksek Öncelik',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTicket();
    _loadUserProfile();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final profile = await UserService().getCurrentUserProfile();
    if (mounted) setState(() => _userProfile = profile);
  }

  // --- VERİTABANI İŞLEMLERİ (Artık Service Kullanıyor) ---

  Future<void> _loadTicket() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _ticketService.getTicket(widget.ticketId);

      if (!mounted) return;
      setState(() {
        _ticket = data;
        if (data == null) {
          _error = 'İş bulunamadı.';
        }
      });
      
      if (data != null) {
        _loadNotes();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ticket = null;
        _error = 'Hata: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadNotes() async {
    setState(() => _notesLoading = true);
    try {
      final notes = await _ticketService.getNotes(widget.ticketId);
      
      if (mounted) {
        setState(() {
          _notes = notes;
          _notesLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Notlar yüklenirken hata: $e');
      if (mounted) setState(() => _notesLoading = false);
    }
  }

  Future<void> _showEditNoteDialog(Map<String, dynamic> note) async {
    final controller = TextEditingController(text: note['note'] as String? ?? '');

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Servis Notunu Düzenle'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Servis notunu güncelleyin',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newText = controller.text.trim();
                if (newText.isEmpty) return;
                try {
                  await _ticketService.updateNote(note['id'] as int, newText);
                  if (mounted) {
                    Navigator.of(ctx).pop();
                    await _loadNotes();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Servis notu güncellendi'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateTicketLocal(Map<String, dynamic> payload) async {
    if (!mounted) return;
    setState(() {
      _isUpdating = true;
      _error = null;
    });
    try {
      await _ticketService.updateTicket(widget.ticketId, payload);
      await _loadTicket();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Hata: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  // --- YARDIMCI METODLAR ---

  Future<void> _showAddNoteDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddNoteDialog(
        ticketId: widget.ticketId,
        onSuccess: _loadNotes, // Başarılı olunca notları yenile
      ),
    );
  }

  Future<void> _showAddPartnerNoteDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddNoteDialog(
        ticketId: widget.ticketId,
        isPartnerNote: true, // Partner notu olarak işaretle
        onSuccess: _loadNotes,
      ),
    );
  }

  Future<void> _changeStatus(String status) async {
    await _updateTicketLocal({'status': status});
  }

  Future<void> _changePriority(String priority) async {
    await _updateTicketLocal({'priority': priority});
  }

  Future<void> _pickPlannedDate() async {
    final currentIso = _ticket?['planned_date'] as String?;
    final now = DateTime.now();
    final initialDate =
        currentIso != null ? DateTime.tryParse(currentIso) ?? now : now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
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
      await _updateTicketLocal({'planned_date': picked.toIso8601String()});
    }
  }

  Future<void> _clearPlannedDate() async {
    await _updateTicketLocal({'planned_date': null});
  }

  Future<void> _exportToPdf() async {
    if (_ticket == null) return;

    // İmza kontrolü
    final hasCustomerSignature = _ticket!['signature_data'] != null;
    final hasTechnicianSignature = _ticket!['technician_signature_data'] != null;
    final hasAllSignatures = hasCustomerSignature && hasTechnicianSignature;

    // İmza eksikliği kontrolü
    if (!hasAllSignatures) {
      String message;
      if (!hasCustomerSignature && !hasTechnicianSignature) {
        // Hiç imza yok
        message = 'PDF imzaları atılmamıştır. Yine de PDF oluşturulsun mu?';
      } else {
        // Bir imza eksik
        String missingSignatures = '';
        if (!hasCustomerSignature) {
          missingSignatures = 'Müşteri İmzası';
        }
        if (!hasTechnicianSignature) {
          if (missingSignatures.isNotEmpty) {
            missingSignatures += ' ve ';
          }
          missingSignatures += 'Teknisyen İmzası';
        }
        message = 'İmza eksikleri vardır ($missingSignatures). Yine de PDF oluşturulsun mu?';
      }

      final shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 12),
              Text('İmza Uyarısı'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hayır'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.corporateNavy,
                foregroundColor: Colors.white,
              ),
              child: const Text('Evet'),
            ),
          ],
        ),
      );

      // Kullanıcı hayır dediyse iptal et
      if (shouldContinue != true) {
        return;
      }
    }

    final jobCode = Formatters.safeText(_ticket!['job_code']);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          title: 'İş Emri: $jobCode',
          pdfFileName: 'Is_Emri_$jobCode.pdf',
          pdfGenerator: () => PdfExportService.generateSingleTicketPdfBytes(widget.ticketId),
        ),
      ),
    );
  }

  Future<void> _openSignaturePage() async {
    if (_ticket == null) return;
    final customer = _ticket!['customers'] as Map<String, dynamic>? ?? {};
    
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SignaturePage(
          ticketId: widget.ticketId,
          type: SignatureType.customer,
          customerName: customer['name'],
          customerPhone: customer['phone'],
          existingSignatureData: _ticket!['signature_data'] as String?,
          existingName: _ticket!['signature_name'] as String?,
          existingSurname: _ticket!['signature_surname'] as String?,
          existingPhone: _ticket!['signature_phone'] as String?,
        ),
      ),
    );

    if (result == true) _loadTicket();
  }

  Future<void> _openTechnicianSignaturePage() async {
    if (_ticket == null) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SignaturePage(
          ticketId: widget.ticketId,
          type: SignatureType.technician,
          existingSignatureData: _ticket!['technician_signature_data'] as String?,
          existingName: _ticket!['technician_signature_name'] as String?,
          existingSurname: _ticket!['technician_signature_surname'] as String?,
        ),
      ),
    );
    if (result == true) _loadTicket();
  }

  Future<void> _launchAttachment(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Dosya açılamadı';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String? _extractPdfUrl(String? description) {
    if (description == null) return null;
    // Regex: Linkin sonundaki nokta, virgül vb. noktalama işaretlerini almaz.
    final regex = RegExp(r'Ekli PDF Dosyası: (https?://[^\s]+?)(?=[.,;:]?(\s|$))');
    final match = regex.firstMatch(description);
    return match?.group(1);
  }
  
  String _getFileNameFromUrl(String url) {
    try {
      final decodedUrl = Uri.decodeFull(url);
      final uri = Uri.parse(decodedUrl);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        String fileName = pathSegments.last;
        final regex = RegExp(r'^\d+_(.+)$');
        final match = regex.firstMatch(fileName);
        if (match != null) {
          return match.group(1) ?? fileName;
        }
        return fileName;
      }
      return 'Ekli Belge';
    } catch (e) {
      return 'Ekli Belge';
    }
  }

  // --- ARAYÜZ (BUILD METODU) ---

  @override
  Widget build(BuildContext context) {
    final isPartnerUser = _userProfile?.role == 'partner_user';
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        iconTheme: const IconThemeData(color: AppColors.corporateNavy),
        leading: const BackButton(),
      ),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget? _buildFloatingActionButton() {
    final isPartnerUser = _userProfile?.role == 'partner_user';
    final isAdminOrManager = _userProfile?.isAdmin == true || _userProfile?.isManager == true;
    final isTechnician = _userProfile?.isTechnician == true;

    // Sadece partner kullanıcıları, admin, manager ve teknisyenler not ekleyebilir
    if (!isPartnerUser && !isAdminOrManager && !isTechnician) {
      return null;
    }

    return FloatingActionButton(
      onPressed: () {
        if (isPartnerUser) {
          _showAddPartnerNoteDialog();
        } else {
          _showAddNoteDialog();
        }
      },
      backgroundColor: isPartnerUser ? Colors.purple : AppColors.corporateNavy,
      child: const Icon(Icons.add_comment, color: Colors.white),
      tooltip: isPartnerUser ? 'Partner Notu Ekle' : 'Servis Notu Ekle',
    );
  }

  // --- YENİ HEADER VE TAB YAPISI METODLARI ---
  
  Widget _buildHeaderSection(
    Map<String, dynamic> ticket,
    Map<String, dynamic> customer,
    String status,
    String priority,
    String? plannedDate,
    bool isPartnerUser,
    bool isWide,
  ) {
    return Container(
      color: AppColors.surfaceWhite,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst satır: Başlık ve Status/Priority
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sol taraf: Başlık ve bilgiler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket['title'] as String? ?? 'Başlıksız İş',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: [
                        Text(
                          Formatters.safeText(ticket['job_code']),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Text('·', style: TextStyle(color: AppColors.textLight)),
                        Text(
                          customer['name'] as String? ?? 'Müşteri Adı Yok',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Sağ taraf: Status ve Priority
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusChip(
                        _statusLabels[status] ?? status,
                        _getStatusColor(status),
                      ),
                      const SizedBox(width: 8),
                      _buildPriorityBadge(
                        _priorityLabels[priority] ?? priority,
                        priority,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Tarih bilgisi - daha kompakt
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              Text(
                'Oluşturma: ${Formatters.date(ticket['created_at'])}',
                style: const TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
              if (plannedDate != null) ...[
                const Text('·', style: TextStyle(color: AppColors.textLight, fontSize: 11)),
                Text(
                  'Planlanan: ${Formatters.date(plannedDate)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Aksiyon butonları - Wrap kullanarak responsive yap
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!isPartnerUser && _userProfile?.isTechnician != true)
                _buildHeaderActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Düzenle',
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditTicketPage(ticketId: widget.ticketId),
                      ),
                    );
                    _loadTicket();
                  },
                ),
              _buildHeaderActionButton(
                icon: Icons.print_outlined,
                label: 'PDF',
                onPressed: _loading || _ticket == null ? null : _exportToPdf,
              ),
              if (!isPartnerUser && _userProfile?.isTechnician != true)
                _buildHeaderActionButton(
                  icon: Icons.edit_document,
                  label: 'İmzalar',
                  onPressed: () => _showSignatureMenu(),
                ),
              if (_userProfile?.isTechnician == true)
                _buildHeaderActionButton(
                  icon: Icons.edit_document,
                  label: 'Teknisyen İmzası',
                  onPressed: () => _openTechnicianSignaturePage(),
                ),
              _buildHeaderActionButton(
                icon: Icons.refresh_outlined,
                label: 'Yenile',
                onPressed: _loading ? null : _loadTicket,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Durum, Öncelik, Planlanan Tarih - Multi-action bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundGrey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: isWide ? 180 : double.infinity,
                  child: _buildCompactDropdown(
                    label: 'İş Durumu',
                    value: status,
                    items: _statusLabels,
                    onChanged: isPartnerUser ? null : (val) => _changeStatus(val!),
                    isDisabled: isPartnerUser,
                  ),
                ),
                SizedBox(
                  width: isWide ? 180 : double.infinity,
                  child: _buildCompactDropdown(
                    label: 'Öncelik',
                    value: priority,
                    items: _priorityLabels,
                    onChanged: isPartnerUser ? null : (val) => _changePriority(val!),
                    isDisabled: isPartnerUser,
                  ),
                ),
                SizedBox(
                  width: isWide ? 200 : double.infinity,
                  child: InkWell(
                    onTap: isPartnerUser || _isUpdating ? null : _pickPlannedDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Opacity(
                      opacity: isPartnerUser ? 0.5 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Planlanan Tarih',
                                    style: TextStyle(fontSize: 10, color: AppColors.textLight),
                                  ),
                                  Text(
                                    Formatters.date(plannedDate) ?? 'Seçiniz',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textDark,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isPartnerUser)
                              const Icon(Icons.lock_outline, size: 18, color: AppColors.textLight)
                            else if (plannedDate != null)
                              InkWell(
                                onTap: _clearPlannedDate,
                                child: const Icon(Icons.close, size: 16, color: Colors.red),
                              )
                            else
                              const Icon(Icons.calendar_month, size: 18, color: AppColors.textLight),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: onPressed == null 
              ? AppColors.backgroundGrey 
              : AppColors.corporateNavy.withOpacity(0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: onPressed == null 
                ? Colors.grey.shade300 
                : AppColors.corporateNavy.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: onPressed == null 
                  ? AppColors.textLight 
                  : AppColors.corporateNavy,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: onPressed == null 
                    ? AppColors.textLight 
                    : AppColors.corporateNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignatureMenu() {
    final hasCustomerSignature = _ticket?['signature_data'] != null;
    final hasTechnicianSignature = _ticket?['technician_signature_data'] != null;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                hasCustomerSignature ? Icons.edit : Icons.person_outline,
                color: AppColors.corporateNavy,
              ),
              title: Text(hasCustomerSignature ? 'Müşteri İmzası Düzenle' : 'Müşteri İmzası'),
              onTap: () {
                Navigator.pop(context);
                _openSignaturePage();
              },
            ),
            ListTile(
              leading: Icon(
                hasTechnicianSignature ? Icons.edit : Icons.badge_outlined,
                color: AppColors.corporateNavy,
              ),
              title: Text(hasTechnicianSignature ? 'Teknisyen İmzası Düzenle' : 'Teknisyen İmzası'),
              onTap: () {
                Navigator.pop(context);
                _openTechnicianSignaturePage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartnerInfoBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.blue.shade200, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bu ekran görüntüleme modundadır. Değişiklik yapmak için merkez ile iletişime geçin.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockWarning(String missingParts) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stok Eksiği Tespit Edildi',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Eksik Parçalar: $missingParts',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(
    Map<String, dynamic> ticket,
    Map<String, dynamic> customer,
    String status,
    String priority,
    String? plannedDate,
    bool isPartnerUser,
    bool isWide,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Müşteri Kartı
              _buildModernContentCard(
                title: 'Müşteri Bilgileri',
                icon: Icons.business,
                children: [
                  _buildInfoRow('Müşteri Adı', customer['name'] as String?, isBold: true),
                  _buildInfoRow('Telefon', customer['phone'] as String?),
                  _buildInfoRow('Adres', customer['address'] as String?, isMultiLine: true),
                  _buildInfoRow('Partner Firma', ticket['device_brand'] as String?),
                ],
              ),
              const SizedBox(height: 20),
              // İş Açıklaması
              _buildModernContentCard(
                title: 'İş Emri Açıklaması',
                icon: Icons.assignment_outlined,
                children: [
                  Builder(
                    builder: (context) {
                      final rawDesc = ticket['description'] as String? ?? 'Açıklama girilmemiş.';
                      final pdfUrl = _extractPdfUrl(rawDesc);
                      final cleanDesc = rawDesc.replaceAll(RegExp(r'Ekli PDF Dosyası: https?://[^\s]+'), '').trim();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cleanDesc.isEmpty ? 'Açıklama girilmemiş.' : cleanDesc,
                            style: const TextStyle(color: AppColors.textDark, height: 1.5, fontSize: 14),
                          ),
                          if (pdfUrl != null) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () => _launchAttachment(pdfUrl),
                              icon: const Icon(Icons.attach_file, size: 18),
                              label: Text(
                                _getFileNameFromUrl(pdfUrl),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.corporateNavy,
                                side: const BorderSide(color: AppColors.corporateNavy),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                alignment: Alignment.centerLeft,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // İmzalar
              _buildModernContentCard(
                title: 'İmzalar',
                icon: Icons.edit_document,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSignatureCard(
                          title: 'Müşteri Onayı',
                          name: ticket['signature_name'] != null 
                              ? '${ticket['signature_name']} ${ticket['signature_surname'] ?? ''}' 
                              : null,
                          date: ticket['signature_date'] as String?,
                          isSigned: ticket['signature_data'] != null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSignatureCard(
                          title: 'Teknisyen',
                          name: ticket['technician_signature_name'] != null 
                              ? '${ticket['technician_signature_name']} ${ticket['technician_signature_surname'] ?? ''}' 
                              : null,
                          date: ticket['technician_signature_date'] as String?,
                          isSigned: ticket['technician_signature_data'] != null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: _buildNotesChatView(),
        ),
      ),
    );
  }

  Widget _buildDocumentsTab(Map<String, dynamic> ticket) {
    final rawDesc = ticket['description'] as String? ?? '';
    final pdfUrl = _extractPdfUrl(rawDesc);
    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ekli PDF - Sadece gömülü PDF göster
              if (pdfUrl != null)
                _buildModernContentCard(
                  title: 'Ekli PDF Dosyası',
                  icon: Icons.attach_file,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _launchAttachment(pdfUrl),
                      icon: const Icon(Icons.picture_as_pdf, size: 20),
                      label: Text(
                        _getFileNameFromUrl(pdfUrl),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.corporateNavy,
                        side: const BorderSide(color: AppColors.corporateNavy, width: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ],
                )
              else
                _buildModernContentCard(
                  title: 'Dokümanlar',
                  icon: Icons.folder_outlined,
                  children: [
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          'Ekli doküman bulunmamaktadır.',
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTechnicalTab(Map<String, dynamic> ticket, bool isWide) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: _buildModernContentCard(
            title: 'Teknik Bilgiler',
            icon: Icons.settings_input_component,
            children: [
              Wrap(
                spacing: 20,
                runSpacing: 10,
                children: [
                  _buildInfoRow('Cihaz Modeli', ticket['device_model'] as String?, isInline: true),
                  _buildInfoRow('Tandem', ticket['tandem'] as String?, isInline: true),
                  _buildInfoRow('Isıtıcı Kademe', ticket['isitici_kademe'] as String?, isInline: true),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Güç Tüketim Değerleri',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isWide ? 4 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _buildTechMetricBox('Aspiratör', ticket['aspirator_kw'], 'kW'),
                  _buildTechMetricBox('Vantilatör', ticket['vant_kw'], 'kW'),
                  _buildTechMetricBox('Kompresör 1', ticket['kompresor_kw_1'], 'kW'),
                  _buildTechMetricBox('Kompresör 2', ticket['kompresor_kw_2'], 'kW'),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Donanım Kontrol Listesi',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _buildFeatureChips(ticket),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.corporateNavy));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _loadTicket,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    final ticket = _ticket!;
    final isPartnerUser = _userProfile?.role == 'partner_user';
    final customer = ticket['customers'] as Map<String, dynamic>? ?? {};
    final status = ticket['status'] as String? ?? 'open';
    final priority = ticket['priority'] as String? ?? 'normal';
    final plannedDate = ticket['planned_date'] as String?;
    final missingParts = ticket['missing_parts'] as String?; 
    final hasMissingParts = missingParts != null && missingParts.isNotEmpty;
    final isWide = MediaQuery.of(context).size.width > 960;

    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return [
          // Üst Header - Servis Özeti
          SliverToBoxAdapter(
            child: _buildHeaderSection(ticket, customer, status, priority, plannedDate, isPartnerUser, isWide),
          ),
          
          // Partner kullanıcılar için info bar
          if (isPartnerUser)
            SliverToBoxAdapter(
              child: _buildPartnerInfoBar(),
            ),
          
          // Stok eksikliği uyarısı (partner kullanıcılar için gösterilmez)
          if (hasMissingParts && !isPartnerUser)
            SliverToBoxAdapter(
              child: _buildStockWarning(missingParts),
            ),
          
          // Tab Bar - Sabit kalacak
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.corporateNavy,
                unselectedLabelColor: AppColors.textLight,
                indicatorColor: AppColors.corporateNavy,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                tabs: const [
                  Tab(text: 'Detaylar'),
                  Tab(text: 'Notlar'),
                  Tab(text: 'Dokümanlar'),
                  Tab(text: 'Teknik Bilgiler'),
                ],
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(ticket, customer, status, priority, plannedDate, isPartnerUser, isWide),
          _buildNotesTab(),
          _buildDocumentsTab(ticket),
          _buildTechnicalTab(ticket, isWide),
        ],
      ),
    );
  }

  // Kurumsal notlar görünümü - Profesyonel kart yapısı
  Widget _buildNotesChatView() {
    if (_notesLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_notes.isEmpty) {
      return const SizedBox.shrink(); // Boş durumda hiçbir şey gösterme (FAB zaten var)
    }

    return Column(
      children: _notes.map((note) {
        final date = note['created_at'] as String?;
        final profile = note['profiles'] as Map<String, dynamic>?;
        final userName = profile?['full_name'] as String? ?? '-';
        final role = profile?['role'] as String?;
        final noteType = note['note_type'] as String? ?? 'service_note';
        final isPartnerNote = noteType == 'partner_note';
        final isCurrentUser = note['user_id'] == _userProfile?.id;
        final isAdminOrManager = _userProfile?.isAdmin == true || _userProfile?.isManager == true;
        final canEditNote = isCurrentUser || isAdminOrManager;
        
        String? roleLabel;
        if (role == 'technician') {
          roleLabel = 'Teknisyen';
        } else if (role == 'manager' || role == 'admin') {
          roleLabel = 'Mühendis';
        } else if (role == 'partner_user') {
          roleLabel = 'Partner';
        }
        
        List<String> images = [];
        if (note['image_urls'] != null) {
          images = List<String>.from(note['image_urls']);
        } else if (note['image_url'] != null) {
          images.add(note['image_url']);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPartnerNote ? Colors.purple.shade200 : Colors.grey.shade200,
              width: isPartnerNote ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık satırı - Kullanıcı, rol, tarih
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isPartnerNote 
                          ? Colors.purple.shade100 
                          : AppColors.corporateNavy.withOpacity(0.1),
                      child: Icon(
                        isPartnerNote ? Icons.business : Icons.person,
                        size: 18,
                        color: isPartnerNote 
                            ? Colors.purple.shade700 
                            : AppColors.corporateNavy,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Kullanıcı bilgileri
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  userName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.corporateNavy,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPartnerNote) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'PARTNER',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (roleLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                roleLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textLight,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Tarih ve düzenleme - Sağ üstte
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          Formatters.date(date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                        if (canEditNote)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: InkWell(
                              onTap: () => _showEditNoteDialog(note),
                              child: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: AppColors.corporateNavy,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Not metni
                if ((note['note'] as String? ?? '').isNotEmpty)
                  Text(
                    note['note'] as String? ?? '',
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                // Resimler
                if (images.isNotEmpty) ...[
                  if ((note['note'] as String? ?? '').isNotEmpty) const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: images.map((url) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  fullscreenDialog: true,
                                  builder: (_) => Scaffold(
                                    backgroundColor: Colors.black,
                                    appBar: AppBar(
                                      backgroundColor: Colors.black,
                                      leading: const CloseButton(color: Colors.white),
                                      elevation: 0,
                                      actions: [
                                        IconButton(
                                          icon: const Icon(Icons.open_in_browser, color: Colors.white),
                                          onPressed: () => _launchAttachment(url),
                                          tooltip: 'Tarayıcıda Aç',
                                        ),
                                      ],
                                    ),
                                    body: Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      alignment: Alignment.center,
                                      child: InteractiveViewer(
                                        panEnabled: true,
                                        boundaryMargin: const EdgeInsets.all(20),
                                        minScale: 0.1,
                                        maxScale: 4.0,
                                        child: Image.network(
                                          url,
                                          fit: BoxFit.contain,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return const Center(
                                              child: CircularProgressIndicator(color: Colors.white),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(Icons.broken_image, color: Colors.white, size: 50),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(
                                  width: 100,
                                  height: 100,
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- TASARIM YARDIMCILARI ---

  Widget _buildDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required Function(String?) onChanged,
  }) {
    final safeValue = items.containsKey(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textLight,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              hint: Text(value, style: const TextStyle(fontSize: 12)), 
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.corporateNavy),
              dropdownColor: AppColors.surfaceWhite,
              style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w500),
              items: items.entries.map((e) {
                return DropdownMenuItem(
                  value: e.key,
                  child: Text(
                    e.value,
                    style: const TextStyle(color: AppColors.textDark, fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: _isUpdating ? null : onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required Function(String?)? onChanged,
    bool isDisabled = false,
  }) {
    final safeValue = items.containsKey(value) ? value : null;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeValue,
                isExpanded: true,
                hint: Text(value, style: const TextStyle(fontSize: 12)), 
                icon: Icon(
                  isDisabled ? Icons.lock_outline : Icons.keyboard_arrow_down,
                  color: AppColors.corporateNavy,
                  size: 18,
                ),
                dropdownColor: AppColors.surfaceWhite,
                style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w500),
                items: items.entries.map((e) {
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: const TextStyle(color: AppColors.textDark, fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (_isUpdating || isDisabled) ? null : onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Row(
              children: [
                Icon(icon, color: AppColors.corporateNavy, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.corporateNavy,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernContentCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sol tarafta renkli vertical bar + başlık
          Container(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.corporateNavy, width: 4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 20, 12),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.corporateNavy, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.corporateNavy,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value, {bool isBold = false, bool isMultiLine = false, bool isInline = false}) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textLight,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value, 
          style: TextStyle(
            fontSize: isBold ? 15 : 14, 
            color: AppColors.textDark, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            height: isMultiLine ? 1.5 : 1.2,
          ),
        ),
        if (!isInline) const SizedBox(height: 16),
      ],
    );

    if (isInline) {
      return Container(
        constraints: const BoxConstraints(minWidth: 150),
        child: content,
      );
    }
    return content;
  }

  Widget _buildTechMetricBox(String label, dynamic value, String unit) {
    final valText = value == null ? '-' : value.toString();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.backgroundGrey,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600)),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                valText,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: valText == '-' ? AppColors.textLight : AppColors.corporateNavy,
                ),
              ),
              const SizedBox(width: 4),
              if (valText != '-')
                Text(unit, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFeatureChips(Map<String, dynamic> ticket) {
    final features = {
      'DX': ticket['dx'],
      'Sulu Batarya': ticket['sulu_batarya'],
      'Karışım Damper': ticket['karisim_damper'],
      'Nemlendirici': ticket['nemlendirici'],
      'Rotor': ticket['rotor'],
      'Brülör': ticket['brulor'],
    };

    if (features.values.every((v) => v != true)) {
       return [const Text('Özel donanım seçili değil.', style: TextStyle(color: AppColors.textLight, fontStyle: FontStyle.italic))];
    }

    return features.entries.map((e) {
      final isActive = e.value == true;
      if (!isActive) return const SizedBox.shrink(); 
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.corporateNavy.withOpacity(0.05),
          border: Border.all(color: AppColors.corporateNavy),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          e.key,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.corporateNavy,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSignatureCard({required String title, String? name, String? date, required bool isSigned}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isSigned ? Colors.green.shade200 : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isSigned ? Icons.check_circle : Icons.edit_document,
                size: 18,
                color: isSigned ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isSigned) ...[
            Text(
              name ?? 'İsimsiz',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.date(date),
              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ] else
            const Text(
              'İmza Bekleniyor',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPriorityBadge(String label, String priorityKey) {
    Color color;
    switch (priorityKey) {
      case 'high': color = Colors.red; break;
      case 'low': color = Colors.green; break;
      default: color = Colors.orange;
    }
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flag, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open': return AppColors.statusOpen;
      case 'panel_done_stock': return AppColors.statusStock;
      case 'panel_done_sent': return AppColors.statusSent;
      case 'in_progress': return AppColors.statusProgress;
      case 'done': return AppColors.statusDone;
      case 'archived': return AppColors.statusArchived;
      default: return Colors.black;
    }
  }
}

// TabBar için SliverPersistentHeader delegate
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.surfaceWhite,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
