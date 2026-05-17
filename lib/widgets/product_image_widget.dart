import 'dart:io';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/db_service.dart';

/// Hiển thị ảnh sản phẩm: URL mạng, file local, hoặc asset fallback.
class ProductImageWidget extends StatelessWidget {
  final Product product;
  final String Function(Product) assetFallback;
  final BoxFit fit;
  final double? height;

  const ProductImageWidget({
    super.key,
    required this.product,
    required this.assetFallback,
    this.fit = BoxFit.cover,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final stored = (DBService.productImages().get(product.id) ??
            product.imageUrl ??
            '')
        .toString();

    Widget image;
    if (stored.isNotEmpty && stored.startsWith('http')) {
      image = Image.network(
        stored,
        fit: fit,
        width: double.infinity,
        height: height,
        errorBuilder: (_, __, ___) => _assetImage(),
      );
    } else if (stored.isNotEmpty) {
      try {
        final file = File(stored);
        if (file.existsSync()) {
          image = Image.file(
            file,
            fit: fit,
            width: double.infinity,
            height: height,
            errorBuilder: (_, __, ___) => _assetImage(),
          );
        } else {
          image = _assetImage();
        }
      } catch (_) {
        image = _assetImage();
      }
    } else {
      image = _assetImage();
    }

    return image;
  }

  Widget _assetImage() {
    return Image.asset(
      assetFallback(product),
      fit: fit,
      width: double.infinity,
      height: height,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: const Icon(Icons.image, size: 36, color: Colors.black26),
      ),
    );
  }
}
