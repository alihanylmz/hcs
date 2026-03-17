import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/structured_ticket_note.dart';
import '../services/ticket_service.dart';
import '../theme/app_colors.dart';

enum AddNoteEntryMode { quick, structured, photo }

class AddNoteDialog extends StatefulWidget {
  const AddNoteDialog({
    super.key,
    required this.ticketId,
    this.isPartnerNote = false,
    this.onSuccess,
    this.initialMode = AddNoteEntryMode.quick,
  });

  final String ticketId;
  final bool isPartnerNote;
  final VoidCallback? onSuccess;
  final AddNoteEntryMode initialMode;

  @override
  State<AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<AddNoteDialog> {
  final TicketService _ticketService = TicketService();
  final TextEditingController _quickNoteController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _workPerformedController =
      TextEditingController();
  final TextEditingController _usedPartsController = TextEditingController();
  final TextEditingController _resultController = TextEditingController();
  final TextEditingController _additionalNoteController =
      TextEditingController();

  late AddNoteEntryMode _mode;
  bool _isSubmitting = false;
  bool _isPickingImages = false;
  final List<PlatformFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    if (_mode == AddNoteEntryMode.photo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pickImages();
        }
      });
    }
  }

  @override
  void dispose() {
    _quickNoteController.dispose();
    _diagnosisController.dispose();
    _workPerformedController.dispose();
    _usedPartsController.dispose();
    _resultController.dispose();
    _additionalNoteController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    setState(() => _isPickingImages = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );

      if (!mounted || result == null || result.files.isEmpty) return;

      setState(() {
        _selectedImages
          ..clear()
          ..addAll(result.files.where((file) => file.bytes != null));
      });
    } finally {
      if (mounted) {
        setState(() => _isPickingImages = false);
      }
    }
  }

  void _removeImageAt(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _submit() async {
    final noteBody = _buildNoteBody();
    final hasImages = _selectedImages.isNotEmpty;

    if (noteBody.isEmpty && !hasImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not veya fotoğraf eklemelisiniz.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      List<String>? imageUrls;
      if (hasImages) {
        imageUrls = await _ticketService.uploadImages(
          widget.ticketId,
          _selectedImages,
        );
      }

      final finalNote =
          noteBody.isEmpty && hasImages ? 'Gorsel kaydi eklendi.' : noteBody;

      if (widget.isPartnerNote) {
        await _ticketService.addPartnerNote(
          widget.ticketId,
          finalNote,
          imageUrls,
        );
      } else {
        await _ticketService.addNote(widget.ticketId, finalNote, imageUrls);
      }

      if (!mounted) return;

      Navigator.pop(context);
      widget.onSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isPartnerNote
                ? 'Partner kaydi eklendi.'
                : 'Servis kaydi eklendi.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kayit eklenemedi: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _buildNoteBody() {
    switch (_mode) {
      case AddNoteEntryMode.quick:
      case AddNoteEntryMode.photo:
        return _quickNoteController.text.trim();
      case AddNoteEntryMode.structured:
        return StructuredTicketNote(
          diagnosis: _diagnosisController.text.trim(),
          workPerformed: _workPerformedController.text.trim(),
          usedParts: _usedPartsController.text.trim(),
          result: _resultController.text.trim(),
          additionalNote: _additionalNoteController.text.trim(),
        ).toStorageText();
    }
  }

  String _dialogTitle() {
    if (widget.isPartnerNote) {
      return 'Partner surec kaydi';
    }
    switch (_mode) {
      case AddNoteEntryMode.quick:
        return 'Hizli servis kaydi';
      case AddNoteEntryMode.structured:
        return 'Detayli servis kaydi';
      case AddNoteEntryMode.photo:
        return 'Fotografli kayit';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhotoMode = _mode == AddNoteEntryMode.photo;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Text(_dialogTitle()),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildModeSelector(),
              const SizedBox(height: 16),
              if (_mode == AddNoteEntryMode.structured)
                _buildStructuredForm()
              else
                _buildQuickForm(isPhotoMode: isPhotoMode),
              const SizedBox(height: 16),
              _buildImageSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Iptal'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.corporateNavy,
          ),
          child:
              _isSubmitting
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Text('Kaydet', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildModeSelector() {
    final options = <(AddNoteEntryMode, String, String)>[
      (
        AddNoteEntryMode.quick,
        'Hizli',
        'Kisa bir guncelleme veya aciklama ekleyin.',
      ),
      (
        AddNoteEntryMode.structured,
        'Detayli',
        'Ariza, yapilan islem ve sonucu duzenli kaydedin.',
      ),
      (
        AddNoteEntryMode.photo,
        'Fotograf',
        'Sadece gorsel veya gorsel destekli kisa bir kayit ekleyin.',
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          options.map((option) {
            final isSelected = _mode == option.$1;
            return ChoiceChip(
              label: Text(option.$2),
              selected: isSelected,
              onSelected:
                  _isSubmitting
                      ? null
                      : (_) => setState(() => _mode = option.$1),
              selectedColor: AppColors.corporateYellow.withOpacity(0.18),
              labelStyle: TextStyle(
                color:
                    isSelected ? AppColors.corporateNavy : AppColors.textDark,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color:
                    isSelected
                        ? AppColors.corporateYellow
                        : Colors.grey.shade300,
              ),
            );
          }).toList(),
    );
  }

  Widget _buildQuickForm({required bool isPhotoMode}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isPhotoMode
              ? 'Isterseniz gorselle ilgili kisa bir aciklama ekleyin.'
              : 'Kisa ve net bir servis guncellemesi ekleyin.',
          style: const TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _quickNoteController,
          decoration: InputDecoration(
            labelText: isPhotoMode ? 'Aciklama (opsiyonel)' : 'Kayit ozeti',
            hintText:
                isPhotoMode
                    ? 'Ornek: Baglanti noktasi ve pano ici gorseller eklendi.'
                    : 'Ornek: Kart degisti, test yapildi, cihaz tekrar devreye alindi.',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: isPhotoMode ? 3 : 5,
          autofocus: !isPhotoMode,
        ),
      ],
    );
  }

  Widget _buildStructuredForm() {
    return Column(
      children: [
        _buildStructuredField(
          controller: _diagnosisController,
          label: 'Ariza tespiti',
          hint: 'Sorunun kaynagini veya ilk bulguyu yazin.',
        ),
        const SizedBox(height: 12),
        _buildStructuredField(
          controller: _workPerformedController,
          label: 'Yapilan islem',
          hint: 'Uygulanan servis adimlarini yazin.',
        ),
        const SizedBox(height: 12),
        _buildStructuredField(
          controller: _usedPartsController,
          label: 'Kullanilan parca',
          hint: 'Degisen veya kullanilan malzemeleri belirtin.',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        _buildStructuredField(
          controller: _resultController,
          label: 'Sonuc',
          hint: 'Islem sonrasi mevcut durumu yazin.',
        ),
        const SizedBox(height: 12),
        _buildStructuredField(
          controller: _additionalNoteController,
          label: 'Ek not',
          hint: 'Gerekiyorsa ek bilgi, risk veya takip notu yazin.',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildStructuredField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 3,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      maxLines: maxLines,
    );
  }

  Widget _buildImageSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.photo_camera_back_outlined,
                color: AppColors.corporateNavy,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Fotograflar',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed:
                    (_isPickingImages || _isSubmitting) ? null : _pickImages,
                icon:
                    _isPickingImages
                        ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 18,
                        ),
                label: Text(_selectedImages.isEmpty ? 'Sec' : 'Degistir'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _selectedImages.isEmpty
                ? 'Isterseniz sureci destekleyen gorseller ekleyin.'
                : '${_selectedImages.length} dosya secildi.',
            style: const TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_selectedImages.length, (index) {
                final file = _selectedImages[index];
                return Container(
                  constraints: const BoxConstraints(maxWidth: 220),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.image_outlined,
                        size: 16,
                        color: AppColors.corporateNavy,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap:
                            _isSubmitting ? null : () => _removeImageAt(index),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
