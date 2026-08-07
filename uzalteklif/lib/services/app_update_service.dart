import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';

/// GitHub Releases [latest] yanitindan secilen surum bilgisi.
class GithubLatestRelease {
  GithubLatestRelease({
    required this.tagName,
    required this.version,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.downloadUrl,
    required this.assetName,
  });

  final String tagName;
  final String version;
  final String name;
  final String body;
  final String htmlUrl;
  final String downloadUrl;
  final String assetName;
}

class AppUpdateService {
  AppUpdateService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _userAgent = 'uzalteklif-windows-auto-update/1.0';

  /// Mevcut uygulama surumu (`pubspec` + derleme).
  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version.trim();
  }

  /// GitHub'da daha yeni bir surum varsa bilgi doner; yoksa veya hata olursa null.
  Future<GithubLatestRelease?> fetchNewerRelease() async {
    if (!Platform.isWindows) return null;
    final pair = AppConfig.updateGithubOwnerRepo;
    if (pair == null) return null;

    final (owner, repo) = pair;
    final uri = Uri.https(
      'api.github.com',
      '/repos/$owner/$repo/releases/latest',
    );

    final response = await _http.get(
      uri,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': _userAgent,
      },
    );

    if (response.statusCode != 200) return null;

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = (map['tag_name'] as String?)?.trim() ?? '';
    if (tagName.isEmpty) return null;

    final remoteVersion = _normalizeVersion(tagName);
    final current = _normalizeVersion(await currentVersion());
    if (compareSemver(remoteVersion, current) <= 0) return null;

    final assets = (map['assets'] as List<dynamic>?) ?? const [];
    final picked = _pickWindowsAsset(assets);
    if (picked == null) return null;

    final downloadUrl = picked['browser_download_url'] as String? ?? '';
    if (downloadUrl.isEmpty) return null;

    return GithubLatestRelease(
      tagName: tagName,
      version: remoteVersion,
      name: (map['name'] as String?)?.trim() ?? tagName,
      body: (map['body'] as String?)?.trim() ?? '',
      htmlUrl: (map['html_url'] as String?)?.trim() ?? '',
      downloadUrl: downloadUrl,
      assetName: (picked['name'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic>? _pickWindowsAsset(List<dynamic> assets) {
    Map<String, dynamic>? best;
    for (final raw in assets) {
      if (raw is! Map<String, dynamic>) continue;
      final name = (raw['name'] as String?)?.toLowerCase() ?? '';
      if (!name.endsWith('.zip') && !name.endsWith('.exe')) continue;
      if (name.contains('windows') || name.contains('win64') || name.contains('x64')) {
        return raw;
      }
      best ??= raw;
    }
    return best;
  }

  String _normalizeVersion(String raw) {
    var s = raw.trim();
    if (s.startsWith('v') || s.startsWith('V')) {
      s = s.substring(1);
    }
    final plus = s.split('+').first;
    return plus.split('-').first.trim();
  }

  /// Indirilen baytlar (buyuk dosyalar icin uyar).
  Future<List<int>> downloadReleaseBytes(String url) async {
    final response = await _http.get(
      Uri.parse(url),
      headers: const {'User-Agent': _userAgent},
    );
    if (response.statusCode != 200) {
      throw HttpException('Indirme basarisiz: ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  void dispose() {
    _http.close();
  }
}

/// `a > b` ise pozitif; esitlik 0.
int compareSemver(String a, String b) {
  List<int> parts(String s) {
    final core = s.split('+').first.split('-').first;
    final segs = core.split('.');
    return segs.map((e) => int.tryParse(e.trim()) ?? 0).toList();
  }

  final pa = parts(a);
  final pb = parts(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}
