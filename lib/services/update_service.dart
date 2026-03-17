import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/logging/app_logger.dart';
import '../theme/app_colors.dart';

class UpdateService {
  UpdateService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  static const AppLogger _logger = AppLogger('UpdateService');
  final SupabaseClient _supabase;

  Future<void> checkVersion(BuildContext context) async {
    if (kIsWeb) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuildNumber = int.parse(packageInfo.buildNumber);

      final response =
          await _supabase
              .from('app_versions')
              .select()
              .order('build_number', ascending: false)
              .limit(1)
              .maybeSingle();

      if (response == null) return;

      final latestBuildNumber = response['build_number'] as int;
      final isMandatory = response['is_mandatory'] as bool? ?? false;
      final downloadUrl = response['download_url'] as String;
      final releaseNotes =
          response['release_notes'] as String? ??
          'Performans iyilestirmeleri ve hata duzeltmeleri.';

      if (latestBuildNumber > currentBuildNumber && context.mounted) {
        _showUpdateDialog(
          context,
          isMandatory: isMandatory,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
          newVersion: response['version_name'] ?? 'Yeni Surum',
        );
      }
    } catch (error, stackTrace) {
      _logger.error(
        'check_version_failed',
        error: error,
        stackTrace: stackTrace,
      );
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
      barrierDismissible: !isMandatory,
      builder:
          (context) => PopScope(
            canPop: !isMandatory,
            child: AlertDialog(
              title: Row(
                children: [
                  const Icon(
                    Icons.system_update,
                    color: AppColors.corporateNavy,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Guncelleme Mevcut')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Surum $newVersion yayinlandi!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text('Yenilikler:'),
                  Text(
                    releaseNotes,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  if (isMandatory)
                    const Text(
                      'Kullanima devam etmek icin guncelleme yapmaniz gerekmektedir.',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              actions: [
                if (!isMandatory)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Sonra',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: () => _launchDownloadUrl(downloadUrl),
                  icon: const Icon(Icons.download),
                  label: const Text('Indir ve Guncelle'),
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
    var finalUrl = url.trim();
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    final uri = Uri.parse(finalUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error, stackTrace) {
      _logger.error(
        'launch_download_url_failed',
        data: {'url': finalUrl},
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
