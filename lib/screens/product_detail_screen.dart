import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/product_review.dart';
import '../services/api_service.dart';
import '../utils/product_stock_utils.dart';
import '../widgets/product_image_widget.dart';

typedef ProductCartAction = Future<void> Function(Product product, int quantity);

/// Chi tiết sản phẩm cho khách hàng (hoặc xem chỉ đọc cho nhân viên).
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final String Function(Product) assetFallback;
  final ProductCartAction? onAddToCart;
  final ProductCartAction? onBuyNow;
  final bool readOnly;

  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.assetFallback,
    this.onAddToCart,
    this.onBuyNow,
    this.readOnly = false,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late int _quantity;
  List<ProductReview> _reviews = [];
  bool _loadingReviews = true;

  Product get _p => widget.product;

  bool get _outOfStock => !ProductStockUtils.canPurchase(_p);
  bool get _canShop => !widget.readOnly && ProductStockUtils.isSellable(_p);

  @override
  void initState() {
    super.initState();
    _quantity = _outOfStock ? 0 : 1;
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final data = await ApiService.fetchProductReviews(_p.id);
      if (!mounted) return;
      setState(() {
        _reviews = data;
        _loadingReviews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reviews = ProductReview.mockForProduct(_p.id);
        _loadingReviews = false;
      });
    }
  }

  String _formatVnd(double amount) {
    final value = amount.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      if (i > 0 && (value.length - i) % 3 == 0) buffer.write('.');
      buffer.write(value[i]);
    }
    return '${buffer.toString()} VNĐ';
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  String _categoryLabel() {
    final name = (_p.categoryName ?? '').trim();
    return name.isEmpty ? 'Chưa phân loại' : name;
  }

  void _clampQuantity() {
    if (_outOfStock) {
      _quantity = 0;
      return;
    }
    if (_quantity < 1) _quantity = 1;
    if (_quantity > _p.stockQuantity) _quantity = _p.stockQuantity;
  }

  void _changeQuantity(int delta) {
    setState(() {
      _quantity += delta;
      _clampQuantity();
    });
  }

  Future<void> _handleAddToCart() async {
    if (!_canShop || widget.onAddToCart == null) return;
    if (_outOfStock) {
      _showSnack('Sản phẩm hiện đã hết hàng');
      return;
    }
    _clampQuantity();
    await widget.onAddToCart!(_p, _quantity);
    if (!mounted) return;
    _showSnack('Đã thêm ${_p.name} vào giỏ hàng');
  }

  Future<void> _handleBuyNow() async {
    if (!_canShop || widget.onBuyNow == null) return;
    if (_outOfStock) {
      _showSnack('Sản phẩm hiện đã hết hàng');
      return;
    }
    _clampQuantity();
    await widget.onBuyNow!(_p, _quantity);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avg = ProductReview.averageRating(_reviews);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('Chi tiết sản phẩm'),
        backgroundColor: ProductStockUtils.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 1.1,
                      child: ProductImageWidget(
                        product: _p,
                        assetFallback: widget.assetFallback,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _p.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _infoRow('SKU / Mã', _p.sku),
                  if ((_p.barcode ?? '').isNotEmpty && _p.barcode != _p.id)
                    _infoRow('Mã vạch', _p.barcode!),
                  _infoRow('Danh mục', _categoryLabel()),
                  _infoRow('Đơn vị', _p.unit),
                  const SizedBox(height: 8),
                  Text(
                    _formatVnd(_p.price),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: ProductStockUtils.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _stockChip(),
                      const SizedBox(width: 8),
                      Text(
                        'Tồn kho: ${_p.stockQuantity}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  if (_outOfStock) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Sản phẩm hiện đã hết hàng',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                  if (!_outOfStock && !widget.readOnly) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Số lượng',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    _quantitySelector(),
                  ],
                  const SizedBox(height: 24),
                  _sectionTitle('Thông tin sản phẩm'),
                  const SizedBox(height: 8),
                  Text(
                    (_p.description ?? '').trim().isEmpty
                        ? 'Chưa có mô tả cho sản phẩm này.'
                        : _p.description!.trim(),
                    style: const TextStyle(height: 1.4, color: Colors.black87),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('Đặc tính nổi bật'),
                  const SizedBox(height: 8),
                  Text(
                    (_p.highlights ?? '').trim().isEmpty
                        ? 'Chưa có thông số nổi bật.'
                        : _p.highlights!.trim(),
                    style: const TextStyle(height: 1.4, color: Colors.black87),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('Đánh giá & bình luận khách hàng'),
                  const SizedBox(height: 8),
                  if (_loadingReviews)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ))
                  else if (_reviews.isEmpty)
                    const Text(
                      'Chưa có đánh giá nào cho sản phẩm này',
                      style: TextStyle(color: Colors.black54),
                    )
                  else ...[
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 22),
                        const SizedBox(width: 6),
                        Text(
                          '${avg.toStringAsFixed(1)}/5',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${_reviews.length} đánh giá)',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._reviews.map(
                      (r) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      r.customerName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(
                                      5,
                                      (i) => Icon(
                                        i < r.rating
                                            ? Icons.star
                                            : Icons.star_border,
                                        size: 16,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (r.createdAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(r.createdAt!),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                              if (r.comment.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(r.comment),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_canShop)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _outOfStock ? null : _handleAddToCart,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ProductStockUtils.primaryGreen,
                          side: const BorderSide(
                            color: ProductStockUtils.primaryGreen,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Thêm giỏ'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _outOfStock ? null : _handleBuyNow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ProductStockUtils.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Mua ngay'),
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

  Widget _stockChip() {
    final color = ProductStockUtils.color(_p);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        ProductStockUtils.label(_p),
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _quantitySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.filled(
          onPressed: _quantity <= 1 ? null : () => _changeQuantity(-1),
          icon: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '$_quantity',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton.filled(
          onPressed: _quantity >= _p.stockQuantity
              ? null
              : () => _changeQuantity(1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
