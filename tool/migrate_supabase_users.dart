import 'dart:convert';
import 'dart:io';

const _settingsFields = <String>[
  'prepared_by_title',
  'prepared_by_phone',
  'prepared_by_email',
  'company_name',
  'company_tagline',
  'company_phone',
  'company_email',
  'company_website',
  'company_address',
  'company_tax_office',
  'company_tax_number',
  'company_mersis',
  'bank_name',
  'bank_branch',
  'bank_account_name',
  'bank_iban',
  'bank_swift',
  'default_validity_text',
  'default_payment_terms',
  'default_delivery_terms',
  'default_vat_rate',
];

Future<void> main(List<String> arguments) async {
  final apply = arguments.contains('--apply');
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
  if (apply &&
      Platform.environment['MIGRATION_CONFIRM']?.trim() != 'USERS_ONLY') {
    throw StateError(
      '--apply için MIGRATION_CONFIRM=USERS_ONLY ayarlanmalıdır.',
    );
  }

  final sourceApi = _SupabaseAdminApi(source);
  final targetApi = _SupabaseAdminApi(target);
  final sourceUsers = await sourceApi.listAuthUsers();
  final targetUsers = await targetApi.listAuthUsers();
  final sourceProfiles = await sourceApi.selectAll('user_profiles');
  final targetProfiles = await targetApi.selectAll('profiles');

  // Migration uygulanmadan veri yazılmasını önlemek için hedef şemayı doğrula.
  await targetApi.selectAll('user_app_access', limit: 1);
  await targetApi.selectAll('user_quote_settings', limit: 1);
  await targetApi.selectAll('auth_user_migration_map', limit: 1);

  final targetByEmail = <String, Map<String, dynamic>>{
    for (final user in targetUsers)
      if (_emailOf(user).isNotEmpty) _emailOf(user): user,
  };
  final sourceProfileById = <String, Map<String, dynamic>>{
    for (final profile in sourceProfiles)
      if ((profile['user_id'] as String? ?? '').isNotEmpty)
        profile['user_id'] as String: profile,
  };
  final targetProfileIds =
      targetProfiles
          .map((profile) => profile['id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

  var matched = 0;
  var invited = 0;
  var missingEmail = 0;
  var migrated = 0;

  for (final sourceUser in sourceUsers) {
    final sourceUserId = sourceUser['id'] as String? ?? '';
    final email = _emailOf(sourceUser);
    if (sourceUserId.isEmpty || email.isEmpty) {
      missingEmail++;
      continue;
    }
    final sourceProfile = sourceProfileById[sourceUserId];
    var targetUser = targetByEmail[email];
    if (targetUser != null) {
      matched++;
    } else if (!apply) {
      invited++;
      continue;
    } else {
      targetUser = await targetApi.inviteUser(
        email: email,
        fullName: _displayName(sourceUser, sourceProfile),
        redirectTo: Platform.environment['TARGET_INVITE_REDIRECT_URL'],
      );
      targetByEmail[email] = targetUser;
      invited++;
    }

    if (!apply) continue;
    final targetUserId = targetUser['id'] as String? ?? '';
    if (targetUserId.isEmpty) {
      throw StateError('Hedef kullanıcı kimliği oluşturulamadı.');
    }

    if (!targetProfileIds.contains(targetUserId)) {
      await targetApi.upsert('profiles', {
        'id': targetUserId,
        'email': email,
        'full_name': _displayName(sourceUser, sourceProfile),
        'role': 'pending',
      }, conflict: 'id');
      targetProfileIds.add(targetUserId);
    }

    final quoteRole = _quoteRole(sourceProfile?['role'] as String?);
    await targetApi.upsert('user_app_access', {
      'user_id': targetUserId,
      'app_code': 'teklif',
      'app_role': quoteRole,
      'is_active': true,
    }, conflict: 'user_id,app_code');

    if (sourceProfile != null) {
      final settings = <String, dynamic>{'user_id': targetUserId};
      for (final field in _settingsFields) {
        if (sourceProfile.containsKey(field)) {
          settings[field] = sourceProfile[field];
        }
      }
      await targetApi.upsert(
        'user_quote_settings',
        settings,
        conflict: 'user_id',
      );
    }

    await targetApi.upsert('auth_user_migration_map', {
      'source_system': 'teklif',
      'source_user_id': sourceUserId,
      'target_user_id': targetUserId,
      'email': email,
      'migration_status':
          targetUsers.any((user) => _emailOf(user) == email)
              ? 'matched'
              : 'invited',
      'migrated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflict: 'source_system,source_user_id');
    migrated++;
  }

  stdout.writeln('Kullanıcı taşıma raporu');
  stdout.writeln('Kaynak Auth kullanıcısı : ${sourceUsers.length}');
  stdout.writeln('Kaynak Teklif profili   : ${sourceProfiles.length}');
  stdout.writeln('Hedef Auth kullanıcısı  : ${targetUsers.length}');
  stdout.writeln('E-posta ile eşleşen     : $matched');
  stdout.writeln('Davet edilecek/edilen   : $invited');
  stdout.writeln('E-postası eksik         : $missingEmail');
  stdout.writeln('Taşınan                 : $migrated');
  stdout.writeln(apply ? 'Uygulama tamamlandı.' : 'DRY-RUN: Veri yazılmadı.');
}

String _emailOf(Map<String, dynamic> user) {
  return (user['email'] as String? ?? '').trim().toLowerCase();
}

String _displayName(Map<String, dynamic> user, Map<String, dynamic>? profile) {
  final prepared = (profile?['prepared_by_name'] as String? ?? '').trim();
  if (prepared.isNotEmpty) return prepared;
  final metadata = user['user_metadata'];
  if (metadata is Map) {
    final fullName = (metadata['full_name'] as String? ?? '').trim();
    if (fullName.isNotEmpty) return fullName;
    final name = (metadata['name'] as String? ?? '').trim();
    if (name.isNotEmpty) return name;
  }
  return (user['email'] as String? ?? '').trim();
}

String _quoteRole(String? raw) {
  switch ((raw ?? '').trim()) {
    case 'admin':
      return 'admin';
    case 'manager':
      return 'manager';
    case 'finance':
    case 'accountant':
      return 'finance';
    case 'operations':
      return 'operations';
    case 'viewer':
      return 'viewer';
    default:
      return 'sales';
  }
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

  Future<List<Map<String, dynamic>>> listAuthUsers() async {
    final result = <Map<String, dynamic>>[];
    const pageSize = 1000;
    for (var page = 1; ; page++) {
      final response = await _request(
        'GET',
        '/auth/v1/admin/users?page=$page&per_page=$pageSize',
      );
      final rawUsers = response is Map ? response['users'] : response;
      if (rawUsers is! List) {
        throw FormatException(
          '${config.label}: Auth kullanıcı yanıtı geçersiz.',
        );
      }
      final users = rawUsers
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      result.addAll(users);
      if (users.length < pageSize) break;
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> selectAll(
    String table, {
    int limit = 10000,
  }) async {
    final response = await _request(
      'GET',
      '/rest/v1/$table?select=*&limit=$limit',
    );
    if (response is! List) {
      throw FormatException('${config.label}: $table yanıtı geçersiz.');
    }
    return response
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> inviteUser({
    required String email,
    required String fullName,
    String? redirectTo,
  }) async {
    final query =
        redirectTo == null || redirectTo.trim().isEmpty
            ? ''
            : '?redirect_to=${Uri.encodeQueryComponent(redirectTo.trim())}';
    final response = await _request(
      'POST',
      '/auth/v1/invite$query',
      body: {
        'email': email,
        'data': {'full_name': fullName},
      },
    );
    if (response is! Map) {
      throw FormatException('${config.label}: Davet yanıtı geçersiz.');
    }
    return Map<String, dynamic>.from(response);
  }

  Future<void> upsert(
    String table,
    Map<String, dynamic> row, {
    required String conflict,
  }) async {
    await _request(
      'POST',
      '/rest/v1/$table?on_conflict=${Uri.encodeQueryComponent(conflict)}',
      body: row,
      prefer: 'resolution=merge-duplicates,return=minimal',
    );
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? prefer,
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
      if (prefer != null) request.headers.set('Prefer', prefer);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          '${config.label}: HTTP ${response.statusCode} - '
          '${text.length > 500 ? text.substring(0, 500) : text}',
        );
      }
      if (text.trim().isEmpty) return null;
      return jsonDecode(text);
    } finally {
      client.close(force: true);
    }
  }
}
