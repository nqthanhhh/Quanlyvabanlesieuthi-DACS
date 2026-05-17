import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_line.dart';
import '../models/product.dart';
import '../services/db_service.dart';

class OrderDetailScreen extends StatelessWidget {
  final Order order;

  const OrderDetailScreen({super.key, required this.order});

  String _formatCurrency(num amount) {
    final text = amount.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return '$textđ';
  }

  String _formatDate(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  double _itemsSubtotal() {
    final subtotal = order.items.fold<double>(
      0,
      (sum, item) => sum + item.quantity * item.pricePerUnit,
    );
    if (subtotal > 0) return subtotal;
    return order.totalAmount + order.discountAmount;
  }

  int _totalQuantity() {
    return order.items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  Product? _productForLine(OrderLine item) {
    final products = DBService.products().values.cast<Product>();
    for (final product in products) {
      if (product.id == item.productId || product.barcode == item.productId) {
        return product;
      }
    }
    return null;
  }

  Color _statusColor() {
    final status = order.status.toLowerCase();
    if (status.contains('hoàn') ||
        status.contains('completed') ||
        status.contains('paid')) {
      return Colors.green;
    }
    if (status.contains('chờ') ||
        status.contains('đang') ||
        status.contains('pending') ||
        status.contains('processing')) {
      return Colors.orange;
    }
    if (status.contains('hủy') ||
        status.contains('từ chối') ||
        status.contains('cancel') ||
        status.contains('reject')) {
      return Colors.red;
    }
    return Colors.blueGrey;
  }

  String _paymentMethodLabel(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'cash':
        return 'Tiền mặt';
      case 'card':
        return 'Thẻ';
      case 'bank_transfer':
      case 'transfer':
        return 'Chuyển khoản';
      case 'momo':
        return 'MoMo';
      case 'cod':
        return 'COD';
      case 'ewallet':
        return 'Ví điện tử';
      default:
        return value == null || value.trim().isEmpty ? '-' : value;
    }
  }

  String _paymentStatusLabel(String? value) {
    switch ((value ?? '').toLowerCase()) {
      case 'paid':
      case 'success':
        return 'Đã thanh toán';
      case 'pending':
        return 'Chờ thanh toán';
      case 'failed':
        return 'Thanh toán lỗi';
      case 'refunded':
        return 'Đã hoàn tiền';
      default:
        return value == null || value.trim().isEmpty ? '-' : value;
    }
  }

  void _showInvoiceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Center(
            child: Text(
              'HÓA ĐƠN BÁN HÀNG',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                Text('Mã đơn: ${order.id}'),
                Text('Khách hàng: ${order.customerName}'),
                Text('Ngày: ${_formatDate(order.orderDate.toLocal())}'),
                const Divider(),
                ...order.items.map((item) {
                  final name = item.productName.isNotEmpty
                      ? item.productName
                      : 'Sản phẩm';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text('${item.quantity} x $name')),
                        Text(
                          _formatCurrency(item.quantity * item.pricePerUnit),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(),
                _invoiceLine('Tạm tính', _formatCurrency(_itemsSubtotal())),
                if (order.discountAmount > 0)
                  _invoiceLine(
                    'Giảm giá',
                    '-${_formatCurrency(order.discountAmount)}',
                  ),
                _invoiceLine(
                  'Tổng thanh toán',
                  _formatCurrency(order.totalAmount),
                  isEmphasis: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đang gửi lệnh in...')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.print, size: 18),
              label: const Text('In'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Chi tiết đơn hàng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOrderHeader(statusColor),
          const SizedBox(height: 14),
          _buildOrderSummary(),
          const SizedBox(height: 14),
          _buildOrderInfoCard(),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showInvoiceDialog(context),
              icon: const Icon(Icons.print, color: Colors.white),
              label: const Text(
                'In hóa đơn',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
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
    );
  }

  Widget _buildOrderHeader(Color statusColor) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đơn #${order.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(order.orderDate.toLocal()),
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            _statusPill(
              order.status.isEmpty ? 'Chưa có trạng thái' : order.status,
              statusColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tóm tắt đơn hàng',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            if (order.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('Đơn hàng chưa có dữ liệu sản phẩm.'),
                ),
              )
            else
              ...order.items.map(_summaryProductRow),
            const SizedBox(height: 8),
            _summaryLine(
              'Tổng (${_totalQuantity()} món)',
              _formatCurrency(_itemsSubtotal()),
              isEmphasis: true,
            ),
            if (order.discountAmount > 0) ...[
              const SizedBox(height: 18),
              _summaryLine(
                'Giảm giá',
                '-${_formatCurrency(order.discountAmount)}',
                valueColor: Colors.green.shade700,
              ),
            ],
            const SizedBox(height: 30),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formatCurrency(order.totalAmount),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryProductRow(OrderLine item) {
    final product = _productForLine(item);
    final name = item.productName.isNotEmpty
        ? item.productName
        : product?.name ?? 'Sản phẩm';
    final total = item.quantity * item.pricePerUnit;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _productThumbnail(product),
          const SizedBox(width: 12),
          Text(
            '${item.quantity} x',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatCurrency(total),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thông tin đơn hàng',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _infoLine(
              'Ghi chú',
              order.note?.trim().isNotEmpty == true ? order.note! : 'Không có',
            ),
            _infoLine('Mã đơn hàng', order.id),
            _infoLine(
              'Thời gian đặt hàng',
              _formatDate(order.orderDate.toLocal()),
            ),
            _infoLine('Thanh toán', _paymentMethodLabel(order.paymentMethod)),
            _infoLine(
              'Trạng thái thanh toán',
              _paymentStatusLabel(order.paymentStatus),
            ),
            _infoLine(
              'Nhận hàng',
              order.shippingAddress?.trim().isNotEmpty == true
                  ? order.shippingAddress!
                  : 'Tại cửa hàng',
            ),
          ],
        ),
      ),
    );
  }

  Widget _productThumbnail(Product? product) {
    final imageUrl = product?.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 52,
        height: 52,
        color: Colors.blue.shade50,
        child: imageUrl != null && imageUrl.startsWith('http')
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _productIcon(),
              )
            : _productIcon(),
      ),
    );
  }

  Widget _productIcon() {
    return Icon(Icons.shopping_bag_outlined, color: Colors.blue.shade700);
  }

  Widget _summaryLine(
    String label,
    String value, {
    bool isEmphasis = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isEmphasis ? Colors.black87 : Colors.black54,
                fontSize: isEmphasis ? 19 : 17,
                fontWeight: isEmphasis ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.black87,
              fontSize: isEmphasis ? 19 : 17,
              fontWeight: isEmphasis ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceLine(String label, String value, {bool isEmphasis = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isEmphasis ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isEmphasis ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
