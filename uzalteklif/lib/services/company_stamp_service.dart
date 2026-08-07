import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

/// Sirket icin tek bir PNG/JPG kase gorsel yonetir.
///
/// - Kase her onaylanan teklifin PDF'ine basilir.
/// - Uygulama `{appSupport}/company_stamp.png` altinda tek bir dosya tutar;
///   kullanici yeni bir PNG yuklediginde eski dosya uzerine yazilir.
/// - Supabase ile senkron degildir (yerel saklama); her kurulum icin kase
///   bir kez yuklenmelidir.
class CompanyStampService {
  const CompanyStampService();

  static const _fileName = 'company_stamp.png';
  static const _allowedExtensions = ['png', 'jpg', 'jpeg', 'webp'];

  /// Mevcut kase dosyasinin yolunu doner. Dosya yoksa null.
  Future<String?> getExistingStampPath() async {
    final path = await _targetPath();
    final file = File(path);
    if (await file.exists()) return path;
    return null;
  }

  /// Kase var mi? `getExistingStampPath` ile esdeger ama bool doner.
  Future<bool> hasStamp() async => (await getExistingStampPath()) != null;

  /// Kullaniciya dosya secim penceresi gosterir; bir resim secerse onu app
  /// veri dizinine kopyalar. Iptal ederse null. Basarili ise kopyanin tam
  /// yolunu doner.
  Future<String?> pickAndStore() async {
    const typeGroup = XTypeGroup(
      label: 'Kase',
      extensions: _allowedExtensions,
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) return null;

    final targetPath = await _targetPath();
    await File(file.path).copy(targetPath);
    return targetPath;
  }

  /// Mevcut kase dosyasini siler. Yoksa sessiz gecer.
  Future<void> remove() async {
    final path = await _targetPath();
    final file = File(path);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {
        // Dosya kilitliyse veya silinemediyse sessiz gec.
      }
    }
  }

  Future<String> _targetPath() async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return '${dir.path}${Platform.pathSeparator}$_fileName';
  }
}
