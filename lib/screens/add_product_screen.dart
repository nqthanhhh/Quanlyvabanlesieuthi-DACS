// lib/screens/add_product_screen.dart (ĐÃ CHỈNH SỬA)
import 'package:flutter/material.dart';
// removed unused dart:io import because image UI was removed
import 'dart:math' as math;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../models/inventory_item.dart';
import '../services/db_service.dart';

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
  int? _selectedTakeAmount;
  String? _selectedInventoryId;

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
    final _qController = TextEditingController(
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
                controller: _qController,
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
                final n = int.parse(_qController.text.trim());
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
        setState(() {
          _selectedInventoryId = item.id;
          _selectedTakeAmount = result;
          _idController.text = item.id;
          _nameController.text = item.name;
          _priceController.text = item.price.toString();
          _unitController.text = item.unit;
          _stockQuantityController.text = result.toString();
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
      final box = DBService.products();
      final invBox = DBService.inventoryProducts();

      // First, try to reduce inventory. This ensures we only add or update
      // product if inventory has enough quantity.
      final int reduceResult = await DBService.reduceInventoryStockIfAvailable(
        item.id,
        takeAmount,
      );
      if (reduceResult == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Kho không có sản phẩm này. Vui lòng nhập kho trước.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      } else if (reduceResult == -2) {
        final inv = invBox.get(item.id);
        final available = inv?.stockQuantity ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kho chỉ còn $available, không đủ để lấy $takeAmount.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (box.containsKey(item.id)) {
        // If product exists, increment its stockQuantity
        final Product existing = box.get(item.id) as Product;
        existing.stockQuantity = existing.stockQuantity + takeAmount;
        await existing.save();

        // Update metadata from inventory if any
        await DBService.updateInventoryMetadataForProduct(existing);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm $takeAmount vào ${existing.name}.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Create and save product using inventory metadata
        final Product newProduct = Product(
          id: item.id,
          name: item.name,
          price: item.price,
          unit: item.unit,
          stockQuantity: takeAmount,
        );

        await box.put(newProduct.id, newProduct);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thêm sản phẩm thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Clear ID field and selection state
      setState(() {
        _idController.clear();
        _selectedInventoryId = null;
        _selectedTakeAmount = null;
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

      final box = DBService.products();

      if (_isEditing) {
        // CHẾ ĐỘ CHỈNH SỬA/NHẬP KHO (GHI ĐÈ TỒN KHO):
        // Nếu số lượng mới lớn hơn số lượng cũ, cần trừ phần chênh lệch từ kho
        final int oldQty = widget.product!.stockQuantity;
        final int delta = stockQuantity - oldQty;
        if (delta > 0) {
          final int reduceResult =
              await DBService.reduceInventoryStockIfAvailable(
                widget.product!.id,
                delta,
              );
          if (reduceResult == -1) {
            // inventory item not found
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Kho chưa có sản phẩm này. Vui lòng nhập kho trước.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          } else if (reduceResult == -2) {
            final inv =
                DBService.inventoryProducts().get(widget.product!.id)
                    as dynamic;
            final available = inv?.stockQuantity ?? 0;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Kho chỉ còn $available, không đủ để tăng $delta.',
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }

        widget.product!.name = name;
        widget.product!.price = price;
        widget.product!.unit = unit;
        widget.product!.stockQuantity = stockQuantity; // GHI ĐÈ số lượng
        await widget.product!.save();

        // image support removed — productImages not modified here

        // Update corresponding inventory metadata (name/price/unit) if it
        // exists. We do NOT change inventory stockQuantity here.
        await DBService.updateInventoryMetadataForProduct(widget.product!);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật sản phẩm thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      } else {
        // CHẾ ĐỘ THÊM MỚI:
        if (box.containsKey(id)) {
          throw Exception('Mã sản phẩm đã tồn tại. Vui lòng chọn Mã khác.');
        }

        final Product newProduct = Product(
          id: id,
          name: name,
          price: price,
          unit: unit,
          stockQuantity: stockQuantity, // Tồn kho ban đầu
        );

        // Trước khi thêm sản phẩm mới, kiểm tra kho có bản ghi tương ứng không
        final invBox = DBService.inventoryProducts();
        if (!invBox.containsKey(id)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Kho chưa có sản phẩm này. Vui lòng nhập kho trước.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Nếu người dùng đã chọn số lượng lấy từ kho, sử dụng nó; nếu không,
        // sử dụng số lượng đang nhập trong ô Tồn kho.
        final int takeAmount = _selectedTakeAmount ?? stockQuantity;
        final int reduceResult =
            await DBService.reduceInventoryStockIfAvailable(id, takeAmount);
        if (reduceResult == -1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Kho không có sản phẩm này. Vui lòng nhập kho trước.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        } else if (reduceResult == -2) {
          final inv = invBox.get(id);
          final available = inv?.stockQuantity ?? 0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Kho chỉ còn $available, không đủ để lấy $takeAmount.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Nếu giảm kho thành công, lưu product với số lượng bằng takeAmount
        newProduct.stockQuantity = takeAmount;
        await box.put(newProduct.id, newProduct);

        // image support removed — productImages not modified here

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
              // Mã sản phẩm
              TextFormField(
                controller: _idController,
                onChanged: (v) => setState(() {}),
                readOnly: _isEditing, // KHÔNG cho phép sửa ID khi chỉnh sửa
                decoration: InputDecoration(
                  labelText: 'Mã Sản phẩm (ID)',
                  hintText: 'VD: TAO_DO, COKE...',
                  border: const OutlineInputBorder(),
                  filled: _isEditing,
                  fillColor: _isEditing ? Colors.grey.shade100 : Colors.white,
                  suffixIcon: _isEditing
                      ? const Icon(Icons.lock_outline, color: Colors.grey)
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập Mã Sản phẩm.';
                  }
                  return null;
                },
              ),
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

                  bool _matches(String text) {
                    final t = text.replaceAll(' ', '').toLowerCase();
                    if (query.isEmpty) return true;
                    // Prefix-only match: require the normalized text to start with the query
                    return t.startsWith(query);
                  }

                  final List<InventoryItem> items = invBox.values
                      .where((it) => _matches(it.id) || _matches(it.name))
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
                        height: math.min(items.length * 72.0 + 8.0, 420.0),
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final it = items[idx];
                            final bool isSelected =
                                _selectedInventoryId == it.id;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                  : null,
                              title: Text(it.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mã: ${it.id} — Tồn: ${it.stockQuantity} ${it.unit}',
                                  ),
                                  if (isSelected && _selectedTakeAmount != null)
                                    Text(
                                      'Đã chọn: ${_selectedTakeAmount} ${it.unit}',
                                      style: TextStyle(
                                        color: Colors.green[700],
                                      ),
                                    ),
                                ],
                              ),
                              trailing: TextButton(
                                onPressed: () =>
                                    _chooseQuantityFromInventory(it),
                                child: const Text('Chọn'),
                              ),
                              onTap: () => _chooseQuantityFromInventory(it),
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
                    'Nhập Mã sản phẩm, chọn một mục trong "Gợi ý từ kho" rồi chọn số lượng. Sản phẩm sẽ được thêm tự động.',
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
