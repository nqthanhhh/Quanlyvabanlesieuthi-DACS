import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/db_service.dart';

class EmployeeConfirmOrdersScreen extends StatefulWidget {
  const EmployeeConfirmOrdersScreen({super.key});

  @override
  State<EmployeeConfirmOrdersScreen> createState() =>
      _EmployeeConfirmOrdersScreenState();
}

class _EmployeeConfirmOrdersScreenState
    extends State<EmployeeConfirmOrdersScreen> {
  static const Color _primary = Color(0xFF2563EB);
  static const Color _surface = Color(0xFFF6F7F9);
  static const Color _success = Color(0xFF16A34A);
  static const Color _danger = Color(0xFFDC2626);

  bool _isLoading = true;
  String? _error;
  String? _busyOrderId;
  String? _busyAction;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  int? _currentEmployeeId() {
    final raw = DBService.settings().get('current_user_id');
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final employeeId = _currentEmployeeId();
      if (employeeId == null) {
        throw ApiException('Không tìm thấy nhân viên hiện tại');
      }
      final orders = await ApiService.fetchPendingOrders(employeeId);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _isLoading = false;
      });
    }
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String actionLabel,
    Color actionColor = _primary,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<String?> _rejectReasonDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Từ chối đơn hàng'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Lý do từ chối (không bắt buộc)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _confirmOrder(Map<String, dynamic> order) async {
    final employeeId = _currentEmployeeId();
    final orderId = (order['order_id'] ?? order['id']).toString();
    if (employeeId == null || orderId.isEmpty) return;

    final accepted = await _confirmDialog(
      title: 'Xác nhận đơn #$orderId?',
      message: 'Đơn hàng sẽ được chuyển sang trạng thái đã xác nhận.',
      actionLabel: 'Xác nhận',
      actionColor: _success,
    );
    if (!accepted || !mounted) return;

    setState(() {
      _busyOrderId = orderId;
      _busyAction = 'confirm';
    });
    try {
      await ApiService.confirmOrder(employeeId: employeeId, orderId: orderId);
      await _loadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xác nhận đơn hàng')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyOrderId = null;
          _busyAction = null;
        });
      }
    }
  }

  Future<void> _rejectOrder(Map<String, dynamic> order) async {
    final employeeId = _currentEmployeeId();
    final orderId = (order['order_id'] ?? order['id']).toString();
    if (employeeId == null || orderId.isEmpty) return;

    final reason = await _rejectReasonDialog();
    if (reason == null || !mounted) return;

    final accepted = await _confirmDialog(
      title: 'Từ chối đơn #$orderId?',
      message: 'Khách hàng sẽ thấy trạng thái bị từ chối và lý do nếu có.',
      actionLabel: 'Từ chối',
      actionColor: _danger,
    );
    if (!accepted || !mounted) return;

    setState(() {
      _busyOrderId = orderId;
      _busyAction = 'reject';
    });
    try {
      await ApiService.rejectOrder(
        employeeId: employeeId,
        orderId: orderId,
        reason: reason,
      );
      await _loadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã từ chối đơn hàng')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is ApiException ? e.message : e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyOrderId = null;
          _busyAction = null;
        });
      }
    }
  }

  String _formatCurrency(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '0') ?? 0;
    return '${amount.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} VND';
  }

  String _label(dynamic value, {String fallback = 'Chưa có'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _orderTypeLabel(String type) {
    switch (type) {
      case 'store_pickup':
        return 'Nhận tại cửa hàng';
      case 'delivery':
        return 'Giao hàng';
      case 'online':
        return 'Online';
      default:
        return type.isEmpty ? 'Online' : type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text('Xác nhận đơn online'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadOrders,
            icon: const Icon(Icons.refresh),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadOrders,
                    child: const Text('Thử lại'),
                  ),
                ],
              )
            : _orders.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 160),
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 54,
                    color: Colors.black26,
                  ),
                  SizedBox(height: 12),
                  Center(child: Text('Không có đơn chờ xử lý')),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _orders.length,
                itemBuilder: (context, index) => _orderCard(_orders[index]),
              ),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final orderId = (order['order_id'] ?? order['id']).toString();
    final items = ((order['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final orderType = _label(order['order_type'], fallback: 'online');
    final isBusy = _busyOrderId == orderId;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Đơn #$orderId',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _statusPill('Đang chờ', const Color(0xFFF59E0B)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              runSpacing: 8,
              spacing: 10,
              children: [
                _metaChip(Icons.person_outline, _label(order['customer_name'])),
                _metaChip(
                  Icons.storefront_outlined,
                  _orderTypeLabel(orderType),
                ),
                _metaChip(
                  Icons.payments_outlined,
                  _label(order['payment_method']),
                ),
                _metaChip(
                  Icons.location_on_outlined,
                  _label(
                    order['shipping_address'],
                    fallback: 'Nhận tại cửa hàng',
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            ...items.map(_itemRow),
            const Divider(height: 26),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tổng tiền',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  _formatCurrency(
                    order['final_amount'] ?? order['totalAmount'],
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B7F4D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : () => _rejectOrder(order),
                    icon: isBusy && _busyAction == 'reject'
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close_rounded),
                    label: const Text('Từ chối'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _danger,
                      side: const BorderSide(color: _danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isBusy ? null : () => _confirmOrder(order),
                    icon: isBusy && _busyAction == 'confirm'
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text('Xác nhận'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _itemRow(Map<String, dynamic> item) {
    final name = _label(item['product_name'] ?? item['productName']);
    final quantity = item['quantity'] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text('x$quantity'),
          const SizedBox(width: 12),
          Text(
            _formatCurrency(item['subtotal']),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
