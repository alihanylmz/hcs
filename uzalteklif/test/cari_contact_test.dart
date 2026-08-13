import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/cari_account.dart';

void main() {
  group('CariContact and CariAccount Tests', () {
    test('CariAccount serialization with multiple contacts', () {
      final json = {
        'id': 'cari-101',
        'company_name': 'Aşortsan Tekstil A.Ş.',
        'contact_name': 'Ahmet Yılmaz',
        'contact_title': 'Satın Alma Müdürü',
        'phone': '05551112233',
        'email': 'ahmet@asortsan.com',
        'tax_office': 'Kadıköy',
        'tax_number': '1234567890',
        'address': 'İstanbul',
        'notes': 'Önemli müşteri',
        'updated_at': '2026-08-07T12:00:00.000Z',
        'contacts': [
          {
            'name': 'Ahmet Yılmaz',
            'title': 'Satın Alma Müdürü',
            'phone': '05551112233',
            'email': 'ahmet@asortsan.com',
            'is_primary': true,
          },
          {
            'name': 'Mehmet Öz',
            'title': 'Teknik Müdür',
            'phone': '05559998877',
            'email': 'mehmet@asortsan.com',
            'is_primary': false,
          },
        ],
      };

      final cari = CariAccount.fromJson(json);

      expect(cari.id, equals('cari-101'));
      expect(cari.companyName, equals('Aşortsan Tekstil A.Ş.'));
      expect(cari.contacts.length, equals(2));
      expect(cari.primaryContact?.name, equals('Ahmet Yılmaz'));
      expect(cari.hasContact('Mehmet Öz'), isTrue);
      expect(cari.hasContact('AHMET YILMAZ'), isTrue);
      expect(cari.hasContact('Bilinmeyen Kişi'), isFalse);

      final exportedJson = cari.toJson();
      expect(exportedJson['contacts'], isA<List>());
      expect((exportedJson['contacts'] as List).length, equals(2));
    });

    test('Legacy CariAccount fallback to primary contact when contacts field is empty', () {
      final json = {
        'id': 'cari-102',
        'company_name': 'Uzal Otomasyon',
        'contact_name': 'Ali Can',
        'contact_title': 'Genel Müdür',
        'phone': '02123332211',
        'email': 'ali@uzal.com',
        'tax_office': 'Maslak',
        'tax_number': '9876543210',
        'address': 'İstanbul',
        'notes': '',
        'updated_at': '2026-08-07T12:00:00.000Z',
      };

      final cari = CariAccount.fromJson(json);

      expect(cari.contacts.length, equals(1));
      expect(cari.contacts.first.name, equals('Ali Can'));
      expect(cari.contacts.first.isPrimary, isTrue);
      expect(cari.primaryContact?.name, equals('Ali Can'));
    });
  });
}
