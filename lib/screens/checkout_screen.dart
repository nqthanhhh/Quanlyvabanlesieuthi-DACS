// lib/screens/checkout_screen.dart
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/db_service.dart';
import './payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, int> cart;
  final VoidCallback onCheckoutComplete;

  const CheckoutScreen({
    super.key,
    required this.cart,
    required this.onCheckoutComplete,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  double _calculateTotal(List<Product> allProducts) {
    double total = 0;
    for (var entry in widget.cart.entries) {
      final product = allProducts.firstWhere((p) => p.id == entry.key);
      total += product.price * entry.value;
    }
    return total;
  }

  void _navigateToPaymentScreen() {
    final List<Product> allProducts = DBService.getAllProducts();
    final double total = _calculateTotal(allProducts);

    // Chuẩn bị giỏ hàng để hiển thị (tên sản phẩm)
    final Map<String, int> detailedCart = {};
    for (var entry in widget.cart.entries) {
      final product = allProducts.firstWhere((p) => p.id == entry.key);
      detailedCart[product.name] = entry.value;
    }

    // Điều hướng và truyền tất cả các tham số cần thiết
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          cartForDisplay: detailedCart,        // Giỏ hàng để hiển thị
          originalCart: widget.cart,         // Giỏ hàng gốc để xử lý logic
          totalAmount: total,
          onCheckoutComplete: widget.onCheckoutComplete, // Truyền callback
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Product> allProducts = DBService.getAllProducts();
    final double total = _calculateTotal(allProducts);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giỏ Hàng', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: widget.cart.entries.map((entry) {
                final product = allProducts.firstWhere((p) => p.id == entry.key);
                return ListTile(
                  title: Text(product.name),
                  subtitle: Text('${product.price.toStringAsFixed(0)} ₫ x ${entry.value}'),
                  trailing: Text(
                    '${(product.price * entry.value).toStringAsFixed(0)} ₫',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
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
                        const Text('Tổng cộng:', style: TextStyle(fontSize: 18)),
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
                      onPressed: _navigateToPaymentScreen,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Đến trang thanh toán',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}