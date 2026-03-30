import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/card.dart';
import '../models/team_member.dart';
import '../models/team_message.dart';
import '../models/team_thread.dart';
import '../services/card_service.dart';
import '../services/team_conversation_service.dart';
import '../services/team_service.dart';
import '../theme/app_colors.dart';

class TeamConversationsPage extends StatefulWidget {
  const TeamConversationsPage({
    super.key,
    required this.teamId,
    required this.canManage,
    this.initialThreadId,
    this.initialCardId,
    this.initialTicketId,
    this.contextRequestId = 0,
    this.onTotalsChanged,
  });

  final String teamId;
  final bool canManage;
  final String? initialThreadId;
  final String? initialCardId;
  final String? initialTicketId;
  final int contextRequestId;
  final ValueChanged<TeamConversationTotals>? onTotalsChanged;

  @override
  State<TeamConversationsPage> createState() => _TeamConversationsPageState();
}

class _TeamConversationsPageState extends State<TeamConversationsPage> {
  final TeamConversationService _conversationService =
      TeamConversationService();
  final TeamService _teamService = TeamService();
  final CardService _cardService = CardService();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  RealtimeChannel? _channel;
  List<TeamThread> _threads = [];
  List<TeamMessage> _messages = [];
  List<TeamMember> _members = [];
  TeamThread? _selectedThread;
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isMessagesLoading = false;
  bool _isSending = false;
  bool _isCardActionRunning = false;
  bool _isThreadDeleteRunning = false;
  String? _error;
  Set<String> _selectedMentionUserIds = <String>{};
  List<TeamMember> _mentionSuggestions = const [];
  int? _activeMentionStart;
  String? _lastHandledContextKey;
  KanbanCard? _linkedCard;

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;
  TeamThread? get _announcementThread {
    for (final thread in _threads) {
      if (thread.type == TeamThreadType.announcement) {
        return thread;
      }
    }
    return null;
  }

  List<TeamThread> get _filteredThreads {
    if (_searchQuery.isEmpty) return _threads;
    return _threads.where((thread) {
      final haystack =
          [
            thread.title,
            thread.description ?? '',
            thread.lastMessagePreview ?? '',
            thread.lastMessageAuthor ?? '',
            thread.type.label,
          ].join(' ').toLowerCase();
      return haystack.contains(_searchQuery);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
    _messageController.addListener(_handleComposerChanged);
    _loadConversationState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant TeamConversationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldContextKey =
        '${oldWidget.initialThreadId}|${oldWidget.initialCardId}|${oldWidget.initialTicketId}';
    final newContextKey =
        '${widget.initialThreadId}|${widget.initialCardId}|${widget.initialTicketId}';
    if ((oldContextKey != newContextKey ||
            oldWidget.contextRequestId != widget.contextRequestId) &&
        newContextKey != 'null|null|null') {
      _applyInitialSelection(force: true);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.removeListener(_handleComposerChanged);
    _messageController.dispose();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  void _subscribe() {
    _channel = _conversationService.subscribeToTeamConversations(
      widget.teamId,
      () async {
        await _loadConversationState(preserveSelection: true, silent: true);
      },
    );
  }

  String? _contextKey() {
    if (widget.initialThreadId != null) {
      return 'thread:${widget.initialThreadId}';
    }
    if (widget.initialCardId != null) {
      return 'card:${widget.initialCardId}';
    }
    if (widget.initialTicketId != null) {
      return 'ticket:${widget.initialTicketId}';
    }
    return null;
  }

  void _notifyTotals(List<TeamThread> threads) {
    if (widget.onTotalsChanged == null) return;
    var unread = 0;
    var mentions = 0;
    for (final thread in threads) {
      unread += thread.unreadCount;
      mentions += thread.mentionCount;
    }
    widget.onTotalsChanged!(
      TeamConversationTotals(unreadCount: unread, mentionCount: mentions),
    );
  }

  void _markThreadAsReadLocally(String threadId) {
    final updatedThreads =
        _threads
            .map(
              (thread) =>
                  thread.id == threadId
                      ? thread.copyWith(unreadCount: 0, mentionCount: 0)
                      : thread,
            )
            .toList();

    TeamThread? updatedSelectedThread = _selectedThread;
    if (updatedSelectedThread?.id == threadId) {
      updatedSelectedThread = updatedSelectedThread?.copyWith(
        unreadCount: 0,
        mentionCount: 0,
      );
    }

    if (!mounted) return;
    setState(() {
      _threads = updatedThreads;
      _selectedThread = updatedSelectedThread;
    });
    _notifyTotals(updatedThreads);
  }

  bool _isThreadReadOnly(TeamThread? thread) {
    if (thread?.cardId == null || _linkedCard == null) return false;
    return _linkedCard!.status == CardStatus.done ||
        _linkedCard!.status == CardStatus.sent;
  }

  bool _isProtectedThread(TeamThread? thread) {
    return thread?.type == TeamThreadType.general ||
        thread?.type == TeamThreadType.announcement;
  }

  bool _canDeleteThread(TeamThread? thread) {
    if (thread == null || _isProtectedThread(thread)) return false;
    return widget.canManage || thread.createdBy == _currentUserId;
  }

  bool _canDeleteLinkedCard(TeamThread? thread) {
    return thread?.cardId != null &&
        _linkedCard != null &&
        (widget.canManage || _linkedCard!.createdBy == _currentUserId);
  }

  bool _canCloseLinkedCard(TeamThread? thread) {
    return thread?.cardId != null &&
        _linkedCard != null &&
        _linkedCard!.status != CardStatus.done &&
        _linkedCard!.status != CardStatus.sent;
  }

  Future<void> _refreshLinkedCard(TeamThread? thread) async {
    final cardId = thread?.cardId;
    if (cardId == null || cardId.isEmpty) {
      if (!mounted) return;
      setState(() => _linkedCard = null);
      return;
    }

    try {
      final card = await _cardService.getCard(cardId);
      if (!mounted || _selectedThread?.id != thread?.id) return;
      setState(() => _linkedCard = card);
    } catch (_) {
      if (!mounted || _selectedThread?.id != thread?.id) return;
      setState(() => _linkedCard = null);
    }
  }

  Future<TeamThread?> _resolveContextThread() async {
    if (widget.initialThreadId != null) {
      for (final thread in _threads) {
        if (thread.id == widget.initialThreadId) {
          return thread;
        }
      }
      return _conversationService.getThreadById(widget.initialThreadId!);
    }
    if (widget.initialCardId != null) {
      return _conversationService.getOrCreateCardThread(
        teamId: widget.teamId,
        cardId: widget.initialCardId!,
      );
    }
    if (widget.initialTicketId != null) {
      return _conversationService.getOrCreateTicketThread(
        teamId: widget.teamId,
        ticketId: widget.initialTicketId!,
      );
    }
    return null;
  }

  Future<void> _applyInitialSelection({bool force = false}) async {
    final contextKey = _contextKey();
    if (contextKey == null) return;
    if (!force && _lastHandledContextKey == contextKey) return;

    try {
      final thread = await _resolveContextThread();
      if (!mounted || thread == null) return;
      _lastHandledContextKey = contextKey;
      await _loadMessagesForThread(thread);
    } catch (_) {
      // Context thread acilmasa da genel sohbeti bozmuyoruz.
    }
  }

  Future<void> _loadConversationState({
    bool preserveSelection = false,
    bool silent = false,
  }) async {
    final selectedThreadId = preserveSelection ? _selectedThread?.id : null;

    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _conversationService.listThreads(widget.teamId),
        _teamService.getTeamMembers(widget.teamId),
      ]);

      final threads = results[0] as List<TeamThread>;
      final members = results[1] as List<TeamMember>;
      _notifyTotals(threads);

      TeamThread? selectedThread;
      if (selectedThreadId != null) {
        for (final thread in threads) {
          if (thread.id == selectedThreadId) {
            selectedThread = thread;
            break;
          }
        }
      }
      selectedThread ??= threads.isNotEmpty ? threads.first : null;

      if (!mounted) return;
      setState(() {
        _threads = threads;
        _members = members;
        _selectedThread = selectedThread;
        _isLoading = false;
      });

      if (selectedThread != null) {
        await _loadMessagesForThread(
          selectedThread,
          showLoader: !silent,
          markAsRead: true,
        );
        await _applyInitialSelection();
      } else if (mounted) {
        setState(() {
          _messages = [];
          _linkedCard = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Konusmalar yuklenemedi: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMessagesForThread(
    TeamThread thread, {
    bool showLoader = true,
    bool markAsRead = true,
  }) async {
    if (showLoader) {
      setState(() {
        _selectedThread = thread;
        _messages = [];
        _linkedCard = null;
        _isMessagesLoading = true;
      });
    } else {
      setState(() {
        _selectedThread = thread;
        if (_linkedCard?.id != thread.cardId) {
          _linkedCard = null;
        }
      });
    }

    try {
      final messages = await _conversationService.getMessages(thread.id);
      if (!mounted) return;

      setState(() {
        _selectedThread = thread;
        _messages = messages;
        _isMessagesLoading = false;
      });
      await _refreshLinkedCard(thread);

      if (messages.isNotEmpty && markAsRead) {
        await _conversationService.markThreadRead(
          thread.id,
          lastReadMessageId: messages.last.id,
        );
        _markThreadAsReadLocally(thread.id);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isMessagesLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mesajlar yuklenemedi: $error')));
    }
  }

  Future<void> _sendMessage() async {
    final thread = _selectedThread;
    if (thread == null) return;
    if (_isThreadReadOnly(thread)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kapali kart konusmalarina yeni mesaj eklenemez.'),
        ),
      );
      return;
    }

    final body = _messageController.text.trim();
    if (body.isEmpty && _selectedMentionUserIds.isEmpty) {
      return;
    }

    setState(() => _isSending = true);

    try {
      await _conversationService.sendMessage(
        teamId: widget.teamId,
        threadId: thread.id,
        body: body,
        mentionUserIds: _selectedMentionUserIds.toList(),
      );

      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _selectedMentionUserIds = <String>{};
        _mentionSuggestions = const [];
        _activeMentionStart = null;
        _isSending = false;
      });
      await _loadMessagesForThread(
        thread,
        showLoader: false,
        markAsRead: false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mesaj gonderilemedi: $error')));
    }
  }

  void _handleComposerChanged() {
    final value = _messageController.value;
    final text = value.text;
    final selection = value.selection;
    final cursorIndex =
        selection.isValid && selection.baseOffset >= 0
            ? selection.baseOffset
            : text.length;

    if (cursorIndex < 0 || cursorIndex > text.length) {
      _clearMentionSuggestions();
      return;
    }

    final textUntilCursor = text.substring(0, cursorIndex);
    final mentionStart = textUntilCursor.lastIndexOf('@');
    if (mentionStart == -1) {
      _clearMentionSuggestions();
      return;
    }

    final mentionQuery = textUntilCursor.substring(mentionStart + 1);
    if (mentionQuery.contains(RegExp(r'\s'))) {
      _clearMentionSuggestions();
      return;
    }

    final normalizedQuery = mentionQuery.trim().toLowerCase();
    final suggestions =
        _members
            .where((member) {
              final name = member.displayName.toLowerCase();
              final email = (member.email ?? '').toLowerCase();
              if (normalizedQuery.isEmpty) return true;
              return name.contains(normalizedQuery) ||
                  email.contains(normalizedQuery);
            })
            .take(6)
            .toList();

    if (!mounted) return;
    setState(() {
      _activeMentionStart = mentionStart;
      _mentionSuggestions = suggestions;
    });
  }

  void _clearMentionSuggestions() {
    if (!mounted) return;
    if (_mentionSuggestions.isEmpty && _activeMentionStart == null) return;
    setState(() {
      _mentionSuggestions = const [];
      _activeMentionStart = null;
    });
  }

  void _insertMention(TeamMember member) {
    final value = _messageController.value;
    final text = value.text;
    final selection = value.selection;
    final cursorIndex =
        selection.isValid && selection.baseOffset >= 0
            ? selection.baseOffset
            : text.length;
    final mentionStart = _activeMentionStart;

    if (mentionStart == null || mentionStart > cursorIndex) {
      return;
    }

    final prefix = text.substring(0, mentionStart);
    final suffix = text.substring(cursorIndex);
    final mentionText = '@${member.displayName} ';
    final newText = '$prefix$mentionText$suffix';
    final newCursor = (prefix + mentionText).length;

    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );

    setState(() {
      _selectedMentionUserIds.add(member.userId);
      _mentionSuggestions = const [];
      _activeMentionStart = null;
    });
  }

  Future<void> _openAnnouncementThread() async {
    final announcementThread = _announcementThread;
    if (announcementThread == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duyuru kanali henuz hazir degil.')),
      );
      return;
    }
    await _loadMessagesForThread(announcementThread);
  }

  Future<void> _closeLinkedCard() async {
    final card = _linkedCard;
    final thread = _selectedThread;
    if (card == null || thread?.cardId == null) return;

    if (card.status == CardStatus.done || card.status == CardStatus.sent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kart zaten kapatildi.')));
      return;
    }

    setState(() => _isCardActionRunning = true);
    try {
      await _cardService.updateCardStatus(card.id, CardStatus.done);
      await _refreshLinkedCard(thread);
      if (!mounted) return;
      setState(() {
        _threads =
            _threads
                .map(
                  (item) =>
                      item.id == thread!.id
                          ? item.copyWith(
                            description:
                                'Kart kapatildi. Bu konusma artik yalnizca okunur.',
                          )
                          : item,
                )
                .toList();
        _selectedThread =
            _selectedThread?.id == thread!.id
                ? _selectedThread?.copyWith(
                  description:
                      'Kart kapatildi. Bu konusma artik yalnizca okunur.',
                )
                : _selectedThread;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kart kapatildi.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kart kapatilamadi: $error')));
    } finally {
      if (mounted) {
        setState(() => _isCardActionRunning = false);
      }
    }
  }

  Future<void> _deleteLinkedCard() async {
    final card = _linkedCard;
    final thread = _selectedThread;
    if (card == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Kart silinsin mi?'),
            content: const Text(
              'Bu islem karti Supabase tarafindan kalici olarak siler. Bagli konusma ve mesajlar da birlikte silinir.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgec'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.corporateRed,
                ),
                child: const Text('Sil'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() => _isCardActionRunning = true);
    try {
      if (thread != null && thread.cardId != null) {
        await _conversationService.deleteThread(thread.id);
      }
      await _cardService.deleteCard(card.id);
      if (!mounted) return;
      await _loadConversationState(preserveSelection: false, silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kart ve bagli konusma Supabase tarafindan silindi.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kart silinemedi: $error')));
    } finally {
      if (mounted) {
        setState(() => _isCardActionRunning = false);
      }
    }
  }

  String _threadDeleteDescription(TeamThread thread) {
    switch (thread.type) {
      case TeamThreadType.card:
        return 'Bu islem sadece konusma kanalini ve mesajlarini kalici olarak siler. Kart kaydi yerinde kalir ve tekrar acildiginda yeni bir konusma olusturulabilir.';
      case TeamThreadType.ticket:
        return 'Bu islem sadece konusma kanalini ve mesajlarini kalici olarak siler. Bagli is emri kaydi silinmez.';
      case TeamThreadType.general:
      case TeamThreadType.announcement:
        return 'Bu kanal korunuyor ve silinemez.';
    }
  }

  Future<void> _deleteSelectedThread() async {
    final thread = _selectedThread;
    if (thread == null || !_canDeleteThread(thread)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Konusma silinsin mi?'),
            content: Text(_threadDeleteDescription(thread)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Vazgec'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.corporateRed,
                ),
                child: const Text('Sil'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() => _isThreadDeleteRunning = true);
    try {
      await _conversationService.deleteThread(thread.id);
      if (!mounted) return;
      await _loadConversationState(preserveSelection: false, silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${thread.title}" konusmasi silindi.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Konusma silinemedi: $error')));
    } finally {
      if (mounted) {
        setState(() => _isThreadDeleteRunning = false);
      }
    }
  }

  Future<void> _showMentionPicker() async {
    final currentSelections = Set<String>.from(_selectedMentionUserIds);

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mention ekle',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children:
                            _members.map((member) {
                              final selected = currentSelections.contains(
                                member.userId,
                              );
                              return CheckboxListTile(
                                dense: true,
                                value: selected,
                                title: Text(member.displayName),
                                subtitle: Text(member.role.label),
                                onChanged: (value) {
                                  setModalState(() {
                                    if (value == true) {
                                      currentSelections.add(member.userId);
                                    } else {
                                      currentSelections.remove(member.userId);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Iptal'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed:
                              () => Navigator.pop(context, currentSelections),
                          child: const Text('Uygula'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() => _selectedMentionUserIds = result);
  }

  Future<void> _showNewThreadDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final cardIdController = TextEditingController();
    final ticketIdController = TextEditingController();
    TeamThreadType selectedType = TeamThreadType.card;

    bool canSubmit() {
      switch (selectedType) {
        case TeamThreadType.card:
          return cardIdController.text.trim().isNotEmpty;
        case TeamThreadType.ticket:
          return ticketIdController.text.trim().isNotEmpty;
        case TeamThreadType.general:
        case TeamThreadType.announcement:
          return titleController.text.trim().isNotEmpty;
      }
    }

    final created = await showDialog<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Yeni konusma kanali'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<TeamThreadType>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Kanal tipi',
                        ),
                        items:
                            const [TeamThreadType.card, TeamThreadType.ticket]
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type.label),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => selectedType = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Baslik'),
                        autofocus: true,
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 12),
                      if (selectedType == TeamThreadType.card)
                        TextField(
                          controller: cardIdController,
                          decoration: const InputDecoration(
                            labelText: 'Bagli kart ID',
                            helperText:
                                'Karttan acarsan otomatik dolar. Elle de girebilirsin.',
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      if (selectedType == TeamThreadType.ticket)
                        TextField(
                          controller: ticketIdController,
                          decoration: const InputDecoration(
                            labelText: 'Bagli is emri ID',
                            helperText:
                                'Takim icinde izlenecek is emri numarasini gir.',
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      if (selectedType == TeamThreadType.card ||
                          selectedType == TeamThreadType.ticket)
                        const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Kisa aciklama',
                        ),
                        minLines: 2,
                        maxLines: 3,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Iptal'),
                    ),
                    FilledButton(
                      onPressed:
                          canSubmit()
                              ? () => Navigator.pop(context, true)
                              : null,
                      child: const Text('Olustur'),
                    ),
                  ],
                ),
          ),
    );

    if (created != true) return;

    try {
      TeamThread thread;
      if (selectedType == TeamThreadType.card) {
        thread = await _conversationService.getOrCreateCardThread(
          teamId: widget.teamId,
          cardId: cardIdController.text.trim(),
          fallbackTitle: titleController.text.trim(),
        );
      } else if (selectedType == TeamThreadType.ticket) {
        thread = await _conversationService.getOrCreateTicketThread(
          teamId: widget.teamId,
          ticketId: ticketIdController.text.trim(),
          fallbackTitle: titleController.text.trim(),
        );
      } else {
        thread = await _conversationService.createThread(
          teamId: widget.teamId,
          type: selectedType,
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          pinned: true,
        );
      }
      if (!mounted) return;
      await _loadConversationState(preserveSelection: true, silent: true);
      await _loadMessagesForThread(thread);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kanal olusturulamadi: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 1080;
    final selectedThread = _selectedThread;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child:
          isWide
              ? Row(
                children: [
                  SizedBox(width: 320, child: _buildThreadPanel(theme)),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: _buildConversationPanel(theme, selectedThread),
                  ),
                  SizedBox(
                    width: 280,
                    child: _buildContextPanel(theme, selectedThread),
                  ),
                ],
              )
              : Column(
                children: [
                  _buildCompactHeader(theme),
                  Expanded(
                    child: _buildConversationPanel(theme, selectedThread),
                  ),
                ],
              ),
    );
  }

  Widget _buildCompactHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedThread?.id,
                  decoration: const InputDecoration(labelText: 'Kanal'),
                  items:
                      _filteredThreads
                          .map(
                            (thread) => DropdownMenuItem<String>(
                              value: thread.id,
                              child: Text(thread.title),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value == null || _threads.isEmpty) return;
                    final thread = _threads.firstWhere(
                      (item) => item.id == value,
                      orElse: () => _threads.first,
                    );
                    _loadMessagesForThread(thread);
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: widget.canManage ? _showNewThreadDialog : null,
                icon: const Icon(Icons.add_comment_outlined),
                tooltip: 'Kanal ekle',
              ),
            ],
          ),
          if (_announcementThread != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _openAnnouncementThread,
                icon: const Icon(Icons.campaign_outlined),
                label: const Text('Duyurular'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Kanal veya mesaj ara',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadPanel(ThemeData theme) {
    return Container(
      color: theme.cardColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Konusmalar',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: widget.canManage ? _showNewThreadDialog : null,
                      icon: const Icon(Icons.add_comment_outlined),
                      tooltip: 'Kanal ekle',
                    ),
                  ],
                ),
                if (_announcementThread != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openAnnouncementThread,
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('Sabit duyuru kanalini ac'),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Kanal veya mesaj ara',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
              itemCount: _filteredThreads.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final thread = _filteredThreads[index];
                final selected = thread.id == _selectedThread?.id;
                return _buildThreadTile(theme, thread, selected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreadTile(ThemeData theme, TeamThread thread, bool selected) {
    final color = _threadTypeColor(thread.type);

    return InkWell(
      onTap: () => _loadMessagesForThread(thread),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              selected
                  ? theme.colorScheme.primary.withOpacity(0.12)
                  : theme.scaffoldBackgroundColor.withOpacity(0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                selected
                    ? theme.colorScheme.primary.withOpacity(0.28)
                    : theme.dividerColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    thread.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (thread.hasMentions)
                  _buildCounterBadge(
                    '@${thread.mentionCount}',
                    AppColors.corporateRed,
                  )
                else if (thread.hasUnread)
                  _buildCounterBadge(
                    '${thread.unreadCount}',
                    theme.colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTypeChip(thread.type.label, color),
                if (thread.isPinned)
                  _buildTypeChip('Sabit', AppColors.corporateYellow),
              ],
            ),
            if ((thread.lastMessagePreview ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                thread.lastMessagePreview!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.72),
                ),
              ),
            ] else if ((thread.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                thread.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.72),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    thread.lastMessageAuthor ?? 'Mesaj bekliyor',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.54),
                    ),
                  ),
                ),
                Text(
                  DateFormat(
                    'dd.MM HH:mm',
                    'tr_TR',
                  ).format(thread.lastMessageAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationPanel(ThemeData theme, TeamThread? selectedThread) {
    if (selectedThread == null) {
      return Center(
        child: Text(
          'Konusma secildiginde mesaj akisi burada gorunecek.',
          style: theme.textTheme.bodyLarge,
        ),
      );
    }

    final showActionMenu =
        _canCloseLinkedCard(selectedThread) ||
        _canDeleteThread(selectedThread) ||
        _canDeleteLinkedCard(selectedThread);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedThread.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selectedThread.description?.trim().isNotEmpty == true
                          ? selectedThread.description!
                          : 'Takim icinde baglamli bir konusma alani.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.68),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildTypeChip(
                selectedThread.type.label,
                _threadTypeColor(selectedThread.type),
              ),
              if (showActionMenu) ...[
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  enabled: !_isCardActionRunning && !_isThreadDeleteRunning,
                  tooltip: 'Kanal islemleri',
                  onSelected: (value) {
                    switch (value) {
                      case 'close_card':
                        _closeLinkedCard();
                        break;
                      case 'delete_thread':
                        _deleteSelectedThread();
                        break;
                      case 'delete_card':
                        _deleteLinkedCard();
                        break;
                    }
                  },
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<String>>[];
                    if (_canCloseLinkedCard(selectedThread)) {
                      items.add(
                        const PopupMenuItem<String>(
                          value: 'close_card',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline),
                              SizedBox(width: 10),
                              Text('Karti kapat'),
                            ],
                          ),
                        ),
                      );
                    }
                    if (_canDeleteThread(selectedThread)) {
                      if (items.isNotEmpty) {
                        items.add(const PopupMenuDivider());
                      }
                      items.add(
                        const PopupMenuItem<String>(
                          value: 'delete_thread',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_sweep_outlined,
                                color: AppColors.corporateRed,
                              ),
                              SizedBox(width: 10),
                              Text('Konusmayi sil'),
                            ],
                          ),
                        ),
                      );
                    }
                    if (_canDeleteLinkedCard(selectedThread)) {
                      if (items.isNotEmpty) {
                        items.add(const PopupMenuDivider());
                      }
                      items.add(
                        const PopupMenuItem<String>(
                          value: 'delete_card',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                color: AppColors.corporateRed,
                              ),
                              SizedBox(width: 10),
                              Text('Karti sil'),
                            ],
                          ),
                        ),
                      );
                    }
                    return items;
                  },
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child:
              _messages.isEmpty && _isMessagesLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? Center(
                    child: Text(
                      'Henuz mesaj yok. Konusmayi ilk sen baslat.',
                      style: theme.textTheme.bodyLarge,
                    ),
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    itemCount: _messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(theme, message);
                    },
                  ),
        ),
        _buildComposer(theme, selectedThread),
      ],
    );
  }

  Widget _buildMessageBubble(ThemeData theme, TeamMessage message) {
    final isMine = message.isAuthoredBy(_currentUserId);
    final isMentioned =
        _currentUserId != null &&
        message.mentionedUserIds.contains(_currentUserId);

    final bubbleColor =
        isMine
            ? theme.colorScheme.primary
            : isMentioned
            ? AppColors.corporateYellow.withOpacity(0.16)
            : theme.cardColor;

    final textColor =
        isMine ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    final alignment =
        isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          isMine ? 'Sen' : (message.authorName ?? 'Kullanici'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.58),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          constraints: const BoxConstraints(maxWidth: 640),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  isMine
                      ? theme.colorScheme.primary
                      : theme.dividerColor.withOpacity(0.75),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.mentionedUserIds.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isMine
                            ? Colors.white.withOpacity(0.16)
                            : AppColors.corporateBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Mention',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                message.body,
                style: theme.textTheme.bodyLarge?.copyWith(color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat(
                  'dd.MM.yyyy HH:mm',
                  'tr_TR',
                ).format(message.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      isMine
                          ? Colors.white.withOpacity(0.78)
                          : theme.colorScheme.onSurface.withOpacity(0.54),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComposer(ThemeData theme, TeamThread selectedThread) {
    final isReadOnly = _isThreadReadOnly(selectedThread);
    final selectedMentions = _members.where(
      (member) => _selectedMentionUserIds.contains(member.userId),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_mentionSuggestions.isNotEmpty) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Column(
                children:
                    _mentionSuggestions.map((member) {
                      final isSelected = _selectedMentionUserIds.contains(
                        member.userId,
                      );
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.corporateBlue.withOpacity(
                            0.12,
                          ),
                          child: Text(
                            member.displayName.characters.first.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.corporateBlue,
                            ),
                          ),
                        ),
                        title: Text(member.displayName),
                        subtitle:
                            member.email == null
                                ? null
                                : Text(member.email!, maxLines: 1),
                        trailing:
                            isSelected
                                ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.corporateBlue,
                                )
                                : null,
                        onTap: () => _insertMention(member),
                      );
                    }).toList(),
              ),
            ),
          ],
          if (_selectedMentionUserIds.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  selectedMentions.map((member) {
                    return InputChip(
                      label: Text('@${member.displayName}'),
                      onDeleted: () {
                        setState(() {
                          _selectedMentionUserIds.remove(member.userId);
                        });
                      },
                    );
                  }).toList(),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton.filledTonal(
                onPressed: isReadOnly ? null : _showMentionPicker,
                icon: const Icon(Icons.alternate_email),
                tooltip: 'Mention ekle',
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: !isReadOnly,
                  minLines: 1,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText:
                        isReadOnly
                            ? 'Bu kart kapatildi. Konusma yalnizca okunur.'
                            : '"${selectedThread.title}" kanalina mesaj yaz... mention icin @ yaz',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: (_isSending || isReadOnly) ? null : _sendMessage,
                icon:
                    _isSending
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.send_rounded),
                label: const Text('Gonder'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextPanel(ThemeData theme, TeamThread? selectedThread) {
    final canDeleteConversation = _canDeleteThread(selectedThread);
    final canDeleteLinkedCard = _canDeleteLinkedCard(selectedThread);
    final canCloseLinkedCard = _canCloseLinkedCard(selectedThread);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child:
          selectedThread == null
              ? const SizedBox.shrink()
              : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Baglam',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      theme,
                      'Kanal Tipi',
                      selectedThread.type.label,
                      icon: Icons.forum_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      theme,
                      'Okunmamis',
                      '${selectedThread.unreadCount}',
                      icon: Icons.mark_chat_unread_outlined,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      theme,
                      'Mention',
                      '${selectedThread.mentionCount}',
                      icon: Icons.alternate_email,
                    ),
                    if (selectedThread.ticketId != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        theme,
                        'Bagli Is Emri',
                        '#${selectedThread.ticketId}',
                        icon: Icons.receipt_long_outlined,
                      ),
                    ],
                    if (selectedThread.cardId != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        theme,
                        'Bagli Kart',
                        selectedThread.cardId!,
                        icon: Icons.view_kanban_outlined,
                      ),
                      if (_linkedCard != null) ...[
                        const SizedBox(height: 12),
                        _buildInfoCard(
                          theme,
                          'Kart Durumu',
                          _linkedCard!.status.label,
                          icon: Icons.task_alt_outlined,
                        ),
                        if (_isThreadReadOnly(selectedThread)) ...[
                          const SizedBox(height: 12),
                          _buildInfoCard(
                            theme,
                            'Konusma Durumu',
                            'Yalnizca okunur',
                            icon: Icons.lock_outline_rounded,
                          ),
                        ],
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              canCloseLinkedCard && !_isCardActionRunning
                                  ? _closeLinkedCard
                                  : null,
                          icon:
                              _isCardActionRunning
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.check_circle_outline),
                          label: Text(
                            canCloseLinkedCard ? 'Karti Kapat' : 'Kart Kapali',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              canDeleteLinkedCard && !_isCardActionRunning
                                  ? _deleteLinkedCard
                                  : null,
                          icon: const Icon(Icons.delete_outline),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.corporateRed,
                          ),
                          label: const Text('Karti Supabase\'den Sil'),
                        ),
                      ),
                    ],
                    if (canDeleteConversation) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              !_isThreadDeleteRunning
                                  ? _deleteSelectedThread
                                  : null,
                          icon:
                              _isThreadDeleteRunning
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.delete_sweep_outlined),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.corporateRed,
                          ),
                          label: const Text('Konusmayi Sil'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'Notlar',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Bu alan genel takim sohbeti, kart baglamli konusma ve is emri kararlarini tek yerde toplamak icin tasarlandi. Mention ekleyerek kritik konulari takipte tutabilirsin.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.68),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildInfoCard(
    ThemeData theme,
    String label,
    String value, {
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withOpacity(0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.58),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildCounterBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _threadTypeColor(TeamThreadType type) {
    switch (type) {
      case TeamThreadType.general:
        return AppColors.corporateBlue;
      case TeamThreadType.card:
        return AppColors.statusDone;
      case TeamThreadType.ticket:
        return AppColors.corporateYellow;
      case TeamThreadType.announcement:
        return AppColors.corporateRed;
    }
  }
}
