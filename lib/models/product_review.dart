import '../utils/type_converters.dart';

/// Đánh giá sản phẩm — map từ API `/api/reviews/products/:id`.
class ProductReview {
  final int? id;
  final String customerName;
  final int rating;
  final String comment;
  final DateTime? createdAt;

  const ProductReview({
    this.id,
    required this.customerName,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    return ProductReview(
      id: TypeConverters.toNullableInt(json['review_id'] ?? json['id']),
      customerName: (json['full_name'] ??
              json['customer_name'] ??
              json['customerName'] ??
              'Khách hàng')
          .toString(),
      rating: TypeConverters.toInt(json['rating'], defaultValue: 5).clamp(1, 5),
      comment: (json['comment'] ?? '').toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  /// Dữ liệu mẫu khi API chưa có review hoặc lỗi mạng.
  static List<ProductReview> mockForProduct(String productId) {
    final seed = productId.hashCode.abs() % 3;
    if (seed == 0) return const [];

    return [
      ProductReview(
        id: 1,
        customerName: 'Nguyễn Văn A',
        rating: 5,
        comment: 'Sản phẩm tươi, đóng gói cẩn thận.',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      ProductReview(
        id: 2,
        customerName: 'Trần Thị B',
        rating: 4,
        comment: 'Giá hợp lý, giao hàng nhanh.',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ];
  }

  static double averageRating(List<ProductReview> reviews) {
    if (reviews.isEmpty) return 0;
    final sum = reviews.fold<int>(0, (acc, r) => acc + r.rating);
    return sum / reviews.length;
  }
}
