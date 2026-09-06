import 'package:flutter_test/flutter_test.dart';

import 'package:uzalteklif/services/quote_repository.dart';
import 'package:uzalteklif/models/quote.dart';
import 'package:uzalteklif/models/cari_account.dart';
import 'package:uzalteklif/services/quote_code_generator.dart';

void main() {
  test('taslak açılması gönderim kaydı oluşturmaz', () async {
    final repository = QuoteRepository();
    await repository.markEmailDraftOpened('seed-001', 'musteri@example.com');
    final quote = (await repository.fetchQuotes()).firstWhere(
      (q) => q.id == 'seed-001',
    );

    expect(quote.emailDraftOpenedAt, isNotNull);
    expect(quote.emailDraftOpenedTo, 'musteri@example.com');
    expect(quote.emailSentAt, isNull);
  });

  test(
    'manuel gönderim teyidi kullanıcı, zaman, alıcı ve notu saklar',
    () async {
      final repository = QuoteRepository();
      await repository.markEmailSent(
        'seed-001',
        'musteri@example.com',
        sentBy: '00000000-0000-0000-0000-000000000001',
        sentByName: 'Test Kullanıcı',
        note: 'Telefonla teyit edildi',
      );
      final quote = (await repository.fetchQuotes()).firstWhere(
        (q) => q.id == 'seed-001',
      );

      expect(quote.emailSentAt, isNotNull);
      expect(quote.emailSentTo, 'musteri@example.com');
      expect(quote.emailSentBy, '00000000-0000-0000-0000-000000000001');
      expect(quote.emailSentByName, 'Test Kullanıcı');
      expect(quote.emailSentNote, 'Telefonla teyit edildi');
    },
  );

  test('json alanları geriye dönük uyumludur', () {
    final json = <String, dynamic>{
      'id': 'legacy',
      'code': 'Q-1',
      'created_at': DateTime.now().toIso8601String(),
      'items': <dynamic>[],
      'market_snapshot': <dynamic>[],
      'document_profile': <String, dynamic>{},
    };
    final quote = Quote.fromJson(json);
    expect(quote.emailSentAt, isNull);
    expect(quote.emailDraftOpenedAt, isNull);
    expect(quote.emailSentNote, isEmpty);
    expect(quote.hasVerifiedPublicLink, isFalse);
    expect(quote.publicShareSlug, 'Q-1');
  });

  test('yeni paylaşım tokenı dört karakterli değildir', () {
    expect(
      QuoteCodeGenerator.buildShareToken(),
      hasLength(greaterThanOrEqualTo(16)),
    );
  });

  test('arşivlenen cari aktif seçimden çıkar ve geri alınabilir', () {
    final cari = CariAccount(
      id: 'c1',
      companyName: 'Firma',
      contactName: '',
      contactTitle: '',
      phone: '',
      email: '',
      taxOffice: '',
      taxNumber: '',
      address: '',
      notes: '',
      updatedAt: DateTime.now(),
    );
    final archived = cari.copyWith(archivedAt: DateTime.now().toUtc());
    expect(archived.isActive, isFalse);
    expect(archived.copyWith(clearArchivedAt: true).isActive, isTrue);
  });

  test('teklif temel takip alanları JSON ile korunur', () {
    final json = <String, dynamic>{
      'id': 'q-core',
      'code': 'Q-CORE',
      'created_at': DateTime.now().toIso8601String(),
      'items': <dynamic>[],
      'market_snapshot': <dynamic>[],
      'document_profile': <String, dynamic>{},
      'owner_user_id': '00000000-0000-0000-0000-000000000001',
      'valid_until': '2026-12-31',
      'next_action_at': '2026-09-10T10:00:00Z',
      'expected_close_at': '2026-10-01',
      'loss_reason_code': 'price',
      'status_changed_at': '2026-09-01T10:00:00Z',
    };
    final quote = Quote.fromJson(json);
    expect(quote.ownerUserId, isNotNull);
    expect(quote.validUntil, isNotNull);
    expect(quote.nextActionAt, isNotNull);
    expect(quote.expectedCloseAt, isNotNull);
    expect(quote.lossReasonCode, 'price');
    expect(quote.statusChangedAt, isNotNull);
  });

  test('geçerlilik tarihi açık teklif kontrolünü belirler', () {
    final json = <String, dynamic>{
      'id': 'q-expiry',
      'code': 'Q-EXPIRY',
      'created_at': DateTime.now().toIso8601String(),
      'items': <dynamic>[],
      'market_snapshot': <dynamic>[],
      'document_profile': <String, dynamic>{},
      'valid_until': '2020-01-01',
      'status': 'sent',
    };
    final quote = Quote.fromJson(json);
    expect(quote.isExpired, isTrue);
    expect(quote.isOpen, isFalse);
    expect(QuoteLossReason.labels[QuoteLossReason.price], 'Fiyat');
  });
}
