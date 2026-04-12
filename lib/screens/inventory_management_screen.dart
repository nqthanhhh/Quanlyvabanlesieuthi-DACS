// lib/screens/inventory_management_screen.dart (ĐÃ CẬP NHẬT: Kết nối nút Sắp hết hàng)
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sieuthimini/screens/import_inventory_screen.dart';

import '../models/inventory_item.dart';
import '../services/db_service.dart';
import 'add_inventory_item_screen.dart';
import 'inventory_check_screen.dart';
import 'inventory_history_screen.dart'; // Màn hình lịch sử xuất nhập kho
import 'low_stock_screen.dart'; // 💡 IMPORT MÀN HÌNH MỚI

class InventoryManagementScreen extends StatefulWidget {
  const InventoryManagementScreen({super.key});

  @override
  State<InventoryManagementScreen> createState() =>
      _InventoryManagementScreenState();
}

class _InventoryManagementScreenState extends State<InventoryManagementScreen> {
  static const int _MIN_STOCK = 50;

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- HÀM TÍNH TOÁN VÀ ĐIỀU HƯỚNG ---

  Map<String, dynamic> _calculateInventoryStats(Box<InventoryItem> box) {
    double totalValue = 0;
    int lowStockCount = 0;

    for (var item in box.values) {
      totalValue += item.stockQuantity * item.price;

      if (item.stockQuantity <= _MIN_STOCK) {
        lowStockCount++;
      }
    }
    return {'totalValue': totalValue, 'lowStockCount': lowStockCount};
  }

  // 💡 HÀM ĐIỀU HƯỚNG ĐẾN DANH SÁCH SẮP HẾT HÀNG
  void _onLowStockPressed() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LowStockScreen()));
  }

  // (Giữ nguyên các hàm điều hướng khác: _onImportInventoryPressed, _onExportInventoryPressed, _onCheckInventoryPressed)

  void _onImportInventoryPressed() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ImportInventoryScreen()));
  }

  void _onHistoryInventoryPressed() async {
    // Chuyển sang màn hình Lịch sử xuất/nhập kho
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const InventoryHistoryScreen()));
  }

  void _onCheckInventoryPressed() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const InventoryCheckScreen()));
  }

  // --- WIDGET HỖ TRỢ (Giữ nguyên) ---

  Widget _buildQuickActionButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    // ... (Giữ nguyên code của _buildQuickActionButton)
    return Expanded(
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.blue.shade700, size: 30),
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildInventoryTile(BuildContext context, InventoryItem item) {
    String status;
    Color statusColor;

    if (item.stockQuantity == 0) {
      status = 'Hết hàng';
      statusColor = Colors.red;
    } else if (item.stockQuantity <= _MIN_STOCK) {
      status = 'Sắp hết';
      statusColor = Colors.orange;
    } else {
      status = 'Còn hàng';
      statusColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: ListTile(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => AddInventoryItemScreen(item: item)),
          );
        },

        leading: Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.inventory_2_outlined, color: Colors.blue.shade700),
        ),

        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mã: ${item.id}'),
            Text(
              'Giá: ${item.price.toStringAsFixed(0)} đ / ${item.unit}',
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Tồn: ${item.stockQuantity} ${item.unit}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: statusColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quản lý Kho',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 1,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thanh tìm kiếm (Giữ nguyên)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.black45, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Tìm kiếm mặt hàng trong kho',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- PHẦN THỐNG KÊ ---
          ValueListenableBuilder<Box<InventoryItem>>(
            valueListenable: DBService.inventoryProducts().listenable(),
            builder: (context, box, _) {
              final stats = _calculateInventoryStats(box);

              final String totalValueStr = (stats['totalValue'] as double)
                  .toStringAsFixed(0)
                  .replaceAllMapped(
                    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                    (Match m) => '${m[1]}.',
                  );

              final int lowStockCount = stats['lowStockCount'] as int;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        elevation: 1,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Giá trị kho',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$totalValueStr đ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.inventory_2,
                                    color: Colors.green,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        // 💡 WRAP BẰNG GESTUREDETECTOR HOẶC INKWELL
                        onTap: _onLowStockPressed, // GỌI HÀM MỚI
                        child: Card(
                          elevation: 1,
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sắp hết hàng',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '$lowStockCount SP',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Colors.red,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // --- KẾT THÚC PHẦN THỐNG KÊ ---
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 12.0),
            child: Text(
              'Tác vụ nhanh',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),

          // --- Dãy 3 NÚT TÁC VỤ NHANH (Giữ nguyên) ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickActionButton(
                  title: 'Nhập kho',
                  icon: Icons.add_circle_outline,
                  onTap: _onImportInventoryPressed,
                ),
                _buildQuickActionButton(
                  title: 'Lịch sử',
                  icon: Icons.history,
                  onTap: _onHistoryInventoryPressed,
                ),
                _buildQuickActionButton(
                  title: 'Kiểm kê',
                  icon: Icons.compare_arrows,
                  onTap: _onCheckInventoryPressed,
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
            child: Text(
              'Danh sách tồn kho',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),

          // PHẦN CUỘN: Danh sách sản phẩm (Giữ nguyên)
          Expanded(
            child: ValueListenableBuilder<Box<InventoryItem>>(
              valueListenable: DBService.inventoryProducts().listenable(),
              builder: (context, box, _) {
                final query = _searchController.text.trim().toLowerCase();
                final List<InventoryItem> items = box.values.where((it) {
                  if (query.isEmpty) return true;
                  return it.id.toLowerCase().contains(query) ||
                      it.name.toLowerCase().contains(query);
                }).toList();

                // Sort: low stock first, then name
                items.sort((a, b) {
                  final cmp = a.stockQuantity.compareTo(b.stockQuantity);
                  if (cmp != 0) return cmp;
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                });

                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Kho hàng đang trống hoặc không có kết quả phù hợp.',
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    bottom: 16.0,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return _buildInventoryTile(context, items[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
