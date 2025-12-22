import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Panoya kopyalamak için
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/daily_activity_report_service.dart';
import '../services/user_service.dart'; // User Service Eklendi
import '../widgets/app_drawer.dart';
import '../theme/app_colors.dart';
import '../models/user_profile.dart'; // Model Eklendi

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final DailyActivityReportService _reportService = DailyActivityReportService();
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
          content: Text('Rapor kopyalandı! WhatsApp veya Mail\'e yapıştırabilirsin. 📋'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      ),
      drawer: AppDrawer(
        currentPage: AppDrawerPage.reports,
        userName: _currentUser?.displayName,
        userRole: _currentUser?.role,
      ),
      body: Column(
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
                        activeColor: AppColors.primary,
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
                      color: const Color(0xFFF1F5F9), // Slate-100 (Kod editörü gibi)
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
      ),
    );
  }
}


