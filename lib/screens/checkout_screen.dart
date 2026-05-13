// lib/screens/checkout_screen.dart
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import '../widgets/role_bottom_navigation_bar.dart';
import '../widgets/slide_page_route.dart';
import 'employee.dart';
import 'order_management_screen.dart';
import 'payment_screen.dart';
import 'profile_view_screen.dart';
import 'scan_product_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, int> cart;
  final String role;
  final VoidCallback onCheckoutComplete;

  const CheckoutScreen({
    super.key,
    required this.cart,
    required this.role,
    required this.onCheckoutComplete,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final Map<String, int> _editableCart;
  String? _currentUserEmail;

  @override
  void initState() {
    super.initState();
    _editableCart = Map<String, int>.from(widget.cart);
    _currentUserEmail = DBService.currentUserEmail();
  }

  Map<String, Product> _productById(List<Product> allProducts) {
    return {for (final product in allProducts) product.id: product};
  }

  Future<void> _persistEditableCart() async {
    final email = _currentUserEmail;
    if (email != null) {
      await DBService.saveCartForUser(email, _editableCart);
    }
  }

  double _calculateTotal(Map<String, Product> productsById) {
    double total = 0;
    for (var entry in _editableCart.entries) {
      final product = productsById[entry.key];
      if (product == null) continue;
      total += product.price * entry.value;
    }
    return total;
  }

  void _navigateToPaymentScreen() {
    if (_editableCart.isEmpty) return;

    final List<Product> allProducts = DBService.getAllProducts();
    final productsById = _productById(allProducts);
    _editableCart.removeWhere((id, quantity) {
      return quantity <= 0 || !productsById.containsKey(id);
    });
    if (_editableCart.isEmpty) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tìm thấy sản phẩm trong giỏ hàng')),
      );
      Future.microtask(_persistEditableCart);
      return;
    }
    final double total = _calculateTotal(productsById);

    final Map<String, int> detailedCart = {};
    for (var entry in _editableCart.entries) {
      final product = productsById[entry.key];
      if (product == null) continue;
      detailedCart[product.name] = entry.value;
    }

    Navigator.push(
      context,
      buildSlidePageRoute(
        PaymentScreen(
          role: widget.role,
          cartForDisplay: detailedCart,
          originalCart: Map<String, int>.from(_editableCart),
          totalAmount: total,
          onCheckoutComplete: widget.onCheckoutComplete,
        ),
      ),
    );
  }

  Future<void> _handleBottomTab(RoleBottomTab tab) async {
    if (tab == RoleBottomTab.cart) return;
    switch (tab) {
      case RoleBottomTab.home:
        Navigator.of(context).popUntil((route) => route.isFirst);
        break;
      case RoleBottomTab.scan:
        await _scanAndAppendProduct();
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
      case RoleBottomTab.cart:
        break;
    }
  }

  Future<void> _scanAndAppendProduct() async {
    final product = await Navigator.of(
      context,
    ).push<Product?>(buildSlidePageRoute(const ScanProductScreen()));
    if (product == null || !mounted) return;
    try {
      final currentQty = _editableCart[product.id] ?? 0;
      if (currentQty + 1 > product.stockQuantity) {
        throw ApiException('Không thể thêm quá số lượng tồn kho');
      }
      setState(() {
        _editableCart[product.id] = currentQty + 1;
      });
      await _persistEditableCart();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm ${product.name} vào giỏ hàng')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _increaseQty(Product product) {
    final currentQty = _editableCart[product.id] ?? 0;
    if (currentQty >= product.stockQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} đã đạt giới hạn tồn kho')),
      );
      return;
    }
    setState(() {
      _editableCart[product.id] = currentQty + 1;
    });
    Future.microtask(_persistEditableCart);
  }

  void _decreaseQty(Product product) {
    final currentQty = _editableCart[product.id] ?? 0;
    if (currentQty <= 1) {
      setState(() {
        _editableCart.remove(product.id);
      });
      Future.microtask(_persistEditableCart);
      return;
    }
    setState(() {
      _editableCart[product.id] = currentQty - 1;
    });
    Future.microtask(_persistEditableCart);
  }

  @override
  Widget build(BuildContext context) {
    final List<Product> allProducts = DBService.getAllProducts();
    final productsById = _productById(allProducts);
    final visibleEntries = _editableCart.entries
        .where((entry) => productsById.containsKey(entry.key))
        .toList();
    final double total = _calculateTotal(productsById);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Giỏ Hàng',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: visibleEntries.isEmpty
                ? const Center(
                    child: Text(
                      'Giỏ hàng trống',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: visibleEntries.length,
                    itemBuilder: (context, index) {
                      final entry = visibleEntries[index];
                      final product = productsById[entry.key]!;
                      final qty = entry.value;
                      final lineTotal = product.price * qty;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    '${product.price.toStringAsFixed(0)} ₫',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => _decreaseQty(product),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Text(
                                    '$qty',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _increaseQty(product),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${lineTotal.toStringAsFixed(0)} ₫',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tổng cộng:',
                          style: TextStyle(fontSize: 18),
                        ),
                        Text(
                          '${total.toStringAsFixed(0)} ₫',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: visibleEntries.isEmpty
                          ? null
                          : _navigateToPaymentScreen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Xác nhận đơn hàng',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
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
}
