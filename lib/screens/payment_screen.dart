import 'dart:async';

import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/order_line.dart';
import '../models/product.dart';
import '../models/voucher.dart';
import '../services/db_service.dart';
import '../services/voucher_service.dart';
import '../widgets/role_bottom_navigation_bar.dart';
import '../widgets/slide_page_route.dart';
import 'checkout_screen.dart';
import 'employee.dart';
import 'employee_confirm_orders_screen.dart';
import 'customer_vouchers_screen.dart';
import 'order_management_screen.dart';
import 'order_success_screen.dart';
import 'profile_route.dart';
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
  static const Color _primary = Color(0xFF1B7F4D);
  static const Color _accent = Color(0xFF2563EB);
  static const Color _surface = Color(0xFFF6F7F9);
  static const Color _ink = Color(0xFF111827);
  static const Duration _checkoutTimeout = Duration(seconds: 12);

  final TextEditingController _voucherController = TextEditingController();
  String? _selectedPaymentMethod;
  String? _voucherMessage;
  int? _appliedVoucherId;
  double _discountAmount = 0;
  bool _isLoadingSavedVouchers = true;
  List<Voucher> _savedVouchers = [];
  bool _isProcessing = false;
  bool _isApplyingVoucher = false;

  @override
  void initState() {
    super.initState();
    _loadSavedVouchers();
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  double get _finalTotal => widget.totalAmount - _discountAmount;

  String _formatCurrency(double amount) {
    return '${amount.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} VND';
  }

  Future<void> _loadSavedVouchers() async {
    final userId = DBService.currentUserId();
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _savedVouchers = [];
        _isLoadingSavedVouchers = false;
      });
      return;
    }

    final token = (DBService.settings().get('auth_token') ?? '').toString();
    final vouchers = await VoucherService.getUserVouchers(userId, token);
    if (!mounted) return;
    setState(() {
      _savedVouchers = vouchers;
      _isLoadingSavedVouchers = false;
    });
  }

  Future<void> _applyVoucher(String voucherCode) async {
    final code = voucherCode.trim();
    if (code.isEmpty || _isApplyingVoucher) return;

    setState(() => _isApplyingVoucher = true);
    try {
      final rawUserId = DBService.settings().get('current_user_id');
      final userId = rawUserId is int
          ? rawUserId
          : int.tryParse(rawUserId?.toString() ?? '') ?? 0;
      final result = await VoucherService.validateVoucher(
        code: code,
        orderTotal: widget.totalAmount,
        userId: userId,
      );

      if (!mounted) return;
      if (result['success'] == true) {
        final data = Map<String, dynamic>.from(result['data'] as Map);
        setState(() {
          _appliedVoucherId = NumberParser.toInt(data['id']);
          _discountAmount = NumberParser.toDouble(data['discountAmount']);
          _voucherMessage = 'Đã áp dụng mã ${data['code']}';
          _voucherController.text = data['code'].toString();
        });
        _showSnack(_voucherMessage!, success: true);
      } else {
        setState(() {
          _appliedVoucherId = null;
          _discountAmount = 0;
          _voucherMessage =
              result['message']?.toString() ?? 'Mã voucher không hợp lệ';
        });
        _showSnack(_voucherMessage!, success: false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _appliedVoucherId = null;
        _discountAmount = 0;
        _voucherMessage = 'Lỗi kiểm tra voucher';
      });
      _showSnack('Lỗi kiểm tra voucher: $e', success: false);
    } finally {
      if (mounted) setState(() => _isApplyingVoucher = false);
    }
  }

  void _removeVoucher() {
    setState(() {
      _appliedVoucherId = null;
      _discountAmount = 0;
      _voucherMessage = null;
      _voucherController.clear();
    });
  }

  void _showSnack(String message, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? _primary : Colors.red.shade700,
      ),
    );
  }

  String _paymentMethodLabel(String value) {
    switch (value) {
      case 'cash':
        return 'Tiền mặt';
      case 'bank':
        return 'Ngân hàng';
      case 'e_wallet':
        return 'Ví điện tử';
      default:
        return value;
    }
  }

  Future<void> _placeOrder() async {
    if (_isProcessing) return;

    if (_selectedPaymentMethod == null) {
      _showSnack('Vui lòng chọn phương thức thanh toán', success: false);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xác nhận thanh toán?'),
        content: Text(
          'Tạo hóa đơn tại quầy với tổng thanh toán ${_formatCurrency(_finalTotal)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final allProducts = DBService.getAllProducts();
      final orderLines = <OrderLine>[];
      for (final entry in widget.originalCart.entries) {
        final product = allProducts.firstWhere((p) => p.id == entry.key);
        if (entry.value > product.stockQuantity) {
          throw Exception('${product.name} không đủ tồn kho');
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
        totalAmount: _finalTotal,
        customerName: 'Khách lẻ',
        customerId: currentUserId,
        status: 'Hoàn thành',
        items: orderLines,
        voucherId: _appliedVoucherId,
        discountAmount: _discountAmount,
      );

      if (_appliedVoucherId != null) {
        await DBService.saveOrderWithVoucher(
          newOrder,
          voucherId: _appliedVoucherId,
          discountAmount: _discountAmount,
          userId: currentUserId is int ? currentUserId : null,
        ).timeout(_checkoutTimeout);
      } else {
        await DBService.saveOrder(newOrder).timeout(_checkoutTimeout);
      }
      widget.onCheckoutComplete();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        buildSlidePageRoute(
          OrderSuccessScreen(
            totalAmount: _formatCurrency(_finalTotal),
            paymentMethod: _paymentMethodLabel(_selectedPaymentMethod!),
          ),
        ),
      );
    } on TimeoutException {
      if (!mounted) return;
      _showSnack(
        'Thanh toán quá thời gian chờ. Vui lòng thử lại.',
        success: false,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceFirst('Exception: ', ''), success: false);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
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
          _showSnack(
            e.toString().replaceFirst('Exception: ', ''),
            success: false,
          );
        }
        break;
      case RoleBottomTab.invoices:
        Navigator.of(
          context,
        ).push(buildSlidePageRoute(OrderManagementScreen(role: widget.role)));
        break;
      case RoleBottomTab.confirmOrders:
        Navigator.of(
          context,
        ).push(buildSlidePageRoute(const EmployeeConfirmOrdersScreen()));
        break;
      case RoleBottomTab.account:
        Navigator.of(
          context,
        ).push(buildSlidePageRoute(buildProfileScreenForRole(widget.role)));
        break;
      case RoleBottomTab.employees:
        Navigator.of(context).push(
          buildSlidePageRoute(EmployeeManagementScreen(role: widget.role)),
        );
        break;
      case RoleBottomTab.offers:
        await Navigator.of(
          context,
        ).push(buildSlidePageRoute(const CustomerVouchersScreen()));
        if (!mounted) return;
        setState(() => _isLoadingSavedVouchers = true);
        await _loadSavedVouchers();
        break;
      case RoleBottomTab.orders:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        title: const Text(
          'Thanh toán tại quầy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _surface,
        foregroundColor: _ink,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final left = Column(
            children: [
              _header(),
              const SizedBox(height: 14),
              _invoiceCard(),
              const SizedBox(height: 14),
              _voucherCard(),
              const SizedBox(height: 14),
              _paymentMethodCard(),
            ],
          );
          final summary = _summaryCard();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: left),
                          const SizedBox(width: 16),
                          Expanded(flex: 4, child: summary),
                        ],
                      )
                    : Column(
                        children: [left, const SizedBox(height: 14), summary],
                      ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: RoleBottomNavigationBar(
        role: widget.role,
        currentTab: RoleBottomTab.cart,
        onTabSelected: _handleBottomTab,
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_primary, _accent]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.point_of_sale, color: Colors.white, size: 34),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hoàn tất thanh toán POS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Kiểm tra hóa đơn, áp dụng voucher và chọn phương thức thanh toán.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _invoiceCard() {
    return _sectionCard(
      title: 'Sản phẩm trong hóa đơn',
      subtitle: '${widget.cartForDisplay.length} dòng sản phẩm',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: widget.cartForDisplay.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'x${entry.value}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _voucherDiscountText(Voucher voucher) {
    if (voucher.discountType == 'percent') {
      final max = voucher.maxDiscount == null
          ? ''
          : ' tối đa ${_formatCurrency(voucher.maxDiscount!)}';
      return 'Giảm ${voucher.discountValue.toStringAsFixed(0)}%$max';
    }
    return 'Giảm ${_formatCurrency(voucher.discountValue)}';
  }

  Widget _savedVoucherList() {
    if (_isLoadingSavedVouchers) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_savedVouchers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Bạn chưa lưu voucher nào. Vào tab Ưu đãi để lấy mã.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Voucher đã lưu',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ..._savedVouchers.map(_savedVoucherTile),
      ],
    );
  }

  Widget _savedVoucherTile(Voucher voucher) {
    final canUse = voucher.isValid(widget.totalAmount);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: canUse ? Colors.blue.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: canUse ? Colors.blue.shade100 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_offer_outlined,
            color: canUse ? _accent : Colors.black38,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  voucher.code,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  voucher.minOrderAmount > widget.totalAmount
                      ? 'Cần đơn từ ${_formatCurrency(voucher.minOrderAmount)}'
                      : _voucherDiscountText(voucher),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: canUse ? () => _applyVoucher(voucher.code) : null,
            child: const Text('Dùng'),
          ),
        ],
      ),
    );
  }

  Widget _voucherCard() {
    return _sectionCard(
      title: 'Mã ưu đãi',
      subtitle: 'Áp dụng voucher riêng cho hóa đơn tại quầy',
      icon: Icons.local_offer_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _voucherController,
                  enabled: _appliedVoucherId == null && !_isApplyingVoucher,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'Nhập mã voucher',
                    filled: true,
                    fillColor: _surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: _applyVoucher,
                ),
              ),
              const SizedBox(width: 8),
              if (_appliedVoucherId == null)
                ElevatedButton(
                  onPressed: _isApplyingVoucher
                      ? null
                      : () => _applyVoucher(_voucherController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isApplyingVoucher
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Áp dụng'),
                )
              else
                TextButton(onPressed: _removeVoucher, child: const Text('Bỏ')),
            ],
          ),
          if (_voucherMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _voucherMessage!,
              style: TextStyle(
                color: _appliedVoucherId != null
                    ? _primary
                    : Colors.red.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          _savedVoucherList(),
        ],
      ),
    );
  }

  Widget _paymentMethodCard() {
    return _sectionCard(
      title: 'Phương thức thanh toán',
      subtitle: 'Chọn cách khách thanh toán tại quầy',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          _paymentOption(
            icon: Icons.money,
            title: 'Tiền mặt',
            subtitle: 'Thu tiền trực tiếp tại quầy.',
            value: 'cash',
          ),
          const SizedBox(height: 10),
          _paymentOption(
            icon: Icons.account_balance,
            title: 'Ngân hàng',
            subtitle: 'Chuyển khoản hoặc quẹt thẻ.',
            value: 'bank',
          ),
          const SizedBox(height: 10),
          _paymentOption(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Ví điện tử',
            subtitle: 'Thanh toán bằng ví điện tử của khách.',
            value: 'e_wallet',
          ),
        ],
      ),
    );
  }

  Widget _paymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    final selected = _selectedPaymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _primary.withValues(alpha: 0.08) : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _primary : Colors.black.withValues(alpha: 0.06),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _primary : Colors.black54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _primary : Colors.transparent,
                border: Border.all(
                  color: selected ? _primary : Colors.black26,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tóm tắt hóa đơn',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          _moneyRow('Tạm tính', widget.totalAmount),
          if (_discountAmount > 0) _moneyRow('Giảm giá', -_discountAmount),
          const Divider(height: 24),
          _moneyRow('Tổng thanh toán', _finalTotal, isTotal: true),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_outlined, color: _accent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hóa đơn POS hoàn thành ngay sau khi xác nhận thanh toán.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isProcessing || _selectedPaymentMethod == null
                  ? null
                  : _placeOrder,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isProcessing ? 'Đang thanh toán...' : 'Xác nhận thanh toán',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moneyRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? _ink : Colors.black.withValues(alpha: 0.62),
              fontSize: isTotal ? 17 : 15,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              color: isTotal ? _primary : _ink,
              fontSize: isTotal ? 20 : 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class NumberParser {
  static int? toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
