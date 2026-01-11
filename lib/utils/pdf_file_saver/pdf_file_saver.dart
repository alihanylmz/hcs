import 'dart:typed_data';

import 'pdf_file_saver_stub.dart'
    if (dart.library.html) 'pdf_file_saver_web.dart'
    if (dart.library.io) 'pdf_file_saver_io.dart';

/// Save/download a PDF in a platform-appropriate way.
abstract class PdfFileSaver {
  /// - Web: by default triggers a download. If [openInBrowser] is true, opens the PDF
  ///   in a new browser tab (user can download from the built-in PDF viewer).
  /// - Mobile: uses native share sheet.
  /// - Desktop: shows a "Save As" dialog and writes the file.
  static Future<void> save({
    required Uint8List bytes,
    required String filename,
    bool openInBrowser = false,
  }) {
    return PdfFileSaverImpl.save(bytes: bytes, filename: filename, openInBrowser: openInBrowser);
  }
}


