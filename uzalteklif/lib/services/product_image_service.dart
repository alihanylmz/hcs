import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'product_image_compress.dart';

/// Urun gorseli: oturum varsa Supabase Storage (`product-images`) + sikistirilmis
/// JPEG; yoksa yerel `{appSupport}/product_images/` kopyasi.
class ProductImageService {
  const ProductImageService();

  static const _bucket = 'product-images';
  static const _folderName = 'product_images';
  static const _allowedExtensions = ['png', 'jpg', 'jpeg', 'webp'];

  static bool isRemoteUrl(String path) {
    final t = path.trim().toLowerCase();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  static String objectKeyForProductId(String productId) {
    final safe = productId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '$safe.jpg';
  }

  /// Oturum acik ve [supabase] verilmisse: dosyayi ~900px JPEG (~76 kalite)
  /// olarak yukler, public URL doner. Aksi halde yerel kopya yolu doner.
  Future<String?> pickAndStore({
    required String productId,
    String? replacing,
    SupabaseClient? supabase,
  }) async {
    const typeGroup = XTypeGroup(
      label: 'Gorsel',
      extensions: _allowedExtensions,
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return null;

    final client = supabase;
    if (client != null && client.auth.currentSession != null) {
      final jpegBytes = await ProductImageCompress.fileToJpegBytes(file.path);
      final key = objectKeyForProductId(productId);
      await client.storage.from(_bucket).uploadBinary(
            key,
            jpegBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      _cleanupLocalReplacing(replacing);
      return client.storage.from(_bucket).getPublicUrl(key);
    }

    final targetPath = await _storeForProduct(
      productId: productId,
      sourcePath: file.path,
    );

    if (replacing != null &&
        replacing.isNotEmpty &&
        replacing != targetPath) {
      _cleanupLocalReplacing(replacing);
    }

    return targetPath;
  }

  /// Yerel dosyayi siler veya Storage nesnesini (oturum + [productId] gerekli).
  Future<void> remove(
    String path, {
    SupabaseClient? supabase,
    String? productId,
  }) async {
    if (path.isEmpty) return;
    if (isRemoteUrl(path)) {
      if (supabase != null &&
          supabase.auth.currentSession != null &&
          productId != null) {
        try {
          await supabase.storage
              .from(_bucket)
              .remove([objectKeyForProductId(productId)]);
        } catch (_) {}
      }
      return;
    }
    _unawaitedDelete(File(path));
  }

  void _cleanupLocalReplacing(String? replacing) {
    if (replacing == null || replacing.isEmpty) return;
    if (isRemoteUrl(replacing)) return;
    _unawaitedDelete(File(replacing));
  }

  Future<String> _storeForProduct({
    required String productId,
    required String sourcePath,
  }) async {
    final dir = await _ensureDir();
    final extension = _extractExtension(sourcePath);
    final safeId = productId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final targetPath = '${dir.path}${Platform.pathSeparator}$safeId.$extension';
    await File(sourcePath).copy(targetPath);
    return targetPath;
  }

  Future<Directory> _ensureDir() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(
      '${support.path}${Platform.pathSeparator}$_folderName',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String _extractExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) {
      return 'png';
    }
    final raw = path.substring(dotIndex + 1).toLowerCase();
    return _allowedExtensions.contains(raw) ? raw : 'png';
  }
}

void _unawaitedDelete(File file) {
  file.exists().then((exists) {
    if (exists) {
      file.delete().catchError((_) => file);
    }
  });
}
