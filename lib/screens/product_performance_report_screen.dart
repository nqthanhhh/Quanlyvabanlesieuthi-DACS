import 'package:flutter/material.dart';

import '../models/product.dart';
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
  static const Color _surface = Color(0xFFF5F7FA);
  static const Color _primary = Color(0xFF146C43);

  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<List<Map<String, dynamic>>> _loadData() async {
    final rawUserId = DBService.settings().get('current_user_id');
    final adminUserId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId?.toString() ?? '');
    if (adminUserId == null) {
      throw ApiException('Thiếu thông tin admin');
    }

    final products = await ApiService.fetchProductPerformanceReport(
      adminUserId,
    );
    _fillMissingProductData(products);
    products.sort((a, b) {
      final bySold = _toInt(
        b['total_quantity_sold'],
      ).compareTo(_toInt(a['total_quantity_sold']));
      if (bySold != 0) return bySold;
      return _toDouble(
        b['total_revenue'],
      ).compareTo(_toDouble(a['total_revenue']));
    });
    return products;
  }

  void _fillMissingProductData(List<Map<String, dynamic>> products) {
    final localProducts = DBService.getAllProducts();
    final byId = <String, Product>{
      for (final product in localProducts) product.id: product,
    };
    final byBarcode = <String, Product>{
      for (final product in localProducts)
        if ((product.barcode ?? '').isNotEmpty) product.barcode!: product,
    };

    for (final product in products) {
      final productId = (product['product_id'] ?? product['id'] ?? '')
          .toString();
      final barcode = (product['barcode'] ?? '').toString();
      final local = byId[productId] ?? byBarcode[barcode];

      if (local != null) {
        if (_toDouble(product['sale_price'] ?? product['price']) <= 0) {
          product['sale_price'] = local.price;
        }
        product['unit'] ??= local.unit;
        product['barcode'] ??= local.barcode;
        product['category_name'] ??= local.categoryName;
        product['image_url'] ??= local.imageUrl;
        product['current_stock'] ??= local.stockQuantity;
      }

      product['sell_through_rate'] = _calculateSellThroughRate(product);
    }
  }

  static double? _calculateSellThroughRate(Map<String, dynamic> product) {
    final explicitValue = product['sell_through_rate'];
    if (explicitValue != null) {
      return _toDouble(explicitValue);
    }

    final sold = _toInt(product['total_quantity_sold']);
    final stock = _toInt(product['current_stock']);
    final totalTracked = sold + stock;
    if (totalTracked <= 0) {
      return null;
    }
    return (sold * 100) / totalTracked;
  }

  void _reload() {
    setState(() {
      _future = _loadData();
    });
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatCurrency(num amount) {
    return '${amount.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VNĐ';
  }

  String _formatPercent(num value) {
    if (value == 0) return '0%';
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}%';
  }

  String _formatOptionalPercent(double? value) {
    if (value == null) return 'Chưa có dữ liệu';
    return _formatPercent(value);
  }

  String _productName(Map<String, dynamic> product) {
    final name = (product['product_name'] ?? '').toString().trim();
    return name.isEmpty ? 'Sản phẩm chưa đặt tên' : name;
  }

  Widget _buildSummary(List<Map<String, dynamic>> products) {
    final totalSold = products.fold<int>(
      0,
      (sum, product) => sum + _toInt(product['total_quantity_sold']),
    );
    final totalRevenue = products.fold<double>(
      0,
      (sum, product) => sum + _toDouble(product['total_revenue']),
    );
    final activeProducts = products
        .where((product) => _toInt(product['total_quantity_sold']) > 0)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 720 ? 3 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: constraints.maxWidth >= 720 ? 2.7 : 1.6,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _MetricCard(
              title: 'Sản phẩm',
              value: '${products.length}',
              subtitle: '$activeProducts đang có doanh số',
              icon: Icons.inventory_2_outlined,
              color: Colors.indigo,
            ),
            _MetricCard(
              title: 'Đã bán',
              value: '$totalSold',
              subtitle: 'Tổng số lượng',
              icon: Icons.shopping_cart_checkout_outlined,
              color: _primary,
            ),
            _MetricCard(
              title: 'Tổng',
              value: _formatCurrency(totalRevenue),
              subtitle: 'Doanh thu sản phẩm',
              icon: Icons.payments_outlined,
              color: Colors.orange.shade700,
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, int index) {
    final importPrice = product['import_price'] == null
        ? null
        : _toDouble(product['import_price']);
    final salePrice = _toDouble(product['sale_price'] ?? product['price']);
    final sold = _toInt(product['total_quantity_sold']);
    final revenue = _toDouble(product['total_revenue']);
    final performance = _calculateSellThroughRate(product);
    final stock = _toInt(product['current_stock']);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _ProductPerformanceDetailScreen(
                product: product,
                rank: index + 1,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RankBadge(rank: index + 1),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _productName(product),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${product['category_name'] ?? 'Chưa phân loại'} • Tồn $stock',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade500),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(
                    label: 'Giá nhập',
                    value: importPrice == null
                        ? 'Chưa có'
                        : _formatCurrency(importPrice),
                  ),
                  _InfoPill(
                    label: 'Giá bán',
                    value: salePrice <= 0
                        ? 'Chưa có dữ liệu'
                        : _formatCurrency(salePrice),
                  ),
                  _InfoPill(
                    label: 'Hiệu suất bán',
                    value: _formatOptionalPercent(performance),
                    valueColor: _performanceColor(performance),
                  ),
                  _InfoPill(label: 'Đã bán', value: '$sold'),
                  _InfoPill(label: 'Tổng', value: _formatCurrency(revenue)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _performanceColor(double? performance) {
    if (performance == null) return Colors.grey.shade700;
    if (performance >= 70) return _primary;
    if (performance >= 35) return Colors.orange.shade700;
    return Colors.red.shade600;
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
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Hiệu suất sản phẩm'),
        backgroundColor: _primary,
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

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummary(products),
                    const SizedBox(height: 18),
                    const Text(
                      'Xếp hạng bán chạy',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                );
              }
              return _buildProductCard(products[index - 1], index - 1);
            },
          );
        },
      ),
    );
  }
}

class _ProductPerformanceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> product;
  final int rank;

  const _ProductPerformanceDetailScreen({
    required this.product,
    required this.rank,
  });

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _formatCurrency(num amount) {
    return '${amount.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VNĐ';
  }

  String _formatPercent(num value) {
    if (value == 0) return '0%';
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}%';
  }

  String _formatOptionalPercent(double? value) {
    if (value == null) return 'Chưa có dữ liệu';
    return _formatPercent(value);
  }

  double? _calculateSellThroughRate() {
    final explicitValue = product['sell_through_rate'];
    if (explicitValue != null) {
      return _toDouble(explicitValue);
    }

    final sold = _toInt(product['total_quantity_sold']);
    final stock = _toInt(product['current_stock']);
    final totalTracked = sold + stock;
    if (totalTracked <= 0) {
      return null;
    }
    return (sold * 100) / totalTracked;
  }

  String _productName() {
    final name = (product['product_name'] ?? '').toString().trim();
    return name.isEmpty ? 'Sản phẩm chưa đặt tên' : name;
  }

  Widget _buildHeroImage() {
    final imageUrl = (product['image_url'] ?? '').toString();
    final resolvedUrl = imageUrl.startsWith('/')
        ? '${ApiService.baseUrl}$imageUrl'
        : imageUrl;
    if (resolvedUrl.startsWith('http')) {
      return Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _fallbackImage(),
      );
    }
    return _fallbackImage();
  }

  Widget _fallbackImage() {
    return Container(
      color: const Color(0xFFE9F5EF),
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_outlined,
        size: 54,
        color: Color(0xFF146C43),
      ),
    );
  }

  Widget _metric({
    required String label,
    required String value,
    IconData? icon,
    Color? color,
  }) {
    final effectiveColor = color ?? const Color(0xFF146C43);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: effectiveColor),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final importPrice = product['import_price'] == null
        ? null
        : _toDouble(product['import_price']);
    final salePrice = _toDouble(product['sale_price'] ?? product['price']);
    final sold = _toInt(product['total_quantity_sold']);
    final revenue = _toDouble(product['total_revenue']);
    final profit = product['total_profit'] == null
        ? null
        : _toDouble(product['total_profit']);
    final averageSalePrice = _toDouble(product['average_sale_price']);
    final performance = _calculateSellThroughRate();
    final stock = _toInt(product['current_stock']);
    final ordersCount = _toInt(product['orders_count']);
    final unit = (product['unit'] ?? 'sp').toString();
    final profitMargin = profit == null || revenue <= 0
        ? null
        : (profit / revenue) * 100;
    final profitPerUnit = profit == null || sold <= 0 ? null : profit / sold;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
        backgroundColor: const Color(0xFF146C43),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(height: 180, child: _buildHeroImage()),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RankBadge(rank: rank),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _productName(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${product['category_name'] ?? 'Chưa phân loại'} • ${product['barcode'] ?? 'Chưa có mã'}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _metric(
                label: 'Đã bán',
                value: '$sold $unit',
                icon: Icons.shopping_bag_outlined,
              ),
              _metric(
                label: 'Tổng',
                value: _formatCurrency(revenue),
                icon: Icons.payments_outlined,
                color: Colors.orange.shade700,
              ),
              _metric(
                label: 'Hiệu suất bán',
                value: _formatOptionalPercent(performance),
                icon: Icons.trending_up_outlined,
                color: Colors.indigo,
              ),
              _metric(
                label: 'Tồn kho',
                value: '$stock $unit',
                icon: Icons.warehouse_outlined,
                color: Colors.blueGrey,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _detailRow(
                  'Giá nhập',
                  importPrice == null
                      ? 'Chưa có'
                      : _formatCurrency(importPrice),
                ),
                _detailRow(
                  'Giá bán',
                  salePrice <= 0
                      ? 'Chưa có dữ liệu'
                      : _formatCurrency(salePrice),
                ),
                _detailRow(
                  'Giá bán TB',
                  averageSalePrice <= 0
                      ? salePrice <= 0
                            ? 'Chưa có dữ liệu'
                            : _formatCurrency(salePrice)
                      : _formatCurrency(averageSalePrice),
                ),
                _detailRow('Số đơn', '$ordersCount'),
                _detailRow(
                  'Lợi nhuận',
                  profit == null ? 'Chưa đủ dữ liệu' : _formatCurrency(profit),
                ),
                _detailRow(
                  'Lãi / đơn vị',
                  profitPerUnit == null
                      ? 'Chưa đủ dữ liệu'
                      : _formatCurrency(profitPerUnit),
                ),
                _detailRow(
                  'Biên lợi nhuận',
                  profitMargin == null
                      ? 'Chưa đủ dữ liệu'
                      : _formatPercent(profitMargin),
                ),
                _detailRow('Mã sản phẩm', '${product['product_id'] ?? '-'}'),
                _detailRow('Mã vạch', '${product['barcode'] ?? '-'}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
            ],
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF146C43).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '#$rank',
        style: const TextStyle(
          color: Color(0xFF146C43),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoPill({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 104),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
