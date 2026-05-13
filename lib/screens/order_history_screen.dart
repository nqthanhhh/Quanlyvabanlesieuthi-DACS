// lib/screens/order_history_screen.dart
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/order_line.dart';
import '../services/db_service.dart';
import '../services/api_service.dart';

class OrderHistoryScreen extends StatefulWidget {
  final int? customerId; // Lấy đơn hàng theo khách
  const OrderHistoryScreen({super.key, this.customerId});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<Order> orders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => isLoading = true);
    try {
      if (widget.customerId != null) {
        orders = await ApiService.fetchPurchaseHistory(customerId: widget.customerId);
      } else {
        orders = DBService.getAllOrders();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải đơn hàng: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Chờ xác nhận nhân viên': return Colors.orange;
      case 'Đang giao': return Colors.blue;
      case 'Hoàn thành': return Colors.green;
      case 'Đã hủy': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: ID + trạng thái
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Đơn #${order.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(
                      color: _statusColor(order.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Table headers
            Row(
              children: const [
                Expanded(flex: 4, child: Text('Sản phẩm', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Số lượng x Giá', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Tổng tiền', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            const Divider(),
            // Danh sách sản phẩm
            ...order.items.map((OrderLine item) {
              final totalPrice = item.pricePerUnit * item.quantity;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: Text(item.productName)),
                    Expanded(flex: 2, child: Text('${item.quantity} x ${item.pricePerUnit} đ')),
                    Expanded(flex: 2, child: Text('${totalPrice.toStringAsFixed(0)} đ')),
                  ],
                ),
              );
            }).toList(),
            const Divider(),
            // Tổng tiền đơn hàng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng cộng:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${order.totalAmount.toStringAsFixed(0)} đ', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            // Phương thức thanh toán
            if (order.paymentMethod != null && order.paymentMethod!.isNotEmpty)
              Text('Thanh toán: ${order.paymentMethod}', style: const TextStyle(color: Colors.black87)),
            // Địa chỉ giao hàng nếu có
            if (order.shippingAddress != null && order.shippingAddress!.isNotEmpty)
              Text('Địa chỉ: ${order.shippingAddress}', style: const TextStyle(color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn hàng của tôi'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
          ? const Center(child: Text('Chưa có đơn hàng nào'))
          : RefreshIndicator(
        onRefresh: _loadOrders,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) => _buildOrderCard(orders[index]),
        ),
      ),
    );
  }
}