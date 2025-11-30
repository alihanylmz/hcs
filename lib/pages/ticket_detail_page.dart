import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

class _TicketDetailPageState extends State<TicketDetailPage> {
  final _ticketService = TicketService();
  
  Map<String, dynamic>? _ticket;
  UserProfile? _userProfile;
  bool _loading = true;
  bool _isUpdating = false;
  String? _error;
  
  // Teknisyen notları için state
  List<Map<String, dynamic>> _notes = [];
  bool _notesLoading = false;

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
    _loadTicket();
    _loadUserProfile();
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

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(
          title: 'İş Emri: ${Formatters.safeText(_ticket!['job_code'])}',
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
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        iconTheme: const IconThemeData(color: AppColors.corporateNavy),
        leadingWidth: 80, 
        leading: Row(
          children: [
            const BackButton(),
            SvgPicture.asset('assets/images/log.svg', width: 24, height: 24),
          ],
        ),
        title: const Text(
          'SERVİS DETAYI',
          style: TextStyle(
            color: AppColors.corporateNavy,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Düzenle',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditTicketPage(ticketId: widget.ticketId),
                ),
              );
              _loadTicket();
            },
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'PDF Oluştur',
            onPressed: _loading || _ticket == null ? null : _exportToPdf,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.edit_document),
            tooltip: 'İmzalar',
            onSelected: (value) {
              if (value == 'customer') {
                _openSignaturePage();
              } else if (value == 'technician') {
                _openTechnicianSignaturePage();
              }
            },
            itemBuilder: (context) {
              final hasCustomerSignature = _ticket?['signature_data'] != null;
              final hasTechnicianSignature = _ticket?['technician_signature_data'] != null;
              
              return [
                PopupMenuItem(
                  value: 'customer',
                  child: Row(
                    children: [
                      Icon(
                        hasCustomerSignature ? Icons.edit : Icons.person_outline,
                        color: AppColors.textDark,
                      ),
                      const SizedBox(width: 10),
                      Text(hasCustomerSignature ? 'Müşteri İmzası Düzenle' : 'Müşteri İmzası'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'technician',
                  child: Row(
                    children: [
                      Icon(
                        hasTechnicianSignature ? Icons.edit : Icons.badge_outlined,
                        color: AppColors.textDark,
                      ),
                      const SizedBox(width: 10),
                      Text(hasTechnicianSignature ? 'Teknisyen İmzası Düzenle' : 'Teknisyen İmzası'),
                    ],
                  ),
                ),
              ];
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Yenile',
            onPressed: _loading ? null : _loadTicket,
          ),
        ],
      ),
      body: _buildBody(),
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
    final customer = ticket['customers'] as Map<String, dynamic>? ?? {};
    final status = ticket['status'] as String? ?? 'open';
    final priority = ticket['priority'] as String? ?? 'normal';
    final plannedDate = ticket['planned_date'] as String?;
    final missingParts = ticket['missing_parts'] as String?; 
    final hasMissingParts = missingParts != null && missingParts.isNotEmpty;
    final isWide = MediaQuery.of(context).size.width > 960;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- ÜST KART: DURUM VE BAŞLIK ---
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Mavi Başlık Alanı
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: const BoxDecoration(
                        color: AppColors.corporateNavy,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(11),
                          topRight: Radius.circular(11),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'İŞ KODU: ${Formatters.safeText(ticket['job_code'])}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                              fontSize: 12,
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                Formatters.date(ticket['created_at']),
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  ticket['title'] as String? ?? 'Başlıksız İş',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              // Durum Badge'leri
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildStatusChip(
                                    _statusLabels[status] ?? status,
                                    _getStatusColor(status),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildPriorityBadge(
                                    _priorityLabels[priority] ?? priority,
                                    priority,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          // Kontrol Paneli (Dropdownlar)
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              SizedBox(
                                width: isWide ? 200 : double.infinity,
                                child: _buildDropdown(
                                  label: 'İş Durumu',
                                  value: status,
                                  items: _statusLabels,
                                  onChanged: (val) => _changeStatus(val!),
                                ),
                              ),
                              SizedBox(
                                width: isWide ? 200 : double.infinity,
                                child: _buildDropdown(
                                  label: 'Öncelik Seviyesi',
                                  value: priority,
                                  items: _priorityLabels,
                                  onChanged: (val) => _changePriority(val!),
                                ),
                              ),
                              SizedBox(
                                width: isWide ? 220 : double.infinity,
                                child: InkWell(
                                  onTap: _isUpdating ? null : _pickPlannedDate,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Planlanan Tarih',
                                              style: TextStyle(fontSize: 10, color: AppColors.textLight),
                                            ),
                                            Text(
                                              Formatters.date(plannedDate),
                                              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
                                            ),
                                          ],
                                        ),
                                        if (plannedDate != null)
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
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // --- ORTA BÖLÜM: MÜŞTERİ ve DETAYLAR ---
              if (hasMissingParts) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 24),
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
                            const Text('STOK EKSİĞİ TESPİT EDİLDİ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              'Eksik Parçalar: $missingParts',
                              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isWide ? 1 : 1,
                    child: Column(
                      children: [
                        // Müşteri Kartı
                        _buildContentCard(
                          title: 'MÜŞTERİ BİLGİLERİ',
                          icon: Icons.business,
                          children: [
                            _buildInfoRow('Müşteri Adı', customer['name'] as String?, isBold: true),
                            _buildInfoRow('Telefon', customer['phone'] as String?),
                            _buildInfoRow('Adres', customer['address'] as String?, isMultiLine: true),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Açıklama Kartı (İş Emri Açıklaması)
                        _buildContentCard(
                          title: 'İŞ EMRİ AÇIKLAMASI',
                          icon: Icons.assignment_outlined,
                          children: [
                            Builder(
                              builder: (context) {
                                final rawDesc = ticket['description'] as String? ?? 'Açıklama girilmemiş.';
                                final pdfUrl = _extractPdfUrl(rawDesc);
                                // Ekranda URL kirliliği yapmamak için description içinden linki temizliyoruz
                                final cleanDesc = rawDesc.replaceAll(RegExp(r'Ekli PDF Dosyası: https?://[^\s]+'), '').trim();
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cleanDesc.isEmpty ? 'Açıklama girilmemiş.' : cleanDesc,
                                      style: const TextStyle(color: AppColors.textDark, height: 1.5),
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
                        
                        const SizedBox(height: 24),

                        // Teknisyen Notları Kartı
                        _buildNotesCard(),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // --- TEKNİK VERİLER ---
              _buildContentCard(
                title: 'TEKNİK BİLGİLER',
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
                   const SizedBox(height: 20),
                   const Text('Güç Tüketim Değerleri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight)),
                   const SizedBox(height: 10),
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
                   const SizedBox(height: 20),
                   const Text('Donanım Kontrol Listesi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight)),
                   const SizedBox(height: 10),
                   Wrap(
                     spacing: 8,
                     runSpacing: 8,
                     children: _buildFeatureChips(ticket),
                   ),
                ],
              ),

              const SizedBox(height: 24),

              // --- İMZA BÖLÜMÜ ---
              Row(
                children: [
                  Expanded(
                    child: _buildSignatureCard(
                      title: 'MÜŞTERİ ONAYI',
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
                      title: 'TEKNİSYEN',
                      name: ticket['technician_signature_name'] != null 
                          ? '${ticket['technician_signature_name']} ${ticket['technician_signature_surname'] ?? ''}' 
                          : null,
                      date: ticket['technician_signature_date'] as String?,
                      isSigned: ticket['technician_signature_data'] != null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.note_add_outlined, color: AppColors.corporateNavy, size: 20),
                    const SizedBox(width: 10),
                    const Text(
                      'TEKNİSYEN NOTLARI',
                      style: TextStyle(
                        color: AppColors.corporateNavy,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, color: AppColors.corporateNavy),
                  onPressed: _showAddNoteDialog, // <--- Yeni Dialog Çağrısı
                  tooltip: 'Not Ekle',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_notesLoading)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_notes.isEmpty)
             Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'Henüz teknisyen notu eklenmemiş.',
                style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic, fontSize: 13),
              ),
            )
          else
            Column(
              children: _notes.asMap().entries.map((entry) {
                final index = entry.key;
                final note = entry.value;
                final date = note['created_at'] as String?;
                final profile = note['profiles'] as Map<String, dynamic>?;
                final userName = profile?['full_name'] as String? ?? '-';
                
                List<String> images = [];
                if (note['image_urls'] != null) {
                  images = List<String>.from(note['image_urls']);
                } else if (note['image_url'] != null) {
                  images.add(note['image_url']);
                }

                return Column(
                  children: [
                    if (index > 0) const Divider(height: 1, indent: 20, endIndent: 20),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                userName,
                                style: const TextStyle(
                                  fontSize: 11, 
                                  fontWeight: FontWeight.bold, 
                                  color: AppColors.corporateNavy
                                ),
                              ),
                              Text(
                                Formatters.date(date),
                                style: const TextStyle(fontSize: 10, color: AppColors.textLight),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            note['note'] as String? ?? '',
                            style: const TextStyle(color: AppColors.textDark, fontSize: 13, height: 1.4),
                          ),
                          if (images.isNotEmpty) ...[
                            const SizedBox(height: 10),
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
                                                      return const Center(child: CircularProgressIndicator(color: Colors.white));
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
                  ],
                );
              }).toList(),
            ),
        ],
      ),
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

  Widget _buildInfoRow(String label, String? value, {bool isBold = false, bool isMultiLine = false, bool isInline = false}) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.textLight, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          value, 
          style: TextStyle(
            fontSize: isBold ? 16 : 14, 
            color: AppColors.textDark, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500
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
        children: [
          Row(
            children: [
              Icon(isSigned ? Icons.check_circle : Icons.pending_outlined, 
                   size: 16, 
                   color: isSigned ? Colors.green : Colors.orange),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textLight)),
            ],
          ),
          const SizedBox(height: 8),
          if (isSigned) ...[
             Text(name ?? 'İsimsiz', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
             Text(Formatters.date(date), style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
          ] else 
             const Text('İmza Bekleniyor', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)),
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
