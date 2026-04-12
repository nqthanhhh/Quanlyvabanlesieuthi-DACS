// lib/models/order.dart
import 'package:hive/hive.dart';
import 'order_line.dart'; // Import OrderLine

part 'order.g.dart'; // File tự động tạo bởi build_runner

@HiveType(typeId: 2) // Chọn typeId chưa dùng (2)
class Order extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime orderDate;

  @HiveField(2)
  double totalAmount;

  @HiveField(3)
  String customerName;

  @HiveField(4)
  String status; // Ví dụ: 'Hoàn thành', 'Đang xử lý', 'Đã hủy'

  @HiveField(5)
  List<OrderLine> items; // Danh sách sản phẩm trong đơn hàng

  Order({
    required this.id,
    required this.orderDate,
    required this.totalAmount,
    required this.customerName,
    required this.status,
    required this.items,
  });
}