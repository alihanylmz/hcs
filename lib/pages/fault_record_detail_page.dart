import 'package:flutter/material.dart';

import '../models/fault_record.dart';
import '../models/fault_record_note.dart';
import '../models/ticket_status.dart';
import '../services/fault_record_service.dart';
import '../services/ticket_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import 'ticket_detail_page.dart';

class FaultRecordDetailPage extends StatefulWidget {
  const FaultRecordDetailPage({super.key, required this.faultRecordId});

  final String faultRecordId;

  @override
  State<FaultRecordDetailPage> createState() => _FaultRecordDetailPageState();
}

class _FaultRecordDetailPageState extends State<FaultRecordDetailPage> {
  final FaultRecordService _faultRecordService = FaultRecordService();
  final TicketService _ticketService = TicketService();

  FaultRecord? _record;
  List<FaultRecordNote> _notes = const <FaultRecordNote>[];
  Map<String, dynamic>? _linkedTicket;
  bool _isLoading = true;
  bool _isSubmittingNote = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final record = await _faultRecordService.getFaultRecord(
        widget.faultRecordId,
      );
      final notesFuture = _faultRecordService.getFaultNotes(
        widget.faultRecordId,
      );
      final linkedTicketFuture =
          record.hasLinkedTicket
              ? _ticketService.getTicket(record.linkedTicketId!)
              : Future<Map<String, dynamic>?>.value(null);

      final results = await Future.wait<Object?>([
        notesFuture,
        linkedTicketFuture,
      ]);

      if (!mounted) return;
      setState(() {
        _record = record;
        _notes = results[0] as List<FaultRecordNote>;
        _linkedTicket = results[1] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Ariza kaydi yuklenemedi: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddNoteDialog() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Ariza notu ekle'),
            content: SizedBox(
              width: 560,
              child: TextField(
                controller: controller,
                minLines: 4,
                maxLines: 8,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Not',
                  hintText:
                      'Sahada ne goruldu, ne denendi, sonraki adim nedir?',
                  alignLabelWithHint: true,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Vazgec'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(context).pop(controller.text.trim()),
                child: const Text('Kaydet'),
              ),
            ],
          ),
    );
    controller.dispose();

    if (!mounted || note == null || note.trim().isEmpty) {
      return;
    }

    setState(() => _isSubmittingNote = true);
    try {
      await _faultRecordService.addFaultNote(widget.faultRecordId, note);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ariza notu eklendi.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ariza notu eklenemedi: $error'),
          backgroundColor: AppColors.corporateRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingNote = false);
      }
    }
  }

  Future<void> _openLinkedTicket() async {
    final linkedTicketId = _record?.linkedTicketId;
    if (linkedTicketId == null || linkedTicketId.trim().isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketDetailPage(ticketId: linkedTicketId),
      ),
    );
    await _load();
  }

  Color _faultStatusColor(String status) {
    switch (status) {
      case FaultRecordStatus.monitoring:
        return Colors.orange;
      case FaultRecordStatus.resolved:
        return Colors.teal;
      case FaultRecordStatus.closed:
        return Colors.blueGrey;
      case FaultRecordStatus.open:
      default:
        return AppColors.corporateRed;
    }
  }

  Color _ticketStatusColor(String status) {
    switch (status) {
      case TicketStatus.done:
        return AppColors.statusDone;
      case TicketStatus.archived:
        return AppColors.statusArchived;
      case TicketStatus.inProgress:
        return AppColors.statusProgress;
      case TicketStatus.panelDoneSent:
        return AppColors.statusSent;
      case TicketStatus.panelDoneStock:
        return AppColors.statusStock;
      case TicketStatus.open:
      default:
        return AppColors.statusOpen;
    }
  }

  Widget _buildChip({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    List<Widget> actions = const <Widget>[],
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildHeader(FaultRecord record) {
    final accent = _faultStatusColor(record.status);
    final linkedTicketStatus = _linkedTicket?['status']?.toString() ?? '';
    final linkedTicketTerminal =
        linkedTicketStatus == TicketStatus.done ||
        linkedTicketStatus == TicketStatus.archived;

    return _buildSectionCard(
      title: 'Ariza karti',
      icon: Icons.bug_report_outlined,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChip(label: record.faultCode, color: accent),
            _buildChip(label: record.statusLabel, color: accent),
            _buildChip(
              label: record.deviceLabel,
              color: AppColors.corporateBlue,
              icon: Icons.memory_rounded,
            ),
            if ((record.assigneeName ?? '').trim().isNotEmpty)
              _buildChip(
                label: 'Atanan: ${record.assigneeName!.trim()}',
                color: Colors.indigo,
                icon: Icons.person_outline,
              ),
            _buildChip(
              label:
                  (record.createdByName ?? '').trim().isEmpty
                      ? 'Kayit sahibi yok'
                      : record.createdByName!.trim(),
              color: AppColors.corporateYellow,
              icon: Icons.person_2_outlined,
            ),
            _buildChip(
              label: Formatters.date(record.createdAt?.toIso8601String()),
              color: Colors.teal,
              icon: Icons.event_outlined,
            ),
            if (linkedTicketTerminal)
              _buildChip(
                label: 'Bitmis is emrine bagli',
                color: Colors.deepOrange,
                icon: Icons.report_problem_outlined,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          record.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Text(
          record.body,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
      ],
    );
  }

  Widget _buildLinkedTicketCard(FaultRecord record) {
    if (!record.hasLinkedTicket || _linkedTicket == null) {
      return _buildSectionCard(
        title: 'Bagli is emri',
        icon: Icons.link_off_rounded,
        children: const [
          Text('Bu ariza kaydi herhangi bir is emrine bagli degil.'),
        ],
      );
    }

    final status = _linkedTicket?['status']?.toString() ?? TicketStatus.open;
    final statusColor = _ticketStatusColor(status);
    final jobCode = _linkedTicket?['job_code']?.toString().trim() ?? '-';
    final title = _linkedTicket?['title']?.toString().trim() ?? 'Basliksiz is';
    final isTerminal =
        status == TicketStatus.done || status == TicketStatus.archived;

    return _buildSectionCard(
      title: 'Bagli is emri',
      icon: Icons.assignment_outlined,
      actions: [
        OutlinedButton.icon(
          onPressed: _openLinkedTicket,
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('Is emrini ac'),
        ),
      ],
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChip(label: jobCode, color: AppColors.corporateBlue),
            _buildChip(label: TicketStatus.labelOf(status), color: statusColor),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (isTerminal) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.deepOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.deepOrange.withValues(alpha: 0.20),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.report_problem_outlined,
                  color: Colors.deepOrange,
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bu ariza bitmis veya arsive alinmis is emrine bagli. Is emri yeniden acilmadi; takip ariza sayfasindan devam eder.',
                    style: TextStyle(
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNotesTimeline() {
    if (_notes.isEmpty) {
      return const Text('Henuz bu ariza icin not eklenmedi.');
    }

    return Column(
      children: List.generate(_notes.length, (index) {
        final note = _notes[index];
        final isLast = index == _notes.length - 1;
        return Stack(
          children: [
            if (!isLast)
              Positioned(
                left: 11,
                top: 26,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: Theme.of(context).dividerColor,
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  padding: const EdgeInsets.only(top: 12),
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.corporateRed,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              note.authorLabel,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (note.roleLabel != null)
                              Text(
                                note.roleLabel!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            Text(
                              Formatters.date(
                                note.createdAt?.toIso8601String(),
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          note.note,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.55),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = _record;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          record == null
              ? 'Ariza Detayi'
              : '${record.faultCode} - ${record.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.corporateRed,
                    ),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ),
              )
              : record == null
              ? const Center(child: Text('Ariza kaydi bulunamadi.'))
              : SafeArea(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(record),
                            const SizedBox(height: 20),
                            _buildLinkedTicketCard(record),
                            const SizedBox(height: 20),
                            _buildSectionCard(
                              title: 'Ariza hikayesi',
                              icon: Icons.timeline_outlined,
                              actions: [
                                FilledButton.icon(
                                  onPressed:
                                      _isSubmittingNote
                                          ? null
                                          : _showAddNoteDialog,
                                  icon:
                                      _isSubmittingNote
                                          ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : const Icon(
                                            Icons.add_comment_outlined,
                                          ),
                                  label: Text(
                                    _isSubmittingNote
                                        ? 'Kaydediliyor...'
                                        : 'Not ekle',
                                  ),
                                ),
                              ],
                              children: [_buildNotesTimeline()],
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
