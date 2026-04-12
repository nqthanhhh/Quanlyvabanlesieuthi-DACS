import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/inventory_item.dart';
import '../services/db_service.dart';

class ImportInventoryScreen extends StatefulWidget {
  const ImportInventoryScreen({super.key});

  @override
  State<ImportInventoryScreen> createState() => _ImportInventoryScreenState();
}

class _ImportInventoryScreenState extends State<ImportInventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _newFormKey = GlobalKey<FormState>();

  // New item controllers
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '0');

  String? _pickedImagePath;
  bool _processing = false;

  Future<void> _pickImage() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (file != null) {
      setState(() => _pickedImagePath = file.path);
    }
  }

  Future<void> _addToExisting(InventoryItem item) async {
    final qtyController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nhập thêm vào: ${item.name}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Số lượng',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Nhập số lượng';
              final n = int.tryParse(v);
              if (n == null || n <= 0) return 'Số không hợp lệ';
              return null;
            },
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
                Navigator.of(context).pop(int.parse(qtyController.text.trim()));
              }
            },
            child: const Text('Nhập'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _processing = true);
      try {
        final box = DBService.inventoryProducts();
        final existing = box.get(item.id);
        if (existing == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mục kho không tồn tại'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          existing.stockQuantity = existing.stockQuantity + result;
          await box.put(existing.id, existing);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã nhập $result vào ${existing.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _processing = false);
      }
    }
  }

  Future<void> _createNewInventoryItem() async {
    if (!_newFormKey.currentState!.validate()) return;
    setState(() => _processing = true);
    try {
      final id = _idController.text.trim();
      final name = _nameController.text.trim();
      final price = double.parse(_priceController.text.trim());
      final unit = _unitController.text.trim();
      final qty = int.parse(_qtyController.text.trim());

      final box = DBService.inventoryProducts();
      if (box.containsKey(id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mã đã tồn tại trong kho'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final item = InventoryItem(
        id: id,
        name: name,
        price: price,
        unit: unit,
        stockQuantity: qty,
      );
      await box.put(item.id, item);

      if (_pickedImagePath != null) {
        await DBService.productImages().put(item.id, _pickedImagePath!);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã thêm mặt hàng vào kho'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _idController.clear();
      _nameController.clear();
      _priceController.clear();
      _unitController.clear();
      _qtyController.text = '0';
      setState(() => _pickedImagePath = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _idController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _unitController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập kho'),
        backgroundColor: Colors.blue.shade600,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tìm trong kho hiện có',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Tìm theo mã hoặc tên',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder(
              valueListenable: DBService.inventoryProducts().listenable(),
              builder: (context, Box<InventoryItem> box, _) {
                final query = _searchController.text.trim().toLowerCase();
                final List<InventoryItem> items = box.values.where((it) {
                  if (query.isEmpty) return true;
                  return it.id.toLowerCase().contains(query) ||
                      it.name.toLowerCase().contains(query);
                }).toList();

                // Sort so items with the smallest stockQuantity appear first.
                items.sort((a, b) {
                  final cmp = a.stockQuantity.compareTo(b.stockQuantity);
                  if (cmp != 0) return cmp;
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                });

                if (items.isEmpty)
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Không tìm thấy trong kho'),
                    ),
                  );

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final it = items[idx];
                    return ListTile(
                      title: Text(it.name),
                      subtitle: Text(
                        'Mã: ${it.id} — Tồn: ${it.stockQuantity} ${it.unit}',
                      ),
                      trailing: ElevatedButton(
                        onPressed: () => _addToExisting(it),
                        child: const Text('Nhập'),
                      ),
                      onTap: () => _addToExisting(it),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Thêm mặt hàng mới vào kho',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Form(
              key: _newFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      labelText: 'Mã (ID)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nhập mã' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nhập tên' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Giá',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Nhập giá';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Giá không hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Đơn vị',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nhập đơn vị' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _qtyController,
                    decoration: const InputDecoration(
                      labelText: 'Số lượng nhập',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Nhập số lượng';
                      final n = int.tryParse(v);
                      if (n == null || n < 0) return 'Số không hợp lệ';
                      return null;
                    },
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
                      if (_pickedImagePath != null)
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Image.file(
                            File(_pickedImagePath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _processing ? null : _createNewInventoryItem,
                      child: _processing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Thêm vào kho'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
