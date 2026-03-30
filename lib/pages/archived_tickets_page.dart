import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/pdf_export_service.dart';
import '../services/permission_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../widgets/sidebar/app_layout.dart';
import '../widgets/ui/ui.dart';
import 'edit_ticket_page.dart';
import 'pdf_viewer_page.dart';
import 'ticket_detail_page.dart';

class ArchivedTicketsPage extends StatefulWidget {
  const ArchivedTicketsPage({super.key});

  @override
  State<ArchivedTicketsPage> createState() => _ArchivedTicketsPageState();
}

class _ArchivedTicketsPageState extends State<ArchivedTicketsPage> {
  late Future<List<Map<String, dynamic>>> _ticketsFuture;

  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();

  String _searchText = '';
  String _priorityFilter = 'all';
  String? _userRole;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _ticketsFuture = _fetchArchivedTickets();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final profile = await _userService.getCurrentUserProfile();
    if (!mounted) return;

    setState(() {
      _userRole = profile?.role;
      _userName = profile?.displayName;
    });
  }

  Future<List<Map<String, dynamic>>> _fetchArchivedTickets() async {
    final response = await Supabase.instance.client
        .from('tickets')
        .select('''
              id,
              job_code,
              title,
              description,
              status,
              priority,
              planned_date,
              device_model,
              device_brand,
              signature_data,
              technician_signature_data,
              archived_at,
              created_at,
              partners (
                id,
                name
              ),
              customers (
                id,
                name,
                address
              )
            ''')
        .eq('status', 'done')
        .order('archived_at', ascending: false)
        .order('created_at', ascending: false);

    final List data = response as List;
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> _refresh() async {
    setState(() {
      _ticketsFuture = _fetchArchivedTickets();
    });
  }

  bool get _canManageTickets => PermissionService.roleHasPermission(
    _userRole,
    AppPermission.manageArchivedTickets,
  );

  Future<void> _deleteTicket(String ticketId) async {
    if (!_canManageTickets) {
      _showSnack('Bu islem icin yetkiniz yok.', isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Kaydi Sil'),
            content: const Text(
              'Arsivdeki bu isi kalici olarak silmek istiyor musunuz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Iptal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sil'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final idValue = int.tryParse(ticketId) ?? ticketId;
    await Supabase.instance.client.from('tickets').delete().eq('id', idValue);

    if (!mounted) return;
    _showSnack('Kayit silindi.');
    await _refresh();
  }

  Future<void> _openDetail(String ticketId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TicketDetailPage(ticketId: ticketId)),
    );
    await _refresh();
  }

  Future<void> _editTicket(String ticketId) async {
    if (!_canManageTickets) {
      _showSnack('Bu is icin duzenleme yetkiniz yok.', isError: true);
      return;
    }

    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditTicketPage(ticketId: ticketId)),
    );

    if (updated == true) {
      await _refresh();
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.corporateRed : null,
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'done':
        return 'Tamamlandi';
      case 'in_progress':
        return 'Serviste';
      case 'open':
        return 'Acik';
      default:
        return status;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'low':
        return 'Dusuk';
      case 'normal':
        return 'Normal';
      case 'high':
        return 'Yuksek';
      default:
        return priority;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return AppColors.corporateRed;
      case 'normal':
        return AppColors.corporateYellow;
      case 'low':
        return AppColors.statusDone;
      default:
        return AppColors.textLight;
    }
  }

  String _normalizeTurkish(String text) {
    if (text.isEmpty) return '';

    return text
        .toLowerCase()
        .replaceAll('i', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .trim();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> tickets) {
    final search = _normalizeTurkish(_searchText);

    return tickets.where((ticket) {
      final priority = (ticket['priority'] as String?) ?? '';
      final title = (ticket['title'] as String?) ?? '';
      final jobCode = (ticket['job_code'] as String?) ?? '';
      final customer =
          ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final customerName = (customer['name'] as String?) ?? '';
      final partner =
          ticket['partners'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final partnerName = (partner['name'] as String?) ?? '';

      if (_priorityFilter != 'all' && priority != _priorityFilter) {
        return false;
      }

      if (search.isNotEmpty) {
        final combined = _normalizeTurkish(
          '$title $customerName $partnerName $jobCode',
        );
        if (!combined.contains(search)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '-';
    return DateFormat('dd.MM.yyyy').format(parsed.toLocal());
  }

  int _recentArchiveCount(List<Map<String, dynamic>> tickets) {
    final threshold = DateTime.now().subtract(const Duration(days: 30));

    return tickets.where((ticket) {
      final archivedAt = ticket['archived_at'] as String?;
      final parsed = archivedAt == null ? null : DateTime.tryParse(archivedAt);
      return parsed != null && parsed.isAfter(threshold);
    }).length;
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return UiCard(
      tone: UiCardTone.muted,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.textOnDark : AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        isDark
                            ? AppColors.textOnDarkMuted
                            : AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPanel(
    List<Map<String, dynamic>> tickets,
    List<Map<String, dynamic>> filteredTickets,
  ) {
    final highPriorityCount =
        tickets.where((ticket) => ticket['priority'] == 'high').length;
    final recentCount = _recentArchiveCount(tickets);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UiCard(
          tone: UiCardTone.accent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Arsiv gorunumu',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Biten isleri daha hizli tarayabilmeniz icin arama, oncelik ve tarih bilgisini ozetli gosteriyoruz.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      isDark ? AppColors.textOnDarkMuted : AppColors.textLight,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 220,
                    child: _buildSummaryCard(
                      label: 'Toplam arsiv kaydi',
                      value: tickets.length.toString(),
                      icon: Icons.archive_outlined,
                      color: AppColors.statusArchived,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _buildSummaryCard(
                      label: 'Son 30 gun',
                      value: recentCount.toString(),
                      icon: Icons.history_rounded,
                      color: AppColors.corporateBlue,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _buildSummaryCard(
                      label: 'Yuksek oncelik',
                      value: highPriorityCount.toString(),
                      icon: Icons.flag_outlined,
                      color: AppColors.corporateRed,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _buildSummaryCard(
                      label: 'Gorunen sonuc',
                      value: filteredTickets.length.toString(),
                      icon: Icons.filter_alt_outlined,
                      color: AppColors.statusDone,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        UiCard(
          tone: UiCardTone.base,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filtreler',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Baslik, musteri veya is kodu ara',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _priorityFilter,
                      decoration: const InputDecoration(labelText: 'Oncelik'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Tumu')),
                        DropdownMenuItem(value: 'low', child: Text('Dusuk')),
                        DropdownMenuItem(
                          value: 'normal',
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('Yuksek')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _priorityFilter = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  UiSecondaryButton(
                    label: 'Temizle',
                    icon: Icons.restart_alt_rounded,
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchText = '';
                        _priorityFilter = 'all';
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArchiveCard(Map<String, dynamic> ticket) {
    final isWide = MediaQuery.of(context).size.width >= 860;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customer =
        ticket['customers'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final title = (ticket['title'] as String?) ?? 'Baslik yok';
    final customerName = (customer['name'] as String?) ?? 'Musteri bilgisi yok';
    final customerAddress = (customer['address'] as String?) ?? '';
    final jobCode = (ticket['job_code'] as String?) ?? '---';
    final deviceBrand = (ticket['device_brand'] as String?) ?? '';
    final deviceModel = (ticket['device_model'] as String?) ?? '';
    final status = (ticket['status'] as String?) ?? '';
    final priority = (ticket['priority'] as String?) ?? '';
    final plannedDate = _formatDate(ticket['planned_date'] as String?);
    final archivedDate = _formatDate(ticket['archived_at'] as String?);
    final priorityColor = _priorityColor(priority);
    final id = ticket['id'].toString();

    final meta = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildInfoChip(
          icon: Icons.check_circle_outline,
          label: _statusLabel(status),
          color: AppColors.statusDone,
        ),
        _buildInfoChip(
          icon: Icons.flag_outlined,
          label: _priorityLabel(priority),
          color: priorityColor,
        ),
        _buildInfoChip(
          icon: Icons.event_outlined,
          label: 'Plan: $plannedDate',
          color: AppColors.corporateBlue,
        ),
        _buildInfoChip(
          icon: Icons.archive_outlined,
          label: 'Arsiv: $archivedDate',
          color: AppColors.statusArchived,
        ),
      ],
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.statusDone.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.statusDone.withOpacity(0.18),
                ),
              ),
              child: const Icon(
                Icons.task_alt_rounded,
                color: AppColors.statusDone,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.textOnDark : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark
                              ? AppColors.textOnDarkMuted
                              : AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        meta,
        if (deviceBrand.isNotEmpty || deviceModel.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            [
              deviceBrand,
              deviceModel,
            ].where((item) => item.isNotEmpty).join(' / '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textOnDarkMuted : AppColors.textLight,
            ),
          ),
        ],
        if (customerAddress.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            customerAddress,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? AppColors.textOnDarkMuted : AppColors.textLight,
            ),
          ),
        ],
      ],
    );

    final sidePanel = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color:
                isDark ? AppColors.surfaceDarkMuted : AppColors.surfaceAccent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Is Kodu',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      isDark ? AppColors.textOnDarkMuted : AppColors.textLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                jobCode,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.textOnDark : AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PopupMenuButton<String>(
          tooltip: 'Islemler',
          onSelected: (value) {
            switch (value) {
              case 'detail':
                _openDetail(id);
                break;
              case 'edit':
                _editTicket(id);
                break;
              case 'delete':
                _deleteTicket(id);
                break;
            }
          },
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'detail',
                child: Text('Detayi ac'),
              ),
            ];

            if (_canManageTickets) {
              items.add(
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Duzenle'),
                ),
              );
              items.add(
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Sil'),
                ),
              );
            }

            return items;
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.surfaceDarkMuted : AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderSubtle,
              ),
            ),
            child: Icon(
              Icons.more_horiz_rounded,
              color: isDark ? AppColors.textOnDark : AppColors.textDark,
            ),
          ),
        ),
      ],
    );

    return UiCard(
      onTap: () => _openDetail(id),
      child:
          isWide
              ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 18),
                  SizedBox(width: 140, child: sidePanel),
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  details,
                  const SizedBox(height: 16),
                  Row(children: [Expanded(child: sidePanel)]),
                ],
              ),
    );
  }

  Future<void> _openPdf(List<Map<String, dynamic>> tickets) async {
    if (tickets.isEmpty) return;

    final uniquePartners =
        tickets
            .map((ticket) {
              final partner =
                  ticket['partners'] as Map<String, dynamic>? ??
                  <String, dynamic>{};
              return ((partner['name'] as String?) ?? '').trim();
            })
            .where((name) => name.isNotEmpty)
            .toSet();

    final partnerName =
        uniquePartners.length == 1 ? uniquePartners.first : null;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PdfViewerPage(
              title: 'Biten Isler',
              pdfFileName:
                  'Biten_Isler_${DateTime.now().toIso8601String().substring(0, 10)}.pdf',
              pdfGenerator:
                  () => PdfExportService.generateTicketListPdfBytesFromList(
                    tickets: tickets,
                    reportTitle: 'Biten Isler Listesi',
                    partnerName: partnerName,
                    generatedBy: _userName,
                  ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: AppPage.archived,
      userName: _userName,
      userRole: _userRole,
      title: 'Biten Isler',
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        PopupMenuButton<String>(
          tooltip: 'Secenekler',
          onSelected: (value) async {
            if (value != 'pdf_filtered') return;
            final tickets = await _ticketsFuture;
            final filtered = _applyFilters(tickets);
            if (!context.mounted) return;
            await _openPdf(filtered);
          },
          itemBuilder:
              (context) => const [
                PopupMenuItem<String>(
                  value: 'pdf_filtered',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('Filtrelenmis listeyi PDF al'),
                  ),
                ),
              ],
        ),
      ],
      child: UiMaxWidth(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _ticketsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const UiLoading(message: 'Arsiv kayitlari yukleniyor...');
            }

            if (snapshot.hasError) {
              return UiErrorState(
                title: 'Arsiv yuklenemedi',
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }

            final tickets = snapshot.data ?? [];
            final filteredTickets = _applyFilters(tickets);

            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 18, bottom: 18),
                      child: _buildHeaderPanel(tickets, filteredTickets),
                    ),
                  ),
                  if (filteredTickets.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: UiEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Kayit bulunamadi',
                        subtitle:
                            'Filtreleri gevseterek veya arama terimini degistirerek tekrar deneyin.',
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildArchiveCard(filteredTickets[index]),
                        );
                      }, childCount: filteredTickets.length),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
