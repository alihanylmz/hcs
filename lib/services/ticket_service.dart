import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb için
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:file_picker/file_picker.dart';

class TicketService {
  final _supabase = Supabase.instance.client;

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
    await _supabase.from('tickets').update(payload).eq('id', queryId);
  }

  // --- NOT İŞLEMLERİ ---

  Future<List<Map<String, dynamic>>> getNotes(String ticketId) async {
    dynamic queryId = int.tryParse(ticketId) ?? ticketId;
    
    final response = await _supabase
        .from('ticket_notes')
        .select('*, profiles(full_name)')
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
        final extension = file.extension ?? 'jpg';
        final cleanName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '');
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$cleanName';

        // 2. Sıkıştırma
        Uint8List? imageBytes = file.bytes;
        imageBytes = await compressImage(imageBytes!);

        if (imageBytes == null) continue;

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
