// lib/screens/inventory_history_screen.dart
import 'package:flutter/material.dart';

class InventoryHistoryScreen extends StatelessWidget {
  const InventoryHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Tạm thời hiển thị trạng thái trống.
    // Sau này có thể kết nối với Hive hoặc service để load dữ liệu lịch sử.
    final List<Map<String, String>> history = [];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lịch sử xuất nhập kho',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'Chưa có lịch sử nào',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return ListTile(
                  leading: Icon(
                    item['type'] == 'in'
                        ? Icons.call_received
                        : Icons.call_made,
                    color: Colors.blue.shade700,
                  ),
                  title: Text(item['title'] ?? ''),
                  subtitle: Text(item['subtitle'] ?? ''),
                );
              },
            ),
    );
  }
}
