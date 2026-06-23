import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
  final _panelWidthController = TextEditingController();
  final _panelHeightController = TextEditingController();
  final _mainBreakerController = TextEditingController();
  final _drivePowerController = TextEditingController();
  final _drivePower2Controller = TextEditingController();
  final _condenserDriveController = TextEditingController();
  final _condenserDrive2Controller = TextEditingController();
  final _compressorController = TextEditingController();
  final _compressor2Controller = TextEditingController();
  final _jetfanController = TextEditingController();
  final _plcModelController = TextEditingController();
  final _controlVoltageController = TextEditingController();
  final _notesController = TextEditingController();
  String _panelType = 'Icten Tava';
  String _fileType = 'Proje PDF';
  bool _isSaving = false;
  bool _isUploading = false;
  bool _isEditing = false;
  String? _loadedCardId;

  @override
  void initState() {
    super.initState();
    _cardFuture = _cardService.getCard(widget.cardId);
  }

  @override
  void dispose() {
    _panelTypeController.dispose();
    _panelWidthController.dispose();
    _panelHeightController.dispose();
    _mainBreakerController.dispose();
    _drivePowerController.dispose();
    _drivePower2Controller.dispose();
    _condenserDriveController.dispose();
    _condenserDrive2Controller.dispose();
    _compressorController.dispose();
    _compressor2Controller.dispose();
    _jetfanController.dispose();
    _plcModelController.dispose();
    _controlVoltageController.dispose();
    _notesController.dispose();
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
    _panelType = data['panel_type']?.toString() ?? _panelType;
    _panelTypeController.text = _panelType;
    _panelWidthController.text = data['panel_width']?.toString() ?? '';
    _panelHeightController.text = data['panel_height']?.toString() ?? '';
    _mainBreakerController.text = data['main_breaker']?.toString() ?? '';
    _drivePowerController.text = data['drive_power']?.toString() ?? '';
    _drivePower2Controller.text = data['drive_power_2']?.toString() ?? '';
    _condenserDriveController.text = data['condenser_drive']?.toString() ?? '';
    _condenserDrive2Controller.text =
        data['condenser_drive_2']?.toString() ?? '';
    _compressorController.text = data['compressor']?.toString() ?? '';
    _compressor2Controller.text = data['compressor_2']?.toString() ?? '';
    _jetfanController.text = data['jetfan']?.toString() ?? '';
    _plcModelController.text = data['plc_model']?.toString() ?? '';
    _controlVoltageController.text = data['control_voltage']?.toString() ?? '';
    _notesController.text =
        data['notes']?.toString() ?? _stripRecipeBlock(card.description);
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
    final data = {
      'panel_type': _panelType,
      'panel_width': _panelWidthController.text.trim(),
      'panel_height': _panelHeightController.text.trim(),
      'main_breaker': _mainBreakerController.text.trim(),
      'drive_power': _drivePowerController.text.trim(),
      'drive_power_2': _drivePower2Controller.text.trim(),
      'condenser_drive': _condenserDriveController.text.trim(),
      'condenser_drive_2': _condenserDrive2Controller.text.trim(),
      'compressor': _compressorController.text.trim(),
      'compressor_2': _compressor2Controller.text.trim(),
      'jetfan': _jetfanController.text.trim(),
      'plc_model': _plcModelController.text.trim(),
      'control_voltage': _controlVoltageController.text.trim(),
      'notes': _notesController.text.trim(),
    };
    final encoded = const JsonEncoder.withIndent('  ').convert(data);
    final humanSummary = [
      '[ATOLYE] Uretim recetesi',
      if (_panelType.trim().isNotEmpty) 'Panel tipi: $_panelType',
      if (_panelWidthController.text.trim().isNotEmpty ||
          _panelHeightController.text.trim().isNotEmpty)
        'Pano olcu: ${_panelWidthController.text.trim()}x${_panelHeightController.text.trim()}',
      if (_mainBreakerController.text.trim().isNotEmpty)
        'Ana salter: ${_mainBreakerController.text.trim()}',
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
      setState(() => _isEditing = false);
      await _refresh();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _printRecipePdf(KanbanCard card) async {
    await Printing.layoutPdf(
      name: 'Uretim_Recetesi_${card.linkedJobCode ?? card.id}.pdf',
      onLayout: (_) => _buildRecipePdf(card),
    );
  }

  Future<Uint8List> _buildRecipePdf(KanbanCard card) async {
    final doc = pw.Document();
    final rows = _recipeRows(card);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'URETIM RECETESI',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 14),
                pw.TableHelper.fromTextArray(
                  headers: const ['Alan', 'Deger'],
                  data: rows.map((row) => [row.$1, row.$2]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                if (_notesController.text.trim().isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'Notlar',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(_notesController.text.trim()),
                ],
              ],
            ),
      ),
    );
    return doc.save();
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
      appBar: AppBar(
        title: const Text('Uretim Recetesi'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _isEditing = !_isEditing),
            icon: Icon(
              _isEditing ? Icons.visibility_outlined : Icons.edit_outlined,
            ),
            label: Text(_isEditing ? 'Onizle' : 'Duzenle'),
          ),
          const SizedBox(width: 8),
        ],
      ),
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
                if (_isEditing) ...[
                  _statusPanel(card),
                  const SizedBox(height: 14),
                  _technicalForm(card),
                  const SizedBox(height: 14),
                  _filePanel(card),
                ] else ...[
                  _recipeSheet(card),
                  const SizedBox(height: 14),
                  _readonlyFilePanel(card),
                ],
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
          DropdownButtonFormField<String>(
            initialValue: _panelType,
            decoration: const InputDecoration(labelText: 'Panel Tipi'),
            items:
                const [
                      'Icten Tava',
                      'Dikili Tip',
                      'Plastik Pano',
                      'Duvar Tipi',
                      'Saha Panosu',
                      'MCC Pano',
                    ]
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
            onChanged:
                (value) => setState(() {
                  _panelType = value ?? _panelType;
                  _panelTypeController.text = _panelType;
                }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _numberField(_panelWidthController, 'Pano En', ''),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('x', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: _numberField(_panelHeightController, 'Pano Boy', ''),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _field(_mainBreakerController, 'Ana Salter Degeri', 'Orn: 125A'),
          const SizedBox(height: 12),
          _numberField(_drivePowerController, 'Surucu', 'kW'),
          const SizedBox(height: 12),
          _numberField(_drivePower2Controller, 'Surucu', 'kW'),
          const SizedBox(height: 12),
          _numberField(_condenserDriveController, 'Kondanser Surucu', 'kW'),
          const SizedBox(height: 12),
          _numberField(_condenserDrive2Controller, 'Kondanser Surucu', 'kW'),
          const SizedBox(height: 12),
          _numberField(_compressorController, 'Kompresor', 'Amper'),
          const SizedBox(height: 12),
          _numberField(_compressor2Controller, 'Kompresor', 'Amper'),
          const SizedBox(height: 12),
          _numberField(_jetfanController, 'Jetfan', 'Zon'),
          const SizedBox(height: 12),
          _field(_plcModelController, 'PLC Modeli', 'Marka / Model'),
          const SizedBox(height: 12),
          _field(_controlVoltageController, 'Kontrol Voltaji', 'Orn: 24V DC'),
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

  Widget _recipeSheet(KanbanCard card) {
    final theme = Theme.of(context);
    final rows = _recipeRows(card);

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
          Row(
            children: [
              Expanded(
                child: Text(
                  'IMALAT RECETESI',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Duzenle'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _printRecipePdf(card),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('PDF'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _sheetBox(
            title: 'Recete Tablosu',
            tone: const Color(0xFFE0F2FE),
            rows: rows,
          ),
          const SizedBox(height: 14),
          _documentTiles(),
          const SizedBox(height: 14),
          _notesSheet(),
        ],
      ),
    );
  }

  List<(String, String)> _recipeRows(KanbanCard card) {
    final due =
        card.dueDate == null
            ? ''
            : DateFormat('dd.MM.yyyy', 'tr_TR').format(card.dueDate!);
    final size =
        _panelWidthController.text.trim().isEmpty &&
                _panelHeightController.text.trim().isEmpty
            ? ''
            : '${_panelWidthController.text.trim()}x${_panelHeightController.text.trim()}';
    final rows = <(String, String)>[
      ('Is Emri', card.linkedJobCode ?? ''),
      ('Termin', due),
      ('Durum', card.status.label),
      ('Sorumlu', card.assigneeName ?? 'Atanmamis'),
      ('Panel Tipi', _panelType),
      ('Pano Olcu', size),
      ('Ana Salter', _mainBreakerController.text),
      ('Surucu', _withSuffix(_drivePowerController.text, 'kW')),
      ('Surucu', _withSuffix(_drivePower2Controller.text, 'kW')),
      ('Kondanser Surucu', _withSuffix(_condenserDriveController.text, 'kW')),
      ('Kondanser Surucu', _withSuffix(_condenserDrive2Controller.text, 'kW')),
      ('Kompresor', _withSuffix(_compressorController.text, 'Amper')),
      ('Kompresor', _withSuffix(_compressor2Controller.text, 'Amper')),
      ('Jetfan', _withSuffix(_jetfanController.text, 'Zon')),
      ('PLC Modeli', _plcModelController.text),
      ('Kontrol Voltaji', _controlVoltageController.text),
    ];
    return rows.where((row) => row.$2.trim().isNotEmpty).toList();
  }

  String _withSuffix(String value, String suffix) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return '$trimmed $suffix';
  }

  Widget _sheetBox({
    required String title,
    required Color tone,
    required List<(String, String)> rows,
  }) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: tone,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          ...rows.map(
            (row) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 118,
                    child: Text(
                      row.$1,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(child: Text(row.$2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentTiles() {
    const items = [
      'Nokta Listesi',
      'Tek Hat Sema',
      'Malzeme Listesi',
      'Pano Yerlesim',
      'Fotograflar',
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          items
              .map(
                (item) => Container(
                  width: 190,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCCFBF1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF99F6E4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text('Dosya: Is emrinde'),
                      const Text('Durum: Takipte'),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _notesSheet() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        _notesController.text.trim().isEmpty
            ? 'Uretim notu girilmedi.'
            : _notesController.text.trim(),
      ),
    );
  }

  Widget _readonlyFilePanel(KanbanCard card) {
    return _panel(
      title: 'Proje Dosyalari',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed:
                card.linkedTicketId == null ? null : () => _openTicket(card),
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('Is Emrindeki Dosyalar'),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _isEditing = true),
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Dosya Eklemek Icin Duzenle'),
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

  Widget _numberField(
    TextEditingController controller,
    String label,
    String suffix,
  ) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix.isEmpty ? null : suffix,
      ),
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
