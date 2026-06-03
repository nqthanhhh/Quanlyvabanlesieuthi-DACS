// lib/screens/add_product_screen.dart (ĐÃ CHỈNH SỬA HOÀN CHỈNH)

import 'package:flutter/material.dart';
// removed unused dart:io import because image UI was removed
import 'dart:math' as math;
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../models/inventory_item.dart';
import '../services/db_service.dart';
import '../services/api_service.dart';
import '../utils/product_asset_resolver.dart';

class AddProductScreen extends StatefulWidget {
  final Product? product;

  // Thêm tham số isAddingStock để phân biệt mục đích:
  // - false (mặc định): Thêm mới hoặc Sửa chi tiết (ghi đè tồn kho)
  // - true: Chỉ để nhập thêm (cộng dồn tồn kho)
  // Tuy nhiên, theo logic mới, ta chỉ giữ lại logic: Thêm mới và Chỉnh sửa (ghi đè tồn kho)
  const AddProductScreen({super.key, this.product});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _unitController;
  late TextEditingController _stockQuantityController;
  bool _isProcessing = false;
  String? _selectedInventoryId;
  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    // Khởi tạo Controllers với dữ liệu hiện có nếu là chế độ chỉnh sửa
    _idController = TextEditingController(text: widget.product?.id ?? '');
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(
      text: widget.product?.price.toString() ?? '',
    );
    _unitController = TextEditingController(text: widget.product?.unit ?? '');
    _stockQuantityController = TextEditingController(
      text: widget.product?.stockQuantity.toString() ?? '0',
    );
    _selectedCategoryId = widget.product?.categoryId;
    _loadCategories();

    // Nếu là chế độ chỉnh sửa, không cho phép sửa ID
    if (_isEditing) {
      _idController.addListener(() {
        if (_idController.text != widget.product!.id) {
          _idController.text = widget.product!.id;
          _idController.selection = TextSelection.fromPosition(
            TextPosition(offset: _idController.text.length),
          );
        }
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ApiService.fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        // Không tự động chọn categories.first (có thể lệch sang Gia vị ID=3).
        // Khi release từ kho lên kệ, buộc người dùng/logic phải chọn đúng danh mục.
        if (_selectedCategoryId != null) {
          // giữ nguyên
        }
      });
    } catch (_) {
      if (mounted) setState(() => _categories = []);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _stockQuantityController.dispose();
    // image feature removed
    super.dispose();
  }

  Future<void> _chooseQuantityFromInventory(InventoryItem item) async {
    final qController = TextEditingController(
      text: '${item.stockQuantity > 0 ? 1 : 0}',
    );
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Lấy từ kho: ${item.name}'),

        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tồn kho hiện có: ${item.stockQuantity} ${item.unit}'),
              const SizedBox(height: 8),
              TextFormField(
                controller: qController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số lượng lấy',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Nhập số lượng';
                  final n = int.tryParse(v);
                  if (n == null) return 'Số không hợp lệ';
                  if (n < 0) return 'Phải là số không âm';
                  if (n > item.stockQuantity) return 'Vượt quá tồn kho';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final n = int.parse(qController.text.trim());
                Navigator.of(context).pop(n);
              }
            },
            child: const Text('Chọn'),
          ),
        ],
      ),
    );

    if (result != null) {
      // If editing, fill fields for manual edit behavior. If adding new,
      // immediately attempt to add product from inventory with chosen qty.
      if (_isEditing) {
        // Gán text vào controller TRƯỚC setState để tránh lỗi TextFormField
        _idController.text = item.id;
        _nameController.text = item.name;
        _priceController.text = item.price.toString();
        _unitController.text = item.unit;
        _stockQuantityController.text = result.toString();

        setState(() {
          _selectedInventoryId = item.id;
        });
      } else {
        await _addProductFromInventory(item, result);
      }
    }
  }

  Future<void> _addProductFromInventory(
    InventoryItem item,
    int takeAmount,
  ) async {
    setState(() => _isProcessing = true);
    try {
      final int? categoryId = item.categoryId;
      if (categoryId == null) {
        throw Exception(
          'Hàng trong kho chưa có danh mục (categoryId). Vui lòng kiểm tra lại khi nhập kho.',
        );
      }

      await DBService.releaseInventoryToShelf(
        item: item,
        quantity: takeAmount,
        categoryId: categoryId,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thêm sản phẩm thành công!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear ID field and selection state
      setState(() {
        _idController.clear();
        _selectedInventoryId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _inventoryThumbnail(InventoryItem item) {
    final storedRaw =
        (DBService.productImages().get(item.id) ?? item.imageUrl ?? '')
            .toString();
    final stored = ApiService.resolveBackendUrl(storedRaw);

    Widget assetImage([String? preferredAsset]) {
      return Image.asset(
        preferredAsset ?? ProductAssetResolver.forInventoryItem(item),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          ProductAssetResolver.defaultProductAsset,
          fit: BoxFit.cover,
        ),
      );
    }

    Widget framed(Widget child) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 56, height: 56, child: child),
      );
    }

    if (storedRaw.trim().startsWith('assets/')) {
      return framed(assetImage(storedRaw.trim()));
    }
    if (stored.startsWith('http')) {
      return framed(
        Image.network(
          stored,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => assetImage(),
        ),
      );
    }
    if (stored.isNotEmpty) {
      try {
        final file = File(stored);
        if (file.existsSync()) {
          return framed(Image.file(file, fit: BoxFit.cover));
        }
      } catch (_) {}
    }

    return framed(assetImage());
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final String id = _idController.text.trim();
      final String name = _nameController.text.trim();
      final double price = double.parse(_priceController.text);
      final String unit = _unitController.text.trim();
      final int stockQuantity = int.parse(
        _stockQuantityController.text,
      ); // Lượng tồn kho mới

      if (_selectedCategoryId == null) {
        throw Exception('Vui lòng thêm hoặc chọn danh mục.');
      }

      final importPrice = await DBService.fetchLatestImportPrice(id);
      if (importPrice != null && price < importPrice) {
        throw Exception('Giá bán không được nhỏ hơn giá nhập');
      }
      if (importPrice == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sản phẩm chưa có giá nhập, không thể kiểm tra giá vốn',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      if (_isEditing) {
        widget.product!.name = name;
        widget.product!.price = price;
        widget.product!.unit = unit;
        widget.product!.barcode = id;
        widget.product!.stockQuantity = stockQuantity; // GHI ĐÈ số lượng
        widget.product!.categoryId = _selectedCategoryId;
        await DBService.updateProductRemote(widget.product!);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật sản phẩm thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        final Product newProduct = Product(
          id: id,
          name: name,
          price: price,
          unit: unit,
          barcode: id,
          stockQuantity: stockQuantity, // Tồn kho ban đầu
          createdAt: DateTime.now(), // <-- ĐÃ THÊM
          categoryId: _selectedCategoryId,
        );

        await DBService.createProduct(newProduct);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thêm sản phẩm thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        // Xóa các trường sau khi thêm mới
        _nameController.clear();
        _priceController.clear();
        _unitController.clear();
        _stockQuantityController.text = '0';
        _idController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Chỉnh sửa Sản phẩm' : 'Thêm Sản phẩm',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _isProcessing ? null : _saveProduct,
              icon: const Icon(Icons.save),
              tooltip: 'Lưu',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mã vạch / mã nội bộ
              TextFormField(
                controller: _idController,
                onChanged: (v) => setState(() {}),
                readOnly: _isEditing,
                decoration: InputDecoration(
                  labelText: 'Mã vạch / Mã nội bộ',
                  hintText: 'VD: PROD007, SP000001, 893...',
                  border: const OutlineInputBorder(),
                  filled: _isEditing,
                  fillColor: _isEditing ? Colors.grey.shade100 : Colors.white,
                  suffixIcon: _isEditing
                      ? const Icon(Icons.lock_outline, color: Colors.grey)
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập mã vạch / mã nội bộ.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Danh mục lấy theo inventory_items.category_id khi release từ kho.
              // Vì inventory_items đang có thể NULL, release sẽ bị chặn để tránh nhầm category.
              const SizedBox(height: 8),

              // Gợi ý sản phẩm từ kho (tìm kiếm theo id/name dựa trên nội dung ô ID)
              ValueListenableBuilder<Box<InventoryItem>>(
                valueListenable: DBService.inventoryProducts().listenable(),
                builder: (context, invBox, _) {
                  // Normalize query: remove spaces and lowercase so typing
                  // matches more naturally. We support contains, startsWith,
                  // and a simple subsequence match (chars in order) so typing
                  // incremental characters will find items.
                  final raw = _idController.text;
                  final query = raw.replaceAll(' ', '').toLowerCase();

                  bool matches(String text) {
                    final t = text.replaceAll(' ', '').toLowerCase();
                    if (query.isEmpty) return true;
                    // Prefix-only match: require the normalized text to start with the query
                    return t.startsWith(query);
                  }

                  final List<InventoryItem> items = invBox.values
                      .where((it) => matches(it.id) || matches(it.name))
                      .toList();

                  if (items.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Các sản phẩm từ kho',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      // make the suggestion list taller when there are more items
                      SizedBox(
                        height: math.min(items.length * 80.0 + 8.0, 420.0),
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final it = items[idx];
                            final bool isSelected =
                                _selectedInventoryId == it.id;

                            final leading = _inventoryThumbnail(it);

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                                horizontal: 8.0,
                              ),
                              leading: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : leading,
                              title: Text(it.name),
                              subtitle: Text(
                                'Mã vạch / mã nội bộ: ${it.id} • Tồn: ${it.stockQuantity} ${it.unit}',
                              ),
                              trailing: ElevatedButton(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _chooseQuantityFromInventory(it),
                                child: const Text('Chọn'),
                              ),
                              onTap: _isProcessing
                                  ? null
                                  : () => _chooseQuantityFromInventory(it),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 12),
              // Minimal instruction area: only ID input + suggestions are used.
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    'Nhập mã vạch / mã nội bộ, chọn một mục trong "Gợi ý từ kho" rồi chọn số lượng. Sản phẩm sẽ được thêm tự động.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_isProcessing)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
