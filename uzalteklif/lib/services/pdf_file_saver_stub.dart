import 'dart:typed_data';

Future<String?> savePdfFile({
  required String fileName,
  required Uint8List bytes,
  bool openAfterSave = false,
  String? archiveQuoteCode,
}) {
  throw UnsupportedError('PDF kaydetme bu platformda desteklenmiyor.');
}
