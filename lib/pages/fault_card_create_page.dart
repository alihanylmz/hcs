import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ticket_fault_record.dart';
import '../models/ticket_status.dart';
import '../models/user_profile.dart';
import '../pages/fault_record_detail_page.dart';
import '../services/fault_record_service.dart';
import '../services/ticket_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';

class FaultCardCreatePage extends StatefulWidget {
  const FaultCardCreatePage({
    super.key,
    this.initialFaultCode = '-',
    this.initialTitle = '',
    this.initialBody = '',
    this.initialDeviceBrand = '',
    this.initialDeviceModel = '',
  });

  final String initialFaultCode;
  final String initialTitle;
  final String initialBody;
  final String initialDeviceBrand;
  final String initialDeviceModel;

  @override
  State<FaultCardCreatePage> createState() => _FaultCardCreatePageState();
}

class _FaultCardCreatePageState extends State<FaultCardCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _faultCodeController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _deviceBrandController = TextEditingController();
  final _deviceModelController = TextEditingController();
  final _ticketSearchController = TextEditingController();
  final TicketService _ticketService = TicketService();
  final FaultRecordService _faultRecordService = FaultRecordService();
  final UserService _userService = UserService();

  Timer? _ticketSearchDebounce;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTicketLoading = false;
  String? _error;
  String? _ticketSearchError;
  List<UserProfile> _users = const <UserProfile>[];
  List<TicketFaultLinkCandidate> _ticketResults =
      const <TicketFaultLinkCandidate>[];
  UserProfile? _selectedAssignee;
  TicketFaultLinkCandidate? _selectedTicket;

  @override
  void initState() {
    super.initState();
    _faultCodeController.text =
        widget.initialFaultCode.trim().isEmpty
            ? '-'
            : widget.initialFaultCode.trim();
    _titleController.text = widget.initialTitle.trim();
    _descriptionController.text = widget.initialBody.trim();
    _deviceBrandController.text = widget.initialDeviceBrand.trim();
    _deviceModelController.text = widget.initialDeviceModel.trim();
    _ticketSearchController.addListener(_handleTicketSearchChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _ticketSearchDebounce?.cancel();
    _ticketSearchController.removeListener(_handleTicketSearchChanged);
    _faultCodeController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _deviceBrandController.dispose();
    _deviceModelController.dispose();
    _ticketSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final usersFuture = _userService.getAllUsers();
      final ticketsFuture = _ticketService.searchTicketsForFaultLink('');
      final results = await Future.wait<Object>([usersFuture, ticketsFuture]);

      if (!mounted) return;

      setState(() {
        _users =
            (results[0] as List<UserProfile>)
                .where((user) => user.role != UserRole.pending)
                .toList();
        _ticketResults = results[1] as List<TicketFaultLinkCandidate>;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Ariza kaydi ekrani yuklenemedi: $error';
        _isLoading = false;
      });
    }
  }

  void _handleTicketSearchChanged() {
    _ticketSearchDebounce?.cancel();
    _ticketSearchDebounce = Timer(const Duration(milliseconds: 280), () {
      _searchTickets(_ticketSearchController.text);
    });
  }

  Future<void> _searchTickets(String query) async {
    setState(() {
      _isTicketLoading = true;
      _ticketSearchError = null;
    });

    try {
      final results = await _ticketService.searchTicketsForFaultLink(query);
      if (!mounted) return;
      setState(() {
        _ticketResults = results;
        _isTicketLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ticketSearchError = 'Is emri aranirken hata olustu: $error';
        _isTicketLoading = false;
      });
    }
  }

  Future<void> _save() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final faultRecordId = await _faultRecordService.createFaultRecord(
        faultCode: _faultCodeController.text.trim(),
        title: _titleController.text.trim(),
        body:
            _descriptionController.text.trim().isEmpty
                ? 'Aciklama girilmedi.'
                : _descriptionController.text.trim(),
        deviceBrand: _deviceBrandController.text.trim(),
        deviceModel: _deviceModelController.text.trim(),
        linkedTicketId: _selectedTicket?.id,
        assigneeId: _selectedAssignee?.id,
        assigneeName: _selectedAssignee?.displayName,
      );

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => FaultRecordDetailPage(faultRecordId: faultRecordId),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Ariza kaydi olusturulamadi: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case TicketStatus.done:
        return 'Bitti';
      case TicketStatus.archived:
        return 'Arsiv';
      case TicketStatus.inProgress:
        return 'Serviste';
      case TicketStatus.panelDoneStock:
        return 'Stokta';
      case TicketStatus.panelDoneSent:
        return 'Gonderildi';
      case TicketStatus.open:
      default:
        return 'Acik';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case TicketStatus.done:
        return AppColors.statusDone;
      case TicketStatus.archived:
        return AppColors.statusArchived;
      case TicketStatus.inProgress:
        return AppColors.statusProgress;
      case TicketStatus.panelDoneStock:
        return AppColors.statusStock;
      case TicketStatus.panelDoneSent:
        return AppColors.statusSent;
      case TicketStatus.open:
      default:
        return AppColors.statusOpen;
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Tarih yok';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day.$month.$year';
  }

  Widget _buildBanner({
    required Color color,
    required IconData icon,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedTicketPanel(ThemeData theme) {
    final selectedTicket = _selectedTicket;
    final hasSelection = selectedTicket != null;
    final selectedStatus = selectedTicket?.status ?? '';
    final selectedStatusColor = _statusColor(selectedStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Opsiyonel is emri baglantisi',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hasSelection)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selectedStatusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: selectedStatusColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Text(
                    _statusLabel(selectedStatus),
                    style: TextStyle(
                      color: selectedStatusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasSelection
                ? selectedTicket.displayTitle
                : 'Bu ariza bagimsiz acilabilir. Istersen bir is emrine sadece referans olarak baglayabilirsin.',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: hasSelection ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasSelection
                ? 'Ariza kendi sayfasinda yasar. Bagliysa is emri ekraninda sadece iliski olarak gorunur.'
                : 'Asagidaki listeden son isleri gorebilir veya is kodu / baslik ile arayabilirsin.',
            style: theme.textTheme.bodyMedium,
          ),
          if (hasSelection &&
              (selectedStatus == TicketStatus.done ||
                  selectedStatus == TicketStatus.archived)) ...[
            const SizedBox(height: 12),
            _buildBanner(
              color: Colors.deepOrange,
              icon: Icons.report_problem_outlined,
              message:
                  'Secilen is bitmis veya arsivde. Bu ariza kaydi is emrini yeniden acmayacak; sadece farkli renkte iliski olarak gosterilecek.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTicketSearchResults(ThemeData theme) {
    if (_isTicketLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_ticketSearchError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: _buildBanner(
          color: AppColors.corporateRed,
          icon: Icons.error_outline,
          message: _ticketSearchError!,
        ),
      );
    }

    if (_ticketResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: _buildBanner(
          color: AppColors.corporateBlue,
          icon: Icons.search_off_rounded,
          message:
              'Eslesen is emri bulunamadi. Bagimsiz devam edebilir veya daha farkli bir is kodu deneyebilirsin.',
        ),
      );
    }

    return ListView.separated(
      itemCount: _ticketResults.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final ticket = _ticketResults[index];
        final isSelected = _selectedTicket?.id == ticket.id;
        final statusColor = _statusColor(ticket.status);

        return InkWell(
          onTap: () {
            setState(() {
              _selectedTicket = ticket;
              _error = null;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.08)
                      : theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.32)
                        : theme.dividerColor,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.assignment_outlined,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.jobCode.isEmpty ? 'Is kodu yok' : ticket.jobCode,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ticket.title.isEmpty
                            ? 'Basliksiz is emri'
                            : ticket.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _statusLabel(ticket.status),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Text(
                            _formatDate(ticket.createdAt),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchHint =
        _ticketSearchController.text.trim().isEmpty
            ? 'Son is emirleri'
            : 'Arama sonuclari';

    return Scaffold(
      appBar: AppBar(title: const Text('Ariza Kaydi Olustur')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ariza artik bagimsiz bir kayit olarak acilir. Istersen bir is emrine baglayip sadece iliski kurabilirsin.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            if (_error != null) ...[
                              _buildBanner(
                                color: AppColors.corporateRed,
                                icon: Icons.error_outline,
                                message: _error!,
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildSelectedTicketPanel(theme),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _ticketSearchController,
                              decoration: const InputDecoration(
                                labelText: 'Is emri ara',
                                hintText: 'Is kodu veya baslik yazin',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    searchHint,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                if (_selectedTicket != null)
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() => _selectedTicket = null);
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('Baglantiyi kaldir'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildTicketSearchResults(theme),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _faultCodeController,
                              decoration: const InputDecoration(
                                labelText: 'Ariza kodu',
                                hintText: 'E101, F12, AL-09...',
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Ariza basligi',
                                hintText: 'Kisa ve net bir baslik',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Baslik zorunludur.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _deviceBrandController,
                                    decoration: const InputDecoration(
                                      labelText: 'Marka',
                                      hintText: 'Inverter / PLC / HMI markasi',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _deviceModelController,
                                    decoration: const InputDecoration(
                                      labelText: 'Model',
                                      hintText: 'Cihaz modeli',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              minLines: 4,
                              maxLines: 7,
                              decoration: const InputDecoration(
                                labelText: 'Ariza aciklamasi',
                                hintText:
                                    'Sorun nedir, sahada ne goruldu, ne denendi, sonraki adim ne olacak?',
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<UserProfile?>(
                              initialValue: _selectedAssignee,
                              decoration: const InputDecoration(
                                labelText: 'Sorumlu kisi',
                              ),
                              items: [
                                const DropdownMenuItem<UserProfile?>(
                                  value: null,
                                  child: Text('Atama yapma'),
                                ),
                                ..._users.map(
                                  (user) => DropdownMenuItem<UserProfile?>(
                                    value: user,
                                    child: Text(user.displayName),
                                  ),
                                ),
                              ],
                              onChanged:
                                  (value) =>
                                      setState(() => _selectedAssignee = value),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isSaving ? null : _save,
                                icon:
                                    _isSaving
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Icon(Icons.bug_report_outlined),
                                label: Text(
                                  _isSaving
                                      ? 'Kaydediliyor...'
                                      : 'Ariza sayfasini olustur',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
    );
  }
}
