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

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return Order(
      id: (json['order_id'] ?? json['id']).toString(),
      orderDate: DateTime.tryParse(
            (json['created_at'] ?? json['orderDate'] ?? '').toString(),
          ) ??
          DateTime.now(),
      totalAmount: _toDouble(json['totalAmount'] ?? json['final_amount']),
      customerName: (json['customer_name'] ?? json['customerName'] ?? 'Khách lẻ').toString(),
      status: (json['status'] ?? '').toString(),
      items: rawItems
          .whereType<Map>()
          .map((e) => OrderLine.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson({int? customerId, int? employeeId}) {
    return {
      'customer_id': customerId,
      'employee_id': employeeId,
      'order_type': 'offline',
      'status': status,
      'payment_status': 'paid',
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
