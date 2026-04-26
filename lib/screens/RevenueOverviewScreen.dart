// lib/screens/RevenueOverviewScreen.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'order_list_screen.dart';
import '../services/db_service.dart';
import '../models/order.dart';

class RevenueOverviewScreen extends StatefulWidget {
  const RevenueOverviewScreen({super.key});

  @override
  State<RevenueOverviewScreen> createState() => _RevenueOverviewScreenState();
}

class _RevenueOverviewScreenState extends State<RevenueOverviewScreen> {
  final String newProducts = '20';
  final String totalCustomers = '50';

  // Tách Widget Card số liệu (Sử dụng Expanded)
  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color,
      {VoidCallback? onTap}) {
    return Expanded( // Bắt buộc Expanded để chia không gian đều
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          // Padding nằm bên trong Card, không gây xung đột với Expanded
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                    const TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    Icon(icon, size: 16, color: color),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Hàm định dạng tiền tệ
  String _formatCurrency(double amount) {
    return '${amount.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    )} ₫';
  }

  // Widget hiển thị Hiệu suất sản phẩm (Giữ nguyên logic)
  Widget _buildProductPerformanceTile(
      String name, String quantity, String imagePath) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              imagePath,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(
                width: 50,
                height: 50,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_not_supported, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  quantity,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
              ],
            ),
          ),
          const Icon(Icons.trending_up, color: Colors.green),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<Order>>(
      valueListenable: DBService.orders().listenable(),
      builder: (context, box, _) {
        final totalOrders = box.length;
        final totalRevenue = DBService.getTotalRevenue();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tổng quan Doanh thu'),
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header (Tổng quan)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Doanh thu (Tổng cộng)',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        _formatCurrency(totalRevenue),
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      // Thêm một dòng số liệu nhỏ nếu cần
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Cập nhật theo thời gian thực',
                              style: TextStyle(color: Colors.white60, fontSize: 12)),
                          const Icon(Icons.show_chart,
                              color: Colors.white70, size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Các chỉ số quan trọng (Đã FIX LỖI OVERFLOW)
                Row(
                  children: [
                    // Thẻ 1: Số đơn hàng
                    _buildMetricCard(
                      'Số đơn hàng',
                      '$totalOrders',
                      Icons.receipt_long,
                      Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const OrderListScreen()),
                        );
                      },
                    ),

                    // 💡 SỬ DỤNG SIZEDBOX NHỎ NHẤT (8) để tránh tràn
                    const SizedBox(width: 8),

                    // Thẻ 2: Khách hàng mới (hoặc Sản phẩm mới)
                    _buildMetricCard(
                      'Sản phẩm mới',
                      newProducts,
                      Icons.new_releases,
                      Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 3. Hiệu suất sản phẩm (Giữ nguyên)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Hiệu suất sản phẩm',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Xem thêm',
                          style: TextStyle(color: Color(0xFF3B82F6))),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Danh sách sản phẩm bán chạy (Dữ liệu giả định)
                _buildProductPerformanceTile(
                    'Táo đỏ', '50 quả', 'assets/images/anh1.png'),
                _buildProductPerformanceTile(
                    'Nước Sprite', '50 lon', 'assets/images/coke.png'),
                _buildProductPerformanceTile(
                    'Quả chuối', '10 lải', 'assets/images/chuoi.png'),
              ],
            ),
          ),
        );
      },
    );
  }
}