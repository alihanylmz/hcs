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
}
