import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/card.dart';
import '../services/card_service.dart';
import '../theme/app_colors.dart';
import 'ticket_detail_page.dart';

class WorkshopRecipePage extends StatefulWidget {
  const WorkshopRecipePage({super.key, required this.cardId});

  final String cardId;

  @override
  State<WorkshopRecipePage> createState() => _WorkshopRecipePageState();
}

class _WorkshopRecipePageState extends State<WorkshopRecipePage> {
  final CardService _cardService = CardService();
  late Future<KanbanCard> _cardFuture;

  @override
  void initState() {
    super.initState();
    _cardFuture = _cardService.getCard(widget.cardId);
  }

  Future<void> _refresh() async {
    setState(() {
      _cardFuture = _cardService.getCard(widget.cardId);
    });
  }

  Future<void> _setStatus(KanbanCard card, CardStatus status) async {
    await _cardService.updateCardStatus(card.id, status);
    await _refresh();
  }

  Future<void> _openTicket(KanbanCard card) async {
    final ticketId = card.linkedTicketId;
    if (ticketId == null || ticketId.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TicketDetailPage(ticketId: ticketId)),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Uretim Recetesi')),
      body: FutureBuilder<KanbanCard>(
        future: _cardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Recete yuklenemedi: ${snapshot.error}'));
          }

          final card = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _heroCard(card),
                const SizedBox(height: 14),
                _statusPanel(card),
                const SizedBox(height: 14),
                _recipeNotes(card),
                const SizedBox(height: 14),
                _filePanel(card),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _heroCard(KanbanCard card) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(card.status);
    final due =
        card.dueDate == null
            ? 'Termin yok'
            : DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(card.dueDate!);

    return Container(
      padding: const EdgeInsets.all(20),
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
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.precision_manufacturing_outlined,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.linkedJobCode ?? 'Bagli is emri',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      card.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(Icons.track_changes_outlined, card.status.label),
              _chip(Icons.flag_outlined, card.priority.label),
              _chip(Icons.person_outline, card.assigneeName ?? 'Atanmamis'),
              _chip(Icons.event_outlined, due),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed:
                card.linkedTicketId == null ? null : () => _openTicket(card),
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Bagli Is Emrini Ac'),
          ),
        ],
      ),
    );
  }

  Widget _statusPanel(KanbanCard card) {
    return _panel(
      title: 'Atolye Akisi',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _statusButton(card, CardStatus.todo, 'Planla'),
          _statusButton(card, CardStatus.doing, 'Uretime Al'),
          _statusButton(card, CardStatus.done, 'Tamamla'),
          _statusButton(card, CardStatus.sent, 'Sevke Hazir'),
        ],
      ),
    );
  }

  Widget _recipeNotes(KanbanCard card) {
    final description =
        (card.description ?? '').trim().isEmpty
            ? 'Bu uretim recetesi icin henuz detay not girilmedi.'
            : card.description!.trim();

    return _panel(
      title: 'Uretim Bilgisi',
      child: Text(description, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  Widget _filePanel(KanbanCard card) {
    return _panel(
      title: 'Proje Dosyalari',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PDF proje, nokta listesi, tek hat semasi ve malzeme listesi bagli is emrinin Evrak/Dosyalar bolumunde tutulur.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                card.linkedTicketId == null ? null : () => _openTicket(card),
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Dosyalari Is Emrinde Ac'),
          ),
        ],
      ),
    );
  }

  Widget _panel({required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _statusButton(KanbanCard card, CardStatus status, String label) {
    final selected = card.status == status;
    return selected
        ? FilledButton.icon(
          onPressed: null,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(label),
        )
        : OutlinedButton(
          onPressed: () => _setStatus(card, status),
          child: Text(label),
        );
  }

  Color _statusColor(CardStatus status) {
    switch (status) {
      case CardStatus.todo:
        return AppColors.corporateBlue;
      case CardStatus.doing:
        return AppColors.statusProgress;
      case CardStatus.done:
        return AppColors.statusDone;
      case CardStatus.sent:
        return const Color(0xFF8B5CF6);
    }
  }
}
