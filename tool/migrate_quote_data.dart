import 'dart:convert';
import 'dart:io';

const _migrationId = 'quote-data-20260731-v1';

const _tables = <_TablePlan>[
  _TablePlan('products', conflict: 'id'),
  _TablePlan('customer_accounts', conflict: 'id'),
  _TablePlan('market_rates', conflict: 'code'),
  _TablePlan('own_companies', conflict: 'id'),
  _TablePlan('price_adjustment_rules', conflict: 'id'),
  _TablePlan('quotes', conflict: 'id'),
  _TablePlan('quote_line_items', conflict: 'id'),
  _TablePlan('quote_revisions', conflict: 'id'),
  _TablePlan('audit_logs', conflict: 'id'),
];

Future<void> main(List<String> arguments) async {
  final apply = arguments.contains('--apply');
  if (apply &&
      Platform.environment['MIGRATION_CONFIRM']?.trim() !=
          'MOVE_QUOTE_DATA_TO_SHARED_DB') {
    throw StateError(
      '--apply için MIGRATION_CONFIRM=MOVE_QUOTE_DATA_TO_SHARED_DB gerekli.',
    );
  }

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
  final sourceRows = <String, List<Map<String, dynamic>>>{};

  stdout.writeln(
    apply ? 'TEKLİF VERİ AKTARIMI BAŞLIYOR' : 'TEKLİF VERİ AKTARIM DRY-RUN',
  );

  for (final plan in _tables) {
    final rows = await sourceApi.selectAll(plan.table, allowMissing: true);
    sourceRows[plan.table] = rows;
    final targetCount = await targetApi.tableCount(plan.table);
    if (targetCount == null) {
      throw StateError(
        'Hedefte ${plan.table} tablosu yok. Önce şema migration çalışmalı.',
      );
    }
    stdout.writeln(
      '${plan.table.padRight(28)} kaynak=${rows.length}, hedef=$targetCount',
    );
  }

  final sourceImages = await sourceApi.listStorageObjects('product-images');
  final targetImages = await targetApi.listStorageObjects('product-images');
  stdout.writeln(
    'product-images'.padRight(28) +
        ' kaynak=${sourceImages.length}, hedef=${targetImages.length}',
  );

  if (!apply) {
    stdout.writeln('DRY-RUN TAMAMLANDI — VERİ YAZILMADI');
    return;
  }

  final existingRun = await targetApi.selectOne(
    'quote_data_migration_runs',
    filters: {'migration_id': 'eq.$_migrationId'},
  );
  if (existingRun == null) {
    final populatedTables = <String>[];
    for (final plan in _tables) {
      final count = await targetApi.tableCount(plan.table) ?? 0;
      if (count > 0) populatedTables.add('${plan.table}=$count');
    }
    if (populatedTables.isNotEmpty || targetImages.isNotEmpty) {
      throw StateError(
        'Hedefte migration kaydı olmadan veri bulundu: '
        '${populatedTables.join(', ')}'
        '${targetImages.isNotEmpty ? ', product-images=${targetImages.length}' : ''}. '
        'İşlem durduruldu.',
      );
    }
    await targetApi.upsert('quote_data_migration_runs', [
      {
        'migration_id': _migrationId,
        'status': 'running',
        'source_counts': {
          for (final entry in sourceRows.entries) entry.key: entry.value.length,
          'product_images': sourceImages.length,
        },
        'started_at': DateTime.now().toUtc().toIso8601String(),
      },
    ], conflict: 'migration_id');
  } else {
    final status = existingRun['status']?.toString() ?? '';
    if (status == 'completed') {
      stdout.writeln('Migration daha önce tamamlanmış; yalnızca doğrulanacak.');
      await _verify(sourceRows, sourceImages.length, targetApi);
      return;
    }
    stdout.writeln('Yarım kalan migration güvenli biçimde devam ettiriliyor.');
  }

  try {
    for (final plan in _tables.where((item) => item.table != 'audit_logs')) {
      final transformed = sourceRows[plan.table]!
          .map(
            (row) => _transformRow(
              table: plan.table,
              row: row,
              sourceUrl: source.url,
              targetUrl: target.url,
            ),
          )
          .toList(growable: false);
      final currentCount = await targetApi.tableCount(plan.table) ?? 0;
      if (currentCount == transformed.length) {
        stdout.writeln(
          '${plan.table}: $currentCount kayıt zaten doğrulanmış, atlandı.',
        );
        continue;
      }
      if (plan.table == 'quote_line_items' || plan.table == 'quote_revisions') {
        await targetApi.deleteAll(plan.table);
        stdout.writeln(
          '${plan.table}: trigger kaynaklı geçici kayıtlar temizlendi.',
        );
      }
      await targetApi.upsertBatches(
        plan.table,
        transformed,
        conflict: plan.conflict,
      );
      stdout.writeln('${plan.table}: ${transformed.length} kayıt aktarıldı.');
    }

    // Normal tablo insert trigger'larının ürettiği geçici loglar temizlenir;
    // hedef yeni ve henüz uygulamaya açılmadığı için yalnızca bu migration'ın
    // ürettiği kayıtlar bulunur. Ardından kaynak geçmişi birebir yüklenir.
    final auditRows = sourceRows['audit_logs']!
        .map(
          (row) => _transformRow(
            table: 'audit_logs',
            row: row,
            sourceUrl: source.url,
            targetUrl: target.url,
          ),
        )
        .toList(growable: false);
    final currentAuditCount = await targetApi.tableCount('audit_logs') ?? 0;
    if (currentAuditCount == auditRows.length) {
      stdout.writeln(
        'audit_logs: $currentAuditCount kayıt zaten doğrulanmış, atlandı.',
      );
    } else {
      await targetApi.deleteAll('audit_logs');
      await targetApi.upsertBatches('audit_logs', auditRows, conflict: 'id');
      stdout.writeln('audit_logs: ${auditRows.length} kayıt aktarıldı.');
    }

    final existingTargetImages =
        (await targetApi.listStorageObjects('product-images')).toSet();
    for (final objectName in sourceImages) {
      if (existingTargetImages.contains(objectName)) {
        stdout.writeln('Görsel zaten mevcut, atlandı: $objectName');
        continue;
      }
      final object = await sourceApi.downloadStorageObject(
        'product-images',
        objectName,
      );
      await targetApi.uploadStorageObject(
        'product-images',
        objectName,
        object.bytes,
        contentType: object.contentType,
      );
      stdout.writeln('Görsel aktarıldı: $objectName');
    }

    await _verify(sourceRows, sourceImages.length, targetApi);
    await targetApi.upsert('quote_data_migration_runs', [
      {
        'migration_id': _migrationId,
        'status': 'completed',
        'source_counts': {
          for (final entry in sourceRows.entries) entry.key: entry.value.length,
          'product_images': sourceImages.length,
        },
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'error_message': '',
      },
    ], conflict: 'migration_id');
    stdout.writeln('TEKLİF VERİ AKTARIMI VE DOĞRULAMA TAMAMLANDI');
  } catch (error) {
    await targetApi.upsert('quote_data_migration_runs', [
      {
        'migration_id': _migrationId,
        'status': 'failed',
        'error_message': error.toString().substring(
          0,
          error.toString().length.clamp(0, 1000),
        ),
      },
    ], conflict: 'migration_id');
    rethrow;
  }
}

Future<void> _verify(
  Map<String, List<Map<String, dynamic>>> sourceRows,
  int sourceImageCount,
  _SupabaseAdminApi targetApi,
) async {
  final mismatches = <String>[];
  for (final plan in _tables) {
    final expected = sourceRows[plan.table]!.length;
    final actual = await targetApi.tableCount(plan.table);
    if (actual != expected) {
      mismatches.add('${plan.table}: beklenen=$expected, hedef=$actual');
    }
  }
  final actualImages =
      (await targetApi.listStorageObjects('product-images')).length;
  if (actualImages != sourceImageCount) {
    mismatches.add(
      'product-images: beklenen=$sourceImageCount, hedef=$actualImages',
    );
  }
  if (mismatches.isNotEmpty) {
    throw StateError('Doğrulama başarısız: ${mismatches.join('; ')}');
  }
}

Map<String, dynamic> _transformRow({
  required String table,
  required Map<String, dynamic> row,
  required String sourceUrl,
  required String targetUrl,
}) {
  final result = Map<String, dynamic>.from(row);
  switch (table) {
    case 'products':
      final imagePath = result['image_path']?.toString() ?? '';
      if (imagePath.startsWith(sourceUrl)) {
        result['image_path'] =
            targetUrl + imagePath.substring(sourceUrl.length);
      }
    case 'customer_accounts':
      result['created_by'] = null;
    case 'quotes':
      result['created_by'] = null;
      result['approved_by'] = null;
      result['accepted_by'] = null;
    case 'quote_revisions':
      result['changed_by'] = null;
    case 'audit_logs':
      result['actor_id'] = null;
  }
  return result;
}

class _TablePlan {
  const _TablePlan(this.table, {required this.conflict});

  final String table;
  final String conflict;
}

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

  Future<List<Map<String, dynamic>>> selectAll(
    String table, {
    bool allowMissing = false,
  }) async {
    const pageSize = 500;
    final result = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += pageSize) {
      final response = await _request(
        'GET',
        '/rest/v1/$table?select=*&limit=$pageSize&offset=$offset',
        allowMissing: allowMissing,
      );
      if (response == null) return const [];
      final decoded = jsonDecode(utf8.decode(response.bytes));
      if (decoded is! List) {
        throw FormatException('${config.label}: $table yanıtı geçersiz.');
      }
      final rows = decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      result.addAll(rows);
      if (rows.length < pageSize) break;
    }
    return result;
  }

  Future<Map<String, dynamic>?> selectOne(
    String table, {
    required Map<String, String> filters,
  }) async {
    final query = filters.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}='
              '${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    final response = await _request(
      'GET',
      '/rest/v1/$table?select=*&$query&limit=1',
    );
    final decoded = jsonDecode(utf8.decode(response!.bytes));
    if (decoded is! List || decoded.isEmpty) return null;
    return Map<String, dynamic>.from(decoded.first as Map);
  }

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
    if (separator < 0) return null;
    return int.parse(contentRange.substring(separator + 1));
  }

  Future<void> upsertBatches(
    String table,
    List<Map<String, dynamic>> rows, {
    required String conflict,
  }) async {
    const batchSize = 100;
    for (var offset = 0; offset < rows.length; offset += batchSize) {
      final end = (offset + batchSize).clamp(0, rows.length);
      await upsert(table, rows.sublist(offset, end), conflict: conflict);
    }
  }

  Future<void> upsert(
    String table,
    List<Map<String, dynamic>> rows, {
    required String conflict,
  }) async {
    if (rows.isEmpty) return;
    await _request(
      'POST',
      '/rest/v1/$table?on_conflict=${Uri.encodeQueryComponent(conflict)}',
      body: jsonEncode(rows),
      headers: const {'Prefer': 'resolution=merge-duplicates,return=minimal'},
    );
  }

  Future<void> deleteAll(String table) async {
    await _request(
      'DELETE',
      '/rest/v1/$table?id=not.is.null',
      headers: const {'Prefer': 'return=minimal'},
    );
  }

  Future<List<String>> listStorageObjects(String bucket) async {
    final result = <String>[];
    const pageSize = 1000;
    for (var offset = 0; ; offset += pageSize) {
      final response = await _request(
        'POST',
        '/storage/v1/object/list/$bucket',
        body: jsonEncode({
          'prefix': '',
          'limit': pageSize,
          'offset': offset,
          'sortBy': {'column': 'name', 'order': 'asc'},
        }),
      );
      final decoded = jsonDecode(utf8.decode(response!.bytes));
      if (decoded is! List) {
        throw FormatException('${config.label}: Storage yanıtı geçersiz.');
      }
      for (final item in decoded.whereType<Map>()) {
        final name = item['name']?.toString() ?? '';
        if (name.isNotEmpty && item['id'] != null) result.add(name);
      }
      if (decoded.length < pageSize) break;
    }
    return result;
  }

  Future<_StorageObject> downloadStorageObject(
    String bucket,
    String objectName,
  ) async {
    final encodedName = objectName
        .split('/')
        .map(Uri.encodeComponent)
        .join('/');
    final response = await _request(
      'GET',
      '/storage/v1/object/authenticated/$bucket/$encodedName',
    );
    return _StorageObject(
      bytes: response!.bytes,
      contentType:
          response.headers['content-type'] ?? 'application/octet-stream',
    );
  }

  Future<void> uploadStorageObject(
    String bucket,
    String objectName,
    List<int> bytes, {
    required String contentType,
  }) async {
    final encodedName = objectName
        .split('/')
        .map(Uri.encodeComponent)
        .join('/');
    await _request(
      'POST',
      '/storage/v1/object/$bucket/$encodedName',
      bodyBytes: bytes,
      headers: {'Content-Type': contentType, 'x-upsert': 'true'},
    );
  }

  Future<_HttpResponse?> _request(
    String method,
    String path, {
    Map<String, String> headers = const {},
    String? body,
    List<int>? bodyBytes,
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
        request.write(body);
      } else if (bodyBytes != null) {
        request.add(bodyBytes);
      }

      final response = await request.close();
      final bytes = await response.fold<List<int>>(
        <int>[],
        (buffer, chunk) => buffer..addAll(chunk),
      );
      final responseText = utf8.decode(bytes, allowMalformed: true);
      if (allowMissing &&
          (response.statusCode == HttpStatus.notFound ||
              response.statusCode == HttpStatus.badRequest) &&
          (responseText.contains('PGRST205') ||
              responseText.contains('does not exist') ||
              responseText.contains('not found'))) {
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          '${config.label}: HTTP ${response.statusCode} - '
          '${responseText.length > 500 ? responseText.substring(0, 500) : responseText}',
        );
      }

      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name.toLowerCase()] = values.join(',');
      });
      return _HttpResponse(bytes: bytes, headers: responseHeaders);
    } finally {
      client.close(force: true);
    }
  }
}

class _HttpResponse {
  const _HttpResponse({required this.bytes, required this.headers});

  final List<int> bytes;
  final Map<String, String> headers;
}

class _StorageObject {
  const _StorageObject({required this.bytes, required this.contentType});

  final List<int> bytes;
  final String contentType;
}
