import 'package:flutter_test/flutter_test.dart';
import 'package:istakip_app/services/personnel_pdf_service.dart';

void main() {
  group('PersonnelPdfService', () {
    test('formatRole returns correct Turkish labels', () {
      expect(PersonnelPdfService.formatRole('admin'), 'Yönetici');
      expect(PersonnelPdfService.formatRole('manager'), 'Müdür');
      expect(PersonnelPdfService.formatRole('stock_manager'), 'Stok Sorumlusu');
      expect(PersonnelPdfService.formatRole('technician'), 'Teknisyen');
      expect(PersonnelPdfService.formatRole('supervisor'), 'Süpervizör');
      expect(PersonnelPdfService.formatRole('custom_role'), 'custom_role');
      expect(PersonnelPdfService.formatRole(null), 'Personel');
    });
  });
}
