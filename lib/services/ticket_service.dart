import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb için
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:file_picker/file_picker.dart';
import 'notification_service.dart';
import 'user_service.dart';

class TicketService {
  final _supabase = Supabase.instance.client;
  final _notificationService = NotificationService();
  final _userService = UserService();

  // --- TICKET İŞLEMLERİ ---

  Future<Map<String, dynamic>?> getTicket(String ticketId) async {
    // String ID'yi int'e çevirmeyi dene, olmazsa string kullan
    dynamic queryId = int.tryParse(ticketId) ?? ticketId;

    return await _supabase
        .from('tickets')
        .select('''
          *,
          customers (
            id,
            name,
            address,
            phone
          )
        ''')
        .eq('id', queryId)
        .maybeSingle();
  }

  Future<void> updateTicket(String ticketId, Map<String, dynamic> payload) async {
    dynamic queryId = int.tryParse(ticketId) ?? ticketId;
    
    // Eski ticket bilgilerini al (bildirim için)
    final oldTicket = await getTicket(ticketId);
    
    // Güncelleme yap
    await _supabase.from('tickets').update(payload).eq('id', queryId);
    
    // Bildirim gönder (asenkron, hata olsa bile işlem devam etsin)
    if (oldTicket != null) {
      _sendUpdateNotifications(oldTicket, payload, ticketId).catchError((e) {
        debugPrint('Bildirim gönderme hatası: $e');
      });
    }
  }
  
  /// Ticket güncellemelerinde bildirim gönderir
  Future<void> _sendUpdateNotifications(
    Map<String, dynamic> oldTicket,
    Map<String, dynamic> payload,
    String ticketId,
  ) async {
    final ticketTitle = oldTicket['title'] as String? ?? 'İş Emri';
    final jobCode = oldTicket['job_code'] as String?;
    final currentUser = await _userService.getCurrentUserProfile();
    final userName = currentUser?.fullName ?? 'Kullanıcı';
    
    // Durum değişikliği kontrolü
    if (payload.containsKey('status')) {
      final oldStatus = oldTicket['status'] as String? ?? 'open';
      final newStatus = payload['status'] as String?;
      if (newStatus != null && oldStatus != newStatus) {
        // Eğer gizli durumdan (draft) aktif duruma geçiyorsa, "yeni iş emri" bildirimi gönder
        final activeStatuses = ['open', 'in_progress', 'panel_done_stock', 'panel_done_sent'];
        if (oldStatus == 'draft' && activeStatuses.contains(newStatus)) {
          // Gizli durumdan aktif duruma geçiş: Yeni iş emri bildirimi gönder
          await _notificationService.notifyTicketCreated(
            ticketId: ticketId,
            ticketTitle: ticketTitle,
            jobCode: jobCode,
            createdBy: userName,
          );
        } else {
          // Normal durum değişikliği bildirimi
          await _notificationService.notifyTicketStatusChanged(
            ticketId: ticketId,
            ticketTitle: ticketTitle,
            oldStatus: oldStatus,
            newStatus: newStatus,
            changedBy: userName,
            jobCode: jobCode,
          );
        }

        // --- PARTNER BİLDİRİMİ ---
        final partnerId = oldTicket['partner_id'] as int?;
        if (partnerId != null && (newStatus == 'completed' || newStatus == 'service_required')) {
          // Burada normalde Partner kullanıcılarını bulup onlara bildirim atarız.
          // Şimdilik logluyoruz. Gerçek implementasyonda NotificationService'e 
          // notifyPartnerUsers(partnerId, message) gibi bir metod eklenmeli.
          debugPrint('Partner Bildirimi Tetiklendi! PartnerID: $partnerId, Yeni Durum: $newStatus');
          
          // Örnek: await _notificationService.notifyPartnerUsers(partnerId, ticketTitle, newStatus);
        }
      }
    }
    
    // Öncelik değişikliği kontrolü
    if (payload.containsKey('priority')) {
      final oldPriority = oldTicket['priority'] as String? ?? 'normal';
      final newPriority = payload['priority'] as String?;
      if (newPriority != null && oldPriority != newPriority) {
        await _notificationService.notifyPriorityChanged(
          ticketId: ticketId,
          ticketTitle: ticketTitle,
          oldPriority: oldPriority,
          newPriority: newPriority,
          jobCode: jobCode,
        );
      }
    }
  }

  // --- NOT İŞLEMLERİ ---

  Future<List<Map<String, dynamic>>> getNotes(String ticketId) async {
    dynamic queryId = int.tryParse(ticketId) ?? ticketId;
    
    final response = await _supabase
        .from('ticket_notes')
        .select('*, profiles(full_name, role)')
        .eq('ticket_id', queryId)
        .order('created_at', ascending: true);
        
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addNote(String ticketId, String note, [List<String>? imageUrls]) async {
    dynamic queryId = int.tryParse(ticketId) ?? ticketId;
    final user = _supabase.auth.currentUser;

    final Map<String, dynamic> data = {
      'ticket_id': queryId,
      'note': note,
      'user_id': user?.id,
    };

    if (imageUrls != null && imageUrls.isNotEmpty) {
      data['image_urls'] = imageUrls;
    }

    await _supabase.from('ticket_notes').insert(data);
    
    // Bildirim gönder (asenkron, hata olsa bile işlem devam etsin)
    _sendNoteNotification(ticketId).catchError((e) {
      debugPrint('Bildirim gönderme hatası: $e');
    });
  }

  /// Not içeriğini günceller
  Future<void> updateNote(int noteId, String note) async {
    await _supabase
        .from('ticket_notes')
        .update({'note': note})
        .eq('id', noteId);
  }
  
  /// Not eklendiğinde bildirim gönderir
  Future<void> _sendNoteNotification(String ticketId) async {
    try {
      final ticket = await getTicket(ticketId);
      if (ticket == null) return;
      
      final ticketTitle = ticket['title'] as String? ?? 'İş Emri';
      final jobCode = ticket['job_code'] as String?;
      final currentUser = await _userService.getCurrentUserProfile();
      final userName = currentUser?.fullName ?? 'Kullanıcı';
      
      await _notificationService.notifyNoteAdded(
        ticketId: ticketId,
        ticketTitle: ticketTitle,
        noteAuthor: userName,
        jobCode: jobCode,
      );
    } catch (e) {
      debugPrint('Not bildirimi gönderme hatası: $e');
    }
  }

  // --- RESİM YÜKLEME VE SIKIŞTIRMA ---

  Future<Uint8List?> compressImage(Uint8List list) async {
    // --- WEB KONTROLÜ ---
    // Web ortamında native sıkıştırma kütüphanesi çalışmadığı için
    // sıkıştırmayı atlıyoruz.
    if (kIsWeb) {
      debugPrint("Web ortamı algılandı: Sıkıştırma atlanıyor.");
      return list; 
    }

    try {
      var result = await FlutterImageCompress.compressWithList(
        list,
        minHeight: 1024,
        minWidth: 1024,
        quality: 70,
      );
      return result;
    } catch (e) {
      debugPrint("Sıkıştırma hatası: $e");
      return list; // Hata durumunda orjinal dosyayı döndür
    }
  }

  Future<List<String>> uploadImages(String ticketId, List<PlatformFile> files) async {
    List<String> uploadedUrls = [];

    for (var file in files) {
      if (file.bytes == null) continue;

      try {
        // 1. Uzantı ve İsim
        String extension = file.extension ?? 'jpg';
        String cleanName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '');
        
        // Sıkıştırma öncesi bytes
        Uint8List? imageBytes = file.bytes;
        
        // 2. Sıkıştırma (Web değilse, çıktı her zaman JPG olur)
        if (!kIsWeb && imageBytes != null) {
          imageBytes = await compressImage(imageBytes);
          // Sıkıştırma yapıldıysa uzantıyı zorla jpg yap
          extension = 'jpg';
          // Dosya ismindeki uzantıyı da jpg ile değiştir
          cleanName = cleanName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '.jpg');
        }

        if (imageBytes == null) continue;

        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$cleanName';

        // 3. Yükleme
        final filePath = '$ticketId/$fileName';
        await _supabase.storage.from('ticket-files').uploadBinary(
          filePath,
          imageBytes,
          fileOptions: FileOptions(contentType: 'image/$extension', upsert: false),
        );

        // 4. URL Alma
        final url = _supabase.storage.from('ticket-files').getPublicUrl(filePath);
        uploadedUrls.add(url);
      } catch (e) {
        debugPrint('Yükleme hatası ($file.name): $e');
      }
    }
    return uploadedUrls;
  }
}
