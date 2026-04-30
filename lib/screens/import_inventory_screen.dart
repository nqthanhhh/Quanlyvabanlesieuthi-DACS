// lib/screens/import_inventory_screen.dart (ĐÃ CHỈNH SỬA)

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../models/inventory_item.dart'; // <<< IMPORT InventoryItem
import '../models/inventory_history_entry.dart';
import '../services/db_service.dart'; // <<< Đảm bảo bạn có DBService và hàm inventoryHistory()

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

  // --- HÀM GHI LỊCH SỬ CHO SẢN PHẨM ĐÃ CÓ ---
  Future<void> _addToExisting(Product item) async {
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
        await DBService.importInventoryRemote(product: item, quantity: result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã nhập $result vào ${item.name}'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi nhập hàng: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _processing = false);
      }
    }
  }

  // --- HÀM GHI LỊCH SỬ CHO SẢN PHẨM MỚI ---
  Future<void> _createNewInventoryItem() async {
    if (!_newFormKey.currentState!.validate()) return;
    setState(() => _processing = true);
    try {
      // Create / update only the InventoryItem (do NOT touch products box)
      final id = _idController.text.trim();
      final invBox = DBService.inventoryProducts();

      // Kiểm tra trùng ID trong inventory
      if (invBox.containsKey(id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mã sản phẩm đã tồn tại trong kho (inventory)!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final name = _nameController.text.trim();
      final price = double.parse(_priceController.text.trim());
      final unit = _unitController.text.trim();
      final qty = int.parse(_qtyController.text.trim());

      final invItem = InventoryItem(
        id: id,
        name: name,
        price: price,
        unit: unit,
        stockQuantity: qty,
      );
      await invBox.put(invItem.id, invItem);

      // Lưu ảnh (nếu có) sử dụng cùng key — ảnh được dùng khi hiển thị inventory/product
      if (_pickedImagePath != null) {
        await DBService.productImages().put(invItem.id, _pickedImagePath!);
      }

      // Ghi lịch sử nhập kho
      final historyItem = InventoryHistoryEntry(
        id: '${DateTime.now().microsecondsSinceEpoch}_${invItem.id}',
        type: 'in',
        itemId: invItem.id,
        itemName: invItem.name,
        unit: invItem.unit,
        quantityChange: invItem.stockQuantity,
        beforeQuantity: 0,
        afterQuantity: invItem.stockQuantity,
        note: 'Tạo mặt hàng kho',
        createdAt: DateTime.now(),
      );
      await DBService.addInventoryHistoryEntry(historyItem);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã thêm ${invItem.name} vào kho với SL: ${invItem.stockQuantity}',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _idController.clear();
      _nameController.clear();
      _priceController.clear();
      _unitController.clear();
      _qtyController.text = '0';
      _newFormKey.currentState!.reset();
      _pickedImagePath = null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi thêm hàng mới: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ... (Phần UI build giữ nguyên)
  @override
  Widget build(BuildContext context) {
    // UI
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nhập hàng vào kho',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search & suggestions for existing products
            const Text(
              'Sản phẩm đã có trong kho',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Tìm theo tên hoặc mã ...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // ValueListenable để tự động cập nhật khi products hoặc inventory box thay đổi
            SizedBox(
              height: 240,
              child: ValueListenableBuilder(
                valueListenable: DBService.products().listenable(),
                builder: (context, Box<Product> prodBox, _) {
                  return ValueListenableBuilder(
                    valueListenable: DBService.inventoryProducts().listenable(),
                    builder: (context, Box invBox, __) {
                      final allProducts = prodBox.values.toList();
                      final allInventory = invBox.values.toList();

                      // Merge: prefer inventory item data for display when available
                      final Map<String, dynamic> merged = {};
                      for (final inv in allInventory) {
                        merged[inv.id] = inv;
                      }
                      for (final p in allProducts) {
                        if (!merged.containsKey(p.id)) merged[p.id] = p;
                      }

                      final List<dynamic> source = merged.values.toList();
                      final query = _searchController.text.trim();
                      final results = DBService.searchProducts(
                        query,
                        source.whereType<Product>().toList(),
                      );

                      // If inventory-only results exist (ids in merged that are InventoryItem), include them too
                      final invMatches = source
                          .where(
                            (s) =>
                                s is InventoryItem &&
                                (query.isEmpty ||
                                    (s.name.toLowerCase().contains(
                                          query.toLowerCase(),
                                        ) ||
                                        s.id.toLowerCase().contains(
                                          query.toLowerCase(),
                                        ))),
                          )
                          .toList();

                      final displayList = <dynamic>[];
                      displayList.addAll(invMatches);
                      // add product matches that are not in inventory matches
                      for (final r in results) {
                        if (!displayList.any(
                          (e) =>
                              (e is InventoryItem ? e.id : (e as Product).id) ==
                              r.id,
                        ))
                          displayList.add(r);
                      }

                      if (displayList.isEmpty) {
                        return const Center(
                          child: Text('Không tìm thấy sản phẩm phù hợp'),
                        );
                      }

                      return ListView.separated(
                        itemCount: displayList.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = displayList[index];
                          final id = item is InventoryItem
                              ? item.id
                              : (item as Product).id;
                          final name = item is InventoryItem
                              ? item.name
                              : (item as Product).name;
                          final stock = item is InventoryItem
                              ? item.stockQuantity
                              : (item as Product).stockQuantity;
                          final unit = item is InventoryItem
                              ? item.unit
                              : (item as Product).unit;
                          final imgPath = DBService.productImages().get(id);
                          Widget leading;
                          if (imgPath != null && File(imgPath).existsSync()) {
                            leading = SizedBox(
                              width: 56,
                              height: 56,
                              child: Image.file(
                                File(imgPath),
                                fit: BoxFit.cover,
                              ),
                            );
                          } else {
                            leading = CircleAvatar(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                              ),
                            );
                          }

                          return ListTile(
                            leading: leading,
                            title: Text(name),
                            subtitle: Text('Mã: $id • Tồn: $stock $unit'),
                            trailing: ElevatedButton(
                              onPressed: _processing
                                  ? null
                                  : () {
                                      // If it's inventory item, open a dialog to add to inventory
                                      if (item is InventoryItem) {
                                        // create a temporary Product-like object to reuse _addToExisting
                                        final temp = Product(
                                          id: item.id,
                                          name: item.name,
                                          price: item.price,
                                          unit: item.unit,
                                          stockQuantity: item.stockQuantity,
                                        );
                                        _addToExisting(temp);
                                      } else if (item is Product) {
                                        _addToExisting(item);
                                      }
                                    },
                              child: const Text('Nhập'),
                            ),
                            onTap: _processing
                                ? null
                                : () {
                                    if (item is InventoryItem) {
                                      final temp = Product(
                                        id: item.id,
                                        name: item.name,
                                        price: item.price,
                                        unit: item.unit,
                                        stockQuantity: item.stockQuantity,
                                      );
                                      _addToExisting(temp);
                                    } else if (item is Product) {
                                      _addToExisting(item);
                                    }
                                  },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Nhập hàng mới (Sản phẩm chưa có trong kho)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Form(
              key: _newFormKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      labelText: 'Mã SP (Dùng làm Key)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Nhập mã SP' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên sản phẩm',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Nhập tên SP' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Giá bán (đơn vị)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Nhập giá bán';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return 'Số không hợp lệ';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Đơn vị tính (kg, chiếc, hộp...)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Nhập đơn vị' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _qtyController,
                    decoration: const InputDecoration(
                      labelText: 'Số lượng nhập (ban đầu)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Nhập số lượng';
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
