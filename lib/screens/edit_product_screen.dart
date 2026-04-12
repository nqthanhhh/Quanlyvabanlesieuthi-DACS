import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/db_service.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;
  const EditProductScreen({super.key, required this.product});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _unitController;
  late TextEditingController _stockController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.product.id);
    _nameController = TextEditingController(text: widget.product.name);
    _priceController = TextEditingController(
      text: widget.product.price.toString(),
    );
    _unitController = TextEditingController(text: widget.product.unit);
    _stockController = TextEditingController(
      text: widget.product.stockQuantity.toString(),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final box = DBService.products();
    final oldId = widget.product.id;
    final newId = _idController.text.trim();
    final newName = _nameController.text.trim();
    final newPrice = double.parse(_priceController.text.trim());
    final newUnit = _unitController.text.trim();
    final newStock = int.parse(_stockController.text.trim());

    try {
      if (newId != oldId) {
        // If new id already exists, reject
        if (box.containsKey(newId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mã mới đã tồn tại, chọn mã khác.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Create new product under newId
        final Product newProduct = Product(
          id: newId,
          name: newName,
          price: newPrice,
          unit: newUnit,
          stockQuantity: newStock,
        );
        await box.put(newProduct.id, newProduct);

        // Migrate product image mapping if present
        final imgBox = DBService.productImages();
        final oldImg = imgBox.get(oldId);
        if (oldImg != null) {
          await imgBox.put(newId, oldImg);
          await imgBox.delete(oldId);
        }

        // Delete old product
        await box.delete(oldId);

        // Update inventory metadata for new product if needed
        await DBService.updateInventoryMetadataForProduct(newProduct);
      } else {
        // Same id: update fields and save
        widget.product.name = newName;
        widget.product.price = newPrice;
        widget.product.unit = newUnit;
        widget.product.stockQuantity = newStock;
        await widget.product.save();

        await DBService.updateInventoryMetadataForProduct(widget.product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lưu sản phẩm thành công.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa Sản phẩm'),
        backgroundColor: Colors.blue.shade600,
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _saveChanges,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _idController,
                decoration: const InputDecoration(
                  labelText: 'Mã sản phẩm (ID)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nhập Mã' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên sản phẩm',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nhập Tên' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Giá (VNĐ)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nhập Giá';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Giá không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(
                  labelText: 'Đơn vị',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nhập đơn vị' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockController,
                // readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Tồn kho',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Nhập tồn kho';
                  final n = int.tryParse(v);
                  if (n == null || n < 0) return 'Số không hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Lưu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
