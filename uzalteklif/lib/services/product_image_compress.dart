import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Urun fotograflarini Storage'a yuklemeden once kucultur; bant genisligi ve
/// disk kotasi icin JPEG ciktisi uretir.
class ProductImageCompress {
  ProductImageCompress._();

  /// Uzun kenar en fazla [maxLongEdge] piksel; JPEG kalitesi [jpegQuality] (1-100).
  static Future<Uint8List> fileToJpegBytes(
    String sourcePath, {
    int maxLongEdge = 900,
    int jpegQuality = 76,
  }) async {
    final raw = await File(sourcePath).readAsBytes();
    return bytesToJpegBytes(
      raw,
      maxLongEdge: maxLongEdge,
      jpegQuality: jpegQuality,
    );
  }

  static Uint8List bytesToJpegBytes(
    Uint8List raw, {
    int maxLongEdge = 900,
    int jpegQuality = 76,
  }) {
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw const FormatException('Gorsel okunamadi (desteklenmeyen format).');
    }
    final w = decoded.width;
    final h = decoded.height;
    final longest = w > h ? w : h;
    img.Image out = decoded;
    if (longest > maxLongEdge) {
      final scale = maxLongEdge / longest;
      out = img.copyResize(
        decoded,
        width: (w * scale).round().clamp(1, 1 << 15),
        height: (h * scale).round().clamp(1, 1 << 15),
        interpolation: img.Interpolation.linear,
      );
    }
    final q = jpegQuality.clamp(50, 92);
    return Uint8List.fromList(img.encodeJpg(out, quality: q));
  }
}
