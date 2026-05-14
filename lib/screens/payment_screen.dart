import 'package:flutter/material.dart';
import 'dart:async';
import '../models/order.dart';
import '../models/order_line.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import '../services/voucher_service.dart';
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

  // Voucher variables
  int? _appliedVoucherId;
  double _discountAmount = 0;
  String? _voucherMessage;
  final TextEditingController _voucherController = TextEditingController();

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  Future<void> _applyVoucher(String voucherCode) async {
    try {
      final userId = DBService.settings().get('current_user_id') ?? 0;
      final result = await VoucherService.validateVoucher(
        code: voucherCode,
        orderTotal: widget.totalAmount,
        userId: userId as int,
      );

      if (mounted) {
        if (result['success']) {
          final data = result['data'];
          setState(() {
            _appliedVoucherId = data['id'];
            _discountAmount = data['discountAmount'] as double;
            _voucherMessage = 'Áp dụng mã ${data['code']} thành công!';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_voucherMessage ?? ''),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _appliedVoucherId = null;
            _discountAmount = 0;
            _voucherMessage = result['message'] ?? 'Mã voucher không hợp lệ';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_voucherMessage ?? ''),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appliedVoucherId = null;
          _discountAmount = 0;
          _voucherMessage = 'Lỗi: ${e.toString()}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi kiểm tra voucher: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeVoucher() {
    setState(() {
      _appliedVoucherId = null;
      _discountAmount = 0;
      _voucherMessage = null;
    });
  }

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

      final currentUserId = DBService.settings().get('current_user_id') as int?;
      final newOrder = Order(
        id: 'DH-${DateTime.now().microsecondsSinceEpoch}',
        orderDate: DateTime.now(),
        totalAmount: widget.totalAmount - _discountAmount,
        customerName: 'Khách lẻ',
        // Gán customerId = người đang đăng nhập để backend ghi user_vouchers đúng user
        customerId: currentUserId,
        status: 'Hoàn thành',
        items: orderLines,
        voucherId: _appliedVoucherId,
        discountAmount: _discountAmount,
      );

      // Nếu có voucher, gửi kèm; không thì dùng saveOrder
      if (_appliedVoucherId != null) {
        await DBService.saveOrderWithVoucher(
          newOrder,
          voucherId: _appliedVoucherId,
          discountAmount: _discountAmount,
          // Đảm bảo backend insert user_vouchers theo người đang đăng nhập
          userId: currentUserId is int ? currentUserId : null,
        ).timeout(_checkoutTimeout);
      } else {
        await DBService.saveOrder(newOrder).timeout(_checkoutTimeout);
      }
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
            totalAmount:
                '${(widget.totalAmount - _discountAmount).toStringAsFixed(0)} ₫',
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildInvoiceDetailsCard(),
            const SizedBox(height: 16),
            _buildVoucherCard(),
            const SizedBox(height: 16),
            _buildPaymentMethodCard(),
            const SizedBox(height: 24),
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
            if (_discountAmount > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Giảm giá:',
                    style: TextStyle(fontSize: 16, color: Colors.green),
                  ),
                  Text(
                    '-${_discountAmount.toStringAsFixed(0)} ₫',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Thành tiền:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${(widget.totalAmount - _discountAmount).toStringAsFixed(0)} ₫',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mã khuyến mãi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_appliedVoucherId != null)
                  TextButton.icon(
                    onPressed: _removeVoucher,
                    icon: const Icon(Icons.close),
                    label: const Text('Bỏ'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_appliedVoucherId != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _voucherMessage ?? 'Voucher đã áp dụng',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _voucherController,
                          enabled: _appliedVoucherId == null,
                          decoration: InputDecoration(
                            hintText: 'Nhập mã voucher',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              _applyVoucher(value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _appliedVoucherId != null
                            ? null
                            : () {
                                if (_voucherController.text.isNotEmpty) {
                                  _applyVoucher(_voucherController.text);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: const Text('Áp dụng'),
                      ),
                    ],
                  ),
                  if (_voucherMessage != null && _appliedVoucherId == null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _voucherMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ],
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
