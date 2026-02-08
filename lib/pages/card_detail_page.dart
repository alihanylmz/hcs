import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/card.dart';
import '../models/card_event.dart';
import '../services/card_service.dart';
import '../theme/app_colors.dart';

class CardDetailPage extends StatefulWidget {
  final KanbanCard card;

  const CardDetailPage({super.key, required this.card});

  @override
  State<CardDetailPage> createState() => _CardDetailPageState();
}

class _CardDetailPageState extends State<CardDetailPage> {
  final CardService _cardService = CardService();
  
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late CardStatus _currentStatus;
  
  bool _isLoading = false;
  List<CardEvent> _history = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.card.title);
    _descController = TextEditingController(text: widget.card.description);
    _currentStatus = widget.card.status;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final events = await _cardService.getCardHistory(widget.card.id);
      if (mounted) {
        setState(() {
          _history = events;
        });
      }
    } catch (e) {
      debugPrint('History load error: $e');
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      // 1. Status değişikliği varsa
      if (_currentStatus != widget.card.status) {
        await _cardService.updateCardStatus(widget.card.id, _currentStatus);
      }

      // 2. Metin değişikliği varsa
      if (_titleController.text != widget.card.title || 
          _descController.text != (widget.card.description ?? '')) {
        await _cardService.updateCardDetails(
          widget.card.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
        );
      }
      
      if (mounted) {
        Navigator.pop(context, true); // Değişiklik yapıldı sinyali
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteCard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sil?'),
        content: const Text('Bu kartı silmek istediğine emin misin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _cardService.deleteCard(widget.card.id);
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _deleteCard,
          ),
          TextButton(
            onPressed: _isLoading ? null : _saveChanges,
            child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Üst Bilgi (Durum vs)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_currentStatus).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getStatusColor(_currentStatus).withOpacity(0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<CardStatus>(
                            value: _currentStatus,
                            isDense: true,
                            icon: Icon(Icons.arrow_drop_down, color: _getStatusColor(_currentStatus)),
                            style: TextStyle(
                              color: _getStatusColor(_currentStatus),
                              fontWeight: FontWeight.bold,
                            ),
                            items: CardStatus.values.map((s) {
                              return DropdownMenuItem(
                                value: s,
                                child: Text(s.label),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _currentStatus = val);
                            },
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.access_time, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd MMM HH:mm').format(widget.card.createdAt),
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Başlık
                  TextField(
                    controller: _titleController,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: 'İş Başlığı',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: null,
                  ),
                  const SizedBox(height: 12),

                  // Açıklama
                  const Text('Açıklama', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _descController,
                      maxLines: 5,
                      decoration: const InputDecoration.collapsed(
                        hintText: 'Daha fazla detay ekle...',
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Tarihçe
                  const Text('Geçmiş', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  if (_history.isEmpty)
                    const Text('Henüz işlem geçmişi yok.', style: TextStyle(color: Colors.grey)),
                  
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _history.length,
                    separatorBuilder: (_,__) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final event = _history[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getEventText(event),
                                  style: const TextStyle(fontSize: 14),
                                ),
                                Text(
                                  DateFormat('dd MMM HH:mm').format(event.createdAt),
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Color _getStatusColor(CardStatus status) {
    switch (status) {
      case CardStatus.todo: return Colors.blueGrey;
      case CardStatus.doing: return Colors.orange;
      case CardStatus.done: return Colors.green;
      case CardStatus.sent: return Colors.purple;
    }
  }

  String _getEventText(CardEvent event) {
    switch (event.eventType) {
      case CardEventType.cardCreated:
        return 'Kart oluşturuldu.';
      case CardEventType.statusChanged:
        return 'Durum değiştirildi: ${event.fromStatus} → ${event.toStatus}';
      case CardEventType.updated:
        return 'Kart güncellendi.';
      default:
        return 'İşlem yapıldı.';
    }
  }
}
