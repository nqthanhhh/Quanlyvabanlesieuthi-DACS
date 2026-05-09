// lib/models/product.dart
import 'package:hive/hive.dart';
import '../utils/type_converters.dart';

part 'product.g.dart';

@HiveType(typeId: 0)
class Product extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double price;

  @HiveField(3)
  String unit;

  @HiveField(4)
  int stockQuantity;

  @HiveField(5) // <-- THÊM DÒNG NÀY (sử dụng index tiếp theo)
  DateTime? createdAt; // <-- THÊM TRƯỜNG NÀY (nullable)

  String? imageUrl;
  String? barcode;
  int? categoryId;
  String? categoryName;
  int minStock;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    this.stockQuantity = 0,
    this.createdAt, // <-- THÊM VÀO CONSTRUCTOR (không 'required')
    this.imageUrl,
    this.barcode,
    this.categoryId,
    this.categoryName,
    this.minStock = 10,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['product_id'] ?? json['id']).toString(),
      name: (json['product_name'] ?? json['name'] ?? '').toString(),
      price: TypeConverters.toDouble(json['price']),
      unit: (json['unit'] ?? 'sp').toString(),
      stockQuantity: TypeConverters.toInt(
        json['stock'] ?? json['stockQuantity'],
      ),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      imageUrl: (json['image_url'] ?? json['imageUrl'])?.toString(),
      barcode: json['barcode']?.toString(),
      categoryId: TypeConverters.toNullableInt(
        json['category_id'] ?? json['categoryId'],
      ),
      categoryName: (json['category_name'] ?? json['categoryName'])?.toString(),
      minStock: TypeConverters.toInt(json['min_stock'], defaultValue: 10),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': int.tryParse(id),
      'product_name': name,
      'barcode': barcode,
      'price': price,
      'unit': unit,
      'stock': stockQuantity,
      'min_stock': minStock,
      'category_id': categoryId,
      'image_url': imageUrl,
    };
  }
}
