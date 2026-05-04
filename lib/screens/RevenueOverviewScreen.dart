import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/db_service.dart';
import 'order_list_screen.dart';
import 'product_performance_report_screen.dart';

class RevenueOverviewScreen extends StatefulWidget {
  const RevenueOverviewScreen({super.key});

  @override
  State<RevenueOverviewScreen> createState() => _RevenueOverviewScreenState();
}

class _RevenueOverviewScreenState extends State<RevenueOverviewScreen> {
  late Future<_RevenueDashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_RevenueDashboardData> _loadData() async {
    final rawUserId = DBService.settings().get('current_user_id');
    final adminUserId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId?.toString() ?? '');
    if (adminUserId == null) {
      throw ApiException('Thiếu thông tin admin');
    }
    final revenue = await ApiService.fetchRevenueReport(adminUserId);
    final products = await ApiService.fetchProductPerformanceReport(
      adminUserId,
    );
    return _RevenueDashboardData(revenue: revenue, products: products);
  }

  void _reload() {
    setState(() {
      _future = _loadData();
    });
  }

  String _formatCurrency(num amount) {
    return '${amount.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(icon, size: 18, color: color),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductPerformanceTile(Map<String, dynamic> product) {
    final name = (product['product_name'] ?? '').toString();
    final quantity = _toInt(product['total_quantity_sold']);
    final revenue = _toDouble(product['total_revenue']);
    final stock = _toInt(product['current_stock']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        leading: Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.trending_up, color: Colors.blue.shade700),
        ),
        title: Text(
          name.isEmpty ? 'Sản phẩm chưa đặt tên' : name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Đã bán: $quantity | Doanh thu: ${_formatCurrency(revenue)}',
        ),
        trailing: Text(
          'Tồn: $stock',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildError(Object error) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng quan Doanh thu'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 42),
              const SizedBox(height: 12),
              Text(
                error is ApiException
                    ? error.message
                    : 'Không tải được báo cáo',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RevenueDashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Tổng quan Doanh thu'),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _buildError(snapshot.error!);
        }

        final data = snapshot.data!;
        final revenue = data.revenue;
        final totalRevenue = _toDouble(revenue['total_revenue']);
        final totalProfit = revenue['total_profit'];
        final totalOrders = _toInt(revenue['total_orders']);
        final totalProductsSold = _toInt(revenue['total_products_sold']);
        final profitNote = (revenue['profit_note'] ?? '').toString();
        final topProducts = data.products.take(3).toList();

        final isEmpty =
            totalRevenue == 0 && totalOrders == 0 && totalProductsSold == 0;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tổng quan Doanh thu'),
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Tải lại',
                icon: const Icon(Icons.refresh),
                onPressed: _reload,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tổng doanh thu',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Text(
                        _formatCurrency(totalRevenue),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isEmpty
                            ? 'Chưa có đơn hàng đã thanh toán hoặc hoàn thành'
                            : 'Dữ liệu lấy từ MySQL qua API báo cáo',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (totalProfit == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(
                      profitNote.isEmpty
                          ? 'Chưa đủ dữ liệu tính lợi nhuận'
                          : profitNote,
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildMetricCard(
                      'Số đơn hàng',
                      '$totalOrders',
                      Icons.receipt_long,
                      Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OrderListScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildMetricCard(
                      'Sản phẩm đã bán',
                      '$totalProductsSold',
                      Icons.inventory_2_outlined,
                      Colors.blue,
                    ),
                  ],
                ),
                if (totalProfit != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildMetricCard(
                        'Tổng lợi nhuận',
                        _formatCurrency(_toDouble(totalProfit)),
                        Icons.ssid_chart,
                        Colors.orange,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Hiệu suất sản phẩm',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const ProductPerformanceReportScreen(),
                          ),
                        );
                      },
                      child: const Text('Xem thêm'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (topProducts.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Chưa có dữ liệu hiệu suất sản phẩm.'),
                    ),
                  )
                else
                  ...topProducts.map(_buildProductPerformanceTile),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RevenueDashboardData {
  final Map<String, dynamic> revenue;
  final List<Map<String, dynamic>> products;

  _RevenueDashboardData({required this.revenue, required this.products});
}
