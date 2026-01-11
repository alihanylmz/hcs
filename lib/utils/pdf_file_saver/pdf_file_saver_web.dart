import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:async';

class PdfFileSaverImpl {
  static Future<void> save({
    required Uint8List bytes,
    required String filename,
    bool openInBrowser = false,
  }) async {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);

    // If we open in a new tab, we cannot revoke immediately (the new tab still needs the URL).
    // We'll revoke a bit later to avoid leaking object URLs.
    void revokeLater() {
      Timer(const Duration(minutes: 2), () {
        try {
          html.Url.revokeObjectUrl(url);
        } catch (_) {
          // ignore
        }
      });
    }

    if (openInBrowser) {
      // Open a dedicated preview tab that includes a "Download" button with the correct filename.
      // NOTE: Opening the raw blob URL directly makes Chrome show a UUID-like name (blob URLs have no filename).
      // This wrapper preserves UX and ensures the downloaded file name is what we want.
      final opened = html.window.open('', '_blank');
      // If popup blocked, fallback to download.
      final html.Window? win = opened is html.Window ? opened : null;
      if (win != null) {
        try {
          // `win.document` is typed as `Document`; `body`/`title` exist on `HtmlDocument`.
          final html.HtmlDocument doc = win.document as html.HtmlDocument;
          doc.title = filename;

          // Basic layout
          doc.body?.style.margin = '0';
          doc.body?.style.backgroundColor = '#0b1220';

          final header = html.DivElement()
            ..style.display = 'flex'
            ..style.alignItems = 'center'
            ..style.justifyContent = 'space-between'
            ..style.padding = '10px 12px'
            ..style.backgroundColor = '#0f172a'
            ..style.color = '#ffffff'
            ..style.fontFamily = 'system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif';

          final title = html.DivElement()
            ..text = filename
            ..style.fontSize = '14px'
            ..style.fontWeight = '600'
            ..style.overflow = 'hidden'
            ..style.textOverflow = 'ellipsis'
            ..style.whiteSpace = 'nowrap'
            ..style.maxWidth = '70vw';

          final actions = html.DivElement()..style.display = 'flex';

          final download = html.AnchorElement(href: url)
            ..text = 'İndir'
            ..download = filename
            ..target = '_self'
            ..style.display = 'inline-flex'
            ..style.alignItems = 'center'
            ..style.gap = '8px'
            ..style.padding = '8px 12px'
            ..style.borderRadius = '10px'
            ..style.backgroundColor = '#1f2937'
            ..style.color = '#ffffff'
            ..style.textDecoration = 'none'
            ..style.border = '1px solid rgba(255,255,255,0.12)';

          actions.append(download);
          header..append(title)..append(actions);

          final frame = html.IFrameElement()
            ..src = url
            ..style.border = '0'
            ..style.width = '100%'
            ..style.height = 'calc(100vh - 52px)'
            ..style.display = 'block'
            ..style.backgroundColor = '#ffffff';

          doc.body?.children.clear();
          doc.body?.append(header);
          doc.body?.append(frame);

          revokeLater();
          return;
        } catch (_) {
          // If anything fails (rare), fallback to download.
        }
      }
    }

    // Default behavior: trigger a download
    try {
      final anchor = html.AnchorElement(href: url)
        ..download = filename
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    } finally {
      html.Url.revokeObjectUrl(url);
    }
  }
}


