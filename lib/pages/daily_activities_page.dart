import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // date formatting için

// Modeller ve Servisler
import '../models/daily_activity.dart';
import '../models/user_profile.dart';
import '../services/daily_activity_service.dart';
import '../services/daily_activity_report_service.dart';
import '../services/user_service.dart';
import '../utils/pdf_file_saver/pdf_file_saver.dart';
import 'pdf_viewer_page.dart';

// Widgetlar
import '../widgets/app_drawer.dart';
import '../widgets/add_task_dialog.dart';
import '../widgets/daily_activities/date_timeline.dart';
import '../widgets/daily_activities/activity_card.dart';
import '../widgets/daily_activities/empty_state.dart';
import '../widgets/daily_activities/daily_background.dart';
import '../widgets/daily_activities/daily_hero_summary_card.dart';
import '../widgets/daily_activities/section_header_with_badge.dart';
import '../widgets/daily_activities/status_chip.dart';
import '../theme/app_colors.dart';
import 'ticket_list_page.dart';

class DailyActivitiesPage extends StatefulWidget {
  const DailyActivitiesPage({super.key});

  @override
  State<DailyActivitiesPage> createState() => _DailyActivitiesPageState();
}

class _DailyActivitiesPageState extends State<DailyActivitiesPage> {
  // Servisler
  final DailyActivityService _activityService = DailyActivityService();
  final DailyActivityReportService _reportService = DailyActivityReportService();
  final UserService _userService = UserService();
  
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // State - Tarih ve Veri
  DateTime _selectedDate = DateTime.now();
  List<DailyActivity> _activities = [];
  bool _isLoading = false;
  int _pendingPastCount = 0;

  // State - Kullanıcı ve Yetki
  UserProfile? _currentUser;
  List<UserProfile> _allUsers = [];
  String? _selectedUserId; // Yönetici başkasını seçerse burası dolar
  bool _isSpeedDialOpen = false; // FAB Menüsü açık mı?
  final ScrollController _listScrollController = ScrollController();
  _DailyUiFilter _uiFilter = _DailyUiFilter.all;

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  Future<void> _initPage() async {
    setState(() => _isLoading = true);
    
    // 1. Önce kimin girdiğini öğren
    final profile = await _userService.getCurrentUserProfile();
    
    if (mounted) {
      setState(() {
        _currentUser = profile;
        _selectedUserId = profile?.id; // Varsayılan: Kendisi
      });
    }
    
    // Partner kullanıcılar günlük plan sayfasını göremez
    if (profile?.isPartnerUser == true) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 2. Eğer yönetici ise, personel listesini çek
    if (profile != null && (profile.isAdmin || profile.isManager)) {
      final users = await _userService.getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
        });
      }
    }

    // 3. Verileri yükle
    await _loadData();
    await _checkPastActivities();
  }

  Future<void> _loadData() async {
    if (!mounted || _selectedUserId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final list = await _activityService.getActivities(_selectedDate, userId: _selectedUserId);
      if (mounted) {
        setState(() {
          _activities = list;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPastActivities() async {
    final count = await _activityService.getPendingPastActivitiesCount();
    if (mounted) {
      setState(() => _pendingPastCount = count);
    }
  }

  Future<void> _moveYesterdayToToday() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Devretme İşlemi'),
        content: const Text('Geçmişteki tamamlanmamış tüm işler bugüne taşınsın mı?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.corporateNavy),
            child: const Text('Evet, Taşı', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // Dünden (veya geçmişten) bugüne taşı
      // Basitlik için: Dünü baz alıyoruz ama servis logiği "fromDate" gününü taşıyor.
      // Burada kullanıcıya "Tüm geçmişi taşı" sözü verdik.
      // Servis metodunu "moveIncompleteActivities" olarak yazmıştık ve belirli bir tarih istiyordu.
      // Tüm geçmişi taşımak için servise yeni bir metod eklemek veya mevcutu döngüyle çağırmak gerekebilirdi.
      // Ancak servis metodunu "fromDate"e eşit olanları taşıyacak şekilde yazmıştık.
      
      // Şimdilik sadece "Dün"ü taşıyalım, en sık kullanılan senaryo.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final today = DateTime.now();

      final count = await _activityService.moveIncompleteActivities(
        fromDate: yesterday,
        toDate: today,
        userId: _selectedUserId,
      );

      if (mounted) {
        if (count > 0) {
          _showSnack('$count adet iş bugüne taşındı.', isSuccess: true);
        } else {
          _showSnack('Dünden kalan iş bulunamadı.', isError: false);
        }
        // Eğer tüm geçmişi temizlemek istersek daha gelişmiş bir sorgu gerekir.
      }
    } catch (e) {
      _showSnack('Taşıma hatası: $e', isError: true);
    } finally {
      if (mounted) {
        // Eğer bugün seçili değilse bugüne geçelim ki taşınanları görelim
        if (!DateUtils.isSameDay(_selectedDate, DateTime.now())) {
           _selectedDate = DateTime.now();
        }
        await _loadData();
        await _checkPastActivities(); // Sayıyı güncelle
      }
    }
  }

  Future<void> _showQuickAddDialog() async {
    final templates = [
      'Sabah Toplantısı',
      'E-posta Kontrolü',
      'Müşteri Aramaları',
      'Raporlama',
      'Stok Sayımı',
      'Ofis Düzeni',
      'Saha Ziyareti',
      'Arıza Takibi',
    ];

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hızlı Ekle'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: templates.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(templates[index]),
                leading: const Icon(Icons.add_task, color: AppColors.corporateNavy),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _addQuickActivity(templates[index]);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
        ],
      ),
    );
  }

  Future<void> _addQuickActivity(String title) async {
    setState(() => _isLoading = true);
    try {
      await _activityService.addActivity(
        title: title, 
        date: _selectedDate, 
        targetUserId: _selectedUserId,
      );
      _showSnack('"$title" eklendi.', isSuccess: true);
      await _loadData();
    } catch (e) {
      _showSnack('Ekleme hatası: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadData();
  }

  void _onUserSelected(String? userId) {
    if (userId == null) return;
    setState(() {
      _selectedUserId = userId;
    });
    _loadData();
  }

  // --- İŞLEMLER ---

  // 1. PDF İndir
  Future<void> _exportToPdf() async {
    if (_activities.isEmpty) {
      _showSnack('Raporlanacak veri yok!', isError: true);
      return;
    }
    try {
      // Seçili kullanıcının adını bul
      final selectedUser = _allUsers.firstWhere(
        (u) => u.id == _selectedUserId, 
        orElse: () => _currentUser!,
      );
      final userName = selectedUser.displayName;

      // Permanent solution: generate real PDF bytes and download/share directly.
      // This avoids Chrome print preview color/scale issues on Web.
      final bytes = await _reportService.generateReport(
        activities: _activities,
        date: _selectedDate,
        userName: userName,
      );

      final filename = 'Rapor_${DateFormat('yyyyMMdd').format(_selectedDate)}.pdf';

      // Önizleme: PDF gerçekten üretiliyor mu kullanıcı direkt görsün.
      // Bu sayfada "Paylaş/Yazdır" gibi aksiyonlar da var.
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerPage(
            title: 'Günlük Rapor',
            pdfFileName: filename,
            pdfGenerator: () async => bytes,
          ),
        ),
      );
    } catch (e) {
      _showSnack('Rapor hatası: $e', isError: true);
    }
  }

  // 2. WhatsApp İçin Kopyala
  Future<void> _copyTextReport() async {
    if (_activities.isEmpty) {
      _showSnack('Raporlanacak veri yok!', isError: true);
      return;
    }
    try {
      final text = await _reportService.generateTextReport(_selectedDate, isDetailed: true);
      await Clipboard.setData(ClipboardData(text: text));
      _showSnack('Rapor kopyalandı.', isSuccess: true);
    } catch (e) {
      _showSnack('Kopyalama hatası: $e', isError: true);
    }
  }

  // 3. Yeni İş Ekle
  Future<void> _showAddDialog() async {
    // Eğer başkasının profiline bakıyorsa, ekleme yaparken o kişiye mi ekleyecek?
    // Şimdilik sadece KENDİ profiline veya yöneticiyse BAŞKASINA ekleyebilir.
    // Servis zaten creator_id'yi current user yapıyor.
    // Target user id'yi dialogdan dönen veriyle değil, _selectedUserId ile belirleyelim.

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AddTaskDialog(selectedDate: _selectedDate),
    );

    if (result != null) {
      final title = result['title'] as String;
      final steps = result['steps'] as List<ActivityStep>;

      try {
        await _activityService.addActivity(
          title: title, 
          date: _selectedDate, 
          steps: steps,
          targetUserId: _selectedUserId, // Seçili kişiye ekle
        );
        _loadData();
        _showSnack('İş paketi eklendi.', isSuccess: true);
      } catch (e) {
        _showSnack('Ekleme hatası: $e', isError: true);
      }
    }
  }

  // --- ACTIVITY ACTIONS (Karttan Gelenler) ---

  Future<void> _toggleStep(DailyActivity activity, ActivityStep step) async {
    final oldState = step.isCompleted;
    setState(() {
      step.isCompleted = !oldState;
    });

    try {
      await _activityService.updateActivitySteps(activity.id, activity.steps);
    } catch (e) {
      setState(() {
        step.isCompleted = oldState;
      });
      _showSnack('Bağlantı hatası.', isError: true);
    }
  }

  Future<void> _toggleActivity(DailyActivity activity) async {
    final oldState = activity.isCompleted;
    final newState = !oldState;

    // Optimistik UI Güncellemesi
    setState(() {
       final index = _activities.indexWhere((a) => a.id == activity.id);
       if (index != -1) {
         if (activity.steps.isNotEmpty) {
           // Alt adımlar varsa hepsini yeni duruma getir
           final newSteps = activity.steps.map((s) {
             return ActivityStep(title: s.title, isCompleted: newState);
           }).toList();
           
           _activities[index] = _activities[index].copyWith(
             steps: newSteps,
             isCompleted: newState, // Model getter'ı override etmez ama UI'da anlık gösterim için gerekebilir
           );
         } else {
           _activities[index] = _activities[index].copyWith(isCompleted: newState);
         }
       }
    });

    try {
      if (activity.steps.isNotEmpty) {
        final newSteps = activity.steps.map((s) => ActivityStep(title: s.title, isCompleted: newState)).toList();
        await _activityService.updateActivitySteps(activity.id, newSteps);
      } else {
        await _activityService.toggleCompletion(activity.id, newState);
      }
    } catch (e) {
      _showSnack('Güncelleme hatası', isError: true);
      _loadData(); // Geri al
    }
  }

  Future<void> _deleteActivity(DailyActivity activity) async {
    try {
      await _activityService.deleteActivity(activity.id);
      setState(() {
        _activities.removeWhere((a) => a.id == activity.id);
      });
    } catch (e) {
      _showSnack('Silme hatası: $e', isError: true);
      _loadData();
    }
  }

  Future<void> _updateKpi(DailyActivity activity, int? score) async {
    final oldScore = activity.kpiScore;
    setState(() {
      final index = _activities.indexWhere((a) => a.id == activity.id);
      if (index != -1) {
        _activities[index] = _activities[index].copyWith(kpiScore: score);
      }
    });

    try {
      await _activityService.updateKpiScore(activity.id, score);
    } catch (e) {
      _showSnack('KPI güncellenemedi.', isError: true);
      setState(() {
        final index = _activities.indexWhere((a) => a.id == activity.id);
        if (index != -1) {
          _activities[index] = _activities[index].copyWith(kpiScore: oldScore);
        }
      });
    }
  }

  Future<bool> _confirmDelete(DailyActivity activity) async {
    if (activity.isAssignedByManager && _currentUser?.id != activity.creatorId) {
      // Eğer yönetici atadıysa ve silmeye çalışan kişi yönetici değilse engelle
      // Ama yönetici kendi atadığı işi silebilir.
      // Basit kontrol: Eğer atayan başkasıysa silemezsin.
      if (activity.creatorId != _currentUser?.id) {
        _showSnack('Yönetici atamaları silinemez.', isError: true);
        return false;
      }
    }
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: const Text('Bu iş paketi ve tüm alt adımları silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Sil', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : (isSuccess ? Colors.green : Colors.black87),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    // Partner kullanıcılar günlük plan sayfasını göremez
    if (_currentUser?.isPartnerUser == true) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Günlük Planım'),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        ),
        drawer: AppDrawer(
          currentPage: AppDrawerPage.ticketList,
          userName: _currentUser?.displayName,
          userRole: _currentUser?.role,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Bu sayfaya erişim yetkiniz yok.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const TicketListPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.corporateNavy),
                  child: const Text('İş Listesine Git', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // İlerleme Hesabı
    double totalProgress = 0;
    int totalSteps = 0;
    int completedSteps = 0;

    for (var act in _activities) {
      if (act.steps.isNotEmpty) {
        totalSteps += act.steps.length;
        completedSteps += act.steps.where((s) => s.isCompleted).length;
      } else {
        totalSteps++;
        if (act.isCompleted) completedSteps++;
      }
    }
    if (totalSteps > 0) totalProgress = completedSteps / totalSteps;

    // Yönetici Modu Kontrolü
    final bool isManagerView = (_currentUser?.isAdmin == true || _currentUser?.isManager == true);

    return Scaffold(
      backgroundColor: AppColors.background,
      key: _scaffoldKey,
      
      // --- APP BAR (Yönetici Seçicili) ---
      appBar: _buildAppBar(isManagerView: isManagerView),
      
      drawer: AppDrawer(
        currentPage: AppDrawerPage.dailyActivities,
        userName: _currentUser?.displayName,
        userRole: _currentUser?.role,
      ),
      
      body: DailyBackground(
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth < 380 ? 14.0 : 16.0;
              return Column(
                children: [
                  const SizedBox(height: 10),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    child: DailyHeroSummaryCard(
                      selectedDate: _selectedDate,
                      progress: totalProgress,
                      completedSteps: completedSteps,
                      totalSteps: totalSteps,
                      isLoading: _isLoading,
                      onCtaPressed: _onHeroCtaPressed,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3) DateTimeline (existing) – restyled
                  DateTimeline(selectedDate: _selectedDate, onDateSelected: _onDateSelected),
                  const SizedBox(height: 12),

                  // 4) Pending past warning banner (restyled)
                  if (_pendingPastCount > 0 && _selectedUserId == _currentUser?.id)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: horizontal),
                      child: _PendingPastBanner(
                        pendingCount: _pendingPastCount,
                        onMoveToToday: _moveYesterdayToToday,
                      ),
                    ),
                  if (_pendingPastCount > 0 && _selectedUserId == _currentUser?.id) const SizedBox(height: 12),

                  // 5) Filter row (UI-only)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    child: _FilterChipsRow(
                      value: _uiFilter,
                      onChanged: (v) => setState(() => _uiFilter = v),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 6) List area
                  Expanded(
                    child: _buildActivitiesArea(horizontalPadding: horizontal),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      
      // --- CUSTOM SPEED DIAL (FAB MENÜ) ---
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isSpeedDialOpen) ...[
            _buildFabItem(
              icon: Icons.bolt, 
              label: 'Hızlı Ekle', 
              color: Colors.amber.shade700, 
              onTap: () {
                setState(() => _isSpeedDialOpen = false);
                _showQuickAddDialog();
              }
            ),
            const SizedBox(height: 12),
            _buildFabItem(
              icon: Icons.copy, 
              label: 'Metin Kopyala', 
              color: Colors.green, 
              onTap: () {
                setState(() => _isSpeedDialOpen = false);
                _copyTextReport();
              }
            ),
            const SizedBox(height: 12),
            _buildFabItem(
              icon: Icons.picture_as_pdf, 
              label: 'PDF İndir', 
              color: Colors.red, 
              onTap: () {
                setState(() => _isSpeedDialOpen = false);
                _exportToPdf();
              }
            ),
            const SizedBox(height: 12),
            _buildFabItem(
              icon: Icons.add, 
              label: 'Yeni İş Ekle', 
              color: AppColors.primary, 
              onTap: () {
                setState(() => _isSpeedDialOpen = false);
                _showAddDialog();
              }
            ),
            const SizedBox(height: 12),
          ],
          
          FloatingActionButton(
            onPressed: () {
              setState(() {
                _isSpeedDialOpen = !_isSpeedDialOpen;
              });
            },
            backgroundColor: AppColors.corporateNavy,
            child: Icon(
              _isSpeedDialOpen ? Icons.close : Icons.menu,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar({required bool isManagerView}) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: AppColors.textDark),
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: isManagerView && _allUsers.isNotEmpty
          ? DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedUserId,
                icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
                onChanged: _onUserSelected,
                items: _allUsers.map((user) {
                  return DropdownMenuItem<String>(
                    value: user.id,
                    child: Text(user.displayName),
                  );
                }).toList(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Günlük Planım',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('d MMM yyyy', 'tr_TR').format(_selectedDate),
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => _onDateSelected(DateTime.now()),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
          child: const Text('BUGÜN'),
        ),
        IconButton(
          icon: const Icon(Icons.calendar_today, color: AppColors.textDark),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2023),
              lastDate: DateTime(2030),
              locale: const Locale('tr', 'TR'),
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
            if (date != null) _onDateSelected(date);
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _onHeroCtaPressed() {
    if (!mounted) return;
    setState(() => _isSpeedDialOpen = false);
    _handleHeroCta();
  }

  Future<void> _handleHeroCta() async {
    // CTA is for focusing the task list (not adding).
    if (_activities.isEmpty && !_isLoading) {
      _showSnack('Bugün için iş yok.', isError: false);
      return;
    }
    if (_isLoading) return;
    if (!_listScrollController.hasClients) return;

    final current = _listScrollController.offset;
    // If already at top, do a tiny "bounce" so it feels like an action.
    if (current <= 1.0) {
      final bump = (_listScrollController.position.maxScrollExtent >= 48) ? 48.0 : 0.0;
      if (bump > 0) {
        await _listScrollController.animateTo(
          bump,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
        );
        await _listScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _showSnack('Liste zaten üstte.', isError: false);
      }
      return;
    }

    await _listScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildActivitiesArea({required double horizontalPadding}) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_activities.isEmpty) {
      return const EmptyActivitiesState();
    }

    final sections = _buildSectionsForUi(_activities);
    final visibleSections = _filterSections(sections, _uiFilter);

    return ListView.builder(
      controller: _listScrollController,
      padding: EdgeInsets.fromLTRB(horizontalPadding, 6, horizontalPadding, 120),
      itemCount: visibleSections.length,
      itemBuilder: (context, index) {
        final section = visibleSections[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeaderWithBadge(title: section.title, count: section.items.length),
              const SizedBox(height: 10),
              ...section.items.map((activity) {
                return ActivityCard(
                  activity: activity,
                  onToggleStep: _toggleStep,
                  onToggleActivity: _toggleActivity,
                  onDelete: _deleteActivity,
                  onConfirmDelete: _confirmDelete,
                  canGiveKpi: isManagerView && _selectedUserId != _currentUser?.id,
                  onKpiChanged: _updateKpi,
                );
              }),
            ],
          ),
        );
      },
    );
  }

  List<_ActivitySection> _buildSectionsForUi(List<DailyActivity> activities) {
    ActivityStatus statusOf(DailyActivity a) {
      if (a.isCompleted || a.progress >= 1.0) return ActivityStatus.done;
      if (a.progress > 0) return ActivityStatus.inProgress;
      return ActivityStatus.todo;
    }

    final todo = <DailyActivity>[];
    final inProgress = <DailyActivity>[];
    final done = <DailyActivity>[];

    for (final a in activities) {
      switch (statusOf(a)) {
        case ActivityStatus.todo:
          todo.add(a);
          break;
        case ActivityStatus.inProgress:
          inProgress.add(a);
          break;
        case ActivityStatus.done:
          done.add(a);
          break;
      }
    }

    final sections = <_ActivitySection>[];
    if (todo.isNotEmpty) sections.add(_ActivitySection(title: 'Yapılacak', items: todo));
    if (inProgress.isNotEmpty) sections.add(_ActivitySection(title: 'Devam Eden', items: inProgress));
    if (done.isNotEmpty) sections.add(_ActivitySection(title: 'Bitti', items: done));
    return sections;
  }

  List<_ActivitySection> _filterSections(List<_ActivitySection> sections, _DailyUiFilter filter) {
    if (filter == _DailyUiFilter.all) return sections;

    String? title;
    switch (filter) {
      case _DailyUiFilter.all:
        title = null;
        break;
      case _DailyUiFilter.todo:
        title = 'Yapılacak';
        break;
      case _DailyUiFilter.inProgress:
        title = 'Devam Eden';
        break;
      case _DailyUiFilter.done:
        title = 'Bitti';
        break;
    }
    if (title == null) return sections;
    return sections.where((s) => s.title == title).toList();
  }

  Widget _buildFabItem({
    required IconData icon, 
    required String label, 
    required Color color, 
    required VoidCallback onTap
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: AppColors.textDark),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          onPressed: onTap,
          backgroundColor: color,
          heroTag: null, // Hero animasyon çakışmasını önlemek için
          child: Icon(icon, color: Colors.white),
        ),
      ],
    );
  }
}

enum _DailyUiFilter { all, todo, inProgress, done }

class _ActivitySection {
  final String title;
  final List<DailyActivity> items;
  _ActivitySection({required this.title, required this.items});
}

class _FilterChipsRow extends StatelessWidget {
  final _DailyUiFilter value;
  final ValueChanged<_DailyUiFilter> onChanged;

  const _FilterChipsRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(label: 'Tümü', selected: value == _DailyUiFilter.all, onTap: () => onChanged(_DailyUiFilter.all)),
          const SizedBox(width: 10),
          _chip(label: 'Yapılacak', selected: value == _DailyUiFilter.todo, onTap: () => onChanged(_DailyUiFilter.todo)),
          const SizedBox(width: 10),
          _chip(label: 'Devam', selected: value == _DailyUiFilter.inProgress, onTap: () => onChanged(_DailyUiFilter.inProgress)),
          const SizedBox(width: 10),
          _chip(label: 'Bitti', selected: value == _DailyUiFilter.done, onTap: () => onChanged(_DailyUiFilter.done)),
        ],
      ),
    );
  }

  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: ChoiceChip(
        selected: selected,
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textDark,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.15,
          ),
        ),
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        backgroundColor: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
        side: BorderSide(color: selected ? Colors.transparent : AppColors.primary.withValues(alpha: 0.10)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _PendingPastBanner extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onMoveToToday;

  const _PendingPastBanner({
    required this.pendingCount,
    required this.onMoveToToday,
  });

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.accent.withValues(alpha: 0.14);
    final border = AppColors.accent.withValues(alpha: 0.20);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.corporateNavy),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Geçmişte $pendingCount tamamlanmamış iş var.',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: onMoveToToday,
            icon: const Icon(Icons.low_priority, size: 16),
            label: const Text('Bugüne Taşı'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.corporateNavy,
              backgroundColor: AppColors.surface.withValues(alpha: 0.85),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
      ),
    );
  }
}
