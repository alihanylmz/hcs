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
  final TextEditingController _searchController = TextEditingController();
  
  List<UserProfile> _allUsers = [];
  List<UserProfile> _filteredUsers = [];
  List<Partner> _partners = [];
  bool _isLoading = true;
  
  // Filtreleme ve sıralama
  String _searchQuery = '';
  String? _selectedRoleFilter;
  String _sortOption = 'name'; // 'name', 'email', 'role', 'date'

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<UserProfile> filtered = List.from(_allUsers);

    // Arama filtresi
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final name = (user.fullName ?? '').toLowerCase();
        final email = (user.email ?? '').toLowerCase();
        return name.contains(_searchQuery) || email.contains(_searchQuery);
      }).toList();
    }

    // Rol filtresi
    if (_selectedRoleFilter != null && _selectedRoleFilter!.isNotEmpty) {
      filtered = filtered.where((user) => user.role == _selectedRoleFilter).toList();
    }

    // Sıralama
    filtered.sort((a, b) {
      switch (_sortOption) {
        case 'name':
          return (a.fullName ?? a.email ?? '').compareTo(b.fullName ?? b.email ?? '');
        case 'email':
          return (a.email ?? '').compareTo(b.email ?? '');
        case 'role':
          return a.role.compareTo(b.role);
        case 'date':
          final aDate = a.createdAt ?? DateTime(1970);
          final bDate = b.createdAt ?? DateTime(1970);
          return bDate.compareTo(aDate); // Yeni önce
        default:
          return 0;
      }
    });

    setState(() {
      _filteredUsers = filtered;
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final users = await _userService.getAllUsers();
      final partners = await _partnerService.getAllPartners();
      
      if (mounted) {
        setState(() {
          _allUsers = users;
          _partners = partners;
          _isLoading = false;
        });
        // Veriler yüklendikten sonra filtreleri uygula
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veri yüklenirken hata: $e'), backgroundColor: Colors.red),
        );
      }
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
            _buildRoleOption(ctx, UserRole.admin, 'Sistem Yöneticisi (Tam Yetki)', Icons.admin_panel_settings, Colors.red),
            _buildRoleOption(ctx, UserRole.manager, 'Yönetici (Stok/Rapor)', Icons.manage_accounts, Colors.orange),
            _buildRoleOption(ctx, UserRole.technician, 'Saha Teknisyeni (Sınırlı)', Icons.engineering, Colors.blue),
            _buildRoleOption(ctx, UserRole.partnerUser, 'Partner Firma Kullanıcısı', Icons.business, Colors.purple),
            _buildRoleOption(ctx, UserRole.pending, 'Onay Bekliyor (Kısıtlı)', Icons.hourglass_empty, Colors.grey),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (newRole != null) {
      if (newRole == user.role && newRole != UserRole.partnerUser) return;

      int? selectedPartnerId;
      
      if (newRole == UserRole.partnerUser) {
        final partner = await _showPartnerSelectDialog();
        if (partner == null) return;
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
          setState(() => _isLoading = false);
        }
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
          
          // Arama ve Filtreleme Toolbar
          Container(
            padding: const EdgeInsets.all(16),
            color: cardColor,
            child: Column(
              children: [
                // Arama Kutusu
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'İsim veya e-posta ile ara...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Filtreler ve Sıralama
                Row(
                  children: [
                    // Rol Filtresi
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRoleFilter,
                            isExpanded: true,
                            hint: const Row(
                              children: [
                                Icon(Icons.filter_list, size: 18),
                                SizedBox(width: 8),
                                Text('Tüm Roller'),
                              ],
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Tüm Roller')),
                              DropdownMenuItem(value: UserRole.admin, child: Text(_getRoleLabel(UserRole.admin))),
                              DropdownMenuItem(value: UserRole.manager, child: Text(_getRoleLabel(UserRole.manager))),
                              DropdownMenuItem(value: UserRole.technician, child: Text(_getRoleLabel(UserRole.technician))),
                              DropdownMenuItem(value: UserRole.partnerUser, child: Text(_getRoleLabel(UserRole.partnerUser))),
                              DropdownMenuItem(value: UserRole.pending, child: Text(_getRoleLabel(UserRole.pending))),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedRoleFilter = value;
                                _applyFilters();
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Sıralama
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortOption,
                          hint: const Row(
                            children: [
                              Icon(Icons.sort, size: 18),
                              SizedBox(width: 8),
                              Text('Sırala'),
                            ],
                          ),
                          items: const [
                            DropdownMenuItem(value: 'name', child: Text('İsme Göre')),
                            DropdownMenuItem(value: 'email', child: Text('E-postaya Göre')),
                            DropdownMenuItem(value: 'role', child: Text('Role Göre')),
                            DropdownMenuItem(value: 'date', child: Text('Tarihe Göre')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _sortOption = value;
                                _applyFilters();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Sonuç Sayısı ve İstatistikler
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_filteredUsers.length} / ${_allUsers.length} kullanıcı',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_selectedRoleFilter != null || _searchQuery.isNotEmpty)
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _selectedRoleFilter = null;
                            _applyFilters();
                          });
                        },
                        icon: const Icon(Icons.clear_all, size: 16),
                        label: const Text('Filtreleri Temizle'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          // Kullanıcı Listesi - DataTable benzeri yapı
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.corporateNavy))
              : _filteredUsers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty || _selectedRoleFilter != null
                                ? Icons.search_off
                                : Icons.people_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty || _selectedRoleFilter != null
                                ? 'Arama kriterlerinize uygun kullanıcı bulunamadı'
                                : 'Henüz kullanıcı bulunmuyor',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.corporateNavy,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          final displayName = user.displayName;
                          final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
                          
                          String? partnerName;
                          if (user.isPartnerUser && user.partnerId != null) {
                            final p = _partners.where((p) => p.id == user.partnerId).firstOrNull;
                            partnerName = p?.name;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () => _changeRole(user),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Avatar
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: _getRoleColor(user.role).withOpacity(0.1),
                                      child: Text(
                                        initial,
                                        style: TextStyle(
                                          color: _getRoleColor(user.role),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    
                                    // Kullanıcı Bilgileri
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  user.fullName ?? 'İsimsiz Kullanıcı',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: textColor,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              // Rol Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getRoleColor(user.role).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: _getRoleColor(user.role).withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  _getRoleLabel(user.role),
                                                  style: TextStyle(
                                                    color: _getRoleColor(user.role),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            user.email ?? '',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (partnerName != null) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.business,
                                                  size: 14,
                                                  color: Colors.purple,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    partnerName,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.purple,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    
                                    // Action Icon
                                    Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),
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
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Yönetici';
      case UserRole.technician:
        return 'Teknisyen';
      case UserRole.partnerUser:
        return 'Partner';
      case UserRole.pending:
        return 'Onay Bekliyor';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.manager:
        return Colors.orange;
      case UserRole.technician:
        return Colors.blue;
      case UserRole.partnerUser:
        return Colors.purple;
      case UserRole.pending:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
