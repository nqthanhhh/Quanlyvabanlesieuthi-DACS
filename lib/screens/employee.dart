import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/db_service.dart';
import 'employee_detail_screen.dart';
import 'add_edit_employee_screen.dart';

// Employee view model used only for presentation
class Employee {
  final String name;
  final String role;
  final String email;
  final String phone;
  final String status;
  final Color statusColor;

  Employee({
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.status,
    required this.statusColor,
  });
}

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<User> _allUsers = [];
  List<User> _displayedUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _displayedUsers = List.from(_allUsers));
      return;
    }

    setState(() {
      _displayedUsers = _allUsers.where((u) {
        final name = u.fullName.isNotEmpty ? u.fullName : u.email;
        final role = _mapRole(u.role).toLowerCase();
        return name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            role.contains(q);
      }).toList();
    });
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Assume DBService.init() already called in app start (main.dart).
      final usersBox = DBService.users();
      final users = usersBox.values.cast<User>().toList();

      _allUsers = users;
      _displayedUsers = List.from(_allUsers);
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Không thể tải danh sách nhân viên.';
      });
    }
  }

  Employee _mapUserToEmployee(User user) {
    final name = user.fullName.isNotEmpty ? user.fullName : user.email;
    final role = _mapRole(user.role);
    final phone = user.phone.isNotEmpty ? user.phone : '-';

    // Determine status:
    // - if startDate is null or in the future -> 'Chưa làm' (not started yet)
    // - otherwise (startDate <= now) -> 'Đang làm'
    final now = DateTime.now();
    final status = (user.startDate == null || user.startDate!.isAfter(now))
        ? 'Chưa làm'
        : 'Đang làm';
    final statusColor = (status == 'Đang làm') ? Colors.green : Colors.orange;

    return Employee(
      name: name,
      role: role,
      email: user.email,
      phone: phone,
      status: status,
      statusColor: statusColor,
    );
  }

  String _mapRole(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Quản lý';
      case 'staff':
        return 'Nhân viên';
      default:
        // Treat any unexpected role as regular staff
        return 'Nhân viên';
    }
  }

  Widget _buildEmployeeTileFromUser(User user) {
    final employee = _mapUserToEmployee(user);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        leading: const CircleAvatar(
          backgroundColor: Color(0xFF4C7FFF),
          child: Icon(Icons.person, color: Colors.white),
        ),
        title: Text(
          employee.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              employee.role,
              style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 13),
            ),
            Text(
              employee.phone,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: employee.statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            employee.status,
            style: TextStyle(
              color: employee.statusColor.withOpacity(1.0),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        onTap: () async {
          final changed = await Navigator.of(context).push<bool?>(
            MaterialPageRoute(builder: (_) => EmployeeDetailScreen(user: user)),
          );
          if (changed == true) {
            await _loadEmployees();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Quản lý nhân viên',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add_alt_1, size: 30),
              onPressed: () async {
                final changed = await Navigator.of(context).push<bool?>(
                  MaterialPageRoute(
                    builder: (_) => const AddEditEmployeeScreen(),
                  ),
                );
                if (changed == true) await _loadEmployees();
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF4C7FFF),
            labelColor: Colors.black87,
            tabs: [
              Tab(text: 'Quản lý'),
              Tab(text: 'Nhân viên'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Thanh tìm kiếm
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
                        decoration: const InputDecoration(
                          hintText: 'Tìm kiếm nhân viên',
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

            // Content: Tab views for owner and staff
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : TabBarView(
                      children: [
                        _buildRoleListView('owner'),
                        _buildRoleListView('staff'),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleListView(String roleKey) {
    final filtered = _displayedUsers
        .where((u) => u.role.toLowerCase() == roleKey)
        .toList();
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'Không có nhân viên phù hợp cho ${roleKey == 'owner' ? 'Quản lý' : 'Nhân viên'}',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: filtered.length,
        itemBuilder: (context, index) =>
            _buildEmployeeTileFromUser(filtered[index]),
      ),
    );
  }
}
