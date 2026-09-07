import 'package:flutter_test/flutter_test.dart';

import 'package:uzalteklif/screens/quote_editor_page.dart';

void main() {
  group('quoteNoteForSource', () {
    test('AUTOSAVE notu oldugu gibi birakir', () {
      // Autosave kalici bir kayit yolu. Etiket eklenirse teklifin notuna
      // yazilir, teklif tekrar acildiginda nota geri yuklenir ve 12 saniyede
      // bir yenisi eklenerek not sinirsiz buyur.
      expect(
        quoteNoteForSource('Kullanici notu', 'AUTOSAVE'),
        'Kullanici notu',
      );
    });

    test('ARSIV notu oldugu gibi birakir', () {
      expect(quoteNoteForSource('Kullanici notu', 'ARSIV'), 'Kullanici notu');
    });

    test('PDF ciktisina cikti bicimi etiketi ekler', () {
      expect(
        quoteNoteForSource('Kullanici notu', 'PDF'),
        'Kullanici notu\nCikti bicimi: PDF',
      );
    });

    test('EXCEL ciktisina cikti bicimi etiketi ekler', () {
      expect(
        quoteNoteForSource('Kullanici notu', 'EXCEL'),
        'Kullanici notu\nCikti bicimi: EXCEL',
      );
    });

    test('art arda AUTOSAVE cagrilari notu buyutmez', () {
      var note = 'Kullanici notu';
      for (var i = 0; i < 5; i++) {
        note = quoteNoteForSource(note, 'AUTOSAVE');
      }
      expect(note, 'Kullanici notu');
    });
  });
}
