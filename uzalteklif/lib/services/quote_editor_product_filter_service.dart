import '../models/product.dart';
import '../utils/product_category_labels.dart';

class QuoteEditorProductFilterService {
  const QuoteEditorProductFilterService();

  String normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');

  List<Product> filter(
    List<Product> products, {
    required String query,
    required String category,
  }) {
    final normalizedQuery = normalize(query);
    return products
        .where((product) {
          final categoryMatch =
              category == 'Tum Kategoriler' || product.category == category;
          final haystack = normalize(
            [
              product.code,
              product.name,
              product.brand,
              product.model,
              product.category,
              productCategoryTurkishLabel(product.category),
              productMainCategoryTurkishLabel(product),
              productSubcategoryTurkishLabel(product),
              product.description,
              product.technicalSummary,
              product.specifications.entries
                  .map((entry) => '${entry.key} ${entry.value}')
                  .join(' '),
            ].join(' '),
          );
          return categoryMatch &&
              (normalizedQuery.isEmpty || haystack.contains(normalizedQuery));
        })
        .toList(growable: false);
  }
}
