import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ticket_list_page.dart';
import 'ticket_detail_page.dart';
import 'archived_tickets_page.dart';
import 'stock_overview_page.dart';
import 'partner_management_page.dart';
import 'user_management_page.dart';
import '../features/admin/application/admin_access_controller.dart';
import '../models/ticket_status.dart';
import '../widgets/access_denied_view.dart';
import '../widgets/sidebar/app_layout.dart';
import '../services/permission_service.dart';
import '../services/partner_service.dart';
import '../models/user_profile.dart';
import '../theme/app_colors.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  /*

  Color _panelSurface(bool isDark) {
    return Theme.of(context).cardColor;
  }

  Color _panelBorder(bool isDark) {
    return isDark ? AppColors.borderDark : AppColors.borderSubtle;
  }

  Color _mutedText(bool isDark) {
    return isDark ? AppColors.textOnDarkMuted : AppColors.textLight;
  }

  Widget _buildPanelCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _panelSurface(isDark),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _panelBorder(isDark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.10 : 0.035),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String subtitle, {
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: _mutedText(isDark)),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 16), trailing],
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? accent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tone = accent ?? AppColors.corporateBlue;
    final foreground = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tone.withOpacity(isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tone.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: tone),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveHeader(bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : AppColors.textDark;
    final totalAttention =
        _overdueTicketCount +
        _stockWaitingCount +
        _missingSignatureCount +
        _lowStockItems.length;

    final summaryItems = [
      'Bugun tamamlanan: $_completedTodayCount',
      'Geciken is: $_overdueTicketCount',
      'Aktif partner: $_activePartnerCount',
      'Saha ekibi: $_technicianCount',
    ];

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildQuickActionButton(
          label: 'Is listesi',
          icon: Icons.list_alt_outlined,
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TicketListPage()));
          },
        ),
        _buildQuickActionButton(
          label: 'Biten isler',
          icon: Icons.archive_outlined,
          accent: AppColors.statusDone,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ArchivedTicketsPage()),
            );
          },
        ),
        _buildQuickActionButton(
          label: 'Stok durumu',
          icon: Icons.inventory_2_outlined,
          accent: AppColors.corporateYellow,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StockOverviewPage()),
            );
          },
        ),
        _buildQuickActionButton(
          label: 'Kullanicilar',
          icon: Icons.people_outline,
          accent: Colors.teal,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UserManagementPage()),
            );
          },
        ),
        _buildQuickActionButton(
          label: 'Partnerler',
          icon: Icons.business_outlined,
          accent: Colors.deepPurple,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PartnerManagementPage()),
            );
          },
        ),
      ],
    );

    return _buildPanelCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operasyon Ozeti',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: _mutedText(isDark),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Bugun hangi alana mudahale edilmesi gerektigini tek ekranda gosterir.',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: primaryText,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        totalAttention > 0
                            ? '$totalAttention kayit yonetsel takip istiyor.'
                            : 'Su an kritik mudahale gerektiren kayit gorunmuyor.',
                        style: TextStyle(
                          fontSize: 14,
                          color: _mutedText(isDark),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children:
                            summaryItems.map((item) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? const Color(0xFF102131)
                                          : AppColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _panelBorder(isDark),
                                  ),
                                ),
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: primaryText,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hizli aksiyonlar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      actions,
                    ],
                  ),
                ),
              ],
            )
          else ...[
            Text(
              'Operasyon Ozeti',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: _mutedText(isDark),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Yonetici paneli',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              totalAttention > 0
                  ? '$totalAttention kayit takip istiyor.'
                  : 'Kritik mudahale gerektiren kayit gorunmuyor.',
              style: TextStyle(fontSize: 14, color: _mutedText(isDark)),
            ),
            const SizedBox(height: 16),
            actions,
          ],
        ],
      ),
    );
  }

*/
  /*
  Color _panelSurface(bool isDark) {
    return isDark ? const Color(0xFF162533) : AppColors.surfaceWhite;
  }

  Color _panelBorder(bool isDark) {
    return isDark ? const Color(0xFF2B3A47) : AppColors.borderSubtle;
  }

  Color _mutedText(bool isDark) {
    return isDark ? const Color(0xFFB1C0CF) : AppColors.textLight;
  }

  Widget _buildPanelCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _panelSurface(isDark),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _panelBorder(isDark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.10 : 0.035),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String subtitle, {
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.corporateNavy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: _mutedText(isDark)),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 16), trailing],
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? accent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tone = accent ?? AppColors.corporateBlue;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tone.withOpacity(isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tone.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: tone),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveHeader(bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : AppColors.textDark;
    final totalAttention =
        _overdueTicketCount +
        _stockWaitingCount +
        _missingSignatureCount +
        _lowStockItems.length;

    final summaryItems = [
      'Bugun tamamlanan: $_completedTodayCount',
      'Geciken is: $_overdueTicketCount',
      'Aktif partner: $_activePartnerCount',
      'Saha ekibi: $_technicianCount',
    ];

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildQuickActionButton(
          label: 'Is listesi',
          icon: Icons.list_alt_outlined,
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TicketListPage()));
          },
        ),
        _buildQuickActionButton(
          label: 'Biten isler',
          icon: Icons.archive_outlined,
          accent: AppColors.statusDone,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ArchivedTicketsPage()),
            );
          },
        ),
        _buildQuickActionButton(
          label: 'Stok durumu',
          icon: Icons.inventory_2_outlined,
          accent: AppColors.corporateYellow,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StockOverviewPage()),
            );
          },
        ),
        _buildQuickActionButton(
          label: 'Kullanicilar',
          icon: Icons.people_outline,
          accent: Colors.teal,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UserManagementPage()),
            );
          },
        ),
        _buildQuickActionButton(
          label: 'Partnerler',
          icon: Icons.business_outlined,
          accent: Colors.deepPurple,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PartnerManagementPage()),
            );
          },
        ),
      ],
    );

    return _buildPanelCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operasyon Ozeti',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: _mutedText(isDark),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Bugun hangi alana mudahale edilmesi gerektigini tek ekranda gosterir.',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: primaryText,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        totalAttention > 0
                            ? '$totalAttention kayit yonetsel takip istiyor.'
                            : 'Su an kritik mudahale gerektiren kayit gorunmuyor.',
                        style: TextStyle(
                          fontSize: 14,
                          color: _mutedText(isDark),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children:
                            summaryItems.map((item) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? const Color(0xFF102131)
                                          : AppColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _panelBorder(isDark),
                                  ),
                                ),
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: primaryText,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hizli aksiyonlar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      actions,
                    ],
                  ),
                ),
              ],
            )
          else ...[
            Text(
              'Operasyon Ozeti',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: _mutedText(isDark),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Yonetici paneli',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              totalAttention > 0
                  ? '$totalAttention kayit takip istiyor.'
                  : 'Kritik mudahale gerektiren kayit gorunmuyor.',
              style: TextStyle(fontSize: 14, color: _mutedText(isDark)),
            ),
            const SizedBox(height: 16),
            actions,
          ],
        ],
      ),
    );
  }

*/
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _supabase = Supabase.instance.client;
  final _adminAccessController = AdminAccessController();
  final PartnerService _partnerService = PartnerService();

  // User Profile - Loaded first
  UserProfile? _currentUser;

  // Loading & Error States
  bool _isLoading = true;
  String? _errorMessage;

  // Dashboard Statistics
  int _monthlyTicketCount = 0;
  int _openTicketCount = 0;
  int _completedTodayCount = 0;
  int _overdueTicketCount = 0;
  int _stockWaitingCount = 0;
  int _missingSignatureCount = 0;
  int _technicianCount = 0;
  int _activePartnerCount = 0;
  int _recentOpenCount = 0;
  int _recentInProgressCount = 0;
  int _recentPanelStockCount = 0;
  int _recentPanelSentCount = 0;

  // Dashboard Data Lists
  List<Map<String, dynamic>> _lowStockItems = [];
  List<Map<String, dynamic>> _recentTickets = [];
  List<Map<String, dynamic>> _partnerOverview = [];

  Color _panelSurface(bool isDark) {
    return isDark ? const Color(0xFF162533) : AppColors.surfaceWhite;
  }

  Color _panelBorder(bool isDark) {
    return isDark ? const Color(0xFF2B3A47) : AppColors.borderSubtle;
  }

  Color _mutedText(bool isDark) {
    return isDark ? const Color(0xFFB1C0CF) : AppColors.textLight;
  }

  Widget _buildPanelCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RepaintBoundary(
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _panelSurface(isDark),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _panelBorder(isDark)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.10 : 0.035),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String subtitle, {
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.corporateNavy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: _mutedText(isDark)),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 16), trailing],
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? accent,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tone = accent ?? AppColors.corporateBlue;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tone.withOpacity(isDark ? 0.16 : 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tone.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: tone),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutiveHeader(bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : AppColors.textDark;
    final totalAttention =
        _overdueTicketCount +
        _stockWaitingCount +
        _missingSignatureCount +
        _lowStockItems.length;

    final summaryItems = [
      'Bugun tamamlanan: $_completedTodayCount',
      'Geciken is: $_overdueTicketCount',
      'Aktif partner: $_activePartnerCount',
      'Saha ekibi: $_technicianCount',
    ];

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildQuickActionButton(
          label: 'Is listesi',
          icon: Icons.list_alt_outlined,
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TicketListPage()));
          },
        ),
        _buildQuickActionButton(
          label: 'Biten isler',
          icon: Icons.archive_outlined,
          accent: AppColors.statusDone,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ArchivedTicketsPage()),
            );
          },
        ),
        _buildQuickActionButton(
          label: 'Stok durumu',
          icon: Icons.inventory_2_outlined,
          accent: AppColors.corporateYellow,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StockOverviewPage()),
            );
          },
        ),
        _buildQuickActionButton(
          label: 'Kullanicilar',
          icon: Icons.people_outline,
          accent: Colors.teal,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UserManagementPage()),
            );
          },
        ),
        _buildQuickActionButton(
          label: 'Partnerler',
          icon: Icons.business_outlined,
          accent: Colors.deepPurple,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PartnerManagementPage()),
            );
          },
        ),
      ],
    );

    return _buildPanelCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operasyon Ozeti',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: _mutedText(isDark),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Bugun hangi alana mudahale edilmesi gerektigini tek ekranda gosterir.',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: primaryText,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        totalAttention > 0
                            ? '$totalAttention kayit yonetsel takip istiyor.'
                            : 'Su an kritik mudahale gerektiren kayit gorunmuyor.',
                        style: TextStyle(
                          fontSize: 14,
                          color: _mutedText(isDark),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children:
                            summaryItems.map((item) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isDark
                                          ? const Color(0xFF102131)
                                          : AppColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _panelBorder(isDark),
                                  ),
                                ),
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: primaryText,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hizli aksiyonlar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      actions,
                    ],
                  ),
                ),
              ],
            )
          else ...[
            Text(
              'Operasyon Ozeti',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: _mutedText(isDark),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Yonetici paneli',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              totalAttention > 0
                  ? '$totalAttention kayit takip istiyor.'
                  : 'Kritik mudahale gerektiren kayit gorunmuyor.',
              style: TextStyle(fontSize: 14, color: _mutedText(isDark)),
            ),
            const SizedBox(height: 16),
            actions,
          ],
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  /// Sequential Loading: First load user profile, then dashboard data
  Future<void> _initDashboard() async {
    try {
      // Step 1: Load user profile first (CRITICAL)
      final accessState = await _adminAccessController.load();
      final profile = accessState.profile;

      if (!mounted) return;

      if (accessState.profile == null) {
        setState(() {
          _errorMessage =
              accessState.errorMessage ?? 'Kullanici profili bulunamadi.';
          _isLoading = false;
        });
        return;
      }

      if (!accessState.hasAccess) {
        setState(() {
          _errorMessage = 'Kullanıcı profili bulunamadı.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _currentUser = profile;
      });

      // Step 2: Only after user profile is loaded, fetch dashboard data
      await _loadDashboardData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Dashboard yüklenirken hata oluştu: ${e.toString()}';
          _isLoading = false;
        });
        _showErrorSnackBar('Veri yüklenirken hata oluştu');
      }
    }
  }

  /// Load all dashboard data with optimized queries
  Future<void> _loadDashboardData() async {
    if (_currentUser == null) return;

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfNextMonth = DateTime(now.year, now.month + 1, 1);

      // 1. Monthly Tickets Count - Using count() for performance
      final monthlyTicketsCount = await _supabase
          .from('tickets')
          .select('id')
          .gte('created_at', startOfMonth.toIso8601String())
          .lt('created_at', startOfNextMonth.toIso8601String())
          .count(CountOption.exact);

      // 2. Open Tickets Count - Using count() for performance
      final openTicketsCount = await _supabase
          .from('tickets')
          .select('id')
          .eq('status', 'open')
          .count(CountOption.exact);

      final technicianCount = await _supabase
          .from('profiles')
          .select('id')
          .inFilter('role', [
            UserRole.technician,
            UserRole.engineer,
            UserRole.supervisor,
          ])
          .count(CountOption.exact);

      final overdueTicketsCount = await _supabase
          .from('tickets')
          .select('id')
          .lt('planned_date', now.toIso8601String())
          .neq('status', TicketStatus.done)
          .neq('status', TicketStatus.archived)
          .neq('status', TicketStatus.cancelled)
          .neq('status', TicketStatus.draft)
          .count(CountOption.exact);

      final stockWaitingCount = await _supabase
          .from('tickets')
          .select('id')
          .inFilter('status', [
            TicketStatus.panelDoneStock,
            'panel_done_waiting_stock',
            'stock_waiting',
          ])
          .count(CountOption.exact);

      int completedTodayCount = 0;
      try {
        final completedTodayResponse = await _supabase
            .from('tickets')
            .select('id')
            .eq('status', TicketStatus.done)
            .gte('updated_at', startOfDay.toIso8601String())
            .count(CountOption.exact);
        completedTodayCount = completedTodayResponse.count;
      } catch (_) {
        completedTodayCount = 0;
      }

      int missingSignatureCount = 0;
      try {
        final missingSignatureResponse = await _supabase
            .from('tickets')
            .select('id')
            .eq('status', TicketStatus.done)
            .or('signature_data.is.null,technician_signature_data.is.null')
            .count(CountOption.exact);
        missingSignatureCount = missingSignatureResponse.count;
      } catch (_) {
        missingSignatureCount = 0;
      }

      // 3. Recent Tickets with Partner Join - Optimized single query
      // Filters must come before order() and limit()
      var recentTicketsQuery = _supabase
          .from('tickets')
          .select('*, partners(name)');

      // Role-based filtering: Non-admin/manager users don't see draft tickets
      if (!PermissionService.hasPermission(
        _currentUser,
        AppPermission.viewDraftTickets,
      )) {
        recentTicketsQuery = recentTicketsQuery.neq('status', 'draft');
      }

      final recentTicketsResponse = await recentTicketsQuery
          .order('created_at', ascending: false)
          .limit(50);
      final recentTicketsList =
          (recentTicketsResponse as List).cast<Map<String, dynamic>>();

      // Count statuses from recent tickets
      int recentOpen = 0;
      int recentInProgress = 0;
      int recentPanelStock = 0;
      int recentPanelSent = 0;

      for (final t in recentTicketsList) {
        final status = t['status'] as String? ?? 'open';
        switch (status) {
          case 'open':
            recentOpen++;
            break;
          case 'in_progress':
            recentInProgress++;
            break;
          case 'panel_done_stock':
            recentPanelStock++;
            break;
          case 'panel_done_sent':
            recentPanelSent++;
            break;
        }
      }

      // 4. Partner Overview with optimized query
      final partnersResponse = await _partnerService.getAllPartners();

      var partnerTicketsQuery = _supabase
          .from('tickets')
          .select('id, partner_id, status, job_code, title')
          .not('partner_id', 'is', null)
          .neq('status', 'done');

      // Role-based filtering
      if (!PermissionService.hasPermission(
        _currentUser,
        AppPermission.viewDraftTickets,
      )) {
        partnerTicketsQuery = partnerTicketsQuery.neq('status', 'draft');
      }

      final partnerTicketsResponse = await partnerTicketsQuery;
      final partnerTicketsList =
          (partnerTicketsResponse as List).cast<Map<String, dynamic>>();

      final Map<int, Map<String, int>> partnerCounts = {};
      final Map<int, List<Map<String, dynamic>>> partnerOpenJobs = {};

      for (final t in partnerTicketsList) {
        final pid = t['partner_id'] as int?;
        final status = t['status'] as String? ?? 'open';
        if (pid == null) continue;

        partnerCounts.putIfAbsent(
          pid,
          () => {'total': 0, 'open': 0, 'in_progress': 0},
        );

        partnerCounts[pid]!['total'] = (partnerCounts[pid]!['total'] ?? 0) + 1;

        if (status == 'open') {
          partnerCounts[pid]!['open'] = (partnerCounts[pid]!['open'] ?? 0) + 1;
          partnerOpenJobs.putIfAbsent(pid, () => []);
          if (partnerOpenJobs[pid]!.length < 3) {
            partnerOpenJobs[pid]!.add({
              'id': t['id'],
              'job_code': t['job_code'],
              'title': t['title'],
            });
          }
        } else if (status == 'in_progress') {
          partnerCounts[pid]!['in_progress'] =
              (partnerCounts[pid]!['in_progress'] ?? 0) + 1;
        }
      }

      final List<Map<String, dynamic>> partnerOverview = [];
      for (final p in partnersResponse) {
        final counts = partnerCounts[p.id];
        if (counts == null) continue; // Skip partners with no active jobs

        partnerOverview.add({
          'id': p.id,
          'name': p.name,
          'total': counts['total'] ?? 0,
          'open': counts['open'] ?? 0,
          'in_progress': counts['in_progress'] ?? 0,
          'openJobs': (partnerOpenJobs[p.id] ?? []),
        });
      }
      partnerOverview.sort(
        (a, b) => (b['total'] as int).compareTo(a['total'] as int),
      );

      // 5. Low Stock Items
      final inventoryResponse = await _supabase
          .from('inventory')
          .select()
          .order('quantity', ascending: true)
          .limit(50);

      final List<Map<String, dynamic>> lowStock = [];
      final inventoryList =
          (inventoryResponse as List).cast<Map<String, dynamic>>();

      for (var item in inventoryList) {
        final qty = item['quantity'] as int? ?? 0;
        final critical = item['critical_level'] as int? ?? 5;

        if (qty <= critical) {
          lowStock.add(item);
        }
      }

      if (mounted) {
        setState(() {
          // Extract counts from Supabase count responses
          _monthlyTicketCount = monthlyTicketsCount.count;
          _openTicketCount = openTicketsCount.count;
          _completedTodayCount = completedTodayCount;
          _overdueTicketCount = overdueTicketsCount.count;
          _stockWaitingCount = stockWaitingCount.count;
          _missingSignatureCount = missingSignatureCount;
          _technicianCount = technicianCount.count;
          _activePartnerCount = partnerOverview.length;
          _recentOpenCount = recentOpen;
          _recentInProgressCount = recentInProgress;
          _recentPanelStockCount = recentPanelStock;
          _recentPanelSentCount = recentPanelSent;
          _recentTickets = recentTicketsList.take(8).toList();
          _partnerOverview = partnerOverview.take(6).toList();
          _lowStockItems = lowStock.take(10).toList();
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('Dashboard veri hatası: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Veri yüklenirken hata oluştu: ${e.toString()}';
        });
        _showErrorSnackBar('Veri yüklenirken hata oluştu');
      }
    }
  }

  /// Refresh dashboard data (for RefreshIndicator)
  Future<void> _refreshDashboard() async {
    await _loadDashboardData();
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Get dynamic appbar title based on user role
  String _getAppBarTitle() {
    if (_currentUser == null) return 'Yükleniyor...';

    if (_currentUser!.isAdmin) {
      return 'Yönetici Paneli';
    } else if (_currentUser!.isManager) {
      return 'Yönetici Paneli';
    } else if (_currentUser!.isTechnician) {
      return 'Teknisyen Paneli';
    } else {
      return 'Saha Yönetimi';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    if (!_isLoading && !PermissionService.canAccessAdminArea(_currentUser)) {
      return AppLayout(
        currentPage: AppPage.dashboard,
        userName: _currentUser?.displayName,
        userRole: _currentUser?.role,
        title: 'Yetkisiz Erişim',
        child: const AccessDeniedView(
          message:
              'Yonetici panelini yalnizca admin ve manager kullanicilar acabilir.',
        ),
      );
    }

    return AppLayout(
      currentPage: AppPage.dashboard,
      userName: _currentUser?.displayName,
      userRole: _currentUser?.role,
      title: _getAppBarTitle(),
      actions: [
        // Management menu (only for admin/manager)
        if (PermissionService.hasPermission(
          _currentUser,
          AppPermission.manageUsers,
        ))
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.corporateNavy),
            onSelected: (value) {
              switch (value) {
                case 'users':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const UserManagementPage(),
                    ),
                  );
                  break;
                case 'partners':
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PartnerManagementPage(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder:
                (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'users',
                    child: Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          color: AppColors.corporateNavy,
                        ),
                        SizedBox(width: 12),
                        Text('Kullanıcı Yönetimi'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'partners',
                    child: Row(
                      children: [
                        Icon(
                          Icons.business_rounded,
                          color: AppColors.corporateNavy,
                        ),
                        SizedBox(width: 12),
                        Text('Partner Firmalar'),
                      ],
                    ),
                  ),
                ],
          ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TicketListPage()),
          );
        },
        label: const Text('İş Emirleri Listesi'),
        icon: const Icon(Icons.list_alt),
        backgroundColor: AppColors.corporateNavy,
      ),
      child:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _initDashboard,
                      child: const Text('Yeniden Dene'),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _refreshDashboard,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildExecutiveHeader(isWide),
                      const SizedBox(height: 24),
                      _buildDecisionKpiSection(),
                      const SizedBox(height: 24),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildAttentionRequiredCard(),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 4,
                              child: _buildRecentActivityPanel(),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _buildAttentionRequiredCard(),
                            const SizedBox(height: 24),
                            _buildRecentActivityPanel(),
                          ],
                        ),
                      const SizedBox(height: 24),
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildOperationsOverviewPanel(),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 4,
                              child: _buildPartnerOperationsPanel(),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _buildOperationsOverviewPanel(),
                            const SizedBox(height: 24),
                            _buildPartnerOperationsPanel(),
                          ],
                        ),
                      const SizedBox(height: 24),
                      _buildInventoryAlertPanel(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildDecisionKpiSection() {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount =
        width >= 1500
            ? 6
            : width >= 1050
            ? 3
            : 2;

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      childAspectRatio: width >= 1050 ? 1.45 : 1.25,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Bu Ay Acilan',
          _monthlyTicketCount.toString(),
          Icons.calendar_month_outlined,
          AppColors.corporateBlue,
          subtitle: 'Aylik operasyon hacmi',
        ),
        _buildStatCard(
          'Acik Isler',
          _openTicketCount.toString(),
          Icons.assignment_late_outlined,
          Colors.orange,
          subtitle: 'Plan bekleyen veya aktif is',
        ),
        _buildStatCard(
          'Bugun Tamamlanan',
          _completedTodayCount.toString(),
          Icons.check_circle_outline,
          AppColors.statusDone,
          subtitle: 'Gunluk kapanan is emri',
        ),
        _buildStatCard(
          'Geciken Isler',
          _overdueTicketCount.toString(),
          Icons.crisis_alert_outlined,
          AppColors.corporateRed,
          subtitle: 'Plan tarihi gecmis aktif is',
        ),
        _buildStatCard(
          'Stok Bekleyen',
          _stockWaitingCount.toString(),
          Icons.inventory_outlined,
          Colors.purple,
          subtitle: 'Paneli hazir, sevk bekliyor',
        ),
        _buildStatCard(
          'Imzasi Eksik',
          _missingSignatureCount.toString(),
          Icons.draw_outlined,
          Colors.teal,
          subtitle: 'Tamamlandi ama imza eksik',
        ),
      ],
    );
  }

  Widget _buildAttentionRequiredCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      (
        title: 'Geciken isler',
        value: _overdueTicketCount,
        color: AppColors.corporateRed,
        detail: 'Plan tarihini gecmis aktif kayitlar.',
        icon: Icons.alarm_outlined,
      ),
      (
        title: 'Stok bekleyen isler',
        value: _stockWaitingCount,
        color: Colors.purple,
        detail: 'Panosu hazir ancak hala sevk bekleyen kayitlar.',
        icon: Icons.inventory_2_outlined,
      ),
      (
        title: 'Imzasi eksik tamamlananlar',
        value: _missingSignatureCount,
        color: Colors.teal,
        detail: 'Musteri veya teknisyen imzasi eksik kalan isler.',
        icon: Icons.border_color_outlined,
      ),
      (
        title: 'Kritik stok kalemi',
        value: _lowStockItems.length,
        color: Colors.orange,
        detail: 'Kritik seviyenin altinda kalan urunler.',
        icon: Icons.warning_amber_rounded,
      ),
    ];

    return _buildPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Mudahale gerektiren alanlar',
            'Yoneticiye ilk bakista aksiyon gerektiren basliklari gosterir.',
          ),
          const SizedBox(height: 18),
          ...items.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: item.color.withOpacity(isDark ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: item.color.withOpacity(0.16)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(item.icon, color: item.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark ? Colors.white : AppColors.corporateNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.detail,
                          style: TextStyle(
                            fontSize: 12,
                            color: _mutedText(isDark),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item.value.toString(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: item.color,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOperationsOverviewPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalRecent =
        _recentOpenCount +
        _recentInProgressCount +
        _recentPanelStockCount +
        _recentPanelSentCount;

    Widget buildRow(String label, int count, Color color) {
      final ratio = totalRecent > 0 ? count / totalRecent : 0.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
            ),
            SizedBox(
              width: 34,
              child: Text(
                '$count',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor:
                      isDark ? const Color(0xFF102131) : AppColors.surfaceMuted,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Operasyon dagilimi',
            'Son 50 kayitta islerin hangi asamada yogunlastigini gosterir.',
          ),
          const SizedBox(height: 18),
          if (totalRecent == 0)
            Text(
              'Gosterilecek operasyon kaydi bulunamadi.',
              style: TextStyle(color: _mutedText(isDark)),
            )
          else ...[
            buildRow('Acik', _recentOpenCount, AppColors.statusOpen),
            buildRow(
              'Serviste',
              _recentInProgressCount,
              AppColors.statusProgress,
            ),
            buildRow('Stokta', _recentPanelStockCount, AppColors.statusStock),
            buildRow('Gonderildi', _recentPanelSentCount, AppColors.statusSent),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentActivityPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String formatDate(String? raw) {
      if (raw == null || raw.isEmpty) return '-';
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return raw;
      return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
    }

    return _buildPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Son hareketler',
            'Yoneticinin hizlica goz atabilecegi son 8 is kaydi.',
          ),
          const SizedBox(height: 18),
          if (_recentTickets.isEmpty)
            Text(
              'Henuz kayit bulunmuyor.',
              style: TextStyle(color: _mutedText(isDark)),
            )
          else
            ..._recentTickets.map((ticket) {
              final status = ticket['status'] as String? ?? TicketStatus.open;
              final title = ticket['title'] as String? ?? 'Basliksiz';
              final plannedDate = ticket['planned_date'] as String?;
              final jobCode = ticket['job_code'] as String? ?? '---';
              final partnerData = ticket['partners'] as Map<String, dynamic>?;
              final partnerName = partnerData?['name'] as String?;
              final statusColor = _getStatusColor(status);

              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => TicketDetailPage(
                            ticketId: ticket['id'].toString(),
                          ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF102131)
                            : AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _panelBorder(isDark)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color:
                                    isDark ? Colors.white : AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                Text(
                                  jobCode,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _mutedText(isDark),
                                  ),
                                ),
                                Text(
                                  formatDate(plannedDate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _mutedText(isDark),
                                  ),
                                ),
                                if (partnerName != null &&
                                    partnerName.trim().isNotEmpty)
                                  Text(
                                    partnerName.trim(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPartnerOperationsPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Partner operasyon gorunumu',
            'Aktif isi olan partnerleri ve acik kayit baskisini gosterir.',
          ),
          const SizedBox(height: 18),
          if (_partnerOverview.isEmpty)
            Text(
              'Su anda partnerlere atanmis aktif is bulunmuyor.',
              style: TextStyle(color: _mutedText(isDark)),
            )
          else
            ..._partnerOverview.map((partner) {
              final total = partner['total'] as int? ?? 0;
              final open = partner['open'] as int? ?? 0;
              final inProgress = partner['in_progress'] as int? ?? 0;
              final openJobs =
                  (partner['openJobs'] as List<dynamic>? ?? [])
                      .cast<Map<String, dynamic>>();
              final ratio = total > 0 ? inProgress / total : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0xFF102131) : AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _panelBorder(isDark)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            partner['name'] as String? ?? '-',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$total aktif kayit',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Acik: $open   •   Serviste: $inProgress',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _mutedText(isDark),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor:
                            isDark
                                ? const Color(0xFF0D1B2A)
                                : AppColors.surfaceMuted,
                        color: Colors.deepPurple,
                      ),
                    ),
                    if (openJobs.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            openJobs.map((job) {
                              final code =
                                  (job['job_code'] as String?) ?? 'Kod yok';
                              return InkWell(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder:
                                          (_) => TicketDetailPage(
                                            ticketId: job['id'].toString(),
                                          ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    code,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildInventoryAlertPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildPanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Kritik stok listesi',
            'Sevki veya saha operasyonunu geciktirebilecek urunler.',
          ),
          const SizedBox(height: 18),
          if (_lowStockItems.isEmpty)
            Text(
              'Kritik seviyenin altinda urun bulunmuyor.',
              style: TextStyle(color: _mutedText(isDark)),
            )
          else
            ..._lowStockItems.map((item) {
              final qty = item['quantity'] as int? ?? 0;
              final critical = item['critical_level'] as int? ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0xFF102131) : AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _panelBorder(isDark)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? '-',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kritik seviye: $critical',
                            style: TextStyle(
                              fontSize: 12,
                              color: _mutedText(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.red.withOpacity(0.16)),
                      ),
                      child: Text(
                        '$qty adet',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSummarySection(bool isWide) {
    return GridView.count(
      crossAxisCount: isWide ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      childAspectRatio: 1.0,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          'Aylık Servis',
          _monthlyTicketCount.toString(),
          Icons.calendar_month,
          Colors.blue,
        ),
        _buildStatCard(
          'Açık İşler',
          _openTicketCount.toString(),
          Icons.assignment_late_outlined,
          Colors.orange,
        ),
        _buildStatCard(
          'Kritik Stok',
          _lowStockItems.length.toString(),
          Icons.inventory_2_outlined,
          Colors.red,
        ),
        _buildStatCard(
          'Personel',
          '5', // TODO: Fetch from users table if needed
          Icons.people_outline,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatusOverviewCard() {
    final totalRecent =
        _recentOpenCount +
        _recentInProgressCount +
        _recentPanelStockCount +
        _recentPanelSentCount;

    Widget buildRow(String label, int count, Color color) {
      final ratio = (totalRecent > 0) ? count / totalRecent : 0.0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text('$count', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade100,
                  color: color.withOpacity(0.9),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Durum Özeti (Son 50 İş)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.corporateNavy,
            ),
          ),
          const SizedBox(height: 12),
          if (totalRecent == 0)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Gösterilecek iş bulunamadı.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else ...[
            buildRow('Açık', _recentOpenCount, Colors.blue),
            buildRow('Serviste', _recentInProgressCount, Colors.orange),
            buildRow('Stokta (Pano)', _recentPanelStockCount, Colors.purple),
            buildRow('Gönderildi', _recentPanelSentCount, Colors.indigo),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentTicketsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Son İş Emirleri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.corporateNavy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'En son açılan 8 iş emri',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (_recentTickets.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Henüz iş emri açılmamış.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentTickets.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final t = _recentTickets[index];
                final status = t['status'] as String? ?? 'open';
                final title = t['title'] as String? ?? 'Başlıksız';
                final plannedDate = t['planned_date'] as String?;
                final jobCode = t['job_code'] as String? ?? '---';

                // Extract partner name from joined data
                final partnerData = t['partners'] as Map<String, dynamic>?;
                final partnerName = partnerData?['name'] as String?;

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) =>
                                TicketDetailPage(ticketId: t['id'].toString()),
                      ),
                    );
                  },
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            jobCode,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          if (plannedDate != null) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.calendar_today,
                              size: 11,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              plannedDate.substring(0, 10),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (partnerName != null &&
                          partnerName.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.handshake_outlined,
                              size: 11,
                              color: Colors.deepPurple,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                partnerName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _buildPanelCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : AppColors.corporateNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: _mutedText(isDark),
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPartnerOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Partner İş Durumu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.corporateNavy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Aktif işi bulunan partnerler',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (_partnerOverview.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Şu anda partnerlere atanmış aktif iş bulunmuyor.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _partnerOverview.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = _partnerOverview[index];
                final total = p['total'] as int? ?? 0;
                final open = p['open'] as int? ?? 0;
                final inProgress = p['in_progress'] as int? ?? 0;
                final ratio = total > 0 ? inProgress / total : 0.0;

                final openJobs =
                    (p['openJobs'] as List<dynamic>? ?? [])
                        .cast<Map<String, dynamic>>();

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    p['name'] as String? ?? '-',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Açık: $open',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Serviste: $inProgress',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (openJobs.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children:
                              openJobs.map((job) {
                                final code =
                                    (job['job_code'] as String?) ?? 'Kod yok';
                                return InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder:
                                            (_) => TicketDetailPage(
                                              ticketId: job['id'].toString(),
                                            ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.deepPurple.withOpacity(
                                        0.06,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      code,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.deepPurple,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 6),
                      ],
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade100,
                          color: Colors.purpleAccent.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'İş',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLowStockCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Stok Uyarı Listesi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.corporateNavy,
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          if (_lowStockItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Kritik seviyenin altında ürün yok.',
                style: TextStyle(color: Colors.green),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _lowStockItems.length,
              separatorBuilder: (ctx, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _lowStockItems[index];
                final qty = item['quantity'] as int? ?? 0;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    item['name'] ?? '-',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      '$qty Adet',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // Status label and colors (consistent with ticket list)
  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Açık';
      case 'done':
        return 'Bitti';
      case 'in_progress':
        return 'Serviste';
      case 'panel_done_stock':
        return 'Stokta';
      case 'panel_done_sent':
        return 'Gönderildi';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return Colors.blue;
      case 'done':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'panel_done_stock':
        return Colors.purple;
      case 'panel_done_sent':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}
