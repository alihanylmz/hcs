import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzalteklif/models/product.dart';
import 'package:uzalteklif/screens/control_hardware_library_page.dart';
import 'package:uzalteklif/services/control_hardware_repository.dart';
import 'package:uzalteklif/services/product_repository.dart';
import 'package:uzalteklif/theme/app_theme.dart';

void main() {
  testWidgets('DDC/I/O kütüphanesi başlangıç kontrolörlerini gösterir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ControlHardwareLibraryPage(
          repository: ControlHardwareRepository(),
          productRepository: _FakeProductRepository(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DDC ve I/O Kütüphanesi'), findsOneWidget);
    expect(find.text('ABB FBXi 8R8'), findsOneWidget);
    expect(find.text('Honeywell Unitary 16'), findsOneWidget);
    expect(find.text('AI-A 4–20 mA desteklenmez'), findsOneWidget);
    expect(find.text('Kontrolör Ekle'), findsOneWidget);
    expect(find.text('I/O Modülü Ekle'), findsOneWidget);
  });

  testWidgets(
    'tüm ürünlerde arama sıfır stoklu katalog ürünlerini de gösterir',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ControlHardwareLibraryPage(
            repository: ControlHardwareRepository(),
            productRepository: _FakeProductRepository([
              _product(
                id: 'stocked-controller',
                code: 'CTRL-1',
                name: 'Stoklu Kontrolör',
                category: 'Kontrolörler',
                stockQuantity: 2,
              ),
              _product(
                id: 'zero-controller',
                code: 'CTRL-2',
                name: 'Sıfır Stoklu Kontrolör',
                category: 'Kontrolörler',
                stockQuantity: 0,
              ),
              _product(
                id: 'zero-sensor',
                code: 'SNS-1',
                name: 'Sıfır Stoklu Sensör',
                category: 'Sensörler',
                stockQuantity: 0,
              ),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kontrolör Ekle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stoktan ürün bağla'));
      await tester.pumpAndSettle();

      expect(find.textContaining('CTRL-2'), findsNWidgets(2));
      expect(find.textContaining('SNS-1'), findsNothing);

      await tester.tap(find.text('Tüm Ürünlerde Ara'));
      await tester.pumpAndSettle();

      expect(find.text('3 ürün · filtre dışı arama açık'), findsOneWidget);
      expect(find.textContaining('CTRL-2'), findsNWidgets(2));
      expect(find.textContaining('SNS-1'), findsNWidgets(2));
    },
  );

  testWidgets('boş ilk yüklemeden sonra stok butonu ürünleri yeniden alır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _RetryProductRepository([
      _product(
        id: 'retry-controller',
        code: 'CTRL-RETRY',
        name: 'Yeniden Yüklenen Kontrolör',
        category: 'Kontrolörler',
        stockQuantity: 0,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ControlHardwareLibraryPage(
          repository: ControlHardwareRepository(),
          productRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kontrolör Ekle'));
    await tester.pumpAndSettle();
    final stockButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Stoktan ürün bağla'),
    );
    expect(stockButton.onPressed, isNotNull);

    await tester.tap(find.text('Stoktan ürün bağla'));
    await tester.pumpAndSettle();

    expect(repository.fetchCount, 2);
    expect(find.text('Stoktan cihaz seç'), findsOneWidget);
    expect(find.textContaining('CTRL-RETRY'), findsNWidgets(2));
  });
}

class _FakeProductRepository extends ProductRepository {
  _FakeProductRepository(this.products);

  final List<Product> products;

  @override
  Future<List<Product>> fetchProducts() async => products;
}

class _RetryProductRepository extends ProductRepository {
  _RetryProductRepository(this.products);

  final List<Product> products;
  int fetchCount = 0;

  @override
  Future<List<Product>> fetchProducts() async {
    fetchCount += 1;
    return fetchCount == 1 ? const [] : products;
  }
}

Product _product({
  required String id,
  required String code,
  required String name,
  required String category,
  required double stockQuantity,
}) {
  return Product(
    id: id,
    code: code,
    name: name,
    category: category,
    brand: 'Test',
    model: code,
    unit: 'adet',
    currencyCode: 'TRY',
    salePrice: 100,
    stockQuantity: stockQuantity,
    minimumStock: 0,
    vatRate: 20,
    leadTime: '',
    description: '',
    technicalSummary: '',
    isActive: true,
    updatedAt: DateTime(2026),
  );
}
