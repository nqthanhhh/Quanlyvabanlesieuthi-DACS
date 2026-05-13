// lib/screens/checkout_online_screen.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/order.dart';
import '../models/order_line.dart';
import '../models/product.dart';
import '../services/db_service.dart';
import '../services/api_service.dart';
import 'package:collection/collection.dart';
import 'order_history_screen.dart';

class CheckoutOnlineScreen extends StatefulWidget {
  final String userEmail;
  final int? customerId;
  final VoidCallback? onCheckoutComplete; // callback để HomeScreen update

  const CheckoutOnlineScreen({
    super.key,
    required this.userEmail,
    this.customerId,
    this.onCheckoutComplete,
  });

  @override
  State<CheckoutOnlineScreen> createState() => _CheckoutOnlineScreenState();
}

class _CheckoutOnlineScreenState extends State<CheckoutOnlineScreen> {
  Map<String, int> cart = {};
  double totalAmount = 0;

  String deliveryOption = 'pickup'; // 'pickup' hoặc 'delivery'
  String paymentMethod = 'cash';    // 'cash' hoặc 'wallet'

  final TextEditingController addressController = TextEditingController();
  final TextEditingController voucherController = TextEditingController();

  bool isLoading = false;
  String? qrData;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    final loadedCart = await DBService.loadCartForCurrentUser(widget.userEmail);
    setState(() {
      cart = Map.from(loadedCart);
    });
    _calculateTotal();
  }

  void _calculateTotal() {
    double total = 0;
    cart.forEach((productId, qty) {
      final product = DBService.products().get(productId);
      if (product != null) total += product.price * qty;
    });
    // TODO: áp dụng voucher giảm giá
    setState(() => totalAmount = total);
  }

  Future<void> _clearCart() async {
    // 1. Lấy userId từ userEmail, dùng firstWhereOrNull
    final user = DBService.users().values.firstWhereOrNull(
          (u) => u.email == widget.userEmail,
    );

    final userId = user?.userId; // nếu không tìm thấy thì null

    // 2. Xóa cart local theo email
    await DBService.carts().delete(widget.userEmail);

    // 3. Xóa cart remote nếu userId tồn tại
    if (userId != null) {
      await ApiService.saveCart(userId, {}); // gửi cart rỗng lên server
    }

    // 4. Cập nhật state
    setState(() {
      cart.clear();
      totalAmount = 0;
    });

    // 5️⃣ Callback HomeScreen nếu có
    if (widget.onCheckoutComplete != null) {
      widget.onCheckoutComplete!();
    }
  }

  Future<void> _confirmOrder() async {
    if (cart.isEmpty) return;

    setState(() => isLoading = true);

    try {
      // 1. Tạo list OrderLine từ cart
      final items = cart.entries.map((e) {
        final product = DBService.products().get(e.key)!;
        return OrderLine(
          productId: product.id,
          productName: product.name,
          quantity: e.value,
          pricePerUnit: product.price,
        );
      }).toList();

      // 2. Tạo Order object
      final order = Order(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        orderDate: DateTime.now(),
        totalAmount: totalAmount,
        customerName: widget.userEmail,
        status: 'Chờ xác nhận nhân viên', // trạng thái mới
        items: items,
        customerId: widget.customerId,
        shippingAddress: deliveryOption == 'delivery' ? addressController.text : null,
        paymentMethod: paymentMethod,
        paymentStatus: paymentMethod == 'cash' ? 'pending' : 'paid',
        note: voucherController.text.isEmpty ? null : 'Voucher: ${voucherController.text}',
      );

      // 3. Gọi API tạo đơn
      final savedOrder = await ApiService.createOrder(order, customerId: widget.customerId);

      // 4. Lưu order vào Hive để màn hình order có dữ liệu
      final ordersBox = DBService.orders();
      await ordersBox.put(savedOrder.id, savedOrder);

      // 5. Clear cart local & remote
      await _clearCart();

      // 6. Gọi callback refresh order list
      if (widget.onCheckoutComplete != null) {
        widget.onCheckoutComplete!();
      }

      // 7. Xử lý ví điện tử
      if (paymentMethod == 'wallet') {
        setState(() => qrData = savedOrder.id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đơn hàng gửi thành công, chờ nhân viên xác nhận!')),
        );
        Navigator.pop(context);
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tạo đơn: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _completeWalletPayment() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanh toán thành công!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thanh toán Online'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : qrData != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(data: qrData!, size: 250),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _completeWalletPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Thanh toán thành công',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Giỏ hàng', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...cart.entries.map((e) {
              final product = DBService.products().get(e.key)!;
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('${product.price} đ x ${cart[e.key]} = ${product.price * cart[e.key]!} đ'),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              setState(() {
                                if (cart[e.key]! > 1) {
                                  cart[e.key] = cart[e.key]! - 1;
                                } else {
                                  cart.remove(e.key);
                                }
                                _calculateTotal();
                              });
                            },
                          ),
                          Text('${cart[e.key]}', style: const TextStyle(fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () {
                              setState(() {
                                cart[e.key] = cart[e.key]! + 1;
                                _calculateTotal();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const Divider(),
            Text('Tổng tiền: $totalAmount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            const Text('Hình thức nhận hàng', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Radio<String>(
                  value: 'pickup',
                  groupValue: deliveryOption,
                  onChanged: (v) => setState(() => deliveryOption = v!),
                ),
                const Text('Tại cửa hàng'),
                Radio<String>(
                  value: 'delivery',
                  groupValue: deliveryOption,
                  onChanged: (v) => setState(() => deliveryOption = v!),
                ),
                const Text('Giao tận nơi'),
              ],
            ),
            if (deliveryOption == 'delivery')
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ giao',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 20),
            TextField(
              controller: voucherController,
              decoration: const InputDecoration(
                labelText: 'Voucher (nếu có)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _calculateTotal(),
            ),
            const SizedBox(height: 20),
            const Text('Phương thức thanh toán', style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Radio<String>(
                  value: 'cash',
                  groupValue: paymentMethod,
                  onChanged: (v) => setState(() => paymentMethod = v!),
                ),
                const Text('Tiền mặt'),
                Radio<String>(
                  value: 'wallet',
                  groupValue: paymentMethod,
                  onChanged: (v) => setState(() => paymentMethod = v!),
                ),
                const Text('Ví điện tử'),
              ],
            ),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton(
                onPressed: _confirmOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Xác nhận đơn hàng',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}