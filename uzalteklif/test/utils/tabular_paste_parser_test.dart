import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/utils/tabular_paste_parser.dart';

void main() {
  group('parseNumber', () {
    test('Turkce bicim: nokta binlik, virgul ondalik', () {
      expect(TabularPasteParser.parseNumber('1.234,56'), 1234.56);
      expect(TabularPasteParser.parseNumber('12,5'), 12.5);
      expect(TabularPasteParser.parseNumber('1.234.567,89'), 1234567.89);
    });

    test('Ingilizce bicim: virgul binlik, nokta ondalik', () {
      expect(TabularPasteParser.parseNumber('1,234.56'), 1234.56);
      expect(TabularPasteParser.parseNumber('12.5'), 12.5);
      expect(TabularPasteParser.parseNumber('1,234,567.89'), 1234567.89);
    });

    test('tek ayirici + uc hane binlik sayilir', () {
      // Ondalik okunsaydi fiyat 1000 kat yanlis cikardi.
      expect(TabularPasteParser.parseNumber('1.234'), 1234);
      expect(TabularPasteParser.parseNumber('1,234'), 1234);
    });

    test('tek ayirici + uc haneden farkli grup ondalik sayilir', () {
      expect(TabularPasteParser.parseNumber('12,50'), 12.5);
      expect(TabularPasteParser.parseNumber('0,5'), 0.5);
      expect(TabularPasteParser.parseNumber('3.1416'), 3.1416);
    });

    test('ayirici yoksa oldugu gibi okunur', () {
      expect(TabularPasteParser.parseNumber('42'), 42);
      expect(TabularPasteParser.parseNumber('-7'), -7);
    });

    test('para simgesi, bosluk ve yuzde temizlenir', () {
      expect(TabularPasteParser.parseNumber('  1.234,56 TL '), 1234.56);
      expect(TabularPasteParser.parseNumber('%15'), 15);
      expect(TabularPasteParser.parseNumber(r'$ 99.90'), 99.90);
    });

    test('sayi olmayan girdi null doner', () {
      expect(TabularPasteParser.parseNumber(''), isNull);
      expect(TabularPasteParser.parseNumber('adet'), isNull);
      expect(TabularPasteParser.parseNumber('-'), isNull);
    });
  });

  group('parse', () {
    test('sekme ile ayrilmis Excel kopyasini okur', () {
      const text =
          'Kablo kanali\t10\tmetre\t125,50\t5\n'
          'Pano montaji\t2\tadet\t1.500,00\t0';
      final rows = TabularPasteParser.parse(text);

      expect(rows, hasLength(2));
      expect(rows[0].description, 'Kablo kanali');
      expect(rows[0].quantity, 10);
      expect(rows[0].unit, 'metre');
      expect(rows[0].unitPrice, 125.50);
      expect(rows[0].discount, 5);
      expect(rows[1].unitPrice, 1500.00);
    });

    test('noktali virgullu CSV de okunur', () {
      const text = 'Sensor;3;adet;250,00;10';
      final rows = TabularPasteParser.parse(text);
      expect(rows, hasLength(1));
      expect(rows[0].quantity, 3);
      expect(rows[0].unitPrice, 250);
    });

    test('virgul ayirici sayilmaz; ondalik olarak korunur', () {
      // Virgulu ayirici kabul etseydik "12,5" iki hucreye bolunur, miktar 12
      // ve birim "5" olurdu.
      const text = 'Tek sutunlu kalem\t12,5';
      final rows = TabularPasteParser.parse(text);
      expect(rows, hasLength(1));
      expect(rows[0].quantity, 12.5);
    });

    test('eksik sutunlar varsayilanla dolar', () {
      const text = 'Sadece aciklama';
      final rows = TabularPasteParser.parse(text);
      expect(rows, hasLength(1));
      expect(rows[0].quantity, 1);
      expect(rows[0].unit, 'adet');
      expect(rows[0].unitPrice, 0);
      expect(rows[0].discount, 0);
    });

    test('bos satirlar ve aciklamasiz satirlar atlanir', () {
      const text = 'Ilk kalem\t1\n\n\t5\tadet\nIkinci kalem\t2';
      final rows = TabularPasteParser.parse(text);
      expect(rows, hasLength(2));
      expect(rows[0].description, 'Ilk kalem');
      expect(rows[1].description, 'Ikinci kalem');
    });

    test('skipHeader ilk satiri atlar', () {
      const text = 'Aciklama\tMiktar\nGercek kalem\t3';
      final rows = TabularPasteParser.parse(text, skipHeader: true);
      expect(rows, hasLength(1));
      expect(rows[0].description, 'Gercek kalem');
    });

    test('bos metin bos liste verir', () {
      expect(TabularPasteParser.parse(''), isEmpty);
      expect(TabularPasteParser.parse('   \n  '), isEmpty);
    });
  });

  group('looksLikeHeader', () {
    test('ikinci hucre sayi degilse baslik sayilir', () {
      expect(TabularPasteParser.looksLikeHeader('Aciklama\tMiktar'), isTrue);
    });

    test('ikinci hucre sayiysa veri sayilir', () {
      expect(TabularPasteParser.looksLikeHeader('Kablo\t10'), isFalse);
    });

    test('tek sutunlu metinde baslik varsayilmaz', () {
      expect(TabularPasteParser.looksLikeHeader('Sadece aciklama'), isFalse);
    });
  });
}
