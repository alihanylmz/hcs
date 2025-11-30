import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';
import '../widgets/app_drawer.dart';
import '../theme/app_colors.dart';
import 'user_management_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserService _userService = UserService();
  UserProfile? _userProfile;
  bool _isLoading = true;
  final _nameController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final profile = await _userService.getCurrentUserProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _nameController.text = profile?.fullName ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_userProfile == null) return;
    
    // Klavyeyi kapat
    FocusScope.of(context).unfocus();
    
    setState(() => _isLoading = true);
    try {
      await _userService.updateProfile(_userProfile!.id, fullName: _nameController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil başarıyla güncellendi'),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : AppColors.backgroundGrey;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.corporateNavy;

    if (_isLoading) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: bgColor,
        drawer: AppDrawer(
          currentPage: AppDrawerPage.profile,
          userName: _userProfile?.fullName,
          userRole: _userProfile?.role,
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.corporateNavy)),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: bgColor,
      drawer: AppDrawer(
        currentPage: AppDrawerPage.profile,
        userName: _userProfile?.fullName,
        userRole: _userProfile?.role,
      ),
      extendBodyBehindAppBar: true, // Header'ın en tepeye kadar çıkması için
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Profilim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Çıkış Yap',
            onPressed: _signOut,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 1. HEADER & AVATAR ALANI ---
            Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior: Clip.none,
              children: [
                // Lacivert Arka Plan
                Container(
                  height: 240,
                  decoration: const BoxDecoration(
                    color: AppColors.corporateNavy,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                  ),
                ),
                // Dekoratif Daireler (Arka plan süsü)
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Profil Resmi (Taşan Kısım)
                Positioned(
                  bottom: -60,
                  child: Container(
                    padding: const EdgeInsets.all(4), // Beyaz çerçeve için boşluk
                    decoration: BoxDecoration(
                      color: bgColor, // Arka plan rengiyle aynı olsun ki kesik gibi dursun
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      child: Text(
                        (_userProfile?.displayName ?? 'A').substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 70), // Avatar boşluğu

            // --- 2. İSİM VE ROL BİLGİSİ ---
            Text(
              _userProfile?.displayName ?? 'İsimsiz Kullanıcı',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.corporateNavy.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.corporateNavy.withOpacity(0.2)),
              ),
              child: Text(
                _getRoleLabel(_userProfile?.role),
                style: const TextStyle(
                  color: AppColors.corporateNavy,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // --- 3. DÜZENLEME FORMU ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildProfileCard(
                    context,
                    title: 'Kişisel Bilgiler',
                    icon: Icons.person_outline,
                    cardColor: cardColor,
                    children: [
                      _buildTextField(
                        label: 'Ad Soyad',
                        controller: _nameController,
                        icon: Icons.badge_outlined,
                        isEditable: true,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        label: 'E-posta Adresi',
                        initialValue: _userProfile?.email,
                        icon: Icons.email_outlined,
                        isEditable: false, // E-posta değişmez
                        isDark: isDark,
                      ),
                    ],
                  ),

                  // Sadece Yönetici Görür
                  if (_userProfile?.isManager == true || _userProfile?.isAdmin == true) ...[
                    const SizedBox(height: 20),
                    _buildActionCard(
                      context,
                      title: 'Kullanıcı Yönetimi',
                      subtitle: 'Personel yetkilerini ve hesaplarını düzenle',
                      icon: Icons.admin_panel_settings_outlined,
                      color: Colors.orange.shade700,
                      cardColor: cardColor,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementPage()));
                      },
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Kaydet Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.corporateNavy,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: AppColors.corporateNavy.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'DEĞİŞİKLİKLERİ KAYDET',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET YARDIMCILARI ---

  Widget _buildProfileCard(BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
    required Color cardColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.corporateNavy),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    String? initialValue,
    required IconData icon,
    required bool isEditable,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isEditable 
                ? (isDark ? Colors.black12 : AppColors.backgroundGrey) 
                : (isDark ? Colors.black26 : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEditable ? Colors.transparent : (isDark ? Colors.white10 : Colors.grey.shade200),
            ),
          ),
          child: TextFormField(
            controller: controller,
            initialValue: initialValue,
            readOnly: !isEditable,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textDark,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: isDark ? Colors.grey : Colors.grey.shade500, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color cardColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  String _getRoleLabel(String? role) {
    switch (role) {
      case 'admin': return 'SİSTEM YÖNETİCİSİ';
      case 'manager': return 'YÖNETİCİ';
      case 'technician': return 'SAHA TEKNİSYENİ';
      default: return 'KULLANICI';
    }
  }
}
