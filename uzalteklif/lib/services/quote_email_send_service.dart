import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// `send-quote-email` Supabase Edge Function'ini cagirarak teklif e-postasini
/// teklif@uzalteknik.com adresinden gercekten gonderir.
///
/// [OutlookAttachmentEmailService] yalnizca Windows'ta yerel Outlook'u acip
/// taslak dolduruyordu (kullanicinin kendisi "Gonder"e basmasi gerekiyordu).
/// Bu servis onun yerine gecebilecek, platform bagimsiz gercek gonderimdir.
class QuoteEmailSendService {
  QuoteEmailSendService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isSupported =>
      _client != null && _client.auth.currentSession != null;

  Future<void> send({
    required String to,
    String cc = '',
    required String subject,
    required String body,
    List<int>? attachmentBytes,
    String attachmentFilename = 'teklif.pdf',
  }) async {
    if (!isSupported) {
      throw StateError(
        'Gercek e-posta gonderimi icin oturum acmis olmaniz gerekiyor.',
      );
    }
    final response = await _client!.functions.invoke(
      'send-quote-email',
      body: {
        'to': to,
        if (cc.trim().isNotEmpty) 'cc': cc.trim(),
        'subject': subject,
        'body': body,
        if (attachmentBytes != null)
          'attachmentBase64': base64Encode(attachmentBytes),
        'attachmentFilename': attachmentFilename,
      },
    );

    final data = response.data;
    if (response.status != 200) {
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'Sunucu e-postayi gonderemedi (HTTP ${response.status}).';
      throw StateError(message);
    }
  }
}
