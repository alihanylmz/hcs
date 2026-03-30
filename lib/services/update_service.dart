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

      final response = await _fetchLatestVersion();

      if (response == null) return;

      final latestBuildNumber = _parseBuildNumber(response['build_number']);
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

  Future<Map<String, dynamic>?> _fetchLatestVersion() async {
    final platformKey = _currentPlatformKey();

    if (platformKey != null) {
      final platformVersion = await _tryFetchPlatformVersion(platformKey);
      if (platformVersion != null) {
        return platformVersion;
      }

      final sharedVersion = await _tryFetchPlatformVersion('all');
      if (sharedVersion != null) {
        return sharedVersion;
      }
    }

    final response =
        await _supabase
            .from('app_versions')
            .select()
            .order('build_number', ascending: false)
            .limit(1)
            .maybeSingle();

    return response == null ? null : Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>?> _tryFetchPlatformVersion(
    String platform,
  ) async {
    try {
      final response =
          await _supabase
              .from('app_versions')
              .select()
              .eq('platform', platform)
              .order('build_number', ascending: false)
              .limit(1)
              .maybeSingle();

      return response == null ? null : Map<String, dynamic>.from(response);
    } on PostgrestException catch (error) {
      if (_isMissingPlatformColumn(error)) {
        return null;
      }
      rethrow;
    }
  }

  String? _currentPlatformKey() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.windows:
        return 'windows';
      default:
        return null;
    }
  }

  int _parseBuildNumber(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _isMissingPlatformColumn(PostgrestException error) {
    final message = error.message.toLowerCase();
    return message.contains('platform') &&
        (message.contains('column') ||
            message.contains('schema cache') ||
            message.contains('does not exist') ||
            error.code == '42703');
  }

  bool _shouldUseWindowsAppInstaller(String url) {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.windows &&
        url.trim().toLowerCase().endsWith('.appinstaller');
  }

  bool _isWindowsInstallerExe(String url) {
    if (kIsWeb) {
      return false;
    }

    final normalized = url.trim().toLowerCase();
    return defaultTargetPlatform == TargetPlatform.windows &&
        normalized.endsWith('.exe');
  }

  bool _isWindowsManualPackage(String url) {
    if (kIsWeb) {
      return false;
    }

    final normalized = url.trim().toLowerCase();
    return defaultTargetPlatform == TargetPlatform.windows &&
        normalized.endsWith('.zip');
  }

  String _downloadActionLabel(String downloadUrl) {
    if (_shouldUseWindowsAppInstaller(downloadUrl)) {
      return 'Windows Yukleyiciyi Ac';
    }
    if (_isWindowsInstallerExe(downloadUrl)) {
      return 'Indir ve Kur';
    }
    if (_isWindowsManualPackage(downloadUrl)) {
      return 'Indir ve Manuel Guncelle';
    }
    return 'Indir ve Guncelle';
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
                  if (_isWindowsInstallerExe(downloadUrl))
                    const Text(
                      'Windows kurulumu tek dosya yukleyici ile yapilir. Dosyayi indirip calistirin; kurulum eski surumun ustune guncelleme yapabilir.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (_isWindowsManualPackage(downloadUrl))
                    const Text(
                      'Windows guncellemesi manuel kurulur. Zip dosyasini indirip acin, sonra yeni surum klasorundeki dosyalarla mevcut kurulumunuzu degistirin.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if ((_isWindowsInstallerExe(downloadUrl) ||
                          _isWindowsManualPackage(downloadUrl)) &&
                      isMandatory)
                    const SizedBox(height: 12),
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
                  icon: Icon(
                    _shouldUseWindowsAppInstaller(downloadUrl)
                        ? Icons.system_update_alt
                        : Icons.download,
                  ),
                  label: Text(_downloadActionLabel(downloadUrl)),
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

    if (_shouldUseWindowsAppInstaller(finalUrl)) {
      final appInstallerUri = Uri.parse(
        'ms-appinstaller:?source=${Uri.encodeComponent(finalUrl)}',
      );

      try {
        final launched = await launchUrl(
          appInstallerUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          return;
        }
      } catch (error, stackTrace) {
        _logger.warning(
          'launch_windows_appinstaller_fallback',
          data: {'url': finalUrl},
          error: error,
          stackTrace: stackTrace,
        );
      }
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
