import 'package:flutter/material.dart';

import '../models/partner.dart';
import '../models/user_app_access.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';

class UserAccessEditorDialog extends StatefulWidget {
  const UserAccessEditorDialog({
    super.key,
    required this.user,
    required this.initialDraft,
    required this.partners,
    required this.isCurrentUser,
    required this.readOnly,
  });

  final UserProfile user;
  final UserAccessDraft initialDraft;
  final List<Partner> partners;
  final bool isCurrentUser;
  final bool readOnly;

  @override
  State<UserAccessEditorDialog> createState() => _UserAccessEditorDialogState();
}

class _UserAccessEditorDialogState extends State<UserAccessEditorDialog> {
  late bool _isTakipActive;
  late String _isTakipRole;
  late bool _teklifActive;
  late String _teklifRole;
  int? _partnerId;

  @override
  void initState() {
    super.initState();
    _isTakipActive = widget.initialDraft.isTakipActive;
    _isTakipRole = widget.initialDraft.isTakipRole;
    _teklifActive = widget.initialDraft.teklifActive;
    _teklifRole = widget.initialDraft.teklifRole;
    _partnerId = widget.initialDraft.partnerId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 760;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 32,
        vertical: compact ? 16 : 28,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.readOnly) _buildReadOnlyNotice(),
                    if (widget.isCurrentUser) _buildSelfNotice(),
                    if (compact) ...[
                      _buildAppAccessCard(
                        appCode: 'is_takip',
                        title: 'İş Takip',
                        subtitle: 'Servis, iş emri, ekip ve stok operasyonları',
                        icon: Icons.assignment_turned_in_outlined,
                        color: AppColors.corporateNavy,
                      ),
                      const SizedBox(height: 14),
                      _buildAppAccessCard(
                        appCode: 'teklif',
                        title: 'Teklif',
                        subtitle: 'Satış, keşif, cari ve teklif operasyonları',
                        icon: Icons.request_quote_outlined,
                        color: const Color(0xFF2F8F72),
                      ),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildAppAccessCard(
                              appCode: 'is_takip',
                              title: 'İş Takip',
                              subtitle:
                                  'Servis, iş emri, ekip ve stok operasyonları',
                              icon: Icons.assignment_turned_in_outlined,
                              color: AppColors.corporateNavy,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildAppAccessCard(
                              appCode: 'teklif',
                              title: 'Teklif',
                              subtitle:
                                  'Satış, keşif, cari ve teklif operasyonları',
                              icon: Icons.request_quote_outlined,
                              color: const Color(0xFF2F8F72),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.corporateNavy.withValues(alpha: 0.10),
            child: Text(
              widget.user.displayName.isEmpty
                  ? '?'
                  : widget.user.displayName[0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.corporateNavy,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.corporateNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.user.email ?? 'E-posta bilgisi yok',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kapat',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyNotice() {
    return _notice(
      icon: Icons.lock_outline_rounded,
      text:
          'Yönetici rolündeki bir kullanıcıyı yalnızca sistem yöneticisi düzenleyebilir.',
      color: Colors.orange.shade800,
    );
  }

  Widget _buildSelfNotice() {
    return _notice(
      icon: Icons.shield_outlined,
      text:
          'Kendi İş Takip erişiminizi kapatamaz veya yönetici yetkinizi düşüremezsiniz.',
      color: Colors.blue.shade800,
    );
  }

  Widget _notice({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppAccessCard({
    required String appCode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isWorkTracking = appCode == 'is_takip';
    final active = isWorkTracking ? _isTakipActive : _teklifActive;
    final role = isWorkTracking ? _isTakipRole : _teklifRole;
    final roles =
        isWorkTracking
            ? UserAccessCatalog.isTakipRoles
            : UserAccessCatalog.teklifRoles;
    final roleDefinition = UserAccessCatalog.roleFor(appCode, role);
    final lockSelfAccess = isWorkTracking && widget.isCurrentUser;
    final controlsEnabled = !widget.readOnly;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            active
                ? color.withValues(alpha: 0.055)
                : Colors.grey.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              active
                  ? color.withValues(alpha: 0.32)
                  : Colors.grey.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.corporateNavy,
                      ),
                    ),
                    Text(
                      active ? 'Erişim açık' : 'Erişim kapalı',
                      style: TextStyle(
                        fontSize: 12,
                        color: active ? color : Colors.grey.shade600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: active,
                activeThumbColor: color,
                onChanged:
                    !controlsEnabled || lockSelfAccess
                        ? null
                        : (value) {
                          setState(() {
                            if (isWorkTracking) {
                              _isTakipActive = value;
                            } else {
                              _teklifActive = value;
                            }
                          });
                        },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey('$appCode-$role-$active'),
            initialValue: role,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Uygulama rolü',
              prefixIcon: Icon(Icons.badge_outlined, size: 20),
            ),
            items: roles
                .map(
                  (item) => DropdownMenuItem(
                    value: item.code,
                    child: Text(item.label, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            onChanged:
                !controlsEnabled || !active
                    ? null
                    : (value) {
                      if (value == null) return;
                      setState(() {
                        if (isWorkTracking) {
                          _isTakipRole = value;
                          if (value != UserRole.partnerUser) _partnerId = null;
                        } else {
                          _teklifRole = value;
                        }
                      });
                    },
          ),
          if (isWorkTracking &&
              active &&
              _isTakipRole == UserRole.partnerUser) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('partner-${_partnerId ?? 'none'}'),
              initialValue: _partnerId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Bağlı partner firma',
                prefixIcon: Icon(Icons.business_outlined, size: 20),
              ),
              items: widget.partners
                  .map(
                    (partner) => DropdownMenuItem(
                      value: partner.id,
                      child: Text(
                        partner.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged:
                  !controlsEnabled
                      ? null
                      : (value) => setState(() => _partnerId = value),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            roleDefinition.description,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Color(0xFF536475),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: roleDefinition.permissions
                .map(
                  (permission) => Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(Icons.check_rounded, size: 15, color: color),
                    label: Text(
                      permission,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Vazgeç'),
          ),
          FilledButton.icon(
            onPressed: widget.readOnly ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.corporateNavy,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            ),
            icon: const Icon(Icons.save_outlined, size: 19),
            label: const Text('Yetkileri Kaydet'),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (_isTakipActive &&
        _isTakipRole == UserRole.partnerUser &&
        _partnerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner kullanıcı için firma seçin.')),
      );
      return;
    }

    Navigator.of(context).pop(
      UserAccessDraft(
        isTakipActive: _isTakipActive,
        isTakipRole: _isTakipRole,
        teklifActive: _teklifActive,
        teklifRole: _teklifRole,
        partnerId: _partnerId,
      ),
    );
  }
}
