// lib/models/order_line.dart
import 'package:hive/hive.dart';

part 'order_line.g.dart';

@HiveType(typeId: 3) // Chọn typeId chưa dùng (3)
class OrderLine extends HiveObject {
  @HiveField(0)
  String productId;

  @HiveField(1)
  String productName; // Giúp hiển thị nhanh

  @HiveField(2)
  int quantity;

  @HiveField(3)
  double pricePerUnit;

  OrderLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.pricePerUnit,
  });
}