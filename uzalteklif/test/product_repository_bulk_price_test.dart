import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/product.dart';
import 'package:uzalteklif/services/product_repository.dart';

void main() {
  test('applyBulkPriceChange filters by brand category and query', () async {
    final repository = ProductRepository();
    final now = DateTime(2026, 9, 1, 12);

    final target = Product(
      id: 'bulk-test-1',
      code: 'BULK-ABB-PLC-1',
      name: 'ABB PLC Test Urunu',
      category: 'PLC',
      brand: 'ABB',
      model: 'P1',
      unit: 'adet',
      currencyCode: 'TL',
      salePrice: 1000,
      stockQuantity: 0,
      minimumStock: 0,
      vatRate: 20,
      leadTime: '',
      description: '',
      technicalSummary: '',
      isActive: true,
      updatedAt: now,
    );
    final sameCategoryOtherBrand = target.copyWith(
      id: 'bulk-test-2',
      code: 'BULK-SIEMENS-PLC-1',
      brand: 'Siemens',
      name: 'Siemens PLC Test Urunu',
    );
    final sameBrandOtherCategory = target.copyWith(
      id: 'bulk-test-3',
      code: 'BULK-ABB-HMI-1',
      category: 'HMI',
      name: 'ABB HMI Test Urunu',
    );

    await repository.saveProducts([
      target,
      sameCategoryOtherBrand,
      sameBrandOtherCategory,
    ]);

    final affected = await repository.applyBulkPriceChange(
      brand: 'ABB',
      category: 'PLC',
      query: 'BULK-ABB',
      percentage: 12,
    );

    final products = await repository.fetchProducts();
    final updatedTarget = products.firstWhere((p) => p.code == target.code);
    final untouchedBrand = products.firstWhere(
      (p) => p.code == sameCategoryOtherBrand.code,
    );
    final untouchedCategory = products.firstWhere(
      (p) => p.code == sameBrandOtherCategory.code,
    );

    expect(affected, 1);
    expect(updatedTarget.salePrice, 1120);
    expect(untouchedBrand.salePrice, 1000);
    expect(untouchedCategory.salePrice, 1000);
  });
}
