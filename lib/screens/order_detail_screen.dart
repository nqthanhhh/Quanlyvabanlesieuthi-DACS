// lib/screens/order_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/order_line.dart';

class OrderDetailScreen extends StatelessWidget {
  final Order order;

  const OrderDetailScreen({super.key, required this.order});

  // Hàm định dạng tiền tệ
  String _formatCurrency(double amount) {
    return '${amount.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    )} ₫';
  }

  // Hàm định dạng ngày
  String _formatDate(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')} - ${date.day}/${date.month}/${date.year}';
  }

  // Widget hiển thị chi tiết sản phẩm trong đơn hàng
  Widget _buildLineItem(OrderLine item) {
    // ... (Giữ nguyên _buildLineItem)
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('x${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.productName,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _formatCurrency(item.quantity * item.pricePerUnit),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Widget hiển thị thông tin chung
  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // 💡 HÀM HIỂN THỊ HÓA ĐƠN XEM TRƯỚC
  void _showInvoiceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Center(
            child: Text('HÓA ĐƠN BÁN HÀNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                // Thông tin cửa hàng (Mô phỏng)
                const Center(
                  child: Text('CỬA HÀNG ABC', style: TextStyle(fontSize: 16)),
                ),
                const Center(
                  child: Text('Địa chỉ: 123 Đường XYZ', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 15),

                // Thông tin Đơn hàng
                Text('Mã đơn: ${order.id}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('Khách hàng: ${order.customerName}'),
                Text('Ngày: ${_formatDate(order.orderDate.toLocal())}'),
                const Divider(),

                // Chi tiết sản phẩm
                const Text('SẢN PHẨM', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                ...order.items.map((item) => Row(
                  children: [
                    Expanded(child: Text('${item.productName} (x${item.quantity})')),
                    Text(_formatCurrency(item.quantity * item.pricePerUnit)),
                  ],
                )),
                const Divider(),

                // Tổng kết
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TỔNG THANH TOÁN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      _formatCurrency(order.totalAmount),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                const Center(child: Text('Cảm ơn quý khách!', style: TextStyle(fontStyle: FontStyle.italic))),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Đóng dialog
              },
              child: const Text('ĐÓNG'),
            ),
            // Nút "In thật" (Nếu muốn triển khai in thật sau này)
            ElevatedButton(
              onPressed: () {
                // TODO: Triển khai chức năng in sử dụng package 'printing' hoặc tương tự
                Navigator.of(context).pop(); // Đóng dialog sau khi in
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đang gửi lệnh in... (Mô phỏng)')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('IN', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (order.status) {
      case 'Hoàn thành':
        statusColor = Colors.green;
        break;
      case 'Đang xử lý':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.red;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết đơn hàng'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... (Thông tin Mã đơn & Trạng thái giữ nguyên)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mã đơn hàng: ${order.id}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // 1. Thông tin chung
            const Text('Thông tin chung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildInfoRow('Khách hàng:', order.customerName),
            _buildInfoRow('Ngày tạo:', _formatDate(order.orderDate.toLocal())),
            const Divider(height: 24),

            // 2. Chi tiết sản phẩm
            const Text('Sản phẩm đã mua', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...order.items.map((item) => _buildLineItem(item)),
            const Divider(height: 24),

            // 3. Tổng kết
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tổng tiền:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(
                  _formatCurrency(order.totalAmount),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange.shade600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Nút In hóa đơn
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // 💡 GỌI HÀM HIỂN THỊ DIALOG HÓA ĐƠN
                onPressed: () => _showInvoiceDialog(context),
                icon: const Icon(Icons.print, color: Colors.white),
                label: const Text('In hóa đơn',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}