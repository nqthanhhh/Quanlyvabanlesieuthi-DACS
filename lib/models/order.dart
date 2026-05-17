// lib/models/order.dart
import 'package:hive/hive.dart';
import 'order_line.dart'; // Import OrderLine
import '../utils/type_converters.dart';

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

  @HiveField(11)
  int? voucherId; // Mã voucher được áp dụng

  @HiveField(12)
  double discountAmount; // Số tiền giảm

  @HiveField(13)
  String orderType;

  @HiveField(14)
  String? deliveryMethod;

  Order({
    required this.id,
    required this.orderDate,
    required this.totalAmount,
    required this.customerName,
    required this.status,
    required this.items,
    this.customerId,
    this.shippingAddress,
    this.paymentMethod,
    this.paymentStatus,
    this.note,
    this.voucherId,
    this.discountAmount = 0,
    this.orderType = 'offline',
    this.deliveryMethod,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return Order(
      id: (json['order_id'] ?? json['id']).toString(),
      orderDate:
          DateTime.tryParse(
            (json['created_at'] ?? json['orderDate'] ?? '').toString(),
          ) ??
          DateTime.now(),
      totalAmount: TypeConverters.toDouble(
        json['final_amount'] ??
            json['total_after_discount'] ??
            json['discounted_total'] ??
            json['totalAmount'] ??
            json['total_amount'],
      ),
      customerName:
          (json['customer_name'] ?? json['customerName'] ?? 'Khách lẻ')
              .toString(),
      status:
          (json['order_status'] ?? json['orderStatus'] ?? json['status'] ?? '')
              .toString(),
      items: rawItems
          .whereType<Map>()
          .map((e) => OrderLine.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      customerId: TypeConverters.toNullableInt(
        json['customer_id'] ?? json['customerId'] ?? json['user_id'],
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
      voucherId: TypeConverters.toNullableInt(json['voucher_id']),
      discountAmount: TypeConverters.toDouble(json['discount_amount'] ?? 0),
      orderType: (json['order_type'] ?? json['orderType'] ?? 'offline')
          .toString(),
      deliveryMethod: TypeConverters.toNullableString(
        json['delivery_method'] ?? json['deliveryMethod'],
      ),
    );
  }

  Map<String, dynamic> toJson({int? customerId, int? employeeId}) {
    return {
      'customer_id': customerId,
      'employee_id': employeeId,
      'order_type': orderType,
      'delivery_method': deliveryMethod,
      'status': status,
      'order_status': status,
      'payment_status': paymentStatus ?? 'paid',
      'shipping_address': shippingAddress,
      'payment_method': paymentMethod ?? 'cash',
      'note': note,
      'voucher_id': voucherId,
      'discount_amount': discountAmount,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
