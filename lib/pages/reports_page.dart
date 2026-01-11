import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Panoya kopyalamak için
import 'package:intl/intl.dart';
import '../services/daily_activity_report_service.dart';
import '../services/daily_activity_service.dart';
import '../services/user_service.dart'; // User Service Eklendi
import '../widgets/app_drawer.dart';
import '../theme/app_colors.dart';
import '../models/user_profile.dart'; // Model Eklendi
import 'ticket_list_page.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final DailyActivityReportService _reportService = DailyActivityReportService();
  final DailyActivityService _dailyActivityService = DailyActivityService();
  final UserService _userService = UserService(); // Servis Eklendi
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  DateTime _selectedDate = DateTime.now();
  bool _isDetailed = true; // Varsayılan olarak detaylı olsun
  String _reportPreview = "";
  bool _isLoading = false;
  
  // User Profile
  UserProfile? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _generateReport();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userService.getCurrentUserProfile();
    if (mounted) {
      setState(() {
        _currentUser = profile;
      });
    }
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);
    try {
      final text = await _reportService.generateTextReport(_selectedDate, isDetailed: _isDetailed);
      if (mounted) {
        setState(() {
          _reportPreview = text;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reportPreview = "Hata oluştu: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _reportPreview));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rapor kopyalandı! WhatsApp veya Mail\'e yapıştırabilirsin.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Partner firmalar günlük rapor ekranını göremez
    if (_currentUser?.isPartnerUser == true) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Rapor Oluştur'),
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Rapor Oluştur', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
          backgroundColor: AppColors.surface,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.textDark),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          bottom: const TabBar(
            indicatorColor: AppColors.primary,
            labelColor: AppColors.textDark,
            unselectedLabelColor: AppColors.textLight,
            tabs: [
              Tab(text: 'Metin'),
              Tab(text: 'Analiz'),
            ],
          ),
        ),
        drawer: AppDrawer(
          currentPage: AppDrawerPage.reports,
          userName: _currentUser?.displayName,
          userRole: _currentUser?.role,
        ),
        body: TabBarView(
          children: [
            _buildTextReportTab(),
            _DailyActivitiesAnalyticsTab(activityService: _dailyActivityService),
          ],
        ),
      ),
    );
  }

  Widget _buildTextReportTab() {
    return Column(
      children: [
        // --- FİLTRE ALANI ---
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              // Tarih Seçici
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2023),
                    lastDate: DateTime(2030),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: AppColors.primary,
                            onPrimary: Colors.white,
                            onSurface: AppColors.textDark,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                    _generateReport();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Rapor Tarihi: ${DateFormat('dd MMMM yyyy', 'tr_TR').format(_selectedDate)}",
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark),
                      ),
                      const Icon(Icons.calendar_month, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Detay Switch'i
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Teknik Detayları Göster", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    Switch(
                      value: _isDetailed,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) {
                        setState(() => _isDetailed = val);
                        _generateReport();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- ÖNİZLEME ALANI ---
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9), // Slate-100
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _reportPreview,
                      style: const TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 14,
                        color: Color(0xFF334155),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
        ),

        // --- AKSİYON BUTONU ---
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.corporateNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              onPressed: _copyToClipboard,
              icon: const Icon(Icons.copy, color: Colors.white),
              label: const Text(
                "Raporu Kopyala",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyActivitiesAnalyticsTab extends StatefulWidget {
  final DailyActivityService activityService;
  const _DailyActivitiesAnalyticsTab({required this.activityService});

  @override
  State<_DailyActivitiesAnalyticsTab> createState() => _DailyActivitiesAnalyticsTabState();
}

class _DailyActivitiesAnalyticsTabState extends State<_DailyActivitiesAnalyticsTab> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 29)),
    end: DateTime.now(),
  );
  bool _loading = false;

  int _totalTasks = 0;
  int _completedTasks = 0;
  int _daysWithCompletion = 0;
  List<_DayStat> _daily = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _range,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _range = picked);
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final start = DateTime(_range.start.year, _range.start.month, _range.start.day);
      final end = DateTime(_range.end.year, _range.end.month, _range.end.day);
      final days = end.difference(start).inDays + 1;

      final daily = <_DayStat>[];
      int total = 0;
      int done = 0;

      for (int i = 0; i < days; i++) {
        final d = start.add(Duration(days: i));
        final list = await widget.activityService.getActivities(d);
        final dayTotal = list.length;
        final dayDone = list.where((a) => a.isCompleted).length;
        total += dayTotal;
        done += dayDone;
        daily.add(_DayStat(date: d, total: dayTotal, done: dayDone));
      }

      final daysWithCompletion = daily.where((e) => e.done > 0).length;
      if (!mounted) return;
      setState(() {
        _daily = daily;
        _totalTasks = total;
        _completedTasks = done;
        _daysWithCompletion = daysWithCompletion;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = DateTime(_range.end.year, _range.end.month, _range.end.day)
            .difference(DateTime(_range.start.year, _range.start.month, _range.start.day))
            .inDays +
        1;

    final avgPerDay = days > 0 ? (_completedTasks / days) : 0.0;
    final maxDone = _daily.isEmpty ? 0 : _daily.map((e) => e.done).reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "${DateFormat('dd.MM.yyyy').format(_range.start)} - ${DateFormat('dd.MM.yyyy').format(_range.end)}",
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
              ),
              TextButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range),
                label: const Text('Aralık'),
              ),
            ],
          ),
        ),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _metricRow(
                  leftTitle: 'Toplam İş',
                  leftValue: '$_totalTasks',
                  rightTitle: 'Bitirilen İş',
                  rightValue: '$_completedTasks',
                ),
                const SizedBox(height: 12),
                _metricRow(
                  leftTitle: 'Gün Sayısı',
                  leftValue: '$days',
                  rightTitle: 'İş Bitirilen Gün',
                  rightValue: '$_daysWithCompletion',
                ),
                const SizedBox(height: 12),
                _metricSingle(title: 'Günlük Ortalama (Bitirilen)', value: avgPerDay.toStringAsFixed(2)),
                const SizedBox(height: 16),
                const Text('Gün Gün Bitirilen İş', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textDark)),
                const SizedBox(height: 10),
                ..._daily.map((d) {
                  final factor = maxDone == 0 ? 0.0 : (d.done / maxDone);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 92,
                          child: Text(
                            DateFormat('dd.MM').format(d.date),
                            style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              height: 10,
                              color: AppColors.primary.withValues(alpha: 0.08),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: factor.clamp(0.0, 1.0),
                                  child: Container(color: AppColors.primary.withValues(alpha: 0.75)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 42,
                          child: Text(
                            '${d.done}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 18),
                const Text(
                  'İşlerin sürme süresi (dakika/saat) için completed_at gibi bir bitiş zamanına ihtiyaç var. '
                  'Şu an DailyActivity modelinde sadece created_at var; bu yüzden doğru süre hesabı yapılamıyor.',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12.5, height: 1.35),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _metricRow({
    required String leftTitle,
    required String leftValue,
    required String rightTitle,
    required String rightValue,
  }) {
    return Row(
      children: [
        Expanded(child: _metricCard(title: leftTitle, value: leftValue)),
        const SizedBox(width: 12),
        Expanded(child: _metricCard(title: rightTitle, value: rightValue)),
      ],
    );
  }

  Widget _metricSingle({required String title, required String value}) {
    return _metricCard(title: title, value: value);
  }

  Widget _metricCard({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w900, fontSize: 22)),
        ],
      ),
    );
  }
}

class _DayStat {
  final DateTime date;
  final int total;
  final int done;
  _DayStat({required this.date, required this.total, required this.done});
}


