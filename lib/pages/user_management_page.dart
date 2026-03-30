import 'package:flutter/material.dart';

import '../features/admin/application/admin_access_controller.dart';
import '../models/partner.dart';
import '../models/user_profile.dart';
import '../services/partner_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/access_denied_view.dart';
import '../widgets/custom_header.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final AdminAccessController _adminAccessController = AdminAccessController();
  final UserService _userService = UserService();
  final PartnerService _partnerService = PartnerService();
  final TextEditingController _searchController = TextEditingController();

  List<UserProfile> _allUsers = [];
  List<UserProfile> _filteredUsers = [];
  List<Partner> _partners = [];

  bool _hasAccess = false;
  bool _isLoading = true;

  String _searchQuery = '';
  String _selectedRoleFilter = '';
  String _sortOption = 'name';

  List<UserProfile> get _pendingUsers =>
      _filteredUsers.where((user) => user.role == UserRole.pending).toList();

  List<UserProfile> get _approvedUsers =>
      _filteredUsers.where((user) => user.role != UserRole.pending).toList();

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
    _searchQuery = _searchController.text.trim().toLowerCase();
    _applyFilters();
  }

  void _applyFilters() {
    var filtered = List<UserProfile>.from(_allUsers);

    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((user) {
            final name = (user.fullName ?? '').toLowerCase();
            final email = (user.email ?? '').toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();
    }

    if (_selectedRoleFilter.isNotEmpty) {
      filtered =
          filtered.where((user) => user.role == _selectedRoleFilter).toList();
    }

    filtered.sort((a, b) {
      switch (_sortOption) {
        case 'email':
          return (a.email ?? '').compareTo(b.email ?? '');
        case 'role':
          final roleCompare = _roleSortIndex(
            a.role,
          ).compareTo(_roleSortIndex(b.role));
          if (roleCompare != 0) return roleCompare;
          return a.displayName.compareTo(b.displayName);
        case 'date':
          final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        case 'name':
        default:
          return a.displayName.compareTo(b.displayName);
      }
    });

    setState(() {
      _filteredUsers = filtered;
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final accessState = await _adminAccessController.load();
      if (!accessState.hasAccess) {
        if (!mounted) return;
        setState(() {
          _hasAccess = false;
          _isLoading = false;
        });
        return;
      }

      final users = await _userService.getAllUsers();
      final partners = await _partnerService.getAllPartners();

      if (!mounted) return;
      setState(() {
        _hasAccess = true;
        _allUsers = users;
        _partners = partners;
        _isLoading = false;
      });
      _applyFilters();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veri yüklenirken hata oluştu: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Partner?> _showPartnerSelectDialog() async {
    if (_partners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce partner firma eklemelisiniz.')),
      );
      return null;
    }

    return showDialog<Partner>(
      context: context,
      builder:
          (context) => SimpleDialog(
            title: const Text('Partner firmayı seçin'),
            children:
                _partners
                    .map(
                      (partner) => SimpleDialogOption(
                        onPressed: () => Navigator.pop(context, partner),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.business_outlined,
                              color: Colors.purple,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(partner.name)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
          ),
    );
  }

  Future<void> _changeRole(UserProfile user) async {
    final selectedRole = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Yetki seviyesi seçin',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                const Divider(height: 1),
                _buildRoleOption(
                  context,
                  UserRole.admin,
                  'Sistem yöneticisi',
                  Icons.admin_panel_settings_outlined,
                  Colors.red,
                ),
                _buildRoleOption(
                  context,
                  UserRole.manager,
                  'Yönetici',
                  Icons.manage_accounts_outlined,
                  Colors.orange,
                ),
                _buildRoleOption(
                  context,
                  UserRole.supervisor,
                  'Süpervizör',
                  Icons.supervisor_account_outlined,
                  Colors.teal,
                ),
                _buildRoleOption(
                  context,
                  UserRole.engineer,
                  'Mühendis',
                  Icons.design_services_outlined,
                  Colors.indigo,
                ),
                _buildRoleOption(
                  context,
                  UserRole.technician,
                  'Teknisyen',
                  Icons.engineering_outlined,
                  Colors.blue,
                ),
                _buildRoleOption(
                  context,
                  UserRole.user,
                  'Kullanıcı',
                  Icons.person_outline_rounded,
                  Colors.blueGrey,
                ),
                _buildRoleOption(
                  context,
                  UserRole.partnerUser,
                  'Partner kullanıcısı',
                  Icons.business_outlined,
                  Colors.purple,
                ),
                _buildRoleOption(
                  context,
                  UserRole.pending,
                  'Onay bekliyor',
                  Icons.hourglass_empty_rounded,
                  Colors.grey,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
    );

    if (selectedRole == null) {
      return;
    }

    int? selectedPartnerId;
    if (selectedRole == UserRole.partnerUser) {
      final partner = await _showPartnerSelectDialog();
      if (partner == null) return;
      selectedPartnerId = partner.id;
    }

    setState(() => _isLoading = true);
    try {
      if (selectedRole == UserRole.pending) {
        await _userService.updateUserRole(
          user.id,
          selectedRole,
          partnerId: selectedPartnerId,
        );
      } else {
        await _userService.approveUserAccount(
          user.id,
          selectedRole,
          partnerId: selectedPartnerId,
        );
      }

      await _loadData();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selectedRole == UserRole.pending
                ? 'Kullanıcı tekrar onay bekleyen duruma alındı.'
                : 'Kullanıcı onaylandı ve rolü güncellendi.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $error'), backgroundColor: Colors.red),
      );
    }
  }

  ListTile _buildRoleOption(
    BuildContext context,
    String roleKey,
    String label,
    IconData icon,
    Color color,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label),
      onTap: () => Navigator.pop(context, roleKey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textDark;

    if (!_isLoading && !_hasAccess) {
      return const Scaffold(
        body: Column(
          children: [
            CustomHeader(
              title: 'Kullanıcı Yönetimi',
              subtitle: 'Bu alan yönetici yetkisi gerektirir',
              showBackArrow: true,
            ),
            Expanded(
              child: AccessDeniedView(
                message:
                    'Kullanıcı yönetimi yalnızca admin ve manager kullanıcılar için açıktır.',
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const CustomHeader(
            title: 'Kullanıcı Yönetimi',
            subtitle: 'Personel ve partner yetkileri',
            showBackArrow: true,
          ),
          _buildToolbar(surfaceColor, isDark),
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.corporateNavy,
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.corporateNavy,
                      child:
                          _filteredUsers.isEmpty
                              ? _buildEmptyState()
                              : ListView(
                                padding: const EdgeInsets.all(16),
                                children: [
                                  if (_pendingUsers.isNotEmpty)
                                    _buildSection(
                                      title: 'Onay Bekleyenler',
                                      subtitle:
                                          '${_pendingUsers.length} kullanıcı yönetici onayı bekliyor',
                                      accentColor: Colors.amber,
                                      users: _pendingUsers,
                                      textColor: textColor,
                                      highlightPending: true,
                                    ),
                                  if (_approvedUsers.isNotEmpty)
                                    _buildSection(
                                      title: 'Aktif Kullanıcılar',
                                      subtitle:
                                          '${_approvedUsers.length} kullanıcı aktif durumda',
                                      accentColor: AppColors.corporateNavy,
                                      users: _approvedUsers,
                                      textColor: textColor,
                                    ),
                                ],
                              ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(Color surfaceColor, bool isDark) {
    final pendingCount =
        _allUsers.where((user) => user.role == UserRole.pending).length;

    return Container(
      color: surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'İsim veya e-posta ile ara...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                      : null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value:
                      _selectedRoleFilter.isEmpty ? null : _selectedRoleFilter,
                  decoration: const InputDecoration(labelText: 'Rol filtresi'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Tüm roller'),
                    ),
                    DropdownMenuItem<String>(
                      value: UserRole.pending,
                      child: Text(_getRoleLabel(UserRole.pending)),
                    ),
                    DropdownMenuItem<String>(
                      value: UserRole.admin,
                      child: Text(_getRoleLabel(UserRole.admin)),
                    ),
                    DropdownMenuItem<String>(
                      value: UserRole.manager,
                      child: Text(_getRoleLabel(UserRole.manager)),
                    ),
                    DropdownMenuItem<String>(
                      value: UserRole.supervisor,
                      child: Text(_getRoleLabel(UserRole.supervisor)),
                    ),
                    DropdownMenuItem<String>(
                      value: UserRole.engineer,
                      child: Text(_getRoleLabel(UserRole.engineer)),
                    ),
                    DropdownMenuItem<String>(
                      value: UserRole.technician,
                      child: Text(_getRoleLabel(UserRole.technician)),
                    ),
                    DropdownMenuItem<String>(
                      value: UserRole.user,
                      child: Text(_getRoleLabel(UserRole.user)),
                    ),
                    DropdownMenuItem<String>(
                      value: UserRole.partnerUser,
                      child: Text(_getRoleLabel(UserRole.partnerUser)),
                    ),
                  ],
                  onChanged: (value) {
                    _selectedRoleFilter = value ?? '';
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _sortOption,
                  decoration: const InputDecoration(labelText: 'Sıralama'),
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('İsme göre')),
                    DropdownMenuItem(
                      value: 'email',
                      child: Text('E-postaya göre'),
                    ),
                    DropdownMenuItem(value: 'role', child: Text('Role göre')),
                    DropdownMenuItem(value: 'date', child: Text('Tarihe göre')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    _sortOption = value;
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(
                label: 'Toplam',
                value: _allUsers.length.toString(),
                color: AppColors.corporateNavy,
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                label: 'Onay bekleyen',
                value: pendingCount.toString(),
                color: Colors.amber.shade700,
              ),
              const Spacer(),
              if (_searchQuery.isNotEmpty || _selectedRoleFilter.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    _selectedRoleFilter = '';
                    _sortOption = 'name';
                    _applyFilters();
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Temizle'),
                ),
            ],
          ),
          if (isDark) const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasFilters =
        _searchQuery.isNotEmpty || _selectedRoleFilter.isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(
          hasFilters ? Icons.search_off_outlined : Icons.people_outline_rounded,
          size: 64,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            hasFilters
                ? 'Arama kriterlerinize uygun kullanıcı bulunamadı.'
                : 'Henüz kullanıcı bulunmuyor.',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required Color accentColor,
    required List<UserProfile> users,
    required Color textColor,
    bool highlightPending = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 14),
        ...users.map(
          (user) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildUserCard(
              user,
              textColor: textColor,
              highlightPending: highlightPending,
            ),
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildUserCard(
    UserProfile user, {
    required Color textColor,
    bool highlightPending = false,
  }) {
    final roleColor = _getRoleColor(user.role);
    final partnerName = _findPartnerName(user.partnerId);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              highlightPending
                  ? Colors.amber.withOpacity(0.45)
                  : Colors.grey.shade300,
        ),
      ),
      child: InkWell(
        onTap: () => _changeRole(user),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: roleColor.withOpacity(0.12),
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName.substring(0, 1).toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: roleColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildRoleBadge(user.role, roleColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email ?? '-',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (partnerName != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.business_outlined,
                            size: 14,
                            color: Colors.purple,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              partnerName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.purple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (highlightPending) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Bu kullanıcı giriş yapamaz. Rol verildiğinde aktif olur.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        _getRoleLabel(role),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String? _findPartnerName(int? partnerId) {
    if (partnerId == null) return null;
    for (final partner in _partners) {
      if (partner.id == partnerId) {
        return partner.name;
      }
    }
    return null;
  }

  int _roleSortIndex(String role) {
    switch (role) {
      case UserRole.pending:
        return 0;
      case UserRole.admin:
        return 1;
      case UserRole.manager:
        return 2;
      case UserRole.supervisor:
        return 3;
      case UserRole.engineer:
        return 4;
      case UserRole.technician:
        return 5;
      case UserRole.user:
        return 6;
      case UserRole.partnerUser:
        return 7;
      default:
        return 99;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Yönetici';
      case UserRole.supervisor:
        return 'Süpervizör';
      case UserRole.engineer:
        return 'Mühendis';
      case UserRole.technician:
        return 'Teknisyen';
      case UserRole.user:
        return 'Kullanıcı';
      case UserRole.partnerUser:
        return 'Partner';
      case UserRole.pending:
        return 'Onay bekliyor';
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
      case UserRole.supervisor:
        return Colors.teal;
      case UserRole.engineer:
        return Colors.indigo;
      case UserRole.technician:
        return Colors.blue;
      case UserRole.user:
        return Colors.blueGrey;
      case UserRole.partnerUser:
        return Colors.purple;
      case UserRole.pending:
        return Colors.amber.shade700;
      default:
        return Colors.grey;
    }
  }
}
