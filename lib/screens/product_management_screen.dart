import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../services/db_service.dart';
import 'edit_product_screen.dart'; // Màn hình chỉnh sửa sản phẩm
import 'add_product_screen.dart'; // Màn hình thêm sản phẩm

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'Tất cả';

  // --- HÀM HỖ TRỢ ---

  // Hàm xác định trạng thái dựa trên số lượng tồn kho
  Map<String, dynamic> _getStockStatus(int stock) {
    String status;
    Color statusColor;

    // 💡 LOGIC TỒN KHO MỚI
    if (stock <= 10) {
      status = 'Hết hàng';
      statusColor = Colors.red;
    } else if (stock < 50) {
      // Từ 11 đến 49
      status = 'Sắp hết';
      statusColor = Colors.orange;
    } else {
      // Từ 50 trở lên
      status = 'Còn hàng';
      statusColor = Colors.green;
    }

    return {'status': status, 'color': statusColor};
  }

  // Xóa sản phẩm khỏi Hive
  Future<void> _deleteProduct(BuildContext context, Product product) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: Text(
              'Bạn có chắc chắn muốn xóa sản phẩm "${product.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Xóa', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await product.delete(); // Xóa trực tiếp từ HiveObject
        // Sử dụng mounted check trước khi gọi ScaffoldMessenger
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa sản phẩm ${product.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi xóa: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Chuyển hướng đến màn hình chỉnh sửa
  void _navigateToEdit(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditProductScreen(product: product)),
    );
  }

  // Widget hiển thị một sản phẩm trong danh sách
  Widget _buildProductTile(BuildContext context, Product product) {
    final statusData = _getStockStatus(product.stockQuantity);
    final String status = statusData['status'];
    final Color statusColor = statusData['color'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        // 1. Ảnh
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 50,
            height: 50,
            color: Colors.blue.shade50,
            child: const Icon(Icons.shopping_bag_outlined, color: Colors.blue),
          ),
        ),

        // 2. Thông tin chính
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mã: ${product.id}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Text(
              '${product.price.round().toString()} ₫ / ${product.unit}',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ],
        ),

        // 3. Tồn kho và Trạng thái
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Tồn: ${product.stockQuantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            // Nút Thao tác (Popup Menu)
            PopupMenuButton<String>(
              onSelected: (String result) {
                if (result == 'edit') {
                  _navigateToEdit(product);
                } else if (result == 'delete') {
                  _deleteProduct(context, product);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit, size: 20),
                    title: Text('Chỉnh sửa'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red, size: 20),
                    title: Text(
                      'Xóa sản phẩm',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _navigateToEdit(product),
      ),
    );
  }

  // --- WIDGET CHÍNH ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý Sản phẩm',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 1. Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.all(16.0).copyWith(bottom: 8),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm theo tên hoặc mã...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Color(0xFFF3F4F6),
                isDense: true,
              ),
            ),
          ),

          // 2. Bộ lọc
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                _buildFilterChip('Tất cả'),
                _buildFilterChip('Còn hàng'),
                _buildFilterChip('Sắp hết'),
                _buildFilterChip('Hết hàng'),
              ],
            ),
          ),

          // 3. Danh sách sản phẩm thực tế (Kết nối Hive)
          Expanded(
            child: ValueListenableBuilder<Box<Product>>(
              valueListenable: DBService.products().listenable(),
              builder: (context, box, _) {
                // Lấy tất cả sản phẩm
                List<Product> allProducts = DBService.getAllProducts();

                // Lọc theo tìm kiếm
                List<Product> filteredProducts = DBService.searchProducts(
                  _searchQuery,
                  allProducts,
                );

                // 💡 LOGIC LỌC THEO TRẠNG THÁI MỚI
                if (_selectedFilter != 'Tất cả') {
                  filteredProducts = filteredProducts.where((product) {
                    final int stock = product.stockQuantity;

                    if (_selectedFilter == 'Hết hàng') {
                      return stock <= 10;
                    } else if (_selectedFilter == 'Sắp hết') {
                      return stock > 10 && stock < 50; // Tức là 11 đến 49
                    } else if (_selectedFilter == 'Còn hàng') {
                      return stock >= 50;
                    }
                    return true;
                  }).toList();
                }

                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Text(
                      'Không tìm thấy sản phẩm nào${_searchQuery.isNotEmpty ? ' khớp với tìm kiếm' : ''}.',
                    ),
                  );
                }

                // Sắp xếp theo tên
                filteredProducts.sort((a, b) => a.name.compareTo(b.name));

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0).copyWith(top: 8),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    return _buildProductTile(context, filteredProducts[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),

      // Nút Thêm sản phẩm
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddProductScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm Sản phẩm'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
    );
  }

  // Widget cho các chip lọc
  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedFilter = label;
            });
          }
        },
        selectedColor: Colors.blue.shade100,
        backgroundColor: Colors.grey.shade100,
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue.shade900 : Colors.black54,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isSelected
              ? BorderSide(color: Colors.blue.shade400)
              : BorderSide.none,
        ),
      ),
    );
  }
}
