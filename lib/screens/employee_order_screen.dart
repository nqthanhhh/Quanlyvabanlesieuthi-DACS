import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/order_line.dart';
import '../services/api_service.dart';

class EmployeeOrderScreen extends StatefulWidget {
  const EmployeeOrderScreen({super.key});

  @override
  State<EmployeeOrderScreen> createState() => _EmployeeOrderScreenState();
}

class _EmployeeOrderScreenState extends State<EmployeeOrderScreen> {
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
      // Lấy tất cả đơn online từ server
      final allOrders = await ApiService.fetchOnlineOrders();
      // Chỉ lấy đơn chờ xác nhận
      orders = allOrders.where((o) => o.status == 'Chờ xác nhận nhân viên').toList();
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
      child: ExpansionTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Đơn #${order.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(order.status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(order.status, style: TextStyle(color: _statusColor(order.status), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sản phẩm:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...order.items.map((OrderLine item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${item.productName} x${item.quantity}')),
                      Text('${(item.pricePerUnit * item.quantity).toStringAsFixed(0)} đ'),
                    ],
                  ),
                );
              }).toList(),
              const Divider(),
              Text('Tổng tiền: ${order.totalAmount.toStringAsFixed(0)} đ', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (order.shippingAddress != null) Text('Địa chỉ: ${order.shippingAddress}'),
              if (order.paymentMethod != null && order.paymentMethod!.isNotEmpty) Text('Thanh toán: ${order.paymentMethod}'),
              const SizedBox(height: 8),
              if (order.status == 'Chờ xác nhận nhân viên')
                Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await ApiService.updateOrderStatus(order.id, 'Đang giao');
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đơn hàng đã được xác nhận!')));
                        _loadOrders();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xác nhận: $e')));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                    child: const Text('Xác nhận đơn hàng'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đơn hàng chờ xác nhận'), backgroundColor: Colors.white, foregroundColor: Colors.black87),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
          ? const Center(child: Text('Chưa có đơn hàng chờ xác nhận'))
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