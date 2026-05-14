// lib/screens/import_inventory_screen.dart (ĐÃ CHỈNH SỬA)

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/inventory_item.dart'; // <<< IMPORT InventoryItem
import '../models/product.dart';
import '../services/api_service.dart';
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
  final TextEditingController _importPriceController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '0');

  List<Map<String, dynamic>> _categories = [];
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ApiService.fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategoryId =
            _selectedCategoryId ??
            (categories.isNotEmpty
                ? categories.first['category_id'] as int
                : null);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = [];
        _selectedCategoryId = null;
      });
    }
  }

  String? _pickedImagePath;
  bool _processing = false;
  bool _codeLookupLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _idController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _importPriceController.dispose();
    _unitController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (file != null) {
      setState(() => _pickedImagePath = file.path);
    }
  }

  Future<void> _openScanDialog() async {
    final controller = TextEditingController(text: _searchController.text);
    final code = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quét mã'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Mã vạch / Mã nội bộ',
            helperText: 'Nhập mã thủ công để demo trên simulator',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Tìm'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code != null && code.isNotEmpty) {
      await _lookupCode(code);
    }
  }

  Future<void> _generateInternalCode() async {
    setState(() => _codeLookupLoading = true);
    try {
      final code = await DBService.generateInternalProductCode();
      _idController.text = code;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã tạo mã nội bộ $code')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không tạo được mã: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _codeLookupLoading = false);
    }
  }

  Future<void> _lookupCode(String code) async {
    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) return;

    setState(() => _codeLookupLoading = true);
    try {
      final localItem = DBService.inventoryProducts().get(normalizedCode);
      if (localItem != null) {
        await _addToExisting(localItem);
        return;
      }

      final result = await ApiService.scanProductCode(normalizedCode);
      final inventoryMap = result['inventory_item'];
      if (inventoryMap is Map) {
        final item = InventoryItem.fromJson(
          Map<String, dynamic>.from(inventoryMap),
        );
        await _addToExisting(item);
        return;
      }

      final productMap = result['product'];
      if (productMap is Map) {
        final product = Product.fromJson(Map<String, dynamic>.from(productMap));
        _idController.text = product.barcode ?? normalizedCode;
        _nameController.text = product.name;
        _priceController.text = product.price.toStringAsFixed(0);
        _unitController.text = product.unit;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mã có sản phẩm bán hàng, hãy thêm vào kho'),
          ),
        );
        return;
      }
    } catch (_) {
      _idController.text = normalizedCode;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã chưa tồn tại, đã điền vào form thêm hàng mới'),
        ),
      );
    } finally {
      if (mounted) setState(() => _codeLookupLoading = false);
    }
  }

  // --- HÀM GHI LỊCH SỬ CHO SẢN PHẨM ĐÃ CÓ ---
  Future<void> _addToExisting(InventoryItem item) async {
    final qtyController = TextEditingController(text: '1');
    final importPriceController = TextEditingController(
      text: item.importPrice?.toString() ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nhập thêm vào: ${item.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
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
              const SizedBox(height: 12),
              TextFormField(
                controller: importPriceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Giá nhập',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Nhập giá nhập';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Giá nhập phải lớn hơn 0';
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
                Navigator.of(context).pop({
                  'quantity': int.parse(qtyController.text.trim()),
                  'importPrice': double.parse(
                    importPriceController.text.trim(),
                  ),
                });
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
        final quantity = result['quantity'] as int;
        final importPrice = result['importPrice'] as double;
        await DBService.importInventoryRemote(
          item: item,
          quantity: quantity,
          importPrice: importPrice,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã nhập $quantity vào ${item.name}'),
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
      final id = _idController.text.trim();

      if (DBService.inventoryProducts().containsKey(id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mã vạch / mã nội bộ đã tồn tại!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final name = _nameController.text.trim();
      final price = double.parse(_priceController.text.trim());
      final importPrice = double.parse(_importPriceController.text.trim());
      final unit = _unitController.text.trim();
      final qty = int.parse(_qtyController.text.trim());

      if (_selectedCategoryId == null) {
        throw Exception('Vui lòng chọn danh mục');
      }

      final saved = await DBService.createInventoryItemRemote(
        barcode: id,
        name: name,
        price: price,
        importPrice: importPrice,
        unit: unit,
        quantity: qty,
        categoryId: _selectedCategoryId,
        imagePath: _pickedImagePath,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã thêm ${saved.name} vào kho với SL: $qty'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      _idController.clear();
      _nameController.clear();
      _priceController.clear();
      _importPriceController.clear();
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
                hintText: 'Tìm theo tên hoặc mã vạch / mã nội bộ ...',
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
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _codeLookupLoading ? null : _openScanDialog,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Quét mã'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _codeLookupLoading
                        ? null
                        : () => _lookupCode(_searchController.text.trim()),
                    icon: const Icon(Icons.search),
                    label: const Text('Tìm mã'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ValueListenable để tự động cập nhật khi kho thay đổi
            SizedBox(
              height: 240,
              child: ValueListenableBuilder(
                valueListenable: DBService.inventoryProducts().listenable(),
                builder: (context, Box invBox, _) {
                  final allInventory = invBox.values.toList();

                  final query = _searchController.text.trim();
                  final displayList = allInventory
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
                      final id = item.id;
                      final name = item.name;
                      final stock = item.stockQuantity;
                      final unit = item.unit;
                      final imgPath = DBService.productImages().get(id);
                      Widget leading;
                      if (imgPath != null && File(imgPath).existsSync()) {
                        leading = SizedBox(
                          width: 56,
                          height: 56,
                          child: Image.file(File(imgPath), fit: BoxFit.cover),
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
                        subtitle: Text(
                          'Mã vạch / Mã nội bộ: $id • Tồn: $stock $unit',
                        ),
                        trailing: ElevatedButton(
                          onPressed: _processing
                              ? null
                              : () {
                                  _addToExisting(item);
                                },
                          child: const Text('Nhập'),
                        ),
                        onTap: _processing
                            ? null
                            : () {
                                _addToExisting(item);
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
                      labelText: 'Mã vạch / Mã nội bộ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nhập mã vạch / mã nội bộ'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _codeLookupLoading
                          ? null
                          : _generateInternalCode,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Tạo mã nội bộ'),
                    ),
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
                      labelText: 'Giá bán dự kiến',
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
                    controller: _importPriceController,
                    decoration: const InputDecoration(
                      labelText: 'Giá nhập',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Nhập giá nhập';
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) {
                        return 'Giá nhập phải lớn hơn 0';
                      }
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
                  DropdownButtonFormField<int>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Danh mục sản phẩm',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories
                        .map(
                          (c) => DropdownMenuItem<int>(
                            value: c['category_id'] as int,
                            child: Text(c['category_name'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                    validator: (v) =>
                        v == null ? 'Vui lòng chọn danh mục' : null,
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
