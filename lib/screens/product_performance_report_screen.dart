import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/db_service.dart';

class ProductPerformanceReportScreen extends StatefulWidget {
  const ProductPerformanceReportScreen({super.key});

  @override
  State<ProductPerformanceReportScreen> createState() =>
      _ProductPerformanceReportScreenState();
}

class _ProductPerformanceReportScreenState
    extends State<ProductPerformanceReportScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<List<Map<String, dynamic>>> _loadData() {
    final rawUserId = DBService.settings().get('current_user_id');
    final adminUserId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId?.toString() ?? '');
    if (adminUserId == null) {
      throw ApiException('Thiếu thông tin admin');
    }
    return ApiService.fetchProductPerformanceReport(adminUserId);
  }

  void _reload() {
    setState(() {
      _future = _loadData();
    });
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

  String _formatCurrency(num amount) {
    return '${amount.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ';
  }

  Widget _buildProductTile(Map<String, dynamic> product, int index) {
    final productName = (product['product_name'] ?? '').toString();
    final quantitySold = _toInt(product['total_quantity_sold']);
    final revenue = _toDouble(product['total_revenue']);
    final profit = product['total_profit'] == null
        ? null
        : _toDouble(product['total_profit']);
    final importPrice = product['import_price'] == null
        ? null
        : _toDouble(product['import_price']);
    final stock = _toInt(product['current_stock']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          foregroundColor: Colors.blue.shade700,
          child: Text('${index + 1}'),
        ),
        title: Text(
          productName.isEmpty ? 'Sản phẩm chưa đặt tên' : productName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('Đã bán: $quantitySold'),
            Text('Doanh thu: ${_formatCurrency(revenue)}'),
            Text(
              profit == null
                  ? 'Lợi nhuận: Chưa đủ dữ liệu'
                  : 'Lợi nhuận: ${_formatCurrency(profit)}',
            ),
            Text(
              importPrice == null
                  ? 'Giá nhập: Chưa có'
                  : 'Giá nhập: ${_formatCurrency(importPrice)}',
            ),
          ],
        ),
        trailing: Text(
          'Tồn: $stock',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
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
                  : 'Không tải được báo cáo hiệu suất sản phẩm',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo hiệu suất sản phẩm'),
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildError(snapshot.error!);
          }

          final products = snapshot.data ?? const [];
          if (products.isEmpty) {
            return const Center(
              child: Text('Chưa có dữ liệu hiệu suất sản phẩm.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            itemBuilder: (context, index) =>
                _buildProductTile(products[index], index),
          );
        },
      ),
    );
  }
}
