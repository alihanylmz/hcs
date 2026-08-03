import 'package:flutter/material.dart';

import '../features/admin/application/admin_access_controller.dart';
import '../models/partner.dart';
import '../models/user_app_access.dart';
import '../models/user_profile.dart';
import '../services/partner_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/access_denied_view.dart';
import '../widgets/custom_header.dart';
import '../widgets/user_access_editor_dialog.dart';

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
  Map<String, Map<String, UserAppAccess>> _appAccessByUser = {};
  UserProfile? _currentProfile;
  final Set<String> _savingUserIds = {};

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
          filtered.where((user) {
            if (_selectedRoleFilter == UserRole.pending) return user.isPending;
            return _businessRoleForUser(user) == _selectedRoleFilter;
          }).toList();
    }

    filtered.sort((a, b) {
      switch (_sortOption) {
        case 'email':
          return (a.email ?? '').compareTo(b.email ?? '');
        case 'role':
          final roleCompare = _roleSortIndex(
            _businessRoleForUser(a),
          ).compareTo(_roleSortIndex(_businessRoleForUser(b)));
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
      final appAccessByUser = await _userService.getAllUserAppAccess();

      if (!mounted) return;
      setState(() {
        _hasAccess = true;
        _currentProfile = accessState.profile;
        _allUsers = users;
        _partners = partners;
        _appAccessByUser = appAccessByUser;
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

  Future<void> _openAccessEditor(UserProfile user) async {
    if (_savingUserIds.contains(user.id)) return;

    final accesses = _appAccessByUser[user.id] ?? const {};
    final workAccess = accesses['is_takip'];
    final quoteAccess = accesses['teklif'];
    final knownWorkRoles =
        UserAccessCatalog.isTakipRoles.map((role) => role.code).toSet();
    final proposedWorkRole = workAccess?.appRole ?? user.role;
    final workRole =
        knownWorkRoles.contains(proposedWorkRole)
            ? proposedWorkRole
            : UserRole.user;
    final knownQuoteRoles =
        UserAccessCatalog.teklifRoles.map((role) => role.code).toSet();
    final proposedQuoteRole = quoteAccess?.appRole ?? 'sales';
    final quoteRole =
        knownQuoteRoles.contains(proposedQuoteRole)
            ? proposedQuoteRole
            : 'sales';
    final draft = await showDialog<UserAccessDraft>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => UserAccessEditorDialog(
            user: user,
            partners: _partners,
            isCurrentUser: _currentProfile?.id == user.id,
            readOnly:
                _currentProfile?.role != UserRole.admin &&
                (user.role == UserRole.admin ||
                    quoteAccess?.appRole == 'admin'),
            initialDraft: UserAccessDraft(
              businessRole: UserAccessCatalog.inferBusinessRole(
                profileRole: workRole,
                teklifActive: quoteAccess?.isActive ?? false,
                teklifRole: quoteRole,
              ),
              isTakipActive:
                  workAccess?.isActive ?? user.role != UserRole.pending,
              isTakipRole: workRole,
              teklifActive: quoteAccess?.isActive ?? false,
              teklifRole: quoteRole,
              partnerId: user.partnerId,
            ),
          ),
    );
    if (draft == null || !mounted) return;

    setState(() => _savingUserIds.add(user.id));
    try {
      await _userService.saveUserAccessConfiguration(user: user, draft: draft);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.displayName} için yetkiler güncellendi.'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Yetkiler güncellenemedi: $error'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingUserIds.remove(user.id));
    }
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
            subtitle: 'Personel, partner ve uygulama yetkileri',
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
    final workAccessCount =
        _allUsers.where((user) {
          final access = _appAccessByUser[user.id]?['is_takip'];
          return access?.isActive ?? user.role != UserRole.pending;
        }).length;
    final quoteAccessCount =
        _allUsers.where((user) {
          return _appAccessByUser[user.id]?['teklif']?.isActive ?? false;
        }).length;

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
          LayoutBuilder(
            builder: (context, constraints) {
              final roleFilter = Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('role-filter-$_selectedRoleFilter'),
                  initialValue:
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
                    ...UserAccessCatalog.businessRoles.map(
                      (role) => DropdownMenuItem<String>(
                        value: role.code,
                        child: Text(role.label),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    _selectedRoleFilter = value ?? '';
                    _applyFilters();
                  },
                ),
              );
              final sortFilter = Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('sort-$_sortOption'),
                  initialValue: _sortOption,
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
              );
              if (constraints.maxWidth < 620) {
                return Column(
                  children: [
                    Row(children: [roleFilter]),
                    const SizedBox(height: 10),
                    Row(children: [sortFilter]),
                  ],
                );
              }
              return Row(
                children: [roleFilter, const SizedBox(width: 12), sortFilter],
              );
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildInfoChip(
                  label: 'Toplam',
                  value: _allUsers.length.toString(),
                  color: AppColors.corporateNavy,
                ),
                _buildInfoChip(
                  label: 'İş Takip',
                  value: workAccessCount.toString(),
                  color: Colors.blue.shade700,
                ),
                _buildInfoChip(
                  label: 'Teklif',
                  value: quoteAccessCount.toString(),
                  color: Colors.green.shade700,
                ),
                if (pendingCount > 0)
                  _buildInfoChip(
                    label: 'Onay bekleyen',
                    value: pendingCount.toString(),
                    color: Colors.amber.shade700,
                  ),
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
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
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
    final partnerName = _findPartnerName(user.partnerId);
    final accesses = _appAccessByUser[user.id] ?? const {};
    final workAccess = accesses['is_takip'];
    final quoteAccess = accesses['teklif'];
    final workActive = workAccess?.isActive ?? user.role != UserRole.pending;
    final quoteActive = quoteAccess?.isActive ?? false;
    final workRole = workAccess?.appRole ?? user.role;
    final quoteRole = quoteAccess?.appRole ?? 'sales';
    final businessRole = UserAccessCatalog.inferBusinessRole(
      profileRole: workRole,
      teklifActive: quoteActive,
      teklifRole: quoteRole,
    );
    final businessRoleDefinition = UserAccessCatalog.businessRole(businessRole);
    final roleColor = _getBusinessRoleColor(businessRole);
    final isSaving = _savingUserIds.contains(user.id);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              highlightPending
                  ? Colors.amber.withValues(alpha: 0.45)
                  : Colors.grey.shade300,
        ),
      ),
      child: InkWell(
        onTap: () => _openAccessEditor(user),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: roleColor.withValues(alpha: 0.12),
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
                        _buildRoleBadge(
                          businessRoleDefinition.label,
                          roleColor,
                        ),
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
                    const SizedBox(height: 3),
                    Text(
                      businessRoleDefinition.department,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: roleColor,
                        fontWeight: FontWeight.w700,
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
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _buildAppAccessBadge(
                          label: 'İş Takip',
                          roleLabel:
                              workActive
                                  ? UserAccessCatalog.roleFor(
                                    'is_takip',
                                    workRole,
                                  ).label
                                  : 'Kapalı',
                          active: workActive,
                          icon: Icons.assignment_turned_in_outlined,
                          color: AppColors.corporateNavy,
                        ),
                        _buildAppAccessBadge(
                          label: 'Teklif',
                          roleLabel:
                              quoteActive
                                  ? UserAccessCatalog.roleFor(
                                    'teklif',
                                    quoteRole,
                                  ).label
                                  : 'Kapalı',
                          active: quoteActive,
                          icon: Icons.request_quote_outlined,
                          color: Colors.green.shade700,
                        ),
                      ],
                    ),
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
              if (isSaving)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.tune_rounded, color: Colors.grey.shade500, size: 21),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppAccessBadge({
    required String label,
    required String roleLabel,
    required bool active,
    required IconData icon,
    required Color color,
  }) {
    final effectiveColor = active ? color : Colors.grey.shade600;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: effectiveColor),
          const SizedBox(width: 6),
          Text(
            '$label · $roleLabel',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _getBusinessRoleColor(String role) {
    switch (role) {
      case 'owner':
        return Colors.red.shade700;
      case 'general_manager':
        return Colors.deepOrange.shade700;
      case 'sales_representative':
        return Colors.green.shade700;
      case 'technical_manager':
        return Colors.indigo.shade700;
      case 'technician':
        return Colors.blue.shade700;
      case 'customer_admin':
      case 'customer_user':
        return Colors.purple.shade700;
      default:
        return Colors.blueGrey;
    }
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

  String _businessRoleForUser(UserProfile user) {
    final accesses = _appAccessByUser[user.id] ?? const {};
    final workAccess = accesses['is_takip'];
    final quoteAccess = accesses['teklif'];
    return UserAccessCatalog.inferBusinessRole(
      profileRole: workAccess?.appRole ?? user.role,
      teklifActive: quoteAccess?.isActive ?? false,
      teklifRole: quoteAccess?.appRole ?? 'viewer',
    );
  }

  int _roleSortIndex(String role) {
    switch (role) {
      case UserRole.pending:
        return 0;
      case 'owner':
        return 1;
      case 'general_manager':
        return 2;
      case 'sales_representative':
        return 3;
      case 'technical_manager':
        return 4;
      case 'technician':
        return 5;
      case 'customer_admin':
        return 6;
      case 'customer_user':
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

}
