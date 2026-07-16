import 'dart:html' as html;
import 'dart:typed_data';

Future<String?> savePdfFile({
  required String fileName,
  required Uint8List bytes,
  bool openAfterSave = false,
  String? archiveQuoteCode,
}) async {
  final safeName = _safePdfFileName(fileName, fallback: 'teklif.pdf');
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = safeName
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return safeName;
}

String _safePdfFileName(String fileName, {required String fallback}) {
  final safeName = fileName
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return safeName.isEmpty ? fallback : safeName;
}
