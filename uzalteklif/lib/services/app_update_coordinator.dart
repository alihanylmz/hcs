import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_update_service.dart';

/// GitHub Releases tabanli Windows guncelleme diyalogunu yonetir.
class AppUpdateCoordinator {
  AppUpdateCoordinator._();

  static const _prefsSkippedTag = 'app_update_skipped_release_tag';

  static Future<void> checkAndPrompt(BuildContext context) async {
    if (!context.mounted) return;
    final service = AppUpdateService();
    try {
      final release = await service.fetchNewerRelease();
      if (release == null || !context.mounted) return;

      final prefs = await SharedPreferences.getInstance();
      if (!context.mounted) return;
      final skipped = prefs.getString(_prefsSkippedTag);
      if (skipped == release.tagName) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _UpdateDialog(
          release: release,
          onDownload: () => _downloadToDownloads(release),
          onSkipVersion: () async {
            await prefs.setString(_prefsSkippedTag, release.tagName);
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          onOpenInBrowser: () => _openUrl(release.htmlUrl),
        ),
      );
    } catch (e, st) {
      debugPrint('AppUpdateCoordinator: $e\n$st');
    } finally {
      service.dispose();
    }
  }

  static Future<void> _openUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;
    if (Platform.isWindows) {
      await Process.start('cmd', ['/c', 'start', '', u], runInShell: true);
    }
  }

  static Future<String?> _downloadToDownloads(GithubLatestRelease release) async {
    final service = AppUpdateService();
    try {
      final bytes = await service.downloadReleaseBytes(release.downloadUrl);
      final dir = await getDownloadsDirectory();
      if (dir == null) return null;
      final safeName = release.assetName.trim().isEmpty
          ? 'uzalteklif-guncelleme.zip'
          : release.assetName.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final file = File('${dir.path}${Platform.pathSeparator}$safeName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } finally {
      service.dispose();
    }
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.release,
    required this.onDownload,
    required this.onSkipVersion,
    required this.onOpenInBrowser,
  });

  final GithubLatestRelease release;
  final Future<String?> Function() onDownload;
  final Future<void> Function() onSkipVersion;
  final Future<void> Function() onOpenInBrowser;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _busy = false;
  String? _error;
  String? _savedPath;

  String get _notes {
    final raw = widget.release.body.trim();
    if (raw.isEmpty) return 'Detaylar icin GitHub surum sayfasini acabilirsiniz.';
    if (raw.length > 1200) return '${raw.substring(0, 1200)}…';
    return raw;
  }

  Future<void> _handleDownload() async {
    setState(() {
      _busy = true;
      _error = null;
      _savedPath = null;
    });
    try {
      final path = await widget.onDownload();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _savedPath = path;
        if (path == null) _error = 'Indirme klasoru bulunamadi.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni surum hazir'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Surum: ${widget.release.version} (${widget.release.tagName})',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(_notes),
            if (_savedPath != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                'Dosya kaydedildi:\n$_savedPath\n\nUygulamayi kapatin, zip icindeki Release klasorunu mevcut kurulumunuzun uzerine yazin (veya zip icindeki talimatlari izleyin).',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Sonra'),
        ),
        TextButton(
          onPressed: _busy ? null : widget.onSkipVersion,
          child: const Text('Bu surumu atla'),
        ),
        TextButton(
          onPressed: _busy || widget.release.htmlUrl.trim().isEmpty
              ? null
              : () async {
                  await widget.onOpenInBrowser();
                  if (context.mounted) Navigator.of(context).pop();
                },
          child: const Text('GitHubda ac'),
        ),
        FilledButton(
          onPressed: _busy ? null : _handleDownload,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Indir'),
        ),
      ],
    );
  }
}
