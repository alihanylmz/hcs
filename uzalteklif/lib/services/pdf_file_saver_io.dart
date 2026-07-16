import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'pdf_archive_service.dart';

Future<String?> savePdfFile({
  required String fileName,
  required Uint8List bytes,
  bool openAfterSave = false,
  String? archiveQuoteCode,
}) async {
  final file = await _writeToDefaultPdfFolder(fileName: fileName, bytes: bytes);
  if (archiveQuoteCode != null && archiveQuoteCode.trim().isNotEmpty) {
    await PdfArchiveService.mirrorToCorporateArchive(
      savedPdfPath: file.path,
      quoteCode: archiveQuoteCode,
    );
  }
  if (openAfterSave) {
    _openWithDefaultViewer(file.path);
  }
  return file.path;
}

void _openWithDefaultViewer(String path) {
  try {
    if (Platform.isWindows) {
      unawaited(Process.start('explorer.exe', [path]));
    } else if (Platform.isMacOS) {
      unawaited(Process.start('open', [path]));
    } else if (Platform.isLinux) {
      unawaited(Process.start('xdg-open', [path]));
    }
  } catch (_) {
    // PDF kaydedildi; goruntuleyici acilamazsa sessiz gec.
  }
}

Future<File> _writeToDefaultPdfFolder({
  required String fileName,
  required Uint8List bytes,
}) async {
  final baseDir =
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final sep = Platform.pathSeparator;
  final dir = Directory('${baseDir.path}${sep}UzalTeklif');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final safeName = _safePdfFileName(fileName, fallback: 'teklif.pdf');
  final target = await _availableFile(dir: dir, fileName: safeName);
  return target.writeAsBytes(bytes, flush: true);
}

Future<File> _availableFile({
  required Directory dir,
  required String fileName,
}) async {
  final dot = fileName.lastIndexOf('.');
  final base = dot > 0 ? fileName.substring(0, dot) : fileName;
  final ext = dot > 0 ? fileName.substring(dot) : '.pdf';
  var candidate = File('${dir.path}${Platform.pathSeparator}$base$ext');
  var index = 2;
  while (await candidate.exists()) {
    candidate = File('${dir.path}${Platform.pathSeparator}$base-$index$ext');
    index++;
  }
  return candidate;
}

String _safePdfFileName(String fileName, {required String fallback}) {
  final safeName = fileName
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return safeName.isEmpty ? fallback : safeName;
}
