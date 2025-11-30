import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui' as ui;

enum SignatureType { customer, technician }

class SignaturePage extends StatefulWidget {
  final String ticketId;
  final SignatureType type;
  final String? customerName;
  final String? customerPhone;
  final String? existingSignatureData; // Mevcut imza verisi (base64)
  final String? existingName; // Mevcut ad
  final String? existingSurname; // Mevcut soyad
  final String? existingPhone; // Mevcut telefon

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
    exportBackgroundColor: Colors.white,
  );

  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == SignatureType.customer) {
      // Mevcut imza bilgileri varsa onları kullan, yoksa müşteri bilgilerini kullan
      _nameController.text = widget.existingName ?? widget.customerName?.split(' ').first ?? '';
      _surnameController.text = widget.existingSurname ?? '';
      _phoneController.text = widget.existingPhone ?? widget.customerPhone ?? '';
    } else {
      // Teknisyen için kullanıcı bilgilerini yükle
      _loadTechnicianInfo();
      // Mevcut imza bilgileri varsa onları kullan
      if (widget.existingName != null) {
        _nameController.text = widget.existingName!;
      }
      if (widget.existingSurname != null) {
        _surnameController.text = widget.existingSurname!;
      }
    }
    // Mevcut imzayı yükle (varsa)
    _loadExistingSignature();
  }

  Future<void> _loadExistingSignature() async {
    // SignatureController'da fromPngBytes metodu yok
    // Mevcut imzayı göstermek için farklı bir yaklaşım kullanacağız
    // Kullanıcı yeni imza çizerse onu kaydedeceğiz
  }

  Future<void> _loadTechnicianInfo() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        // Kullanıcı profil bilgilerini çek (full_name ve phone)
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
              _nameController.text = nameParts.first;
              if (nameParts.length > 1) {
                _surnameController.text = nameParts.sublist(1).join(' ');
              }
            }
          }
        }
      } catch (e) {
        // Profil bulunamazsa email'den çıkarmaya çalış
        if (mounted) {
          final email = user.email ?? '';
          final nameParts = email.split('@').first.split('.');
          if (nameParts.isNotEmpty) {
            _nameController.text = nameParts.first;
            if (nameParts.length > 1) {
              _surnameController.text = nameParts.sublist(1).join(' ');
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveSignature() async {
    // Mevcut imza varsa düzenleme modunda, yoksa yeni imza atılmalı
    final isEditing = widget.existingSignatureData != null && widget.existingSignatureData!.isNotEmpty;
    
    if (!isEditing && _controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen imza atın'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Müşteri imzası için ad soyad zorunlu
    if (widget.type == SignatureType.customer) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen ad girin'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_surnameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen soyad girin'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // İmzayı PNG olarak export et
      String signatureBase64;
      
      if (_controller.isEmpty && isEditing) {
        // Düzenleme modunda ve imza silinmişse, mevcut imzayı koru
        signatureBase64 = widget.existingSignatureData!;
      } else {
        // Yeni imza çizilmişse veya yeni imza atılıyorsa
        final Uint8List? signatureBytes = await _controller.toPngBytes();
        
        if (signatureBytes == null) {
          throw Exception('İmza oluşturulamadı');
        }
        
        // Base64'e çevir
        signatureBase64 = base64Encode(signatureBytes);
      }

      // Supabase'e kaydet
      final supabase = Supabase.instance.client;
      final idValue = int.tryParse(widget.ticketId) ?? widget.ticketId;
      final user = supabase.auth.currentUser;

      Map<String, dynamic> updateData = {};

      if (widget.type == SignatureType.customer) {
        // Müşteri imzası
        updateData = {
          'signature_data': signatureBase64,
          'signature_name': _nameController.text.trim(),
          'signature_surname': _surnameController.text.trim(),
          'signature_phone': _phoneController.text.trim().isEmpty 
              ? null 
              : _phoneController.text.trim(),
          'signature_date': DateTime.now().toIso8601String(),
        };
      } else {
        // Teknisyen imzası - Supabase'den kullanıcı bilgilerini al
        String userName = _nameController.text.trim();
        String? userSurname = _surnameController.text.trim().isNotEmpty 
            ? _surnameController.text.trim() 
            : null;
        
        if (user != null) {
          try {
            // Kullanıcı profil bilgilerini çek
            final profile = await supabase
                .from('profiles')
                .select('full_name, phone')
                .eq('id', user.id)
                .maybeSingle();
            
            if (profile != null) {
              final fullName = profile['full_name'] as String? ?? '';
              if (fullName.isNotEmpty) {
                final nameParts = fullName.split(' ');
                if (nameParts.isNotEmpty) {
                  userName = nameParts.first;
                  if (nameParts.length > 1) {
                    userSurname = nameParts.sublist(1).join(' ');
                  }
                }
              }
            }
          } catch (e) {
            // Profil bulunamazsa mevcut değerleri kullan
            if (userName.isEmpty) {
              userName = user.email?.split('@').first.split('.').first ?? 'Teknisyen';
            }
          }
        }
        
        updateData = {
          'technician_signature_data': signatureBase64,
          'technician_signature_name': userName,
          'technician_signature_surname': userSurname?.isNotEmpty == true ? userSurname : null,
          'technician_signature_date': DateTime.now().toIso8601String(),
          'technician_id': user?.id,
        };
      }

      try {
        final response = await supabase
            .from('tickets')
            .update(updateData)
            .eq('id', idValue);
      } on PostgrestException catch (e) {
        // Supabase hatası - muhtemelen kolon eksik
        throw Exception('Veritabanı hatası: ${e.message}. Gerekli kolonlar: ${updateData.keys.join(", ")}');
      } catch (e) {
        rethrow;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.type == SignatureType.customer ? "Müşteri" : "Teknisyen"} imzası başarıyla kaydedildi!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İmza kaydetme hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingSignatureData != null && widget.existingSignatureData!.isNotEmpty
              ? (widget.type == SignatureType.customer ? 'Müşteri İmzası Düzenle' : 'Teknisyen İmzası Düzenle')
              : (widget.type == SignatureType.customer ? 'Müşteri İmzası' : 'Teknisyen İmzası'),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF050912), Color(0xFF0D1423)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.type == SignatureType.customer)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Müşteri Bilgileri',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Ad *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _surnameController,
                            decoration: const InputDecoration(
                              labelText: 'Soyad *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Telefon Numarası',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.type == SignatureType.technician)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Teknisyen Bilgileri',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FutureBuilder<Map<String, dynamic>?>(
                            future: () async {
                              final supabase = Supabase.instance.client;
                              final user = supabase.auth.currentUser;
                              if (user == null) return null;
                              
                              try {
                                final profile = await supabase
                                    .from('profiles')
                                    .select('full_name, phone')
                                    .eq('id', user.id)
                                    .maybeSingle();
                                return profile;
                              } catch (e) {
                                return null;
                              }
                            }(),
                            builder: (context, snapshot) {
                              final supabase = Supabase.instance.client;
                              final user = supabase.auth.currentUser;
                              final email = user?.email ?? 'Bilinmiyor';
                              
                              String userName = 'Teknisyen';
                              String? phone;
                              
                              if (snapshot.hasData && snapshot.data != null) {
                                final fullName = snapshot.data!['full_name'] as String? ?? '';
                                phone = snapshot.data!['phone'] as String?;
                                if (fullName.isNotEmpty) {
                                  userName = fullName;
                                } else {
                                  userName = user?.email?.split('@').first ?? 'Teknisyen';
                                }
                              } else {
                                userName = user?.email?.split('@').first ?? 'Teknisyen';
                              }
                              
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Teknisyen: $userName',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Email: $email',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (phone != null && phone.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Telefon: $phone',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  const Text(
                                    'İmza atarak işi onaylıyorsunuz.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'İmza',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Aşağıdaki alana parmağınızla veya kalemle imza atın',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            children: [
                              // Mevcut imzayı göster (varsa)
                              if (widget.existingSignatureData != null && widget.existingSignatureData!.isNotEmpty)
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      base64Decode(widget.existingSignatureData!),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              // Yeni imza çizme alanı
                              Signature(
                                controller: _controller,
                                backgroundColor: Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _controller.clear,
                              icon: const Icon(Icons.clear),
                              label: const Text('Temizle'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveSignature,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check),
                              label: Text(_isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

