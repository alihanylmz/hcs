import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';

// Yeni oluşturduğumuz modülleri import ediyoruz
import '../services/pdf_export_service.dart';
import '../services/card_service.dart';
import '../services/permission_service.dart';
import '../services/user_service.dart';
import '../services/ticket_service.dart'; // <--- Yeni Service
import '../services/stock_service.dart'; // <--- Stock Service
import '../models/card.dart';
import '../models/structured_ticket_note.dart';
import '../models/ticket_linked_team_card.dart';
import '../models/user_profile.dart';
import '../models/ticket_part.dart';
import '../models/ticket_status.dart';
import 'card_detail_page.dart';
import '../pages/edit_ticket_page.dart';
import 'team_home_page.dart';
import 'signature_page.dart';
import 'pdf_viewer_page.dart';
import 'profile_page.dart'; // <--- Eklendi
import '../theme/app_colors.dart'; // <--- Renkler
import '../utils/formatters.dart'; // <--- Formatlayıcılar
import '../widgets/add_note_dialog.dart';

class TicketDetailPage extends StatefulWidget {
  final String ticketId;

  const TicketDetailPage({super.key, required this.ticketId});

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage>
    with SingleTickerProviderStateMixin {
  final _ticketService = TicketService();
  final _cardService = CardService();
  final _stockService = StockService(); // Stock Service Eklendi

  Map<String, dynamic>? _ticket;
  UserProfile? _userProfile;
  bool _loading = true;
  bool _isUpdating = false;
  bool _isUploadingFile = false; // Supabase yükleme durumu
  bool _isHeaderExpanded = false;
  String? _error;

  bool get _canEditTicket =>
      PermissionService.hasPermission(_userProfile, AppPermission.editTicket);

  bool get _canManageWorkflow => PermissionService.hasPermission(
    _userProfile,
    AppPermission.updateTicketWorkflow,
  );

  bool get _canManageTicketSignatures => PermissionService.hasPermission(
    _userProfile,
    AppPermission.manageTicketSignatures,
  );

  bool get _canModerateTicketNotes => PermissionService.hasPermission(
    _userProfile,
    AppPermission.moderateTicketNotes,
  );

  // Teknisyen notları için state
  List<Map<String, dynamic>> _notes = [];
  bool _notesLoading = false;

  // Kullanılan Parçalar için state
  List<TicketPart> _parts = [];
  bool _partsLoading = false;
  List<TicketLinkedTeamCard> _linkedTeamCards = [];
  bool _linkedTeamCardsLoading = false;
  bool _supportsLinkedTeamCards = true;

  // Tab controller
  late TabController _tabController;

  // --- UI İÇİN SABİTLER ---
  // ignore: unused_field
  static const Map<String, String> _statusLabels = {
    'open': 'Açık',
    'panel_done_stock': 'Panosu Yapıldı Stokta',
    'panel_done_sent': 'Panosu Yapıldı Gönderildi',
    'in_progress': 'Serviste',
    'done': 'İş Tamamlandı',
    'archived': 'Arşivde',
    'cancelled': 'İptal',
  };

  static const Map<String, String> _priorityLabels = {
    'low': 'Düşük Öncelik',
    'normal': 'Normal Öncelik',
    'high': 'Yüksek Öncelik',
  };

  bool _isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color _pageBackgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  Color _surfaceColor(BuildContext context) {
    return Theme.of(context).cardColor;
  }

  Color _surfaceMutedColor(BuildContext context) {
    return _isDark(context)
        ? AppColors.surfaceDarkMuted
        : AppColors.surfaceSoft;
  }

  Color _borderColor(BuildContext context) {
    return _isDark(context) ? AppColors.borderDark : AppColors.borderSubtle;
  }

  Color _primaryTextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  Color _secondaryTextColor(BuildContext context) {
    return _isDark(context) ? AppColors.textOnDarkMuted : AppColors.textLight;
  }

  Color _actionBackgroundColor(BuildContext context, {required bool enabled}) {
    if (!enabled) {
      return _surfaceMutedColor(context);
    }
    return AppColors.surfaceAccent;
  }

  Color _corporatePanelColor(BuildContext context) {
    return _isDark(context)
        ? AppColors.surfaceDarkMuted
        : AppColors.surfaceAccent;
  }

  Color _pageAccentColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

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
        _loadParts(); // Parçaları yükle
      }

      if (data != null) {
        _loadLinkedTeamCards();
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

  Future<void> _loadParts() async {
    setState(() => _partsLoading = true);
    try {
      final parts = await _stockService.getTicketParts(widget.ticketId);
      if (mounted) {
        setState(() {
          _parts = parts;
          _partsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Parçalar yüklenirken hata: $e');
      if (mounted) setState(() => _partsLoading = false);
    }
  }

  Future<void> _loadLinkedTeamCards() async {
    setState(() => _linkedTeamCardsLoading = true);
    try {
      final supports = await _cardService.supportsLinkedTicketing();
      if (!supports) {
        if (!mounted) return;
        setState(() {
          _supportsLinkedTeamCards = false;
          _linkedTeamCards = const [];
          _linkedTeamCardsLoading = false;
        });
        return;
      }

      final cards = await _cardService.getLinkedCardsForTicket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _supportsLinkedTeamCards = true;
        _linkedTeamCards = cards;
        _linkedTeamCardsLoading = false;
      });
    } catch (e) {
      debugPrint('Takim baglantilari yuklenirken hata: $e');
      if (!mounted) return;
      setState(() {
        _linkedTeamCards = const [];
        _linkedTeamCardsLoading = false;
      });
    }
  }

  Future<void> _openLinkedTeamBoard(TicketLinkedTeamCard linkedCard) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => TeamHomePage(teamId: linkedCard.teamId),
      ),
    );
    if (!mounted) return;
    await _loadLinkedTeamCards();
  }

  Future<void> _openLinkedTeamConversation(
    TicketLinkedTeamCard linkedCard,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => TeamHomePage(teamId: linkedCard.teamId),
      ),
    );
    if (!mounted) return;
    await _loadLinkedTeamCards();
  }

  Future<void> _openLinkedTeamCard(TicketLinkedTeamCard linkedCard) async {
    try {
      final card = await _cardService.getCard(linkedCard.cardId);
      if (!mounted) return;

      final result = await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => CardDetailPage(card: card)));

      if (!mounted) return;

      if (result == 'open_conversation') {
        await _openLinkedTeamConversation(linkedCard);
        return;
      }

      if (result != null) {
        await _loadLinkedTeamCards();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kart acilamadi: $e')));
    }
  }

  Future<void> _showEditNoteDialog(Map<String, dynamic> note) async {
    final controller = TextEditingController(
      text: note['note'] as String? ?? '',
    );

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
      builder:
          (context) => AddNoteDialog(
            ticketId: widget.ticketId,
            onSuccess: _loadNotes, // Başarılı olunca notları yenile
          ),
    );
  }

  Future<void> _showAddPartnerNoteDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AddNoteDialog(
            ticketId: widget.ticketId,
            isPartnerNote: true, // Partner notu olarak işaretle
            onSuccess: _loadNotes,
          ),
    );
  }

  Future<void> _openNoteDialog({
    required bool isPartnerNote,
    AddNoteEntryMode initialMode = AddNoteEntryMode.quick,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AddNoteDialog(
            ticketId: widget.ticketId,
            isPartnerNote: isPartnerNote,
            initialMode: initialMode,
            onSuccess: _loadNotes,
          ),
    );
  }

  Future<void> _showAddPhotoDialog() async {
    await _openNoteDialog(
      isPartnerNote: _userProfile?.role == 'partner_user',
      initialMode: AddNoteEntryMode.photo,
    );
  }

  bool _canCurrentUserAddNotes() {
    if (_userProfile?.role == UserRole.partnerUser) {
      return PermissionService.hasPermission(
        _userProfile,
        AppPermission.addPartnerTicketNote,
      );
    }

    return PermissionService.hasPermission(
      _userProfile,
      AppPermission.addServiceTicketNote,
    );
  }

  Map<String, String> _availableStatusItems(String currentStatus) {
    final allowedTargets =
        TicketStatus.allowedTransitions[currentStatus] ?? <String>{};
    final visibleKeys = <String>{currentStatus, ...allowedTargets};

    return {
      for (final key in TicketStatus.orderedKeys)
        if (visibleKeys.contains(key)) key: TicketStatus.labelOf(key),
    };
  }

  Future<void> _showStatusQuickPicker(String currentStatus) async {
    if (!_canManageWorkflow) return;

    final items = _availableStatusItems(currentStatus);
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Is durumu guncelle',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              ...items.entries.map((entry) {
                final isCurrent = entry.key == currentStatus;
                return ListTile(
                  leading: Icon(
                    isCurrent ? Icons.radio_button_checked : Icons.sync_alt,
                    color:
                        isCurrent
                            ? _getStatusColor(entry.key)
                            : AppColors.corporateNavy,
                  ),
                  title: Text(entry.value),
                  subtitle: Text(TicketStatus.descriptionOf(entry.key)),
                  trailing:
                      isCurrent
                          ? const Text(
                            'Mevcut',
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                          : null,
                  onTap:
                      isCurrent
                          ? null
                          : () async {
                            Navigator.pop(context);
                            await _changeStatus(entry.key);
                          },
                );
              }),
            ],
          ),
        );
      },
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

    final userService = UserService();
    final userProfile = await userService.getCurrentUserProfile();

    // 1. TEKNİSYEN İMZASI KONTROLÜ (PROFiLDEN)
    if (userProfile?.signatureData == null) {
      final shouldGoToSetup = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Profil İmzası Eksik'),
              content: const Text(
                'PDF raporu oluşturabilmek için profilinize bir imza eklemeniz gerekmektedir. Şimdi eklemek ister misiniz?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.corporateNavy,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('İmza Ayarla'),
                ),
              ],
            ),
      );

      if (shouldGoToSetup == true) {
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfilePage()),
        );
        // Profil sayfasından döndüğünde tekrar kontrol etmek için metodu durduruyoruz
        return;
      } else {
        return; // İşlemi iptal et
      }
    }

    // 2. MÜŞTERİ İMZASI KONTROLÜ
    final hasCustomerSignature = _ticket!['signature_data'] != null;

    if (!hasCustomerSignature) {
      final shouldGoToSign = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Müşteri İmzası Eksik'),
              content: const Text(
                'Müşteri imzası atılmamış. İmza sayfasına yönlendirilsin mi?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Hayır, İmzasız Devam Et'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.corporateNavy,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('İmzaya Git'),
                ),
              ],
            ),
      );

      if (shouldGoToSign == true) {
        _openSignaturePage(); // Müşteri imzasına yönlendir
        return;
      }
    }

    // PDF oluşturma işlemi devam eder...
    final jobCode = Formatters.safeText(_ticket!['job_code']);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PdfViewerPage(
              title: 'İş Emri: $jobCode',
              pdfFileName: 'Is_Emri_$jobCode.pdf',
              pdfGenerator:
                  () => PdfExportService.generateSingleTicketPdfBytes(
                    widget.ticketId,
                    technicianSignature: userProfile?.signatureData,
                  ),
            ),
      ),
    );
  }

  Future<void> _openSignaturePage() async {
    if (_ticket == null) return;
    final customer = _ticket!['customers'] as Map<String, dynamic>? ?? {};

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => SignaturePage(
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
        builder:
            (_) => SignaturePage(
              ticketId: widget.ticketId,
              type: SignatureType.technician,
              existingSignatureData:
                  _ticket!['technician_signature_data'] as String?,
              existingName: _ticket!['technician_signature_name'] as String?,
              existingSurname:
                  _ticket!['technician_signature_surname'] as String?,
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
    final regex = RegExp(
      r'Ekli PDF Dosyası: (https?://[^\s]+?)(?=[.,;:]?(\s|$))',
    );
    final match = regex.firstMatch(description);
    return match?.group(1);
  }

  List<Map<String, String>> _extractFileLinks(String? description) {
    if (description == null) return [];
    // Format: Program Dosyası ([NAME]): [URL]
    final regex = RegExp(
      r'Program Dosyası \((.*?)\): (https?://[^\s]+?)(?=[.,;:]?(\s|$))',
    );
    final matches = regex.allMatches(description);
    return matches
        .map(
          (m) => {
            'name': m.group(1) ?? 'Bilinmeyen Dosya',
            'url': m.group(2) ?? '',
          },
        )
        .toList();
  }

  Future<void> _uploadFileToStorage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;
      final pickedFile = result.files.first;

      setState(() => _isUploadingFile = true);

      final fileUrl = await _ticketService.uploadFile(
        widget.ticketId,
        pickedFile,
      );

      if (fileUrl != null) {
        // Supabase'deki bilet açıklamasını güncelle
        final oldDesc = _ticket?['description'] as String? ?? '';
        final newLinkLine = '\nProgram Dosyası (${pickedFile.name}): $fileUrl';
        final newDesc = '$oldDesc$newLinkLine';

        await _updateTicketLocal({'description': newDesc});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dosya yüklendi.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw 'Yükleme başarısız oldu.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: _pageBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: _surfaceColor(context),
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: _primaryTextColor(context)),
        leading: const BackButton(),
        title: Text(
          'Is Detayi',
          style: theme.textTheme.titleLarge?.copyWith(
            color: _primaryTextColor(context),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: _buildModernFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ignore: unused_element
  Widget? _buildFloatingActionButton() {
    final isPartnerUser = _userProfile?.role == 'partner_user';
    // Sadece partner kullanıcıları, admin, manager ve teknisyenler not ekleyebilir
    if (!_canCurrentUserAddNotes()) {
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
      backgroundColor:
          isPartnerUser
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.primary,
      child: Icon(
        Icons.add_comment,
        color:
            isPartnerUser
                ? Theme.of(context).colorScheme.onSecondary
                : Theme.of(context).colorScheme.onPrimary,
      ),
      tooltip: isPartnerUser ? 'Partner Notu Ekle' : 'Servis Notu Ekle',
    );
  }

  // --- YENİ HEADER VE TAB YAPISI METODLARI ---

  Widget? _buildModernFloatingActionButton() {
    final isPartnerUser = _userProfile?.role == 'partner_user';
    if (!_canCurrentUserAddNotes()) {
      return null;
    }

    return FloatingActionButton(
      onPressed: () => _openNoteDialog(isPartnerNote: isPartnerUser),
      backgroundColor:
          isPartnerUser
              ? Theme.of(context).colorScheme.secondary
              : Theme.of(context).colorScheme.primary,
      child: Icon(
        Icons.add_comment,
        color:
            isPartnerUser
                ? Theme.of(context).colorScheme.onSecondary
                : Theme.of(context).colorScheme.onPrimary,
      ),
      tooltip: isPartnerUser ? 'Partner surec kaydi ekle' : 'Servis kaydi ekle',
    );
  }

  Widget _buildHeaderSection(
    Map<String, dynamic> ticket,
    Map<String, dynamic> customer,
    String status,
    String priority,
    String? plannedDate,
    bool isPartnerUser,
    bool isWide,
  ) {
    final primaryText = _primaryTextColor(context);
    final secondaryText = _secondaryTextColor(context);

    return Container(
      color: _surfaceColor(context),
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
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
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
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Text(
                          '·',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                        Text(
                          customer['name'] as String? ?? 'Müşteri Adı Yok',
                          style: TextStyle(fontSize: 13, color: secondaryText),
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
                        TicketStatus.labelOf(status),
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
                style: TextStyle(fontSize: 11, color: secondaryText),
              ),
              if (plannedDate != null) ...[
                const Text(
                  '·',
                  style: TextStyle(color: AppColors.textLight, fontSize: 11),
                ),
                Text(
                  'Planlanan: ${Formatters.date(plannedDate)}',
                  style: TextStyle(fontSize: 11, color: secondaryText),
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
              if (_canCurrentUserAddNotes())
                _buildHeaderActionButton(
                  icon: Icons.playlist_add_outlined,
                  label: isPartnerUser ? 'Partner Kaydi' : 'Not Ekle',
                  onPressed:
                      () => _openNoteDialog(isPartnerNote: isPartnerUser),
                ),
              if (_canCurrentUserAddNotes())
                _buildHeaderActionButton(
                  icon: Icons.photo_camera_back_outlined,
                  label: 'Fotograf',
                  onPressed: _showAddPhotoDialog,
                ),
              _buildHeaderActionButton(
                icon: Icons.swap_horiz_outlined,
                label: 'Durum Guncelle',
                onPressed:
                    !_canManageWorkflow
                        ? null
                        : () => _showStatusQuickPicker(status),
              ),
              _buildHeaderActionButton(
                icon: Icons.print_outlined,
                label: 'PDF',
                onPressed: _loading || _ticket == null ? null : _exportToPdf,
              ),
              if (_canEditTicket)
                _buildHeaderActionButton(
                  icon: Icons.edit_outlined,
                  label: 'Düzenle',
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => EditTicketPage(ticketId: widget.ticketId),
                      ),
                    );
                    _loadTicket();
                  },
                ),
              if (_canManageTicketSignatures)
                _buildHeaderActionButton(
                  icon: Icons.edit_document,
                  label: 'İmzalar',
                  onPressed: () => _showSignatureMenu(),
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
                    items: _availableStatusItems(status),
                    onChanged:
                        !_canManageWorkflow
                            ? null
                            : (val) => _changeStatus(val!),
                    isDisabled: !_canManageWorkflow,
                  ),
                ),
                SizedBox(
                  width: isWide ? 180 : double.infinity,
                  child: _buildCompactDropdown(
                    label: 'Öncelik',
                    value: priority,
                    items: _priorityLabels,
                    onChanged:
                        !_canManageWorkflow
                            ? null
                            : (val) => _changePriority(val!),
                    isDisabled: !_canManageWorkflow,
                  ),
                ),
                SizedBox(
                  width: isWide ? 200 : double.infinity,
                  child: InkWell(
                    onTap:
                        !_canManageWorkflow || _isUpdating
                            ? null
                            : _pickPlannedDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Opacity(
                      opacity: _canManageWorkflow ? 1 : 0.5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
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
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textLight,
                                    ),
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
                            if (!_canManageWorkflow)
                              const Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: AppColors.textLight,
                              )
                            else if (plannedDate != null)
                              InkWell(
                                onTap: _clearPlannedDate,
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.red,
                                ),
                              )
                            else
                              const Icon(
                                Icons.calendar_month,
                                size: 18,
                                color: AppColors.textLight,
                              ),
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

  Widget _buildRefinedHeaderSection(
    Map<String, dynamic> ticket,
    Map<String, dynamic> customer,
    String status,
    String priority,
    String? plannedDate,
    bool isPartnerUser,
    bool isWide,
  ) {
    final theme = Theme.of(context);
    final primaryText = _primaryTextColor(context);
    final secondaryText = _secondaryTextColor(context);
    final borderColor = _borderColor(context);
    final createdAt = Formatters.date(ticket['created_at']);
    final plannedLabel =
        plannedDate == null
            ? 'Planlama bekleniyor'
            : Formatters.date(plannedDate);
    final ownerLabel = _resolveTechnicianLabel(ticket);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Container(
            padding: EdgeInsets.all(isWide ? 24 : 18),
            decoration: BoxDecoration(
              color: _surfaceColor(context),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0E1A2A).withOpacity(0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'IS EMRI OZETI',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: secondaryText,
                                letterSpacing: 1.1,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ticket['title'] as String? ?? 'Basliksiz is',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: primaryText,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                              maxLines: _isHeaderExpanded ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${customer['name'] as String? ?? 'Musteri bilgisi yok'}  •  ${Formatters.safeText(ticket['job_code'])}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: secondaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              TicketStatus.descriptionOf(status),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: secondaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          _buildStatusChip(
                            TicketStatus.labelOf(status),
                            _getStatusColor(status),
                          ),
                          _buildPriorityBadge(
                            _priorityLabels[priority] ?? priority,
                            priority,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildHeaderInfoPanel(
                      title: 'Is kodu',
                      value: Formatters.safeText(ticket['job_code']),
                      icon: Icons.confirmation_number_outlined,
                    ),
                    _buildHeaderInfoPanel(
                      title: 'Son durum',
                      value: TicketStatus.labelOf(status),
                      icon: Icons.track_changes_outlined,
                    ),
                    _buildHeaderInfoPanel(
                      title: 'Planlanan',
                      value: plannedLabel,
                      icon: Icons.event_outlined,
                    ),
                    _buildHeaderInfoPanel(
                      title: 'Sorumlu',
                      value: ownerLabel,
                      icon: Icons.engineering_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceMutedColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isHeaderExpanded
                              ? 'Aksiyonlar ve guncelleme alanlari acik.'
                              : 'Temel ozet gorunuyor. Daha fazla kontrol icin paneli ac.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: secondaryText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed:
                            () => setState(
                              () => _isHeaderExpanded = !_isHeaderExpanded,
                            ),
                        icon: Icon(
                          _isHeaderExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: _pageAccentColor(context),
                        ),
                        label: Text(
                          _isHeaderExpanded ? 'Detayi gizle' : 'Detayi goster',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: _pageAccentColor(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState:
                      _isHeaderExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderInfoPanel(
                          title: 'Olusturma',
                          value: createdAt,
                          icon: Icons.calendar_today_outlined,
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (_canCurrentUserAddNotes())
                              _buildHeaderActionButton(
                                icon: Icons.playlist_add_outlined,
                                label:
                                    isPartnerUser
                                        ? 'Partner kaydi'
                                        : 'Not ekle',
                                onPressed:
                                    () => _openNoteDialog(
                                      isPartnerNote: isPartnerUser,
                                    ),
                              ),
                            if (_canCurrentUserAddNotes())
                              _buildHeaderActionButton(
                                icon: Icons.photo_camera_back_outlined,
                                label: 'Fotograf',
                                onPressed: _showAddPhotoDialog,
                              ),
                            _buildHeaderActionButton(
                              icon: Icons.swap_horiz_outlined,
                              label: 'Durum guncelle',
                              onPressed:
                                  !_canManageWorkflow
                                      ? null
                                      : () => _showStatusQuickPicker(status),
                            ),
                            _buildHeaderActionButton(
                              icon: Icons.print_outlined,
                              label: 'PDF',
                              onPressed:
                                  _loading || _ticket == null
                                      ? null
                                      : _exportToPdf,
                            ),
                            if (_canEditTicket)
                              _buildHeaderActionButton(
                                icon: Icons.edit_outlined,
                                label: 'Duzenle',
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder:
                                          (_) => EditTicketPage(
                                            ticketId: widget.ticketId,
                                          ),
                                    ),
                                  );
                                  _loadTicket();
                                },
                              ),
                            if (_canManageTicketSignatures)
                              _buildHeaderActionButton(
                                icon: Icons.edit_document,
                                label: 'Imzalar',
                                onPressed: _showSignatureMenu,
                              ),
                            _buildHeaderActionButton(
                              icon: Icons.refresh_outlined,
                              label: 'Yenile',
                              onPressed: _loading ? null : _loadTicket,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _corporatePanelColor(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: isWide ? 220 : double.infinity,
                                child: _buildCompactDropdown(
                                  label: 'Is durumu',
                                  value: status,
                                  items: _availableStatusItems(status),
                                  onChanged:
                                      !_canManageWorkflow
                                          ? null
                                          : (val) => _changeStatus(val!),
                                  isDisabled: !_canManageWorkflow,
                                ),
                              ),
                              SizedBox(
                                width: isWide ? 220 : double.infinity,
                                child: _buildCompactDropdown(
                                  label: 'Oncelik',
                                  value: priority,
                                  items: _priorityLabels,
                                  onChanged:
                                      !_canManageWorkflow
                                          ? null
                                          : (val) => _changePriority(val!),
                                  isDisabled: !_canManageWorkflow,
                                ),
                              ),
                              SizedBox(
                                width: isWide ? 250 : double.infinity,
                                child: InkWell(
                                  onTap:
                                      !_canManageWorkflow || _isUpdating
                                          ? null
                                          : _pickPlannedDate,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Opacity(
                                    opacity: _canManageWorkflow ? 1 : 0.55,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _surfaceColor(context),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Planlanan tarih',
                                                  style: theme
                                                      .textTheme
                                                      .labelMedium
                                                      ?.copyWith(
                                                        color: secondaryText,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  Formatters.date(
                                                        plannedDate,
                                                      ) ??
                                                      'Tarih secin',
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color: primaryText,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isPartnerUser)
                                            Icon(
                                              Icons.lock_outline,
                                              size: 18,
                                              color: secondaryText,
                                            )
                                          else if (plannedDate != null)
                                            InkWell(
                                              onTap: _clearPlannedDate,
                                              child: const Icon(
                                                Icons.close,
                                                size: 16,
                                                color: Colors.red,
                                              ),
                                            )
                                          else
                                            Icon(
                                              Icons.calendar_month_outlined,
                                              size: 18,
                                              color: secondaryText,
                                            ),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaPill({required IconData icon, required String label}) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceMutedColor(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: _primaryTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfoPanel({
    required String title,
    required String value,
    required IconData icon,
    bool isCompact = false,
  }) {
    final theme = Theme.of(context);
    final accent = _pageAccentColor(context);

    return Container(
      width: isCompact ? 240 : 184,
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isCompact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _secondaryTextColor(context),
                    fontSize: 10,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: isCompact ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _primaryTextColor(context),
                    fontSize: isCompact ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
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
    final theme = Theme.of(context);
    final accent = _pageAccentColor(context);
    final isEnabled = onPressed != null;
    final foregroundColor = isEnabled ? accent : _secondaryTextColor(context);

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color:
              isEnabled ? _surfaceColor(context) : _surfaceMutedColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEnabled ? accent.withOpacity(0.18) : _borderColor(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignatureMenu() {
    final hasCustomerSignature = _ticket?['signature_data'] != null;
    final hasTechnicianSignature =
        _ticket?['technician_signature_data'] != null;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    hasCustomerSignature ? Icons.edit : Icons.person_outline,
                    color: AppColors.corporateNavy,
                  ),
                  title: Text(
                    hasCustomerSignature
                        ? 'Müşteri İmzası Düzenle'
                        : 'Müşteri İmzası',
                  ),
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
                  title: Text(
                    hasTechnicianSignature
                        ? 'Teknisyen İmzası Düzenle'
                        : 'Teknisyen İmzası',
                  ),
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
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = _isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? accent.withOpacity(0.12) : AppColors.surfaceAccent,
        border: Border(
          bottom: BorderSide(color: accent.withOpacity(0.22), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bu ekran görüntüleme modundadır. Değişiklik yapmak için merkez ile iletişime geçin.',
              style: TextStyle(
                fontSize: 12,
                color: accent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cleanTicketDescription(String? description) {
    if (description == null || description.trim().isEmpty) {
      return 'Aciklama girilmemis.';
    }

    return description
            .replaceAll(RegExp(r'Ekli PDF DosyasÄ±: https?://[^\s]+'), '')
            .replaceAll(
              RegExp(r'Program DosyasÄ± \((.*?)\): https?://[^\s]+'),
              '',
            )
            .trim()
            .isEmpty
        ? 'Aciklama girilmemis.'
        : description
            .replaceAll(RegExp(r'Ekli PDF DosyasÄ±: https?://[^\s]+'), '')
            .replaceAll(
              RegExp(r'Program DosyasÄ± \((.*?)\): https?://[^\s]+'),
              '',
            )
            .trim();
  }

  List<String> _parseMissingParts(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(RegExp(r'[\n,;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Map<String, dynamic>? _latestNoteRecord() {
    if (_notes.isEmpty) return null;
    return _notes.last;
  }

  List<String> _extractNoteImages(Map<String, dynamic> note) {
    if (note['image_urls'] != null) {
      return List<String>.from(note['image_urls']);
    }
    if (note['image_url'] != null) {
      return [
        (note['image_url'] as String?) ?? '',
      ].where((item) => item.isNotEmpty).toList();
    }
    return const [];
  }

  int _totalNoteImageCount() {
    var total = 0;
    for (final note in _notes) {
      total += _extractNoteImages(note).length;
    }
    return total;
  }

  String _resolveTechnicianLabel(Map<String, dynamic> ticket) {
    final signedName =
        [
          ticket['technician_signature_name'],
          ticket['technician_signature_surname'],
        ].whereType<String>().join(' ').trim();
    if (signedName.isNotEmpty) return signedName;

    final latestNote = _latestNoteRecord();
    final profile = latestNote?['profiles'] as Map<String, dynamic>?;
    final latestAuthor = profile?['full_name'] as String?;
    if (latestAuthor != null && latestAuthor.trim().isNotEmpty) {
      return latestAuthor;
    }
    return 'Atanmamis';
  }

  String _buildNextStepText(
    String status,
    String? plannedDate,
    List<String> missingParts,
  ) {
    if (missingParts.isNotEmpty) {
      return 'Eksik malzemeleri tamamlayip surece tekrar kayit girin.';
    }

    switch (status) {
      case TicketStatus.draft:
        return 'Is emrini aktif duruma alip planlama yapin.';
      case TicketStatus.open:
        return plannedDate == null
            ? 'Planlanan tarihi netlestirip ekip yonlendirmesini yapin.'
            : 'Planlanan tarihte servis islemini baslatin.';
      case TicketStatus.inProgress:
        return 'Yapilan islemleri surece ekleyip sonucu netlestirin.';
      case TicketStatus.panelDoneStock:
        return 'Sevk veya montaj planini belirleyin.';
      case TicketStatus.panelDoneSent:
        return 'Teslimat sonucunu ve saha durumunu kaydedin.';
      case TicketStatus.done:
        return 'Imza ve evraklari tamamlayip arsive alin.';
      case TicketStatus.archived:
        return 'Kayit arsivde. Gerekiyorsa evraklari inceleyin.';
      case TicketStatus.cancelled:
        return 'Iptal gerekcesini surece ekleyin.';
      default:
        return TicketStatus.descriptionOf(status);
    }
  }

  Widget _buildSummaryMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              _isDark(context)
                  ? _borderColor(context)
                  : color.withOpacity(0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_isDark(context) ? 0.16 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 11,
              color: _secondaryTextColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _primaryTextColor(context),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailDisclosure({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: _primaryTextColor(context),
            ),
          ),
          children: children,
        ),
      ),
    );
  }

  // ignore: unused_element
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
                  _buildInfoRow(
                    'Müşteri Adı',
                    customer['name'] as String?,
                    isBold: true,
                  ),
                  _buildInfoRow('Telefon', customer['phone'] as String?),
                  _buildInfoRow(
                    'Adres',
                    customer['address'] as String?,
                    isMultiLine: true,
                  ),
                  _buildInfoRow(
                    'Partner Firma',
                    ticket['device_brand'] as String?,
                  ),
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
                      final rawDesc =
                          ticket['description'] as String? ??
                          'Açıklama girilmemiş.';
                      final pdfUrl = _extractPdfUrl(rawDesc);
                      final cleanDesc =
                          rawDesc
                              .replaceAll(
                                RegExp(r'Ekli PDF Dosyası: https?://[^\s]+'),
                                '',
                              )
                              .trim();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cleanDesc.isEmpty
                                ? 'Açıklama girilmemiş.'
                                : cleanDesc,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              height: 1.5,
                              fontSize: 14,
                            ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.corporateNavy,
                                side: const BorderSide(
                                  color: AppColors.corporateNavy,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
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
                          name:
                              ticket['signature_name'] != null
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
                          name:
                              ticket['technician_signature_name'] != null
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

  // ignore: unused_element
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

  // ignore: unused_element
  Widget _buildDocumentsTab(Map<String, dynamic> ticket) {
    final rawDesc = ticket['description'] as String? ?? '';
    final pdfUrl = _extractPdfUrl(rawDesc);
    final fileLinks = _extractFileLinks(rawDesc);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dosya Yükleme Butonu (Supabase)
              _buildModernContentCard(
                title: 'Dosya Yükle (Supabase)',
                icon: Icons.cloud_upload_outlined,
                children: [
                  Text(
                    'Program veya dokümanları Supabase depolama alanına yükleyip iş detayına ekleyebilirsiniz.',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isUploadingFile ? null : _uploadFileToStorage,
                      icon:
                          _isUploadingFile
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.upload_file),
                      label: Text(
                        _isUploadingFile
                            ? 'Yükleniyor...'
                            : 'Supabase\'e Yükle',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.corporateNavy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Yüklenen Dosyalar
              if (fileLinks.isNotEmpty) ...[
                _buildModernContentCard(
                  title: 'Yüklenen Dosyalar',
                  icon: Icons.terminal_outlined,
                  children:
                      fileLinks.map((link) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: OutlinedButton.icon(
                            onPressed: () => _launchAttachment(link['url']!),
                            icon: const Icon(Icons.download, size: 20),
                            label: Text(
                              link['name']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.corporateNavy,
                              side: const BorderSide(
                                color: AppColors.corporateNavy,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              alignment: Alignment.centerLeft,
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 20),
              ],

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
                        side: const BorderSide(
                          color: AppColors.corporateNavy,
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                )
              else if (fileLinks.isEmpty)
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
          child: Column(
            children: [
              // Stok Kullanımı (Yeni)
              _buildPartsSection(),
              const SizedBox(height: 20),

              _buildModernContentCard(
                title: 'Teknik Bilgiler',
                icon: Icons.settings_input_component,
                children: [
                  Wrap(
                    spacing: 20,
                    runSpacing: 10,
                    children: [
                      _buildInfoRow(
                        'Cihaz Modeli',
                        ticket['device_model'] as String?,
                        isInline: true,
                      ),
                      _buildInfoRow(
                        'Tandem',
                        ticket['tandem'] as String?,
                        isInline: true,
                      ),
                      _buildInfoRow(
                        'Isıtıcı Kademe',
                        ticket['isitici_kademe'] as String?,
                        isInline: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Güç Tüketim Değerleri',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _primaryTextColor(context),
                    ),
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
                      _buildTechMetricBox(
                        'Aspiratör',
                        ticket['aspirator_kw'],
                        'kW',
                      ),
                      _buildTechMetricBox(
                        'Vantilatör',
                        ticket['vant_kw'],
                        'kW',
                      ),
                      _buildTechMetricBox(
                        'Kompresör 1',
                        ticket['kompresor_kw_1'],
                        'kW',
                      ),
                      _buildTechMetricBox(
                        'Kompresör 2',
                        ticket['kompresor_kw_2'],
                        'kW',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Donanım Kontrol Listesi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _primaryTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildFeatureChips(ticket),
                  ),
                ],
              ), // _buildModernContentCard'ın kapanışı
            ], // Column'un kapanışı
          ),
        ),
      ),
    );
  }

  Widget _buildPartsSection() {
    if (_partsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_parts.isEmpty) {
      return _buildModernContentCard(
        title: 'Kullanılan Malzemeler',
        icon: Icons.inventory_2_outlined,
        children: [
          Text(
            'Henüz malzeme eklenmemiş.',
            style: TextStyle(color: _secondaryTextColor(context)),
          ),
        ],
      );
    }

    return _buildModernContentCard(
      title: 'Kullanılan Malzemeler',
      icon: Icons.inventory_2_outlined,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _parts.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final part = _parts[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                part.inventoryName ?? 'Bilinmeyen Ürün',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _primaryTextColor(context),
                ),
              ),
              subtitle: Text(
                part.category ?? '',
                style: TextStyle(color: _secondaryTextColor(context)),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(
                    _isDark(context) ? 0.18 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.28),
                  ),
                ),
                child: Text(
                  '${part.quantity} Adet',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _cleanDescriptionForSummary(String? description) {
    if (description == null || description.trim().isEmpty) {
      return 'Aciklama girilmemis.';
    }

    final cleaned =
        description
            .replaceAll(RegExp(r'Ekli PDF Dosyas.*?: https?://[^\s]+'), '')
            .replaceAll(RegExp(r'Program Dosyas.*?: https?://[^\s]+'), '')
            .trim();

    return cleaned.isEmpty ? 'Aciklama girilmemis.' : cleaned;
  }

  Widget _buildSummaryTab(
    Map<String, dynamic> ticket,
    Map<String, dynamic> customer,
    String status,
    String priority,
    String? plannedDate,
  ) {
    final latestNote = _latestNoteRecord();
    final latestStructuredNote = StructuredTicketNote.fromRaw(
      latestNote?['note'] as String? ?? '',
    );
    final latestAuthor =
        ((latestNote?['profiles'] as Map<String, dynamic>?)?['full_name']
            as String?) ??
        'Henuz kayit yok';
    final latestDate = latestNote?['created_at'] as String?;
    final missingParts = _parseMissingParts(ticket['missing_parts'] as String?);
    final cleanDescription = _cleanDescriptionForSummary(
      ticket['description'] as String?,
    );
    final nextStep = _buildNextStepText(status, plannedDate, missingParts);
    final technicianLabel = _resolveTechnicianLabel(ticket);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildSummaryMetricCard(
                    icon: Icons.business_outlined,
                    label: 'Musteri',
                    value: (customer['name'] as String?) ?? 'Musteri yok',
                    color: AppColors.corporateNavy,
                  ),
                  _buildSummaryMetricCard(
                    icon: Icons.engineering_outlined,
                    label: 'Sorumlu / son kayit',
                    value: technicianLabel,
                    color: AppColors.corporateYellow,
                  ),
                  _buildSummaryMetricCard(
                    icon: Icons.event_available_outlined,
                    label: 'Plan',
                    value:
                        plannedDate == null
                            ? 'Planlama bekleniyor'
                            : Formatters.date(plannedDate),
                    color: Colors.teal,
                  ),
                  _buildSummaryMetricCard(
                    icon: Icons.photo_library_outlined,
                    label: 'Surec yogunlugu',
                    value:
                        '${_notes.length} kayit, ${_totalNoteImageCount()} fotograf',
                    color: Colors.deepPurple,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildModernContentCard(
                title: 'Ariza Ozeti',
                icon: Icons.assignment_outlined,
                children: [
                  Text(
                    cleanDescription,
                    style: TextStyle(
                      color: _primaryTextColor(context),
                      height: 1.55,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusChip(
                        TicketStatus.labelOf(status),
                        _getStatusColor(status),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.corporateYellow.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _priorityLabels[priority] ?? priority,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildModernContentCard(
                title: 'Surec Ozeti',
                icon: Icons.route_outlined,
                children: [
                  _buildInfoRow(
                    'Son islem',
                    latestStructuredNote.hasAnyContent
                        ? latestStructuredNote.summary
                        : 'Henuz surec kaydi eklenmemis.',
                    isMultiLine: true,
                  ),
                  _buildInfoRow('Son guncelleyen', latestAuthor),
                  _buildInfoRow('Son guncelleme', Formatters.date(latestDate)),
                  _buildInfoRow(
                    'Bir sonraki adim',
                    nextStep,
                    isMultiLine: true,
                    isBold: true,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTeamLinksCard(),
              const SizedBox(height: 20),
              _buildModernContentCard(
                title: 'Eksik Parca ve Takip',
                icon: Icons.warning_amber_rounded,
                children: [
                  if (missingParts.isEmpty)
                    Text(
                      'Eksik parca kaydi bulunmuyor.',
                      style: TextStyle(color: _secondaryTextColor(context)),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          missingParts
                              .map(
                                (item) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.shade100,
                                    ),
                                  ),
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailDisclosure(
                title: 'Detaylari goster',
                icon: Icons.unfold_more_outlined,
                children: [
                  _buildInfoRow(
                    'Musteri adi',
                    customer['name'] as String?,
                    isBold: true,
                  ),
                  _buildInfoRow('Telefon', customer['phone'] as String?),
                  _buildInfoRow(
                    'Adres',
                    customer['address'] as String?,
                    isMultiLine: true,
                  ),
                  _buildInfoRow(
                    'Cihaz modeli',
                    ticket['device_model'] as String?,
                  ),
                  _buildInfoRow(
                    'Partner / Marka',
                    ticket['device_brand'] as String?,
                  ),
                  _buildInfoRow(
                    'Olusturma tarihi',
                    Formatters.date(ticket['created_at']),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamLinksCard() {
    return _buildModernContentCard(
      title: 'Takim Baglantilari',
      icon: Icons.groups_2_outlined,
      children: [
        Text(
          'Bu is emrine bagli ekip kartlari ve hizli gecisler burada toplanir.',
          style: TextStyle(color: _secondaryTextColor(context), height: 1.5),
        ),
        const SizedBox(height: 16),
        if (_linkedTeamCardsLoading)
          const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (!_supportsLinkedTeamCards)
          Text(
            'Takim kartlarini is emrine baglama ozelligi bu ortamda henuz etkin degil.',
            style: TextStyle(color: _secondaryTextColor(context), height: 1.5),
          )
        else if (_linkedTeamCards.isEmpty)
          Text(
            'Bu is emrine bagli takim karti bulunmuyor. Takim panosunda karti bu is emrine bagladiginda burada otomatik gorunecek.',
            style: TextStyle(color: _secondaryTextColor(context), height: 1.5),
          )
        else
          Column(
            children:
                _linkedTeamCards
                    .map(
                      (linkedCard) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildLinkedTeamCardTile(linkedCard),
                      ),
                    )
                    .toList(),
          ),
      ],
    );
  }

  Widget _buildLinkedTeamCardTile(TicketLinkedTeamCard linkedCard) {
    final theme = Theme.of(context);
    final statusColor = _cardStatusColor(linkedCard.status);
    final priorityColor = _cardPriorityColor(linkedCard.priority);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceMutedColor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(
                    _isDark(context) ? 0.20 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.group_work_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      linkedCard.teamName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      linkedCard.title,
                      style: TextStyle(
                        color: _primaryTextColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLinkedTeamChip(
                icon: Icons.view_kanban_outlined,
                label: linkedCard.boardName,
                color: AppColors.corporateBlue,
              ),
              _buildLinkedTeamChip(
                icon: Icons.sync_alt_rounded,
                label: linkedCard.status.label,
                color: statusColor,
              ),
              _buildLinkedTeamChip(
                icon: Icons.flag_outlined,
                label: linkedCard.priority.label,
                color: priorityColor,
              ),
              if ((linkedCard.assigneeName ?? '').trim().isNotEmpty)
                _buildLinkedTeamChip(
                  icon: Icons.person_outline,
                  label: linkedCard.assigneeName!,
                  color: AppColors.corporateNavy,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Son hareket: ${_formatLinkedTeamDate(linkedCard.updatedAt)}',
            style: TextStyle(color: _secondaryTextColor(context)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openLinkedTeamBoard(linkedCard),
                icon: const Icon(Icons.dashboard_outlined),
                label: const Text('Pano'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openLinkedTeamConversation(linkedCard),
                icon: const Icon(Icons.forum_outlined),
                label: const Text('Konusma'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openLinkedTeamCard(linkedCard),
                icon: const Icon(Icons.open_in_new_outlined),
                label: const Text('Karti Ac'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedTeamChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _cardStatusColor(CardStatus status) {
    switch (status) {
      case CardStatus.todo:
        return AppColors.corporateBlue;
      case CardStatus.doing:
        return const Color(0xFFF59E0B);
      case CardStatus.done:
        return const Color(0xFF10B981);
      case CardStatus.sent:
        return AppColors.corporateNavy;
    }
  }

  Color _cardPriorityColor(CardPriority priority) {
    switch (priority) {
      case CardPriority.low:
        return const Color(0xFF10B981);
      case CardPriority.normal:
        return const Color(0xFFF59E0B);
      case CardPriority.high:
        return AppColors.corporateRed;
    }
  }

  String _formatLinkedTeamDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }

  Future<void> _openImagePreview(String url) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder:
            (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                leading: const CloseButton(color: Colors.white),
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.open_in_browser,
                      color: Colors.white,
                    ),
                    onPressed: () => _launchAttachment(url),
                    tooltip: 'Tarayicida ac',
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
                    errorBuilder:
                        (context, error, stackTrace) => const Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 50,
                        ),
                  ),
                ),
              ),
            ),
      ),
    );
  }

  String? _roleLabelFor(String? role) {
    switch (role) {
      case 'user':
        return 'Kullanici';
      case 'engineer':
        return 'Muhendis';
      case 'technician':
        return 'Teknisyen';
      case 'manager':
        return 'Yonetici';
      case 'supervisor':
        return 'Supervizor';
      case 'admin':
        return 'Admin';
      case 'partner_user':
        return 'Partner';
      default:
        return null;
    }
  }

  IconData _timelineSectionIcon(String key) {
    switch (key) {
      case StructuredTicketNote.diagnosisKey:
        return Icons.search_outlined;
      case StructuredTicketNote.workPerformedKey:
        return Icons.build_outlined;
      case StructuredTicketNote.usedPartsKey:
        return Icons.inventory_2_outlined;
      case StructuredTicketNote.resultKey:
        return Icons.check_circle_outline;
      case StructuredTicketNote.additionalNoteKey:
        return Icons.sticky_note_2_outlined;
      default:
        return Icons.notes_outlined;
    }
  }

  Color _timelineSectionColor(String key) {
    switch (key) {
      case StructuredTicketNote.diagnosisKey:
        return Colors.orange;
      case StructuredTicketNote.workPerformedKey:
        return Colors.blue;
      case StructuredTicketNote.usedPartsKey:
        return Colors.teal;
      case StructuredTicketNote.resultKey:
        return Colors.green;
      case StructuredTicketNote.additionalNoteKey:
        return Colors.deepPurple;
      default:
        return AppColors.corporateNavy;
    }
  }

  Widget _buildTimelineSection(StructuredTicketNoteSection section) {
    final color = _timelineSectionColor(section.key);
    final primaryText = _primaryTextColor(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_timelineSectionIcon(section.key), size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  section.value,
                  style: TextStyle(
                    fontSize: 13,
                    color: primaryText,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessTimelineView() {
    final theme = Theme.of(context);
    final primaryText = _primaryTextColor(context);
    final secondaryText = _secondaryTextColor(context);

    if (_notesLoading) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_notes.isEmpty) {
      return _buildModernContentCard(
        title: 'Surec kaydi yok',
        icon: Icons.timeline_outlined,
        children: [
          Text(
            'Bu is emrinde henuz surec adimi kaydedilmemis.',
            style: TextStyle(color: _secondaryTextColor(context)),
          ),
          if (_canCurrentUserAddNotes()) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed:
                  () => _openNoteDialog(
                    isPartnerNote: _userProfile?.role == 'partner_user',
                  ),
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Ilk kaydi ekle'),
            ),
          ],
        ],
      );
    }

    return Column(
      children: List.generate(_notes.length, (index) {
        final note = _notes[index];
        final structured = StructuredTicketNote.fromRaw(
          note['note'] as String? ?? '',
        );
        final images = _extractNoteImages(note);
        final profile = note['profiles'] as Map<String, dynamic>?;
        final userName = profile?['full_name'] as String? ?? '-';
        final role = profile?['role'] as String?;
        final roleLabel = _roleLabelFor(role);
        final noteType = note['note_type'] as String? ?? 'service_note';
        final isPartnerNote = noteType == 'partner_note';
        final isCurrentUser = note['user_id'] == _userProfile?.id;
        final canEditNote = isCurrentUser || _canModerateTicketNotes;
        final isLast = index == _notes.length - 1;

        return Stack(
          children: [
            if (!isLast)
              Positioned(
                left: 11,
                top: 28,
                bottom: 0,
                child: Container(width: 2, color: _borderColor(context)),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  padding: const EdgeInsets.only(top: 16),
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color:
                          isPartnerNote
                              ? Colors.purple
                              : AppColors.corporateNavy,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surfaceColor(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isPartnerNote
                                ? Colors.purple.withOpacity(0.35)
                                : _borderColor(context),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            _isDark(context) ? 0.16 : 0.03,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        userName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: primaryText,
                                        ),
                                      ),
                                      if (roleLabel != null)
                                        Text(
                                          roleLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: secondaryText,
                                          ),
                                        ),
                                      if (isPartnerNote)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade50,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: const Text(
                                            'Partner',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.purple,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    Formatters.date(
                                      note['created_at'] as String?,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (canEditNote)
                              IconButton(
                                onPressed: () => _showEditNoteDialog(note),
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                tooltip: 'Duzenle',
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...structured.sections.map(_buildTimelineSection),
                        if (images.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            '${images.length} fotograf eklendi',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: secondaryText,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children:
                                  images.map((url) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: InkWell(
                                        onTap: () => _openImagePreview(url),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Image.network(
                                            url,
                                            width: 110,
                                            height: 110,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (c, e, s) => Container(
                                                  width: 110,
                                                  height: 110,
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(
                                                    Icons.broken_image,
                                                    color: Colors.grey,
                                                  ),
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
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _buildProcessTab() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModernContentCard(
                title: 'Surec akisi',
                icon: Icons.timeline_outlined,
                children: [
                  Text(
                    'Notlar ve fotograflar tek bir hikaye akisi icinde gorunur. Boylece ne yapildigi ve isin su an nerede oldugu daha rahat izlenir.',
                    style: TextStyle(
                      fontSize: 13,
                      color: _primaryTextColor(context),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusChip(
                        '${_notes.length} kayit',
                        AppColors.corporateNavy,
                      ),
                      _buildStatusChip(
                        '${_totalNoteImageCount()} fotograf',
                        Colors.deepPurple,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildProcessTimelineView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaperworkTab(Map<String, dynamic> ticket) {
    final rawDesc = ticket['description'] as String? ?? '';
    final pdfUrl = _extractPdfUrl(rawDesc);
    final fileLinks = _extractFileLinks(rawDesc);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModernContentCard(
                title: 'Imzalar',
                icon: Icons.edit_document,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSignatureCard(
                          title: 'Musteri onayi',
                          name:
                              ticket['signature_name'] != null
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
                          name:
                              ticket['technician_signature_name'] != null
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
              const SizedBox(height: 20),
              _buildModernContentCard(
                title: 'Dosya Yukle (Supabase)',
                icon: Icons.cloud_upload_outlined,
                children: [
                  Text(
                    'Program veya dokumanlari Supabase depolama alanina yukleyip is detayina ekleyebilirsiniz.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _secondaryTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isUploadingFile ? null : _uploadFileToStorage,
                      icon:
                          _isUploadingFile
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.upload_file),
                      label: Text(
                        _isUploadingFile
                            ? 'Yukleniyor...'
                            : 'Supabase\'e yukle',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (fileLinks.isNotEmpty) ...[
                _buildModernContentCard(
                  title: 'Yuklenen dosyalar',
                  icon: Icons.folder_outlined,
                  children:
                      fileLinks.map((link) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton.icon(
                            onPressed: () => _launchAttachment(link['url']!),
                            icon: const Icon(Icons.download, size: 20),
                            label: Text(
                              link['name']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                              side: const BorderSide(
                                color: AppColors.corporateNavy,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              alignment: Alignment.centerLeft,
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 20),
              ],
              if (pdfUrl != null)
                _buildModernContentCard(
                  title: 'Ekli PDF',
                  icon: Icons.picture_as_pdf_outlined,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _launchAttachment(pdfUrl),
                      icon: const Icon(Icons.picture_as_pdf, size: 20),
                      label: Text(
                        _getFileNameFromUrl(pdfUrl),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: const BorderSide(
                          color: AppColors.corporateNavy,
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                )
              else if (fileLinks.isEmpty)
                _buildModernContentCard(
                  title: 'Evraklar',
                  icon: Icons.folder_open_outlined,
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'Ekli evrak bulunmamaktadir.',
                          style: TextStyle(
                            color: _secondaryTextColor(context),
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

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      );
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
    final isWide = MediaQuery.of(context).size.width > 960;

    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return [
          // Üst Header - Servis Özeti
          SliverToBoxAdapter(
            child: _buildRefinedHeaderSection(
              ticket,
              customer,
              status,
              priority,
              plannedDate,
              isPartnerUser,
              isWide,
            ),
          ),

          // Partner kullanıcılar için info bar
          if (isPartnerUser) SliverToBoxAdapter(child: _buildPartnerInfoBar()),

          // Tab Bar - Sabit kalacak
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: false,
                dividerColor: Colors.transparent,
                splashBorderRadius: BorderRadius.circular(16),
                labelColor: Colors.white,
                unselectedLabelColor: _primaryTextColor(context),
                indicator: BoxDecoration(
                  color: _pageAccentColor(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(height: 56, text: 'Ozet'),
                  Tab(height: 56, text: 'Surec'),
                  Tab(height: 56, text: 'Evrak'),
                  Tab(height: 56, text: 'Teknik'),
                ],
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(ticket, customer, status, priority, plannedDate),
          _buildProcessTab(),
          _buildPaperworkTab(ticket),
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
      children:
          _notes.map((note) {
            final date = note['created_at'] as String?;
            final profile = note['profiles'] as Map<String, dynamic>?;
            final userName = profile?['full_name'] as String? ?? '-';
            final role = profile?['role'] as String?;
            final noteType = note['note_type'] as String? ?? 'service_note';
            final isPartnerNote = noteType == 'partner_note';
            final isCurrentUser = note['user_id'] == _userProfile?.id;
            final canEditNote = isCurrentUser || _canModerateTicketNotes;

            String? roleLabel;
            if (role == 'user') {
              roleLabel = 'Kullanici';
            } else if (role == 'engineer') {
              roleLabel = 'Muhendis';
            } else if (role == 'technician') {
              roleLabel = 'Teknisyen';
            } else if (role == 'manager') {
              roleLabel = 'Yonetici';
            } else if (role == 'supervisor') {
              roleLabel = 'Supervizor';
            } else if (role == 'admin') {
              roleLabel = 'Admin';
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
                  color:
                      isPartnerNote
                          ? Colors.purple.shade200
                          : Colors.grey.shade200,
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
                          backgroundColor:
                              isPartnerNote
                                  ? Colors.purple.shade100
                                  : AppColors.corporateNavy.withOpacity(0.1),
                          child: Icon(
                            isPartnerNote ? Icons.business : Icons.person,
                            size: 18,
                            color:
                                isPartnerNote
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
                      if ((note['note'] as String? ?? '').isNotEmpty)
                        const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              images.map((url) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          fullscreenDialog: true,
                                          builder:
                                              (_) => Scaffold(
                                                backgroundColor: Colors.black,
                                                appBar: AppBar(
                                                  backgroundColor: Colors.black,
                                                  leading: const CloseButton(
                                                    color: Colors.white,
                                                  ),
                                                  elevation: 0,
                                                  actions: [
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.open_in_browser,
                                                        color: Colors.white,
                                                      ),
                                                      onPressed:
                                                          () =>
                                                              _launchAttachment(
                                                                url,
                                                              ),
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
                                                    boundaryMargin:
                                                        const EdgeInsets.all(
                                                          20,
                                                        ),
                                                    minScale: 0.1,
                                                    maxScale: 4.0,
                                                    child: Image.network(
                                                      url,
                                                      fit: BoxFit.contain,
                                                      loadingBuilder: (
                                                        context,
                                                        child,
                                                        loadingProgress,
                                                      ) {
                                                        if (loadingProgress ==
                                                            null)
                                                          return child;
                                                        return const Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                        );
                                                      },
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) => const Icon(
                                                            Icons.broken_image,
                                                            color: Colors.white,
                                                            size: 50,
                                                          ),
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
                                        errorBuilder:
                                            (c, e, s) => Container(
                                              width: 100,
                                              height: 100,
                                              color: Colors.grey.shade200,
                                              child: const Icon(
                                                Icons.broken_image,
                                                color: Colors.grey,
                                              ),
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
    final theme = Theme.of(context);
    final safeValue = items.containsKey(value) ? value : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: _secondaryTextColor(context),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderColor(context)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              hint: Text(value, style: const TextStyle(fontSize: 12)),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: theme.colorScheme.primary,
              ),
              dropdownColor: _surfaceColor(context),
              style: TextStyle(
                color: _primaryTextColor(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              items:
                  items.entries.map((e) {
                    return DropdownMenuItem(
                      value: e.key,
                      child: Text(
                        e.value,
                        style: TextStyle(
                          color: _primaryTextColor(context),
                          fontSize: 14,
                        ),
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
    final theme = Theme.of(context);
    final safeValue = items.containsKey(value) ? value : null;

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _secondaryTextColor(context),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _surfaceColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _borderColor(context)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: safeValue,
                isExpanded: true,
                hint: Text(value, style: const TextStyle(fontSize: 12)),
                icon: Icon(
                  isDisabled ? Icons.lock_outline : Icons.keyboard_arrow_down,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                dropdownColor: _surfaceColor(context),
                style: TextStyle(
                  color: _primaryTextColor(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                items:
                    items.entries.map((e) {
                      return DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          e.value,
                          style: TextStyle(
                            color: _primaryTextColor(context),
                            fontSize: 13,
                          ),
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

  Widget _buildContentCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
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

  Widget _buildModernContentCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E1A2A).withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (kurumsal sarı aksan)
          Container(
            decoration: BoxDecoration(
              color: _corporatePanelColor(context),
              border: Border(
                left: BorderSide(color: theme.colorScheme.primary, width: 4),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(
                      _isDark(context) ? 0.16 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.24),
                    ),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: _primaryTextColor(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  'Bolum',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _secondaryTextColor(context),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.black.withOpacity(0.06)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String? value, {
    bool isBold = false,
    bool isMultiLine = false,
    bool isInline = false,
  }) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontSize: 11,
            color: _secondaryTextColor(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: isBold ? 15 : 14,
            color: _primaryTextColor(context),
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
    final theme = Theme.of(context);
    final valText = value == null ? '-' : value.toString();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: _borderColor(context)),
        borderRadius: BorderRadius.circular(8),
        color: _surfaceMutedColor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontSize: 10,
              color: _secondaryTextColor(context),
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                valText,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color:
                      valText == '-'
                          ? _secondaryTextColor(context)
                          : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              if (valText != '-')
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: _secondaryTextColor(context),
                  ),
                ),
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
      return [
        const Text(
          'Özel donanım seçili değil.',
          style: TextStyle(
            color: AppColors.textLight,
            fontStyle: FontStyle.italic,
          ),
        ),
      ];
    }

    return features.entries.map((e) {
      final isActive = e.value == true;
      if (!isActive) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(_isDark(context) ? 0.18 : 0.08),
          border: Border.all(color: Theme.of(context).colorScheme.primary),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          e.key,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSignatureCard({
    required String title,
    String? name,
    String? date,
    required bool isSigned,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isSigned ? Colors.green.withOpacity(0.35) : _borderColor(context),
        ),
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
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _primaryTextColor(context),
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
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _primaryTextColor(context),
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              Formatters.date(date),
              style: TextStyle(
                fontSize: 11,
                color: _secondaryTextColor(context),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(_isDark(context) ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String label, String priorityKey) {
    Color color;
    switch (priorityKey) {
      case 'high':
        color = AppColors.corporateRed;
        break;
      case 'low':
        color = Colors.green;
        break;
      default:
        color = AppColors.corporateYellow;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(_isDark(context) ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.statusOpen;
      case 'panel_done_stock':
        return AppColors.statusStock;
      case 'panel_done_sent':
        return AppColors.statusSent;
      case 'in_progress':
        return AppColors.statusProgress;
      case 'done':
        return AppColors.statusDone;
      case 'archived':
        return AppColors.statusArchived;
      default:
        return Colors.black;
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
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      alignment: Alignment.centerLeft,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
              ),
              boxShadow:
                  overlapsContent
                      ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                      : null,
            ),
            child: tabBar,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
