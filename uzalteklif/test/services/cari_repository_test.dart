import 'package:flutter_test/flutter_test.dart';

import 'package:uzalteklif/models/cari_account.dart';
import 'package:uzalteklif/services/cari_repository.dart';

void main() {
  group('CariRepository.findByCompanyName', () {
    final testCariler = [
      const CariAccount(
        id: 'cari-1',
        companyName: 'UZAL TEKNIK',
        contactName: 'Ali',
        contactTitle: '',
        phone: '',
        email: '',
        taxOffice: '',
        taxNumber: '',
        address: '',
        notes: '',
        contacts: [],
      ),
      const CariAccount(
        id: 'cari-2',
        companyName: 'Enerji Sistemleri Ltd',
        contactName: 'Fatih',
        contactTitle: '',
        phone: '',
        email: '',
        taxOffice: '',
        taxNumber: '',
        address: '',
        notes: '',
        contacts: [],
      ),
      const CariAccount(
        id: 'cari-3',
        companyName: 'Kontrol Teknolojileri',
        contactName: 'Nur',
        contactTitle: '',
        phone: '',
        email: '',
        taxOffice: '',
        taxNumber: '',
        address: '',
        notes: '',
        contacts: [],
      ),
    ];

    test('Tam eşleşme bulur (büyük/küçük harfe duyarsız)', () {
      final result = CariRepository.findByCompanyName(testCariler, 'uzal teknik');
      expect(result, isNotNull);
      expect(result?.id, 'cari-1');
    });

    test('Boşluk göz ardı ederek eşleşme bulur', () {
      final result =
          CariRepository.findByCompanyName(testCariler, '  UZAL TEKNIK  ');
      expect(result, isNotNull);
      expect(result?.id, 'cari-1');
    });

    test('Eşleşme yoksa null döndürür', () {
      final result = CariRepository.findByCompanyName(testCariler, 'Bilinmeyen Firma');
      expect(result, isNull);
    });

    test('Boş string için null döndürür', () {
      final result = CariRepository.findByCompanyName(testCariler, '');
      expect(result, isNull);
    });

    test('Sadece boşluk içeren string için null döndürür', () {
      final result = CariRepository.findByCompanyName(testCariler, '   ');
      expect(result, isNull);
    });

    test('Boş liste için null döndürür', () {
      final result = CariRepository.findByCompanyName(const [], 'UZAL TEKNIK');
      expect(result, isNull);
    });
  });
}
