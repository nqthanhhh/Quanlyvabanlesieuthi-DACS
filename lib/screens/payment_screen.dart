import 'package:flutter/material.dart';
import 'dart:async';
import '../models/order.dart';
import '../models/order_line.dart';
import '../models/product.dart';
import '../services/db_service.dart';
import '../widgets/role_bottom_navigation_bar.dart';
import '../widgets/slide_page_route.dart';
import 'employee.dart';
import 'order_management_screen.dart';
import 'order_success_screen.dart';
import 'profile_view_screen.dart';
import 'checkout_screen.dart';
import 'scan_product_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String role;
  final Map<String, int> cartForDisplay;
  final Map<String, int> originalCart;
  final double totalAmount;
  final VoidCallback onCheckoutComplete;

  const PaymentScreen({
    super.key,
    required this.role,
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
  static const Duration _checkoutTimeout = Duration(seconds: 12);

  Future<void> _placeOrder() async {
    if (_isProcessing) return;

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
    try {
      final List<Product> allProducts = DBService.getAllProducts();
      final List<OrderLine> orderLines = [];
      for (var entry in widget.originalCart.entries) {
        final product = allProducts.firstWhere((p) => p.id == entry.key);
        if (entry.value > product.stockQuantity) {
          throw Exception('Lỗi: ${product.name} không đủ tồn kho!');
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

      if (orderLines.isEmpty) {
        throw Exception('Giỏ hàng đang trống, không thể thanh toán.');
      }

      final newOrder = Order(
        id: 'DH-${DateTime.now().microsecondsSinceEpoch}',
        orderDate: DateTime.now(),
        totalAmount: widget.totalAmount,
        customerName: 'Khách lẻ',
        status: 'Hoàn thành',
        items: orderLines,
      );

      await DBService.saveOrder(newOrder).timeout(_checkoutTimeout);
      widget.onCheckoutComplete();

      if (!mounted) return;
      final paymentMethodString = _selectedPaymentMethod == 'cash'
          ? 'Tiền mặt'
          : _selectedPaymentMethod == 'bank'
          ? 'Ngân hàng'
          : 'Ví điện tử';

      Navigator.pushReplacement(
        context,
        buildSlidePageRoute(
          OrderSuccessScreen(
            totalAmount: '${widget.totalAmount.toStringAsFixed(0)} ₫',
            paymentMethod: paymentMethodString,
          ),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanh toán quá thời gian chờ. Vui lòng thử lại.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleBottomTab(RoleBottomTab tab) async {
    switch (tab) {
      case RoleBottomTab.home:
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      case RoleBottomTab.cart:
        Navigator.of(context).pop();
        break;
      case RoleBottomTab.scan:
        final product = await Navigator.of(
          context,
        ).push<Product?>(buildSlidePageRoute(const ScanProductScreen()));
        if (product == null || !mounted) return;
        try {
          final updatedCart = await DBService.addProductToCurrentCart(product);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            buildSlidePageRoute(
              CheckoutScreen(
                cart: updatedCart,
                role: widget.role,
                onCheckoutComplete: widget.onCheckoutComplete,
              ),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
            ),
          );
        }
        break;
      case RoleBottomTab.invoices:
        Navigator.of(
          context,
        ).push(buildSlidePageRoute(OrderManagementScreen(role: widget.role)));
        break;
      case RoleBottomTab.account:
        Navigator.of(
          context,
        ).push(buildSlidePageRoute(ProfileViewScreen(role: widget.role)));
        break;
      case RoleBottomTab.employees:
        Navigator.of(context).push(
          buildSlidePageRoute(EmployeeManagementScreen(role: widget.role)),
        );
        break;
      case RoleBottomTab.offers:
      case RoleBottomTab.orders:
        break;
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
      bottomNavigationBar: RoleBottomNavigationBar(
        role: widget.role,
        currentTab: RoleBottomTab.cart,
        onTabSelected: _handleBottomTab,
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
            }),
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
