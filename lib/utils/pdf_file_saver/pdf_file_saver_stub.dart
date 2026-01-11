import 'dart:typed_data';

/// Fallback implementation (should never be used on supported platforms).
class PdfFileSaverImpl {
  static Future<void> save({
    required Uint8List bytes,
    required String filename,
    bool openInBrowser = false,
  }) async {
    throw UnsupportedError('PDF save is not supported on this platform.');
  }
}


