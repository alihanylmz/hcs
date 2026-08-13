// lib/pages/public_service_form_page.dart
// Müşteriye gönderilen link üzerinden açılan, imza sayfası.
// Anonim (giriş yapmamış) kullanıcılar erişebilir.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import '../models/service_form.dart';
import '../services/service_form_service.dart';
import '../theme/app_colors.dart';

class PublicServiceFormPage extends StatefulWidget {
  final String formId;

  const PublicServiceFormPage({super.key, required this.formId});

  @override
  State<PublicServiceFormPage> createState() => _PublicServiceFormPageState();
}

class _PublicServiceFormPageState extends State<PublicServiceFormPage> {
  final _service = ServiceFormService();
  final _nameController = TextEditingController();
  final _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  TicketServiceForm? _form;
  bool _loading = true;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  // Checkbox durumları: true = işaretli
  List<bool> _checkboxStates = [];

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _loadForm() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final form = await _service.getFormById(widget.formId);
      if (form == null) {
        setState(() {
          _error = 'Form bulunamadı veya geçersiz link.';
          _loading = false;
        });
        return;
      }

      if (form.isSigned) {
        setState(() {
          _form = form;
          _submitted = true;
          _loading = false;
        });
        return;
      }

      if (form.isCancelled) {
        setState(() {
          _error = 'Bu form iptal edilmiştir.';
          _loading = false;
        });
        return;
      }

      setState(() {
        _form = form;
        _checkboxStates = List.filled(
          form.template?.checkboxes.length ?? 0,
          false,
        );
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Bir hata oluştu: $e';
        _loading = false;
      });
    }
  }

  bool get _allRequiredChecked {
    final template = _form?.template;
    if (template == null) return false;
    for (int i = 0; i < template.checkboxes.length; i++) {
      if (template.checkboxes[i].required && !_checkboxStates[i]) {
        return false;
      }
    }
    return true;
  }

  bool get _canSubmit {
    if (_nameController.text.trim().isEmpty) return false;
    if (_signatureController.isEmpty) return false;
    if (!_allRequiredChecked) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);

    try {
      final Uint8List? signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes == null) throw Exception('İmza alınamadı.');

      final checkedIndices = <int>[];
      for (int i = 0; i < _checkboxStates.length; i++) {
        if (_checkboxStates[i]) checkedIndices.add(i);
      }

      await _service.signForm(
        formId: widget.formId,
        customerName: _nameController.text.trim(),
        signatureBytes: signatureBytes,
        checkedItems: checkedIndices,
      );

      if (mounted) {
        setState(() {
          _submitting = false;
          _submitted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.corporateBlue),
            SizedBox(height: 16),
            Text('Form yükleniyor...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    if (_submitted) {
      return _buildSuccessView();
    }

    return _buildFormView();
  }

  Widget _buildSuccessView() {
    final signedAt = _form?.signedAt;
    final formatted =
        signedAt != null
            ? DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(signedAt)
            : null;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Form Başarıyla İmzalandı!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Servis talebiniz alınmıştır. Ekibimiz en kısa sürede sizinle iletişime geçecektir.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
            if (formatted != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Colors.green,
                      size: 16,
                    ),
                    Text(
                      'İmzalanma: $formatted',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_form?.customerName != null) ...[
              const SizedBox(height: 12),
              Text(
                'İmzalayan: ${_form!.customerName}',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormView() {
    final template = _form?.template;
    if (template == null) return const SizedBox();

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(template),
                const SizedBox(height: 14),
                _buildSummaryStrip(template),
                const SizedBox(height: 14),
                _buildInfoTextCard(template),
                const SizedBox(height: 14),
                _buildCheckboxesCard(template),
                const SizedBox(height: 14),
                _buildNameCard(),
                const SizedBox(height: 14),
                _buildSignatureCard(),
                const SizedBox(height: 22),
                _buildSubmitButton(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ServiceFormTemplate template) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2742),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.engineering_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SERVİS ONAY FORMU',
                  style: TextStyle(
                    color: Color(0xFFB7C7D8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  template.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                if ((template.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    template.description!.trim(),
                    style: const TextStyle(
                      color: Color(0xFFE5EDF5),
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStrip(ServiceFormTemplate template) {
    final requiredCount = template.checkboxes.where((e) => e.required).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E0EA)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _summaryItem(Icons.verified_user_outlined, 'Online onay'),
          _summaryItem(
            Icons.fact_check_outlined,
            '$requiredCount zorunlu madde',
          ),
          _summaryItem(Icons.draw_outlined, 'Dijital imza'),
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.corporateBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1F344A),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTextCard(ServiceFormTemplate template) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E0EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined, color: AppColors.corporateBlue),
              SizedBox(width: 8),
              Text(
                'Form İçeriği',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            template.contentText,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxesCard(ServiceFormTemplate template) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E0EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist, color: AppColors.corporateBlue),
              SizedBox(width: 8),
              Text(
                'Onay Maddeleri',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Devam etmek için zorunlu maddeleri onaylayın.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 14),
          ...List.generate(template.checkboxes.length, (i) {
            final item = template.checkboxes[i];
            return InkWell(
              onTap: () {
                setState(() => _checkboxStates[i] = !_checkboxStates[i]);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
                decoration: BoxDecoration(
                  color:
                      _checkboxStates[i]
                          ? const Color(0xFFEFF8F4)
                          : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        _checkboxStates[i]
                            ? const Color(0xFF96D4B3)
                            : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Checkbox(
                        value: _checkboxStates[i],
                        onChanged: (v) {
                          setState(() => _checkboxStates[i] = v ?? false);
                        },
                        activeColor: AppColors.corporateBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                              height: 1.45,
                            ),
                            children: [
                              TextSpan(text: item.label),
                              if (item.required)
                                const TextSpan(
                                  text: ' *',
                                  style: TextStyle(
                                    color: Color(0xFFB42318),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNameCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E0EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline, color: AppColors.corporateBlue),
              SizedBox(width: 8),
              Text(
                'Yetkili Bilgisi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Ad Soyad',
              hintText: 'İmzalayan yetkilinin adı ve soyadı',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: AppColors.corporateBlue,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8E0EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.draw_outlined, color: AppColors.corporateBlue),
              SizedBox(width: 8),
              Text(
                'Dijital İmza',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Parmağınızla veya fareyle imzanızı atın.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    _signatureController.isEmpty
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF3FB980),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: GestureDetector(
                onPanDown: (_) => FocusScope.of(context).unfocus(),
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                _signatureController.clear();
                setState(() {});
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('İmzayı Temizle'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final canSubmit = _canSubmit && !_submitting;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton(
        onPressed: canSubmit ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canSubmit ? Colors.green : Colors.grey.shade300,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: canSubmit ? 4 : 0,
        ),
        child:
            _submitting
                ? const Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    Text('Gönderiliyor...', style: TextStyle(fontSize: 16)),
                  ],
                )
                : const Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Icon(Icons.check_circle_outline, size: 22),
                    Text(
                      'Kabul Ediyorum ve Servis Çağırıyorum',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
