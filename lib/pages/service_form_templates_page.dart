// lib/pages/service_form_templates_page.dart
// Yöneticilerin form şablonlarını (Jetfan, Nem Alma, AHU vb.) yönettiği ekran

import 'package:flutter/material.dart';
import '../models/service_form.dart';
import '../services/service_form_service.dart';
import '../theme/app_colors.dart';

class ServiceFormTemplatesPage extends StatefulWidget {
  const ServiceFormTemplatesPage({super.key});

  @override
  State<ServiceFormTemplatesPage> createState() =>
      _ServiceFormTemplatesPageState();
}

class _ServiceFormTemplatesPageState extends State<ServiceFormTemplatesPage> {
  final _service = ServiceFormService();
  List<ServiceFormTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);
    try {
      final list = await _service.getAllTemplates();
      if (mounted) setState(() => _templates = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openEditor({ServiceFormTemplate? template}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _TemplateEditorDialog(
        service: _service,
        existing: template,
      ),
    );
    if (result == true) _loadTemplates();
  }

  Future<void> _deleteTemplate(ServiceFormTemplate template) async {
    // 1. Uyarı
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Şablonu Sil'),
        content: Text(
          '"${template.name}" şablonunu silmek istediğinizden emin misiniz?\n\nBu şablona bağlı daha önce oluşturulan formlar etkilenmeyecektir.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );
    if (confirm1 != true) return;

    // 2. Uyarı
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Son Onay'),
          ],
        ),
        content: Text(
          'Bu işlem geri alınamaz! "${template.name}" şablonu kalıcı olarak silinecek.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Kalıcı Olarak Sil',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm2 != true) return;

    try {
      await _service.deleteTemplate(template.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Şablon silindi.'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadTemplates();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Form Şablonları'),
        backgroundColor: AppColors.corporateNavy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Yeni Şablon',
            onPressed: () => _openEditor(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? _buildEmpty()
              : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: AppColors.corporateBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Şablon'),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Henüz form şablonu yok.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            label: const Text('İlk Şablonu Oluştur'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _templates.length,
      itemBuilder: (ctx, i) {
        final t = _templates[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: t.isActive
                  ? AppColors.corporateBlue.withOpacity(0.1)
                  : Colors.grey.shade100,
              child: Icon(
                Icons.description_outlined,
                color: t.isActive ? AppColors.corporateBlue : Colors.grey,
              ),
            ),
            title: Text(
              t.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t.description != null)
                  Text(t.description!,
                      style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  '${t.checkboxes.length} onay maddesi',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
                if (!t.isActive)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Text('Pasif',
                        style: TextStyle(
                            fontSize: 11, color: Colors.orange)),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _openEditor(template: t);
                if (v == 'delete') _deleteTemplate(t);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Düzenle'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading:
                        Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Sil',
                        style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// Form Şablonu Oluşturma / Düzenleme Diyaloğu
// ============================================================
class _TemplateEditorDialog extends StatefulWidget {
  final ServiceFormService service;
  final ServiceFormTemplate? existing;

  const _TemplateEditorDialog({required this.service, this.existing});

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _contentCtrl;
  late List<_CheckboxEntry> _entries;
  late bool _isActive;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _contentCtrl = TextEditingController(text: e?.contentText ?? '');
    _isActive = e?.isActive ?? true;
    _entries = e?.checkboxes
            .map((c) => _CheckboxEntry(
                labelCtrl: TextEditingController(text: c.label),
                required: c.required))
            .toList() ??
        [_CheckboxEntry(labelCtrl: TextEditingController(), required: true)];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _contentCtrl.dispose();
    for (final e in _entries) {
      e.labelCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final checkboxes = _entries
        .where((e) => e.labelCtrl.text.trim().isNotEmpty)
        .map((e) =>
            ServiceFormCheckbox(label: e.labelCtrl.text.trim(), required: e.required))
        .toList();

    try {
      if (widget.existing == null) {
        await widget.service.createTemplate(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          contentText: _contentCtrl.text.trim(),
          checkboxes: checkboxes,
        );
      } else {
        await widget.service.updateTemplate(
          templateId: widget.existing!.id,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty
              ? null
              : _descCtrl.text.trim(),
          contentText: _contentCtrl.text.trim(),
          checkboxes: checkboxes,
          isActive: _isActive,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 750),
        child: Column(
          children: [
            // Başlık
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: AppColors.corporateNavy,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined,
                      color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? 'Şablonu Düzenle' : 'Yeni Form Şablonu',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // İçerik
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _field('Şablon Adı', _nameCtrl,
                        hint: 'Jetfan Servis Formu'),
                    const SizedBox(height: 14),
                    _field('Açıklama (opsiyonel)', _descCtrl,
                        required: false,
                        hint: 'Kısa bir açıklama giriniz'),
                    const SizedBox(height: 14),
                    _field('Bilgilendirme Metni', _contentCtrl,
                        maxLines: 5,
                        hint:
                            'Müşteriye gösterilecek bilgilendirme metnini buraya yazınız...'),
                    const SizedBox(height: 20),
                    // Onay Maddeleri
                    Row(
                      children: [
                        const Text('Onay Maddeleri',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _entries.add(_CheckboxEntry(
                                  labelCtrl: TextEditingController(),
                                  required: true));
                            });
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Madde Ekle'),
                          style: TextButton.styleFrom(
                              foregroundColor: AppColors.corporateBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._entries.asMap().entries.map((entry) {
                      final i = entry.key;
                      final e = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text('${i + 1}.',
                                      style: TextStyle(
                                          color: Colors.grey.shade500)),
                                  const Spacer(),
                                  Row(
                                    children: [
                                      const Text('Zorunlu',
                                          style:
                                              TextStyle(fontSize: 12)),
                                      Switch(
                                        value: e.required,
                                        onChanged: (v) => setState(
                                            () => e.required = v),
                                        activeColor:
                                            AppColors.corporateBlue,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize
                                                .shrinkWrap,
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20),
                                    onPressed: _entries.length > 1
                                        ? () {
                                            e.labelCtrl.dispose();
                                            setState(
                                                () => _entries.removeAt(i));
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                              TextFormField(
                                controller: e.labelCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Onay maddesi metnini giriniz...',
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (isEdit) ...[
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Şablon Aktif'),
                        subtitle: const Text(
                            'Pasif şablonlar form göndermede görünmez.'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        activeColor: AppColors.corporateBlue,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Alt Butonlar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('İptal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.corporateBlue,
                        foregroundColor: Colors.white,
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(isEdit ? 'Güncelle' : 'Oluştur'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool required = true, int maxLines = 1, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          validator: required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppColors.corporateBlue, width: 2)),
          ),
        ),
      ],
    );
  }
}

class _CheckboxEntry {
  TextEditingController labelCtrl;
  bool required;
  _CheckboxEntry({required this.labelCtrl, required this.required});
}
