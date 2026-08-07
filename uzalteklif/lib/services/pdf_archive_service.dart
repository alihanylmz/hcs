import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

/// Her basarili PDF diske yazildiginda bir kopya uygulama destek dizinine alinir;
/// kurumsal yedek / denetim izi (Supabase disi, cihaz ici).
class PdfArchiveService {
  PdfArchiveService._();

  static Future<void> mirrorToCorporateArchive({
    required String savedPdfPath,
    required String quoteCode,
  }) async {
    try {
      final root = await getApplicationSupportDirectory();
      final sep = Platform.pathSeparator;
      final dir = Directory('${root.path}${sep}UzalTeklif${sep}pdf_arsiv');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final safe = quoteCode.replaceAll(RegExp(r'[^\w.\-]'), '_');
      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final destPath = '${dir.path}$sep${safe}_$stamp.pdf';
      await File(savedPdfPath).copy(destPath);
    } catch (_) {
      // Birincil dosya zaten yazildi; arsiv kopyasi opsiyonel.
    }
  }
}
