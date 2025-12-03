import 'package:flutter/material.dart';
import '../services/user_service.dart';
import '../services/partner_service.dart';
import '../models/user_profile.dart';
import '../models/partner.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_header.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final UserService _userService = UserService();
  final PartnerService _partnerService = PartnerService();
  
  List<UserProfile> _users = [];
  List<Partner> _partners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final users = await _userService.getAllUsers();
      final partners = await _partnerService.getAllPartners();

      users.sort((a, b) {
        if (a.role == 'pending' && b.role != 'pending') return -1;
        if (a.role != 'pending' && b.role == 'pending') return 1;
        return (a.fullName ?? '').compareTo(b.fullName ?? '');
      });
      
      if (mounted) {
        setState(() {
          _users = users;
          _partners = partners;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Partner?> _showPartnerSelectDialog() async {
    if (_partners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce Partner Firma eklemelisiniz!')),
      );
      return null;
    }

    return await showDialog<Partner>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Hangi Partner Firması?'),
        children: _partners.map((partner) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, partner),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                const Icon(Icons.business, color: Colors.purple, size: 20),
                const SizedBox(width: 12),
                Text(partner.name, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  Future<void> _changeRole(UserProfile user) async {
    final newRole = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Yetki Seviyesi Seçin',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.corporateNavy),
              ),
            ),
            const Divider(height: 1),
            _buildRoleOption(ctx, 'admin', 'Sistem Yöneticisi (Tam Yetki)', Icons.admin_panel_settings, Colors.red),
            _buildRoleOption(ctx, 'manager', 'Yönetici (Stok/Rapor)', Icons.manage_accounts, Colors.orange),
            _buildRoleOption(ctx, 'technician', 'Saha Teknisyeni (Sınırlı)', Icons.engineering, Colors.blue),
            _buildRoleOption(ctx, 'partner_user', 'Partner Firma Kullanıcısı', Icons.business, Colors.purple),
            _buildRoleOption(ctx, 'pending', 'Onay Bekliyor (Kısıtlı)', Icons.hourglass_empty, Colors.grey),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (newRole != null) {
      // Eğer aynı rol seçildiyse ve partner değilse işlem yapma
      if (newRole == user.role && newRole != 'partner_user') return;

      int? selectedPartnerId;
      
      // Partner User seçildiyse, her zaman partner sor (değiştirmek isteyebilir)
      if (newRole == 'partner_user') {
        final partner = await _showPartnerSelectDialog();
        if (partner == null) return; // İptal edildi
        selectedPartnerId = partner.id;
      }

      setState(() => _isLoading = true);
      try {
        await _userService.updateUserRole(user.id, newRole, partnerId: selectedPartnerId);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kullanıcı yetkisi güncellendi'), backgroundColor: Colors.green)
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red)
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  ListTile _buildRoleOption(BuildContext context, String roleKey, String label, IconData icon, Color color) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: () => Navigator.pop(context, roleKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : AppColors.backgroundGrey;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textDark;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          const CustomHeader(
            title: 'Kullanıcı Yönetimi',
            subtitle: 'Personel ve Partner yetkileri',
            showBackArrow: true,
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.corporateNavy))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.corporateNavy,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      final displayName = user.fullName ?? user.email ?? '?';
                      final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
                      
                      // Kullanıcının partner ismini bul
                      String? partnerName;
                      if (user.isPartner && user.partnerId != null) {
                        final p = _partners.where((p) => p.id == user.partnerId).firstOrNull;
                        partnerName = p?.name;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
                            child: Text(
                              initial,
                              style: TextStyle(color: _getRoleColor(user.role), fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            user.fullName ?? 'İsimsiz Kullanıcı',
                            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.email ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              if (partnerName != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.business, size: 12, color: Colors.purple),
                                      const SizedBox(width: 4),
                                      Text(partnerName, style: const TextStyle(fontSize: 12, color: Colors.purple, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getRoleColor(user.role).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _getRoleColor(user.role).withOpacity(0.3)),
                            ),
                            child: Text(
                              _getRoleLabel(user.role),
                              style: TextStyle(color: _getRoleColor(user.role), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          onTap: () => _changeRole(user),
                        ),
                      );
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin': return 'Admin';
      case 'manager': return 'Yönetici';
      case 'technician': return 'Teknisyen';
      case 'partner_user': return 'Partner';
      case 'pending': return 'Onay Bekliyor';
      default: return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return Colors.red;
      case 'manager': return Colors.orange;
      case 'technician': return Colors.blue;
      case 'partner_user': return Colors.purple;
      case 'pending': return Colors.grey;
      default: return Colors.grey;
    }
  }
}
