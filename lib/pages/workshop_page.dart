import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/card.dart';
import '../models/ticket_linked_team_card.dart';
import '../services/card_service.dart';
import '../theme/app_colors.dart';
import '../widgets/sidebar/app_layout.dart';
import 'ticket_detail_page.dart';
import 'workshop_recipe_page.dart';

class WorkshopPage extends StatefulWidget {
  const WorkshopPage({super.key});

  @override
  State<WorkshopPage> createState() => _WorkshopPageState();
}

class _WorkshopPageState extends State<WorkshopPage> {
  final CardService _cardService = CardService();
  late Future<List<TicketLinkedTeamCard>> _cardsFuture;
  String _statusFilter = 'active';

  @override
  void initState() {
    super.initState();
    _cardsFuture = _cardService.getWorkshopCards();
  }

  Future<void> _refresh() async {
    setState(() {
      _cardsFuture = _cardService.getWorkshopCards();
    });
  }

  List<TicketLinkedTeamCard> _applyFilter(List<TicketLinkedTeamCard> cards) {
    if (_statusFilter == 'all') return cards;
    if (_statusFilter == 'done') {
      return cards.where((card) => card.status == CardStatus.done).toList();
    }
    return cards.where((card) => card.status != CardStatus.done).toList();
  }

  Future<void> _openCard(TicketLinkedTeamCard item) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkshopRecipePage(cardId: item.cardId),
        fullscreenDialog: true,
      ),
    );
    if (result == true) {
      await _refresh();
    }
  }

  Future<void> _openTicket(TicketLinkedTeamCard item) async {
    final card = await _cardService.getCard(item.cardId);
    final ticketId = card.linkedTicketId;
    if (!mounted || ticketId == null || ticketId.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TicketDetailPage(ticketId: ticketId)),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentPage: AppPage.workshop,
      title: 'Atolye Imalat',
      child: FutureBuilder<List<TicketLinkedTeamCard>>(
        future: _cardsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _emptyState(
              icon: Icons.error_outline,
              title: 'Atolye listesi yuklenemedi',
              message: snapshot.error.toString(),
            );
          }

          final cards = snapshot.data ?? const <TicketLinkedTeamCard>[];
          final filtered = _applyFilter(cards);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _buildSummary(cards),
                const SizedBox(height: 16),
                _buildFilters(),
                const SizedBox(height: 16),
                if (filtered.isEmpty)
                  _emptyState(
                    icon: Icons.precision_manufacturing_outlined,
                    title: 'Atolyede takip edilecek is yok',
                    message:
                        'Is listesinden Atolyeye Gonder ile uretim recetesi olusturunca burada gorunur.',
                  )
                else
                  ...filtered.map(_buildWorkshopCard),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary(List<TicketLinkedTeamCard> cards) {
    final active = cards.where((card) => card.status != CardStatus.done).length;
    final doing = cards.where((card) => card.status == CardStatus.doing).length;
    final done = cards.where((card) => card.status == CardStatus.done).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        final children = [
          _metric(
            'Aktif',
            '$active',
            Icons.pending_actions_outlined,
            AppColors.corporateBlue,
          ),
          _metric(
            'Uretimde',
            '$doing',
            Icons.handyman_outlined,
            const Color(0xFFF59E0B),
          ),
          _metric(
            'Tamamlanan',
            '$done',
            Icons.task_alt_outlined,
            const Color(0xFF10B981),
          ),
        ];
        if (isWide) {
          return Row(
            children: children.map((item) => Expanded(child: item)).toList(),
          );
        }
        return Column(children: children);
      },
    );
  }

  Widget _metric(String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 10, bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'active',
          label: Text('Aktif'),
          icon: Icon(Icons.playlist_add_check),
        ),
        ButtonSegment(
          value: 'done',
          label: Text('Biten'),
          icon: Icon(Icons.done_all_outlined),
        ),
        ButtonSegment(
          value: 'all',
          label: Text('Tumu'),
          icon: Icon(Icons.all_inbox_outlined),
        ),
      ],
      selected: {_statusFilter},
      onSelectionChanged:
          (value) => setState(() => _statusFilter = value.first),
    );
  }

  Widget _buildWorkshopCard(TicketLinkedTeamCard item) {
    final theme = Theme.of(context);
    final dueLabel =
        item.dueDate == null
            ? 'Termin yok'
            : DateFormat(
              'dd.MM.yyyy HH:mm',
              'tr_TR',
            ).format(item.dueDate!.toLocal());

    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.precision_manufacturing_outlined,
                color: _statusColor(item.status),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.teamName} / ${item.boardName}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _statusChip(item.status),
            ],
          ),
          if ((item.description ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              item.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _miniChip(Icons.person_outline, item.assigneeName ?? 'Atanmamis'),
              _miniChip(Icons.event_outlined, dueLabel),
              _miniChip(Icons.flag_outlined, item.priority.label),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _openCard(item),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Uretim Recetesi'),
              ),
              OutlinedButton.icon(
                onPressed: () => _openTicket(item),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Is Emri'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(CardStatus status) {
    return Chip(
      label: Text(status.label),
      avatar: Icon(Icons.circle, size: 12, color: _statusColor(status)),
    );
  }

  Widget _miniChip(IconData icon, String label) {
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Color _statusColor(CardStatus status) {
    switch (status) {
      case CardStatus.todo:
        return AppColors.corporateBlue;
      case CardStatus.doing:
        return const Color(0xFFF59E0B);
      case CardStatus.done:
        return const Color(0xFF10B981);
      case CardStatus.sent:
        return const Color(0xFF8B5CF6);
    }
  }
}
