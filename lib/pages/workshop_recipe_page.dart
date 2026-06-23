import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/card.dart';
import '../services/card_service.dart';
import '../services/ticket_service.dart';
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
  final TicketService _ticketService = TicketService();
  late Future<KanbanCard> _cardFuture;
  final _panelTypeController = TextEditingController();
  final _mainBreakerController = TextEditingController();
  final _drivePowerController = TextEditingController();
  final _plcModelController = TextEditingController();
  final _controlVoltageController = TextEditingController();
  final _notesController = TextEditingController();
  final List<TextEditingController> _motorControllers = [];
  String _fileType = 'Proje PDF';
  bool _isSaving = false;
  bool _isUploading = false;
  String? _loadedCardId;

  @override
  void initState() {
    super.initState();
    _cardFuture = _cardService.getCard(widget.cardId);
  }

  @override
  void dispose() {
    _panelTypeController.dispose();
    _mainBreakerController.dispose();
    _drivePowerController.dispose();
    _plcModelController.dispose();
    _controlVoltageController.dispose();
    _notesController.dispose();
    for (final controller in _motorControllers) {
      controller.dispose();
    }
    super.dispose();
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

  void _loadRecipeIfNeeded(KanbanCard card) {
    if (_loadedCardId == card.id) return;
    _loadedCardId = card.id;
    final data = _extractRecipe(card.description);
    _panelTypeController.text = data['panel_type']?.toString() ?? '';
    _mainBreakerController.text = data['main_breaker']?.toString() ?? '';
    _drivePowerController.text = data['drive_power']?.toString() ?? '';
    _plcModelController.text = data['plc_model']?.toString() ?? '';
    _controlVoltageController.text = data['control_voltage']?.toString() ?? '';
    _notesController.text =
        data['notes']?.toString() ?? _stripRecipeBlock(card.description);
    _motorControllers.clear();
    final motors = data['motors'];
    if (motors is List && motors.isNotEmpty) {
      for (final motor in motors) {
        _motorControllers.add(TextEditingController(text: motor.toString()));
      }
    } else {
      _motorControllers.add(TextEditingController());
    }
  }

  Map<String, dynamic> _extractRecipe(String? description) {
    final text = description ?? '';
    final match = RegExp(
      r'---WORKSHOP_RECIPE_JSON---\s*([\s\S]*?)\s*---END_WORKSHOP_RECIPE_JSON---',
    ).firstMatch(text);
    if (match == null) return {};
    try {
      final decoded = jsonDecode(match.group(1) ?? '{}');
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  String _stripRecipeBlock(String? description) {
    return (description ?? '')
        .replaceAll(
          RegExp(
            r'---WORKSHOP_RECIPE_JSON---\s*[\s\S]*?\s*---END_WORKSHOP_RECIPE_JSON---',
          ),
          '',
        )
        .trim();
  }

  Future<void> _saveRecipe(KanbanCard card) async {
    setState(() => _isSaving = true);
    final motors =
        _motorControllers
            .map((controller) => controller.text.trim())
            .where((value) => value.isNotEmpty)
            .toList();
    final data = {
      'panel_type': _panelTypeController.text.trim(),
      'main_breaker': _mainBreakerController.text.trim(),
      'motors': motors,
      'drive_power': _drivePowerController.text.trim(),
      'plc_model': _plcModelController.text.trim(),
      'control_voltage': _controlVoltageController.text.trim(),
      'notes': _notesController.text.trim(),
    };
    final encoded = const JsonEncoder.withIndent('  ').convert(data);
    final humanSummary = [
      '[ATOLYE] Uretim recetesi',
      if (_panelTypeController.text.trim().isNotEmpty)
        'Panel tipi: ${_panelTypeController.text.trim()}',
      if (_mainBreakerController.text.trim().isNotEmpty)
        'Ana salter: ${_mainBreakerController.text.trim()}',
      if (motors.isNotEmpty) 'Motorlar: ${motors.join(', ')}',
      if (_drivePowerController.text.trim().isNotEmpty)
        'Surucu: ${_drivePowerController.text.trim()}',
      if (_plcModelController.text.trim().isNotEmpty)
        'PLC: ${_plcModelController.text.trim()}',
      if (_controlVoltageController.text.trim().isNotEmpty)
        'Kontrol voltaji: ${_controlVoltageController.text.trim()}',
      '',
      _notesController.text.trim(),
      '',
      '---WORKSHOP_RECIPE_JSON---',
      encoded,
      '---END_WORKSHOP_RECIPE_JSON---',
    ].join('\n');

    try {
      await _cardService.updateCardDetails(card.id, description: humanSummary);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uretim recetesi kaydedildi.')),
      );
      await _refresh();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadProjectFile(KanbanCard card) async {
    final ticketId = card.linkedTicketId;
    if (ticketId == null || ticketId.isEmpty) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'xlsx', 'xls', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _isUploading = true);
    try {
      final file = result.files.first;
      final url = await _ticketService.uploadFile(ticketId, file);
      if (url != null) {
        await _ticketService.addNote(
          ticketId,
          'Atolye proje dosyasi eklendi\nTur: $_fileType\nDosya: ${file.name}\n$url',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(url == null ? 'Dosya yuklenemedi.' : 'Dosya yuklendi.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
          _loadRecipeIfNeeded(card);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _heroCard(card),
                const SizedBox(height: 14),
                _statusPanel(card),
                const SizedBox(height: 14),
                _technicalForm(card),
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

  Widget _technicalForm(KanbanCard card) {
    return _panel(
      title: 'Teknik Ozellikler',
      child: Column(
        children: [
          _field(
            _panelTypeController,
            'Panel Tipi',
            'Duvar tipi, dikili tip...',
          ),
          const SizedBox(height: 12),
          _field(_mainBreakerController, 'Ana Salter Degeri', 'Orn: 125A'),
          const SizedBox(height: 12),
          _field(_drivePowerController, 'Surucu Gucu', 'Orn: 22 kW'),
          const SizedBox(height: 12),
          _field(_plcModelController, 'PLC Modeli', 'Orn: Siemens S7-1200'),
          const SizedBox(height: 12),
          _field(_controlVoltageController, 'Kontrol Voltaji', 'Orn: 24V DC'),
          const SizedBox(height: 16),
          _motorList(),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Uretim Notlari',
              hintText:
                  'Klemens, etiket, test, sevk veya ozel imalat notlari...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : () => _saveRecipe(card),
              icon:
                  _isSaving
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.save_outlined),
              label: const Text('Receteyi Kaydet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  Widget _motorList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Motor Gucleri',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _motorControllers.add(TextEditingController());
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Motor Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(_motorControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _motorControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Motor ${index + 1}',
                      hintText: 'Orn: 7.5 kW',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed:
                      _motorControllers.length == 1
                          ? null
                          : () {
                            setState(() {
                              final controller = _motorControllers.removeAt(
                                index,
                              );
                              controller.dispose();
                            });
                          },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _filePanel(KanbanCard card) {
    return _panel(
      title: 'Proje Dosyalari',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _fileType,
            decoration: const InputDecoration(labelText: 'Dosya Turu'),
            items:
                const [
                      'Proje PDF',
                      'Nokta Listesi',
                      'Tek Hat Semasi',
                      'Malzeme Listesi',
                      'Excel',
                      'Fotograf',
                      'Diger',
                    ]
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
            onChanged:
                (value) => setState(() => _fileType = value ?? _fileType),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed:
                    card.linkedTicketId == null || _isUploading
                        ? null
                        : () => _uploadProjectFile(card),
                icon:
                    _isUploading
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.upload_file_outlined),
                label: const Text('Dosya Yukle'),
              ),
              OutlinedButton.icon(
                onPressed:
                    card.linkedTicketId == null
                        ? null
                        : () => _openTicket(card),
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Is Emrindeki Dosyalar'),
              ),
            ],
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
