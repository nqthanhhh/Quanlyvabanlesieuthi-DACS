// lib/screens/payment_screen.dart
import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/order_line.dart';
import '../models/product.dart';
import '../services/db_service.dart';
import 'order_success_screen.dart'; // Import màn hình thành công

class PaymentScreen extends StatefulWidget {
  final Map<String, int> cartForDisplay;
  final Map<String, int> originalCart;
  final double totalAmount;
  final VoidCallback onCheckoutComplete;

  const PaymentScreen({
    super.key,
    required this.cartForDisplay,
    required this.originalCart,
    required this.totalAmount,
    required this.onCheckoutComplete,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _selectedPaymentMethod;
  bool _isProcessing = false;

  Future<void> _placeOrder() async {
    if (_selectedPaymentMethod == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn phương thức thanh toán!'),
          ),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    // 1. Kiểm tra tồn kho và chuẩn bị đơn hàng
    final List<Product> allProducts = DBService.getAllProducts();
    final List<OrderLine> orderLines = [];
    for (var entry in widget.originalCart.entries) {
      final product = allProducts.firstWhere((p) => p.id == entry.key);
      if (entry.value > product.stockQuantity) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: ${product.name} không đủ tồn kho!')),
          );
        }
        setState(() => _isProcessing = false);
        return;
      }
      orderLines.add(
        OrderLine(
          productId: product.id,
          productName: product.name,
          quantity: entry.value,
          pricePerUnit: product.price,
        ),
      );
    }

    // 2. Tạo và lưu đơn hàng
    final newOrder = Order(
      id: 'DH-${DateTime.now().microsecondsSinceEpoch}',
      orderDate: DateTime.now(),
      totalAmount: widget.totalAmount,
      customerName: 'Khách lẻ',
      status: 'Hoàn thành',
      items: orderLines,
      // paymentMethod: _selectedPaymentMethod,
    );
    await DBService.saveOrder(newOrder);

    // 3. Xóa giỏ hàng
    widget.onCheckoutComplete();
    setState(() => _isProcessing = false);

    // 4. Điều hướng đến màn hình thành công
    if (mounted) {
      // Chuyển đổi paymentMethod thành chuỗi tiếng Việt
      String paymentMethodString = _selectedPaymentMethod == 'cash'
          ? 'Tiền mặt'
          : _selectedPaymentMethod == 'bank'
          ? 'Ngân hàng'
          : 'Ví điện tử';

      // Thay vì xóa toàn bộ stack (vì làm mất trạng thái tài khoản),
      // ta chỉ thay thế màn hình Payment bằng OrderSuccess để giữ
      // Home/Checkout trong stack (và giữ state của tài khoản hiện tại).
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderSuccessScreen(
            totalAmount: '${widget.totalAmount.toStringAsFixed(0)} ₫',
            paymentMethod: paymentMethodString,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Thanh toán',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _buildInvoiceDetailsCard(),
          const SizedBox(height: 16),
          _buildPaymentMethodCard(),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              height: 50,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing || _selectedPaymentMethod == null
                    ? null
                    : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5C6BC0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      )
                    : const Text(
                        'Xác nhận thanh toán',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceDetailsCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chi tiết hóa đơn',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24, thickness: 1),
            ...widget.cartForDisplay.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      'x${entry.value}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              );
            }).toList(),
            const Divider(height: 24, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tổng cộng:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${widget.totalAmount.toStringAsFixed(0)} ₫',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phương thức thanh toán',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildPaymentOption(
              icon: Icons.money,
              title: 'Tiền mặt',
              value: 'cash',
            ),
            _buildPaymentOption(
              icon: Icons.account_balance,
              title: 'Ngân hàng',
              value: 'bank',
            ),
            _buildPaymentOption(
              icon: Icons.wallet,
              title: 'Ví điện tử',
              value: 'e_wallet',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: _selectedPaymentMethod == value
          ? Colors.blue.shade50
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _selectedPaymentMethod == value
              ? Colors.blue.shade200
              : Colors.grey.shade300,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedPaymentMethod = value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16)),
              ),
              Radio<String>(
                value: value,
                groupValue: _selectedPaymentMethod,
                onChanged: (newValue) =>
                    setState(() => _selectedPaymentMethod = newValue),
                activeColor: Colors.blue.shade700,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
