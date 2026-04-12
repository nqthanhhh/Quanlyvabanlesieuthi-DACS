import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/order.dart'; // Cần import model Order
import '../services/db_service.dart'; // Cần import DBService
import 'order_detail_screen.dart'; // Cần import màn hình chi tiết (Giả sử bạn đã có file này)

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // String _selectedStatus = 'Tất cả'; // Có thể dùng cho lọc trạng thái

  // Hàm định dạng tiền tệ
  String _formatCurrency(double amount) {
    return '${amount.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\\d))'),
          (Match m) => '${m[1]},',
    )} ₫';
  }

  // Widget hiển thị một đơn hàng
  Widget _buildOrderTile(BuildContext context, Order order) {
    // Tùy biến màu sắc trạng thái (Giả định trạng thái cố định là "Hoàn thành")
    Color statusColor = Colors.green;
    String statusText = 'Hoàn thành';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        // Thông tin đơn hàng
        title: Text(
          'Mã đơn hàng: ${order.id}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Khách hàng: ${order.customerName}',
              style: const TextStyle(color: Colors.black87),
            ),
            Text(
              'Ngày: ${order.orderDate.day}/${order.orderDate.month}/${order.orderDate.year}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng tiền: ${_formatCurrency(order.totalAmount)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        // 💡 XỬ LÝ KHI NHẤN VÀO ĐƠN HÀNG
        onTap: () {
          // Chuyển hướng sang màn hình chi tiết và truyền toàn bộ đối tượng Order
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OrderDetailScreen(order: order),
          ));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Đơn hàng', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.black45, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: const InputDecoration(
                        hintText: 'Tìm kiếm theo mã/khách hàng',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Danh sách đơn hàng thực tế (Kết nối Hive với ValueListenableBuilder)
          Expanded(
            child: ValueListenableBuilder<Box<Order>>(
              valueListenable: DBService.orders().listenable(),
              builder: (context, box, _) {
                // 💡 LẤY DANH SÁCH ĐƠN HÀNG VÀ SẮP XẾP MỚI NHẤT
                final allOrders = DBService.getAllOrders(); // Sử dụng hàm getAllOrders đã sắp xếp trong DBService

                // 💡 LỌC THEO TÌM KIẾM
                final filteredOrders = allOrders.where((order) {
                  final query = _searchQuery.toLowerCase();
                  return order.id.toLowerCase().contains(query) ||
                      order.customerName.toLowerCase().contains(query);
                }).toList();

                if (filteredOrders.isEmpty) {
                  return Center(
                    child: Text('Không tìm thấy đơn hàng nào${_searchQuery.isNotEmpty ? ' khớp với tìm kiếm' : ''}.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    return _buildOrderTile(context, filteredOrders[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}