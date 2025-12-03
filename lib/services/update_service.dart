import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class UpdateService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Güncelleme kontrolü yapar ve gerekirse dialog gösterir
  Future<void> checkVersion(BuildContext context) async {
    try {
      // 1. Mevcut uygulamanın sürüm bilgilerini al
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.parse(packageInfo.buildNumber);

      // 2. Supabase'den en son sürüm bilgisini çek
      final response = await _supabase
          .from('app_versions')
          .select()
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return;

      final latestBuildNumber = response['build_number'] as int;
      final isMandatory = response['is_mandatory'] as bool? ?? false;
      final downloadUrl = response['download_url'] as String;
      final releaseNotes = response['release_notes'] as String? ?? 'Performans iyileştirmeleri ve hata düzeltmeleri.';

      // 3. Karşılaştırma: Eğer sunucudaki sürüm daha büyükse güncelleme var
      if (latestBuildNumber > currentBuildNumber) {
        if (context.mounted) {
          _showUpdateDialog(
            context,
            isMandatory: isMandatory,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
            newVersion: response['version_name'] ?? 'Yeni Sürüm',
          );
        }
      }
    } catch (e) {
      debugPrint('Update kontrol hatası: $e');
    }
  }

  void _showUpdateDialog(
    BuildContext context, {
    required bool isMandatory,
    required String downloadUrl,
    required String releaseNotes,
    required String newVersion,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isMandatory, // Zorunlu ise boşluğa basınca kapanmaz
      builder: (context) => PopScope(
        canPop: !isMandatory, // Zorunlu ise geri tuşuyla kapanmaz
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.system_update, color: AppColors.corporateNavy),
              const SizedBox(width: 10),
              const Expanded(child: Text('Güncelleme Mevcut')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sürüm $newVersion yayınlandı!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text('Yenilikler:'),
              Text(releaseNotes, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 20),
              if (isMandatory)
                const Text(
                  'Kullanıma devam etmek için güncelleme yapmanız gerekmektedir.',
                  style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          actions: [
            if (!isMandatory)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Sonra', style: TextStyle(color: Colors.grey)),
              ),
            ElevatedButton.icon(
              onPressed: () => _launchDownloadUrl(downloadUrl),
              icon: const Icon(Icons.download),
              label: const Text('İndir ve Güncelle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.corporateNavy,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchDownloadUrl(String url) async {
    String finalUrl = url.trim();
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }
    
    final uri = Uri.parse(finalUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Link açılamadı: $e');
    }
  }
}

