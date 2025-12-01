import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Ekran yönü için
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_header.dart'; // Header widget'ını eklemeyi unutma

enum SignatureType { customer, technician }

class SignaturePage extends StatefulWidget {
  final String ticketId;
  final SignatureType type;
  final String? customerName;
  final String? customerPhone;
  final String? existingSignatureData;
  final String? existingName;
  final String? existingSurname;
  final String? existingPhone;

  const SignaturePage({
    super.key,
    required this.ticketId,
    required this.type,
    this.customerName,
    this.customerPhone,
    this.existingSignatureData,
    this.existingName,
    this.existingSurname,
    this.existingPhone,
  });

  @override
  State<SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends State<SignaturePage> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.transparent, // PNG şeffaf olsun
  );

  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isSaving = false;
  bool _isRedrawing = false; // Mevcut imzayı silip yeniden çizme modu

  @override
  void initState() {
    super.initState();
    
    // --- KRİTİK: EKRANI DİKEY KİLİTLE ---
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // ------------------------------------

    _initializeData();
  }

  void _initializeData() {
    // Mevcut imza verisi varsa redraw modunu kapalı başlat (Resmi göster)
    if (widget.existingSignatureData != null && widget.existingSignatureData!.isNotEmpty) {
      _isRedrawing = false;
    } else {
      _isRedrawing = true;
    }

    if (widget.type == SignatureType.customer) {
      _nameController.text = widget.existingName ?? widget.customerName?.split(' ').first ?? '';
      _surnameController.text = widget.existingSurname ?? '';
      _phoneController.text = widget.existingPhone ?? widget.customerPhone ?? '';
    } else {
      _loadTechnicianInfo();
      if (widget.existingName != null) _nameController.text = widget.existingName!;
      if (widget.existingSurname != null) _surnameController.text = widget.existingSurname!;
    }
  }

  Future<void> _loadTechnicianInfo() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final profile = await supabase
            .from('profiles')
            .select('full_name, phone')
            .eq('id', user.id)
            .maybeSingle();
        
        if (profile != null && mounted) {
          final fullName = profile['full_name'] as String? ?? '';
          if (fullName.isNotEmpty) {
            final nameParts = fullName.split(' ');
            if (nameParts.isNotEmpty) {
              setState(() {
                _nameController.text = nameParts.first;
                if (nameParts.length > 1) {
                  _surnameController.text = nameParts.sublist(1).join(' ');
                }
              });
            }
          }
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    
    // --- ÇIKIŞTA EKRAN YÖNÜNÜ SERBEST BIRAK ---
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    // -------------------------------------------
    
    super.dispose();
  }

  Future<void> _saveSignature() async {
    // Eğer yeniden çizim modundaysak ve boşsa uyarı ver
    if (_isRedrawing && _controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen imza atın'), backgroundColor: Colors.red),
      );
      return;
    }

    if (widget.type == SignatureType.customer) {
      if (_nameController.text.trim().isEmpty || _surnameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen ad ve soyad girin'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      String signatureBase64;
      
      if (!_isRedrawing && widget.existingSignatureData != null) {
        // Mevcut imza korunuyor
        signatureBase64 = widget.existingSignatureData!;
      } else {
        // Yeni çizilen imza
        final Uint8List? signatureBytes = await _controller.toPngBytes();
        if (signatureBytes == null) throw Exception('İmza alınamadı');
        signatureBase64 = base64Encode(signatureBytes);
      }

      final supabase = Supabase.instance.client;
      final idValue = int.tryParse(widget.ticketId) ?? widget.ticketId;
      final user = supabase.auth.currentUser;

      Map<String, dynamic> updateData = {};

      if (widget.type == SignatureType.customer) {
        updateData = {
          'signature_data': signatureBase64,
          'signature_name': _nameController.text.trim(),
          'signature_surname': _surnameController.text.trim(),
          'signature_phone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
          'signature_date': DateTime.now().toIso8601String(),
        };
      } else {
        // Teknisyen
        updateData = {
          'technician_signature_data': signatureBase64,
          'technician_signature_name': _nameController.text.trim(),
          'technician_signature_surname': _surnameController.text.trim().isNotEmpty ? _surnameController.text.trim() : null,
          'technician_signature_date': DateTime.now().toIso8601String(),
          'technician_id': user?.id,
        };
      }

      await supabase.from('tickets').update(updateData).eq('id', idValue);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İmza başarıyla kaydedildi!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);

    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      // AppBar yerine CustomHeader kullanımı
      body: Column(
        children: [
          CustomHeader(
            title: widget.type == SignatureType.customer ? 'Müşteri İmzası' : 'Teknisyen İmzası',
            subtitle: 'Onay işlemi için imza gereklidir',
            showBackArrow: true,
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // --- KİŞİ BİLGİLERİ KARTI ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(widget.type == SignatureType.customer ? Icons.person : Icons.badge, color: AppColors.corporateNavy),
                            const SizedBox(width: 10),
                            Text(
                              widget.type == SignatureType.customer ? 'Müşteri Bilgileri' : 'Teknisyen Bilgileri',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 30),
                        _buildTextField(label: 'Ad', controller: _nameController),
                        const SizedBox(height: 16),
                        _buildTextField(label: 'Soyad', controller: _surnameController),
                        if (widget.type == SignatureType.customer) ...[
                          const SizedBox(height: 16),
                          _buildTextField(label: 'Telefon', controller: _phoneController, keyboardType: TextInputType.phone),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- İMZA ALANI KARTI ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.draw, color: AppColors.corporateNavy),
                            SizedBox(width: 10),
                            Text('İmza Paneli', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Lütfen aşağıdaki kutuya imza atınız.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        
                        // İMZA KUTUSU
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.corporateNavy.withOpacity(0.3), width: 2),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: !_isRedrawing && widget.existingSignatureData != null
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Image.memory(
                                        base64Decode(widget.existingSignatureData!),
                                        fit: BoxFit.contain,
                                      ),
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.green,
                                          radius: 12,
                                          child: const Icon(Icons.check, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ],
                                  )
                                : GestureDetector(
                                    // Dokunulunca klavyeyi kapat
                                    onPanDown: (_) => FocusScope.of(context).unfocus(),
                                    child: Signature(
                                      controller: _controller,
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // BUTONLAR
                        Row(
                          children: [
                            // Temizle / Yeniden Çiz Butonu
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  if (!_isRedrawing && widget.existingSignatureData != null) {
                                    // Mevcut imzayı silip yeniden çizme moduna geç
                                    setState(() => _isRedrawing = true);
                                  } else {
                                    // Sadece tahtayı temizle
                                    _controller.clear();
                                  }
                                },
                                icon: Icon(_isRedrawing ? Icons.delete_outline : Icons.refresh),
                                label: Text(_isRedrawing ? 'Temizle' : 'Yeniden İmzala'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  side: BorderSide(color: Colors.grey.shade400),
                                  foregroundColor: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Kaydet Butonu
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveSignature,
                                icon: _isSaving 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.save),
                                label: Text(_isSaving ? 'Kaydediliyor' : 'Kaydet'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.corporateNavy,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.corporateNavy)),
          ),
        ),
      ],
    );
  }
}
