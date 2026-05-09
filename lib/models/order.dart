// lib/models/order.dart
import 'package:hive/hive.dart';
import 'order_line.dart'; // Import OrderLine
import '../utils/type_converters.dart';

part 'order.g.dart'; // File tự động tạo bởi build_runner

@HiveType(typeId: 2) // Chọn typeId chưa dùng (2)
class Order extends HiveObject {
  @HiveField(6)
  int? customerId;

  @HiveField(7)
  String? shippingAddress;

  @HiveField(8)
  String? paymentMethod;

  @HiveField(9)
  String? paymentStatus;

  @HiveField(10)
  String? note;

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
    this.customerId,
    this.shippingAddress,
    this.paymentMethod,
    this.paymentStatus,
    this.note,
    required this.id,
    required this.orderDate,
    required this.totalAmount,
    required this.customerName,
    required this.status,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return Order(
      customerId: TypeConverters.toNullableInt(
        json['customer_id'] ?? json['customerId'],
      ),
      shippingAddress: TypeConverters.toNullableString(
        json['shipping_address'] ?? json['shippingAddress'],
      ),
      paymentMethod: TypeConverters.toNullableString(
        json['payment_method'] ?? json['paymentMethod'] ?? json['method'],
      ),
      paymentStatus: TypeConverters.toNullableString(
        json['payment_status'] ?? json['paymentStatus'],
      ),
      note: TypeConverters.toNullableString(json['note']),
      id: (json['order_id'] ?? json['id']).toString(),
      orderDate:
          DateTime.tryParse(
            (json['created_at'] ?? json['orderDate'] ?? '').toString(),
          ) ??
          DateTime.now(),
      totalAmount: TypeConverters.toDouble(
        json['totalAmount'] ?? json['final_amount'],
      ),
      customerName:
          (json['customer_name'] ?? json['customerName'] ?? 'Khách lẻ')
              .toString(),
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
      'payment_status': paymentStatus ?? 'paid',
      'shipping_address': shippingAddress,
      'payment_method': paymentMethod ?? 'cash',
      'note': note,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
