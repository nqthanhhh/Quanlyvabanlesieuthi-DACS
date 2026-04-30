// lib/models/product.dart
import 'package:hive/hive.dart';

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
    this.categoryId,
    this.categoryName,
    this.minStock = 10,
  });

  static int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? defaultValue;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['product_id'] ?? json['id']).toString(),
      name: (json['product_name'] ?? json['name'] ?? '').toString(),
      price: _toDouble(json['price']),
      unit: (json['unit'] ?? 'sp').toString(),
      stockQuantity: _toInt(json['stock'] ?? json['stockQuantity']),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      imageUrl: (json['image_url'] ?? json['imageUrl'])?.toString(),
      categoryId: _toNullableInt(json['category_id'] ?? json['categoryId']),
      categoryName: (json['category_name'] ?? json['categoryName'])?.toString(),
      minStock: _toInt(json['min_stock'], defaultValue: 10),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': int.tryParse(id),
      'product_name': name,
      'price': price,
      'unit': unit,
      'stock': stockQuantity,
      'min_stock': minStock,
      'category_id': categoryId,
      'image_url': imageUrl,
    };
  }
}
