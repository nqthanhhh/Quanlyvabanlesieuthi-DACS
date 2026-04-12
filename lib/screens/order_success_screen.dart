// dart
// lib/screens/order_success_screen.dart
import 'package:flutter/material.dart';
// Note: do not recreate HomeScreen here; we'll pop back to the existing HomeScreen

class OrderSuccessScreen extends StatelessWidget {
  final String totalAmount;
  final String paymentMethod;

  const OrderSuccessScreen({
    super.key,
    required this.totalAmount,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Thanh toán thành công'),
        backgroundColor: const Color(0xFF5C6BC0),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
            // Icon và thông báo
            const Icon(Icons.check_circle, color: Colors.green, size: 100),
            const SizedBox(height: 20),
            const Text(
              'Thanh toán thành công!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cảm ơn bạn đã mua hàng',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),

            // Chi tiết thanh toán
            _buildInfoRow('Đã thanh toán:', totalAmount),
            const SizedBox(height: 12),
            _buildInfoRow('Phương thức:', paymentMethod),
            const SizedBox(height: 50),

            // Nút "In hóa đơn"
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chức năng in đang được phát triển!'),
                  ),
                );
              },
              icon: const Icon(Icons.print),
              label: const Text('In hoá đơn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C6BC0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nút "Về trang chủ" - trở về HomeScreen hiện có (không đổi tài khoản)
            OutlinedButton.icon(
              onPressed: () {
                // Pop mọi route tới route đầu tiên trong stack (HomeScreen gốc)
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.home),
              label: const Text('Về trang chủ'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
                side: BorderSide(color: Colors.grey.shade400),
                padding: const EdgeInsets.symmetric(vertical: 15),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 18, color: Colors.black54),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
