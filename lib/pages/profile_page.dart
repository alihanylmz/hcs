import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart';
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
    
    setState(() => _isLoading = true);
    try {
      await _userService.updateProfile(_userProfile!.id, fullName: _nameController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil güncellendi')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    // AuthGate otomatik olarak Login sayfasına atacak
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Profilim')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
            const SizedBox(height: 20),
            
            // Kişisel Bilgiler Kartı
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kişisel Bilgiler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Ad Soyad', prefixIcon: Icon(Icons.badge)),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      initialValue: _userProfile?.email,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'E-posta', prefixIcon: Icon(Icons.email), filled: true),
                    ),
                     const SizedBox(height: 10),
                    TextFormField(
                      initialValue: _getRoleLabel(_userProfile?.role),
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Yetki Seviyesi', prefixIcon: Icon(Icons.security), filled: true),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(onPressed: _updateProfile, child: const Text('Bilgileri Güncelle')),
                    ),
                  ],
                ),
              ),
            ),
            
            // Yönetici Paneli Butonu (Sadece Admin/Manager Görür)
            if (_userProfile?.isManager == true || _userProfile?.isAdmin == true) ...[
              const SizedBox(height: 20),
              Card(
                color: theme.colorScheme.primaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('Kullanıcı Yönetimi'),
                  subtitle: const Text('Personel yetkilerini düzenle'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementPage()));
                  },
                ),
              ),
            ],

            const SizedBox(height: 30),
            TextButton.icon(
              onPressed: _signOut, 
              icon: const Icon(Icons.logout, color: Colors.red), 
              label: const Text('Çıkış Yap', style: TextStyle(color: Colors.red))
            ),
          ],
        ),
      ),
    );
  }

  String _getRoleLabel(String? role) {
    switch (role) {
      case 'admin': return 'Sistem Yöneticisi';
      case 'manager': return 'Yönetici';
      case 'technician': return 'Teknisyen';
      default: return 'Kullanıcı';
    }
  }
}

