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

  @HiveField(3) // Tên mới: Đơn vị tính (unit)
  String unit;

  @HiveField(4) // Trường mới: Số lượng tồn kho (stockQuantity)
  int stockQuantity;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    this.stockQuantity = 0, // Đặt mặc định hoặc nhận giá trị từ DBService
  });
}