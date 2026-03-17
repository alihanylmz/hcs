import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/logging/app_logger.dart';

class TicketRepository {
  TicketRepository({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  static const AppLogger _logger = AppLogger('TicketRepository');
  final SupabaseClient _supabase;

  Future<Map<String, dynamic>?> getTicket(String ticketId) async {
    final queryId = _resolveId(ticketId);

    return _supabase
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

  Future<void> updateTicket(
    String ticketId,
    Map<String, dynamic> payload,
  ) async {
    final queryId = _resolveId(ticketId);
    await _supabase.from('tickets').update(payload).eq('id', queryId);
  }

  Future<List<Map<String, dynamic>>> getNotes(String ticketId) async {
    final queryId = _resolveId(ticketId);

    final response = await _supabase
        .from('ticket_notes')
        .select('*, profiles(full_name, role)')
        .eq('ticket_id', queryId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addNote({
    required String ticketId,
    required String note,
    required String noteType,
    List<String>? imageUrls,
  }) async {
    final queryId = _resolveId(ticketId);
    final user = _supabase.auth.currentUser;

    final data = <String, dynamic>{
      'ticket_id': queryId,
      'note': note,
      'user_id': user?.id,
      'note_type': noteType,
    };

    if (imageUrls != null && imageUrls.isNotEmpty) {
      data['image_urls'] = imageUrls;
    }

    await _supabase.from('ticket_notes').insert(data);
  }

  Future<void> updateNote(int noteId, String note) async {
    await _supabase
        .from('ticket_notes')
        .update({'note': note})
        .eq('id', noteId);
  }

  Future<Uint8List?> compressImage(Uint8List bytes) async {
    if (kIsWeb) {
      _logger.info('compress_image_skipped_for_web');
      return bytes;
    }

    try {
      return await FlutterImageCompress.compressWithList(
        bytes,
        minHeight: 1024,
        minWidth: 1024,
        quality: 70,
      );
    } catch (error, stackTrace) {
      _logger.warning(
        'compress_image_failed',
        error: error,
        stackTrace: stackTrace,
      );
      return bytes;
    }
  }

  Future<List<String>> uploadImages(
    String ticketId,
    List<PlatformFile> files,
  ) async {
    final uploadedUrls = <String>[];

    for (final file in files) {
      if (file.bytes == null) continue;

      try {
        var extension = file.extension ?? 'jpg';
        var cleanName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '');
        Uint8List? imageBytes = file.bytes;

        if (!kIsWeb && imageBytes != null) {
          imageBytes = await compressImage(imageBytes);
          extension = 'jpg';
          cleanName = cleanName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '.jpg');
        }

        if (imageBytes == null) continue;

        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$cleanName';
        final filePath = '$ticketId/$fileName';

        await _supabase.storage
            .from('ticket-files')
            .uploadBinary(
              filePath,
              imageBytes,
              fileOptions: FileOptions(
                contentType: 'image/$extension',
                upsert: false,
              ),
            );

        final url = _supabase.storage
            .from('ticket-files')
            .getPublicUrl(filePath);
        uploadedUrls.add(url);
      } catch (error, stackTrace) {
        _logger.warning(
          'upload_image_failed',
          data: {'ticketId': ticketId, 'fileName': file.name},
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return uploadedUrls;
  }

  Future<String?> uploadFile(String ticketId, PlatformFile file) async {
    if (file.bytes == null) return null;

    try {
      final cleanName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$cleanName';
      final filePath = '$ticketId/$fileName';

      var contentType = 'application/octet-stream';
      if (file.extension == 'pdf') contentType = 'application/pdf';
      if (file.extension == 'jpg' || file.extension == 'jpeg') {
        contentType = 'image/jpeg';
      }
      if (file.extension == 'png') contentType = 'image/png';

      await _supabase.storage
          .from('ticket-files')
          .uploadBinary(
            filePath,
            file.bytes!,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );

      return _supabase.storage.from('ticket-files').getPublicUrl(filePath);
    } catch (error, stackTrace) {
      _logger.error(
        'upload_file_failed',
        data: {'ticketId': ticketId, 'fileName': file.name},
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  dynamic _resolveId(String ticketId) {
    return int.tryParse(ticketId) ?? ticketId;
  }
}
