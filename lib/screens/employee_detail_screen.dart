import 'package:flutter/material.dart';

import '../models/user.dart';
import 'add_edit_employee_screen.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final User user;

  const EmployeeDetailScreen({super.key, required this.user});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  late User user;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    user = widget.user;
  }

  Future<void> _edit() async {
    final changed = await Navigator.of(context).push<bool?>(
      MaterialPageRoute(builder: (_) => AddEditEmployeeScreen(user: user)),
    );
    if (changed == true) {
      // reload from Hive (user is HiveObject so fields updated in-place)
      setState(() {});
      Navigator.of(context).pop(true); // notify list to refresh
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa nhân viên này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await user.delete();
      Navigator.of(context).pop(true); // notify list to refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết nhân viên'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(onPressed: _edit, icon: const Icon(Icons.edit)),
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_forever),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(
                user.fullName.isNotEmpty ? user.fullName : user.email,
              ),
              subtitle: Text(user.role),
            ),
            const SizedBox(height: 8),
            ListTile(leading: const Icon(Icons.email), title: Text(user.email)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.phone),
              title: Text(user.phone.isNotEmpty ? user.phone : '-'),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.lock),
              title: Text(_obscurePassword ? '••••••••' : user.password),
              trailing: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.home),
              title: Text(user.address.isNotEmpty ? user.address : '-'),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.cake),
              title: Text(user.birthYear != 0 ? '${user.birthYear}' : '-'),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                user.startDate != null
                    ? user.startDate!
                          .toLocal()
                          .toIso8601String()
                          .split('T')
                          .first
                    : 'Chưa có',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
