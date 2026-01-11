import 'dart:typed_data';
import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

class PdfFileSaverImpl {
  static Future<void> save({
    required Uint8List bytes,
    required String filename,
    bool openInBrowser = false,
  }) async {
    // Mobile: native share sheet is a good UX.
    if (Platform.isAndroid || Platform.isIOS) {
      await Printing.sharePdf(bytes: bytes, filename: filename);
      return;
    }

    // Desktop (Windows/macOS/Linux): use a "Save As" dialog and write the file.
    final String defaultName = filename.toLowerCase().endsWith('.pdf') ? filename : '$filename.pdf';

    final String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'PDF Kaydet',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (outputFile == null) {
      // User cancelled.
      return;
    }

    final String path = outputFile.toLowerCase().endsWith('.pdf') ? outputFile : '$outputFile.pdf';
    final file = File(path);
    await file.writeAsBytes(bytes);

    // Optional: open the saved file with the OS default handler (often Chrome or a PDF viewer).
    if (openInBrowser) {
      final uri = Uri.file(path);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}


