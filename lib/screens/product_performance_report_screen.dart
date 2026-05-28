import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/order.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';

enum _PerformanceRange { today, sevenDays, thirtyDays, month }

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

  late Future<Map<String, dynamic>> _future;
  _PerformanceRange _range = _PerformanceRange.thirtyDays;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _future = _loadData();
  }

  Future<Map<String, dynamic>> _loadData() async {
    final rawUserId = DBService.settings().get('current_user_id');
    final adminUserId = rawUserId is int
        ? rawUserId
        : int.tryParse(rawUserId?.toString() ?? '');
    if (adminUserId == null) {
      throw ApiException('Thiếu thông tin admin');
    }

    debugPrint(
      '[performance] load dashboard range=$_rangeApiValue month=${_range == _PerformanceRange.month ? _monthKey(_selectedMonth) : '-'}',
    );
    try {
      final data = await ApiService.fetchProductPerformanceDashboard(
        adminUserId,
        range: _rangeApiValue,
        month: _range == _PerformanceRange.month
            ? _monthKey(_selectedMonth)
            : null,
      );
      debugPrint('[performance] dashboard api ok keys=${data.keys.join(',')}');
      return data;
    } catch (error) {
      debugPrint('[performance] dashboard api failed: $error');
      return _loadLegacyDashboard(adminUserId);
    }
  }

  Future<Map<String, dynamic>> _loadLegacyDashboard(int adminUserId) async {
    debugPrint('[performance] fallback to legacy report APIs');
    final results = await Future.wait([
      ApiService.fetchRevenueReport(adminUserId),
      ApiService.fetchProductPerformanceReport(adminUserId),
    ]);
    final revenue = results[0] as Map<String, dynamic>;
    final products = (results[1] as List<Map<String, dynamic>>)
        .map((product) => Map<String, dynamic>.from(product))
        .toList();
    final orders = await _fetchFilteredOrderDetails();
    final periodProducts = _productsFromOrders(products, orders);
    final sourceProducts = periodProducts.isEmpty ? products : periodProducts;

    sourceProducts.sort((a, b) {
      final bySold = _toInt(
        b['total_quantity_sold'],
      ).compareTo(_toInt(a['total_quantity_sold']));
      if (bySold != 0) return bySold;
      return _toDouble(
        b['total_revenue'],
      ).compareTo(_toDouble(a['total_revenue']));
    });

    final topProducts = sourceProducts
        .where((product) => _toInt(product['total_quantity_sold']) > 0)
        .take(10)
        .toList();
    final highStockProducts =
        sourceProducts
            .where((product) => _toInt(product['current_stock']) > 50)
            .toList()
          ..sort(
            (a, b) => _toInt(
              b['current_stock'],
            ).compareTo(_toInt(a['current_stock'])),
          );
    final slowProducts = sourceProducts
        .where((product) => _toInt(product['total_quantity_sold']) < 5)
        .map((product) {
          product['days_without_order'] ??= 999;
          return product;
        })
        .take(10)
        .toList();
    final totalStock = products.fold<int>(
      0,
      (sum, product) => sum + _toInt(product['current_stock']),
    );
    final revenueChart = orders.isEmpty
        ? _filterLegacyRevenueRows(_list(revenue['revenue_by_time']))
        : _chartFromOrders(orders);
    final periodRevenue = orders.isEmpty
        ? revenueChart.fold<double>(
            0,
            (sum, row) => sum + _toDouble(row['revenue']),
          )
        : orders.fold<double>(0, (sum, order) => sum + order.totalAmount);
    final periodSold = orders.fold<int>(
      0,
      (sum, order) =>
          sum +
          order.items.fold<int>(0, (itemSum, item) => itemSum + item.quantity),
    );

    return {
      'filter': {
        'range': _rangeApiValue,
        'month': _range == _PerformanceRange.month
            ? _monthKey(_selectedMonth)
            : null,
        'source': 'legacy_reports',
      },
      'overview': {
        'total_revenue': periodRevenue,
        'total_orders': orders.isEmpty
            ? _estimateOrders(revenueChart)
            : orders.length,
        'total_products_sold': orders.isEmpty
            ? _toInt(revenue['total_products_sold'])
            : periodSold,
        'total_stock': totalStock,
        'average_order_value': orders.isEmpty || periodRevenue <= 0
            ? _toDouble(revenue['average_order_value'])
            : periodRevenue / orders.length,
      },
      'top_products': topProducts,
      'high_stock_products': highStockProducts.take(10).toList(),
      'slow_products': slowProducts,
      'suggestions': _buildLocalSuggestions(
        topProducts,
        highStockProducts,
        slowProducts,
      ),
      'revenue_chart': revenueChart,
    };
  }

  Future<List<Order>> _fetchFilteredOrderDetails() async {
    try {
      final orders = await ApiService.fetchOrders();
      final filtered = orders.where(_isOrderInSelectedRange).toList();
      final detailed = await Future.wait(
        filtered.map((order) => ApiService.fetchOrderDetail(order.id)),
      );
      return detailed.where((order) => order.items.isNotEmpty).toList();
    } catch (error) {
      debugPrint('[performance] legacy order detail fallback failed: $error');
      return const [];
    }
  }

  bool _isOrderInSelectedRange(Order order) {
    final date = order.orderDate;
    final now = DateTime.now();
    switch (_range) {
      case _PerformanceRange.today:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case _PerformanceRange.sevenDays:
        return date.isAfter(now.subtract(const Duration(days: 7)));
      case _PerformanceRange.thirtyDays:
        return date.isAfter(now.subtract(const Duration(days: 30)));
      case _PerformanceRange.month:
        return date.year == _selectedMonth.year &&
            date.month == _selectedMonth.month;
    }
  }

  List<Map<String, dynamic>> _productsFromOrders(
    List<Map<String, dynamic>> allProducts,
    List<Order> orders,
  ) {
    final byId = <String, Map<String, dynamic>>{
      for (final product in allProducts)
        (product['product_id'] ?? product['id'] ?? '').toString():
            Map<String, dynamic>.from(product),
    };
    final result = <String, Map<String, dynamic>>{};
    for (final product in allProducts) {
      final clone = Map<String, dynamic>.from(product);
      clone['total_quantity_sold'] = 0;
      clone['total_revenue'] = 0;
      clone['orders_count'] = 0;
      clone['days_without_order'] = 999;
      result[(clone['product_id'] ?? clone['id'] ?? '').toString()] = clone;
    }

    final productOrderIds = <String, Set<String>>{};
    final lastSoldAt = <String, DateTime>{};
    for (final order in orders) {
      for (final item in order.items) {
        final product =
            result[item.productId] ??
            Map<String, dynamic>.from(byId[item.productId] ?? const {});
        product['product_id'] ??= item.productId;
        product['product_name'] = (product['product_name'] ?? item.productName)
            .toString();
        product['total_quantity_sold'] =
            _toInt(product['total_quantity_sold']) + item.quantity;
        product['total_revenue'] =
            _toDouble(product['total_revenue']) +
            item.quantity * item.pricePerUnit;
        result[item.productId] = product;
        productOrderIds
            .putIfAbsent(item.productId, () => <String>{})
            .add(order.id);
        final currentLast = lastSoldAt[item.productId];
        if (currentLast == null || order.orderDate.isAfter(currentLast)) {
          lastSoldAt[item.productId] = order.orderDate;
        }
      }
    }

    final now = DateTime.now();
    for (final entry in result.entries) {
      entry.value['orders_count'] = productOrderIds[entry.key]?.length ?? 0;
      final last = lastSoldAt[entry.key];
      entry.value['days_without_order'] = last == null
          ? 999
          : now.difference(last).inDays;
    }
    return result.values.toList();
  }

  List<Map<String, dynamic>> _chartFromOrders(List<Order> orders) {
    final buckets = <String, Map<String, dynamic>>{};
    for (final order in orders) {
      final key =
          '${order.orderDate.year.toString().padLeft(4, '0')}-${order.orderDate.month.toString().padLeft(2, '0')}-${order.orderDate.day.toString().padLeft(2, '0')}';
      final bucket = buckets.putIfAbsent(
        key,
        () => {'period': key, 'revenue': 0.0, 'orders_count': 0},
      );
      bucket['revenue'] = _toDouble(bucket['revenue']) + order.totalAmount;
      bucket['orders_count'] = _toInt(bucket['orders_count']) + 1;
    }
    final rows = buckets.values.toList()
      ..sort(
        (a, b) => a['period'].toString().compareTo(b['period'].toString()),
      );
    return rows;
  }

  List<Map<String, dynamic>> _filterLegacyRevenueRows(
    List<Map<String, dynamic>> rows,
  ) {
    return rows.where((row) {
      final raw = row['period'];
      final date = DateTime.tryParse(raw?.toString() ?? '');
      if (date == null) return true;
      return _isOrderInSelectedRange(
        Order(
          id: '',
          orderDate: date,
          totalAmount: _toDouble(row['revenue']),
          customerName: '',
          status: '',
          items: const [],
        ),
      );
    }).toList();
  }

  int _estimateOrders(List<Map<String, dynamic>> rows) {
    return rows.fold<int>(0, (sum, row) => sum + _toInt(row['orders_count']));
  }

  List<Map<String, dynamic>> _buildLocalSuggestions(
    List<Map<String, dynamic>> topProducts,
    List<Map<String, dynamic>> highStockProducts,
    List<Map<String, dynamic>> slowProducts,
  ) {
    final suggestions = <Map<String, dynamic>>[];
    for (final product in slowProducts.take(3)) {
      if (_toInt(product['current_stock']) >= 50) {
        suggestions.add({
          'title': '${_productName(product)} tồn kho cao nhưng bán chậm',
          'message':
              'Nên tạo voucher hoặc chương trình xả kho cho sản phẩm này.',
          'severity': 'warning',
        });
      }
    }
    for (final product in topProducts.take(3)) {
      if (_toInt(product['current_stock']) <=
          (_toInt(product['min_stock']) == 0
              ? 10
              : _toInt(product['min_stock']))) {
        suggestions.add({
          'title': '${_productName(product)} đang bán tốt, nên nhập thêm hàng',
          'message': 'Sản phẩm có doanh số cao và tồn kho đang thấp.',
          'severity': 'success',
        });
      }
    }
    if (suggestions.isEmpty) {
      suggestions.add({
        'title': 'Hiệu suất sản phẩm đang ổn định',
        'message':
            'Chưa phát hiện sản phẩm cần xử lý gấp theo tồn kho và doanh số.',
        'severity': 'info',
      });
    }
    return suggestions;
  }

  String get _rangeApiValue {
    switch (_range) {
      case _PerformanceRange.today:
        return 'today';
      case _PerformanceRange.sevenDays:
        return '7days';
      case _PerformanceRange.thirtyDays:
        return '30days';
      case _PerformanceRange.month:
        return 'month';
    }
  }

  void _reload() {
    setState(() {
      _future = _loadData();
    });
  }

  void _setRange(_PerformanceRange value) {
    setState(() {
      _range = value;
      _future = _loadData();
    });
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
      _range = _PerformanceRange.month;
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

  static List<Map<String, dynamic>> _list(dynamic value) {
    return ((value as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static String _formatCurrency(num amount) {
    return '${amount.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VNĐ';
  }

  static String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  static String _dateLabel(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return raw?.toString() ?? '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  String _productName(Map<String, dynamic> product) {
    final name = (product['product_name'] ?? '').toString().trim();
    return name.isEmpty ? 'Sản phẩm chưa đặt tên' : name;
  }

  Widget _buildFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_PerformanceRange>(
            showSelectedIcon: false,
            selected: {_range},
            onSelectionChanged: (value) => _setRange(value.first),
            segments: const [
              ButtonSegment(
                value: _PerformanceRange.today,
                icon: Icon(Icons.today_outlined),
                label: Text('Hôm nay'),
              ),
              ButtonSegment(
                value: _PerformanceRange.sevenDays,
                icon: Icon(Icons.date_range_outlined),
                label: Text('7 ngày'),
              ),
              ButtonSegment(
                value: _PerformanceRange.thirtyDays,
                icon: Icon(Icons.calendar_view_week_outlined),
                label: Text('30 ngày'),
              ),
              ButtonSegment(
                value: _PerformanceRange.month,
                icon: Icon(Icons.calendar_month_outlined),
                label: Text('Theo tháng'),
              ),
            ],
          ),
        ),
        if (_range == _PerformanceRange.month) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Tháng trước',
              ),
              Expanded(
                child: Text(
                  'Tháng ${_selectedMonth.month}/${_selectedMonth.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Tháng sau',
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildOverview(Map<String, dynamic> overview) {
    final cards = [
      _MetricCard(
        title: 'Tổng doanh thu',
        value: _formatCurrency(_toDouble(overview['total_revenue'])),
        subtitle: 'Theo bộ lọc hiện tại',
        icon: Icons.payments_outlined,
        color: Colors.orange.shade700,
      ),
      _MetricCard(
        title: 'Tổng đơn hàng',
        value: '${_toInt(overview['total_orders'])}',
        subtitle: 'Đơn đã thanh toán',
        icon: Icons.receipt_long_outlined,
        color: Colors.indigo,
      ),
      _MetricCard(
        title: 'Đã bán',
        value: '${_toInt(overview['total_products_sold'])}',
        subtitle: 'Tổng sản phẩm',
        icon: Icons.shopping_cart_checkout_outlined,
        color: _primary,
      ),
      _MetricCard(
        title: 'Tồn kho',
        value: '${_toInt(overview['total_stock'])}',
        subtitle: 'Sản phẩm còn trong kho',
        icon: Icons.warehouse_outlined,
        color: Colors.blueGrey,
      ),
      _MetricCard(
        title: 'Giá trị TB/đơn',
        value: _formatCurrency(_toDouble(overview['average_order_value'])),
        subtitle: 'Average order value',
        icon: Icons.trending_up_outlined,
        color: Colors.blue.shade700,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 520
            ? 2
            : 2;
        final ratio = constraints.maxWidth < 380 ? 1.15 : 1.45;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: constraints.maxWidth >= 900 ? 2.2 : ratio,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: cards,
        );
      },
    );
  }

  Widget _buildRevenueChart(List<Map<String, dynamic>> rows) {
    final maxRevenue = rows.fold<double>(0, (max, row) {
      final value = _toDouble(row['revenue']);
      return value > max ? value : max;
    });
    final interval = maxRevenue <= 0 ? 1.0 : (maxRevenue / 4).ceilToDouble();

    return _SectionCard(
      title: 'Biểu đồ doanh thu',
      trailing: Text(
        '${rows.length} mốc',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      child: SizedBox(
        height: 260,
        child: rows.isEmpty
            ? const _EmptyState(
                icon: Icons.bar_chart_outlined,
                message: 'Chưa có dữ liệu doanh thu trong kỳ này.',
              )
            : BarChart(
                BarChartData(
                  maxY: maxRevenue <= 0 ? 1 : maxRevenue * 1.18,
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: rows.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: _toDouble(entry.value['revenue']),
                          width: rows.length > 20 ? 8 : 14,
                          color: _primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (value) =>
                        FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: interval,
                        getTitlesWidget: (value, meta) {
                          if (value <= 0) return const SizedBox.shrink();
                          return Text(
                            _compactCurrency(value),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= rows.length) {
                            return const SizedBox.shrink();
                          }
                          if (rows.length > 12 && index % 3 != 0) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8,
                            child: Text(
                              _dateLabel(rows[index]['period']),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final row = rows[group.x.toInt()];
                        return BarTooltipItem(
                          '${_dateLabel(row['period'])}\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          children: [
                            TextSpan(
                              text: _formatCurrency(_toDouble(row['revenue'])),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  static String _compactCurrency(num value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)} tỷ';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)} tr';
    }
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.round().toString();
  }

  Widget _buildTopProducts(List<Map<String, dynamic>> products) {
    final maxSold = products.fold<int>(0, (max, product) {
      final sold = _toInt(product['total_quantity_sold']);
      return sold > max ? sold : max;
    });
    return _SectionCard(
      title: 'Top sản phẩm bán chạy',
      trailing: Text(
        'Top ${products.length}',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      child: products.isEmpty
          ? const _EmptyState(
              icon: Icons.shopping_bag_outlined,
              message: 'Chưa có sản phẩm bán chạy trong kỳ này.',
            )
          : Column(
              children: products.take(10).toList().asMap().entries.map((entry) {
                return _RankedProductTile(
                  rank: entry.key + 1,
                  product: entry.value,
                  maxSold: maxSold,
                  name: _productName(entry.value),
                  onTap: () => _openDetail(entry.value, entry.key + 1),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildHighStock(List<Map<String, dynamic>> products) {
    return _SectionCard(
      title: 'Sản phẩm tồn kho cao',
      trailing: const _StatusBadge(label: 'Ngưỡng > 50', color: Colors.orange),
      child: products.isEmpty
          ? const _EmptyState(
              icon: Icons.inventory_2_outlined,
              message: 'Không có sản phẩm tồn kho cao.',
            )
          : Column(
              children: products
                  .take(8)
                  .map(
                    (product) => _AlertProductTile(
                      product: product,
                      name: _productName(product),
                      badge: 'Tồn cao',
                      badgeColor: Colors.orange,
                      titleValue: 'Tồn ${_toInt(product['current_stock'])}',
                      subtitle:
                          'Đã bán ${_toInt(product['total_quantity_sold'])}',
                      onTap: () => _openDetail(product, null),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildSlowProducts(List<Map<String, dynamic>> products) {
    return _SectionCard(
      title: 'Sản phẩm bán chậm',
      trailing: const _StatusBadge(label: 'Sold < 5', color: Colors.red),
      child: products.isEmpty
          ? const _EmptyState(
              icon: Icons.speed_outlined,
              message: 'Không có sản phẩm bán chậm trong kỳ này.',
            )
          : Column(
              children: products
                  .take(8)
                  .map(
                    (product) => _AlertProductTile(
                      product: product,
                      name: _productName(product),
                      badge: _slowBadge(product),
                      badgeColor: Colors.red,
                      titleValue:
                          'Đã bán ${_toInt(product['total_quantity_sold'])}',
                      subtitle:
                          '${_toInt(product['days_without_order'])} ngày chưa phát sinh đơn',
                      onTap: () => _openDetail(product, null),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  String _slowBadge(Map<String, dynamic> product) {
    final stock = _toInt(product['current_stock']);
    if (stock > 50) return 'Cần xả kho';
    if (stock > 20) return 'Nên giảm giá';
    return 'Bán chậm';
  }

  Widget _buildSuggestions(List<Map<String, dynamic>> suggestions) {
    return _SectionCard(
      title: 'Đề xuất thông minh',
      child: suggestions.isEmpty
          ? const _EmptyState(
              icon: Icons.lightbulb_outline,
              message: 'Chưa có đề xuất trong kỳ này.',
            )
          : Column(
              children: suggestions
                  .map(
                    (item) => _SuggestionTile(
                      title: (item['title'] ?? '').toString(),
                      message: (item['message'] ?? '').toString(),
                      severity: (item['severity'] ?? 'info').toString(),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  void _openDetail(Map<String, dynamic> product, int? rank) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _ProductPerformanceDetailScreen(product: product, rank: rank),
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
                  : 'Không tải được dashboard hiệu suất sản phẩm',
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return _buildError(snapshot.error!);

          final data = snapshot.data ?? const <String, dynamic>{};
          final overview = Map<String, dynamic>.from(
            (data['overview'] as Map?) ?? const {},
          );
          final topProducts = _list(data['top_products']);
          final highStock = _list(data['high_stock_products']);
          final slowProducts = _list(data['slow_products']);
          final suggestions = _list(data['suggestions']);
          final revenueChart = _list(data['revenue_chart']);

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Dashboard phân tích bán hàng',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Theo dõi doanh thu, tốc độ bán, tồn kho và đề xuất xử lý sản phẩm.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Bộ lọc thời gian',
                  child: _buildFilterBar(),
                ),
                const SizedBox(height: 14),
                _buildOverview(overview),
                const SizedBox(height: 14),
                _buildRevenueChart(revenueChart),
                const SizedBox(height: 14),
                _buildTopProducts(topProducts),
                const SizedBox(height: 14),
                _buildHighStock(highStock),
                const SizedBox(height: 14),
                _buildSlowProducts(slowProducts),
                const SizedBox(height: 14),
                _buildSuggestions(suggestions),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProductPerformanceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> product;
  final int? rank;

  const _ProductPerformanceDetailScreen({required this.product, this.rank});

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

  String _productName() {
    final name = (product['product_name'] ?? '').toString().trim();
    return name.isEmpty ? 'Sản phẩm chưa đặt tên' : name;
  }

  @override
  Widget build(BuildContext context) {
    final sold = _toInt(product['total_quantity_sold']);
    final revenue = _toDouble(product['total_revenue']);
    final stock = _toInt(product['current_stock']);
    final ordersCount = _toInt(product['orders_count']);
    final unit = (product['unit'] ?? 'sp').toString();
    final salePrice = _toDouble(product['sale_price'] ?? product['price']);
    final daysWithoutOrder = _toInt(product['days_without_order']);

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
            child: SizedBox(
              height: 180,
              child: _ProductThumb(product: product, size: double.infinity),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rank != null) ...[
                _RankBadge(rank: rank!),
                const SizedBox(width: 12),
              ],
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final ratio = constraints.maxWidth < 380 ? 1.35 : 1.8;
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: ratio,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _MetricCard(
                    title: 'Đã bán',
                    value: '$sold $unit',
                    subtitle: 'Trong kỳ lọc',
                    icon: Icons.shopping_bag_outlined,
                    color: const Color(0xFF146C43),
                  ),
                  _MetricCard(
                    title: 'Doanh thu',
                    value: _formatCurrency(revenue),
                    subtitle: '$ordersCount đơn hàng',
                    icon: Icons.payments_outlined,
                    color: Colors.orange.shade700,
                  ),
                  _MetricCard(
                    title: 'Tồn kho',
                    value: '$stock $unit',
                    subtitle: 'Hiện tại',
                    icon: Icons.warehouse_outlined,
                    color: Colors.blueGrey,
                  ),
                  _MetricCard(
                    title: 'Giá bán',
                    value: salePrice <= 0
                        ? 'Chưa có'
                        : _formatCurrency(salePrice),
                    subtitle: 'Giá niêm yết',
                    icon: Icons.sell_outlined,
                    color: Colors.indigo,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Thông tin phân tích',
            child: Column(
              children: [
                _DetailRow('Số đơn', '$ordersCount'),
                _DetailRow('Số ngày không phát sinh đơn', '$daysWithoutOrder'),
                _DetailRow('Mã sản phẩm', '${product['product_id'] ?? '-'}'),
                _DetailRow('Mã vạch', '${product['barcode'] ?? '-'}'),
                _DetailRow('Danh mục', '${product['category_name'] ?? '-'}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Flexible(child: trailing!),
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
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
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
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

class _RankedProductTile extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> product;
  final int maxSold;
  final String name;
  final VoidCallback onTap;

  const _RankedProductTile({
    required this.rank,
    required this.product,
    required this.maxSold,
    required this.name,
    required this.onTap,
  });

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
    return '${amount.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VNĐ';
  }

  @override
  Widget build(BuildContext context) {
    final sold = _toInt(product['total_quantity_sold']);
    final progress = maxSold <= 0 ? 0.0 : sold / maxSold;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            _RankBadge(rank: rank),
            const SizedBox(width: 10),
            _ProductThumb(product: product, size: 52),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            _formatCurrency(
                              _toDouble(product['total_revenue']),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 7,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF146C43),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Đã bán $sold sản phẩm',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final String name;
  final String badge;
  final Color badgeColor;
  final String titleValue;
  final String subtitle;
  final VoidCallback onTap;

  const _AlertProductTile({
    required this.product,
    required this.name,
    required this.badge,
    required this.badgeColor,
    required this.titleValue,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: badgeColor.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            _ProductThumb(product: product, size: 50),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusBadge(label: badge, color: badgeColor),
                const SizedBox(height: 6),
                Text(
                  titleValue,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String title;
  final String message;
  final String severity;

  const _SuggestionTile({
    required this.title,
    required this.message,
    required this.severity,
  });

  Color get _color {
    switch (severity) {
      case 'success':
        return const Color(0xFF146C43);
      case 'warning':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  IconData get _icon {
    switch (severity) {
      case 'success':
        return Icons.trending_up_outlined;
      case 'warning':
        return Icons.warning_amber_outlined;
      default:
        return Icons.lightbulb_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: _color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: Colors.grey.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductThumb extends StatelessWidget {
  final Map<String, dynamic> product;
  final double size;

  const _ProductThumb({required this.product, required this.size});

  @override
  Widget build(BuildContext context) {
    final imageUrl = (product['image_url'] ?? '').toString();
    final resolvedUrl = imageUrl.startsWith('/')
        ? '${ApiService.baseUrl}$imageUrl'
        : imageUrl;
    final fallback = Container(
      width: size,
      height: size,
      color: const Color(0xFFE9F5EF),
      alignment: Alignment.center,
      child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF146C43)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: resolvedUrl.startsWith('http')
            ? Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              )
            : fallback,
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

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: Colors.black26, size: 38),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
