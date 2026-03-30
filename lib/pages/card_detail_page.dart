import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/card.dart';
import '../models/card_comment.dart';
import '../models/card_event.dart';
import '../models/card_linked_ticket.dart';
import '../services/card_service.dart';
import '../theme/app_colors.dart';
import 'ticket_detail_page.dart';

class CardDetailPage extends StatefulWidget {
  const CardDetailPage({super.key, required this.card});

  final KanbanCard card;

  @override
  State<CardDetailPage> createState() => _CardDetailPageState();
}

class _CardDetailPageState extends State<CardDetailPage> {
  final CardService _cardService = CardService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  late CardStatus _currentStatus;
  late String _initialTitle;
  late String _initialDescription;
  late CardStatus _initialStatus;
  String? _selectedLinkedTicketId;
  String? _initialLinkedTicketId;

  bool _isLoading = false;
  bool _isCommentSending = false;
  bool _isCommentsLoading = true;
  bool _hasSavedChanges = false;
  bool _supportsTicketLinking = false;

  List<CardEvent> _history = [];
  List<CardComment> _comments = [];
  List<CardLinkedTicket> _linkableTickets = [];

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  bool get _hasPendingChanges =>
      _titleController.text.trim() != _initialTitle ||
      _descController.text.trim() != _initialDescription ||
      _currentStatus != _initialStatus ||
      _selectedLinkedTicketId != _initialLinkedTicketId;

  @override
  void initState() {
    super.initState();
    _titleController.text = widget.card.title;
    _descController.text = widget.card.description ?? '';
    _currentStatus = widget.card.status;
    _selectedLinkedTicketId = widget.card.linkedTicketId;
    _initialTitle = widget.card.title;
    _initialDescription = widget.card.description ?? '';
    _initialStatus = widget.card.status;
    _initialLinkedTicketId = widget.card.linkedTicketId;
    _loadLinkedTicketingSupport();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadHistory(),
      _loadComments(),
      if (_supportsTicketLinking) _loadLinkableTickets(),
    ]);
  }

  Future<void> _loadLinkedTicketingSupport() async {
    try {
      final supports = await _cardService.supportsLinkedTicketing();
      if (!mounted) return;
      setState(() => _supportsTicketLinking = supports);
      if (supports) {
        await _loadLinkableTickets();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _supportsTicketLinking = false);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final events = await _cardService.getCardHistory(widget.card.id);
      if (!mounted) return;
      setState(() => _history = events);
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    if (mounted) setState(() => _isCommentsLoading = true);
    try {
      final comments = await _cardService.getCardComments(widget.card.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _isCommentsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCommentsLoading = false);
    }
  }

  Future<void> _loadLinkableTickets() async {
    try {
      final tickets = await _cardService.getLinkableTickets();
      if (!mounted) return;
      setState(() => _linkableTickets = tickets);
    } catch (_) {}
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      if (_currentStatus != _initialStatus) {
        await _cardService.updateCardStatus(widget.card.id, _currentStatus);
      }

      final titleChanged = _titleController.text.trim() != _initialTitle;
      final descriptionChanged =
          _descController.text.trim() != _initialDescription;
      final linkedTicketChanged =
          _supportsTicketLinking &&
          _selectedLinkedTicketId != _initialLinkedTicketId;

      if (titleChanged || descriptionChanged || linkedTicketChanged) {
        await _cardService.updateCardDetails(
          widget.card.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          linkedTicketId: _selectedLinkedTicketId,
          updateLinkedTicket: _supportsTicketLinking,
        );
      }

      if (!mounted) return;
      setState(() {
        _initialTitle = _titleController.text.trim();
        _initialDescription = _descController.text.trim();
        _initialStatus = _currentStatus;
        _initialLinkedTicketId = _selectedLinkedTicketId;
        _hasSavedChanges = true;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kart degisiklikleri kaydedildi.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kart kaydedilemedi: $error')));
    }
  }

  Future<void> _deleteCard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Kart silinsin mi?'),
            content: const Text(
              'Bu kart Supabase tarafindan kalici olarak silinecek.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgec'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.corporateRed,
                ),
                child: const Text('Sil'),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _cardService.deleteCard(widget.card.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kart silinemedi: $error')));
    }
  }

  Future<void> _addComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;
    setState(() => _isCommentSending = true);
    try {
      await _cardService.addCardComment(
        cardId: widget.card.id,
        teamId: widget.card.teamId,
        comment: comment,
      );
      if (!mounted) return;
      _commentController.clear();
      await _loadComments();
      await _loadHistory();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kart notu eklenemedi: $error')));
    } finally {
      if (mounted) setState(() => _isCommentSending = false);
    }
  }

  Future<void> _editComment(CardComment comment) async {
    final controller = TextEditingController(text: comment.comment);
    final updated = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Kart notunu duzenle'),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(hintText: 'Notu guncelle...'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgec'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Kaydet'),
              ),
            ],
          ),
    );
    if (updated == null || updated.isEmpty) return;
    try {
      await _cardService.updateCardComment(comment.id, updated);
      if (!mounted) return;
      await _loadComments();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kart notu guncellenemedi: $error')),
      );
    }
  }

  Future<void> _deleteComment(CardComment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Kart notu silinsin mi?'),
            content: const Text('Bu not karttan kaldirilacak.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgec'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.corporateRed,
                ),
                child: const Text('Sil'),
              ),
            ],
          ),
    );
    if (confirm != true) return;
    try {
      await _cardService.deleteCardComment(comment.id);
      if (!mounted) return;
      await _loadComments();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kart notu silinemedi: $error')));
    }
  }

  Future<void> _openLinkedTicket() async {
    final ticketId = _selectedLinkedTicketId;
    if (ticketId == null || ticketId.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TicketDetailPage(ticketId: ticketId)),
    );
  }

  List<CardLinkedTicket> _ticketOptions() {
    final options = List<CardLinkedTicket>.from(_linkableTickets);
    final selectedId = _selectedLinkedTicketId;
    if (selectedId == null || selectedId.isEmpty) return options;
    if (options.any((ticket) => ticket.id == selectedId)) return options;
    options.insert(
      0,
      CardLinkedTicket(
        id: selectedId,
        jobCode: widget.card.linkedJobCode ?? 'Bagli is emri',
        title: widget.card.linkedTicketTitle ?? '',
      ),
    );
    return options;
  }

  Future<bool> _handleBack() async {
    Navigator.pop(context, _hasSavedChanges);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 1080;

    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Pano Karti'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _hasSavedChanges),
          ),
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    _buildHeader(theme, isWide),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: theme.dividerColor),
                            ),
                            child: Text(
                              'Akis',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1080),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(top: 0),
                              child: _buildProcessTab(theme),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isWide) {
    final statusColor = _statusColor(_currentStatus);
    final priorityColor = _priorityColor(widget.card.priority);
    final dueLabel =
        widget.card.dueDate == null
            ? 'Tarih yok'
            : DateFormat(
              'dd.MM.yyyy HH:mm',
              'tr_TR',
            ).format(widget.card.dueDate!.toLocal());
    final linkedLabel =
        (widget.card.linkedJobCode ?? '').trim().isNotEmpty
            ? widget.card.linkedJobCode!
            : (_selectedLinkedTicketId == null
                ? 'Bagli degil'
                : 'Bagli is emri');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Container(
            padding: EdgeInsets.all(isWide ? 22 : 18),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(
                    theme.brightness == Brightness.dark ? 0.16 : 0.05,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kanbanMark(theme, statusColor),
                      const SizedBox(width: 18),
                      Expanded(child: _buildHeaderCopy(theme)),
                      const SizedBox(width: 18),
                      _buildHeaderSidebar(
                        theme,
                        statusColor,
                        priorityColor,
                        dueLabel,
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kanbanMark(theme, statusColor),
                          const SizedBox(width: 14),
                          Expanded(child: _buildHeaderCopy(theme)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildHeaderSidebar(
                        theme,
                        statusColor,
                        priorityColor,
                        dueLabel,
                      ),
                    ],
                  ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _identityChip(
                      theme,
                      'Kart no',
                      _shortId(widget.card.id),
                      Icons.tag_rounded,
                      AppColors.corporateBlue,
                    ),
                    _identityChip(
                      theme,
                      'Sorumlu',
                      widget.card.assigneeName ?? 'Atanmamis',
                      Icons.person_outline_rounded,
                      const Color(0xFF10B981),
                    ),
                    _identityChip(
                      theme,
                      'Termin',
                      dueLabel,
                      Icons.event_outlined,
                      const Color(0xFFF59E0B),
                    ),
                    _identityChip(
                      theme,
                      'Referans',
                      _supportsTicketLinking ? linkedLabel : 'Bagli degil',
                      Icons.link_rounded,
                      const Color(0xFF8B5CF6),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        theme.brightness == Brightness.dark
                            ? AppColors.surfaceDarkMuted.withOpacity(0.72)
                            : AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _hasPendingChanges
                              ? 'Kaydedilmemis degisiklikler var.'
                              : 'Bu ekran ekip ici pano gorevine odaklanir. Referans is emri baglanti icin opsiyoneldir.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(
                              0.68,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _actionButton(theme, 'Konusma', Icons.forum_outlined, () {
                        Navigator.pop(context, 'open_conversation');
                      }),
                      _actionButton(
                        theme,
                        'Is emrini ac',
                        Icons.open_in_new_outlined,
                        _selectedLinkedTicketId == null
                            ? null
                            : _openLinkedTicket,
                      ),
                      _actionButton(
                        theme,
                        'Kaydet',
                        Icons.save_outlined,
                        _saveChanges,
                      ),
                      _actionButton(
                        theme,
                        'Sil',
                        Icons.delete_outline,
                        _deleteCard,
                        destructive: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 900;

        final mainPanel = _sectionShell(
          theme,
          title: 'Kart tanimi',
          subtitle:
              'Bu kartin ekibe ne anlattigini, hangi ciktiyi bekledigini ve nasil bir baglam tasidigini yaz.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Kart basligi'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _descController,
                minLines: 6,
                maxLines: 9,
                decoration: const InputDecoration(
                  labelText: 'Kart aciklamasi',
                  hintText:
                      'Bu kart neden acildi, ekipten ne bekleniyor, ne tamamlandiginda kart kapanmali gibi net bir cerceve yaz.',
                ),
              ),
            ],
          ),
        );

        final sidePanel = Column(
          children: [
            _sectionShell(
              theme,
              title: 'Kart sinyalleri',
              subtitle: 'Kartin genel ritmini gosteren ozet bilgiler.',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metric(
                    theme,
                    'Not',
                    '${_comments.length}',
                    Icons.sticky_note_2_outlined,
                    AppColors.corporateBlue,
                  ),
                  _metric(
                    theme,
                    'Hareket',
                    '${_history.length}',
                    Icons.bolt_outlined,
                    const Color(0xFFF59E0B),
                  ),
                  _metric(
                    theme,
                    'Sahip',
                    widget.card.assigneeName ?? 'Atanmamis',
                    Icons.person_outline_rounded,
                    const Color(0xFF10B981),
                  ),
                  _metric(
                    theme,
                    'Termin',
                    widget.card.dueDate == null
                        ? 'Plan yok'
                        : DateFormat(
                          'dd.MM.yyyy HH:mm',
                          'tr_TR',
                        ).format(widget.card.dueDate!.toLocal()),
                    Icons.event_outlined,
                    const Color(0xFF8B5CF6),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionShell(
              theme,
              title: 'Bu kart nasil kullanilir?',
              subtitle: 'Is emri degil, ekip ici gorev mantigi.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _hintLine(
                    theme,
                    Icons.check_circle_outline,
                    'Takim ici gorev, takip ve koordinasyon icin kullan.',
                  ),
                  const SizedBox(height: 10),
                  _hintLine(
                    theme,
                    Icons.link_outlined,
                    'Is emri baglantisi sadece gercekten ilgili bir servis kaydi varsa eklenmeli.',
                  ),
                  const SizedBox(height: 10),
                  _hintLine(
                    theme,
                    Icons.done_all_outlined,
                    'Tamamlanma kosulunu acik yazarsan kart ekip icinde daha hizli ilerler.',
                  ),
                ],
              ),
            ),
          ],
        );

        if (!twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [mainPanel, const SizedBox(height: 16), sidePanel],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: mainPanel),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: sidePanel),
          ],
        );
      },
    );
  }

  Widget _buildProcessTab(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 920;

        final notesPanel = _sectionShell(
          theme,
          title: 'Takim notlari',
          subtitle:
              'Kart ilerlerken ekip ici kisa not, durum aktarimi ve karar kayitlari burada tutulur.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Karta not ekle...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isCommentSending ? null : _addComment,
                    icon:
                        _isCommentSending
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.add_comment_outlined),
                    label: const Text('Ekle'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildComments(theme),
            ],
          ),
        );

        final historyPanel = _sectionShell(
          theme,
          title: 'Kart hareketleri',
          subtitle:
              'Durum degisikligi, guncelleme ve not akisi bu bolumde toplanir.',
          child: _buildHistory(theme),
        );

        if (!twoColumns) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [notesPanel, const SizedBox(height: 16), historyPanel],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: notesPanel),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: historyPanel),
          ],
        );
      },
    );
  }

  Widget _buildLinksTab(ThemeData theme) {
    if (!_supportsTicketLinking) {
      return _sectionShell(
        theme,
        title: 'Referans is emri',
        subtitle:
            'Bu alan karti belirli bir servis kaydiyla eslemek istediginde kullanilir.',
        child: Text(
          'Is emri baglama su an devre disi. Supabase cards tablosunda linked_ticket_id kolonu kurulunca bu alan otomatik acilacak.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    final linkedLabel = _ticketOptions()
        .where((ticket) => ticket.id == _selectedLinkedTicketId)
        .map((ticket) => ticket.displayLabel)
        .cast<String?>()
        .firstWhere((label) => true, orElse: () => null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionShell(
          theme,
          title: 'Referans is emri',
          subtitle:
              'Opsiyonel. Sadece bu kart gercekten belirli bir servis kaydini takip ediyorsa bagla.',
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedLinkedTicketId,
                  decoration: const InputDecoration(
                    labelText: 'Acik is emri sec',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Is emri baglama'),
                    ),
                    ..._ticketOptions().map(
                      (ticket) => DropdownMenuItem<String?>(
                        value: ticket.id,
                        child: Text(
                          ticket.displayLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged:
                      (value) =>
                          setState(() => _selectedLinkedTicketId = value),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed:
                    _selectedLinkedTicketId == null ? null : _openLinkedTicket,
                icon: const Icon(Icons.open_in_new_outlined),
                label: const Text('Ac'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _metric(
              theme,
              'Baglanti',
              linkedLabel ?? 'Bagli degil',
              Icons.link_outlined,
              AppColors.corporateBlue,
            ),
            _metric(
              theme,
              'Olusturuldu',
              DateFormat(
                'dd.MM.yyyy HH:mm',
                'tr_TR',
              ).format(widget.card.createdAt),
              Icons.calendar_today_outlined,
              const Color(0xFF64748B),
            ),
            _metric(
              theme,
              'Kart durumu',
              _currentStatus.label,
              Icons.track_changes_outlined,
              _statusColor(_currentStatus),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComments(ThemeData theme) {
    if (_isCommentsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_comments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Text(
          'Bu kart icin henuz not eklenmedi.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    return Column(
      children:
          _comments.map((comment) {
            final isOwn = comment.userId == _currentUserId;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment.authorName ?? 'Kullanici',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isOwn)
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _editComment(comment);
                            if (value == 'delete') _deleteComment(comment);
                          },
                          itemBuilder:
                              (_) => const [
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: Text('Duzenle'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text('Sil'),
                                ),
                              ],
                        ),
                      Text(
                        DateFormat(
                          'dd.MM.yyyy HH:mm',
                          'tr_TR',
                        ).format(comment.createdAt.toLocal()),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(comment.comment, style: theme.textTheme.bodyLarge),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildHistory(ThemeData theme) {
    if (_history.isEmpty) {
      return Text(
        'Kart icin henuz gecmis kaydi yok.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
      );
    }
    return Column(
      children:
          _history.map((event) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_toggle_off_outlined),
              title: Text(_eventText(event)),
              subtitle: Text(
                DateFormat(
                  'dd.MM.yyyy HH:mm',
                  'tr_TR',
                ).format(event.createdAt.toLocal()),
              ),
            );
          }).toList(),
    );
  }

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withOpacity(0.16)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w800),
    ),
  );

  Widget _kanbanMark(ThemeData theme, Color color) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.view_kanban_outlined, color: color, size: 28),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCopy(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PANO KARTI',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.62),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _titleController.text.trim().isEmpty
              ? 'Basliksiz kart'
              : _titleController.text.trim(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          'Bu ekran ekip ici gorev, takip ve koordinasyon icin kullanilir. Is emrinden farkli olarak daha hafif, daha hizli ve pano odakli calisir.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.68),
          ),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildHeaderSidebar(
    ThemeData theme,
    Color statusColor,
    Color priorityColor,
    String dueLabel,
  ) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            theme.brightness == Brightness.dark
                ? AppColors.surfaceDarkMuted.withOpacity(0.64)
                : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(_currentStatus.label, statusColor),
              _pill(widget.card.priority.label, priorityColor),
            ],
          ),
          const SizedBox(height: 14),
          _sidebarInfoLine(
            theme,
            'Kart sahibi',
            widget.card.assigneeName ?? 'Atanmamis',
          ),
          const SizedBox(height: 10),
          _sidebarInfoLine(theme, 'Termin', dueLabel),
        ],
      ),
    );
  }

  Widget _sidebarInfoLine(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.58),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _identityChip(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return SizedBox(
      width: 212,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              theme.brightness == Brightness.dark
                  ? AppColors.surfaceDarkMuted.withOpacity(0.58)
                  : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionShell(
    ThemeData theme, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.68),
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _hintLine(ThemeData theme, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.74),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoCard(ThemeData theme, String title, String value, IconData icon) {
    return SizedBox(
      width: 184,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              theme.brightness == Brightness.dark
                  ? AppColors.surfaceDarkMuted.withOpacity(0.64)
                  : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(
    ThemeData theme,
    String label,
    IconData icon,
    VoidCallback? onPressed, {
    bool destructive = false,
  }) {
    final color =
        destructive ? AppColors.corporateRed : theme.colorScheme.primary;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(
    ThemeData theme,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return SizedBox(
      width: 250,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(CardStatus status) {
    switch (status) {
      case CardStatus.todo:
        return const Color(0xFF64748B);
      case CardStatus.doing:
        return const Color(0xFFF59E0B);
      case CardStatus.done:
        return const Color(0xFF10B981);
      case CardStatus.sent:
        return const Color(0xFF8B5CF6);
    }
  }

  Color _priorityColor(CardPriority priority) {
    switch (priority) {
      case CardPriority.low:
        return AppColors.corporateBlue;
      case CardPriority.normal:
        return AppColors.corporateYellow;
      case CardPriority.high:
        return AppColors.corporateRed;
    }
  }

  String _shortId(String value) =>
      value.length <= 8 ? value : value.substring(0, 8);

  String _eventText(CardEvent event) {
    switch (event.eventType) {
      case CardEventType.cardCreated:
        return 'Kart olusturuldu.';
      case CardEventType.statusChanged:
        return 'Durum degisti: ${event.fromStatus ?? '-'} -> ${event.toStatus ?? '-'}';
      case CardEventType.updated:
        return 'Kart guncellendi.';
      case CardEventType.commented:
        return 'Kart notu eklendi.';
      default:
        return 'Kartta islem yapildi.';
    }
  }
}
