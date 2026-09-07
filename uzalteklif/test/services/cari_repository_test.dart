import 'package:flutter_test/flutter_test.dart';

import 'package:uzalteklif/models/cari_account.dart';
import 'package:uzalteklif/services/cari_repository.dart';

CariAccount _cari({required String id, required String companyName}) {
  return CariAccount(
    id: id,
    companyName: companyName,
    contactName: '',
    contactTitle: '',
    phone: '',
    email: '',
    taxOffice: '',
    taxNumber: '',
    address: '',
    notes: '',
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('CariRepository.findByCompanyName', () {
    final testCariler = [
      _cari(id: 'cari-1', companyName: 'UZAL TEKNIK'),
      _cari(id: 'cari-2', companyName: 'Enerji Sistemleri Ltd'),
      _cari(id: 'cari-3', companyName: 'Kontrol Teknolojileri'),
    ];

    test('Tam eslesme bulur (buyuk/kucuk harfe duyarsiz)', () {
      final result = CariRepository.findByCompanyName(
        testCariler,
        'uzal teknik',
      );
      expect(result, isNotNull);
      expect(result?.id, 'cari-1');
    });

    test('Bosluklari yok sayarak eslesme bulur', () {
      final result = CariRepository.findByCompanyName(
        testCariler,
        '  UZAL TEKNIK  ',
      );
      expect(result, isNotNull);
      expect(result?.id, 'cari-1');
    });

    test('Eslesme yoksa null dondurur', () {
      final result = CariRepository.findByCompanyName(
        testCariler,
        'Bilinmeyen Firma',
      );
      expect(result, isNull);
    });

    test('Bos string icin null dondurur', () {
      expect(CariRepository.findByCompanyName(testCariler, ''), isNull);
    });

    test('Sadece bosluk iceren string icin null dondurur', () {
      expect(CariRepository.findByCompanyName(testCariler, '   '), isNull);
    });

    test('Bos liste icin null dondurur', () {
      expect(CariRepository.findByCompanyName(const [], 'UZAL TEKNIK'), isNull);
    });
  });
}
