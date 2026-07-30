import 'dart:convert';
import 'dart:io';

const _quoteTables = <String>[
  'products',
  'customer_accounts',
  'quotes',
  'quote_line_items',
  'quote_revisions',
  'discovery_projects',
  'discovery_device_templates',
  'control_hardware_catalog',
  'own_companies',
  'price_adjustment_rules',
  'market_rates',
  'audit_logs',
  'user_profiles',
];

Future<void> main() async {
  final source = _ProjectConfig.fromEnvironment(
    prefix: 'SOURCE',
    label: 'Teklif kaynak',
  );
  final target = _ProjectConfig.fromEnvironment(
    prefix: 'TARGET',
    label: 'İş Takip hedef',
  );
  if (source.url == target.url) {
    throw StateError('Kaynak ve hedef Supabase projeleri aynı olamaz.');
  }

  final sourceApi = _SupabaseAdminApi(source);
  final targetApi = _SupabaseAdminApi(target);

  stdout.writeln('TEKLİF VERİ TAŞIMA ENVANTERİ');
  stdout.writeln('Bu işlem salt okunurdur; hiçbir veri yazılmaz.');
  stdout.writeln('');
  stdout.writeln(
    '${'TABLO'.padRight(32)}'
    '${'KAYNAK'.padLeft(10)}'
    '${'HEDEF'.padLeft(10)}  DURUM',
  );

  var sourceTotal = 0;
  var existingTargetTableCount = 0;
  var populatedTargetTableCount = 0;
  for (final table in _quoteTables) {
    final sourceCount = await sourceApi.tableCount(table);
    final targetCount = await targetApi.tableCount(table);
    if (sourceCount != null) sourceTotal += sourceCount;
    if (targetCount != null) existingTargetTableCount++;
    if ((targetCount ?? 0) > 0) populatedTargetTableCount++;

    final status =
        sourceCount == null
            ? 'KAYNAKTA YOK'
            : targetCount == null
            ? 'HEDEF ŞEMA GEREKLİ'
            : targetCount == 0
            ? 'HEDEF BOŞ'
            : 'ÇAKIŞMA KONTROLÜ GEREKLİ';
    stdout.writeln(
      '${table.padRight(32)}'
      '${_countLabel(sourceCount).padLeft(10)}'
      '${_countLabel(targetCount).padLeft(10)}  $status',
    );
  }

  final sourceImages = await sourceApi.storageObjectCount('product-images');
  final targetImages = await targetApi.storageObjectCount('product-images');
  stdout.writeln(
    '${'storage: product-images'.padRight(32)}'
    '${_countLabel(sourceImages).padLeft(10)}'
    '${_countLabel(targetImages).padLeft(10)}  '
    '${targetImages == null ? 'HEDEF BUCKET GEREKLİ' : 'KONTROL EDİLDİ'}',
  );

  final sourceUsers = await sourceApi.authUserCount();
  final targetUsers = await targetApi.authUserCount();
  stdout.writeln('');
  stdout.writeln('Kaynak Auth kullanıcı sayısı : $sourceUsers');
  stdout.writeln('Hedef Auth kullanıcı sayısı  : $targetUsers');
  stdout.writeln('Kaynak toplam tablo kaydı    : $sourceTotal');
  stdout.writeln(
    'Hedefte hazır Teklif tablosu : '
    '$existingTargetTableCount/${_quoteTables.length}',
  );
  stdout.writeln('Hedefte dolu Teklif tablosu  : $populatedTargetTableCount');
  stdout.writeln('');
  stdout.writeln('ENVANTER TAMAMLANDI — VERİ YAZILMADI');
}

String _countLabel(int? value) => value?.toString() ?? 'YOK';

class _ProjectConfig {
  const _ProjectConfig({
    required this.label,
    required this.url,
    required this.serviceRoleKey,
  });

  factory _ProjectConfig.fromEnvironment({
    required String prefix,
    required String label,
  }) {
    final url = Platform.environment['${prefix}_SUPABASE_URL']?.trim() ?? '';
    final key =
        Platform.environment['${prefix}_SERVICE_ROLE_KEY']?.trim() ?? '';
    if (url.isEmpty || key.isEmpty) {
      throw StateError(
        '${prefix}_SUPABASE_URL ve ${prefix}_SERVICE_ROLE_KEY gerekli.',
      );
    }
    return _ProjectConfig(
      label: label,
      url: url.replaceAll(RegExp(r'/+$'), ''),
      serviceRoleKey: key,
    );
  }

  final String label;
  final String url;
  final String serviceRoleKey;
}

class _SupabaseAdminApi {
  const _SupabaseAdminApi(this.config);

  final _ProjectConfig config;

  Future<int?> tableCount(String table) async {
    final response = await _request(
      'GET',
      '/rest/v1/$table?select=*&limit=1',
      headers: const {'Prefer': 'count=exact', 'Range': '0-0'},
      allowMissing: true,
    );
    if (response == null) return null;
    final contentRange = response.headers['content-range'] ?? '';
    final separator = contentRange.lastIndexOf('/');
    if (separator < 0) {
      throw FormatException(
        '${config.label}: $table için kayıt sayısı alınamadı.',
      );
    }
    return int.parse(contentRange.substring(separator + 1));
  }

  Future<int> authUserCount() async {
    var total = 0;
    const pageSize = 1000;
    for (var page = 1; ; page++) {
      final response = await _request(
        'GET',
        '/auth/v1/admin/users?page=$page&per_page=$pageSize',
      );
      final decoded = jsonDecode(response!.body);
      final rawUsers = decoded is Map ? decoded['users'] : decoded;
      if (rawUsers is! List) {
        throw FormatException(
          '${config.label}: Auth kullanıcı yanıtı geçersiz.',
        );
      }
      total += rawUsers.length;
      if (rawUsers.length < pageSize) break;
    }
    return total;
  }

  Future<int?> storageObjectCount(String bucket) async {
    var total = 0;
    const pageSize = 1000;
    for (var offset = 0; ; offset += pageSize) {
      final response = await _request(
        'POST',
        '/storage/v1/object/list/$bucket',
        body: {'prefix': '', 'limit': pageSize, 'offset': offset},
        allowMissing: true,
      );
      if (response == null) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw FormatException(
          '${config.label}: $bucket bucket yanıtı geçersiz.',
        );
      }
      total += decoded.length;
      if (decoded.length < pageSize) break;
    }
    return total;
  }

  Future<_HttpResponse?> _request(
    String method,
    String path, {
    Map<String, String> headers = const {},
    Map<String, dynamic>? body,
    bool allowMissing = false,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(
        method,
        Uri.parse('${config.url}$path'),
      );
      request.headers
        ..set('apikey', config.serviceRoleKey)
        ..set(
          HttpHeaders.authorizationHeader,
          'Bearer ${config.serviceRoleKey}',
        )
        ..set(HttpHeaders.acceptHeader, 'application/json');
      headers.forEach(request.headers.set);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      if (allowMissing &&
          (response.statusCode == HttpStatus.notFound ||
              response.statusCode == HttpStatus.badRequest) &&
          (text.contains('PGRST205') ||
              text.contains('does not exist') ||
              text.contains('not found') ||
              text.contains('Bucket not found'))) {
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          '${config.label}: HTTP ${response.statusCode} - '
          '${text.length > 500 ? text.substring(0, 500) : text}',
        );
      }

      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name.toLowerCase()] = values.join(',');
      });
      return _HttpResponse(body: text, headers: responseHeaders);
    } finally {
      client.close(force: true);
    }
  }
}

class _HttpResponse {
  const _HttpResponse({required this.body, required this.headers});

  final String body;
  final Map<String, String> headers;
}
