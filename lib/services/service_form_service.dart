// lib/services/service_form_service.dart
// Servis Öncesi Onay Formu - Veri Katmanı

import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/service_form.dart';

class ServiceFormService {
  final _supabase = Supabase.instance.client;

  // ============================================================
  // ŞABLON İŞLEMLERİ
  // ============================================================

  /// Aktif form şablonlarını listele
  Future<List<ServiceFormTemplate>> getActiveTemplates() async {
    final data = await _supabase
        .from('service_form_templates')
        .select()
        .eq('is_active', true)
        .order('created_at');

    return (data as List)
        .cast<Map<String, dynamic>>()
        .map((e) => ServiceFormTemplate.fromJson(e))
        .toList();
  }

  /// Tüm şablonları listele (Yönetim ekranı için)
  Future<List<ServiceFormTemplate>> getAllTemplates() async {
    final data = await _supabase
        .from('service_form_templates')
        .select()
        .order('created_at');

    return (data as List)
        .cast<Map<String, dynamic>>()
        .map((e) => ServiceFormTemplate.fromJson(e))
        .toList();
  }

  /// Yeni şablon oluştur
  Future<ServiceFormTemplate> createTemplate({
    required String name,
    String? description,
    required String contentText,
    required List<ServiceFormCheckbox> checkboxes,
  }) async {
    final data = await _supabase
        .from('service_form_templates')
        .insert({
          'name': name,
          'description': description,
          'content_text': contentText,
          'checkboxes': checkboxes.map((e) => e.toJson()).toList(),
          'created_by': _supabase.auth.currentUser?.id,
        })
        .select()
        .single();

    return ServiceFormTemplate.fromJson(data);
  }

  /// Şablonu güncelle
  Future<void> updateTemplate({
    required String templateId,
    required String name,
    String? description,
    required String contentText,
    required List<ServiceFormCheckbox> checkboxes,
    required bool isActive,
  }) async {
    await _supabase
        .from('service_form_templates')
        .update({
          'name': name,
          'description': description,
          'content_text': contentText,
          'checkboxes': checkboxes.map((e) => e.toJson()).toList(),
          'is_active': isActive,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', templateId);
  }

  /// Şablonu sil (kalıcı)
  Future<void> deleteTemplate(String templateId) async {
    await _supabase
        .from('service_form_templates')
        .delete()
        .eq('id', templateId);
  }

  // ============================================================
  // TICKET FORMU İŞLEMLERİ
  // ============================================================

  /// Bir ticket'a bağlı formları listele (şablon bilgisiyle birlikte)
  Future<List<TicketServiceForm>> getFormsForTicket(String ticketId) async {
    final data = await _supabase
        .from('ticket_service_forms')
        .select('*, service_form_templates(*)')
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: false);

    return (data as List)
        .cast<Map<String, dynamic>>()
        .map((e) => TicketServiceForm.fromJson(e))
        .toList();
  }

  /// Yeni form oluştur (ticket + şablon seçimi)
  Future<TicketServiceForm> createForm({
    required String ticketId,
    required String templateId,
    String? customerName,
  }) async {
    final data = await _supabase
        .from('ticket_service_forms')
        .insert({
          'ticket_id': ticketId,
          'template_id': templateId,
          'customer_name': customerName,
          'status': 'pending',
          'created_by': _supabase.auth.currentUser?.id,
        })
        .select('*, service_form_templates(*)')
        .single();

    return TicketServiceForm.fromJson(data);
  }

  /// Formu iptal et (sadece admin/manager)
  Future<void> cancelForm(String formId, {String? reason}) async {
    await _supabase.from('ticket_service_forms').update({
      'status': 'cancelled',
      'cancelled_at': DateTime.now().toIso8601String(),
      'cancel_reason': reason,
    }).eq('id', formId);
  }

  // ============================================================
  // MÜŞTERİ TARAFLI İŞLEMLER (Anonim erişim)
  // ============================================================

  /// Form bilgilerini sadece ID ile çek (anonim erişim - müşteri linki)
  Future<TicketServiceForm?> getFormById(String formId) async {
    try {
      final data = await _supabase
          .from('ticket_service_forms')
          .select('*, service_form_templates(*)')
          .eq('id', formId)
          .maybeSingle();

      if (data == null) return null;
      return TicketServiceForm.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// Formu imzala (anonim - müşteri tarafı)
  /// İmzayı Supabase Storage'a yükler, formu günceller.
  Future<void> signForm({
    required String formId,
    required String customerName,
    required Uint8List signatureBytes,
    required List<int> checkedItems,
    String? customerIp,
  }) async {
    // 1. İmzayı storage'a yükle
    final fileName = 'form_${formId}_${DateTime.now().millisecondsSinceEpoch}.png';
    await _supabase.storage
        .from('service-signatures')
        .uploadBinary(fileName, signatureBytes,
            fileOptions: const FileOptions(contentType: 'image/png'));

    // 2. Base64 olarak da sakla (offline görüntüleme kolaylığı için)
    final signatureBase64 = base64Encode(signatureBytes);

    // 3. Formu güncelle
    await _supabase.from('ticket_service_forms').update({
      'status': 'signed',
      'customer_name': customerName,
      'signature_data': signatureBase64,
      'checked_items': checkedItems,
      'customer_ip': customerIp,
      'signed_at': DateTime.now().toIso8601String(),
    }).eq('id', formId);
  }
}
