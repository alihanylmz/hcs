import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/board.dart';
import '../models/card.dart';
import '../models/card_linked_ticket.dart';
import '../models/team_member.dart';
import '../services/board_service.dart';
import '../services/card_service.dart';
import '../services/team_service.dart';
import '../theme/app_colors.dart';
import 'card_detail_page.dart';
import 'ticket_detail_page.dart';

class BoardPage extends StatefulWidget {
  final String teamId;
  final ValueChanged<KanbanCard>? onOpenConversation;

  const BoardPage({super.key, required this.teamId, this.onOpenConversation});

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  final BoardService _boardService = BoardService();
  final CardService _cardService = CardService();
  final TeamService _teamService = TeamService();

  bool _isLoading = true;
  String? _error;
  List<Board> _boards = [];
  Board? _activeBoard;
  List<KanbanCard> _cards = [];
  List<TeamMember> _members = [];
  List<CardLinkedTicket> _linkableTickets = [];
  bool _isLinkableTicketsLoading = false;
  bool _supportsTicketLinking = false;

  @override
  void initState() {
    super.initState();
    _loadBoards();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await _teamService.getTeamMembers(widget.teamId);
      if (!mounted) return;
      setState(() => _members = members);
    } catch (_) {
      // Uye listesi acilmadiysa bile pano akisina devam ediyoruz.
    }
  }

  Future<void> _loadLinkableTickets() async {
    if (_isLinkableTicketsLoading) return;
    _isLinkableTicketsLoading = true;
    try {
      final tickets = await _cardService.getLinkableTickets();
      if (!mounted) return;
      setState(() => _linkableTickets = tickets);
    } catch (_) {
      // Ticket listesi acilamasa da pano akisina devam ediyoruz.
    } finally {
      _isLinkableTicketsLoading = false;
    }
  }

  Future<void> _loadLinkedTicketingSupport() async {
    try {
      final supports = await _cardService.supportsLinkedTicketing();
      if (!mounted) return;
      setState(() => _supportsTicketLinking = supports);
    } catch (_) {
      if (!mounted) return;
      setState(() => _supportsTicketLinking = false);
    }
  }

  Future<void> _prepareCardDialogData() async {
    final futures = <Future<void>>[];
    if (_members.isEmpty) {
      futures.add(_loadMembers());
    }
    if (!_supportsTicketLinking) {
      futures.add(_loadLinkedTicketingSupport());
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
    if (_supportsTicketLinking && _linkableTickets.isEmpty) {
      await _loadLinkableTickets();
    }
  }

  Future<void> _loadBoards() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final boards = await _boardService.getTeamBoards(widget.teamId);
      if (!mounted) return;

      if (boards.isEmpty) {
        setState(() {
          _boards = [];
          _activeBoard = null;
          _isLoading = false;
          _error = 'Pano bulunamadi.';
        });
        return;
      }

      setState(() {
        _boards = boards;
        _activeBoard = boards.first;
      });
      await _loadCards();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Panolar yuklenemedi: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCards() async {
    if (_activeBoard == null) return;

    try {
      final cards = await _cardService.getBoardCards(_activeBoard!.id);
      if (!mounted) return;
      setState(() {
        _cards = cards;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Kartlar yuklenemedi: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _createCard({
    required String title,
    String? description,
    String? assigneeId,
    String? linkedTicketId,
    CardPriority priority = CardPriority.normal,
    DateTime? dueDate,
  }) async {
    if (_activeBoard == null) return;

    try {
      await _cardService.createCard(
        teamId: widget.teamId,
        boardId: _activeBoard!.id,
        title: title,
        description:
            description?.trim().isEmpty ?? true ? null : description!.trim(),
        assigneeId: assigneeId,
        linkedTicketId: linkedTicketId,
        priority: priority,
        dueDate: dueDate,
      );
      await _loadCards();
    } catch (error) {
      _showSnack('Kart olusturulamadi: $error', isError: true);
    }
  }

  Future<void> _moveCardToStatus(
    KanbanCard card,
    CardStatus newStatus, {
    bool showSuccess = true,
  }) async {
    if (card.status == newStatus) return;

    final oldCards = List<KanbanCard>.from(_cards);
    setState(() {
      final index = _cards.indexWhere((item) => item.id == card.id);
      if (index != -1) {
        _cards[index] = _copyCardWithStatus(card, newStatus);
      }
    });

    try {
      await _cardService.updateCardStatus(card.id, newStatus);
      if (showSuccess) {
        _showSnack('Kart tasindi.', isSuccess: true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _cards = oldCards);
      _showSnack('Kart tasinamadi: $error', isError: true);
    }
  }

  KanbanCard _copyCardWithStatus(KanbanCard card, CardStatus newStatus) {
    return KanbanCard(
      id: card.id,
      boardId: card.boardId,
      teamId: card.teamId,
      title: card.title,
      description: card.description,
      status: newStatus,
      createdBy: card.createdBy,
      assigneeId: card.assigneeId,
      assigneeName: card.assigneeName,
      linkedTicketId: card.linkedTicketId,
      linkedJobCode: card.linkedJobCode,
      linkedTicketTitle: card.linkedTicketTitle,
      priority: card.priority,
      dueDate: card.dueDate,
      createdAt: card.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _openCardDetail(KanbanCard card) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardDetailPage(card: card),
        fullscreenDialog: true,
      ),
    );

    if (result == 'open_conversation') {
      widget.onOpenConversation?.call(card);
      return;
    }

    if (result == true) {
      await _loadCards();
    }
  }

  Future<void> _openLinkedTicket(KanbanCard card) async {
    final ticketId = card.linkedTicketId;
    if (ticketId == null || ticketId.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TicketDetailPage(ticketId: ticketId)),
    );
  }

  Future<void> _unlinkLinkedTicket(KanbanCard card) async {
    try {
      await _cardService.updateCardDetails(
        card.id,
        linkedTicketId: null,
        updateLinkedTicket: true,
      );
      await _loadCards();
      _showSnack('Is emri baglantisi kaldirildi.', isSuccess: true);
    } catch (error) {
      _showSnack('Baglanti kaldirilamadi: $error', isError: true);
    }
  }

  CardLinkedTicket? _findLinkedTicketById(String? ticketId) {
    if (ticketId == null || ticketId.isEmpty) return null;
    for (final ticket in _linkableTickets) {
      if (ticket.id == ticketId) return ticket;
    }
    return null;
  }

  String? _findAssigneeNameById(String? assigneeId) {
    if (assigneeId == null || assigneeId.isEmpty) return null;
    for (final member in _members) {
      if (member.userId == assigneeId) {
        return member.displayName;
      }
    }
    return null;
  }

  Future<CardLinkedTicket?> _showTicketPicker({
    String? selectedTicketId,
  }) async {
    if (!_supportsTicketLinking) return null;
    if (_linkableTickets.isEmpty) {
      await _loadLinkableTickets();
    }
    if (!mounted) return null;

    final selected = _findLinkedTicketById(selectedTicketId);
    final searchController = TextEditingController();
    String query = '';

    final result = await showModalBottomSheet<CardLinkedTicket?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              final filtered =
                  _linkableTickets.where((ticket) {
                    final haystack =
                        '${ticket.jobCode} ${ticket.title} ${ticket.status ?? ''}'
                            .toLowerCase();
                    return haystack.contains(query.toLowerCase());
                  }).toList();

              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 8,
                    bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                  ),
                  child: SizedBox(
                    height: 540,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ilgili is emrini sec',
                          style: Theme.of(sheetContext).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Bu kart sadece belli bir is emrinin takibi veya ic koordinasyonu icinse bagla. Genel ekip kartlarinda bos birakabilirsin.',
                          style: Theme.of(sheetContext).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: searchController,
                          onChanged:
                              (value) => setSheetState(() => query = value),
                          decoration: const InputDecoration(
                            hintText: 'Is kodu veya baslik ara...',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (selected != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.corporateBlue.withOpacity(
                                  0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.corporateBlue.withOpacity(
                                    0.18,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.link_rounded),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Secili: ${selected.displayLabel}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Expanded(
                          child:
                              filtered.isEmpty
                                  ? const Center(
                                    child: Text('Eslesen acik is emri yok.'),
                                  )
                                  : ListView.separated(
                                    itemCount: filtered.length,
                                    separatorBuilder:
                                        (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final ticket = filtered[index];
                                      final isSelected =
                                          ticket.id == selectedTicketId;
                                      return InkWell(
                                        onTap:
                                            () => Navigator.pop(
                                              sheetContext,
                                              ticket,
                                            ),
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color:
                                                isSelected
                                                    ? AppColors.corporateBlue
                                                        .withOpacity(0.08)
                                                    : Theme.of(
                                                      sheetContext,
                                                    ).cardColor,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color:
                                                  isSelected
                                                      ? AppColors.corporateBlue
                                                          .withOpacity(0.28)
                                                      : Theme.of(
                                                        sheetContext,
                                                      ).dividerColor,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                ticket.jobCode.isEmpty
                                                    ? 'Is Kodu Yok'
                                                    : ticket.jobCode,
                                                style: Theme.of(sheetContext)
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                      color:
                                                          AppColors
                                                              .corporateBlue,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                ticket.title.isEmpty
                                                    ? 'Basliksiz is emri'
                                                    : ticket.title,
                                                style: Theme.of(sheetContext)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );

    searchController.dispose();
    return result;
  }

  Future<TeamMember?> _showAssigneePicker({String? selectedAssigneeId}) async {
    return showModalBottomSheet<TeamMember?>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                height: 420,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sorumlu kisiyi sec',
                      style: Theme.of(sheetContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _members.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          final isSelected =
                              member.userId == selectedAssigneeId;
                          return InkWell(
                            onTap: () => Navigator.pop(sheetContext, member),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? AppColors.corporateBlue.withOpacity(
                                          0.08,
                                        )
                                        : Theme.of(sheetContext).cardColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? AppColors.corporateBlue.withOpacity(
                                            0.28,
                                          )
                                          : Theme.of(sheetContext).dividerColor,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.corporateBlue
                                        .withOpacity(0.12),
                                    child: Text(
                                      member.displayName.trim().isEmpty
                                          ? '?'
                                          : member.displayName
                                              .trim()
                                              .substring(0, 1)
                                              .toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.corporateBlue,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member.displayName,
                                          style: Theme.of(
                                            sheetContext,
                                          ).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          member.role.label,
                                          style:
                                              Theme.of(
                                                sheetContext,
                                              ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<CardPriority?> _showPriorityPicker(CardPriority selected) async {
    return showModalBottomSheet<CardPriority?>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Oncelik sec',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  ...CardPriority.values.map((priority) {
                    final isSelected = priority == selected;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.flag_outlined,
                        color: _priorityColor(priority),
                      ),
                      title: Text(priority.label),
                      trailing:
                          isSelected
                              ? Icon(
                                Icons.check_rounded,
                                color: _priorityColor(priority),
                              )
                              : null,
                      onTap: () => Navigator.pop(sheetContext, priority),
                    );
                  }),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _showAddCardDialog() async {
    await _prepareCardDialogData();
    if (!mounted) return;

    final titleController = TextEditingController();
    final detailController = TextEditingController();
    String? selectedAssigneeId;
    String? selectedLinkedTicketId;
    CardPriority selectedPriority = CardPriority.normal;
    DateTime? selectedDueDate;
    await showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  title: const Text('Yeni Kart'),
                  content: SizedBox(
                    width: 460,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: titleController,
                          decoration: InputDecoration(
                            labelText: 'Kart basligi',
                            hintText: 'Ne yapilmasi gerekiyor?',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: detailController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: InputDecoration(
                            labelText: 'Kart detayi',
                            hintText:
                                'Basligin altinda gorunecek aciklama, not veya sonraki adimi yaz.',
                            alignLabelWithHint: true,
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Detay alani opsiyoneldir. Yazarsan kart basliginin altinda gorunur.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_supportsTicketLinking)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ilgili is emri (opsiyonel)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _findLinkedTicketById(
                                        selectedLinkedTicketId,
                                      )?.displayLabel ??
                                      'Bir is emrine baglama',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final ticket = await _showTicketPicker(
                                          selectedTicketId:
                                              selectedLinkedTicketId,
                                        );
                                        if (ticket == null) return;
                                        setDialogState(
                                          () =>
                                              selectedLinkedTicketId =
                                                  ticket.id,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.receipt_long_outlined,
                                      ),
                                      label: Text(
                                        selectedLinkedTicketId == null
                                            ? 'Is emri sec'
                                            : 'Is emrini degistir',
                                      ),
                                    ),
                                    if (selectedLinkedTicketId != null) ...[
                                      const SizedBox(width: 10),
                                      TextButton(
                                        onPressed:
                                            () => setDialogState(
                                              () =>
                                                  selectedLinkedTicketId = null,
                                            ),
                                        child: const Text('Temizle'),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.18),
                              ),
                            ),
                            child: const Text(
                              'Is emri baglama su an devre disi. Supabase cards tablosunda linked_ticket_id kolonu kurulunca otomatik acilacak.',
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          _supportsTicketLinking
                              ? 'Sadece bu kart mevcut bir servis isinin takibiyle ilgiliyse bagla. Genel ekip gorevlerinde bos birakmak daha dogru.'
                              : 'Kart olusturma etkilenmez. Is emri baglama alani gecici olarak kapatildi.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sorumlu kisi',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _findAssigneeNameById(selectedAssigneeId) ??
                                    'Atama yapma',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final member = await _showAssigneePicker(
                                        selectedAssigneeId: selectedAssigneeId,
                                      );
                                      if (member == null) return;
                                      setDialogState(
                                        () =>
                                            selectedAssigneeId = member.userId,
                                      );
                                    },
                                    icon: const Icon(Icons.person_outline),
                                    label: const Text('Kisi sec'),
                                  ),
                                  if (selectedAssigneeId != null) ...[
                                    const SizedBox(width: 10),
                                    TextButton(
                                      onPressed:
                                          () => setDialogState(
                                            () => selectedAssigneeId = null,
                                          ),
                                      child: const Text('Temizle'),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: () async {
                            final picked = await _showPriorityPicker(
                              selectedPriority,
                            );
                            if (picked == null) return;
                            setDialogState(() => selectedPriority = picked);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  color: _priorityColor(selectedPriority),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Oncelik',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        selectedPriority.label,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        InkWell(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: selectedDueDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 30),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (pickedDate == null) return;
                            if (!context.mounted) return;
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime:
                                  selectedDueDate == null
                                      ? const TimeOfDay(hour: 18, minute: 0)
                                      : TimeOfDay.fromDateTime(
                                        selectedDueDate!,
                                      ),
                            );
                            if (pickedTime == null) return;
                            setDialogState(() {
                              selectedDueDate = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    selectedDueDate == null
                                        ? 'Son tarih sec'
                                        : 'Son tarih: ${DateFormat('dd.MM.yyyy HH:mm').format(selectedDueDate!)}',
                                    style: TextStyle(
                                      color:
                                          selectedDueDate == null
                                              ? Colors.grey.shade700
                                              : AppColors.textDark,
                                      fontWeight:
                                          selectedDueDate == null
                                              ? FontWeight.w500
                                              : FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (selectedDueDate != null)
                                  IconButton(
                                    onPressed:
                                        () => setDialogState(
                                          () => selectedDueDate = null,
                                        ),
                                    icon: const Icon(Icons.close_rounded),
                                    tooltip: 'Tarihi temizle',
                                  )
                                else
                                  const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Iptal',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: titleController,
                      builder: (_, value, __) {
                        return ElevatedButton(
                          onPressed:
                              value.text.trim().isEmpty
                                  ? null
                                  : () {
                                    _createCard(
                                      title: value.text.trim(),
                                      description: detailController.text,
                                      assigneeId: selectedAssigneeId,
                                      linkedTicketId:
                                          _supportsTicketLinking
                                              ? selectedLinkedTicketId
                                              : null,
                                      priority: selectedPriority,
                                      dueDate: selectedDueDate,
                                    );
                                    Navigator.pop(context);
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.corporateNavy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Olustur'),
                        );
                      },
                    ),
                  ],
                ),
          ),
    );
  }

  void _showSnack(
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red : (isSuccess ? Colors.green : null),
      ),
    );
  }

  void _showStatusMenu(KanbanCard card, CardStatus currentStatus) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Durumu Degistir',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                _buildStatusOption(
                  card,
                  currentStatus,
                  CardStatus.todo,
                  'Yapilacak',
                  Icons.list_alt,
                  const Color(0xFF94A3B8),
                ),
                _buildStatusOption(
                  card,
                  currentStatus,
                  CardStatus.doing,
                  'Devam Eden',
                  Icons.play_circle,
                  const Color(0xFF3B82F6),
                ),
                _buildStatusOption(
                  card,
                  currentStatus,
                  CardStatus.done,
                  'Bitti',
                  Icons.check_circle,
                  const Color(0xFF10B981),
                ),
                _buildStatusOption(
                  card,
                  currentStatus,
                  CardStatus.sent,
                  'Gonderildi',
                  Icons.send,
                  const Color(0xFF8B5CF6),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildStatusOption(
    KanbanCard card,
    CardStatus fromStatus,
    CardStatus toStatus,
    String label,
    IconData icon,
    Color color,
  ) {
    final isCurrent = fromStatus == toStatus;

    return ListTile(
      leading: Icon(
        icon,
        color: isCurrent ? color : AppColors.textLight,
        size: 24,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
          color: isCurrent ? color : AppColors.textDark,
        ),
      ),
      trailing: isCurrent ? Icon(Icons.check, color: color, size: 24) : null,
      onTap:
          isCurrent
              ? null
              : () async {
                Navigator.pop(context);
                await _moveCardToStatus(card, toStatus);
              },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _boards.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _boards.isEmpty) {
      return Center(child: Text(_error!));
    }
    if (_boards.isEmpty) {
      return const Center(child: Text('Pano yok'));
    }

    final todoCards =
        _cards.where((card) => card.status == CardStatus.todo).toList();
    final doingCards =
        _cards.where((card) => card.status == CardStatus.doing).toList();
    final doneCards =
        _cards.where((card) => card.status == CardStatus.done).toList();
    final sentCards =
        _cards.where((card) => card.status == CardStatus.sent).toList();

    return Stack(
      children: [
        Column(
          children: [
            if (_boards.length > 1)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: DropdownButtonFormField<String>(
                  value: _activeBoard?.id,
                  decoration: const InputDecoration(
                    labelText: 'Pano Secin',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  items:
                      _boards
                          .map(
                            (board) => DropdownMenuItem<String>(
                              value: board.id,
                              child: Text(board.name),
                            ),
                          )
                          .toList(),
                  onChanged: (boardId) async {
                    if (boardId == null) return;
                    final board = _boards.firstWhere(
                      (item) => item.id == boardId,
                    );
                    setState(() {
                      _activeBoard = board;
                      _isLoading = true;
                    });
                    await _loadCards();
                  },
                ),
              ),
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.corporateNavy,
                        ),
                      )
                      : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildColumn(
                              'Yapilacak',
                              todoCards,
                              CardStatus.todo,
                            ),
                            _buildColumn(
                              'Devam Eden',
                              doingCards,
                              CardStatus.doing,
                            ),
                            _buildColumn('Bitti', doneCards, CardStatus.done),
                            _buildColumn(
                              'Gonderildi',
                              sentCards,
                              CardStatus.sent,
                            ),
                          ],
                        ),
                      ),
            ),
          ],
        ),
        Positioned(
          left: 24,
          bottom: 24,
          child: FloatingActionButton.extended(
            onPressed: _showAddCardDialog,
            backgroundColor: AppColors.corporateNavy,
            elevation: 6,
            icon: const Icon(Icons.add, color: Colors.white, size: 24),
            label: const Text(
              'Kart Ekle',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColumn(String title, List<KanbanCard> cards, CardStatus status) {
    final headerColor = _statusColor(status);

    return DragTarget<KanbanCard>(
      onWillAccept: (card) => card != null && card.status != status,
      onAccept: (card) => _moveCardToStatus(card, status, showSuccess: false),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return Container(
          width: 300,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isHovering ? headerColor : headerColor.withOpacity(0.3),
                    width: isHovering ? 2.6 : 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: headerColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          color: headerColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: headerColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${cards.length}',
                        style: TextStyle(
                          color: headerColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:
                        isHovering
                            ? headerColor.withOpacity(0.08)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          isHovering
                              ? headerColor.withOpacity(0.35)
                              : Colors.transparent,
                    ),
                  ),
                  child:
                      cards.isEmpty
                          ? Center(
                            child: Text(
                              isHovering ? 'Buraya birak' : 'Bos sutun',
                              style: TextStyle(
                                color:
                                    isHovering
                                        ? headerColor
                                        : AppColors.textLight,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: cards.length,
                            itemBuilder: (context, index) {
                              final card = cards[index];
                              return _buildDraggableCard(
                                card,
                                status,
                                headerColor,
                              );
                            },
                          ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggableCard(
    KanbanCard card,
    CardStatus currentStatus,
    Color accentColor,
  ) {
    return LongPressDraggable<KanbanCard>(
      data: card,
      delay: const Duration(milliseconds: 120),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 288,
          child: _buildCardSurface(
            card,
            currentStatus,
            accentColor,
            enableTap: false,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: _buildCardSurface(card, currentStatus, accentColor),
      ),
      child: _buildCardSurface(card, currentStatus, accentColor),
    );
  }

  Widget _buildCardSurface(
    KanbanCard card,
    CardStatus currentStatus,
    Color accentColor, {
    bool enableTap = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: enableTap ? () => _openCardDetail(card) : null,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.textLight.withOpacity(0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.3,
                      ),
                    ),
                    if (card.description != null &&
                        card.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        card.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textLight.withOpacity(0.8),
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (card.priority != CardPriority.normal ||
                        card.dueDate != null ||
                        card.linkedJobCode != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if ((card.linkedJobCode ?? '').isNotEmpty)
                            _buildMetaChip(
                              icon: Icons.receipt_long_outlined,
                              label: card.linkedJobCode!,
                              color: AppColors.corporateBlue,
                            ),
                          _buildMetaChip(
                            icon: Icons.flag_outlined,
                            label: card.priority.label,
                            color: _priorityColor(card.priority),
                          ),
                          if (card.dueDate != null)
                            _buildMetaChip(
                              icon: Icons.event_outlined,
                              label: DateFormat(
                                'dd.MM HH:mm',
                              ).format(card.dueDate!.toLocal()),
                              color: AppColors.corporateBlue,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (card.assigneeId != null)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 14,
                                    color: accentColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      card.assigneeName ?? 'Atanan kisi',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: accentColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        if (card.assigneeId != null) const SizedBox(width: 8),
                        if (_supportsTicketLinking &&
                            enableTap &&
                            (card.linkedTicketId ?? '').trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: PopupMenuButton<String>(
                              tooltip: 'Bagli is emri islemleri',
                              onSelected: (value) {
                                if (value == 'open_ticket') {
                                  _openLinkedTicket(card);
                                  return;
                                }
                                if (value == 'unlink_ticket') {
                                  _unlinkLinkedTicket(card);
                                }
                              },
                              itemBuilder:
                                  (_) => const [
                                    PopupMenuItem<String>(
                                      value: 'open_ticket',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.open_in_new_outlined,
                                        ),
                                        title: Text('Is emrini ac'),
                                      ),
                                    ),
                                    PopupMenuItem<String>(
                                      value: 'unlink_ticket',
                                      child: ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.link_off_outlined),
                                        title: Text('Baglantiyi kaldir'),
                                      ),
                                    ),
                                  ],
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.corporateBlue.withOpacity(
                                      0.22,
                                    ),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.receipt_long_outlined,
                                  size: 18,
                                  color: AppColors.corporateBlue,
                                ),
                              ),
                            ),
                          ),
                        if (enableTap)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap:
                                    widget.onOpenConversation == null
                                        ? null
                                        : () => widget.onOpenConversation?.call(
                                          card,
                                        ),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: accentColor.withOpacity(0.22),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.forum_outlined,
                                    size: 18,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (enableTap)
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showStatusMenu(card, currentStatus),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.textLight.withOpacity(0.2),
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.more_horiz,
                                  size: 18,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(CardStatus status) {
    switch (status) {
      case CardStatus.todo:
        return const Color(0xFF94A3B8);
      case CardStatus.doing:
        return const Color(0xFF3B82F6);
      case CardStatus.done:
        return const Color(0xFF10B981);
      case CardStatus.sent:
        return const Color(0xFF8B5CF6);
    }
  }

  Color _priorityColor(CardPriority priority) {
    switch (priority) {
      case CardPriority.low:
        return const Color(0xFF5B8DEF);
      case CardPriority.normal:
        return AppColors.corporateYellow;
      case CardPriority.high:
        return AppColors.corporateRed;
    }
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
