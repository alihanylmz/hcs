import 'package:flutter/material.dart';
import '../models/daily_activity.dart';
import '../theme/app_colors.dart';

class AddTaskDialog extends StatefulWidget {
  final DateTime selectedDate;
  final DailyActivity? existingActivity; // Düzenleme için opsiyonel

  const AddTaskDialog({
    super.key, 
    required this.selectedDate,
    this.existingActivity,
  });

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  late TextEditingController _titleController;
  // Hem controller hem de orijinal step verisini tutmak için bir yapı
  final List<_StepItem> _stepItems = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingActivity?.title ?? '');
    
    if (widget.existingActivity != null) {
      // Mevcut adımları yükle
      for (var step in widget.existingActivity!.steps) {
        _stepItems.add(_StepItem(
          controller: TextEditingController(text: step.title),
          isCompleted: step.isCompleted,
        ));
      }
    }
  }

  // Yeni alt adım ekleme
  void _addStepField() {
    setState(() {
      _stepItems.add(_StepItem(
        controller: TextEditingController(),
        isCompleted: false, // Yeni adım tamamlanmamış başlar
      ));
    });
  }

  // Alt adım silme
  void _removeStepField(int index) {
    setState(() {
      _stepItems[index].controller.dispose();
      _stepItems.removeAt(index);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var item in _stepItems) item.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingActivity != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Üst Başlık ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: isEditing ? Colors.orange.shade50 : Colors.blue.shade50, shape: BoxShape.circle),
                  child: Icon(
                    isEditing ? Icons.edit : Icons.assignment_add, 
                    color: isEditing ? Colors.orange : AppColors.primary
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isEditing ? "İş Paketini Düzenle" : "Yeni İş Paketi Oluştur", 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
              ],
            ),
            const Divider(height: 30),

            // --- Ana İş Başlığı ---
            const Text("Ana İş Başlığı", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Örn: Sincan Modbus Haberleşme',
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // --- Alt Adımlar Başlığı ve Ekle Butonu ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Alt Adımlar (Detaylar)", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                TextButton.icon(
                  onPressed: _addStepField,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text("Adım Ekle"),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero, 
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                )
              ],
            ),

            // --- Dinamik Liste ---
            Expanded(
              child: _stepItems.isEmpty
                  ? Center(
                      child: Text(
                        "Henüz alt adım eklemedin.\nDetaylı rapor için adım ekle.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _stepItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return Row(
                          children: [
                            const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _stepItems[index].controller,
                                decoration: InputDecoration(
                                  hintText: '${index + 1}. Adım',
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary)),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                              onPressed: () => _removeStepField(index),
                            )
                          ],
                        );
                      },
                    ),
            ),

            const SizedBox(height: 20),

            // --- Kaydet Butonu ---
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEditing ? Colors.orange.shade700 : AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () {
                  final title = _titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen bir ana başlık girin")));
                    return;
                  }

                  // Dolu olan alt adımları topla
                  final steps = _stepItems
                      .where((item) => item.controller.text.trim().isNotEmpty)
                      .map((item) => ActivityStep(
                        title: item.controller.text.trim(),
                        isCompleted: item.isCompleted, // Mevcut durumu koru
                      ))
                      .toList();

                  // Veriyi geri döndür
                  Navigator.pop(context, {'title': title, 'steps': steps});
                },
                child: Text(
                  isEditing ? "Güncelle" : "Projeyi Kaydet", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Yardımcı sınıf
class _StepItem {
  final TextEditingController controller;
  final bool isCompleted;

  _StepItem({required this.controller, required this.isCompleted});
}
