import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/services/product_csv_service.dart';

void main() {
  const service = ProductCsvService();

  test('Honeywell sekmeli fiyat listesini başlıksız içe aktarır', () {
    const content =
        'Controller Accessories\t10BASE-T1L-ADAPT-0\t'
        'IP - T1L MEDIA ADAPTER (NO POWER SUPPLY)\t USD \t'
        r' $287,00 '
        '\t Honeywell \tActive\n'
        'Niagara Edge\tCLNX-1N-SMA-1Y\tSUPPORT 1 YEAR\t USD \t'
        r' $10.300,25 '
        '\t Honeywell \t#YOK';

    final result = service.parseContent(content, existingProducts: const []);

    expect(result.skippedRows, 0);
    expect(result.products, hasLength(2));
    expect(result.products.first.code, '10BASE-T1L-ADAPT-0');
    expect(result.products.first.category, 'Controller Accessories');
    expect(result.products.first.brand, 'Honeywell');
    expect(result.products.first.currencyCode, 'USDTRY');
    expect(result.products.first.salePrice, 287);
    expect(result.products.first.isActive, isTrue);
    expect(result.products.last.salePrice, 10300.25);
    expect(result.products.last.isActive, isFalse);
  });

  test('standart başlıklı CSV biçimini okumaya devam eder', () {
    const content =
        'code,name,category,brand,currency_code,sale_price,is_active\n'
        'ABC-1,"Test, ürün",Sensör,Honeywell,EUR,"1.250,50",true\n';

    final result = service.parseContent(content, existingProducts: const []);

    expect(result.skippedRows, 0);
    expect(result.products, hasLength(1));
    expect(result.products.single.name, 'Test, ürün');
    expect(result.products.single.currencyCode, 'EURTRY');
    expect(result.products.single.salePrice, 1250.50);
  });

  test('9 kolonlu detaylı Honeywell listesini doğru alanlara eşler', () {
    const content =
        'Common\tThermostats\tElectronic Thermostats\tTB3026B\t'
        'BACNET FIXED FUNCTION THERMOSTAT\t USD \t'
        r' $520,00 '
        '\t Active \t MX \n'
        'Field Devices\tSensors and Wall Modules\tModule with Setpoint\t'
        'TR100-T-G\tCommercial Wall Module, T\t USD \t'
        r' $250,44 '
        '\t Phase Out Inprogress \t US ';

    final result = service.parseContent(content, existingProducts: const []);

    expect(result.skippedRows, 0);
    expect(result.products, hasLength(2));
    expect(result.products.first.code, 'TB3026B');
    expect(result.products.first.name, 'BACNET FIXED FUNCTION THERMOSTAT');
    expect(result.products.first.category, 'Thermostats');
    expect(result.products.first.brand, 'Honeywell');
    expect(result.products.first.salePrice, 520);
    expect(result.products.first.isActive, isTrue);
    expect(result.products.first.specifications['supplier_group'], 'Common');
    expect(
      result.products.first.specifications['supplier_subcategory'],
      'Electronic Thermostats',
    );
    expect(result.products.first.specifications['origin_country'], 'MX');
    expect(result.products.last.code, 'TR100-T-G');
    expect(result.products.last.isActive, isFalse);
  });

  test('detaylı listede tekrarlanan ürün kodunun son satırını kullanır', () {
    const content =
        'Common\tThermostats\tElectronic\tTB3026B\tFirst\tUSD\t'
        r'$500,00'
        '\tActive\tMX\n'
        'Common\tThermostats\tElectronic\tTB3026B\tUpdated\tUSD\t'
        r'$520,00'
        '\tActive\tMX';

    final result = service.parseContent(content, existingProducts: const []);

    expect(result.products, hasLength(1));
    expect(result.products.single.name, 'Updated');
    expect(result.products.single.salePrice, 520);
  });
}
