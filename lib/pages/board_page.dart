import 'package:flutter/material.dart';
import '../models/board.dart';
import '../models/card.dart';
import '../services/board_service.dart';
import '../services/card_service.dart';
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

  bool _isLoading = true;
  String? _error;
  List<Board> _boards = [];
  Board? _activeBoard;
  List<KanbanCard> _cards = [];

  @override
  void initState() {
    super.initState();
    _loadBoards();
  }

  Future<void> _loadBoards() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final boards = await _boardService.getTeamBoards(widget.teamId);
      if (mounted) {
        setState(() {
          _boards = boards;
        });
        
        if (boards.isNotEmpty) {
          _activeBoard = boards.first;
          await _loadCards();
        } else {
          setState(() {
            _isLoading = false;
            _error = 'Pano bulunamadı.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Yüklenirken hata oluştu: $e';
        });
      }
    }
  }

  Future<void> _loadCards() async {
    if (_activeBoard == null) return;
    try {
      final cards = await _cardService.getBoardCards(_activeBoard!.id);
      if (mounted) {
        setState(() {
          _cards = cards;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Kartlar yüklenemedi: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createCard(String title) async {
    if (_activeBoard == null) return;
    try {
      await _cardService.createCard(
        teamId: widget.teamId,
        boardId: _activeBoard!.id,
        title: title,
      );
      _loadCards(); 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kart oluşturulamadı: $e')),
      );
    }
  }

  Future<void> _openCardDetail(KanbanCard card) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardDetailPage(card: card),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      _loadCards(); // Değişiklik varsa yenile
    }
  }

  Future<void> _showAddCardDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Yeni İş Oluştur'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Ne yapılması gerekiyor?',
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _createCard(controller.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.corporateNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }
  
  void _showSnack(String message, {bool isError = false, bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : (isSuccess ? Colors.green : null),
      ),
    );
  }

  // Durum değiştirme menüsü (Optimistic Update ile)
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
            _buildStatusOption(card, currentStatus, CardStatus.done, 'Bitti', Icons.check_circle, const Color(0xFF10B981)),
            _buildStatusOption(card, currentStatus, CardStatus.sent, 'Gönderildi', Icons.send, const Color(0xFF8B5CF6)),
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
      trailing: isCurrent
          ? Icon(Icons.check, color: color, size: 24)
          : null,
      onTap: isCurrent
          ? null
          : () async {
              Navigator.pop(context);
              
              // OPTIMISTIC UPDATE (hemen UI'ı güncelle)
              final oldCards = List<KanbanCard>.from(_cards);
              setState(() {
                final index = _cards.indexWhere((c) => c.id == card.id);
                if (index != -1) {
                  // Mevcut kartı yeni durumla güncellemek için copyWith kullanıyoruz (gerçi immutable değilmiş, yeni instance oluşturabiliriz)
                  // KanbanCard modeli immutable görünüyor, ama copyWith yok.
                  // Basitçe yeni bir instance oluşturalım:
                  _cards[index] = KanbanCard(
                    id: card.id,
                    boardId: card.boardId,
                    teamId: card.teamId,
                    title: card.title,
                    description: card.description,
                    status: toStatus,
                    createdBy: card.createdBy,
                    assigneeId: card.assigneeId,
                    createdAt: card.createdAt,
                    updatedAt: DateTime.now(),
                  );
                }
              });

              try {
                // Arka planda DB'ye kaydet
                await _cardService.updateCardStatus(card.id, toStatus);
                _showSnack('✓ Durum değiştirildi', isSuccess: true);
              } catch (e) {
                // Hata olursa geri al
                setState(() {
                  _cards = oldCards;
                });
                _showSnack('Hata: $e', isError: true);
              }
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _boards.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _boards.isEmpty) return Center(child: Text(_error!));
    if (_boards.isEmpty) return const Center(child: Text('Pano yok'));

    final todoCards = _cards.where((c) => c.status == CardStatus.todo).toList();
    final doingCards = _cards.where((c) => c.status == CardStatus.doing).toList();
    final doneCards = _cards.where((c) => c.status == CardStatus.done).toList();
    final sentCards = _cards.where((c) => c.status == CardStatus.sent).toList();

    return Stack(
      children: [
        Column(
          children: [
            // Board Selector
            if (_boards.length > 1)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: DropdownButtonFormField<String>(
                  value: _activeBoard?.id,
                  decoration: const InputDecoration(
                    labelText: 'Pano Seçin',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: _boards.map((board) {
                    return DropdownMenuItem<String>(
                      value: board.id,
                      child: Text(board.name),
                    );
                  }).toList(),
                  onChanged: (boardId) async {
                    if (boardId != null) {
                      final board = _boards.firstWhere((b) => b.id == boardId);
                      setState(() {
                        _activeBoard = board;
                        _isLoading = true;
                      });
                      await _loadCards();
                    }
                  },
                ),
              ),

            // Kanban Board
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.corporateNavy),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), 
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildColumn('Yapılacak', todoCards, CardStatus.todo),
                          _buildColumn('Devam Eden', doingCards, CardStatus.doing),
                          _buildColumn('Bitti', doneCards, CardStatus.done),
                          _buildColumn('Gönderildi', sentCards, CardStatus.sent),
                        ],
                      ),
                    ),
            ),
          ],
        ),
        
        // MODERN FAB
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
          // MODERN Column Header (Trello-style)
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

          // Cards List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                return _buildModernCard(card, status, headerColor);
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
           // Atanan kişi bilgisini şimdilik detayda göstermek için modele veya servise ek geliştirme gerekebilir,
           // şimdilik mevcut verilerle detayı açıyoruz.
           await _openCardDetail(card);
        },
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
              // Üst renkli çizgi (Trello-style)
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
                    // Başlık
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.3,
                      ),
                    ),
                    
                    // Açıklama
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
                    
                    // Alt bilgiler
                    Row(
                      children: [
                        // Atanan kişi - Şimdilik icon olarak gösterelim, isim verisi modelde yok
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
                                      'Atanan Kişi', // İsim servisten join ile gelmeli, şimdilik statik
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
                        if (card.assigneeId == null) const Spacer(),
                         if (card.assigneeId != null) const SizedBox(width: 8),

                        // Durum değiştirme butonu
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
}
