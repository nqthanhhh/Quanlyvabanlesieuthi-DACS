import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/order.dart';
import '../services/db_service.dart';
import 'order_detail_screen.dart';
// import 'order_detail_screen.dart'; // Màn hình chi tiết đơn hàng (giả định)

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  // 💡 1. KHAI BÁO CÁC BIẾN CHO INFINITE SCROLL
  final ScrollController _scrollController = ScrollController();
  final int _ordersPerPage = 10; // Số lượng đơn hàng tải mỗi lần
  int _loadedOrderCount = 10;    // Số lượng đơn hàng đang hiển thị
  bool _isLoadingMore = false;    // Cờ kiểm tra đang tải dữ liệu

  @override
  void initState() {
    super.initState();
    // 💡 2. THÊM LISTENER CHO SCROLL CONTROLLER
    _scrollController.addListener(_scrollListener);
  }

  // 💡 3. HÀM XỬ LÝ SỰ KIỆN CUỘN
  void _scrollListener() {
    // Kiểm tra nếu cuộn đến cuối danh sách VÀ không có quá trình tải nào đang diễn ra
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && !_isLoadingMore) {
      _loadMoreOrders();
    }
  }

  // 💡 4. HÀM TẢI THÊM ĐƠN HÀNG
  void _loadMoreOrders() {
    // Nếu số lượng đã tải bằng hoặc lớn hơn tổng số đơn hàng, thì không cần tải nữa.
    final totalOrders = DBService.orders().length;
    if (_loadedOrderCount >= totalOrders) return;

    setState(() {
      _isLoadingMore = true;
    });

    // Giả lập độ trễ tải dữ liệu (thay thế bằng thao tác DB nếu cần thiết)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _loadedOrderCount += _ordersPerPage;
          if (_loadedOrderCount > totalOrders) {
            _loadedOrderCount = totalOrders;
          }
          _isLoadingMore = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Widget hiển thị một đơn hàng (Giữ nguyên logic sửa lỗi RenderFlex)
  Widget _buildOrderTile(BuildContext context, Order order) {
    // ... (logic formatCurrency và statusColor giữ nguyên)
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

    String formatCurrency(double amount) {
      return '${amount.round().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
      )} ₫';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // 💡 HÀM ĐIỀU HƯỚNG TỚI MÀN HÌNH CHI TIẾT
          Navigator.of(context).push(
            MaterialPageRoute(
              // Truyền đối tượng 'order' của đơn hàng hiện tại
              builder: (_) => OrderDetailScreen(order: order),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Mã đơn: ${order.id}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.status,
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Khách hàng: '),
                  Expanded(
                    child: Text(
                      order.customerName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Ngày: ${order.orderDate.day}/${order.orderDate.month}/${order.orderDate.year} ${order.orderDate.hour}:${order.orderDate.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng tiền:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    formatCurrency(order.totalAmount),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.deepOrange.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget hiển thị Loading ở cuối danh sách
  Widget _buildLoadingFooter() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách đơn hàng'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm (Giữ nguyên)
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, color: Colors.black45, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
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

          // Danh sách đơn hàng thực tế (có Infinite Scroll)
          Expanded(
            child: ValueListenableBuilder<Box<Order>>(
              valueListenable: DBService.orders().listenable(),
              builder: (context, box, _) {
                // Lấy tất cả đơn hàng và sắp xếp theo ngày mới nhất
                final allOrders = box.values.toList()
                  ..sort((a, b) => b.orderDate.compareTo(a.orderDate));

                // 💡 CHỈ LẤY SỐ LƯỢNG ĐÃ TẢI
                final ordersToDisplay = allOrders.take(_loadedOrderCount).toList();

                if (allOrders.isEmpty) {
                  return const Center(
                    child: Text('Chưa có đơn hàng nào được tạo.'),
                  );
                }

                // Tính toán số lượng mục hiển thị: ordersToDisplay.length + (1 nếu đang tải thêm)
                final itemCount = ordersToDisplay.length + (_isLoadingMore ? 1 : 0);

                return ListView.builder(
                  controller: _scrollController, // 💡 GẮN SCROLL CONTROLLER
                  padding: const EdgeInsets.all(16.0),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    if (index == ordersToDisplay.length) {
                      // Nếu đang tải thêm, hiển thị Loading Footer
                      return _buildLoadingFooter();
                    }
                    // Ngược lại, hiển thị Order Tile
                    return _buildOrderTile(context, ordersToDisplay[index]);
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