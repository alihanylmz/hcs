import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/board.dart';
import '../models/kanban_card.dart';
import '../models/team_member.dart';
import '../services/board_service.dart';
import '../services/card_service.dart';
import '../services/team_service.dart';
import '../theme/app_colors.dart';
import 'card_detail_page.dart';

class BoardPage extends StatefulWidget {
  final String teamId;

  const BoardPage({super.key, required this.teamId});

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> {
  final BoardService _boardService = BoardService();
  final CardService _cardService = CardService();
  final TeamService _teamService = TeamService();

  List<Board> _boards = [];
  Board? _selectedBoard;
  List<KanbanCard> _cards = [];
  List<TeamMember> _teamMembers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final boards = await _boardService.getBoards(widget.teamId);
      Board? selected;
      if (boards.isNotEmpty) {
        selected = boards.first;
      }

      List<KanbanCard> cards = [];
      if (selected != null) {
        cards = await _cardService.getCards(selected.id);
      }

      final members = await _teamService.getTeamMembers(widget.teamId);

      if (mounted) {
        setState(() {
          _boards = boards;
          _selectedBoard = selected;
          _cards = cards;
          _teamMembers = members;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Yükleme hatası: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAddCardDialog() async {
    if (_selectedBoard == null) {
      _showSnack('Önce bir pano seçin', isError: true);
      return;
    }

    final titleController = TextEditingController();
    final descController = TextEditingController();
    String? selectedAssignee;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yeni Kart Ekle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Başlık *',
                    hintText: 'Kart başlığı',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (opsiyonel)',
                    hintText: 'Detaylar',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedAssignee,
                  decoration: const InputDecoration(
                    labelText: 'Atanan Kişi (opsiyonel)',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Atanmamış'),
                    ),
                    ..._teamMembers.map((member) {
                      return DropdownMenuItem<String>(
                        value: member.userId,
                        child: Text(member.fullName ?? 'Üye'),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedAssignee = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Başlık gerekli')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.corporateNavy,
              ),
              child: const Text('Ekle', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        await _cardService.createCard(
          boardId: _selectedBoard!.id,
          teamId: widget.teamId,
          title: titleController.text.trim(),
          description: descController.text.trim().isEmpty
              ? null
              : descController.text.trim(),
          assigneeId: selectedAssignee,
        );
        _showSnack('Kart eklendi', isSuccess: true);
        await _loadData();
      } catch (e) {
        _showSnack('Ekleme hatası: $e', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Colors.red
            : (isSuccess ? Colors.green : Colors.black87),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _selectedBoard == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_selectedBoard == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.view_kanban_outlined,
                size: 80,
                color: AppColors.textLight.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pano bulunamadı',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final todoCards = _cards.where((c) => c.status == CardStatus.todo).toList();
    final doingCards = _cards.where((c) => c.status == CardStatus.doing).toList();

    return Stack(
      children: [
        _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildColumn('Yapılacak', todoCards, CardStatus.todo),
                    _buildColumn('Devam Eden', doingCards, CardStatus.doing),
                  ],
                ),
              ),
        
        Positioned(
          left: 16,
          bottom: 16,
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
    Color headerColor;
    switch (status) {
      case CardStatus.todo:
        headerColor = const Color(0xFF94A3B8);
        break;
      case CardStatus.doing:
        headerColor = const Color(0xFF3B82F6);
        break;
      case CardStatus.done:
        headerColor = const Color(0xFF10B981);
        break;
      case CardStatus.sent:
        headerColor = const Color(0xFF8B5CF6);
        break;
    }

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
                color: headerColor.withOpacity(0.3),
                width: 2,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                return _buildModernCard(cards[index], status, headerColor);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCard(KanbanCard card, CardStatus currentStatus, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CardDetailPage(
                card: card,
                teamId: widget.teamId,
                teamMembers: _teamMembers,
              ),
            ),
          );
          _loadData();
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.textLight.withOpacity(0.1),
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
                    if (card.description != null && card.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        card.description!,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textLight.withOpacity(0.8),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (card.assigneeName != null)
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
                                      card.assigneeName!,
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
                          ),
                        const SizedBox(width: 8),
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
                              child: Icon(
                                Icons.more_horiz,
                                size: 18,
                                color: AppColors.textLight,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 11,
                          color: AppColors.textLight.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd MMM HH:mm', 'tr_TR').format(card.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textLight.withOpacity(0.7),
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

  void _showStatusMenu(KanbanCard card, CardStatus currentStatus) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Durumu Değiştir',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatusOption(card, currentStatus, CardStatus.todo, 'Yapılacak', Icons.list_alt, const Color(0xFF94A3B8)),
            _buildStatusOption(card, currentStatus, CardStatus.doing, 'Devam Eden', Icons.play_circle, const Color(0xFF3B82F6)),
            _buildStatusOption(card, currentStatus, CardStatus.done, 'Tamamlandı', Icons.check_circle, const Color(0xFF10B981)),
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
      leading: Icon(icon, color: isCurrent ? color : AppColors.textLight, size: 24),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
          color: isCurrent ? color : AppColors.textDark,
        ),
      ),
      trailing: isCurrent ? Icon(Icons.check, color: color, size: 24) : null,
      onTap: isCurrent
          ? null
          : () async {
              Navigator.pop(context);
              
              final oldCards = List<KanbanCard>.from(_cards);
              setState(() {
                final index = _cards.indexWhere((c) => c.id == card.id);
                if (index != -1) {
                  _cards[index] = card.copyWith(status: toStatus);
                }
              });

              try {
                await _cardService.changeCardStatus(
                  cardId: card.id,
                  teamId: widget.teamId,
                  fromStatus: fromStatus,
                  toStatus: toStatus,
                );
                _showSnack('✓ Durum değiştirildi', isSuccess: true);
              } catch (e) {
                setState(() => _cards = oldCards);
                _showSnack('Hata: $e', isError: true);
              }
            },
    );
  }
}
