import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // date formatting için
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printing/printing.dart';

// Modeller ve Servisler
import '../models/daily_activity.dart';
import '../models/user_profile.dart';
import '../services/daily_activity_service.dart';
import '../services/daily_activity_report_service.dart';
import '../services/user_service.dart';

// Widgetlar
import '../widgets/app_drawer.dart';
import '../widgets/add_task_dialog.dart';
import '../widgets/daily_activities/date_timeline.dart';
import '../widgets/daily_activities/activity_card.dart';
import '../widgets/daily_activities/empty_state.dart';
import '../theme/app_colors.dart';

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

  @override
  void initState() {
    super.initState();
    _initPage();
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
          _showSnack('$count adet iş bugüne taşındı 📦', isSuccess: true);
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
      _showSnack('"$title" eklendi ✅', isSuccess: true);
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
      final userName = selectedUser.displayName ?? 'Personel';

      await Printing.layoutPdf(
        onLayout: (format) => _reportService.generateReport(
          activities: _activities, 
          date: _selectedDate,
          userName: userName,
        ),
        name: 'Rapor_${DateFormat('yyyyMMdd').format(_selectedDate)}',
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
      _showSnack('Rapor kopyalandı! 📋', isSuccess: true);
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
        _showSnack('İş paketi eklendi 🚀', isSuccess: true);
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
      _showSnack('Bağlantı hatası ⚠️', isError: true);
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
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
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
                    fontWeight: FontWeight.bold, 
                    fontSize: 18
                  ),
                  onChanged: _onUserSelected,
                  items: _allUsers.map((user) {
                    return DropdownMenuItem<String>(
                      value: user.id,
                      child: Text(user.displayName ?? 'İsimsiz'),
                    );
                  }).toList(),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Günlük Planım', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                  Text(
                    DateFormat('d MMM yyyy', 'tr_TR').format(_selectedDate),
                    style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
        actions: [
          // BUGÜN Butonu
          TextButton(
             onPressed: () => _onDateSelected(DateTime.now()),
             child: const Text('BUGÜN', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          // Takvim
          IconButton(
            icon: const Icon(Icons.calendar_today, color: AppColors.textDark),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
              );
              if (date != null) _onDateSelected(date);
            },
          ),
        ],
      ),
      
      drawer: AppDrawer(
        currentPage: AppDrawerPage.dailyActivities,
        userName: _currentUser?.displayName,
        userRole: _currentUser?.role,
      ),
      
      body: Column(
        children: [
          // 1. Tarih Şeridi
          DateTimeline(
            selectedDate: _selectedDate, 
            onDateSelected: _onDateSelected
          ),

          // 2. Geçmiş Uyarısı (Sadece kendi profilindeyse göster)
          if (_pendingPastCount > 0 && _selectedUserId == _currentUser?.id)
            Container(
              width: double.infinity,
              color: Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Geçmişte $_pendingPastCount tamamlanmamış iş var.',
                      style: TextStyle(color: Colors.orange.shade900, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _moveYesterdayToToday,
                    icon: const Icon(Icons.low_priority, size: 16),
                    label: const Text('Bugüne Taşı'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange.shade900,
                      backgroundColor: Colors.white.withOpacity(0.5),
                    ),
                  )
                ],
              ),
            ),
          
          // 3. İlerleme Çubuğu
          if (_activities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Günün İlerlemesi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textLight)),
                      Text("%${(totalProgress * 100).toInt()}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: totalProgress == 1.0 ? AppColors.statusDone : AppColors.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalProgress,
                      backgroundColor: Colors.grey.shade200,
                      color: totalProgress == 1.0 ? AppColors.statusDone : AppColors.primary,
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

          // 4. Liste
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _activities.isEmpty
                    ? const EmptyActivitiesState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _activities.length,
                        itemBuilder: (context, index) {
                          final activity = _activities[index];
                          return ActivityCard(
                            activity: activity,
                            onToggleStep: _toggleStep,
                            onToggleActivity: _toggleActivity,
                            onDelete: _deleteActivity,
                            onConfirmDelete: _confirmDelete,
                          );
                        },
                      ),
          ),
        ],
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

  Widget _buildFabItem({
    required IconData icon, 
    required String label, 
    required Color color, 
    required VoidCallback onTap
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
            ],
          ),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
