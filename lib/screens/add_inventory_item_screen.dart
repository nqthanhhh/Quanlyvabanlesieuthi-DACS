import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/inventory_item.dart';
import '../services/db_service.dart';

class AddInventoryItemScreen extends StatefulWidget {
  final InventoryItem? item;

  const AddInventoryItemScreen({super.key, this.item});

  @override
  State<AddInventoryItemScreen> createState() => _AddInventoryItemScreenState();
}

class _AddInventoryItemScreenState extends State<AddInventoryItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _unitController;
  late TextEditingController _stockController;
  bool get _isEditing => widget.item != null;
  bool _processing = false;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(text: widget.item?.id ?? '');
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _priceController = TextEditingController(
      text: widget.item?.price.toString() ?? '',
    );
    _unitController = TextEditingController(text: widget.item?.unit ?? '');
    _stockController = TextEditingController(
      text: widget.item?.stockQuantity.toString() ?? '0',
    );
    if (_isEditing) {
      _idController.text = widget.item!.id;
      // load image path if any
      _imagePath = DBService.productImages().get(widget.item!.id);
    }
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

  Future<void> _pickImage() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (file != null) {
      setState(() => _imagePath = file.path);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _processing = true);
    try {
      final id = _idController.text.trim();
      final name = _nameController.text.trim();
      final price = double.parse(_priceController.text.trim());
      final unit = _unitController.text.trim();
      final qty = int.parse(_stockController.text.trim());

      final box = DBService.inventoryProducts();

      if (_isEditing) {
        final existing = widget.item!;
        final oldId = existing.id;
        final newId = id;

        if (newId != oldId) {
          // reject if new id exists
          if (box.containsKey(newId)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mã mới đã tồn tại trong kho'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          final InventoryItem newItem = InventoryItem(
            id: newId,
            name: name,
            price: price,
            unit: unit,
            stockQuantity: qty,
          );

          await box.put(newItem.id, newItem);

          // migrate image mapping if present
          final imgBox = DBService.productImages();
          final oldImg = imgBox.get(oldId);
          if (_imagePath != null) {
            await imgBox.put(newId, _imagePath!);
            if (oldImg != null && oldId != newId) await imgBox.delete(oldId);
          } else if (oldImg != null) {
            // if user didn't pick a new image but an old image exists, move it
            await imgBox.put(newId, oldImg);
            await imgBox.delete(oldId);
          }

          // delete old record
          await box.delete(oldId);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật kho thành công'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          // same id: update fields
          existing.name = name;
          existing.price = price;
          existing.unit = unit;
          existing.stockQuantity = qty;
          await box.put(existing.id, existing);

          // update image if user picked one
          if (_imagePath != null) {
            await DBService.productImages().put(existing.id, _imagePath!);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cập nhật kho thành công'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        if (box.containsKey(id)) {
          throw Exception('Mã tồn kho đã tồn tại');
        }
        final inv = InventoryItem(
          id: id,
          name: name,
          price: price,
          unit: unit,
          stockQuantity: qty,
        );
        await box.put(inv.id, inv);
        if (_imagePath != null) {
          await DBService.productImages().put(inv.id, _imagePath!);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thêm vào kho thành công'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Chỉnh sửa Kho' : 'Thêm hàng vào Kho'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _idController,
                readOnly: false,
                decoration: const InputDecoration(
                  labelText: 'Mã hàng (ID)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Nhập mã hàng' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên hàng',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Nhập tên' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Giá',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Nhập giá' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(
                  labelText: 'Đơn vị',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Nhập đơn vị' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockController,
                readOnly: _isEditing,
                decoration: const InputDecoration(
                  labelText: 'Số lượng tồn (chỉ xem)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Nhập số lượng' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: const Text('Chọn ảnh'),
                  ),
                  const SizedBox(width: 12),
                  if (_imagePath != null)
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _processing ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                  ),
                  child: _processing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isEditing ? 'Cập nhật' : 'Thêm vào kho'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
