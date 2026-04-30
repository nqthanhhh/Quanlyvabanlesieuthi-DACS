import 'package:flutter_test/flutter_test.dart';
import 'package:sieuthimini/models/product.dart';
import 'package:sieuthimini/services/api_service.dart';

void main() {
  test('API base URL and product JSON mapping are valid', () {
    expect(ApiService.baseUrl, isNotEmpty);

    final product = Product.fromJson({
      'product_id': 1,
      'product_name': 'Táo đỏ',
      'price': 20000,
      'stock': 10,
      'category_id': 2,
      'category_name': 'Trái cây',
    });

    expect(product.id, '1');
    expect(product.name, 'Táo đỏ');
    expect(product.price, 20000);
    expect(product.stockQuantity, 10);
    expect(product.categoryId, 2);
  });
}
