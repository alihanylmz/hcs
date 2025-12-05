import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_colors.dart';
import '../services/ticket_service.dart';

class AddNoteDialog extends StatefulWidget {
  final String ticketId;
  final Function() onSuccess;
  final bool isPartnerNote;

  const AddNoteDialog({
    super.key, 
    required this.ticketId, 
    required this.onSuccess,
    this.isPartnerNote = false,
  });

  @override
  State<AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<AddNoteDialog> {
  final _noteController = TextEditingController();
  final List<PlatformFile> _selectedImages = [];
  bool _isUploading = false;
  final _ticketService = TicketService();

  Future<void> _handleSave() async {
    if (_noteController.text.trim().isEmpty && _selectedImages.isEmpty) {
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Resimleri Yükle
      List<String> uploadedUrls = [];
      if (_selectedImages.isNotEmpty) {
        uploadedUrls = await _ticketService.uploadImages(widget.ticketId, _selectedImages);
      }

      // Notu Kaydet
      if (widget.isPartnerNote) {
        await _ticketService.addPartnerNote(widget.ticketId, _noteController.text.trim(), uploadedUrls);
      } else {
        await _ticketService.addNote(widget.ticketId, _noteController.text.trim(), uploadedUrls);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isPartnerNote ? 'Partner notu eklendi' : 'Not eklendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result != null) {
        setState(() {
          _selectedImages.addAll(result.files);
        });
      }
    } catch (e) {
      debugPrint('Resim seçme hatası: $e');
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceWhite,
      title: Text(
        widget.isPartnerNote ? 'Partner Notu Ekle' : 'Servis Notu Ekle',
        style: const TextStyle(color: AppColors.corporateNavy),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  hintText: 'Yapılan işlem, gidilen servis vb.',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Resim Ekle'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.corporateNavy),
              ),
              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('Seçilen Resimler:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final file = _selectedImages[index];
                      return Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade100,
                            ),
                            child: file.bytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      file.bytes!,
                                      fit: BoxFit.cover,
                                      width: 80,
                                      height: 80,
                                      errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  )
                                : const Icon(Icons.image, color: Colors.grey),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () => setState(() => _selectedImages.removeAt(index)),
                              child: Container(
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: const Icon(Icons.cancel, color: Colors.red, size: 20),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _handleSave,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.corporateNavy),
          child: _isUploading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Ekle', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

